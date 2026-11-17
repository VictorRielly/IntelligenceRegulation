/-
D63 lane L63 (2026-11-17), part 34: **a stage define polynomial at slot `0` that does not vanish everywhere, at every
reading, is the stage's view doom** (`StgDoomAtV`'s first disjunct; `hdzW`, third piece).

At a reading, slot `0`'s define draw reads what `define` saw (`stg_tHistS_trace` at `k = 0`: the head's challenges, no
earlier draws); its state before any challenge is `Φ ≡ 0` (`szSt_nil`). So a point where `Φ` is non-zero means the
draw entered doomed.

* **`ssh_doomAtV_of_def0`**.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldDzPhi

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

section Doom

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **A NON-VANISHING DEFINE POLYNOMIAL AT SLOT `0` IS STAGE DOOM.** -/
theorem ssh_doomAtV_of_def0 (U : K) (key : Option Dig) (domain : List UInt8) (P0 : Block.BlockParams)
    (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (hostOf : ℕ → List (ℕ × ℕ)) (absOf : QB L → Option (List UInt8))
    (F : StgVw L → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K)
    (Φ : StgVw L → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K)
    (dg : ℕ → ℕ) (e : ℕ) (Λ : StgVw L → List (List UInt8 × K) → Prop)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (hP : ∀ ch, StgSame P0 (Pof ch))
    (hgeom : ∀ ch k, k < (Pof ch).geom.slots.length → 1 ≤ (Block.slotShape (Pof ch) k).2.2)
    (hgt : ∀ ch, (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (h0 : 0 ∈ stgDrawing P0)
    (hne : ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
      ∃ y, Φ (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 []))) 0 (ch, []) y ≠ 0) :
    StgDoomAtV U key domain P0 Pof m hdrLen bgaOf hostOf absOf F Φ dg e Λ G Lg τ := by
  intro hdr core ch rs hrd
  left
  refine ⟨0, h0, ?_⟩
  obtain ⟨y, hy⟩ := hne hdr core ch rs hrd
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
        ⟨_, List.getElem?_eq_getElem (by rw [← hgt ch]; omega)⟩
      have := (hsh.2 i q s tt hq hs' htt).1
      rw [this, Block.slotShape, List.getD_eq_getElem?_getD, hs', Option.getD_some]
    have hd1 : ∀ i, i < core.slots.length → 1 ≤ (Block.slotShape (Pof ch) (0 + i)).2.2 := fun i hi => by
      rw [Nat.zero_add]
      exact hgeom ch i (by omega)
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
    have hhist := stg_tHistS_trace (liftH G) (Pof ch) m core hdr (Tr.newKeyed (liftH G) domain key) 0
      (Nat.zero_le _) hround rs (by omega) hv
    intro hSt
    have hS : szSt (Φ (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 []))) 0 (ch, []))
        ([] : List (List UInt8 × K)) := by
      have e0 : core.slots.take 0 = [] := List.take_zero
      change (match tHistS P0 hdrLen m 0 (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take 0))) with
        | some (hh, _) => szSt (Φ (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
            (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take 0)))) 0 hh) []
        | none => True) at hSt
      rw [stg_tHistS (hP ch), ← hhl, hhist, hch] at hSt
      simpa [e0] using hSt
    exact hy ((szSt_nil _).mp hS y)
  · cases hacc

end Doom

end ZK60.ProtocolClassify
