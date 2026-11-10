/-
D63 lane L57 (2026-11-10), part 2: **the stage lists with polynomials that SEE THE HEADER** (finding L57-1; deliverable
1's precondition).

**Finding L57-1.** Lane L53's stage lists hand a stage slot's polynomial `F`, a define draw's polynomial `Φ` and the
head's LogUp state `Λ` ONLY the cuts the header shows (`stgCuts absOf Lg τ`: at each header position, the prover's log
cut before the first absorption of what the header absorbs there). A cut stops BEFORE the root it is cut at, so the root
is not in it; and every extraction of a committed table reads the root as well as the cut (L22's `colX` reads
`rootAt hdr i`; L36's `csXof` reads `cuts3` AND `rootsAt`; the blocks' `Fsl k` takes `Cuts3 Lq → RootsO → …`). With
L53's types no `F`, `Φ`, `Λ` can be the stage's polynomials over the EXTRACTED tables: two prover logs with the same
cut and different committed roots (a prover that builds two trees and absorbs one root) are the same input. Nor can
they read the statement's public data (`Win`, the header's `expected-IO` and `public-statement` absorbs), which the
stages' `define`s read (`IncPub`: the template, the embedding fold; `OutcPub`: the margin vector, the verdict).

**The repair, here.** New list builders with the same windows, degrees, rounds and claims, whose polynomials and state
read the VIEW `stgVw absOf Lg τ = (stgCuts absOf Lg τ, τ)`: the cuts AND the header itself (the trace before the
entry's window). The header does not read the log, so the view is still a cut reader (`stgVw_cut`), the one side
condition `hD` asks. L53's lists are the instances that ignore the header (`stgSlotX_V`, `stgSchedX_V`, `stgDefSq_V`,
`stgDefs_V`, `stgLkSq_V`: definitional), so nothing L53 proved is lost.

* `StgVw`, `stgVw`, **`stgVw_cut`**;
* `stgSlotV`, `stgSchedV`, `stgDefSqV`, `stgDefsV`, `stgLkSqV`: the lists' entries, as L53's with the view;
* `stgSlotV_cut`, `stgDefSqV_cut`, `stgLkSqV_cut`, **`stgDefSqV_rbr`**: `hD`'s side conditions that do not depend on
  the polynomials (define draws round-by-round from their degree in the draws);
* `stgSchedV_get`, **`stgV_win`**: slot `k` and its window (`slotsLenX` form) = define window + `draws k + 3`;
* `stgSlotX_V` … `stgLkSq_V`: L53's lists are the view lists that ignore the header.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgList

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

section Vw

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **What a stage list entry's polynomial or state sees at its window**: the cuts the header shows at every position,
and the header (the trace before the window) itself. -/
abbrev StgVw (L : ℕ) : Type := (ℕ → List (QB L × Dig)) × List (TItem × Dig)

/-- The view of the log `Lg` at the header `hdr`. -/
def stgVw (absOf : QB L → Option (List UInt8)) (Lg : List (QB L × Dig)) (hdr : List (TItem × Dig)) : StgVw L :=
  (stgCuts absOf Lg hdr, hdr)

/-- **The view reads the log only through the cuts the header shows** (the header does not read the log). -/
theorem stgVw_cut (absOf : QB L → Option (List UInt8)) : CutReads absOf (stgVw absOf) := by
  intro P P' hdr h
  show (stgCuts absOf P hdr, hdr) = (stgCuts absOf P' hdr, hdr)
  rw [stgCuts_cutEq h]

/-- **Stage slot `k` with a polynomial over the view**: L53's `stgSlotX` (the window `stgS`, the stage's degree and
rounds, the verifier's claimed sum `stgClaim`) with `F` reading the cuts AND the header. -/
def stgSlotV (P : Block.BlockParams) (m hdrLen : ℕ) (hostOf : ℕ → List (ℕ × ℕ)) (absOf : QB L → Option (List UInt8))
    (F : StgVw L → (k : ℕ) → StageFS.SeenS → (Fin (stgN P k) → K) → K) (k : ℕ) : SlotX K L where
  s := stgS P m hdrLen k
  d := (Block.slotShape P k).2.2
  n := stgN P k
  stmt Lg τ :=
    match StageFS.tSeenS P hdrLen m k τ with
    | some (sn, _) => (F (stgVw absOf Lg τ) k sn, stgClaim hostOf k sn)
    | none => (fun _ => 0, Fp2.zero)

/-- **The stage's slots over the view**: one per slot of the schedule, in order. -/
def stgSchedV (P : Block.BlockParams) (m hdrLen : ℕ) (hostOf : ℕ → List (ℕ × ℕ)) (absOf : QB L → Option (List UInt8))
    (F : StgVw L → (k : ℕ) → StageFS.SeenS → (Fin (stgN P k) → K) → K) : List (SlotX K L) :=
  (List.range P.geom.slots.length).map (stgSlotV P m hdrLen hostOf absOf F)

/-- **Stage slot `k`'s define draws over the view**: L53's `stgDefSq` with `Φ` reading the cuts AND the header. -/
def stgDefSqV (P : Block.BlockParams) (m hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : StgVw L → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P.draws k) → K) → K)
    (dg : ℕ → ℕ) (k : ℕ) : SqX K L where
  a := stgDefPos P m hdrLen k
  n := P.draws k
  e := dg k
  St Lg hdr τ :=
    match tHistS P hdrLen m k hdr with
    | some (h, _) => szSt (Φ (stgVw absOf Lg hdr) k h) τ
    | none => True

