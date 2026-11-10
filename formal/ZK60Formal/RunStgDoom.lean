/-
D63 lane L53 (2026-11-10), part 6: **the stage doom covers `hdin`, `hdout` at the stage parts' lists, reduced to each
stage's own doom at its reading of the run** (deliverable 3, the run half; L46's `rd_cover_of_sq` with the stages'
slots).

`hdin` (`hdout`) asks: on an accepted run outside the run's extraction event, if stage IN-C's (OUT-C's) conclusion fails
on the extracted data, some kind of the ordered list `rtKo` has a doomed entrant in some part. With the stage parts'
lists of `RunStgList.lean`, every check the stage verifier makes is a list entry of its part, so it suffices that ONE of
them starts from a false claim. This file proves that transport:

* `StgDoomAt`: at every reading of a stage, one of the lists' entries starts from a false claim ON THE STAGE'S OWN
  TRACE before its window: a define draw of a slot that draws (its polynomial not identically zero at what `define`
  saw), the head's LogUp run (its state false before the challenges), or a slot (its claimed sum not its polynomial's
  cube sum);
* `stg_rd_head`, `stg_rd_def`, `stg_rd_slot`: at a reading, the run's transcript cut at each window IS the stage's
  trace before it;
* `stg_some_sl`: a slot of a part's list with a false header state is a doomed entrant of `rtKo` (L46's `rd_some_sq`
  for the slots' kind);
* **`stg_cover_rd`**: a stage's doom at a reading is a doomed entrant of `rtKo` in the stage's part;
* **`stg_hal_din`**, **`stg_hal_dout`**: `hdin`'s and `hdout`'s conclusions on the classify run, from the stage's doom at
  the run's reading of stage IN-C (part `0`) and stage OUT-C (part `Lb + 1`).

What remains is the stage algebra: a failing `InOkP` (`OutOkP`) gives the stage's doom at its reading (L12's
`inc_stage_sound`, L15's `outc_stage_sound`), as a premise.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgHal

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV incHeadDraws IncCtx incCtx)
open ZK60.Circuit (gP GF)

/-! ## A stage's doom at its readings -/

section DoomAt

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **A stage's doom at every reading**: one of the lists' entries starts from a false claim on the stage's own trace
before its window: a define draw of a slot that draws, the head's LogUp run, or a slot. -/
def StgDoomAt (U : K) (key : Option Dig) (domain : List UInt8) (P0 : Block.BlockParams)
    (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (hostOf : ℕ → List (ℕ × ℕ)) (absOf : QB L → Option (List UInt8))
    (F : (ℕ → List (QB L × Dig)) → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K)
    (Φ : (ℕ → List (QB L × Dig)) → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K)
    (dg : ℕ → ℕ) (e : ℕ) (Λ : (ℕ → List (QB L × Dig)) → List (List UInt8 × K) → Prop)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
    (∃ k ∈ stgDrawing P0, ¬ (stgDefSq P0 m hdrLen absOf Φ dg k).St Lg
        (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k))) [])
    ∨ ¬ (stgLkSq m hdrLen e absOf Λ).St Lg
        (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core)) []
    ∨ (∃ k q, core.slots[k]? = some q ∧ ¬ (slotSub U ((stgSlotX P0 m hdrLen hostOf absOf F k).at Lg)
        (stgDefPos P0 m hdrLen k + (P0.draws k + 3))).St
        (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q)) [])

