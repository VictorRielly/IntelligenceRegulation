/-
D63 lane L27 (2026-11-07), part 1: **L24-2's weak stability premise at the escaping step, for every reader of the
prover's log that reads it through the cuts at the roots its header absorbs.**

L24's first-doom count (`fs_code_chain_first_log`, `FirstKind.hstab`) asks the state of a kind's schedule to agree at
two logs: the log before the escaping step's first query (`L.take t`) and the whole log (`L`), on the chain before that
step and the step's own entries. L24-2 noted that the strong form (every extension) fails for a schedule over several
blocks, and that the weak form holds for the cut-at-first-absorption extraction "because a root absorbed by the
escaping step's own query is cut at that query in both logs". This file proves it:

* `cutAt_self_of_none`, `cutAt_append_cons`, **`cutAt_proverLog_esc`**: if the log's entry `t` absorbs `r`, the PROVER's
  log (recovered by replay) cut at `r`'s first absorption is the same whether the log is cut before entry `t` or not
  (either `r` was absorbed before `t`, L16's `cutAt_proverLog_stable`, or entry `t` is the first absorption and both
  cuts stop exactly there);
* `CutEq`, `absAt_take`, `cutEq_take`: two logs cut alike at every root a chain prefix absorbs, and its prefixes;
* `zipItems_getElem?`, `stepItem_kind`, `absAt_ents`: a step's entries absorb at most the step's head item's bytes
  (the continuation of a step is the head again or a squeeze, `StepCont`; `stepsB_cont`: the code's `stepsB`);
* **`cutEq_esc`**: in the context of `FirstKind.hstab` (the chain `τ` before the escaping step logged before `t`, the
  log's entry `t` the step's first query), the two logs `proverLog A (L.take t)` and `proverLog A L` cut alike at every
  root that any prefix of `τ ++ ext` absorbs, for `ext` empty or the step's entries with ANY digests: positions inside
  `τ` by L16's `cutO_stable`, the step's head by `cutAt_proverLog_esc`, its continuation absorbs nothing new.

So every sub-protocol whose state reads the prover's log only through such cuts (the slots' tables, the define draws'
and LogUp's data, `M`'s rows and the openings' columns: all of L16, L20, L21, L22's extractions) meets L24-2's weak
stability (`RunChainSched.lean` turns it into `FirstKind.hstab`). Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunExtractKinds

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Sound

/-! ## The cut at the escaping step's own absorption -/

section Esc

variable {Q D β : Type} [DecidableEq β]

/-- A log with no absorption of `r` is its own cut. -/
theorem cutAt_self_of_none (absOf : Q → Option β) (r : β) (P : List (Q × D)) (h : ∀ e ∈ P, absOf e.1 ≠ some r) :
    cutAt absOf r P = P := by
  unfold cutAt
  have h1 : P.findIdx (isAbsAt absOf r) = P.length :=
    List.findIdx_eq_length.mpr (fun e he => by simp [isAbsAt, h e he])
  rw [h1, List.take_length]

