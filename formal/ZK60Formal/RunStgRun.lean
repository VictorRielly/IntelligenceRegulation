/-
D63 lane L53 (2026-11-10), part 3: **the classify run's transcript at its two stage parts is the stage's verifier trace
and more, and the stage parts' sub-protocols are alive at the end of the run's transcript** (deliverable 2, the run
half; L50's `ra_blk_acc` and `ra_hal_*` at the stages).

* **`stg_inc_rd`**, **`stg_outc_rd`**: on an accepted run (`classifyVerifyE` accepts), at the part `i` that is stage IN-C
  (resp. OUT-C), the run's transcript is a READING of the stage (`StgRd`): a header of `off i + 5` (resp. `off i + 2`)
  operations (the run before the part and the stage's frame), a canonical core of the stage's slot shapes, the stage's
  slot phase accepted after it as L15's `stageSlots` (IN-C: under the schedule of its head's challenges, by L29's
  `incSlots_model`; OUT-C: under its one schedule, `(0, γ, α)`), and the transcript the trace of the stage's operations
  followed by operations within `Lq` bytes;
* `StgTermAt`, `StgDefAt`, `StgLkAt`: the stage-level facts at every reading of a stage on a transcript (L50's
  `RaTermAt`, `RaDefAt`, `RaLkAt` for a stage): each slot's terminal identity over the extracted tables, each define
  draw's polynomial vanishing at the drawn challenges, LogUp's state at the head's challenges;
* **`stg_sl_rd`**, **`stg_def_rd`**, **`stg_lk_rd`**: at a reading, the lists' slots, define draws and LogUp run are
  alive at the end of the transcript, given those facts.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgAlive

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV incHeadDraws IncCtx incCtx)
open ZK60.Circuit (gP GF)

/-! ## A reading of a stage on a transcript -/

section Rd

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **A reading of a stage on the transcript `τ`**: a header of `hdrLen` operations within `L` bytes, a canonical core
of the slot shapes of the schedule `Pof ch`, the stage's slot phase accepted after the header (L15's `stageSlots` under
`Pof ch`, `ch` its head's `m` challenges, `rs` its slot records), and `τ` the trace of the stage's operations (the
header, the head, the slots) followed by operations within `L` bytes. -/
def StgRd (key : Option Dig) (domain : List UInt8) (L : ℕ) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (G : QB L → Dig) (τ : List (TItem × Dig)) (hdr : List Op)
    (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec) : Prop :=
  hdr.length = hdrLen ∧ (∀ op ∈ hdr, op.len ≤ L) ∧ Block.CoreCanon core ∧ StageFS.SlotsShape (Pof ch).geom core
    ∧ (∃ acc t', StageFS.stageSlots (liftH G) (Pof ch) m bgaOf core
        (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) = .ok (ch, rs, acc, t'))
    ∧ ∃ T : List Op, (∀ op ∈ T, op.len ≤ L) ∧ τ = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 core.slots ++ T)

/-- **Every stage slot's terminal identity at every reading** (L50's `RaTermAt` for a stage): the slot's final value is
its polynomial `F` over the cuts the trace before its rounds shows, at what the trace shows, at the slot's point. -/
def StgTermAt (U : K) (key : Option Dig) (domain : List UInt8) (P0 : Block.BlockParams)
    (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (absOf : QB L → Option (List UInt8))
    (F : (ℕ → List (QB L × Dig)) → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
    ∀ k q r, core.slots[k]? = some q → rs[k]? = some r →
      r.fin.toK U = F (stgCuts absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q)))
        k (StageFS.seenOfS ch rs k) (fun i => ((r.rho ++ r.es).getD i Fp2.zero).toK U)

/-- **Every stage define draw's polynomial vanishes at every reading** (L50's `RaDefAt` for a stage): for every slot
that draws, its polynomial `Φ` over the cuts the trace before its draws shows, at what `define` saw, is zero at the
drawn challenges. -/
def StgDefAt (U : K) (key : Option Dig) (domain : List UInt8) (P0 : Block.BlockParams)
    (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (absOf : QB L → Option (List UInt8))
    (Φ : (ℕ → List (QB L × Dig)) → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
    ∀ k ∈ stgDrawing P0, ∃ r, rs[k]? = some r ∧
      Φ (stgCuts absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)))) k
        (ch, (rs.take k).map Block.SlotRec.draws) (fun i => (r.draws.getD i.val Fp2.zero).toK U) = 0