/-- **The stage's define draws over the view**: one per slot that draws. -/
def stgDefsV (P : Block.BlockParams) (m hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : StgVw L → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P.draws k) → K) → K)
    (dg : ℕ → ℕ) : List (SqX K L) :=
  (stgDrawing P).map (stgDefSqV P m hdrLen absOf Φ dg)

/-- **The stage's head as its LogUp run over the view**: L53's `stgLkSq` with `Λ` reading the cuts AND the header. -/
def stgLkSqV (m hdrLen e : ℕ) (absOf : QB L → Option (List UInt8))
    (Λ : StgVw L → List (List UInt8 × K) → Prop) : SqX K L where
  a := hdrLen + 4
  n := m
  e := e
  St Lg hdr τ := Λ (stgVw absOf Lg hdr) τ

/-! ### Their side conditions that do not depend on the polynomials -/

omit [Algebra GF K] in
theorem stgSlotV_cut (P : Block.BlockParams) (m hdrLen : ℕ) (hostOf : ℕ → List (ℕ × ℕ))
    (absOf : QB L → Option (List UInt8))
    (F : StgVw L → (k : ℕ) → StageFS.SeenS → (Fin (stgN P k) → K) → K) (k : ℕ) :
    CutReads absOf (stgSlotV P m hdrLen hostOf absOf F k).stmt := by
  intro P1 P2 hdr h
  show (match StageFS.tSeenS P hdrLen m k hdr with
    | some (sn, _) => (F (stgVw absOf P1 hdr) k sn, stgClaim hostOf k sn)
    | none => (fun _ => 0, Fp2.zero)) = (match StageFS.tSeenS P hdrLen m k hdr with
    | some (sn, _) => (F (stgVw absOf P2 hdr) k sn, stgClaim hostOf k sn)
    | none => (fun _ => 0, Fp2.zero))
  rw [stgVw_cut absOf P1 P2 hdr h]

omit [Algebra GF K] in
theorem stgDefSqV_cut (P : Block.BlockParams) (m hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : StgVw L → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P.draws k) → K) → K)
    (dg : ℕ → ℕ) (k : ℕ) : SqCut absOf (stgDefSqV P m hdrLen absOf Φ dg k) := by
  intro P1 P2 hdr h τr
  show (match tHistS P hdrLen m k hdr with
    | some (hh, _) => szSt (Φ (stgVw absOf P1 hdr) k hh) τr
    | none => True) ↔ (match tHistS P hdrLen m k hdr with
    | some (hh, _) => szSt (Φ (stgVw absOf P2 hdr) k hh) τr
    | none => True)
  rw [stgVw_cut absOf P1 P2 hdr h]

omit [Field K] [Algebra GF K] in
theorem stgLkSqV_cut (m hdrLen e : ℕ) (absOf : QB L → Option (List UInt8))
    (Λ : StgVw L → List (List UInt8 × K) → Prop) : SqCut absOf (stgLkSqV m hdrLen e absOf Λ) := by
  intro P1 P2 hdr h τr
  show Λ (stgVw absOf P1 hdr) τr ↔ Λ (stgVw absOf P2 hdr) τr
  rw [stgVw_cut absOf P1 P2 hdr h]

omit [Algebra GF K] in
/-- **A stage define draw over the view is round-by-round sound** (Schwartz–Zippel's, from its degree in the draws). -/
theorem stgDefSqV_rbr [Fintype K] [DecidableEq K] (P : Block.BlockParams) (m hdrLen : ℕ)
    (absOf : QB L → Option (List UInt8))
    (Φ : StgVw L → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P.draws k) → K) → K)
    (dg : ℕ → ℕ) (k : ℕ) (hdeg : ∀ v h, IndDegLE (dg k) (Φ v k h)) : (stgDefSqV P m hdrLen absOf Φ dg k).Rbr := by
  intro Lg hdr τ mg hτ hns
  simp only [stgDefSqV] at hns ⊢
  split at hns
  · exact szSt_escape _ (hdeg _ _) τ mg hτ hns
  · exact absurd trivial hns

