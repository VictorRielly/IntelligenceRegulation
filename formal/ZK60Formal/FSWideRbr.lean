/-
D63, step L3 (soundness): a round-by-round sound protocol with VECTOR challenges, run on the code's chain.

`FSChainRbr.lean` runs a protocol whose rounds are "one message, one squeeze". The code's protocols are not all of
that shape:
* a round's challenge may be several squeezes with no absorb between them (`challenge_fp2_vec`, `challenge_indices`,
  LogUp's `β, γ, α`);
* a round may have no message at all (LogUp's `β, γ` and `α`; the PCS opening's `λ, ρ` follow the statement directly);
* the squeeze counter is the transcript's running count of squeezes: round `i` starts at `ctr w i = Σ_{i' < i} w i'`.
This file is that protocol, on `FSWide.lean`'s steps.

**The protocol** (`n` rounds; round `i` has width `w i ≥ 1` and a message iff `hasMsg i`). The verifier's items
(`pHeadsW` expanded by `pSteps`): the statement; then for each round `i`, the message (if any) and the squeezes
`sq (ctr w i)`, …, `sq (ctr w i + w i − 1)`. The transcript the protocol speaks about records, for each round, the
message (a default `m₀` when the round has none) and the round's `w i` RAW DIGESTS (`List D`); deriving the
challenge from the digests (`challenge_fp2`, the index masks, any packing into a tuple) is the protocol's business,
inside its state function. `rDecodeW` reads a chain back as such a transcript; a chain that leaves the schedule
reads as `none` (doomed).

**Round-by-round soundness with vector challenges** (`RbrWide`): from a doomed transcript of fewer than `n` rounds,
whatever the round's message, a uniform vector of `w i` digests escapes doom with probability at most `ε`. The start
and final conditions are as in `FSRbr.lean`'s `RbrSound`.

**What is proved.**
* `foldl_rStepW_sq`, `foldl_bnd_flatMap`, `foldl_roundHeads`: the reader on a squeeze run, on any chain of whole
  steps (it never stops inside a round), and on the verifier's own chain (exactly `|ms|` rounds).
* `liftStW_round`: the protocol's state lifted to chains satisfies `chain_sound_wide`'s round hypothesis: a message
  step never escapes, a round's squeeze step escapes with the round's `ε`, a step out of the schedule dooms the chain.
* `fs_chain_wide_flip`: the general form, with a state that may read the log (for knowledge soundness).
* `fs_chain_sound_of_rbr_wide`: **soundness on the code's chain**: a false statement is accepted with probability
  at most `T·ε + collBound T D + collBound (T + 1) D`, `T = q + ℓW n w + 1`, `ℓW n w = 1 + Σ_{i<n} (1 + w i)`.
* `prob_vec_comap_le`, `prob_fp2_vec_le`: from the interactive bound to digests. A vector of `k` challenges read
  coordinatewise through a derivation with at most `K` digests per value has the interactive probability times
  `biasFactor K C D ^ k`; for the code's `challenge_fp2`, `(1 + p/2^128)^(2k)`.