/-- **The stage's LogUp state at every reading** (L50's `RaLkAt` for a stage): at the head's challenges, over the cuts
the trace before them shows. -/
def StgLkAt (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB L → Option (List UInt8))
    (Λ : (ℕ → List (QB L × Dig)) → List (List UInt8 × K) → Prop)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
    Λ (stgCuts absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
      (hdr ++ Block.rootOpsA (Pof ch) core))) (ch.map (fun c => (([] : List UInt8), c.toK U)))

/-- **At a reading, the lists' slots are alive at the end of the transcript**, given every slot's terminal identity
(`StgTermAt`), the lists' schedule `P0` with the stage's draws and slot shapes, and the stage's hosting `hostOf`. -/
theorem stg_sl_rd (U : K) (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64)
    (hL81 : 81 ≤ L) (P0 : Block.BlockParams) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (hostOf : ℕ → List (ℕ × ℕ)) (absOf : QB L → Option (List UInt8))
    (F : (ℕ → List (QB L × Dig)) → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs)
    (hP : StgSame P0 (Pof ch))
    (hgeom : ∀ k, k < (Pof ch).geom.slots.length → 1 ≤ (Block.slotShape (Pof ch) k).2.2
      ∧ 56 + 16 * ((Block.slotShape (Pof ch) k).2.2 + 1) ≤ L ∧ 55 + 16 * Block.slotTerms (Pof ch) k ≤ L)
    (hgt : (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hhost : ∀ k hist dr df, (Pof ch).define k hist dr = .ok df →
      df.hosted = (hostOf k).map (fun x => (x.1, dr.getD x.2 Fp2.zero)))
    (hterm : StgTermAt U key domain P0 Pof m hdrLen bgaOf absOf F G Lg τ) :
    allSt W1 (slotSubs U (slotsAt (stgSchedX P0 m hdrLen hostOf absOf F) Lg)) τ := by
  obtain ⟨hhl, hhfit, hcan, hsh, ⟨acc, t', hacc⟩, T, hT, hτ⟩ := hrd
  have hgeom' : ∀ k, k < (Pof ch).geom.slots.length → 1 ≤ (Block.slotShape (Pof ch) k).2.2
      ∧ (Block.slotShape (Pof ch) k).2.2 < gP ∧ 56 + 16 * ((Block.slotShape (Pof ch) k).2.2 + 1) ≤ L
      ∧ 55 + 16 * Block.slotTerms (Pof ch) k ≤ L := by
    intro k hk
    obtain ⟨h1, h2, h3⟩ := hgeom k hk
    refine ⟨h1, ?_, h2, h3⟩
    have h64' : L < 18446744073709551616 := by
      have h := hL64
      norm_num at h
      exact h
    show (Block.slotShape (Pof ch) k).2.2 < 18446744069414584321
    omega
  rw [hτ, ← hhl]
  exact stg_slots_alive U hU key domain hs hL hL64 hL81 P0 (Pof ch) hP m hostOf absOf F bgaOf hgeom' hgt G Lg hdr core
    hhfit hcan.1 hsh ch rs acc t' hacc hhost
    (fun k q r hq hr => hterm hdr core ch rs ⟨hhl, hhfit, hcan, hsh, ⟨acc, t', hacc⟩, T, hT, hτ⟩ k q r hq hr) T hT

/-- **At a reading, the lists' define draws are alive at the end of the transcript**, given every define draw's
polynomial vanishing at the drawn challenges (`StgDefAt`). -/
theorem stg_def_rd (U : K) (key : Option Dig) (domain : List UInt8) (P0 : Block.BlockParams)
    (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : (ℕ → List (QB L × Dig)) → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K)
    (dg : ℕ → ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (G : QB L → Dig) (Lg : List (QB L × Dig))
    (τ : List (TItem × Dig)) (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs)
    (hP : StgSame P0 (Pof ch))
    (hgeom : ∀ k, k < (Pof ch).geom.slots.length → 1 ≤ (Block.slotShape (Pof ch) k).2.2)
    (hgt : (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hdef : StgDefAt U key domain P0 Pof m hdrLen bgaOf absOf Φ G Lg τ) :
    ∀ sx ∈ stgDefs P0 m hdrLen absOf Φ dg, subSt W1 (sqSub U sx Lg) τ := by
  intro sx hsx
  obtain ⟨k, hk, rfl⟩ := List.mem_map.mp hsx
  obtain ⟨r, hr, hz⟩ := hdef hdr core ch rs hrd k hk
  obtain ⟨hhl, -, -, hsh, ⟨acc, t', hacc⟩, T, -, hτ⟩ := hrd
  rw [hτ, ← hhl]
  exact stg_def_alive U key domain P0 (Pof ch) hP m absOf Φ dg bgaOf hgeom hgt G Lg hdr core hsh ch rs acc t' hacc T
    k r hr hz

/-- **At a reading, the lists' LogUp run is alive at the end of the transcript**, given its state at the head's
challenges (`StgLkAt`). -/
theorem stg_lk_rd (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams)
    (m hdrLen e : ℕ) (absOf : QB L → Option (List UInt8))
    (Λ : (ℕ → List (QB L × Dig)) → List (List UInt8 × K) → Prop) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) (hdr : List Op) (core : Block.Core)
    (ch : List Fp2) (rs : List Block.SlotRec) (hrd : StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs)
    (hlk : StgLkAt U key domain Pof m hdrLen bgaOf absOf Λ G Lg τ) :
    subSt W1 (sqSub U (stgLkSq m hdrLen e absOf Λ) Lg) τ := by
  have hΛ := hlk hdr core ch rs hrd
  obtain ⟨hhl, -, -, -, ⟨acc, t', hacc⟩, T, -, hτ⟩ := hrd
  rw [hτ, ← hhl]
  exact stg_lk_alive U key domain (Pof ch) m e absOf Λ bgaOf G Lg hdr core ch rs acc t' hacc T hΛ

end Rd

/-! ## The run's transcript at its two stage parts -/

section Run

variable {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}

/-- **Stage IN-C's slot phase as L15's `stageSlots` at the schedule of its head's challenges** (L29's
`incSlots_model`): the same challenges, records and transcript. -/
theorem stg_inc_stageSlots (H : HIn → Dig) (VI : IncV) (core : Block.Core) (t : Tr) (recs : List Block.SlotRec)
    (acc : Block.Acc) (t4 : Tr) (h : VI.slots H core t = .ok (recs, acc, t4)) :
    ∃ acc', StageFS.stageSlots H (VI.bp (incCtx VI.pub (VI.headCh H core t).1)) (incHeadDraws VI.pub)
      (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) core t = .ok ((VI.headCh H core t).1, recs, acc', t4) := by
  have hm := StageV.incSlots_model H VI core t
  rw [h] at hm
  have h2 : (fun x : List Fp2 × List Block.SlotRec × Block.Acc × Tr => ((x.1, x.2.1), StageV.accStrip x.2.2.1, x.2.2.2))
      <$> StageFS.stageSlots H (VI.bp (incCtx VI.pub (VI.headCh H core t).1)) (incHeadDraws VI.pub)
        (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) core t
      = .ok (((VI.headCh H core t).1, recs), StageV.accStrip acc, t4) := hm.symm
  obtain ⟨⟨ch', recs', acc', t4'⟩, hl, hy⟩ := (StageV.map_ok_iff _ _ _).mp h2
  simp only [Prod.mk.injEq] at hy
  obtain ⟨⟨rfl, rfl⟩, -, rfl⟩ := hy
  exact ⟨acc', hl⟩

/-- A stage's head reads its schedule only through `A`'s and `H`'s row counts and the column log. -/
theorem stg_root_congr (P P' : Block.BlockParams) (core : Block.Core) (m : ℕ) (h1 : P.aRows = P'.aRows)
    (h2 : P.hRows = P'.hRows) (h3 : P.logCols = P'.logCols) :
    StageFS.stageRootOps P core m = StageFS.stageRootOps P' core m := by
  simp only [StageFS.stageRootOps, Block.rootOpsA, Block.rootOpsH, h1, h2, h3]

theorem stg_incBp_aRows (VI : IncV) (cx : IncCtx) : (VI.bp cx).aRows = VI.lay.aRows := rfl

theorem stg_incBp_hRows (VI : IncV) (cx : IncCtx) : (VI.bp cx).hRows = VI.lay.hRows := rfl

theorem stg_incBp_logCols (VI : IncV) (cx : IncCtx) : (VI.bp cx).logCols = VI.lay.logN := rfl

/-- Stage IN-C's head does not read the context (`define` alone does). -/
theorem stg_incBp_root (VI : IncV) (cx cx' : IncCtx) (core : Block.Core) (m : ℕ) :
    StageFS.stageRootOps (VI.bp cx) core m = StageFS.stageRootOps (VI.bp cx') core m :=
  stg_root_congr _ _ core m (by rw [stg_incBp_aRows, stg_incBp_aRows]) (by rw [stg_incBp_hRows, stg_incBp_hRows])
    (by rw [stg_incBp_logCols, stg_incBp_logCols])

/-- Stage IN-C's slots' operations do not read the context. -/
theorem stg_incBp_full (VI : IncV) (cx cx' : IncCtx) (sps : List Block.SlotProof) :
    Block.fullOps (VI.bp cx) 0 sps = Block.fullOps (VI.bp cx') 0 sps := by
  rw [rt_fullOps, rt_fullOps, rt_incBp_draws, rt_incBp_draws]

/-- **THE RUN'S TRANSCRIPT AT STAGE IN-C IS A READING OF THE STAGE.** On an accepted run, at the part `i` that is
stage IN-C (`rtIncSeg inc incG cx0 p`): a reading (`StgRd`) with the header the run's operations before the part and the
stage's frame (`off i + 5` of them), under the schedule of the head's challenges (`(inc s.hdr).bp (incCtx … ch)`),
`m = incHeadDraws`, `define`'s history `(0, 0, 0)`. -/
theorem stg_inc_rd (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i : ℕ) (p : RtPart)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (cx0 : IncCtx)
    (hσi : R.σs[i]? = some (rtIncSeg inc incG cx0 p))
    (hgeo : (incG s.hdr).g = (inc s.hdr).geom)
    (hgt : (inc s.hdr).geom.slots.length = (inc s.hdr).geom.terms.length)
    (hd : ∀ cx k, k < (inc s.hdr).geom.slots.length → 1 ≤ (Block.slotShape ((inc s.hdr).bp cx) k).2.2) :
    ∃ (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec),
      StgRd key domain Lq (fun ch => (inc s.hdr).bp (incCtx (inc s.hdr).pub ch)) (incHeadDraws (inc s.hdr).pub)
        (R.pf.off i + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) G (R.tr G (s, segs)) hdr core ch rs := by
  obtain ⟨seg, root, recs, acc, t4, -, -, -, -, -, hcanC, hshape, -, hrdi, hpi, hbr, hs, -⟩ :=
    rs_inc_run R hv G s segs hE i p inc incG cx0 hσi hgeo hgt hd (fun _ => inc s.hdr) rfl
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  have hgd : seg.bRoot.getD zeroDig = root := by rw [hbr]; rfl
  have hfitAll := rtS_fit Lq R.pf R.rd (s, segs)
  have e1 := rtPre_facts Lq R.pf (R.rd (s, segs)) hgood i
  have e2 := rtPartsStps_drop R.pf.parts (R.rd (s, segs)).2 i p _ hpi hrdi
  obtain ⟨acc', hst⟩ := stg_inc_stageSlots (liftH G) (inc s.hdr) seg.core _ recs acc t4 hs
  obtain ⟨hdr, hhdr⟩ : ∃ hdr, hdr = stpsOps (rtPre R.pf (R.rd (s, segs)) i)
      ++ rtIncFrame (inc s.hdr).pub.embDigest root (inc s.hdr).geo.bRows (inc s.hdr).geo.bLogN := ⟨_, rfl⟩
  rw [← hhdr] at hst
  obtain ⟨T, hops⟩ : ∃ T, stpsOps (rtS Lq R.pf R.rd (s, segs))
      = hdr ++ StageFS.stageRootOps ((inc s.hdr).bp cx0) seg.core (incHeadDraws (inc s.hdr).pub)
        ++ Block.fullOps ((inc s.hdr).bp cx0) 0 seg.core.slots ++ T := by
    refine ⟨stpsOps (mStps p.S seg.core.maskOpen ++ (pcsStps p.wA p.mA seg.core.aOpen ++ (pcsStps p.wH p.mH
      seg.core.hOpen ++ pcsStps p.wX p.mX (seg.closes.headD IncV.ozk0))) ++ rtPartsStps (R.pf.parts.drop (i + 1))
        ((R.rd (s, segs)).2.drop (i + 1))), ?_⟩
    rw [rtS_good Lq R.pf R.rd (s, segs) hgood, e1.1, e2]
    simp only [hhdr, rtPartStps, rtIncData, stpsOps_append, stpsOps_opsStps, hgd, List.append_assoc]
  refine ⟨hdr, seg.core, ((inc s.hdr).headCh (liftH G) seg.core (runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
    hdr)).1, recs, ?_, ?_, hcanC, ⟨hshape.1, hshape.2.1⟩, ⟨acc', t4, hst⟩, T, ?_, ?_⟩
  · rw [hhdr, List.length_append, e1.2.1]
    rfl
  · intro op hop
    exact hfitAll op (by rw [hops]; exact List.mem_append_left _ (List.mem_append_left _
      (List.mem_append_left _ hop)))
  · intro op hop
    exact hfitAll op (by rw [hops]; exact List.mem_append_right _ hop)
  · show opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtS Lq R.pf R.rd (s, segs))) = _
    rw [hops, stg_incBp_root (inc s.hdr) cx0 _ seg.core, stg_incBp_full (inc s.hdr) cx0 _ seg.core.slots]

/-- **THE RUN'S TRANSCRIPT AT STAGE OUT-C IS A READING OF THE STAGE.** On an accepted run, at the part `i` that is
stage OUT-C (`rtOutcSeg outc outcG p`): a reading with the header the run's operations before the part and the stage's
frame (`off i + 2` of them), under the stage's one schedule `(outc s.hdr s.verdict).bp`, `m = 2`, `(0, γ, α)`. -/
theorem stg_outc_rd (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i : ℕ) (p : RtPart)
    (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (hσi : R.σs[i]? = some (rtOutcSeg outc outcG p))
    (hgeo : (outcG s.hdr).g = (outc s.hdr s.verdict).geom)
    (hgt : (outc s.hdr s.verdict).geom.slots.length = (outc s.hdr s.verdict).geom.terms.length)
    (hd : ∀ k, k < (outc s.hdr s.verdict).geom.slots.length →
      1 ≤ (Block.slotShape (outc s.hdr s.verdict).bp k).2.2) :
    ∃ (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec),
      StgRd key domain Lq (fun _ => (outc s.hdr s.verdict).bp) 2 (R.pf.off i + 2) OutcV.bga G (R.tr G (s, segs))
        hdr core ch rs := by
  obtain ⟨-, seg, ch, recs, acc, t4, -, -, -, -, -, -, hcanC, hshape, -, hrdi, hpi, hs, -⟩ :=
    rs_outc_run R hv G s segs hE i p outc outcG hσi hgeo hgt hd (fun _ => outc s.hdr s.verdict) rfl
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  have hfitAll := rtS_fit Lq R.pf R.rd (s, segs)
  have e1 := rtPre_facts Lq R.pf (R.rd (s, segs)) hgood i
  have e2 := rtPartsStps_drop R.pf.parts (R.rd (s, segs)).2 i p _ hpi hrdi
  obtain ⟨hdr, hhdr⟩ : ∃ hdr, hdr = stpsOps (rtPre R.pf (R.rd (s, segs)) i)
      ++ rtOutcFrame (outc s.hdr s.verdict).stageIndex (outc s.hdr s.verdict).pub.wDigest := ⟨_, rfl⟩
  rw [← hhdr] at hs
  obtain ⟨T, hops⟩ : ∃ T, stpsOps (rtS Lq R.pf R.rd (s, segs))
      = hdr ++ StageFS.stageRootOps (outc s.hdr s.verdict).bp seg.core 2
        ++ Block.fullOps (outc s.hdr s.verdict).bp 0 seg.core.slots ++ T := by
    refine ⟨stpsOps (mStps p.S seg.core.maskOpen ++ (pcsStps p.wA p.mA seg.core.aOpen ++ (pcsStps p.wH p.mH
      seg.core.hOpen ++ pcsStps p.wX p.mX (seg.closes.headD IncV.ozk0))) ++ rtPartsStps (R.pf.parts.drop (i + 1))
        ((R.rd (s, segs)).2.drop (i + 1))), ?_⟩
    rw [rtS_good Lq R.pf R.rd (s, segs) hgood, e1.1, e2]
    simp only [hhdr, rtPartStps, rtOutcData, stpsOps_append, stpsOps_opsStps, List.append_assoc]
  refine ⟨hdr, seg.core, ch, recs, ?_, ?_, hcanC, ⟨hshape.1, hshape.2.1⟩, ⟨acc, t4, hs⟩, T, ?_, ?_⟩
  · rw [hhdr, List.length_append, e1.2.1]
    rfl
  · intro op hop
    exact hfitAll op (by rw [hops]; exact List.mem_append_left _ (List.mem_append_left _
      (List.mem_append_left _ hop)))
  · intro op hop
    exact hfitAll op (by rw [hops]; exact List.mem_append_right _ hop)
  · show opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtS Lq R.pf R.rd (s, segs))) = _
    rw [hops]

end Run

end ZK60.ProtocolClassify
