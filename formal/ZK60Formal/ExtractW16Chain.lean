/-
D63 lane L16 (2026-11-07), part 1: **the KNOWLEDGE version of L8's composition on the code's chain**, where the
sub-protocols' states may read data EXTRACTED from the prover's hash log.

L8's `fs_code_chain_sound_sched` (`ExecComposeFS.lean`) composes sub-protocols on the code's transcript chain, each with
a state that is a function of the chain (its header and its own rounds). That is the SOUNDNESS version: the committed
tables a slot's polynomial or an opening's claims are about must be named by the statement. The knowledge version
(ASSEMBLY §4.2 item a, finding L10-6 (a)) needs states that read the committed tables EXTRACTED from the prover's log,
as `FSOpening.lean` does for one opening on a model chain. `FSWide.lean`'s `chain_sound_wide` already allows a state
that reads the log, provided it is frozen once the chain's queries are logged; this file carries that to L8's schedule
on the code's chain.

* `chain_take`, `chain_link_mem`: a prefix of a chain is a chain with a prefix of its queries; entry `i`'s link query is
  among the chain's queries (so a logged chain logs every root it absorbs).
* `cutAt`, `cutAt_append`, **`cutAt_proverLog_stable`**: the log cut at the first query that ABSORBS a value `r`
  (any decoder `absOf` of a query to the value it absorbs), on the prover's log recovered by replay (`proverLog`); once a
  log contains an absorption of `r`, every longer log cuts the prover's log at the same place. This is
  `FSOpening.lean`'s `cut_proverLog_stable` for any chain encoding (there: the model chain's statement item).
* `allSt_short`, `everSt_congr_pre`: a combined state whose windows all start after `s` entries cannot be doomed before
  `s`; two schedules that agree on every chain extending a fixed `s`-entry prefix have the same `everSt` there.
