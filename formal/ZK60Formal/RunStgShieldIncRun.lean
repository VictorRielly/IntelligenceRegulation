/-
D63 lane L63 (2026-11-18), part 52: **what "no doomed R0 / slot entrant" gives at a stage's reading** (item 4b of
HANDOFF_20261118_1.md, the run-level half; generic in the stage).

At a reading of a stage whose part `i` lists are the stage's (`D.r0 i = stgDefsV …`, `D.sls i = stgSchedV …`):
* **`stg_r0Dm_of_def`**: a define draw of a drawing slot whose state is false at its window is a doomed entrant of
  `rtKR0` (the kind itself, not only `RcSome` of the cover); **`stg_defAlive_of_notR0`**, its contrapositive;
* **`stg_slDm_of_slot`**: a slot whose start claim is false is a doomed entrant of `rtKsl`;
  **`stg_slAlive_of_notSl`**, its contrapositive;
* **`stg_def_zero_of_alive`**: an alive define draw at slot `k` means its polynomial vanishes EVERYWHERE, at the view
  of the trace before the draw and the history `(ch, the earlier slots' draws)` (L21's state before the draw is
  Schwartz–Zippel's `Φ ≡ 0`; `ssh_doomAtV_of_def0` at every `k`).

These are the first step of `hLI_stg` (and `hLO_stg`): with `sshΦIC` at SIC_QZC / SIC_TZC the vanishing everywhere is
what gives `QzcHolds` / `TzcHolds` (not done here; see HANDOFF_20261118_2.md).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldDzDoom

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## 1. Doomed entrants of the two kinds, and the alive forms -/

section Kinds

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)

/-- **A false define state at a reading is a doomed entrant of `rtKR0`.** -/
theorem stg_r0Dm_of_def (n i : ℕ) (hi : i < pf.parts.length) (hin : i < n) (P0 : Block.BlockParams)
    (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (absOf : QB Lq → Option (List UInt8))
    (Φ : StgVw Lq → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K) (dg : ℕ → ℕ)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) (hdr : List Op) (core : Block.Core)
    (ch : List Fp2) (rs : List Block.SlotRec) (hrd : StgRd key domain Lq Pof m hdrLen bgaOf G τ hdr core ch rs)
    (hP : StgSame P0 (Pof ch)) (hgt : (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hR : D.r0 i = stgDefsV P0 m hdrLen absOf Φ dg) (k : ℕ) (hk : k ∈ stgDrawing P0)
    (hn : ¬ (stgDefSqV P0 m hdrLen absOf Φ dg k).St lg
        (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k))) []) :
    (rtKR0 key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ := by
  have hslen : core.slots.length = (Pof ch).geom.slots.length := hrd.2.2.2.1.1
  have hkl : k < core.slots.length := by
    rw [hslen, ← hP.2]
    exact List.mem_range.mp (List.mem_filter.mp hk).1
  obtain ⟨q, hq⟩ : ∃ q, core.slots[k]? = some q := ⟨_, List.getElem?_eq_getElem hkl⟩
  obtain ⟨h1, h2⟩ := stg_rd_def key domain Pof m hdrLen bgaOf G τ hdr core ch rs hrd hgt k q hq
  have ha : (stgDefSqV P0 m hdrLen absOf Φ dg k).a = stgDefPos (Pof ch) m hdrLen k := stg_stgDefPos hP m hdrLen k
  refine ⟨i, hin, sqSub U (stgDefSqV P0 m hdrLen absOf Φ dg k) lg, ?_,
    rd_entD_sq Lq U _ lg τ (by rw [ha]; exact h2) (by rw [ha, h1]; exact hn)⟩
  show sqSub U (stgDefSqV P0 m hdrLen absOf Φ dg k) lg
    ∈ (rtKsq key domain hs Lq hL pf rd hL64 hv U hbij 80 (80 * 451) D.r0 hD.r0).cs i lg
  rw [rd_ksq_cs key domain hs Lq hL pf rd hL64 hv U hbij _ _ _ _ i hi]
  refine List.mem_map_of_mem ?_
  rw [hR]
  exact List.mem_map_of_mem hk

/-- **No doomed `rtKR0` entrant: every drawing slot's define state is alive at the reading.** -/
theorem stg_defAlive_of_notR0 (n i : ℕ) (hi : i < pf.parts.length) (hin : i < n) (P0 : Block.BlockParams)
    (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (absOf : QB Lq → Option (List UInt8))
    (Φ : StgVw Lq → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K) (dg : ℕ → ℕ)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) (hdr : List Op) (core : Block.Core)
    (ch : List Fp2) (rs : List Block.SlotRec) (hrd : StgRd key domain Lq Pof m hdrLen bgaOf G τ hdr core ch rs)
    (hP : StgSame P0 (Pof ch)) (hgt : (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hR : D.r0 i = stgDefsV P0 m hdrLen absOf Φ dg)
    (hno : ¬ (rtKR0 key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ) (k : ℕ) (hk : k ∈ stgDrawing P0) :
    (stgDefSqV P0 m hdrLen absOf Φ dg k).St lg
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k))) [] := by
  by_contra hn
  exact hno (stg_r0Dm_of_def key domain hs Lq hL pf rd hL64 hv U hbij D hD n i hi hin P0 Pof m hdrLen bgaOf absOf Φ dg
    G lg τ hdr core ch rs hrd hP hgt hR k hk hn)