/-- The slots' rounds are the schedule's, on a core of its slot shapes. -/
theorem stg_rounds (P : Block.BlockParams) (core : Block.Core) (hsh : StageFS.SlotsShape P.geom core)
    (hgt : P.geom.slots.length = P.geom.terms.length) :
    ∀ i q, core.slots[i]? = some q → q.rounds.length = (Block.slotShape P i).1 + (Block.slotShape P i).2.1 := by
  intro i q hq
  have hslen : core.slots.length = P.geom.slots.length := hsh.1
  have hi : i < P.geom.slots.length := by rw [← hslen]; exact (List.getElem?_eq_some_iff.mp hq).1
  obtain ⟨s, hs'⟩ : ∃ s, P.geom.slots[i]? = some s := ⟨_, List.getElem?_eq_getElem hi⟩
  obtain ⟨tt, htt⟩ : ∃ tt, P.geom.terms[i]? = some tt := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  have := (hsh.2 i q s tt hq hs' htt).1
  rw [this, Block.slotShape, List.getD_eq_getElem?_getD, hs', Option.getD_some]

/-- **At a reading, the transcript cut after `A` and `M` is the stage's trace there** (LogUp's window). -/
theorem stg_rd_head (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (G : QB L → Dig) (τ : List (TItem × Dig)) (hdr : List Op)
    (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs) :
    τ.take (hdrLen + 4) = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core)
      ∧ hdrLen + 4 ≤ τ.length := by
  obtain ⟨hhl, -, -, -, -, T, -, hτ⟩ := hrd
  have hops : hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 core.slots ++ T
      = (hdr ++ Block.rootOpsA (Pof ch) core) ++ (Block.drawOps m ++ (Block.rootOpsH (Pof ch) core
        ++ Block.fullOps (Pof ch) 0 core.slots ++ T)) := by
    simp only [StageFS.stageRootOps, List.append_assoc]
  have hlA : (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core)).length
      = hdrLen + 4 := by
    rw [Block.opTrace_length, List.length_append, hhl]
    rfl
  rw [hτ, hops, Block.opTrace_append]
  refine ⟨?_, ?_⟩
  · rw [← hlA, List.take_left' rfl]
  · rw [List.length_append, hlA]
    exact Nat.le_add_right _ _

/-- **At a reading, the transcript cut at slot `k`'s define window is the stage's trace there.** -/
theorem stg_rd_def (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (G : QB L → Dig) (τ : List (TItem × Dig)) (hdr : List Op)
    (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs)
    (hgt : (Pof ch).geom.slots.length = (Pof ch).geom.terms.length) (k : ℕ) (q : Block.SlotProof)
    (hq : core.slots[k]? = some q) :
    τ.take (stgDefPos (Pof ch) m hdrLen k) = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k))
      ∧ stgDefPos (Pof ch) m hdrLen k ≤ τ.length := by
  obtain ⟨hhl, -, -, hsh, -, T, -, hτ⟩ := hrd
  obtain ⟨hw1, -, hw3⟩ := stg_def_window (liftH G) (Pof ch) m core hdr (Tr.newKeyed (liftH G) domain key) k q hq
    (stg_rounds (Pof ch) core hsh hgt)
  rw [hhl] at hw1 hw3
  rw [hτ, Block.opTrace_append]
  refine ⟨?_, ?_⟩
  · rw [List.take_append_of_le_length hw3, hw1]
  · rw [List.length_append]
    exact hw3.trans (Nat.le_add_right _ _)