**What this does not cover.** The statement is one item (the code's header is several absorbs: only `T` changes).
The counter of round `0` is `0` here; in a block it is the number of squeezes drawn before (a fixed offset, the same
argument). Several protocols composed on one chain are not stated.
-/
import ZK60Formal.FSWide

namespace ZK60.Sound

open scoped ENNReal
open Finset

/-! ## Rounds, widths and the code's squeeze counter -/

section Schedule

/-- **The squeeze counter** at the start of round `i`: the widths of the rounds before it. -/
def ctr (w : ℕ → ℕ) : ℕ → ℕ
  | 0 => 0
  | i + 1 => ctr w i + w i

/-- The counters of the rounds increase strictly. -/
theorem ctr_strictMono {w : ℕ → ℕ} (hw : ∀ i, 0 < w i) : StrictMono (ctr w) :=
  strictMono_nat_of_lt_succ (fun i => by simp only [ctr]; have := hw i; omega)

open Classical in
/-- The width of the step a squeeze with counter `c` starts: round `i`'s width when `c` is round `i`'s first counter (`i < n`), else `1` (a squeeze out of the schedule). -/
noncomputable def sqWidth (n : ℕ) (w : ℕ → ℕ) (c : ℕ) : ℕ :=
  if h : ∃ i, i < n ∧ ctr w i = c then w (Classical.choose h) else 1

/-- Round `i`'s first squeeze starts a step of round `i`'s width. -/
theorem sqWidth_ctr {n : ℕ} {w : ℕ → ℕ} (hw : ∀ i, 0 < w i) {i : ℕ} (hi : i < n) :
    sqWidth n w (ctr w i) = w i := by
  have h : ∃ i', i' < n ∧ ctr w i' = ctr w i := ⟨i, hi, rfl⟩
  rw [sqWidth, dite_eq_left h]
  rw [(ctr_strictMono hw).injective (Classical.choose_spec h).2]

/-- Every step has at least one item. -/
theorem sqWidth_pos {n : ℕ} {w : ℕ → ℕ} (hw : ∀ i, 0 < w i) (c : ℕ) : 0 < sqWidth n w c := by
  unfold sqWidth
  split_ifs
  · exact hw _
  · exact one_pos

/-- A round's counter never starts a step wider than the round. -/
theorem sqWidth_le {n : ℕ} {w : ℕ → ℕ} (hw : ∀ i, 0 < w i) (i : ℕ) : sqWidth n w (ctr w i) ≤ w i := by
  by_cases hi : i < n
  · rw [sqWidth_ctr hw hi]
  · unfold sqWidth
    split_ifs with h
    · exact absurd (by have := (Classical.choose_spec h); rw [(ctr_strictMono hw).injective this.2] at this; exact this.1) hi
    · exact hw i

end Schedule

section Items

variable {X M : Type}

/-- The forced continuation of a squeeze: the next counters. -/
def pCont : PItem X M → ℕ → PItem X M
  | .sq c, j => .sq (c + 1 + j)
  | it, _ => it

/-- The width of a protocol item's step: a squeeze's from the schedule, `1` for the statement and messages. -/
noncomputable def pWd (n : ℕ) (w : ℕ → ℕ) : PItem X M → ℕ
  | .sq c => sqWidth n w c
  | _ => 1

/-- The `j`-th item of a squeeze's step has counter `c + j`. -/
theorem stepItem_sq (c : ℕ) : ∀ j, stepItem (pCont (X := X) (M := M)) (.sq c) j = .sq (c + j)
  | 0 => rfl
  | j + 1 => by
    simp only [stepItem, pCont, PItem.sq.injEq]
    omega

/-- **The protocol's steps**: the statement and each message alone; a round's squeezes together. -/
noncomputable def pSteps (n : ℕ) (w : ℕ → ℕ) (hw : ∀ i, 0 < w i) : Steps (PItem X M) where
  wd := pWd n w
  wd_pos it := by
    cases it with
    | sq c => exact sqWidth_pos hw c
    | stmt x => exact one_pos
    | msg m => exact one_pos
  cont := pCont
  distinct it i j hi hj h := by
    cases it with
    | sq c =>
      rw [stepItem_sq, stepItem_sq, PItem.sq.injEq] at h
      omega
    | stmt x =>
      simp only [pWd] at hi hj
      omega
    | msg m =>
      simp only [pWd] at hi hj
      omega

/-- The items of a squeeze's step. -/
theorem pSteps_items_sq (n : ℕ) (w : ℕ → ℕ) (hw : ∀ i, 0 < w i) (c : ℕ) :
    (pSteps (X := X) (M := M) n w hw).items (.sq c) = (List.range (sqWidth n w c)).map (fun j => .sq (c + j)) := by
  simp only [Steps.items, pSteps, pWd]
  exact List.map_congr_left (fun j _ => stepItem_sq c j)

/-- A message is a step of one item. -/
theorem pSteps_items_msg (n : ℕ) (w : ℕ → ℕ) (hw : ∀ i, 0 < w i) (m : M) :
    (pSteps (X := X) (M := M) n w hw).items (.msg m) = [.msg m] := rfl

/-- The statement is a step of one item. -/
theorem pSteps_items_stmt (n : ℕ) (w : ℕ → ℕ) (hw : ∀ i, 0 < w i) (x : X) :
    (pSteps (X := X) (M := M) n w hw).items (.stmt x) = [.stmt x] := rfl

/-- A squeeze step's entries carry the step's counters and exactly the given digests. -/
theorem pSteps_ents_sq {D : Type} (n : ℕ) (w : ℕ → ℕ) (hw : ∀ i, 0 < w i) (c : ℕ) (ds : List D) :
    ((pSteps (X := X) (M := M) n w hw).ents (.sq c) ds).map Prod.fst
        = (List.range ds.length).map (fun j => .sq (c + j))
      ∧ ((pSteps (X := X) (M := M) n w hw).ents (.sq c) ds).map Prod.snd = ds := by
  have key : ∀ (j : ℕ) (ds : List D), (zipItems (stepItem (pCont (X := X) (M := M)) (.sq c)) j ds).map Prod.fst
      = (List.range ds.length).map (fun i => .sq (c + (j + i)))
      ∧ (zipItems (stepItem (pCont (X := X) (M := M)) (.sq c)) j ds).map Prod.snd = ds := by
    intro j ds
    induction ds generalizing j with
    | nil => simp [zipItems]
    | cons d ds ih =>
      obtain ⟨h1, h2⟩ := ih (j + 1)
      refine ⟨?_, ?_⟩
      · simp only [zipItems, List.map_cons, List.length_cons, List.range_succ_eq_map, List.map_map, h1, stepItem_sq]
        refine congrArg₂ _ (by simp) (List.map_congr_left (fun i _ => ?_))
        simp only [Function.comp, PItem.sq.injEq]
        omega
      · simp [zipItems, h2]
  obtain ⟨h1, h2⟩ := key 0 ds
  show (zipItems (stepItem pCont (PItem.sq c)) 0 ds).map Prod.fst = _
    ∧ (zipItems (stepItem pCont (PItem.sq c)) 0 ds).map Prod.snd = ds
  exact ⟨by simpa using h1, h2⟩

/-- The heads of the rounds from round `i` on: the message if the round has one, then the round's first squeeze. -/
def roundHeads (w : ℕ → ℕ) (hasMsg : ℕ → Bool) : ℕ → List M → List (PItem X M)
  | _, [] => []
  | i, m :: ms => (if hasMsg i then [PItem.msg m] else []) ++ PItem.sq (ctr w i) :: roundHeads w hasMsg (i + 1) ms

/-- **The verifier's heads** for the statement `x` and the messages `ms` (at most `n` rounds). -/
def pHeadsW (n : ℕ) (w : ℕ → ℕ) (hasMsg : ℕ → Bool) (x : X) (ms : List M) : List (PItem X M) :=
  PItem.stmt x :: roundHeads w hasMsg 0 (ms.take n)

end Items

/-! ## Reading a chain back as a transcript of rounds -/

section Reader

variable {X M D : Type}

/-- The reader's state: the transcript so far, the pending message, and the current round's digests so far; `none` once the chain leaves the schedule. -/
abbrev RState (M D : Type) := Option (List (M × List D) × Option M × List D)

/-- **One step of the reader.** A message is held until its round's squeezes (only in a round that has one); a squeeze must carry the round's next counter; the round's last squeeze completes the round with its message (or `m₀`) and its digests; anything else leaves the schedule. -/
def rStepW (n : ℕ) (w : ℕ → ℕ) (hasMsg : ℕ → Bool) (m₀ : M) : RState M D → PItem X M × D → RState M D
  | some (τ, none, []), (.msg m, _) => if τ.length < n ∧ hasMsg τ.length = true then some (τ, some m, []) else none
  | some (τ, pm, ds), (.sq c, d) =>
      if τ.length < n ∧ c = ctr w τ.length + ds.length ∧ hasMsg τ.length = pm.isSome then
        if ds.length + 1 = w τ.length then some (τ ++ [(pm.getD m₀, ds ++ [d])], none, [])
        else some (τ, pm, ds ++ [d])
      else none
  | _, _ => none

/-- **The reader** of the items after the statement. -/
def rDecodeW (n : ℕ) (w : ℕ → ℕ) (hasMsg : ℕ → Bool) (m₀ : M) (τ : List (PItem X M × D)) : RState M D :=
  τ.foldl (rStepW n w hasMsg m₀) (some ([], none, []))

variable {n : ℕ} {w : ℕ → ℕ} {hasMsg : ℕ → Bool} {m₀ : M}

/-- Out of the schedule stays out. -/
theorem rStepW_none (e : PItem X M × D) : rStepW n w hasMsg m₀ none e = none := by
  obtain ⟨it, d⟩ := e
  cases it <;> rfl

/-- Out of the schedule stays out, over any items. -/
theorem foldl_rStepW_none : ∀ es : List (PItem X M × D), es.foldl (rStepW n w hasMsg m₀) none = none
  | [] => rfl
  | e :: es => by
    rw [List.foldl_cons, rStepW_none]
    exact foldl_rStepW_none es

/-- The reader on a squeeze, in every state. -/
theorem rStepW_sq (τ : List (M × List D)) (pm : Option M) (ds : List D) (c : ℕ) (d : D) :
    rStepW (X := X) n w hasMsg m₀ (some (τ, pm, ds)) (.sq c, d)
      = if τ.length < n ∧ c = ctr w τ.length + ds.length ∧ hasMsg τ.length = pm.isSome then
          (if ds.length + 1 = w τ.length then some (τ ++ [(pm.getD m₀, ds ++ [d])], none, [])
          else some (τ, pm, ds ++ [d]))
        else none := by
  cases pm <;> cases ds <;> rfl

/-- **A round's squeeze run** with the right counters completes the round with exactly its digests. -/
theorem foldl_rStepW_sq {ptr : List (M × List D)} {pm : Option M} (hn : ptr.length < n)
    (hm : hasMsg ptr.length = pm.isSome) :
    ∀ (es : List (PItem X M × D)) (ds : List D), es ≠ [] → ds.length + es.length = w ptr.length →
      es.map Prod.fst = (List.range es.length).map (fun j => PItem.sq (ctr w ptr.length + ds.length + j)) →
      es.foldl (rStepW n w hasMsg m₀) (some (ptr, pm, ds))
        = some (ptr ++ [(pm.getD m₀, ds ++ es.map Prod.snd)], none, [])
  | [], _, h, _, _ => absurd rfl h
  | (it1, d1) :: es, ds, _, hlen, hmap => by
    have hit1 : it1 = PItem.sq (ctr w ptr.length + ds.length) := by
      rw [List.map_cons, List.length_cons, List.range_succ_eq_map, List.map_cons] at hmap
      simpa using (List.cons.inj hmap).1
    subst hit1
    rw [List.foldl_cons, rStepW_sq, ite_eq_left ⟨hn, rfl, hm⟩]
    simp only [List.length_cons] at hlen
    by_cases hlast : ds.length + 1 = w ptr.length
    · rw [ite_eq_left hlast]
      have hes : es = [] := List.eq_nil_of_length_eq_zero (by omega)
      subst hes
      simp
    · rw [ite_eq_right hlast]
      have hes : es ≠ [] := fun h => by subst h; simp at hlen; omega
      have hmap' : es.map Prod.fst
          = (List.range es.length).map (fun j => PItem.sq (ctr w ptr.length + (ds ++ [d1]).length + j)) := by
        rw [List.map_cons, List.length_cons, List.range_succ_eq_map, List.map_cons, List.map_map] at hmap
        rw [(List.cons.inj hmap).2]
        refine List.map_congr_left (fun j _ => ?_)
        simp only [Function.comp, List.length_append, List.length_singleton, PItem.sq.injEq]
        omega
      rw [foldl_rStepW_sq hn hm es (ds ++ [d1]) hes (by simp; omega) hmap']
      simp [List.append_assoc]

/-- The reader is between rounds (or out of the schedule): no digests of a round pending. -/
def RBnd (st : RState M D) : Prop := st = none ∨ ∃ ptr pm, st = some (ptr, pm, [])

/-- Reading one whole step keeps the reader between rounds. -/
theorem foldl_step_bnd (hw : ∀ i, 0 < w i) {st : RState M D} (hst : RBnd st) (it : PItem X M)
    (es : List (PItem X M × D)) (hes : es.map Prod.fst = (pSteps n w hw).items it) :
    RBnd (es.foldl (rStepW n w hasMsg m₀) st) := by
  rcases hst with rfl | ⟨ptr, pm, rfl⟩
  · left
    exact foldl_rStepW_none es
  cases it with
  | stmt x =>
    rw [pSteps_items_stmt] at hes
    obtain ⟨⟨it1, d1⟩, rfl⟩ : ∃ e, es = [e] := List.length_eq_one_iff.mp (by simpa using congrArg List.length hes)
    simp only [List.map_cons, List.map_nil, List.cons.injEq, and_true] at hes
    subst hes
    left
    cases pm <;> rfl
  | msg m =>
    rw [pSteps_items_msg] at hes
    obtain ⟨⟨it1, d1⟩, rfl⟩ : ∃ e, es = [e] := List.length_eq_one_iff.mp (by simpa using congrArg List.length hes)
    simp only [List.map_cons, List.map_nil, List.cons.injEq, and_true] at hes
    subst hes
    simp only [List.foldl_cons, List.foldl_nil]
    cases pm with
    | none =>
      show RBnd (if ptr.length < n ∧ hasMsg ptr.length = true then some (ptr, some m, []) else none)
      split_ifs
      · exact Or.inr ⟨ptr, some m, rfl⟩
      · exact Or.inl rfl
    | some m' => exact Or.inl rfl
  | sq c =>
    rw [pSteps_items_sq] at hes
    have hlen : es.length = sqWidth n w c := by simpa using congrArg List.length hes
    by_cases hc : ptr.length < n ∧ c = ctr w ptr.length + ([] : List D).length ∧ hasMsg ptr.length = pm.isSome
    · have hcw : sqWidth n w c = w ptr.length := by
        rw [hc.2.1, List.length_nil, add_zero, sqWidth_ctr hw hc.1]
      have hne : es ≠ [] := fun h => by subst h; have := sqWidth_pos (n := n) hw c; simp at hlen; omega
      rw [foldl_rStepW_sq hc.1 hc.2.2 es [] hne (by simp [hlen, hcw]) (by
        rw [hes, hlen]
        refine List.map_congr_left (fun j _ => ?_)
        rw [hc.2.1])]
      exact Or.inr ⟨_, none, rfl⟩
    · obtain ⟨⟨it1, d1⟩, es', rfl⟩ : ∃ e es', es = e :: es' := by
        cases es with
        | nil => have := sqWidth_pos (n := n) hw c; simp at hlen; omega
        | cons e es' => exact ⟨e, es', rfl⟩
      have hit1 : it1 = PItem.sq c := by
        rw [List.map_cons] at hes
        rw [show sqWidth n w c = (sqWidth n w c - 1) + 1 by have := sqWidth_pos (n := n) hw c; omega,
          List.range_succ_eq_map, List.map_cons] at hes
        simpa using (List.cons.inj hes).1
      subst hit1
      rw [List.foldl_cons, rStepW_sq, ite_eq_right hc, foldl_rStepW_none]
      exact Or.inl rfl

/-- Reading whole steps keeps the reader between rounds: it never stops inside a round's challenge. -/
theorem foldl_bnd_flatMap (hw : ∀ i, 0 < w i) : ∀ (hs : List (PItem X M)) (es : List (PItem X M × D))
    (st : RState M D), RBnd st → es.map Prod.fst = hs.flatMap (pSteps n w hw).items →
    RBnd (es.foldl (rStepW n w hasMsg m₀) st)
  | [], es, st, h, hes => by
    have : es = [] := by simpa using hes
    subst this
    exact h
  | h0 :: hs, es, st, h, hes => by
    rw [List.flatMap_cons] at hes
    set k := ((pSteps (X := X) (M := M) n w hw).items h0).length
    have h1 : (es.take k).map Prod.fst = (pSteps n w hw).items h0 := by
      rw [List.map_take, hes, List.take_left' rfl]
    have h2 : (es.drop k).map Prod.fst = hs.flatMap (pSteps n w hw).items := by
      rw [List.map_drop, hes, List.drop_left' rfl]
    rw [← List.take_append_drop k es, List.foldl_append]
    exact foldl_bnd_flatMap hw hs _ _ (foldl_step_bnd hw h h0 _ h1) h2

/-- **The reader on the verifier's chain**: the items of `|ms|` rounds, with any digests, read as exactly `|ms|` more rounds. -/
theorem foldl_roundHeads (hw : ∀ i, 0 < w i) : ∀ (ms : List M) (i : ℕ) (ptr : List (M × List D))
    (es : List (PItem X M × D)), ptr.length = i → i + ms.length ≤ n →
    es.map Prod.fst = (roundHeads w hasMsg i ms).flatMap (pSteps n w hw).items →
    ∃ ptr', es.foldl (rStepW n w hasMsg m₀) (some (ptr, none, [])) = some (ptr', none, [])
      ∧ ptr'.length = i + ms.length
  | [], i, ptr, es, hp, _, hes => by
    have : es = [] := by simpa [roundHeads] using hes
    subst this
    exact ⟨ptr, rfl, by simp [hp]⟩
  | m :: ms, i, ptr, es, hp, hn, hes => by
    have hi : i < n := by simp at hn; omega
    have hsq := pSteps_items_sq (X := X) (M := M) n w hw (ctr w i)
    rw [sqWidth_ctr hw hi] at hsq
    -- the squeeze run of round `i`, then the rounds after it
    have hsplit : ∀ (es₁ : List (PItem X M × D)) (pm : Option M), hasMsg i = pm.isSome →
        es₁.map Prod.fst = (pSteps n w hw).items (PItem.sq (ctr w i))
          ++ (roundHeads w hasMsg (i + 1) ms).flatMap (pSteps n w hw).items →
        ∃ ptr', es₁.foldl (rStepW n w hasMsg m₀) (some (ptr, pm, [])) = some (ptr', none, [])
          ∧ ptr'.length = i + (m :: ms).length := by
      intro es₁ pm hpm hes₁
      set k := ((pSteps (X := X) (M := M) n w hw).items (PItem.sq (ctr w i))).length with hk
      have hkw : k = w i := by rw [hk, hsq]; simp
      have h1 : (es₁.take k).map Prod.fst = (pSteps n w hw).items (PItem.sq (ctr w i)) := by
        rw [List.map_take, hes₁, List.take_left' rfl]
      have h2 : (es₁.drop k).map Prod.fst = (roundHeads w hasMsg (i + 1) ms).flatMap (pSteps n w hw).items := by
        rw [List.map_drop, hes₁, List.drop_left' rfl]
      have hlen1 : (es₁.take k).length = w i := by
        have := congrArg List.length h1
        rw [List.length_map] at this
        rw [this, ← hk, hkw]
      have hne : es₁.take k ≠ [] := fun h => by rw [h] at hlen1; have := hw i; simp at hlen1; omega
      rw [← List.take_append_drop k es₁, List.foldl_append,
        foldl_rStepW_sq (by rw [hp]; exact hi) (by rw [hp]; exact hpm) (es₁.take k) [] hne
          (by rw [hlen1, hp]; simp)
          (by rw [h1, hsq, hlen1, hp]; simp)]
      obtain ⟨ptr', h3, h4⟩ := foldl_roundHeads hw ms (i + 1)
        (ptr ++ [(pm.getD m₀, [] ++ (es₁.take k).map Prod.snd)]) (es₁.drop k)
        (by simp [hp]) (by simp only [List.length_cons] at hn; omega) h2
      exact ⟨ptr', h3, by rw [h4]; simp; omega⟩
    rw [roundHeads, List.flatMap_append, List.flatMap_cons] at hes
    cases hhm : hasMsg i with
    | false =>
      rw [ite_eq_right (by simp [hhm])] at hes
      simp only [List.flatMap_nil, List.nil_append] at hes
      exact hsplit es none (by simp [hhm]) hes
    | true =>
      rw [ite_eq_left hhm] at hes
      simp only [List.flatMap_cons, List.flatMap_nil, List.append_nil, pSteps_items_msg, List.singleton_append] at hes
      obtain ⟨⟨it1, d1⟩, es₁, rfl⟩ : ∃ e es₁, es = e :: es₁ := by
        cases es with
        | nil => simp at hes
        | cons e es₁ => exact ⟨e, es₁, rfl⟩
      rw [List.map_cons, List.cons.injEq] at hes
      obtain ⟨rfl, hes₁⟩ := hes
      rw [List.foldl_cons]
      have hstep : rStepW (X := X) n w hasMsg m₀ (some (ptr, none, [])) (PItem.msg m, d1)
          = some (ptr, some m, []) := by
        show (if ptr.length < n ∧ hasMsg ptr.length = true then some (ptr, some m, []) else none) = _
        rw [ite_eq_left ⟨by rw [hp]; exact hi, by rw [hp]; exact hhm⟩]
      rw [hstep]
      exact hsplit es₁ (some m) (by simp [hhm]) hes₁

end Reader

/-! ## The protocol on the chain -/

section Lift

variable {X M Q D : Type}

/-- **Round-by-round soundness with vector challenges, at the level of digests**: from a doomed transcript of fewer than `n` rounds, whatever the round's message, a uniform vector of the round's `w i` digests leads out of doom with probability at most `ε`. -/
structure RbrWide [Fintype D] [Nonempty D] (n : ℕ) (w : ℕ → ℕ) (St : X → List (M × List D) → Prop) (ε : ℝ≥0∞) :
    Prop where
  round : ∀ x τ m, τ.length < n → ¬ St x τ →
    (PMF.uniformOfFintype (Fin (w τ.length) → D)).toOuterMeasure {b | St x (τ ++ [(m, List.ofFn b)])} ≤ ε

/-- The protocol's state of a reading of the chain (a reading out of the schedule is doomed). -/
def liftOfW (St : X → List (M × List D) → Prop) (x : X) : RState M D → Prop
  | some (ptr, _, _) => St x ptr
  | none => False

/-- **The protocol's state on chains**: the chain starts with the statement, then the protocol's state of the transcript read off the rest. It may read the log `P`. -/
def liftStW (n : ℕ) (w : ℕ → ℕ) (hasMsg : ℕ → Bool) (m₀ : M) (St : List (Q × D) → X → List (M × List D) → Prop)
    (P : List (Q × D)) : List (PItem X M × D) → Prop
  | (.stmt x, _) :: rest => liftOfW (St P) x (rDecodeW n w hasMsg m₀ rest)
  | _ => False

variable {n : ℕ} {w : ℕ → ℕ} {hasMsg : ℕ → Bool} {m₀ : M}

/-- **The lifted state is round by round, step by step.** From a doomed chain of whole steps, a message step never escapes, the squeeze step of round `i` escapes with probability at most `ε` (`RbrWide.round`), and any other step dooms the chain. -/
theorem liftStW_round [Fintype D] [Nonempty D] (hw : ∀ i, 0 < w i)
    (St : List (Q × D) → X → List (M × List D) → Prop) (ε : ℝ≥0∞) (hR : ∀ P, RbrWide n w (St P) ε)
    (P : List (Q × D)) (τ : List (PItem X M × D)) (it : PItem X M) (hlen : 1 ≤ τ.length)
    (hbd : ∃ hs : List (PItem X M), τ.map Prod.fst = hs.flatMap (pSteps n w hw).items)
    (hns : ¬ liftStW n w hasMsg m₀ St P τ) :
    (PMF.uniformOfFintype (Fin ((pSteps (X := X) (M := M) n w hw).wd it) → D)).toOuterMeasure
        {b | liftStW n w hasMsg m₀ St P (τ ++ (pSteps n w hw).ents it (List.ofFn b))} ≤ ε := by
  have hempty : ∀ (E : Set (Fin ((pSteps (X := X) (M := M) n w hw).wd it) → D)), (∀ b, b ∉ E) →
      (PMF.uniformOfFintype (Fin ((pSteps (X := X) (M := M) n w hw).wd it) → D)).toOuterMeasure E ≤ ε := by
    intro E hE
    have : E = ∅ := Set.eq_empty_iff_forall_notMem.mpr hE
    rw [this, MeasureTheory.measure_empty]
    exact zero_le
  obtain ⟨⟨it0, d0⟩, rest, rfl⟩ : ∃ e rest, τ = e :: rest := by
    cases τ with
    | nil => simp at hlen
    | cons e rest => exact ⟨e, rest, rfl⟩
  cases it0 with
  | msg m0 => exact hempty _ (fun b hb => by simp [liftStW] at hb)
  | sq c0 => exact hempty _ (fun b hb => by simp [liftStW] at hb)
  | stmt x =>
    obtain ⟨hs, hhs⟩ := hbd
    obtain ⟨h0, hs', rfl⟩ : ∃ h0 hs', hs = h0 :: hs' := by
      cases hs with
      | nil => simp at hhs
      | cons h0 hs' => exact ⟨h0, hs', rfl⟩
    obtain ⟨r0, hr0⟩ := (pSteps (X := X) (M := M) n w hw).items_cons h0
    rw [List.map_cons, List.flatMap_cons, hr0, List.cons_append, List.cons.injEq] at hhs
    obtain ⟨rfl, hhs⟩ := hhs
    rw [pSteps_items_stmt, List.cons.injEq] at hr0
    rw [← hr0.2, List.nil_append] at hhs
    have hbnd := foldl_bnd_flatMap (m₀ := m₀) (hasMsg := hasMsg) hw hs' rest (some ([], none, []))
      (Or.inr ⟨[], none, rfl⟩) hhs
    have hstep : ∀ b : Fin ((pSteps (X := X) (M := M) n w hw).wd it) → D,
        liftStW n w hasMsg m₀ St P (((PItem.stmt x, d0) :: rest) ++ (pSteps n w hw).ents it (List.ofFn b))
          = liftOfW (St P) x (((pSteps n w hw).ents it (List.ofFn b)).foldl (rStepW n w hasMsg m₀)
              (rDecodeW n w hasMsg m₀ rest)) := by
      intro b
      rw [List.cons_append, liftStW, rDecodeW, rDecodeW, List.foldl_append]
    simp only [liftStW] at hns
    rcases hbnd with hnone | ⟨ptr, pm, hsome⟩
    · refine hempty _ (fun b hb => ?_)
      rw [Set.mem_ofPred_eq, hstep, rDecodeW, hnone, foldl_rStepW_none] at hb
      exact hb
    · rw [rDecodeW] at hns
      rw [hsome] at hns
      simp only [liftOfW] at hns
      cases it with
      | stmt x' =>
        refine hempty _ (fun b hb => ?_)
        rw [Set.mem_ofPred_eq, hstep, rDecodeW, hsome] at hb
        have hb' : ((pSteps (X := X) (M := M) n w hw).ents (PItem.stmt x') (List.ofFn b))
            = [(PItem.stmt x', b ⟨0, (pSteps (X := X) (M := M) n w hw).wd_pos _⟩)] := rfl
        rw [hb'] at hb
        cases pm <;> exact hb
      | msg m =>
        refine hempty _ (fun b hb => ?_)
        rw [Set.mem_ofPred_eq, hstep, rDecodeW, hsome] at hb
        have hb' : ((pSteps (X := X) (M := M) n w hw).ents (PItem.msg m) (List.ofFn b))
            = [(PItem.msg m, b ⟨0, (pSteps (X := X) (M := M) n w hw).wd_pos _⟩)] := rfl
        rw [hb'] at hb
        cases pm with
        | none =>
          change liftOfW (St P) x (if ptr.length < n ∧ hasMsg ptr.length = true then some (ptr, some m, []) else none)
            at hb
          split_ifs at hb
          · exact hns hb
          · exact hb
        | some m' => exact hb
      | sq c =>
        have hents := fun b : Fin ((pSteps (X := X) (M := M) n w hw).wd (PItem.sq c)) → D =>
          pSteps_ents_sq (X := X) (M := M) n w hw c (List.ofFn b)
        by_cases hc : ptr.length < n ∧ c = ctr w ptr.length + ([] : List D).length ∧ hasMsg ptr.length = pm.isSome
        · have hcw : (pSteps (X := X) (M := M) n w hw).wd (PItem.sq c) = w ptr.length := by
            show sqWidth n w c = w ptr.length
            rw [hc.2.1, List.length_nil, add_zero, sqWidth_ctr hw hc.1]
          have hset : {b : Fin ((pSteps (X := X) (M := M) n w hw).wd (PItem.sq c)) → D |
              liftStW n w hasMsg m₀ St P (((PItem.stmt x, d0) :: rest) ++ (pSteps n w hw).ents (.sq c) (List.ofFn b))}
              = {b | St P x (ptr ++ [(pm.getD m₀, List.ofFn b)])} := by
            ext b
            rw [Set.mem_ofPred_eq, Set.mem_ofPred_eq, hstep, rDecodeW, hsome]
            have hne : (pSteps (X := X) (M := M) n w hw).ents (PItem.sq c) (List.ofFn b) ≠ [] := by
              intro h
              have := congrArg List.length (hents b).2
              rw [h] at this
              simp only [List.map_nil, List.length_nil, List.length_ofFn] at this
              have := (pSteps (X := X) (M := M) n w hw).wd_pos (PItem.sq c)
              omega
            have hlen' : ((pSteps (X := X) (M := M) n w hw).ents (PItem.sq c) (List.ofFn b)).length
                = w ptr.length := by
              have := congrArg List.length (hents b).2
              rw [List.length_map, List.length_ofFn] at this
              rw [this, hcw]
            rw [foldl_rStepW_sq hc.1 hc.2.2 _ [] hne (by rw [List.length_nil, zero_add, hlen'])
              (by rw [(hents b).1, hlen', List.length_ofFn, hcw, hc.2.1]),
              (hents b).2, List.nil_append]
            rfl
          rw [hset, prob_ofFn_congr hcw (fun ds => St P x (ptr ++ [(pm.getD m₀, ds)]))]
          exact (hR P).round x ptr (pm.getD m₀) hc.1 hns
        · refine hempty _ (fun b hb => ?_)
          rw [Set.mem_ofPred_eq, hstep, rDecodeW, hsome] at hb
          obtain ⟨⟨it1, d1⟩, es, hes⟩ : ∃ e es, (pSteps (X := X) (M := M) n w hw).ents (PItem.sq c) (List.ofFn b)
              = e :: es := by
            cases h : (pSteps (X := X) (M := M) n w hw).ents (PItem.sq c) (List.ofFn b) with
            | nil =>
              have := congrArg List.length (hents b).2
              rw [h] at this
              simp only [List.map_nil, List.length_nil, List.length_ofFn] at this
              have := (pSteps (X := X) (M := M) n w hw).wd_pos (PItem.sq c)
              omega
            | cons e es => exact ⟨e, es, rfl⟩
          have hit1 : it1 = PItem.sq c := by
            have h1 := (hents b).1
            rw [hes, List.map_cons, List.length_ofFn,
              show (pSteps (X := X) (M := M) n w hw).wd (PItem.sq c)
                = ((pSteps (X := X) (M := M) n w hw).wd (PItem.sq c) - 1) + 1 by
                  have := (pSteps (X := X) (M := M) n w hw).wd_pos (PItem.sq c); omega,
              List.range_succ_eq_map, List.map_cons] at h1
            simpa using (List.cons.inj h1).1
          rw [hes, hit1, List.foldl_cons, rStepW_sq, ite_eq_right hc, foldl_rStepW_none] at hb
          exact hb

/-- The empty chain asks only the start query. -/
theorem ChainEnc.chain_nil_queries {It : Type} (C : ChainEnc It Q D) (H : Q → D) {τ : List (It × D)}
    {qs : List Q} (h : C.Chain H τ qs) (hτ : τ = []) : qs = [C.start] := by
  cases h with
  | nil => rfl
  | snoc it _ => simp at hτ

/-- A chain's queries include the start query and the link of its first item. -/
theorem ChainEnc.chain_head_mem {It : Type} (C : ChainEnc It Q D) (H : Q → D) {τ : List (It × D)}
    {qs : List Q} (h : C.Chain H τ qs) : ∀ e rest, τ = e :: rest → C.start ∈ qs ∧ C.link (H C.start) e.1 ∈ qs := by
  induction h with
  | nil => intro e rest h; simp at h
  | @snoc τ qs it hc ih =>
    intro e rest he
    rcases τ with _ | ⟨e0, τ0⟩
    · have hq := C.chain_nil_queries H hc rfl
      subst hq
      simp only [List.nil_append, List.cons.injEq] at he
      rw [← he.1]
      simp [ChainEnc.lastD_nil]
    · simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨h1, h2⟩ := ih e τ0 (by rw [he.1])
      exact ⟨List.mem_append_left _ h1, List.mem_append_left _ h2⟩

/-- A bound on the verifier's items: the statement, and per round a message and the round's squeezes. -/
def ℓW (n : ℕ) (w : ℕ → ℕ) : ℕ := 1 + ∑ i ∈ range n, (1 + w i)

/-- The rounds' items number at most one message and the round's width each. -/
theorem roundHeads_length_le (hw : ∀ i, 0 < w i) : ∀ (ms : List M) (i : ℕ),
    ((roundHeads (X := X) w hasMsg i ms).flatMap (pSteps n w hw).items).length
      ≤ ∑ j ∈ range ms.length, (1 + w (i + j))
  | [], _ => by simp [roundHeads]
  | m :: ms, i => by
    rw [roundHeads, List.flatMap_append, List.flatMap_cons, List.length_append, List.length_append,
      List.length_cons, Finset.sum_range_succ']
    have h1 : ((if hasMsg i = true then [PItem.msg (X := X) m] else []).flatMap (pSteps n w hw).items).length
        ≤ 1 := by
      split_ifs <;> simp [pSteps_items_msg]
    have h2 : ((pSteps (X := X) (M := M) n w hw).items (PItem.sq (ctr w i))).length ≤ w i := by
      rw [Steps.items_length]
      exact sqWidth_le hw i
    have h3 := roundHeads_length_le hw ms (i + 1)
    have h4 : ∑ j ∈ range ms.length, (1 + w (i + 1 + j)) = ∑ j ∈ range ms.length, (1 + w (i + (j + 1))) :=
      sum_congr rfl (fun j _ => by rw [Nat.add_assoc, Nat.add_comm 1 j])
    rw [add_zero]
    omega

/-- The verifier hashes at most `ℓW n w` items. -/
theorem pHeadsW_length_le (hw : ∀ i, 0 < w i) (x : X) (ms : List M) :
    ((pHeadsW n w hasMsg x ms).flatMap (pSteps (X := X) (M := M) n w hw).items).length ≤ ℓW n w := by
  rw [pHeadsW, List.flatMap_cons, List.length_append, pSteps_items_stmt, List.length_singleton, ℓW]
  refine Nat.add_le_add_left ((roundHeads_length_le hw (ms.take n) 0).trans ?_) 1
  simp only [zero_add]
  exact sum_le_sum_of_subset (range_subset_range.mpr (by simp))

/-- **The chain verifier**: exactly `n` messages; the chain of the verifier's items is hashed from the start query; the items after the statement read as a transcript (each round's message and digests), and the protocol's verifier accepts it. -/
def chainAcceptsW (n : ℕ) (w : ℕ → ℕ) (hw : ∀ i, 0 < w i) (hasMsg : ℕ → Bool) (m₀ : M) {Mf : Type}
    (accept : X → List (M × List D) → Mf → Prop) (C : ChainEnc (PItem X M) Q D) (H : Q → D) (x : X)
    (ms : List M) (mf : Mf) : Prop :=
  ms.length = n ∧ ∃ ptr, rDecodeW n w hasMsg m₀ ((C.chainFrom H [] ((pHeadsW n w hasMsg x ms).flatMap
    (pSteps n w hw).items)).drop 1) = some (ptr, none, []) ∧ accept x ptr mf

/-- An accepted chain reads as exactly `n` rounds. -/
theorem chainAcceptsW_length (hw : ∀ i, 0 < w i)
    (C : ChainEnc (PItem X M) Q D) (H : Q → D) (x : X) (ms : List M) (ptr : List (M × List D))
    (hlen : ms.length = n)
    (hdec : rDecodeW n w hasMsg m₀ ((C.chainFrom H [] ((pHeadsW n w hasMsg x ms).flatMap
      (pSteps n w hw).items)).drop 1) = some (ptr, none, [])) : ptr.length = n := by
  obtain ⟨ext, hext, hmap⟩ := C.chainFrom_eq_append H ((roundHeads w hasMsg 0 (ms.take n)).flatMap
    (pSteps n w hw).items) [(PItem.stmt x, H (C.link (C.lastD H []) (PItem.stmt x)))]
  have hfull : C.chainFrom H [] ((pHeadsW n w hasMsg x ms).flatMap (pSteps n w hw).items)
      = (PItem.stmt x, H (C.link (C.lastD H []) (PItem.stmt x))) :: ext := by
    rw [pHeadsW, List.flatMap_cons, pSteps_items_stmt, List.singleton_append, ChainEnc.chainFrom,
      List.nil_append, hext, List.singleton_append]
  rw [hfull, List.drop_one, List.tail_cons] at hdec
  obtain ⟨ptr', h1, h2⟩ := foldl_roundHeads (m₀ := m₀) hw (ms.take n) 0 [] ext rfl
    (by simp [List.length_take]) hmap
  rw [rDecodeW, h1] at hdec
  cases hdec
  rw [h2, zero_add, List.length_take, hlen, min_self]

variable [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D]

/-- **The protocol on the chain, the general form.** For a state that may read the log (stable once the statement's link is logged) and is round-by-round sound with vector challenges for every log: a prover making at most `q` hash queries gets a doomed statement and a chain that reads as a transcript the state does not doom with probability at most `T·ε + collBound T D + collBound (T + 1) D`, `T = q + ℓW n w + 1`. -/
theorem fs_chain_wide_flip (hw : ∀ i, 0 < w i) (C : ChainEnc (PItem X M) Q D)
    (St : List (Q × D) → X → List (M × List D) → Prop) (ε : ℝ≥0∞) (hR : ∀ P, RbrWide n w (St P) ε)
    (hstab : ∀ (H : Q → D) (P P' : List (Q × D)) (x : X) (τ : List (M × List D)), C.start ∈ P.map Prod.fst →
      C.link (H C.start) (PItem.stmt x) ∈ P.map Prod.fst → P <+: P' → (∀ e ∈ P', e.2 = H e.1) →
        (St P x τ ↔ St P' x τ))
    {Mf : Type} (q : ℕ) (A : OC Q D (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H =>
        ¬ St ((C.stepRun (pSteps n w hw) (fun o => pHeadsW n w hasMsg o.1 o.2.1) A).runLog H).2 (A.run H).1 []
        ∧ ∃ ptr pm, rDecodeW n w hasMsg m₀ ((C.chainFrom H []
            ((pHeadsW n w hasMsg (A.run H).1 (A.run H).2.1).flatMap (pSteps n w hw).items)).drop 1)
              = some (ptr, pm, [])
          ∧ St ((C.stepRun (pSteps n w hw) (fun o => pHeadsW n w hasMsg o.1 o.2.1) A).runLog H).2 (A.run H).1 ptr)
      ≤ ((q + ℓW n w + 1 : ℕ) : ℝ≥0∞) * ε + collBound (q + ℓW n w + 1) D
        + collBound (q + ℓW n w + 1 + 1) D := by
  have hstab' : ∀ (H : Q → D) (P P' : List (Q × D)) (τ : List (PItem X M × D)) (qs : List Q)
      (ext : List (PItem X M × D)), C.Chain H τ qs → 1 ≤ τ.length → (∀ y ∈ qs, y ∈ P.map Prod.fst) →
        P <+: P' → (∀ e ∈ P', e.2 = H e.1) →
          (liftStW n w hasMsg m₀ St P (τ ++ ext) ↔ liftStW n w hasMsg m₀ St P' (τ ++ ext)) := by
    intro H P P' τ qs ext hc hlen hqs hpre hL
    obtain ⟨⟨it0, d0⟩, rest, rfl⟩ : ∃ e rest, τ = e :: rest := by
      cases τ with
      | nil => simp at hlen
      | cons e rest => exact ⟨e, rest, rfl⟩
    obtain ⟨h1, h2⟩ := C.chain_head_mem H hc _ rest rfl
    cases it0 with
    | stmt x =>
      rw [List.cons_append, liftStW, liftStW]
      rcases rDecodeW n w hasMsg m₀ (rest ++ ext) with _ | ⟨ptr, pm, ds⟩
      · exact Iff.rfl
      · exact hstab H P P' x ptr (hqs _ h1) (hqs _ h2) hpre hL
    | msg m => simp [liftStW]
    | sq c => simp [liftStW]
  refine le_trans (MeasureTheory.measure_mono ?_)
    (chain_sound_wide C (pSteps n w hw) (liftStW n w hasMsg m₀ St) 1 ε
      (fun P τ it h1 h2 h3 => liftStW_round hw St ε hR P τ it h1 h2 h3) hstab'
      (fun o => pHeadsW n w hasMsg o.1 o.2.1) (ℓW n w) (fun o => pHeadsW_length_le hw _ _) q A hA)
  rintro H ⟨hns, ptr, pm, hdec, hst⟩
  set L := ((C.stepRun (pSteps n w hw) (fun o => pHeadsW n w hasMsg o.1 o.2.1) A).runLog H).2
  set x := (A.run H).1
  obtain ⟨ext, hext, -⟩ := C.chainFrom_eq_append H ((roundHeads w hasMsg 0 ((A.run H).2.1.take n)).flatMap
    (pSteps n w hw).items) [(PItem.stmt x, H (C.link (C.lastD H []) (PItem.stmt x)))]
  have hfull : C.chainFrom H [] ((pHeadsW n w hasMsg x (A.run H).2.1).flatMap (pSteps n w hw).items)
      = (PItem.stmt x, H (C.link (C.lastD H []) (PItem.stmt x))) :: ext := by
    rw [pHeadsW, List.flatMap_cons, pSteps_items_stmt, List.singleton_append, ChainEnc.chainFrom,
      List.nil_append, hext, List.singleton_append]
  constructor
  · show ¬ liftStW n w hasMsg m₀ St L (C.chainFrom H [] (((pHeadsW n w hasMsg x (A.run H).2.1).take 1).flatMap
      (pSteps n w hw).items))
    rw [pHeadsW, List.take_succ_cons, List.take_zero, List.flatMap_cons, List.flatMap_nil, List.append_nil,
      pSteps_items_stmt, ChainEnc.chainFrom, ChainEnc.chainFrom, List.nil_append, liftStW]
    exact hns
  · show liftStW n w hasMsg m₀ St L (C.chainFrom H [] ((pHeadsW n w hasMsg x (A.run H).2.1).flatMap
      (pSteps n w hw).items))
    rw [hfull, liftStW]
    rw [hfull, List.drop_one, List.tail_cons] at hdec
    rw [hdec]
    exact hst

/-- **Fiat–Shamir soundness with vector challenges on the code's chain.** A protocol that is round-by-round sound with vector challenges (`RbrWide`, plus the start and final conditions), run on the chain with its rounds' widths, messages and counters, accepts a false statement from a prover making at most `q` hash queries with probability at most `T·ε + collBound T D + collBound (T + 1) D`, `T = q + ℓW n w + 1`. -/
theorem fs_chain_sound_of_rbr_wide (hw : ∀ i, 0 < w i) (C : ChainEnc (PItem X M) Q D) {Mf : Type}
    {L : X → Prop} {accept : X → List (M × List D) → Mf → Prop} {St : X → List (M × List D) → Prop}
    (ε : ℝ≥0∞) (hR : RbrWide n w St ε) (hstart : ∀ x, ¬ L x → ¬ St x [])
    (hfinal : ∀ x τ mf, τ.length = n → ¬ St x τ → ¬ accept x τ mf)
    (q : ℕ) (A : OC Q D (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1
        ∧ chainAcceptsW n w hw hasMsg m₀ accept C H (A.run H).1 (A.run H).2.1 (A.run H).2.2)
      ≤ ((q + ℓW n w + 1 : ℕ) : ℝ≥0∞) * ε + collBound (q + ℓW n w + 1) D
        + collBound (q + ℓW n w + 1 + 1) D := by
  refine le_trans (MeasureTheory.measure_mono ?_)
    (fs_chain_wide_flip (hasMsg := hasMsg) (m₀ := m₀) hw C (fun _ => St) ε (fun _ => hR)
      (fun _ _ _ _ _ _ _ _ _ => Iff.rfl) q A hA)
  rintro H ⟨hL, hlen, ptr, hdec, hacc⟩
  refine ⟨hstart _ hL, ptr, none, hdec, ?_⟩
  have hn := chainAcceptsW_length hw C H _ _ ptr hlen hdec
  by_contra hns
  exact hfinal _ _ _ hn hns hacc

end Lift

/-! ## From the interactive bound to digests -/

section Bias

variable {D : Type} [Fintype D] [Nonempty D]

/-- **A vector challenge through a derivation.** If each challenge value has at most `K` digest preimages, a vector of `k` digests, read coordinatewise, lands in a set with at most the uniform probability times `biasFactor K C D ^ k`. -/
theorem prob_vec_comap_le {C : Type} [Fintype C] [Nonempty C] [DecidableEq C] (chal : D → C) (K : ℕ)
    (hK : ∀ c, (univ.filter (fun d : D => chal d = c)).card ≤ K) (k : ℕ) (S : (Fin k → C) → Prop) :
    (PMF.uniformOfFintype (Fin k → D)).toOuterMeasure {b | S (fun j => chal (b j))}
      ≤ (PMF.uniformOfFintype (Fin k → C)).toOuterMeasure {c | S c} * biasFactor K C D ^ k := by
  classical
  have hcount : (univ.filter (fun b : Fin k → D => S (fun j => chal (b j)))).card ≤ (univ.filter S).card * K ^ k := by
    have hsub : univ.filter (fun b : Fin k → D => S (fun j => chal (b j))) ⊆ (univ.filter S).biUnion
        (fun c => Fintype.piFinset (fun j => univ.filter (fun d : D => chal d = c j))) := by
      intro b hb
      simp only [mem_filter, mem_univ, true_and] at hb
      refine mem_biUnion.mpr ⟨fun j => chal (b j), mem_filter.mpr ⟨mem_univ _, hb⟩, ?_⟩
      rw [Fintype.mem_piFinset]
      intro j
      simp
    refine (card_le_card hsub).trans (card_biUnion_le.trans ?_)
    calc ∑ c ∈ univ.filter S, (Fintype.piFinset (fun j => univ.filter (fun d : D => chal d = c j))).card
        ≤ ∑ _c ∈ univ.filter S, K ^ k := by
          refine sum_le_sum (fun c _ => ?_)
          rw [Fintype.card_piFinset]
          calc ∏ j, (univ.filter (fun d : D => chal d = c j)).card ≤ K ^ (univ : Finset (Fin k)).card :=
                Finset.prod_le_pow_card _ _ _ (fun j _ => hK (c j))
            _ = K ^ k := by rw [card_univ, Fintype.card_fin]
      _ = (univ.filter S).card * K ^ k := by rw [sum_const, smul_eq_mul]
  calc (PMF.uniformOfFintype (Fin k → D)).toOuterMeasure {b | S (fun j => chal (b j))}
      ≤ (((univ.filter S).card * K ^ k : ℕ) : ℝ≥0∞) / Fintype.card (Fin k → D) :=
        prob_le_of_card_filter _ _ hcount
    _ = ((univ.filter S).card : ℝ≥0∞) / Fintype.card (Fin k → C) * biasFactor (K ^ k) (Fin k → C) (Fin k → D) :=
        div_card_eq_mul_bias _ _
    _ = _ := by
        rw [prob_uniform_eq_card S]
        congr 1
        simp only [biasFactor, Fintype.card_fun, Fintype.card_fin, Nat.cast_pow]
        rw [ennreal_div_pow, mul_pow]

/-- For `challenge_fp2`, the bias of `k` coordinates is at most `(1 + p/N)^(2k)`. -/
theorem biasFactor_fp2_pow_le {F : Type} [Fintype F] (N p : ℕ) [NeZero N] (hF : Fintype.card F = p ^ 2) (k : ℕ) :
    biasFactor ((N / p + 1) ^ 2) F (Fin N × Fin N) ^ k ≤ (1 + (p : ℝ≥0∞) / N) ^ (2 * k) := by
  rw [pow_mul]
  gcongr
  exact biasFactor_fp2_le N p hF

/-- **The code's `challenge_fp2_vec`**: `k` squeezes, each read as an `Fp2` element, land in a set with at most its uniform probability times `(1 + p/2^128)^(2k)`. -/
theorem prob_fp2_vec_le {F : Type} [Fintype F] [Nonempty F] [DecidableEq F] (p : ℕ) [NeZero p] (ι : ZMod p × ZMod p ≃ F)
    (k : ℕ) (S : (Fin k → F) → Prop) :
    (PMF.uniformOfFintype (Fin k → Fin (2 ^ 128) × Fin (2 ^ 128))).toOuterMeasure
        {b | S (fun j => fp2Field p (2 ^ 128) ι (b j))}
      ≤ (PMF.uniformOfFintype (Fin k → F)).toOuterMeasure {c | S c}
        * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * k) := by
  have hF : Fintype.card F = p ^ 2 := by
    rw [← Fintype.card_congr ι, Fintype.card_prod, ZMod.card, sq]
  refine (prob_vec_comap_le (fp2Field p (2 ^ 128) ι) ((2 ^ 128 / p + 1) ^ 2)
    (card_fp2Field_fiber_le (2 ^ 128) p ι) k S).trans ?_
  exact mul_le_mul' le_rfl (biasFactor_fp2_pow_le (2 ^ 128) p hF k)

/-- Repacking a uniform draw through an equivalence keeps it uniform. -/
theorem prob_equiv_comp {α β : Type} [Fintype α] [Nonempty α] [Fintype β] [Nonempty β] (e : α ≃ β)
    (S : β → Prop) :
    (PMF.uniformOfFintype α).toOuterMeasure {a | S (e a)} = (PMF.uniformOfFintype β).toOuterMeasure {b | S b} := by
  rw [← Hiding.map_uniform_equiv e, PMF.toOuterMeasure_map_apply]
  rfl

end Bias

end ZK60.Sound