* **`fs_code_chain_ever_log`**, **`fs_code_chain_sound_sched_log`**: for a FAMILY of schedules indexed by the run's log
  `P` (each sub-protocol's state may read the log), each `RbrWide` with its error, releases framed, every window after
  `s` entries, and the family frozen once a chain's first `s` entries are logged (`hstab`), the probability that some
  sub-protocol enters its window with a false claim and yet every sub-protocol is alive at the end is at most
  `T·ε + collBound T + collBound (T + 1)`, `T = q + ℓ + 1`: L8's bound, unchanged.

Only `propext`, `Classical.choice`, `Quot.sound`. Nothing here names a W16R2 specific; `ExtractW16Slots.lean` applies it
to the block's slots and `ExtractW16Open.lean` to the openings and `M`.
-/
import ZK60Formal.ExecComposeFS
import ZK60Formal.FSOpening

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Sound
open scoped ENNReal

/-! ## Chain prefixes -/

section ChainPrefix

variable {It Q D : Type}

/-- **A prefix of a chain is a chain**, whose queries are among the chain's. -/
theorem chain_take (C : ChainEnc It Q D) (H : Q → D) {τ : List (It × D)} {qs : List Q} (hc : C.Chain H τ qs) :
    ∀ i, i ≤ τ.length → ∃ qs', C.Chain H (τ.take i) qs' ∧ ∀ y ∈ qs', y ∈ qs := by
  induction hc with
  | nil =>
    intro i hi
    simp only [List.length_nil, Nat.le_zero] at hi
    subst hi
    exact ⟨_, ChainEnc.Chain.nil, fun y hy => hy⟩
  | @snoc τ qs it h ih =>
    intro i hi
    by_cases hle : i ≤ τ.length
    · obtain ⟨qs', h', hs⟩ := ih i hle
      refine ⟨qs', ?_, fun y hy => List.mem_append_left _ (hs y hy)⟩
      rwa [List.take_append_of_le_length hle]
    · have hi' : i = τ.length + 1 := by
        simp only [List.length_append, List.length_cons, List.length_nil] at hi
        omega
      refine ⟨_, ?_, fun y hy => hy⟩
      rw [List.take_of_length_le (show (τ ++ [(it, H (C.link (C.lastD H τ) it))]).length ≤ i by simp [hi'])]
      exact h.snoc it

/-- **Every entry's link query is among the chain's queries**: entry `i` was hashed as `link(lastD (τ.take i), item)`. -/
theorem chain_link_mem (C : ChainEnc It Q D) (H : Q → D) {τ : List (It × D)} {qs : List Q} (hc : C.Chain H τ qs) :
    ∀ (i : ℕ) (hi : i < τ.length), C.link (C.lastD H (τ.take i)) (τ[i]'hi).1 ∈ qs := by
  induction hc with
  | nil =>
    intro i hi
    simp at hi
  | @snoc τ qs it h ih =>
    intro i hi
    by_cases hlt : i < τ.length
    · have e1 : (τ ++ [(it, H (C.link (C.lastD H τ) it))]).take i = τ.take i := List.take_append_of_le_length hlt.le
      have e2 : (τ ++ [(it, H (C.link (C.lastD H τ) it))])[i]'hi = τ[i]'hlt := List.getElem_append_left hlt
      rw [e1, e2]
      exact List.mem_append_left _ (ih i hlt)
    · have hi' : i = τ.length := by
        simp only [List.length_append, List.length_cons, List.length_nil] at hi
        omega
      subst hi'
      have e1 : (τ ++ [(it, H (C.link (C.lastD H τ) it))]).take τ.length = τ := List.take_left' rfl
      have e2 : (τ ++ [(it, H (C.link (C.lastD H τ) it))])[τ.length]'hi = (it, H (C.link (C.lastD H τ) it)) := by
        simp
      rw [e1, e2]
      exact List.mem_append_right _ (List.mem_singleton_self _)

end ChainPrefix

/-! ## The log cut at a value's first absorption -/

section Cut

variable {Q D β : Type} [DecidableEq β]

/-- Whether a log entry's query absorbs the value `r` (read by `absOf`). -/
def isAbsAt (absOf : Q → Option β) (r : β) (e : Q × D) : Bool := decide (absOf e.1 = some r)

/-- **The log cut at `r`'s first absorption**: the entries before the first query that absorbs `r` (all of them if
none does). -/
def cutAt (absOf : Q → Option β) (r : β) (P : List (Q × D)) : List (Q × D) :=
  P.take (P.findIdx (isAbsAt absOf r))

/-- Once the log contains an absorption of `r`, extending it does not move the cut. -/
theorem cutAt_append (absOf : Q → Option β) (r : β) (P R : List (Q × D)) (h : ∃ e ∈ P, absOf e.1 = some r) :
    cutAt absOf r (P ++ R) = cutAt absOf r P := by
  have hlt : P.findIdx (isAbsAt absOf r) < P.length := by
    obtain ⟨e, he, h⟩ := h
    exact List.findIdx_lt_length_of_exists ⟨e, he, by simp [isAbsAt, h]⟩
  rw [cutAt, cutAt, List.findIdx_append, ite_eq_left hlt, List.take_append_of_le_length hlt.le]

/-- **The extraction is frozen at the absorption** (`FSOpening.lean`'s `cut_proverLog_stable` for any chain encoding):
once a log contains an absorption of `r`, every longer log cuts the PROVER's log (recovered by replay) at the same
place. -/
theorem cutAt_proverLog_stable {γ : Type} (A : OC Q D γ) (absOf : Q → Option β) (r : β)
    (P P' : List (Q × D)) (hpre : P <+: P') (h : ∃ e ∈ P, absOf e.1 = some r) :
    cutAt absOf r (proverLog A P') = cutAt absOf r (proverLog A P) := by
  obtain ⟨R, rfl⟩ := hpre
  rcases hr : A.replay P with _ | r0
  · have hP : proverLog A P = P := by simp [proverLog, hr]
    rw [hP]
    rcases hr' : A.replay (P ++ R) with _ | r'
    · have : proverLog A (P ++ R) = P ++ R := by simp [proverLog, hr']
      rw [this, cutAt_append absOf r P R h]
    · have hlt := ZK60.OC.replay_none_lt A P R r' hr hr'
      have : proverLog A (P ++ R) = P ++ R.take (r'.2 - P.length) := by
        simp only [proverLog, hr']
        rw [List.take_append, List.take_of_length_le hlt.le]
      rw [this, cutAt_append absOf r P _ h]
  · have h1 := ZK60.OC.replay_append_of_some A P R r0 hr
    have : proverLog A (P ++ R) = proverLog A P := by
      simp only [proverLog, h1, hr]
      exact List.take_append_of_le_length (ZK60.OC.replay_le_length A P r0 hr)
    rw [this]

end Cut

/-! ## Combined states that agree after a prefix -/

section Agree

variable {D : Type}

/-- Before every window, the combined state is alive. -/
theorem allSt_short (W : UInt64 → ℕ) (cs : List (CSub D)) (τ : List (TItem × D)) (h : ∀ c ∈ cs, τ.length < c.a) :
    allSt W cs τ :=
  fun _ c hc => Or.inl (h c (List.mem_of_getElem? hc))

/-- **Two schedules that agree after a prefix agree on `everSt` there**: if every window of both starts after the
`s`-entry prefix `pre`, and the two combined states agree on every chain extending `pre`, then so do their `everSt`. -/
theorem everSt_congr_pre (W : UInt64 → ℕ) (cs cs' : List (CSub D)) (s : ℕ) (pre : List (TItem × D))
    (hpl : pre.length = s) (hwin : ∀ c ∈ cs, s < c.a) (hwin' : ∀ c ∈ cs', s < c.a)
    (hst : ∀ ext, allSt W cs (pre ++ ext) ↔ allSt W cs' (pre ++ ext)) (ext : List (TItem × D)) :
    everSt W cs (pre ++ ext) ↔ everSt W cs' (pre ++ ext) := by
  have key : ∀ j, (allSt W cs ((pre ++ ext).take j) ↔ allSt W cs' ((pre ++ ext).take j)) := by
    intro j
    by_cases hj : j < s
    · have hl : ((pre ++ ext).take j).length ≤ j := List.length_take_le _ _
      exact ⟨fun _ => allSt_short W cs' _ (fun c hc => by have := hwin' c hc; omega),
        fun _ => allSt_short W cs _ (fun c hc => by have := hwin c hc; omega)⟩
    · have e : (pre ++ ext).take j = pre ++ ext.take (j - s) := by
        rw [List.take_append, List.take_of_length_le (by omega), hpl]
      rw [e]
      exact hst _
  unfold everSt
  constructor
  · rintro ⟨h1, j, hj, ht, hn⟩
    exact ⟨(hst ext).mp h1, j, hj, ht, fun h => hn ((key j).mpr h)⟩
  · rintro ⟨h1, j, hj, ht, hn⟩
    exact ⟨(hst ext).mpr h1, j, hj, ht, fun h => hn ((key j).mp h)⟩

end Agree

/-! ## The composition with log-reading states -/

section LogChain

variable {D It' : Type} [Fintype D] [Nonempty D] [DecidableEq D] {Q : Type} [Fintype Q] [DecidableEq Q]

/-- **The knowledge version of L8's composition, the general form.** A family of schedules `cs P` indexed by the run's
log (each sub-protocol's state may read the log: data extracted from it), each `RbrWide` with its error, releases
handed on only forward; every window starts after `s` entries, the prover's first `s` heads hash at most `s` entries,
and the family is FROZEN once a chain's first `s` entries are logged (`hstab`). Then the probability that the chain is
alive at the end but was doomed at some step's end, for the schedule at the run's own log, is at most
`T·ε + collBound T D + collBound (T + 1) D`, `T = q + ℓ + 1`. -/
theorem fs_code_chain_ever_log (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) (cs : List (Q × D) → List (CSub D))
    (ε : ℝ≥0∞) (hR : ∀ P, ∀ c ∈ cs P, RbrWide c.R.n c.R.w c.St c.ε) (hε : ∀ P, ∀ c ∈ cs P, c.ε ≤ ε)
    (hframe : ∀ (P : List (Q × D)) (k : ℕ) (c : CSub D) (τ : List (TItem × D)) (h : TItem) (ks : List UInt64)
      (ds : List D), (cs P)[k]? = some c → tRem W τ = some 0 → ks.length + 1 = tWd W h →
      ds.length = ks.length + 1 → ¬ subSt W c τ → c.rel (τ ++ stE h ks ds) →
        ∃ k' c', k < k' ∧ (cs P)[k']? = some c' ∧ ¬ subSt W c' τ)
    (C : ChainEnc It' Q D) (toT : It' → TItem) (S : Steps It') (hS : StepsOK W toT S)
    {α : Type} (heads : α → List It') (ℓ : ℕ) (hℓ : ∀ o, ((heads o).flatMap S.items).length ≤ ℓ)
    (s : ℕ) (hwin : ∀ P, ∀ c ∈ cs P, s < c.a) (hhd : ∀ o, (((heads o).take s).flatMap S.items).length ≤ s)
    (hstab : ∀ (H : Q → D) (P P' : List (Q × D)) (τ : List (It' × D)) (qs : List Q), C.Chain H τ qs →
      τ.length = s → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' → (∀ e ∈ P', e.2 = H e.1) →
        ∀ ext : List (TItem × D),
          allSt W (cs P) (τ.map (toTE toT) ++ ext) ↔ allSt W (cs P') (τ.map (toTE toT) ++ ext))
    (q : ℕ) (A : OC Q D α) (hA : A.Bounded q) :
    prH (fun H => everSt W (cs ((C.stepRun S heads A).runLog H).2) (cChain C toT S H (heads (A.run H))))
      ≤ ((q + ℓ + 1 : ℕ) : ℝ≥0∞) * ε + collBound (q + ℓ + 1) D + collBound (q + ℓ + 1 + 1) D := by
  have hE : ∀ P, CodeRbr W (everSt W (cs P)) ε := fun P =>
    everSt_rbr W (cs P) ε (allSt_rbr W hW (cs P) ε (hR P) (hε P) (hframe P))
  refine le_trans (MeasureTheory.measure_mono ?_)
    (chain_sound_wide C S (fun P τ => everSt W (cs P) (τ.map (toTE toT))) s ε
      (fun P τ it _ h2 h3 => codeRbr_step W toT S hS (hE P) τ it h2 h3) ?_ heads ℓ hℓ q A hA)
  · intro H hH
    rw [Set.mem_ofPred_eq] at hH ⊢
    refine ⟨?_, hH⟩
    rintro ⟨-, j, -, -, h2⟩
    apply h2
    intro k c hc
    have hl : ((C.chainFrom H [] (((heads (A.run H)).take s).flatMap S.items)).map (toTE toT)).length ≤ s := by
      rw [List.length_map, ChainEnc.chainFrom_length, List.length_nil, zero_add]
      exact hhd _
    have hc' := hwin _ c (List.mem_of_getElem? hc)
    refine Or.inl ?_
    rw [List.length_take]
    omega
  · intro H P P' τ qs ext hc hs hq hpre hans
    obtain ⟨qs₀, hc₀, hq₀⟩ := chain_take C H hc s hs
    have hl0 : (τ.take s).length = s := by
      rw [List.length_take]
      omega
    have hsplit : (τ ++ ext).map (toTE toT) = (τ.take s).map (toTE toT) ++ ((τ.drop s ++ ext).map (toTE toT)) := by
      rw [← List.map_append, ← List.append_assoc, List.take_append_drop]
    show everSt W (cs P) ((τ ++ ext).map (toTE toT)) ↔ everSt W (cs P') ((τ ++ ext).map (toTE toT))
    rw [hsplit]
    exact everSt_congr_pre W (cs P) (cs P') s _ (by rw [List.length_map, hl0]) (hwin P) (hwin P')
      (hstab H P P' (τ.take s) qs₀ hc₀ hl0 (fun y hy => hq y (hq₀ y hy)) hpre hans) _

/-- **The knowledge version of L8's scheduled composition** (`fs_code_chain_sound_sched` with log-reading states): for
the schedule at the run's own log, the probability that SOME sub-protocol enters its window with a false claim (at a
step's end, not released) and yet EVERY sub-protocol is alive at the end is at most
`T·ε + collBound T D + collBound (T + 1) D`, `T = q + ℓ + 1`. -/
theorem fs_code_chain_sound_sched_log (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) (cs : List (Q × D) → List (CSub D))
    (ε : ℝ≥0∞) (hR : ∀ P, ∀ c ∈ cs P, RbrWide c.R.n c.R.w c.St c.ε) (hε : ∀ P, ∀ c ∈ cs P, c.ε ≤ ε)
    (hframe : ∀ (P : List (Q × D)) (k : ℕ) (c : CSub D) (τ : List (TItem × D)) (h : TItem) (ks : List UInt64)
      (ds : List D), (cs P)[k]? = some c → tRem W τ = some 0 → ks.length + 1 = tWd W h →
      ds.length = ks.length + 1 → ¬ subSt W c τ → c.rel (τ ++ stE h ks ds) →
        ∃ k' c', k < k' ∧ (cs P)[k']? = some c' ∧ ¬ subSt W c' τ)
    (C : ChainEnc It' Q D) (toT : It' → TItem) (S : Steps It') (hS : StepsOK W toT S)
    {α : Type} (heads : α → List It') (ℓ : ℕ) (hℓ : ∀ o, ((heads o).flatMap S.items).length ≤ ℓ)
    (s : ℕ) (hwin : ∀ P, ∀ c ∈ cs P, s < c.a) (hhd : ∀ o, (((heads o).take s).flatMap S.items).length ≤ s)
    (hstab : ∀ (H : Q → D) (P P' : List (Q × D)) (τ : List (It' × D)) (qs : List Q), C.Chain H τ qs →
      τ.length = s → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' → (∀ e ∈ P', e.2 = H e.1) →
        ∀ ext : List (TItem × D),
          allSt W (cs P) (τ.map (toTE toT) ++ ext) ↔ allSt W (cs P') (τ.map (toTE toT) ++ ext))
    (q : ℕ) (A : OC Q D α) (hA : A.Bounded q) :
    prH (fun H => (∃ (k : ℕ) (c : CSub D), (cs ((C.stepRun S heads A).runLog H).2)[k]? = some c
          ∧ c.a ≤ (cChain C toT S H (heads (A.run H))).length
          ∧ tRem W ((cChain C toT S H (heads (A.run H))).take c.a) = some 0
          ∧ ¬ c.St ((cChain C toT S H (heads (A.run H))).take c.a) []
          ∧ ¬ c.rel ((cChain C toT S H (heads (A.run H))).take c.a))
        ∧ allSt W (cs ((C.stepRun S heads A).runLog H).2) (cChain C toT S H (heads (A.run H))))
      ≤ ((q + ℓ + 1 : ℕ) : ℝ≥0∞) * ε + collBound (q + ℓ + 1) D + collBound (q + ℓ + 1 + 1) D := by
  refine le_trans (MeasureTheory.measure_mono ?_)
    (fs_code_chain_ever_log W hW cs ε hR hε hframe C toT S hS heads ℓ hℓ s hwin hhd hstab q A hA)
  intro H hH
  rw [Set.mem_ofPred_eq] at hH ⊢
  obtain ⟨⟨k, c, hc, ha, hal, hst, hrel⟩, hall⟩ := hH
  refine ⟨hall, c.a, ha, hal, fun h' => ?_⟩
  rcases h' k c hc with h1 | ⟨-, h1⟩ | h1
  · rw [List.length_take, min_eq_left ha] at h1
    omega
  · rw [List.take_take, min_self, List.drop_eq_nil_of_le (by rw [List.length_take]; omega)] at h1
    exact hst h1
  · exact hrel h1

end LogChain

end ZK60.Exec