/-- A log whose first absorption of `r` is the entry right after `P` is cut at `P`. -/
theorem cutAt_append_cons (absOf : Q → Option β) (r : β) (P R : List (Q × D)) (e : Q × D)
    (h : ∀ e' ∈ P, absOf e'.1 ≠ some r) (he : absOf e.1 = some r) : cutAt absOf r (P ++ e :: R) = P := by
  unfold cutAt
  have h1 : P.findIdx (isAbsAt absOf r) = P.length :=
    List.findIdx_eq_length.mpr (fun e' he' => by simp [isAbsAt, h e' he'])
  have h2 : (e :: R).findIdx (isAbsAt absOf r) = 0 := by
    rw [List.findIdx_cons]
    simp [isAbsAt, he]
  rw [List.findIdx_append, h1, ite_eq_right (lt_irrefl _), h2, Nat.zero_add, List.take_left' rfl]

/-- The escaping-step cut, the case with no earlier absorption: the log before the step's absorbing entry and any
log continuing with that entry give the prover's log the same cut. -/
theorem cutAt_proverLog_esc_aux {γ : Type} (A : OC Q D γ) (absOf : Q → Option β) (r : β) (P R : List (Q × D))
    (e : Q × D) (he : absOf e.1 = some r) (hP : ∀ e' ∈ P, absOf e'.1 ≠ some r) :
    cutAt absOf r (proverLog A P) = cutAt absOf r (proverLog A (P ++ e :: R)) := by
  rcases hr : A.replay P with _ | r0
  · have h1 : proverLog A P = P := by simp [proverLog, hr]
    rw [h1, cutAt_self_of_none absOf r P hP]
    rcases hr' : A.replay (P ++ e :: R) with _ | r'
    · have h2 : proverLog A (P ++ e :: R) = P ++ e :: R := by simp [proverLog, hr']
      rw [h2, cutAt_append_cons absOf r P R e hP he]
    · have hlt := ZK60.OC.replay_none_lt A P (e :: R) r' hr hr'
      obtain ⟨n, hn⟩ : ∃ n, r'.2 - P.length = n + 1 := ⟨r'.2 - P.length - 1, by omega⟩
      have h2 : proverLog A (P ++ e :: R) = P ++ e :: R.take n := by
        simp only [proverLog, hr']
        rw [List.take_append, List.take_of_length_le hlt.le, hn, List.take_succ_cons]
      rw [h2, cutAt_append_cons absOf r P _ e hP he]
  · have h1 := ZK60.OC.replay_append_of_some A P (e :: R) r0 hr
    have h2 : proverLog A (P ++ e :: R) = proverLog A P := by
      simp only [proverLog, h1, hr]
      exact List.take_append_of_le_length (ZK60.OC.replay_le_length A P r0 hr)
    rw [h2]

/-- **The cut at the escaping step's own absorption is the same at both logs** (finding L24-2's weak stability): if
the log's entry `t` absorbs `r`, the prover's log cut at `r`'s first absorption is the same for the log cut before `t`
and for the whole log. -/
theorem cutAt_proverLog_esc {γ : Type} (A : OC Q D γ) (absOf : Q → Option β) (r : β) (L : List (Q × D)) (t : ℕ)
    (e : Q × D) (ht : L[t]? = some e) (he : absOf e.1 = some r) :
    cutAt absOf r (proverLog A (L.take t)) = cutAt absOf r (proverLog A L) := by
  by_cases hP : ∃ e' ∈ L.take t, absOf e'.1 = some r
  · exact (cutAt_proverLog_stable A absOf r (L.take t) L (List.take_prefix t L) hP).symm
  · have hP' : ∀ e' ∈ L.take t, absOf e'.1 ≠ some r := fun e' he' h => hP ⟨e', he', h⟩
    have htl : t < L.length := (List.getElem?_eq_some_iff.mp ht).1
    have hdrop : L.drop t = e :: L.drop (t + 1) := by
      rw [List.drop_eq_getElem_cons htl]
      congr 1
      exact Option.some.inj ((List.getElem?_eq_getElem htl).symm.trans ht)
    have hL : L.take t ++ e :: L.drop (t + 1) = L := by
      rw [← hdrop, List.take_append_drop]
    have h := cutAt_proverLog_esc_aux A absOf r (L.take t) (L.drop (t + 1)) e he hP'
    rw [hL] at h
    exact h

end Esc

/-! ## Two logs cut alike at the roots a chain prefix absorbs -/

section CutEq

variable {Q : Type}

/-- **Two logs cut alike at every root the chain prefix `τ` absorbs** (at every position). -/
def CutEq (absOf : Q → Option (List UInt8)) (τ : List (TItem × Dig)) (P P' : List (Q × Dig)) : Prop :=
  ∀ i, Exec.Block.cutO absOf (Exec.Block.absAt τ i) P = Exec.Block.cutO absOf (Exec.Block.absAt τ i) P'

/-- A prefix absorbs what the chain absorbs before its end. -/
theorem absAt_take (τ : List (TItem × Dig)) (a i : ℕ) :
    Exec.Block.absAt (τ.take a) i = if i < a then Exec.Block.absAt τ i else none := by
  unfold Exec.Block.absAt
  rw [List.getElem?_take]
  split_ifs <;> rfl

/-- Cut alike at a chain, cut alike at its prefixes. -/
theorem cutEq_take (absOf : Q → Option (List UInt8)) (τ : List (TItem × Dig)) (P P' : List (Q × Dig))
    (h : CutEq absOf τ P P') (a : ℕ) : CutEq absOf (τ.take a) P P' := by
  intro i
  rw [absAt_take]
  split_ifs
  · exact h i
  · rfl

/-- Cut alike at a chain, cut alike at any prefix of it. -/
theorem cutEq_of_prefix (absOf : Q → Option (List UInt8)) (τ τ' : List (TItem × Dig)) (P P' : List (Q × Dig))
    (h : CutEq absOf τ P P') (hp : τ' <+: τ) : CutEq absOf τ' P P' := by
  rw [List.prefix_iff_eq_take.mp hp]
  exact cutEq_take absOf τ P P' h _

end CutEq

/-! ## A step's entries absorb only its head's bytes -/

section StepAbs

variable {L : ℕ}

/-- **A step's continuation is its head again or a squeeze** (the code's steps: an absorb is a step of one item, a
squeeze of `k` starts a run of squeezes; `stepsB_cont`). -/
def StepCont (S : Steps (ItB L)) : Prop :=
  ∀ (it : ItB L) (j : ℕ), (S.cont it j).1 = it.1 ∨ ∃ k, (S.cont it j).1 = TItem.squeeze k

/-- The code's steps (`stepsB`) continue an absorb with itself and a squeeze with squeezes. -/
theorem stepsB_cont (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) (hW64 : ∀ k, W k ≤ 2 ^ 64) :
    StepCont (stepsB L W hW hW64) := by
  intro it j
  obtain ⟨t, ht⟩ := it
  cases t with
  | absorb l x => exact Or.inl rfl
  | squeeze k => exact Or.inr ⟨k + 1 + UInt64.ofNat j, rfl⟩

theorem zipItems_getElem? {It D : Type} (f : ℕ → It) :
    ∀ (j0 : ℕ) (ds : List D) (j : ℕ), (zipItems f j0 ds)[j]? = ds[j]?.map (fun d => (f (j0 + j), d))
  | j0, [], j => by simp [zipItems]
  | j0, d :: ds, 0 => by simp [zipItems]
  | j0, d :: ds, j + 1 => by
    simp only [zipItems, List.getElem?_cons_succ]
    rw [zipItems_getElem? f (j0 + 1) ds j, show j0 + 1 + j = j0 + (j + 1) by omega]

theorem stepItem_kind (S : Steps (ItB L)) (hcont : StepCont S) (it : ItB L) :
    ∀ j, (stepItem S.cont it j).1 = it.1 ∨ ∃ k, (stepItem S.cont it j).1 = TItem.squeeze k
  | 0 => Or.inl rfl
  | j + 1 => hcont it j

/-- What an entry absorbs depends only on that entry. -/
theorem absAt_eq_single (l : List (TItem × Dig)) (j : ℕ) (e : TItem × Dig) (h : l[j]? = some e) :
    Exec.Block.absAt l j = Exec.Block.absAt [e] 0 := by
  unfold Exec.Block.absAt
  rw [h]
  rfl

theorem absAt_none (l : List (TItem × Dig)) (j : ℕ) (h : l[j]? = none) : Exec.Block.absAt l j = none := by
  unfold Exec.Block.absAt
  rw [h]

theorem absAt_single (x : TItem) (d : Dig) :
    Exec.Block.absAt [(x, d)] 0 = none ∨ ∃ lab y, x = TItem.absorb lab y ∧ Exec.Block.absAt [(x, d)] 0 = some y := by
  cases x with
  | absorb lab y => exact Or.inr ⟨lab, y, rfl, rfl⟩
  | squeeze k => exact Or.inl rfl

/-- A step's entries, as code items: entry `j` is the step's `j`-th item with the `j`-th digest. -/
theorem ents_map_getElem? (S : Steps (ItB L)) (it : ItB L) (ds : List Dig) (j : ℕ) :
    ((S.ents it ds).map (toTE (fun it : ItB L => it.1)))[j]? = ds[j]?.map (fun d => ((stepItem S.cont it j).1, d)) := by
  rw [List.getElem?_map, Steps.ents, zipItems_getElem?, Option.map_map, Nat.zero_add]
  rfl

/-- **A step's entries absorb at most the head's bytes**: at any position, nothing, or the head is an absorb of `x` and
the entry absorbs `x`. -/
theorem absAt_ents (S : Steps (ItB L)) (hcont : StepCont S) (it : ItB L) (ds : List Dig) (j : ℕ) :
    Exec.Block.absAt ((S.ents it ds).map (toTE (fun it : ItB L => it.1))) j = none
      ∨ ∃ lab x, it.1 = TItem.absorb lab x
        ∧ Exec.Block.absAt ((S.ents it ds).map (toTE (fun it : ItB L => it.1))) j = some x := by
  rcases hd : ds[j]? with _ | d
  · exact Or.inl (absAt_none _ _ (by rw [ents_map_getElem?, hd]; rfl))
  · rw [absAt_eq_single _ j ((stepItem S.cont it j).1, d) (by rw [ents_map_getElem?, hd]; rfl)]
    rcases stepItem_kind S hcont it j with h | ⟨k, h⟩
    · rw [h]
      exact absAt_single it.1 d
    · rw [h]
      exact Or.inl rfl

end StepAbs

/-! ## The escaping step: the two logs cut alike on the step's chain -/

section EscChain

variable {L : ℕ} {Q : Type}

/-- **L24-2's weak stability for cut readers** (the context of `FirstKind.hstab`): the chain `τ` before the escaping
step is logged before `t` and the log's entry `t` is the step's first query `link (lastD τ) it`. Then the prover's log
recovered from `L.take t` and from `L` are cut alike at every root that any prefix of `τ ++ ext` absorbs, for `ext`
empty or the step's entries with any digests. -/
theorem cutEq_esc (C : ChainEnc (ItB L) Q Dig) (S : Steps (ItB L)) (hcont : StepCont S) {γ : Type} (A : OC Q Dig γ)
    (H : Q → Dig) (Lg : List (Q × Dig)) (t : ℕ) (τ : List (ItB L × Dig)) (qs : List Q) (it : ItB L) (e2 : Dig)
    (hc : C.Chain H τ qs) (hq : ∀ z ∈ qs, z ∈ (Lg.take t).map Prod.fst)
    (ht : Lg[t]? = some (C.link (C.lastD H τ) it, e2))
    (ext : List (ItB L × Dig)) (hext : ext = [] ∨ ∃ ds, ext = S.ents it ds)
    (τ' : List (TItem × Dig)) (hτ' : τ' <+: (τ ++ ext).map (toTE (fun it : ItB L => it.1))) :
    CutEq (Exec.Block.absOfC C) τ' (proverLog A (Lg.take t)) (proverLog A Lg) := by
  refine cutEq_of_prefix _ _ τ' _ _ (fun i => ?_) hτ'
  rw [List.map_append]
  by_cases hi : i < (τ.map (toTE (fun it : ItB L => it.1))).length
  · have e1 : Exec.Block.absAt (τ.map (toTE (fun it : ItB L => it.1)) ++ ext.map (toTE (fun it : ItB L => it.1))) i
        = Exec.Block.absAt (τ.map Exec.entB) i := by
      unfold Exec.Block.absAt
      rw [List.getElem?_append_left hi]
      rfl
    rw [e1]
    exact Exec.Block.cutO_stable C H τ qs hc (Lg.take t) Lg hq (List.take_prefix t Lg) A i
  · have e1 : Exec.Block.absAt (τ.map (toTE (fun it : ItB L => it.1)) ++ ext.map (toTE (fun it : ItB L => it.1))) i
        = Exec.Block.absAt (ext.map (toTE (fun it : ItB L => it.1)))
          (i - (τ.map (toTE (fun it : ItB L => it.1))).length) := by
      unfold Exec.Block.absAt
      rw [List.getElem?_append_right (not_lt.mp hi)]
    rw [e1]
    rcases hext with rfl | ⟨ds, rfl⟩
    · rfl
    · rcases absAt_ents S hcont it ds (i - (τ.map (toTE (fun it : ItB L => it.1))).length) with h0 | ⟨lab, x, hx, h1⟩
      · rw [h0]
        rfl
      · rw [h1]
        exact cutAt_proverLog_esc A (Exec.Block.absOfC C) x Lg t _ ht
          (Exec.Block.absOfC_link C (C.lastD H τ) it lab x hx)

end EscChain

end ZK60.ProtocolClassify
