/-
D63, step L3 (soundness): the random oracle. A fresh answer rarely lands in a small set; hence collision resistance
and preimage resistance, for adaptive oracle computations.

Model (`Statements.lean`'s): the hash is ONE uniformly random function `H : Q → D` on a finite query space; an
adversary is a deterministic oracle computation `OC Q D α`, its budget `OC.Bounded q` counted on every path; the
probability is `prH`, the uniform law on `Q → D`. Several hash functions (BLAKE3 under the four D19 keys, and unkeyed)
are ONE random function on the disjoint union of their inputs, so nothing is lost by using one `H`.

The one probabilistic fact (`prob_fresh_mem_le`): if an event names, for each oracle, at most one point `y` (`G y H`)
that is NOT YET FIXED (changing `H` at `y` changes neither the event nor the set `T y H`), then `H y` lands in the set
of at most `m` values with probability at most `m/|D|`. The proof swaps `H y` with a fresh value: an involution of
`(Q → D) × D`, so it preserves counting.

Applied to an adaptive run, position by position (`freshHit_prob_le`): the chance that SOME query, the first time it is
asked, gets an answer in a set `F` of at most `m t` values computed from the log before it (position `t`), is at most
`Σ_{t < T} m t / |D|`. Consequences:
* `collision_prob_le`: a `q`-query computation's queries contain a collision (`a ≠ b`, `H a = H b`) with probability
  at most `q(q − 1)/2 / |D|` (here `F` is the set of answers so far, `m t = t`);
* `collision_out_prob_le`: a `q`-query computation OUTPUTS a collision with probability at most
  `(q + 2)(q + 1)/2 / |D|` (it costs two more queries to check);
* `preimage_query_prob_le`: some query hits a target `t₀` fixed in advance with probability at most `q/|D|`;
* `preimage_out_prob_le`: a computation outputs `(x, d)` with `H x = d` WITHOUT having asked `x` with probability at most
  `1/|D|`, whatever its budget.

What this is not: a statement about BLAKE3. The random-oracle model is D19's idealisation (and D63's statement-level
choice in `Statements.lean`).
-/
import ZK60Formal.HidingMerkle
import ZK60Formal.SoundSchwartzZippel

namespace ZK60

open scoped ENNReal

/-! ## Oracle computations: logs, prefixes, replay -/

namespace OC

variable {I O α β : Type}

/-- The result `runLog` returns is the result of `run`. -/
theorem runLog_fst (f : I → O) (A : OC I O α) : (A.runLog f).1 = A.run f := by
  induction A with
  | ret a => rfl
  | ask i k ih => exact ih (f i)

/-- Every entry of a run's log is a question paired with the oracle's answer to it. -/
theorem runLog_answer (f : I → O) (A : OC I O α) : ∀ e ∈ (A.runLog f).2, e.2 = f e.1 := by
  induction A with
  | ret a => simp [runLog]
  | ask i k ih =>
    intro e he
    simp only [runLog, List.mem_cons] at he
    rcases he with rfl | he
    · rfl
    · exact ih (f i) e he

/-- A computation bounded by `q` logs at most `q` entries on the path it takes. -/
theorem runLog_length_le (f : I → O) (A : OC I O α) (q : ℕ) (hA : A.Bounded q) :
    (A.runLog f).2.length ≤ q := by
  have := length_queries_le f A q hA
  simpa [queries] using this

/-- The log of a sequential composition is the first computation's log followed by the second's. -/
theorem runLog_bind (f : I → O) (A : OC I O α) (k : α → OC I O β) :
    ((A.bind k).runLog f).2 = (A.runLog f).2 ++ ((k (A.run f)).runLog f).2 := by
  induction A with
  | ret a => simp [OC.bind, runLog, run]
  | ask i c ih =>
    simp only [OC.bind, runLog, run, List.cons_append]
    rw [ih (f i)]

/-- The questions of a sequential composition are the first computation's followed by the second's. -/
theorem queries_bind (f : I → O) (A : OC I O α) (k : α → OC I O β) :
    queries f (A.bind k) = queries f A ++ queries f (k (A.run f)) := by
  simp only [queries, runLog_bind, List.map_append]

