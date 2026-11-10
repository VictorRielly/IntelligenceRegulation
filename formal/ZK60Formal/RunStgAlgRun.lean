/-
D63 lane L57 (2026-11-10), part 3: **the stage parts' alive premises and doom covers at the view lists** (finding L57-1;
lane L53's `RunStgRun.lean`, `RunStgHal.lean` and `RunStgDoom.lean` for the lists of `RunStgAlgList.lean`).

The stage-level facts are restated with the view (`StgTermAtV`, `StgDefAtV`, `StgLkAtV`, `StgDoomAtV`: L53's, the
polynomials and state reading the cuts AND the header at their windows). Their consequences at the run come from L53's
theorems, without re-proving them: at ONE transcript `τ` (the run's), a view polynomial is an L53 polynomial that reads
the header `τ` shows at the entry's window (`stgFAt`, `stgΦAt`, `stgΛAt`); at a reading of the stage the run's
transcript cut at each window IS the stage's trace there (L53's `stg_rd_slot`, `stg_rd_def`, `stg_rd_head`), so the
view facts give L53's (`stgTermAt_of_V`, `stgDefAt_of_V`, `stgLkAt_of_V`); and the two lists' sub-protocols have the
same windows, rounds and errors and the same states at `τ`'s windows (`stg_slot_V`, `stg_allSt_V`, `stg_def_V`,
`stg_lk_V`). The doom cover is L53's `stg_cover_rd` at the view lists (`stg_cover_rdV`).

* **`stg_hal_slV`**, **`stg_hal_r0V`**, **`stg_hal_luV`**: `hsl_stg`'s, `hR0_stg`'s, `hLU_stg`'s conclusions at the view
  lists, from the view facts;
* **`stg_hal_doomV`**: `hdin`'s and `hdout`'s conclusion at the view lists, from a stage's view doom at its reading.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgDoom
import ZK60Formal.RunStgAlgList
import ZK60Formal.RunStgAlgHost

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV incHeadDraws IncCtx incCtx)
open ZK60.Circuit (gP GF)

/-! ## A view polynomial at one transcript is an L53 polynomial -/

section At

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **A slot polynomial over the view, at the transcript `τ`**: slot `k` reads the header `τ` shows at its window. -/
def stgFAt (P0 : Block.BlockParams) (m hdrLen : ℕ)
    (F : StgVw L → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K) (τ : List (TItem × Dig)) :
    (ℕ → List (QB L × Dig)) → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K :=
  fun cu k sn x => F (cu, τ.take (stgDefPos P0 m hdrLen k + (P0.draws k + 3))) k sn x

/-- **A define polynomial over the view, at the transcript `τ`**: slot `k`'s draws read the header at their window. -/
def stgΦAt (P0 : Block.BlockParams) (m hdrLen : ℕ)
    (Φ : StgVw L → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K) (τ : List (TItem × Dig)) :
    (ℕ → List (QB L × Dig)) → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K :=
  fun cu k h y => Φ (cu, τ.take (stgDefPos P0 m hdrLen k)) k h y

/-- **The LogUp state over the view, at the transcript `τ`**: the header at the head's window. -/
def stgΛAt (hdrLen : ℕ) (Λ : StgVw L → List (List UInt8 × K) → Prop) (τ : List (TItem × Dig)) :
    (ℕ → List (QB L × Dig)) → List (List UInt8 × K) → Prop :=
  fun cu τr => Λ (cu, τ.take (hdrLen + 4)) τr