/-- **At a reading, the transcript cut at slot `k`'s window is the stage's trace there** (the slot's header). -/
theorem stg_rd_slot (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (G : QB L → Dig) (τ : List (TItem × Dig)) (hdr : List Op)
    (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs)
    (hgt : (Pof ch).geom.slots.length = (Pof ch).geom.terms.length) (k : ℕ) (q : Block.SlotProof)
    (hq : core.slots[k]? = some q) :
    τ.take (stgDefPos (Pof ch) m hdrLen k + ((Pof ch).draws k + 3)) = opTrace (liftH G)
        (Tr.newKeyed (liftH G) domain key) (hdr ++ StageFS.stageRootOps (Pof ch) core m
          ++ Block.fullOps (Pof ch) 0 (core.slots.take k) ++ Block.slotPreOps (Pof ch) k q)
      ∧ stgDefPos (Pof ch) m hdrLen k + ((Pof ch).draws k + 3) ≤ τ.length := by
  obtain ⟨hhl, -, -, hsh, -, T, -, hτ⟩ := hrd
  have hr := stg_rounds (Pof ch) core hsh hgt
  have hk : k < core.slots.length := (List.getElem?_eq_some_iff.mp hq).1
  have hqk : core.slots[k] = q := (List.getElem?_eq_some_iff.mp hq).2
  have hlenk : (core.slots.take k).length = k := by rw [List.length_take]; omega
  have hdrop : core.slots.drop k = q :: core.slots.drop (k + 1) := by rw [List.drop_eq_getElem_cons hk, hqk]
  have hfo : Block.fullOps (Pof ch) 0 core.slots = Block.fullOps (Pof ch) 0 (core.slots.take k)
      ++ (Block.slotPreOps (Pof ch) k q ++ (scOps q.rounds ++ [Block.termOp q]
        ++ Block.fullOps (Pof ch) (k + 1) (core.slots.drop (k + 1)))) := by
    conv_lhs => rw [← List.take_append_drop k core.slots]
    rw [Block.fullOps_append, hlenk, Nat.zero_add, hdrop]
    simp only [Block.fullOps, List.append_assoc]
  obtain ⟨X, hX⟩ : ∃ X, X = hdr ++ StageFS.stageRootOps (Pof ch) core m
      ++ Block.fullOps (Pof ch) 0 (core.slots.take k) ++ Block.slotPreOps (Pof ch) k q := ⟨_, rfl⟩
  have hops : hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 core.slots ++ T
      = X ++ ((scOps q.rounds ++ [Block.termOp q] ++ Block.fullOps (Pof ch) (k + 1) (core.slots.drop (k + 1))) ++ T) := by
    rw [hX, hfo]
    simp only [List.append_assoc]
  have hlX : (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) X).length
      = stgDefPos (Pof ch) m hdrLen k + ((Pof ch).draws k + 3) := by
    rw [Block.opTrace_length, hX, List.length_append, List.length_append, List.length_append,
      StageFS.stageRootOps_length, Block.slotPreOps_length,
      Block.fullOps_length (Pof ch) 0 _ (fun i sp hsp => by
        rw [Nat.zero_add]
        rw [List.getElem?_take] at hsp
        split_ifs at hsp
        exact hr i sp hsp), hlenk, hhl]
    rfl
  rw [hτ, hops, Block.opTrace_append, ← hX]
  refine ⟨?_, ?_⟩
  · rw [← hlX, List.take_left' rfl]
  · rw [List.length_append, hlX]
    exact Nat.le_add_right _ _

end DoomAt

/-! ## A stage's doom is a doomed entrant of the run's kinds -/

section Cover

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)

/-- **A slot of part `i`'s list with a false header state is a doomed entrant of the run's kinds** (the slots' kind;
L46's `rd_some_sq` for the squeeze kinds). -/
theorem stg_some_sl (n i : ℕ) (hi : i < pf.parts.length) (hin : i < n) (lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) (k : ℕ) (sl : SlotX K Lq) (hk : (D.sls i)[k]? = some sl)
    (ha : slotsLenX ((D.sls i).take k) + sl.s ≤ τ.length)
    (hn : ¬ (slotSub U (sl.at lg) (slotsLenX ((D.sls i).take k) + sl.s)).St
      (τ.take (slotsLenX ((D.sls i).take k) + sl.s)) []) :
    RcSome (rtKo key domain hs Lq hL pf rd hL64 hv U hbij D hD) n lg τ := by
  refine ⟨rtKsl key domain hs Lq hL pf rd hL64 hv U hbij D hD, ?_, i, hin,
    slotSub U (sl.at lg) (slotsLenX ((D.sls i).take k) + sl.s), ?_, ha, tRem_W1 _, hn⟩
  · exact List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ List.mem_cons_self))
  · rw [ra_ksl_cs key domain hs Lq hL pf rd hL64 hv U hbij D hD i hi]
    exact List.mem_of_getElem? (by rw [rt_slotSubs_getElem?, hk]; rfl)