/-- **Prefixes depend only on the prefix's answers.** If two oracles agree on the questions of the first `t` entries of
the run against `f`, the two runs have the same first `t` entries and ask the same `t`-th question (or both stop). -/
theorem runLog_take_agree (f g : I → O) (A : OC I O α) (t : ℕ)
    (h : ∀ e ∈ (A.runLog f).2.take t, g e.1 = f e.1) :
    (A.runLog g).2.take t = (A.runLog f).2.take t
      ∧ ((A.runLog g).2[t]?).map Prod.fst = ((A.runLog f).2[t]?).map Prod.fst := by
  induction A generalizing t with
  | ret a => simp [runLog]
  | ask i k ih =>
    cases t with
    | zero => simp [runLog]
    | succ t =>
      simp only [runLog, List.take_succ_cons, List.getElem?_cons_succ] at h ⊢
      have hi : g i = f i := h (i, f i) List.mem_cons_self
      rw [hi]
      have := ih (f i) t (fun e he => h e (List.mem_cons_of_mem _ he))
      exact ⟨by rw [this.1], this.2⟩

/-- **Identical until bad, for the log.** Two oracles that agree on every question the run against the first asks give
the same log (hence the same result and the same questions). -/
theorem runLog_eq_of_agree (f g : I → O) (A : OC I O α) (h : ∀ y ∈ queries f A, g y = f y) :
    A.runLog g = A.runLog f := by
  induction A with
  | ret a => rfl
  | ask i k ih =>
    rw [queries_ask] at h
    have hi : g i = f i := h i List.mem_cons_self
    simp only [runLog]
    rw [hi, ih (f i) (fun y hy => h y (List.mem_cons_of_mem _ hy))]

/-- Replay a computation against a log: feed it the logged answers in order. It returns the result and the number of
entries used, or `none` if the log is too short. -/
def replay : OC I O α → List (I × O) → Option (α × ℕ)
  | .ret a, _ => some (a, 0)
  | .ask _ _, [] => none
  | .ask _ k, e :: rest => (replay (k e.2) rest).map (fun r => (r.1, r.2 + 1))

/-- Replaying a computation against its own log, followed by anything, recovers its result and its log's length. -/
theorem replay_runLog_append (f : I → O) (A : OC I O α) (R : List (I × O)) :
    A.replay ((A.runLog f).2 ++ R) = some (A.run f, (A.runLog f).2.length) := by
  induction A with
  | ret a => simp [replay, runLog, run]
  | ask i k ih => simp [replay, runLog, run, ih (f i)]

/-- A computation bounded by `q` uses at most `q` entries when replayed. -/
theorem replay_le (A : OC I O α) (q : ℕ) (hA : A.Bounded q) (P : List (I × O)) (r : α × ℕ)
    (h : A.replay P = some r) : r.2 ≤ q := by
  induction A generalizing q P r with
  | ret a =>
    simp only [replay, Option.some.injEq] at h
    rw [← h]
    exact Nat.zero_le _
  | ask i k ih =>
    cases q with
    | zero => simp [Bounded] at hA
    | succ q =>
      cases P with
      | nil => simp [replay] at h
      | cons e rest =>
        simp only [replay, Option.map_eq_some_iff] at h
        obtain ⟨r', hr', rfl⟩ := h
        have := ih e.2 q (hA e.2) rest r' hr'
        simp only
        omega

end OC

namespace Sound

open Finset

/-! ## The one probabilistic fact -/

section Fresh

variable {Q D : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]