/-- A slot whose statement agrees on its window's header has the same state. -/
theorem subSt_slotSub_stmt (U : K) (W : UInt64 → ℕ) (s d n : ℕ)
    (st st' : List (TItem × Dig) → ((Fin n → K) → K) × Fp2) (a : ℕ) (τ : List (TItem × Dig))
    (h : st (τ.take a) = st' (τ.take a)) :
    subSt W (slotSub U ⟨s, d, n, st⟩ a) τ ↔ subSt W (slotSub U ⟨s, d, n, st'⟩ a) τ := by
  refine subSt_congr W _ _ τ rfl rfl Iff.rfl ?_
  rw [slotSub_a]
  funext τr
  simp only [slotSub_St, scSt, h]

/-- **Slot `k` of the two lists at its window, at `τ`**: the same state. -/
theorem stg_slot_V (U : K) (P0 : Block.BlockParams) (m hdrLen : ℕ) (hostOf : ℕ → List (ℕ × ℕ))
    (absOf : QB L → Option (List UInt8))
    (F : StgVw L → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K) (Lg : List (QB L × Dig))
    (τ : List (TItem × Dig)) (k : ℕ) :
    subSt W1 (slotSub U ((stgSlotX P0 m hdrLen hostOf absOf (stgFAt P0 m hdrLen F τ) k).at Lg)
        (stgDefPos P0 m hdrLen k + (P0.draws k + 3))) τ
      ↔ subSt W1 (slotSub U ((stgSlotV P0 m hdrLen hostOf absOf F k).at Lg)
        (stgDefPos P0 m hdrLen k + (P0.draws k + 3))) τ := by
  refine subSt_slotSub_stmt U W1 (stgS P0 m hdrLen k) (Block.slotShape P0 k).2.2 (stgN P0 k)
    ((stgSlotX P0 m hdrLen hostOf absOf (stgFAt P0 m hdrLen F τ) k).stmt Lg)
    ((stgSlotV P0 m hdrLen hostOf absOf F k).stmt Lg) _ τ ?_
  show (match StageFS.tSeenS P0 hdrLen m k (τ.take (stgDefPos P0 m hdrLen k + (P0.draws k + 3))) with
    | some (sn, _) => (stgFAt P0 m hdrLen F τ (stgCuts absOf Lg (τ.take (stgDefPos P0 m hdrLen k + (P0.draws k + 3))))
        k sn, stgClaim hostOf k sn)
    | none => (fun _ => 0, Fp2.zero)) = (match StageFS.tSeenS P0 hdrLen m k
        (τ.take (stgDefPos P0 m hdrLen k + (P0.draws k + 3))) with
    | some (sn, _) => (F (stgVw absOf Lg (τ.take (stgDefPos P0 m hdrLen k + (P0.draws k + 3)))) k sn,
        stgClaim hostOf k sn)
    | none => (fun _ => 0, Fp2.zero))
  cases StageFS.tSeenS P0 hdrLen m k (τ.take (stgDefPos P0 m hdrLen k + (P0.draws k + 3))) with
  | none => rfl
  | some p =>
    cases p
    rfl

/-- **The two lists' slots at `τ`**: alive together. -/
theorem stg_allSt_V (U : K) (P0 : Block.BlockParams) (m hdrLen : ℕ) (hostOf : ℕ → List (ℕ × ℕ))
    (absOf : QB L → Option (List UInt8))
    (F : StgVw L → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K) (Lg : List (QB L × Dig))
    (τ : List (TItem × Dig)) :
    allSt W1 (slotSubs U (slotsAt (stgSchedX P0 m hdrLen hostOf absOf (stgFAt P0 m hdrLen F τ)) Lg)) τ
      ↔ allSt W1 (slotSubs U (slotsAt (stgSchedV P0 m hdrLen hostOf absOf F) Lg)) τ := by
  have hget : ∀ (sch : List (SlotX K L)) (k : ℕ), (slotSubs U (slotsAt sch Lg))[k]?
      = sch[k]?.map (fun sl => slotSub U (sl.at Lg) (slotsLenX (sch.take k) + sl.s)) := by
    intro sch k
    rw [slotSubs_getElem?, slotsLen_take_at, slotsAt, List.getElem?_map, Option.map_map]
    rfl
  have hX : ∀ k, k < P0.geom.slots.length →
      (slotSubs U (slotsAt (stgSchedX P0 m hdrLen hostOf absOf (stgFAt P0 m hdrLen F τ)) Lg))[k]?
        = some (slotSub U ((stgSlotX P0 m hdrLen hostOf absOf (stgFAt P0 m hdrLen F τ) k).at Lg)
          (stgDefPos P0 m hdrLen k + (P0.draws k + 3))) := by
    intro k hk
    rw [hget, (stgSchedX_get P0 m hdrLen hostOf absOf (stgFAt P0 m hdrLen F τ) k _).mpr ⟨hk, rfl⟩]
    show some (slotSub U ((stgSlotX P0 m hdrLen hostOf absOf (stgFAt P0 m hdrLen F τ) k).at Lg)
      (slotsLenX ((stgSchedX P0 m hdrLen hostOf absOf (stgFAt P0 m hdrLen F τ)).take k)
        + (stgSlotX P0 m hdrLen hostOf absOf (stgFAt P0 m hdrLen F τ) k).s)) = _
    rw [stg_win P0 m hdrLen hostOf absOf (stgFAt P0 m hdrLen F τ) k hk.le]
  have hV : ∀ k, k < P0.geom.slots.length →
      (slotSubs U (slotsAt (stgSchedV P0 m hdrLen hostOf absOf F) Lg))[k]?
        = some (slotSub U ((stgSlotV P0 m hdrLen hostOf absOf F k).at Lg)
          (stgDefPos P0 m hdrLen k + (P0.draws k + 3))) := by
    intro k hk
    rw [hget, (stgSchedV_get P0 m hdrLen hostOf absOf F k _).mpr ⟨hk, rfl⟩]
    show some (slotSub U ((stgSlotV P0 m hdrLen hostOf absOf F k).at Lg)
      (slotsLenX ((stgSchedV P0 m hdrLen hostOf absOf F).take k) + (stgSlotV P0 m hdrLen hostOf absOf F k).s)) = _
    rw [stgV_win P0 m hdrLen hostOf absOf F k hk.le]
  have hlen : ∀ (sch : List (SlotX K L)) (k : ℕ) (c : CSub Dig), (slotSubs U (slotsAt sch Lg))[k]? = some c →
      k < sch.length := by
    intro sch k c h
    rw [hget] at h
    obtain ⟨sl, hsl, -⟩ := Option.map_eq_some_iff.mp h
    exact (List.getElem?_eq_some_iff.mp hsl).1
  have hlX : (stgSchedX P0 m hdrLen hostOf absOf (stgFAt P0 m hdrLen F τ)).length = P0.geom.slots.length := by
    rw [stgSchedX, List.length_map, List.length_range]
  have hlV : (stgSchedV P0 m hdrLen hostOf absOf F).length = P0.geom.slots.length := by
    rw [stgSchedV, List.length_map, List.length_range]
  constructor
  · intro hall k c hc
    have hk : k < P0.geom.slots.length := by rw [← hlV]; exact hlen _ k c hc
    rw [hV k hk, Option.some.injEq] at hc
    subst hc
    exact (stg_slot_V U P0 m hdrLen hostOf absOf F Lg τ k).mp (hall k _ (hX k hk))
  · intro hall k c hc
    have hk : k < P0.geom.slots.length := by rw [← hlX]; exact hlen _ k c hc
    rw [hX k hk, Option.some.injEq] at hc
    subst hc
    exact (stg_slot_V U P0 m hdrLen hostOf absOf F Lg τ k).mpr (hall k _ (hV k hk))

/-- **Slot `k`'s define draws in the two lists, at `τ`**: the same state. -/
theorem stg_def_V (U : K) (P0 : Block.BlockParams) (m hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : StgVw L → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K) (dg : ℕ → ℕ)
    (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) (k : ℕ) :
    subSt W1 (sqSub U (stgDefSq P0 m hdrLen absOf (stgΦAt P0 m hdrLen Φ τ) dg k) Lg) τ
      ↔ subSt W1 (sqSub U (stgDefSqV P0 m hdrLen absOf Φ dg k) Lg) τ := by
  refine subSt_congr W1 _ _ τ rfl rfl Iff.rfl ?_
  funext τr
  show (match tHistS P0 hdrLen m k (τ.take (stgDefPos P0 m hdrLen k)) with
    | some (hh, _) => szSt (stgΦAt P0 m hdrLen Φ τ (stgCuts absOf Lg (τ.take (stgDefPos P0 m hdrLen k))) k hh) _
    | none => True) = (match tHistS P0 hdrLen m k (τ.take (stgDefPos P0 m hdrLen k)) with
    | some (hh, _) => szSt (Φ (stgVw absOf Lg (τ.take (stgDefPos P0 m hdrLen k))) k hh) _
    | none => True)
  cases tHistS P0 hdrLen m k (τ.take (stgDefPos P0 m hdrLen k)) with
  | none => rfl
  | some p =>
    cases p
    rfl

/-- **The two lists' define draws at `τ`**: alive together (the old ones alive give the view ones). -/
theorem stg_defs_V (U : K) (P0 : Block.BlockParams) (m hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : StgVw L → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K) (dg : ℕ → ℕ)
    (Lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (h : ∀ sx ∈ stgDefs P0 m hdrLen absOf (stgΦAt P0 m hdrLen Φ τ) dg, subSt W1 (sqSub U sx Lg) τ) :
    ∀ sx ∈ stgDefsV P0 m hdrLen absOf Φ dg, subSt W1 (sqSub U sx Lg) τ := by
  intro sx hsx
  obtain ⟨k, hk, rfl⟩ := List.mem_map.mp hsx
  exact (stg_def_V U P0 m hdrLen absOf Φ dg Lg τ k).mp (h _ (List.mem_map_of_mem hk))

/-- **The head's LogUp run in the two lists, at `τ`**: the same state. -/
theorem stg_lk_V (U : K) (m hdrLen e : ℕ) (absOf : QB L → Option (List UInt8))
    (Λ : StgVw L → List (List UInt8 × K) → Prop) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) :
    subSt W1 (sqSub U (stgLkSq m hdrLen e absOf (stgΛAt hdrLen Λ τ)) Lg) τ
      ↔ subSt W1 (sqSub U (stgLkSqV m hdrLen e absOf Λ) Lg) τ :=
  subSt_congr W1 _ _ τ rfl rfl Iff.rfl rfl

end At

/-! ## The stage-level facts over the view, and L53's from them -/

section Facts

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **Every stage slot's terminal identity at every reading, over the view** (L53's `StgTermAt` with `F` reading the
cuts AND the trace before the slot's rounds). -/
def StgTermAtV (U : K) (key : Option Dig) (domain : List UInt8) (P0 : Block.BlockParams)
    (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (absOf : QB L → Option (List UInt8))
    (F : StgVw L → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
    ∀ k q r, core.slots[k]? = some q → rs[k]? = some r →
      r.fin.toK U = F (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q)))
        k (StageFS.seenOfS ch rs k) (fun i => ((r.rho ++ r.es).getD i Fp2.zero).toK U)

/-- **Every stage define draw's polynomial vanishes at every reading, over the view.** -/
def StgDefAtV (U : K) (key : Option Dig) (domain : List UInt8) (P0 : Block.BlockParams)
    (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (absOf : QB L → Option (List UInt8))
    (Φ : StgVw L → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
    ∀ k ∈ stgDrawing P0, ∃ r, rs[k]? = some r ∧
      Φ (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)))) k
        (ch, (rs.take k).map Block.SlotRec.draws) (fun i => (r.draws.getD i.val Fp2.zero).toK U) = 0

/-- **The stage's LogUp state at every reading, over the view.** -/
def StgLkAtV (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB L → Option (List UInt8))
    (Λ : StgVw L → List (List UInt8 × K) → Prop)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
    Λ (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
      (hdr ++ Block.rootOpsA (Pof ch) core))) (ch.map (fun c => (([] : List UInt8), c.toK U)))

/-- **The view terminal identities give L53's at `τ`.** -/
theorem stgTermAt_of_V (U : K) (key : Option Dig) (domain : List UInt8) (P0 : Block.BlockParams)
    (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (absOf : QB L → Option (List UInt8))
    (F : StgVw L → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (hP : ∀ ch, StgSame P0 (Pof ch)) (hgt : ∀ ch, (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (h : StgTermAtV U key domain P0 Pof m hdrLen bgaOf absOf F G Lg τ) :
    StgTermAt U key domain P0 Pof m hdrLen bgaOf absOf (stgFAt P0 m hdrLen F τ) G Lg τ := by
  intro hdr core ch rs hrd k q r hq hr
  rw [h hdr core ch rs hrd k q r hq hr]
  obtain ⟨h1, -⟩ := stg_rd_slot key domain Pof m hdrLen bgaOf G τ hdr core ch rs hrd (hgt ch) k q hq
  show F (stgCuts absOf Lg _, _) k _ _ = F (stgCuts absOf Lg _, τ.take (stgDefPos P0 m hdrLen k + (P0.draws k + 3))) k _ _
  rw [stg_stgDefPos (hP ch) m hdrLen k, (hP ch).1, h1]

/-- **The view define polynomials vanishing give L53's at `τ`.** -/
theorem stgDefAt_of_V (U : K) (key : Option Dig) (domain : List UInt8) (P0 : Block.BlockParams)
    (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (absOf : QB L → Option (List UInt8))
    (Φ : StgVw L → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (hP : ∀ ch, StgSame P0 (Pof ch)) (hgt : ∀ ch, (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (h : StgDefAtV U key domain P0 Pof m hdrLen bgaOf absOf Φ G Lg τ) :
    StgDefAt U key domain P0 Pof m hdrLen bgaOf absOf (stgΦAt P0 m hdrLen Φ τ) G Lg τ := by
  intro hdr core ch rs hrd k hk
  obtain ⟨r, hr, hz⟩ := h hdr core ch rs hrd k hk
  refine ⟨r, hr, ?_⟩
  have hslen : core.slots.length = (Pof ch).geom.slots.length := hrd.2.2.2.1.1
  have hkl : k < core.slots.length := by
    rw [hslen, ← (hP ch).2]
    exact List.mem_range.mp (List.mem_filter.mp hk).1
  obtain ⟨q, hq⟩ : ∃ q, core.slots[k]? = some q := ⟨_, List.getElem?_eq_getElem hkl⟩
  obtain ⟨h1, -⟩ := stg_rd_def key domain Pof m hdrLen bgaOf G τ hdr core ch rs hrd (hgt ch) k q hq
  show Φ (stgCuts absOf Lg _, τ.take (stgDefPos P0 m hdrLen k)) k _ _ = 0
  rw [stg_stgDefPos (hP ch) m hdrLen k, h1]
  exact hz

/-- **The view LogUp state gives L53's at `τ`.** -/
theorem stgLkAt_of_V (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams)
    (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB L → Option (List UInt8))
    (Λ : StgVw L → List (List UInt8 × K) → Prop) (G : QB L → Dig) (Lg : List (QB L × Dig))
    (τ : List (TItem × Dig))
    (h : StgLkAtV U key domain Pof m hdrLen bgaOf absOf Λ G Lg τ) :
    StgLkAt U key domain Pof m hdrLen bgaOf absOf (stgΛAt hdrLen Λ τ) G Lg τ := by
  intro hdr core ch rs hrd
  obtain ⟨h1, -⟩ := stg_rd_head key domain Pof m hdrLen bgaOf G τ hdr core ch rs hrd
  show Λ (stgCuts absOf Lg _, τ.take (hdrLen + 4)) _
  rw [h1]
  exact h hdr core ch rs hrd

end Facts

/-! ## The three alive conclusions at the view lists -/

section Hal

variable {K : Type} [Field K] [Algebra GF K] (U : K)
  {Hdr : Type} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (Lb : ℕ) (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr)
  (inc : Hdr → IncV) (incG : Hdr → StageGeom) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
  (Pk : ℕ → Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

/-- **`hsl_stg`'s conclusion at the view lists**: both stage parts' slots alive at the end of the run's transcript,
from the view terminal identities. -/
theorem stg_hal_slV (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
    (hL64 : Lq < 2 ^ 64) (hU : U ^ 2 = algebraMap GF K 7) (hL81 : 81 ≤ Lq)
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
    (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn) (absOf : QB Lq → Option (List UInt8))
    (P0in P0out : Block.BlockParams) (hostIn hostOut : ℕ → List (ℕ × ℕ))
    (FI : StgVw Lq → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0in k) → K) → K)
    (FO : StgVw Lq → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0out k) → K) → K)
    (hPin : ∀ hd cx, StgSame P0in ((inc hd).bp cx)) (hPout : ∀ hd v, StgSame P0out (outc hd v).bp)
    (hhIn : ∀ hd cx k hist dr df, ((inc hd).bp cx).define k hist dr = .ok df →
      df.hosted = (hostIn k).map (fun x => (x.1, dr.getD x.2 Fp2.zero)))
    (hhOut : ∀ hd v k hist dr df, (outc hd v).bp.define k hist dr = .ok df →
      df.hosted = (hostOut k).map (fun x => (x.1, dr.getD x.2 Fp2.zero)))
    (D : RtKData K Lq)
    (hS0 : D.sls 0 = stgSchedV P0in mIn (R.pf.off 0 + 5) hostIn absOf FI)
    (hS1 : D.sls (Lb + 1) = stgSchedV P0out 2 (R.pf.off (Lb + 1) + 2) hostOut absOf FO)
    (lg : List (QB Lq × Dig)) (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G) s segs = .ok ())
    (hTI : StgTermAtV U key domain P0in (fun ch => (inc s.hdr).bp (incCtx (inc s.hdr).pub ch)) mIn (R.pf.off 0 + 5)
      (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) absOf FI G lg (R.tr G (s, segs)))
    (hTO : StgTermAtV U key domain P0out (fun _ => (outc s.hdr s.verdict).bp) 2 (R.pf.off (Lb + 1) + 2) OutcV.bga
      absOf FO G lg (R.tr G (s, segs))) :
    allSt W1 (slotSubs U (slotsAt (D.sls 0) lg)) (R.tr G (s, segs))
      ∧ allSt W1 (slotSubs U (slotsAt (D.sls (Lb + 1)) lg)) (R.tr G (s, segs)) := by
  obtain ⟨⟨hdr, core, ch, rs, hrd⟩, ⟨hdr', core', ch', rs', hrd'⟩⟩ := stg_rds Lb preA preB start inc incG outc outcG
    Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv cx0 pin pout bp wXk gXk mXk hσ Iin Oout mIn hmIn G s
    segs hE
  rw [hS0, hS1]
  refine ⟨?_, ?_⟩
  · exact (stg_allSt_V U P0in mIn (R.pf.off 0 + 5) hostIn absOf FI lg (R.tr G (s, segs))).mp
      (stg_sl_rd U hU key domain hs hL hL64 hL81 P0in _ mIn _ hostIn absOf
        (stgFAt P0in mIn (R.pf.off 0 + 5) FI (R.tr G (s, segs))) _ G lg _ hdr core ch rs hrd
        (hPin s.hdr _) (fun k hk => Iin.hgeomL s.hdr _ k hk) (Iin.hgt s.hdr) (hhIn s.hdr _)
        (stgTermAt_of_V U key domain P0in _ mIn _ _ absOf FI G lg _ (fun _ => hPin s.hdr _)
          (fun _ => Iin.hgt s.hdr) hTI))
  · exact (stg_allSt_V U P0out 2 (R.pf.off (Lb + 1) + 2) hostOut absOf FO lg (R.tr G (s, segs))).mp
      (stg_sl_rd U hU key domain hs hL hL64 hL81 P0out _ 2 _ hostOut absOf
        (stgFAt P0out 2 (R.pf.off (Lb + 1) + 2) FO (R.tr G (s, segs))) _ G lg _ hdr' core' ch' rs' hrd'
        (hPout s.hdr s.verdict) (fun k hk => Oout.hgeomL s.hdr s.verdict k hk) (Oout.hgt s.hdr s.verdict)
        (hhOut s.hdr s.verdict)
        (stgTermAt_of_V U key domain P0out _ 2 _ _ absOf FO G lg _ (fun _ => hPout s.hdr s.verdict)
          (fun _ => Oout.hgt s.hdr s.verdict) hTO))

/-- **`hR0_stg`'s conclusion at the view lists**: both stage parts' define draws alive. -/
theorem stg_hal_r0V
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
    (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn) (absOf : QB Lq → Option (List UInt8))
    (P0in P0out : Block.BlockParams)
    (ΦI : StgVw Lq → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0in.draws k) → K) → K)
    (ΦO : StgVw Lq → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0out.draws k) → K) → K)
    (dgI dgO : ℕ → ℕ)
    (hPin : ∀ hd cx, StgSame P0in ((inc hd).bp cx)) (hPout : ∀ hd v, StgSame P0out (outc hd v).bp)
    (D : RtKData K Lq)
    (hR0 : D.r0 0 = stgDefsV P0in mIn (R.pf.off 0 + 5) absOf ΦI dgI)
    (hR1 : D.r0 (Lb + 1) = stgDefsV P0out 2 (R.pf.off (Lb + 1) + 2) absOf ΦO dgO)
    (lg : List (QB Lq × Dig)) (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G) s segs = .ok ())
    (hDI : StgDefAtV U key domain P0in (fun ch => (inc s.hdr).bp (incCtx (inc s.hdr).pub ch)) mIn (R.pf.off 0 + 5)
      (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) absOf ΦI G lg (R.tr G (s, segs)))
    (hDO : StgDefAtV U key domain P0out (fun _ => (outc s.hdr s.verdict).bp) 2 (R.pf.off (Lb + 1) + 2) OutcV.bga
      absOf ΦO G lg (R.tr G (s, segs))) :
    (∀ sx ∈ D.r0 0, subSt W1 (sqSub U sx lg) (R.tr G (s, segs)))
      ∧ (∀ sx ∈ D.r0 (Lb + 1), subSt W1 (sqSub U sx lg) (R.tr G (s, segs))) := by
  obtain ⟨⟨hdr, core, ch, rs, hrd⟩, ⟨hdr', core', ch', rs', hrd'⟩⟩ := stg_rds Lb preA preB start inc incG outc outcG
    Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv cx0 pin pout bp wXk gXk mXk hσ Iin Oout mIn hmIn G s
    segs hE
  rw [hR0, hR1]
  refine ⟨?_, ?_⟩
  · exact stg_defs_V U P0in mIn (R.pf.off 0 + 5) absOf ΦI dgI lg (R.tr G (s, segs))
      (stg_def_rd U key domain P0in _ mIn _ absOf (stgΦAt P0in mIn (R.pf.off 0 + 5) ΦI (R.tr G (s, segs))) dgI _ G
        lg _ hdr core ch rs hrd (hPin s.hdr _)
        (fun k hk => (Iin.hgeomL s.hdr _ k hk).1) (Iin.hgt s.hdr)
        (stgDefAt_of_V U key domain P0in _ mIn _ _ absOf ΦI G lg _ (fun _ => hPin s.hdr _)
          (fun _ => Iin.hgt s.hdr) hDI))
  · exact stg_defs_V U P0out 2 (R.pf.off (Lb + 1) + 2) absOf ΦO dgO lg (R.tr G (s, segs))
      (stg_def_rd U key domain P0out _ 2 _ absOf (stgΦAt P0out 2 (R.pf.off (Lb + 1) + 2) ΦO (R.tr G (s, segs))) dgO _
        G lg _ hdr' core' ch' rs' hrd' (hPout s.hdr s.verdict)
        (fun k hk => (Oout.hgeomL s.hdr s.verdict k hk).1) (Oout.hgt s.hdr s.verdict)
        (stgDefAt_of_V U key domain P0out _ 2 _ _ absOf ΦO G lg _ (fun _ => hPout s.hdr s.verdict)
          (fun _ => Oout.hgt s.hdr s.verdict) hDO))

/-- **`hLU_stg`'s conclusion at the view lists**: both stage parts' head LogUp runs alive. -/
theorem stg_hal_luV
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
    (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn) (absOf : QB Lq → Option (List UInt8)) (eI eO : ℕ)
    (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop) (D : RtKData K Lq)
    (hL0 : D.lu 0 = [stgLkSqV mIn (R.pf.off 0 + 5) eI absOf ΛI])
    (hL1 : D.lu (Lb + 1) = [stgLkSqV 2 (R.pf.off (Lb + 1) + 2) eO absOf ΛO])
    (lg : List (QB Lq × Dig)) (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G) s segs = .ok ())
    (hLI : StgLkAtV U key domain (fun ch => (inc s.hdr).bp (incCtx (inc s.hdr).pub ch)) mIn (R.pf.off 0 + 5)
      (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) absOf ΛI G lg (R.tr G (s, segs)))
    (hLO : StgLkAtV U key domain (fun _ => (outc s.hdr s.verdict).bp) 2 (R.pf.off (Lb + 1) + 2) OutcV.bga absOf ΛO G
      lg (R.tr G (s, segs))) :
    (∀ sx ∈ D.lu 0, subSt W1 (sqSub U sx lg) (R.tr G (s, segs)))
      ∧ (∀ sx ∈ D.lu (Lb + 1), subSt W1 (sqSub U sx lg) (R.tr G (s, segs))) := by
  obtain ⟨⟨hdr, core, ch, rs, hrd⟩, ⟨hdr', core', ch', rs', hrd'⟩⟩ := stg_rds Lb preA preB start inc incG outc outcG
    Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv cx0 pin pout bp wXk gXk mXk hσ Iin Oout mIn hmIn G s
    segs hE
  rw [hL0, hL1]
  refine ⟨fun sx hsx => ?_, fun sx hsx => ?_⟩
  · rw [List.mem_singleton] at hsx
    subst hsx
    exact (stg_lk_V U mIn (R.pf.off 0 + 5) eI absOf ΛI lg (R.tr G (s, segs))).mp
      (stg_lk_rd U key domain _ mIn _ eI absOf (stgΛAt (R.pf.off 0 + 5) ΛI (R.tr G (s, segs))) _ G lg _ hdr core ch rs
        hrd
        (stgLkAt_of_V U key domain _ mIn _ _ absOf ΛI G lg _ hLI))
  · rw [List.mem_singleton] at hsx
    subst hsx
    exact (stg_lk_V U 2 (R.pf.off (Lb + 1) + 2) eO absOf ΛO lg (R.tr G (s, segs))).mp
      (stg_lk_rd U key domain _ 2 _ eO absOf (stgΛAt (R.pf.off (Lb + 1) + 2) ΛO (R.tr G (s, segs))) _ G lg _ hdr' core'
        ch' rs' hrd'
        (stgLkAt_of_V U key domain _ 2 _ _ absOf ΛO G lg _ hLO))