/-- **A STAGE'S DOOM AT A READING IS A DOOMED ENTRANT OF THE RUN'S KINDS IN THE STAGE'S PART.** When part `i`'s lists
are the stage's (`hS`, `hR`, `hLU`), the lists' schedule has the stage's draws and slot shapes (`hP`), and at the reading
one of the lists' entries starts from a false claim on the stage's trace (`hdoom`), the run's kinds have a doomed
entrant (`RcSome`, the form of `hdin`, `hdout`). -/
theorem stg_cover_rd (n i : ℕ) (hi : i < pf.parts.length) (hin : i < n) (P0 : Block.BlockParams)
    (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (hostOf : ℕ → List (ℕ × ℕ)) (absOf : QB Lq → Option (List UInt8))
    (F : (ℕ → List (QB Lq × Dig)) → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K)
    (Φ : (ℕ → List (QB Lq × Dig)) → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K)
    (dg : ℕ → ℕ) (e : ℕ) (Λ : (ℕ → List (QB Lq × Dig)) → List (List UInt8 × K) → Prop)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) (hdr : List Op) (core : Block.Core)
    (ch : List Fp2) (rs : List Block.SlotRec) (hrd : StgRd key domain Lq Pof m hdrLen bgaOf G τ hdr core ch rs)
    (hP : StgSame P0 (Pof ch)) (hgt : (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hS : D.sls i = stgSchedX P0 m hdrLen hostOf absOf F) (hR : D.r0 i = stgDefs P0 m hdrLen absOf Φ dg)
    (hLU : D.lu i = [stgLkSq m hdrLen e absOf Λ])
    (hdoom : StgDoomAt U key domain P0 Pof m hdrLen bgaOf hostOf absOf F Φ dg e Λ G lg τ) :
    RcSome (rtKo key domain hs Lq hL pf rd hL64 hv U hbij D hD) n lg τ := by
  have hslen : core.slots.length = (Pof ch).geom.slots.length := hrd.2.2.2.1.1
  rcases hdoom hdr core ch rs hrd with ⟨k, hk, hn⟩ | hn | ⟨k, q, hq, hn⟩
  · -- a define draw
    have hkl : k < core.slots.length := by
      rw [hslen, ← hP.2]
      exact List.mem_range.mp (List.mem_filter.mp hk).1
    obtain ⟨q, hq⟩ : ∃ q, core.slots[k]? = some q := ⟨_, List.getElem?_eq_getElem hkl⟩
    obtain ⟨h1, h2⟩ := stg_rd_def key domain Pof m hdrLen bgaOf G τ hdr core ch rs hrd hgt k q hq
    have ha : (stgDefSq P0 m hdrLen absOf Φ dg k).a = stgDefPos (Pof ch) m hdrLen k := stg_stgDefPos hP m hdrLen k
    refine rd_some_sq key domain hs Lq hL pf rd hL64 hv U hbij D hD n i hi hin lg τ
      (stgDefSq P0 m hdrLen absOf Φ dg k) (Or.inl ?_) (by rw [ha]; exact h2) ?_
    · rw [hR]
      exact List.mem_map_of_mem hk
    · rw [ha, h1]
      exact hn
  · -- the head's LogUp run
    obtain ⟨h1, h2⟩ := stg_rd_head key domain Pof m hdrLen bgaOf G τ hdr core ch rs hrd
    refine rd_some_sq key domain hs Lq hL pf rd hL64 hv U hbij D hD n i hi hin lg τ
      (stgLkSq m hdrLen e absOf Λ) (Or.inr (Or.inr (Or.inr (Or.inr ?_)))) h2 ?_
    · rw [hLU]
      exact List.mem_singleton_self _
    · show ¬ (stgLkSq m hdrLen e absOf Λ).St lg (τ.take (hdrLen + 4)) []
      rw [h1]
      exact hn
  · -- a slot
    have hkl : k < core.slots.length := (List.getElem?_eq_some_iff.mp hq).1
    have hk0 : k < P0.geom.slots.length := by rw [hP.2, ← hslen]; exact hkl
    obtain ⟨h1, h2⟩ := stg_rd_slot key domain Pof m hdrLen bgaOf G τ hdr core ch rs hrd hgt k q hq
    have hsl : (D.sls i)[k]? = some (stgSlotX P0 m hdrLen hostOf absOf F k) := by
      rw [hS]
      exact (stgSchedX_get P0 m hdrLen hostOf absOf F k _).mpr ⟨hk0, rfl⟩
    have hwin : slotsLenX ((D.sls i).take k) + (stgSlotX P0 m hdrLen hostOf absOf F k).s
        = stgDefPos (Pof ch) m hdrLen k + ((Pof ch).draws k + 3) := by
      rw [hS, stg_win P0 m hdrLen hostOf absOf F k hk0.le, stg_stgDefPos hP, hP.1]
    have hwin0 : stgDefPos P0 m hdrLen k + (P0.draws k + 3)
        = stgDefPos (Pof ch) m hdrLen k + ((Pof ch).draws k + 3) := by
      rw [stg_stgDefPos hP, hP.1]
    refine stg_some_sl key domain hs Lq hL pf rd hL64 hv U hbij D hD n i hi hin lg τ k _ hsl
      (by rw [hwin]; exact h2) ?_
    rw [hwin, h1, ← hwin0]
    exact hn

end Cover

/-! ## `hdin` and `hdout` on the classify run -/

section Hal

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

/-- **`hdin`'s and `hdout`'s conclusion on the classify run, from a stage's doom at the run's reading**: stage IN-C's at
part `0` (`hIn`) or stage OUT-C's at part `Lb + 1` (`hOut`) gives a doomed entrant of `rtKo` (`RcSome`). -/
theorem stg_hal_doom
    (R : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : R.pf.Valid) (cx0 : IncCtx) (pin pout : RtPart) (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : R.σs = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (Iin : RtInc Lq inc incG pin) (Oout : RtOutc Lq outc outcG pout) (mIn : ℕ)
    (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn)
    (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) R.pf)
    (P0in P0out : Block.BlockParams) (hostIn hostOut : ℕ → List (ℕ × ℕ))
    (FI : (ℕ → List (QB Lq × Dig)) → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0in k) → K) → K)
    (FO : (ℕ → List (QB Lq × Dig)) → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0out k) → K) → K)
    (ΦI : (ℕ → List (QB Lq × Dig)) → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0in.draws k) → K) → K)
    (ΦO : (ℕ → List (QB Lq × Dig)) → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0out.draws k) → K) → K)
    (dgI dgO : ℕ → ℕ) (eI eO : ℕ) (ΛI ΛO : (ℕ → List (QB Lq × Dig)) → List (List UInt8 × K) → Prop)
    (hPin : ∀ hd cx, StgSame P0in ((inc hd).bp cx)) (hPout : ∀ hd v, StgSame P0out (outc hd v).bp)
    (hS0 : D.sls 0 = stgSchedX P0in mIn (R.pf.off 0 + 5) hostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) FI)
    (hR0 : D.r0 0 = stgDefs P0in mIn (R.pf.off 0 + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΦI dgI)
    (hL0 : D.lu 0 = [stgLkSq mIn (R.pf.off 0 + 5) eI (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛI])
    (hS1 : D.sls (Lb + 1) = stgSchedX P0out 2 (R.pf.off (Lb + 1) + 2) hostOut
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) FO)
    (hR1 : D.r0 (Lb + 1) = stgDefs P0out 2 (R.pf.off (Lb + 1) + 2) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      ΦO dgO)
    (hL1 : D.lu (Lb + 1) = [stgLkSq 2 (R.pf.off (Lb + 1) + 2) eO (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      ΛO])
    (n : ℕ) (hn : Lb + 2 = n) (lg : List (QB Lq × Dig)) (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G) s segs = .ok ())
    (hdoom : StgDoomAt U key domain P0in (fun ch => (inc s.hdr).bp (incCtx (inc s.hdr).pub ch)) mIn (R.pf.off 0 + 5)
        (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) hostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) FI ΦI dgI
        eI ΛI G lg (R.tr G (s, segs))
      ∨ StgDoomAt U key domain P0out (fun _ => (outc s.hdr s.verdict).bp) 2 (R.pf.off (Lb + 1) + 2) OutcV.bga hostOut
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) FO ΦO dgO eO ΛO G lg (R.tr G (s, segs))) :
    RcSome (rtKo key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD) n lg (R.tr G (s, segs)) := by
  have hL2 : R.pf.parts.length = Lb + 2 := RtRun.parts_length R
  obtain ⟨⟨hdr, core, ch, rs, hrd⟩, ⟨hdr', core', ch', rs', hrd'⟩⟩ := stg_rds Lb preA preB start inc incG outc outcG
    Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv cx0 pin pout bp wXk gXk mXk hσ Iin Oout mIn hmIn G s
    segs hE
  rcases hdoom with h | h
  · exact stg_cover_rd key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD n 0 (by omega) (by omega) P0in _ mIn _ _
      hostIn _ FI ΦI dgI eI ΛI G lg _ hdr core ch rs hrd (hPin s.hdr _) (Iin.hgt s.hdr) hS0 hR0 hL0 h
  · exact stg_cover_rd key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD n (Lb + 1) (by omega) (by omega) P0out _ 2 _ _
      hostOut _ FO ΦO dgO eO ΛO G lg _ hdr' core' ch' rs' hrd' (hPout s.hdr s.verdict) (Oout.hgt s.hdr s.verdict) hS1 hR1
      hL1 h

end Hal

end ZK60.ProtocolClassify