/-- **A not-yet-fixed coordinate of a uniform function lands in a small set with probability at most its size over
`|D|`.** For each oracle `H` the event names at most one point `y` (`G y H`); changing `H` at that point changes
neither `G y` nor the set `T y H`, which has at most `m` elements. Then `H y ∈ T y H` has probability at most
`m/|D|`. -/
theorem prob_fresh_mem_le (G : Q → (Q → D) → Prop) (T : Q → (Q → D) → Finset D) (m : ℕ)
    (hdisj : ∀ y y' H, G y H → G y' H → y = y')
    (hinv : ∀ y H d, G y H → G y (Function.update H y d) ∧ T y (Function.update H y d) = T y H)
    (hcard : ∀ y H, G y H → (T y H).card ≤ m) :
    (PMF.uniformOfFintype (Q → D)).toOuterMeasure {H | ∃ y, G y H ∧ H y ∈ T y H}
      ≤ (m : ℝ≥0∞) / Fintype.card D := by
  classical
  refine prob_le_of_card_mul _ m (Fintype.card D) Fintype.card_ne_zero ?_
  -- one point at a time: swap `H y` with a fresh value
  have hy : ∀ y, (univ.filter (fun H : Q → D => G y H ∧ H y ∈ T y H)).card * Fintype.card D
      ≤ m * (univ.filter (fun H : Q → D => G y H)).card := by
    intro y
    have h1 : (univ.filter (fun H : Q → D => G y H ∧ H y ∈ T y H)).card * Fintype.card D
        = (univ.filter (fun p : (Q → D) × D => G y p.1 ∧ p.1 y ∈ T y p.1)).card := by
      have : (univ.filter (fun p : (Q → D) × D => G y p.1 ∧ p.1 y ∈ T y p.1))
          = (univ.filter (fun H : Q → D => G y H ∧ H y ∈ T y H)) ×ˢ (univ : Finset D) := by
        ext p
        simp
      rw [this, card_product, card_univ]
    have h2 : (univ.filter (fun p : (Q → D) × D => G y p.1 ∧ p.1 y ∈ T y p.1)).card
        = (univ.filter (fun p : (Q → D) × D => G y p.1 ∧ p.2 ∈ T y p.1)).card := by
      refine card_nbij' (fun p => (Function.update p.1 y p.2, p.1 y))
        (fun p => (Function.update p.1 y p.2, p.1 y)) ?_ ?_ ?_ ?_
      · rintro ⟨H, d⟩ hp
        simp only [coe_filter, mem_univ, true_and, Set.mem_ofPred_eq] at hp ⊢
        obtain ⟨hG, hT⟩ := hinv y H d hp.1
        exact ⟨hG, by rw [hT]; exact hp.2⟩
      · rintro ⟨H, d⟩ hp
        simp only [coe_filter, mem_univ, true_and, Set.mem_ofPred_eq] at hp ⊢
        obtain ⟨hG, hT⟩ := hinv y H d hp.1
        refine ⟨hG, ?_⟩
        rw [hT, Function.update_self]
        exact hp.2
      · rintro ⟨H, d⟩ _
        simp [Function.update_idem, Function.update_eq_self]
      · rintro ⟨H, d⟩ _
        simp [Function.update_idem, Function.update_eq_self]
    have h3 : (univ.filter (fun p : (Q → D) × D => G y p.1 ∧ p.2 ∈ T y p.1)).card
        ≤ m * (univ.filter (fun H : Q → D => G y H)).card := by
      rw [card_filter_prod]
      calc ∑ H : Q → D, (univ.filter (fun d : D => G y H ∧ d ∈ T y H)).card
          ≤ ∑ H : Q → D, (if G y H then m else 0) := by
            refine sum_le_sum (fun H _ => ?_)
            by_cases hG : G y H
            · rw [ite_eq_left hG]
              refine le_trans (card_le_card ?_) (hcard y H hG)
              intro d hd
              exact (mem_filter.mp hd).2.2
            · rw [ite_eq_right hG]
              refine le_of_eq (card_eq_zero.mpr (filter_eq_empty_iff.mpr fun d _ hd => hG hd.1))
        _ = m * (univ.filter (fun H : Q → D => G y H)).card := by
            rw [← sum_filter, sum_const, smul_eq_mul, mul_comm]
    rw [h1, h2]
    exact h3
  -- the points named are distinct for one oracle, so their events cover the oracles at most once
  have hdis : ∑ y, (univ.filter (fun H : Q → D => G y H)).card ≤ Fintype.card (Q → D) := by
    simp only [card_filter]
    rw [sum_comm]
    calc ∑ H : Q → D, ∑ y : Q, (if G y H then 1 else 0)
        = ∑ H : Q → D, (univ.filter (fun y => G y H)).card := by simp only [card_filter]
      _ ≤ ∑ _H : Q → D, 1 := by
          refine sum_le_sum (fun H _ => ?_)
          rw [card_le_one]
          intro a ha b hb
          exact hdisj a b H (mem_filter.mp ha).2 (mem_filter.mp hb).2
      _ = Fintype.card (Q → D) := by simp
  have hunion : (univ.filter (fun H : Q → D => ∃ y, G y H ∧ H y ∈ T y H))
      = univ.biUnion (fun y => univ.filter (fun H : Q → D => G y H ∧ H y ∈ T y H)) := by
    ext H
    simp
  rw [hunion]
  calc (univ.biUnion (fun y => univ.filter (fun H : Q → D => G y H ∧ H y ∈ T y H))).card * Fintype.card D
      ≤ (∑ y, (univ.filter (fun H : Q → D => G y H ∧ H y ∈ T y H)).card) * Fintype.card D :=
        Nat.mul_le_mul_right _ card_biUnion_le
    _ = ∑ y, (univ.filter (fun H : Q → D => G y H ∧ H y ∈ T y H)).card * Fintype.card D := by
        rw [sum_mul]
    _ ≤ ∑ y, m * (univ.filter (fun H : Q → D => G y H)).card := sum_le_sum (fun y _ => hy y)
    _ = m * ∑ y, (univ.filter (fun H : Q → D => G y H)).card := by rw [mul_sum]
    _ ≤ m * Fintype.card (Q → D) := Nat.mul_le_mul_left _ hdis

end Fresh

/-! ## Fresh hits in a log -/

section Hits

variable {Q D : Type}

/-- **A fresh hit in a log**: some entry asks a question that no earlier entry asked, and its answer lies in the set
`F` computes from the entries before it. -/
def FreshHit (F : List (Q × D) → Finset D) (L : List (Q × D)) : Prop :=
  ∃ t e, L[t]? = some e ∧ e.1 ∉ (L.take t).map Prod.fst ∧ e.2 ∈ F (L.take t)

/-- The first occurrence of a logged question. -/
theorem exists_first {L : List (Q × D)} {v : Q} (hv : v ∈ L.map Prod.fst) :
    ∃ t e, L[t]? = some e ∧ e.1 = v ∧ v ∉ (L.take t).map Prod.fst := by
  induction L with
  | nil => simp at hv
  | cons e L ih =>
    by_cases he : e.1 = v
    · exact ⟨0, e, rfl, he, by simp⟩
    · have hv' : v ∈ L.map Prod.fst := by
        simp only [List.map_cons, List.mem_cons] at hv
        rcases hv with hv | hv
        · exact absurd hv.symm he
        · exact hv
      obtain ⟨t, e', h1, h2, h3⟩ := ih hv'
      refine ⟨t + 1, e', by simpa using h1, h2, ?_⟩
      simp only [List.take_succ_cons, List.map_cons, List.mem_cons, not_or]
      exact ⟨fun h => he h.symm, h3⟩

/-- A fresh hit from a first occurrence: if a logged question's answer lies in `F` of the log before its first
occurrence, the log has a fresh hit. -/
theorem freshHit_of_first (H : Q → D) {L : List (Q × D)} (hL : ∀ e ∈ L, e.2 = H e.1)
    (F : List (Q × D) → Finset D) {v : Q} (hv : v ∈ L.map Prod.fst)
    (hF : ∀ t e, L[t]? = some e → e.1 = v → v ∉ (L.take t).map Prod.fst → H v ∈ F (L.take t)) :
    FreshHit F L := by
  obtain ⟨t, e, h1, h2, h3⟩ := exists_first hv
  refine ⟨t, e, h1, by rw [h2]; exact h3, ?_⟩
  rw [hL e (List.mem_of_getElem? h1), h2]
  exact hF t e h1 h2 h3

/-- The first occurrence of a question lies after a prefix that never asks it. -/
theorem first_after_prefix {L₁ L₂ : List (Q × D)} {v : Q} (hv : v ∉ L₁.map Prod.fst) {t : ℕ} {e : Q × D}
    (h1 : (L₁ ++ L₂)[t]? = some e) (h2 : e.1 = v) : L₁.length ≤ t := by
  by_contra hlt
  push Not at hlt
  rw [List.getElem?_append_left hlt] at h1
  exact hv (h2 ▸ List.mem_map_of_mem (List.mem_of_getElem? h1))

/-- **A collision among a log's questions gives a fresh hit on the answers so far**: of the two colliding questions,
the one asked later is new at its first occurrence and its answer is an earlier answer. -/
theorem freshHit_of_collision [DecidableEq D] (H : Q → D) (L : List (Q × D)) (hL : ∀ e ∈ L, e.2 = H e.1)
    (h : ∃ a ∈ L.map Prod.fst, ∃ b ∈ L.map Prod.fst, a ≠ b ∧ H a = H b) :
    FreshHit (fun P => (P.map Prod.snd).toFinset) L := by
  obtain ⟨a, ha, b, hb, hab, hH⟩ := h
  obtain ⟨ta, ea, ha1, ha2, ha3⟩ := exists_first ha
  obtain ⟨tb, eb, hb1, hb2, hb3⟩ := exists_first hb
  -- the earlier of the two first occurrences is in the prefix of the later one
  have key : ∀ (t₁ t₂ : ℕ) (e₁ e₂ : Q × D), L[t₁]? = some e₁ → L[t₂]? = some e₂ → t₁ < t₂ →
      e₂.1 ∉ (L.take t₂).map Prod.fst → H e₁.1 = H e₂.1 → FreshHit (fun P => (P.map Prod.snd).toFinset) L := by
    intro t₁ t₂ e₁ e₂ h1 h2 hlt hnew hHe
    refine ⟨t₂, e₂, h2, hnew, ?_⟩
    have hmem : e₁ ∈ L.take t₂ := by
      have : (L.take t₂)[t₁]? = some e₁ := by
        rw [List.getElem?_take]
        simp [hlt, h1]
      exact List.mem_of_getElem? this
    rw [List.mem_toFinset, hL e₂ (List.mem_of_getElem? h2), ← hHe, ← hL e₁ (List.mem_of_getElem? h1)]
    exact List.mem_map_of_mem hmem
  rcases lt_trichotomy ta tb with hlt | heq | hgt
  · exact key ta tb ea eb ha1 hb1 hlt (by rw [hb2]; exact hb3) (by rw [ha2, hb2]; exact hH)
  · subst heq
    rw [ha1] at hb1
    cases hb1
    exact absurd (ha2.symm.trans hb2) hab
  · exact key tb ta eb ea hb1 ha1 hgt (by rw [ha2]; exact ha3) (by rw [ha2, hb2]; exact hH.symm)

end Hits

section Bounds

variable {Q D : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]

/-- **The fresh-hit lemma.** For a computation making at most `T` queries on every path, and a set `F` of at most
`m t` digests computed from the log before position `t`: the probability, over a uniform oracle, that some query gets,
the first time it is asked, an answer in `F` of the log before it, is at most `Σ_{t < T} m t / |D|`. -/
theorem freshHit_prob_le {α : Type} (A : OC Q D α) (T : ℕ) (hA : A.Bounded T)
    (F : List (Q × D) → Finset D) (m : ℕ → ℕ) (hF : ∀ P, (F P).card ≤ m P.length) :
    prH (fun H => FreshHit F (A.runLog H).2)
      ≤ ((∑ t ∈ range T, m t : ℕ) : ℝ≥0∞) / Fintype.card D := by
  classical
  set μ := (PMF.uniformOfFintype (Q → D)).toOuterMeasure
  -- position `t` names the point it asks, when that point is new
  let G : ℕ → Q → (Q → D) → Prop := fun t y H =>
    ∃ e, (A.runLog H).2[t]? = some e ∧ e.1 = y ∧ y ∉ ((A.runLog H).2.take t).map Prod.fst
  let Tt : ℕ → Q → (Q → D) → Finset D := fun t _ H => F ((A.runLog H).2.take t)
  have hsub : {H : Q → D | FreshHit F (A.runLog H).2}
      ⊆ ⋃ t ∈ range T, {H | ∃ y, G t y H ∧ H y ∈ Tt t y H} := by
    intro H hH
    obtain ⟨t, e, h1, h2, h3⟩ := hH
    have ht : t < (A.runLog H).2.length := (List.getElem?_eq_some_iff.mp h1).1
    simp only [Set.mem_iUnion, Set.mem_ofPred_eq, mem_range]
    refine ⟨t, lt_of_lt_of_le ht (OC.runLog_length_le H A T hA), e.1, ⟨e, h1, rfl, h2⟩, ?_⟩
    rw [← OC.runLog_answer H A e (List.mem_of_getElem? h1)]
    exact h3
  have hpos : ∀ t, μ {H | ∃ y, G t y H ∧ H y ∈ Tt t y H} ≤ (m t : ℝ≥0∞) / Fintype.card D := by
    intro t
    refine prob_fresh_mem_le (G t) (Tt t) (m t) ?_ ?_ ?_
    · rintro y y' H ⟨e, h1, rfl, -⟩ ⟨e', h1', rfl, -⟩
      rw [h1] at h1'
      cases h1'
      rfl
    · rintro y H d ⟨e, h1, rfl, h3⟩
      have hag := OC.runLog_take_agree H (Function.update H e.1 d) A t (fun e' he' => by
        refine Function.update_of_ne ?_ d H
        intro hc
        exact h3 (hc ▸ List.mem_map_of_mem he'))
      refine ⟨?_, by simp only [Tt, hag.1]⟩
      have hq : ((A.runLog (Function.update H e.1 d)).2[t]?).map Prod.fst = some e.1 := by
        rw [hag.2, h1]
        rfl
      obtain ⟨e', he', he'1⟩ := Option.map_eq_some_iff.mp hq
      exact ⟨e', he', he'1, by rw [hag.1]; exact h3⟩
    · rintro y H ⟨e, h1, rfl, -⟩
      have ht : t < (A.runLog H).2.length := (List.getElem?_eq_some_iff.mp h1).1
      have := hF ((A.runLog H).2.take t)
      rwa [List.length_take, min_eq_left ht.le] at this
  calc prH (fun H => FreshHit F (A.runLog H).2)
      ≤ μ (⋃ t ∈ range T, {H | ∃ y, G t y H ∧ H y ∈ Tt t y H}) := MeasureTheory.measure_mono hsub
    _ ≤ ∑ t ∈ range T, μ {H | ∃ y, G t y H ∧ H y ∈ Tt t y H} :=
        MeasureTheory.measure_biUnion_finset_le _ _
    _ ≤ ∑ t ∈ range T, (m t : ℝ≥0∞) / Fintype.card D := sum_le_sum (fun t _ => hpos t)
    _ = ((∑ t ∈ range T, m t : ℕ) : ℝ≥0∞) / Fintype.card D := by
        rw [Nat.cast_sum]
        simp only [div_eq_mul_inv, sum_mul]

/-- **Collision resistance of a random oracle (task 1).** The queries of a computation making at most `q` queries
contain a collision, two different questions with the same answer, with probability at most `q(q − 1)/2 / |D|`. -/
theorem collision_prob_le {α : Type} (A : OC Q D α) (q : ℕ) (hA : A.Bounded q) :
    prH (fun H => ∃ a ∈ OC.queries H A, ∃ b ∈ OC.queries H A, a ≠ b ∧ H a = H b)
      ≤ ((q * (q - 1) / 2 : ℕ) : ℝ≥0∞) / Fintype.card D := by
  classical
  have h := freshHit_prob_le A q hA (fun P => (P.map Prod.snd).toFinset) (fun t => t)
    (fun P => by simpa using List.toFinset_card_le (P.map Prod.snd))
  rw [sum_range_id] at h
  refine le_trans (MeasureTheory.measure_mono ?_) h
  intro H hH
  exact freshHit_of_collision H _ (OC.runLog_answer H A) hH

/-- The bound of `collision_prob_le`: `q(q − 1)/2 / |D|`. -/
noncomputable def collBound (q : ℕ) (D : Type) [Fintype D] : ℝ≥0∞ :=
  ((q * (q - 1) / 2 : ℕ) : ℝ≥0∞) / Fintype.card D

/-- **An adversary that outputs a collision.** A computation making at most `q` queries outputs two different questions
with the same answer with probability at most `(q + 2)(q + 1)/2 / |D|`: checking its output costs two queries. -/
theorem collision_out_prob_le (A : OC Q D (Q × Q)) (q : ℕ) (hA : A.Bounded q) :
    prH (fun H => (A.run H).1 ≠ (A.run H).2 ∧ H (A.run H).1 = H (A.run H).2)
      ≤ (((q + 2) * (q + 1) / 2 : ℕ) : ℝ≥0∞) / Fintype.card D := by
  classical
  let B : OC Q D (Q × Q) := A.bind (fun o => .ask o.1 (fun _ => .ask o.2 (fun _ => .ret o)))
  have hB : B.Bounded (q + 2) := hA.bind (fun o => by simp [OC.Bounded])
  have h := collision_prob_le B (q + 2) hB
  rw [show q + 2 - 1 = q + 1 by omega] at h
  refine le_trans (MeasureTheory.measure_mono ?_) h
  rintro H ⟨hne, hH⟩
  have hq : OC.queries H B = OC.queries H A ++ [(A.run H).1, (A.run H).2] := by
    simp only [B, OC.queries_bind]
    simp [OC.queries, OC.runLog]
  exact ⟨(A.run H).1, by rw [hq]; simp, (A.run H).2, by rw [hq]; simp, hne, hH⟩

/-- **A preimage of a fixed target.** The queries of a computation making at most `q` queries include a preimage of a
digest `t₀` fixed in advance with probability at most `q/|D|`. -/
theorem preimage_query_prob_le {α : Type} (A : OC Q D α) (q : ℕ) (hA : A.Bounded q) (t₀ : D) :
    prH (fun H => ∃ y ∈ OC.queries H A, H y = t₀) ≤ (q : ℝ≥0∞) / Fintype.card D := by
  classical
  have h := freshHit_prob_le A q hA (fun _ => {t₀}) (fun _ => 1) (fun P => by simp)
  simp only [sum_const, card_range, smul_eq_mul, mul_one] at h
  refine le_trans (MeasureTheory.measure_mono ?_) h
  rintro H ⟨y, hy, hHy⟩
  exact freshHit_of_first H (OC.runLog_answer H A) (fun _ => {t₀}) hy (fun _ _ _ _ _ => by simp [hHy])

/-- **A query-free preimage.** A computation outputs a pair `(x, d)` with `H x = d` WITHOUT having asked `x` with
probability at most `1/|D|`, whatever its query budget: the answer at an unasked point is still uniform. -/
theorem preimage_out_prob_le {α : Type} (A : OC Q D (Q × D × α)) :
    prH (fun H => H (A.run H).1 = (A.run H).2.1 ∧ (A.run H).1 ∉ OC.queries H A)
      ≤ 1 / Fintype.card D := by
  classical
  have h := prob_fresh_mem_le (fun y H => (A.run H).1 = y ∧ y ∉ OC.queries H A)
    (fun _ H => {(A.run H).2.1}) 1
    (fun y y' H h1 h2 => h1.1.symm.trans h2.1)
    (fun y H d hG => by
      have hl := OC.runLog_eq_of_agree H (Function.update H y d) A (fun y' hy' =>
        Function.update_of_ne (fun hc => hG.2 (by rw [← hc]; exact hy')) d H)
      have hr : A.run (Function.update H y d) = A.run H := by
        rw [← OC.runLog_fst, hl, OC.runLog_fst]
      have hq : OC.queries (Function.update H y d) A = OC.queries H A := by
        simp only [OC.queries, hl]
      exact ⟨⟨by rw [hr]; exact hG.1, by rw [hq]; exact hG.2⟩, by rw [hr]⟩)
    (fun y H _ => by simp)
  rw [Nat.cast_one] at h
  refine le_trans (MeasureTheory.measure_mono ?_) h
  rintro H ⟨hH, hq⟩
  exact ⟨(A.run H).1, ⟨rfl, hq⟩, by simp [hH]⟩

end Bounds

end Sound

end ZK60