end Hal

/-! ## The doom covers at the view lists -/

section DoomAt

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **A stage's doom at every reading, over the view** (L53's `StgDoomAt` at the view lists): a define draw of a slot
that draws, the head's LogUp run, or a slot starts from a false claim on the stage's own trace before its window. -/
def StgDoomAtV (U : K) (key : Option Dig) (domain : List UInt8) (P0 : Block.BlockParams)
    (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (hostOf : ℕ → List (ℕ × ℕ)) (absOf : QB L → Option (List UInt8))
    (F : StgVw L → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K)
    (Φ : StgVw L → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K)
    (dg : ℕ → ℕ) (e : ℕ) (Λ : StgVw L → List (List UInt8 × K) → Prop)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
    (∃ k ∈ stgDrawing P0, ¬ (stgDefSqV P0 m hdrLen absOf Φ dg k).St Lg
        (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k))) [])
    ∨ ¬ (stgLkSqV m hdrLen e absOf Λ).St Lg
        (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core)) []
    ∨ (∃ k q, core.slots[k]? = some q ∧ ¬ (slotSub U ((stgSlotV P0 m hdrLen hostOf absOf F k).at Lg)
        (stgDefPos P0 m hdrLen k + (P0.draws k + 3))).St
        (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q)) [])

end DoomAt