/-- **A false slot start claim at a reading is a doomed entrant of `rtKsl`.** -/
theorem stg_slDm_of_slot (n i : ℕ) (hi : i < pf.parts.length) (hin : i < n) (P0 : Block.BlockParams)
    (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (hostOf : ℕ → List (ℕ × ℕ)) (absOf : QB Lq → Option (List UInt8))
    (F : StgVw Lq → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) (hdr : List Op) (core : Block.Core)
    (ch : List Fp2) (rs : List Block.SlotRec) (hrd : StgRd key domain Lq Pof m hdrLen bgaOf G τ hdr core ch rs)
    (hP : StgSame P0 (Pof ch)) (hgt : (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hS : D.sls i = stgSchedV P0 m hdrLen hostOf absOf F) (k : ℕ) (q : Block.SlotProof)
    (hq : core.slots[k]? = some q)
    (hn : ¬ (slotSub U ((stgSlotV P0 m hdrLen hostOf absOf F k).at lg)
        (stgDefPos P0 m hdrLen k + (P0.draws k + 3))).St
        (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q)) []) :
    (rtKsl key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ := by
  have hslen : core.slots.length = (Pof ch).geom.slots.length := hrd.2.2.2.1.1
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
  have ha : slotsLenX ((D.sls i).take k) + (stgSlotV P0 m hdrLen hostOf absOf F k).s ≤ τ.length := by
    rw [hwin]; exact h2
  have hn' : ¬ (slotSub U ((stgSlotV P0 m hdrLen hostOf absOf F k).at lg)
      (slotsLenX ((D.sls i).take k) + (stgSlotV P0 m hdrLen hostOf absOf F k).s)).St
      (τ.take (slotsLenX ((D.sls i).take k) + (stgSlotV P0 m hdrLen hostOf absOf F k).s)) [] := by
    rw [hwin, h1, ← hwin0]
    exact hn
  have hmem : slotSub U ((stgSlotV P0 m hdrLen hostOf absOf F k).at lg)
      (slotsLenX ((D.sls i).take k) + (stgSlotV P0 m hdrLen hostOf absOf F k).s)
      ∈ (rtKsl key domain hs Lq hL pf rd hL64 hv U hbij D hD).cs i lg := by
    rw [ra_ksl_cs key domain hs Lq hL pf rd hL64 hv U hbij D hD i hi]
    exact List.mem_of_getElem? (by rw [rt_slotSubs_getElem?, hsl]; rfl)
  exact ⟨i, hin, _, hmem, ha, tRem_W1 _, hn'⟩

/-- **No doomed `rtKsl` entrant: every slot's start claim is alive at the reading.** -/
theorem stg_slAlive_of_notSl (n i : ℕ) (hi : i < pf.parts.length) (hin : i < n) (P0 : Block.BlockParams)
    (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (hostOf : ℕ → List (ℕ × ℕ)) (absOf : QB Lq → Option (List UInt8))
    (F : StgVw Lq → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) (hdr : List Op) (core : Block.Core)
    (ch : List Fp2) (rs : List Block.SlotRec) (hrd : StgRd key domain Lq Pof m hdrLen bgaOf G τ hdr core ch rs)
    (hP : StgSame P0 (Pof ch)) (hgt : (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hS : D.sls i = stgSchedV P0 m hdrLen hostOf absOf F)
    (hno : ¬ (rtKsl key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ) (k : ℕ) (q : Block.SlotProof)
    (hq : core.slots[k]? = some q) :
    (slotSub U ((stgSlotV P0 m hdrLen hostOf absOf F k).at lg)
        (stgDefPos P0 m hdrLen k + (P0.draws k + 3))).St
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
          ++ Block.slotPreOps (Pof ch) k q)) [] := by
  by_contra hn
  exact hno (stg_slDm_of_slot key domain hs Lq hL pf rd hL64 hv U hbij D hD n i hi hin P0 Pof m hdrLen bgaOf hostOf
    absOf F G lg τ hdr core ch rs hrd hP hgt hS k q hq hn)

end Kinds

/-! ## 2. An alive define state is `Φ ≡ 0` -/

section Zero

variable {K : Type} [Field K] {L : ℕ}

/-- **AN ALIVE DEFINE DRAW VANISHES EVERYWHERE**: at a reading, slot `k`'s define state on the trace before its draw is
`Φ ≡ 0` at the view there, the head's challenges and the earlier slots' draws. -/
theorem stg_def_zero_of_alive (key : Option Dig) (domain : List UInt8) (P0 : Block.BlockParams)
    (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (absOf : QB L → Option (List UInt8))
    (Φ : StgVw L → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K) (dg : ℕ → ℕ)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) (hdr : List Op) (core : Block.Core)
    (ch : List Fp2) (rs : List Block.SlotRec) (hrd : StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs)
    (hP : StgSame P0 (Pof ch))
    (hgeom : ∀ k, k < (Pof ch).geom.slots.length → 1 ≤ (Block.slotShape (Pof ch) k).2.2)
    (hgt : (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (k : ℕ) (hk : k ≤ core.slots.length)
    (hal : (stgDefSqV P0 m hdrLen absOf Φ dg k).St Lg
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k))) []) :
    ∀ y, Φ (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)))) k
      (ch, (rs.take k).map Block.SlotRec.draws) y = 0 := by
  obtain ⟨hhl, -, -, hsh, ⟨acc, t', hacc⟩, -⟩ := hrd
  have hslen : core.slots.length = (Pof ch).geom.slots.length := hsh.1
  rw [StageFS.stageSlots_eq] at hacc
  simp only [← runOps_append] at hacc
  split at hacc
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at hacc
    obtain ⟨hch, hres⟩ := hacc
    subst hres
    have hround : ∀ i q, core.slots[i]? = some q →
        q.rounds.length = (Block.slotShape (Pof ch) i).1 + (Block.slotShape (Pof ch) i).2.1 := by
      intro i q hq
      have hi : i < (Pof ch).geom.slots.length := by rw [← hslen]; exact (List.getElem?_eq_some_iff.mp hq).1
      obtain ⟨s, hs'⟩ : ∃ s, (Pof ch).geom.slots[i]? = some s := ⟨_, List.getElem?_eq_getElem hi⟩
      obtain ⟨tt, htt⟩ : ∃ tt, (Pof ch).geom.terms[i]? = some tt :=
        ⟨_, List.getElem?_eq_getElem (by rw [← hgt]; omega)⟩
      have := (hsh.2 i q s tt hq hs' htt).1
      rw [this, Block.slotShape, List.getD_eq_getElem?_getD, hs', Option.getD_some]
    have hd1 : ∀ i, i < core.slots.length → 1 ≤ (Block.slotShape (Pof ch) (0 + i)).2.2 := fun i hi => by
      rw [Nat.zero_add]
      exact hgeom i (by omega)
    obtain ⟨rs', hrs', hlen, hall⟩ := Block.slotsLoop_ok (liftH G) (Pof ch) _ _ _ core.slots [] 0 {} _ rs acc t' hd1 hloop
    simp only [List.nil_append] at hrs'
    subst hrs'
    have hv : ∀ i q r, core.slots[i]? = some q → rs[i]? = some r →
        r.draws = (Block.preVals (liftH G) (Pof ch) (Block.slotTr (liftH G) (Pof ch) (runOps (liftH G)
          (Tr.newKeyed (liftH G) domain key) (hdr ++ StageFS.stageRootOps (Pof ch) core m)) 0 core.slots i) i q).1 := by
      intro i q r hq hr
      have h1 := congrArg Prod.fst (hall i q r hq hr).1
      rw [Nat.zero_add] at h1
      exact h1
    have hhist := stg_tHistS_trace (liftH G) (Pof ch) m core hdr (Tr.newKeyed (liftH G) domain key) k
      hk hround rs (by omega) hv
    change (match tHistS P0 hdrLen m k (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k))) with
      | some (hh, _) => szSt (Φ (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)))) k hh) []
      | none => True) at hal
    rw [stg_tHistS hP, ← hhl, hhist, hch] at hal
    exact (szSt_nil _).mp hal
  · cases hacc

end Zero

end ZK60.ProtocolClassify