/-! ### The slots' windows -/

omit [Algebra GF K] in
theorem stgSchedV_get (P : Block.BlockParams) (m hdrLen : ℕ) (hostOf : ℕ → List (ℕ × ℕ))
    (absOf : QB L → Option (List UInt8))
    (F : StgVw L → (k : ℕ) → StageFS.SeenS → (Fin (stgN P k) → K) → K) (k : ℕ) (sl : SlotX K L) :
    (stgSchedV P m hdrLen hostOf absOf F)[k]? = some sl ↔
      k < P.geom.slots.length ∧ sl = stgSlotV P m hdrLen hostOf absOf F k := by
  simp only [stgSchedV, List.getElem?_map]
  constructor
  · intro h
    obtain ⟨k', hk', rfl⟩ := Option.map_eq_some_iff.mp h
    obtain ⟨hlt, hget⟩ := List.getElem?_eq_some_iff.mp hk'
    rw [List.getElem_range] at hget
    subst hget
    exact ⟨by simpa using hlt, rfl⟩
  · rintro ⟨hk, rfl⟩
    rw [List.getElem?_range hk]
    rfl

omit [Algebra GF K] in
/-- **Stage slot `k`'s window in the kinds data** is its define draws' window plus `draws k + 3`. -/
theorem stgV_win (P : Block.BlockParams) (m hdrLen : ℕ) (hostOf : ℕ → List (ℕ × ℕ))
    (absOf : QB L → Option (List UInt8))
    (F : StgVw L → (k : ℕ) → StageFS.SeenS → (Fin (stgN P k) → K) → K) (k : ℕ)
    (hk : k ≤ P.geom.slots.length) :
    slotsLenX ((stgSchedV P m hdrLen hostOf absOf F).take k) + (stgSlotV P m hdrLen hostOf absOf F k).s
      = stgDefPos P m hdrLen k + (P.draws k + 3) := by
  have htake : (stgSchedV P m hdrLen hostOf absOf F).take k
      = (List.range k).map (stgSlotV P m hdrLen hostOf absOf F) := by
    rw [stgSchedV, ← List.map_take, List.take_range, min_eq_left hk]
  rw [htake, ← stg_len_win P m hdrLen k]
  simp only [slotsLenX, List.map_map, stgLen]
  rfl

/-! ### L53's lists are the view lists that ignore the header -/

omit [Algebra GF K] in
theorem stgSlotX_V (P : Block.BlockParams) (m hdrLen : ℕ) (hostOf : ℕ → List (ℕ × ℕ))
    (absOf : QB L → Option (List UInt8))
    (F : (ℕ → List (QB L × Dig)) → (k : ℕ) → StageFS.SeenS → (Fin (stgN P k) → K) → K) (k : ℕ) :
    stgSlotX P m hdrLen hostOf absOf F k = stgSlotV P m hdrLen hostOf absOf (fun v => F v.1) k := rfl

omit [Algebra GF K] in
theorem stgSchedX_V (P : Block.BlockParams) (m hdrLen : ℕ) (hostOf : ℕ → List (ℕ × ℕ))
    (absOf : QB L → Option (List UInt8))
    (F : (ℕ → List (QB L × Dig)) → (k : ℕ) → StageFS.SeenS → (Fin (stgN P k) → K) → K) :
    stgSchedX P m hdrLen hostOf absOf F = stgSchedV P m hdrLen hostOf absOf (fun v => F v.1) := rfl

omit [Algebra GF K] in
theorem stgDefSq_V (P : Block.BlockParams) (m hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : (ℕ → List (QB L × Dig)) → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P.draws k) → K) → K)
    (dg : ℕ → ℕ) (k : ℕ) :
    stgDefSq P m hdrLen absOf Φ dg k = stgDefSqV P m hdrLen absOf (fun v => Φ v.1) dg k := rfl

omit [Algebra GF K] in
theorem stgDefs_V (P : Block.BlockParams) (m hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : (ℕ → List (QB L × Dig)) → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P.draws k) → K) → K)
    (dg : ℕ → ℕ) : stgDefs P m hdrLen absOf Φ dg = stgDefsV P m hdrLen absOf (fun v => Φ v.1) dg := rfl

omit [Field K] [Algebra GF K] in
theorem stgLkSq_V (m hdrLen e : ℕ) (absOf : QB L → Option (List UInt8))
    (Λ : (ℕ → List (QB L × Dig)) → List (List UInt8 × K) → Prop) :
    stgLkSq m hdrLen e absOf Λ = stgLkSqV m hdrLen e absOf (fun v => Λ v.1) := rfl

end Vw

end ZK60.ProtocolClassify