section Cover

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)

/-- **A STAGE'S VIEW DOOM AT A READING IS A DOOMED ENTRANT OF THE RUN'S KINDS IN THE STAGE'S PART** (L53's
`stg_cover_rd` at the view lists). -/
theorem stg_cover_rdV (n i : ℕ) (hi : i < pf.parts.length) (hin : i < n) (P0 : Block.BlockParams)
    (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (hostOf : ℕ → List (ℕ × ℕ)) (absOf : QB Lq → Option (List UInt8))
    (F : StgVw Lq → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K)
    (Φ : StgVw Lq → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K)
    (dg : ℕ → ℕ) (e : ℕ) (Λ : StgVw Lq → List (List UInt8 × K) → Prop)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) (hdr : List Op) (core : Block.Core)
    (ch : List Fp2) (rs : List Block.SlotRec) (hrd : StgRd key domain Lq Pof m hdrLen bgaOf G τ hdr core ch rs)
    (hP : StgSame P0 (Pof ch)) (hgt : (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hS : D.sls i = stgSchedV P0 m hdrLen hostOf absOf F) (hR : D.r0 i = stgDefsV P0 m hdrLen absOf Φ dg)
    (hLU : D.lu i = [stgLkSqV m hdrLen e absOf Λ])
    (hdoom : StgDoomAtV U key domain P0 Pof m hdrLen bgaOf hostOf absOf F Φ dg e Λ G lg τ) :
    RcSome (rtKo key domain hs Lq hL pf rd hL64 hv U hbij D hD) n lg τ := by
  have hslen : core.slots.length = (Pof ch).geom.slots.length := hrd.2.2.2.1.1
  rcases hdoom hdr core ch rs hrd with ⟨k, hk, hn⟩ | hn | ⟨k, q, hq, hn⟩
  · -- a define draw
    have hkl : k < core.slots.length := by
      rw [hslen, ← hP.2]
      exact List.mem_range.mp (List.mem_filter.mp hk).1
    obtain ⟨q, hq⟩ : ∃ q, core.slots[k]? = some q := ⟨_, List.getElem?_eq_getElem hkl⟩
    obtain ⟨h1, h2⟩ := stg_rd_def key domain Pof m hdrLen bgaOf G τ hdr core ch rs hrd hgt k q hq
    have ha : (stgDefSqV P0 m hdrLen absOf Φ dg k).a = stgDefPos (Pof ch) m hdrLen k := stg_stgDefPos hP m hdrLen k
    refine rd_some_sq key domain hs Lq hL pf rd hL64 hv U hbij D hD n i hi hin lg τ
      (stgDefSqV P0 m hdrLen absOf Φ dg k) (Or.inl ?_) (by rw [ha]; exact h2) ?_
    · rw [hR]
      exact List.mem_map_of_mem hk
    · rw [ha, h1]
      exact hn
  · -- the head's LogUp run
    obtain ⟨h1, h2⟩ := stg_rd_head key domain Pof m hdrLen bgaOf G τ hdr core ch rs hrd
    refine rd_some_sq key domain hs Lq hL pf rd hL64 hv U hbij D hD n i hi hin lg τ
      (stgLkSqV m hdrLen e absOf Λ) (Or.inr (Or.inr (Or.inr (Or.inr ?_)))) h2 ?_
    · rw [hLU]
      exact List.mem_singleton_self _
    · show ¬ (stgLkSqV m hdrLen e absOf Λ).St lg (τ.take (hdrLen + 4)) []
      rw [h1]
      exact hn
  · -- a slot
    have hkl : k < core.slots.length := (List.getElem?_eq_some_iff.mp hq).1
    have hk0 : k < P0.geom.slots.length := by rw [hP.2, ← hslen]; exact hkl
    obtain ⟨h1, h2⟩ := stg_rd_slot key domain Pof m hdrLen bgaOf G τ hdr core ch rs hrd hgt k q hq
    have hsl : (D.sls i)[k]? = some (stgSlotV P0 m hdrLen hostOf absOf F k) := by
      rw [hS]
      exact (stgSchedV_get P0 m hdrLen hostOf absOf F k _).mpr ⟨hk0, rfl⟩
    have hwin : slotsLenX ((D.sls i).take k) + (stgSlotV P0 m hdrLen hostOf absOf F k).s
        = stgDefPos (Pof ch) m hdrLen k + ((Pof ch).draws k + 3) := by
      rw [hS, stgV_win P0 m hdrLen hostOf absOf F k hk0.le, stg_stgDefPos hP, hP.1]
    have hwin0 : stgDefPos P0 m hdrLen k + (P0.draws k + 3)
        = stgDefPos (Pof ch) m hdrLen k + ((Pof ch).draws k + 3) := by
      rw [stg_stgDefPos hP, hP.1]
    refine stg_some_sl key domain hs Lq hL pf rd hL64 hv U hbij D hD n i hi hin lg τ k _ hsl
      (by rw [hwin]; exact h2) ?_
    rw [hwin, h1, ← hwin0]
    exact hn

end Cover

section HalDoom

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

/-- **`hdin`'s and `hdout`'s conclusion at the view lists**, from a stage's view doom at the run's reading: stage
IN-C's at part `0` or stage OUT-C's at part `Lb + 1` gives a doomed entrant of `rtKo` (L53's `stg_hal_doom`). -/
theorem stg_hal_doomV
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
    (FI : StgVw Lq → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0in k) → K) → K)
    (FO : StgVw Lq → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0out k) → K) → K)
    (ΦI : StgVw Lq → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0in.draws k) → K) → K)
    (ΦO : StgVw Lq → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0out.draws k) → K) → K)
    (dgI dgO : ℕ → ℕ) (eI eO : ℕ) (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop)
    (hPin : ∀ hd cx, StgSame P0in ((inc hd).bp cx)) (hPout : ∀ hd v, StgSame P0out (outc hd v).bp)
    (hS0 : D.sls 0 = stgSchedV P0in mIn (R.pf.off 0 + 5) hostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) FI)
    (hR0 : D.r0 0 = stgDefsV P0in mIn (R.pf.off 0 + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΦI dgI)
    (hL0 : D.lu 0 = [stgLkSqV mIn (R.pf.off 0 + 5) eI (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛI])
    (hS1 : D.sls (Lb + 1) = stgSchedV P0out 2 (R.pf.off (Lb + 1) + 2) hostOut
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) FO)
    (hR1 : D.r0 (Lb + 1) = stgDefsV P0out 2 (R.pf.off (Lb + 1) + 2) (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      ΦO dgO)
    (hL1 : D.lu (Lb + 1) = [stgLkSqV 2 (R.pf.off (Lb + 1) + 2) eO (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      ΛO])
    (n : ℕ) (hn : Lb + 2 = n) (lg : List (QB Lq × Dig)) (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G) s segs = .ok ())
    (hdoom : StgDoomAtV U key domain P0in (fun ch => (inc s.hdr).bp (incCtx (inc s.hdr).pub ch)) mIn (R.pf.off 0 + 5)
        (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) hostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) FI ΦI dgI
        eI ΛI G lg (R.tr G (s, segs))
      ∨ StgDoomAtV U key domain P0out (fun _ => (outc s.hdr s.verdict).bp) 2 (R.pf.off (Lb + 1) + 2) OutcV.bga hostOut
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) FO ΦO dgO eO ΛO G lg (R.tr G (s, segs))) :
    RcSome (rtKo key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD) n lg (R.tr G (s, segs)) := by
  have hL2 : R.pf.parts.length = Lb + 2 := RtRun.parts_length R
  obtain ⟨⟨hdr, core, ch, rs, hrd⟩, ⟨hdr', core', ch', rs', hrd'⟩⟩ := stg_rds Lb preA preB start inc incG outc outcG
    Pk sgeom check paths digest bRows bLogN bndCheck bndOpen R hv cx0 pin pout bp wXk gXk mXk hσ Iin Oout mIn hmIn G s
    segs hE
  rcases hdoom with h | h
  · exact stg_cover_rdV key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD n 0 (by omega) (by omega) P0in _ mIn _ _
      hostIn _ FI ΦI dgI eI ΛI G lg _ hdr core ch rs hrd (hPin s.hdr _) (Iin.hgt s.hdr) hS0 hR0 hL0 h
  · exact stg_cover_rdV key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD n (Lb + 1) (by omega) (by omega) P0out _ 2 _
      _ hostOut _ FO ΦO dgO eO ΛO G lg _ hdr' core' ch' rs' hrd' (hPout s.hdr s.verdict) (Oout.hgt s.hdr s.verdict) hS1
      hR1 hL1 h

end HalDoom

end ZK60.ProtocolClassify
