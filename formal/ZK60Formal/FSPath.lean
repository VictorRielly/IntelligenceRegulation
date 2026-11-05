/-
D63, step L3 (soundness): the PATH-WISE round-by-round bound (finding F25, Victor's ruling D66(4), option (a)).

`FSCompose.lean`'s `Composed.rbrWide` shows that sub-protocols on one chain are round-by-round sound with the MAXIMUM
of their round errors, so the per-query rate is the largest error. Its query-free part, through `FSWideRbr.lean`, is
`(ℓW + 1)·ε`; with `FSPathRbr.lean`'s sharper count it becomes the sum of the round errors charged along the
verifier's transcript. This file charges a round only when it can revive the doom the proof follows.

**The doom's zone.** A false statement dooms some sub-protocol; a reduction hands its doom on to the sub-protocols its
claim goes to; a doom can be revived only in a round of the sub-protocol that holds it. The proof follows one doom
inside a ZONE, a set of sub-protocols that may change from round to round with the round's message (`zone x τ m`): in
a D12a run the prover's commitment of the boundary `B_k`, absorbed in the message of the first round of stage `k`,
decides whether the doom stays with the rest of the run or enters block `k` (`run.rs:1402-1407`). A sub-protocol's
state AFTER the round's message, before its challenge, is `pre` (a doom created by the message, such as `B_k`'s, is
doomed in `pre`; for a sub-protocol whose claim is fixed before the round, `pre` is its state before the round).
`ZComposed` asks:
* `own_round`: from a doomed `pre` state, the round revives its owner with probability at most the round's error;
* `hand`: if the current zone holds a doom before the round, the zone the message chooses holds a `pre` doom
  (messages hand a doom on; they never revive it);
* `frame`: in the chosen zone, a round never revives a `pre`-doomed sub-protocol it does not own, unless a LATER one of
  the zone is `pre`-doomed (`FSCompose.lean`'s `frame`, within the zone and after the message).

**What is proved.**
* `ZComposed.rbrWideT`: the combined state "every sub-protocol of the zone alive" is `RbrWideT` with the round's error
  charged ONLY when the round's owner is in the zone the round's message chose (`zEr`), and `0` otherwise. The proof
  is `Composed.rbrWide`'s: the largest `pre`-doomed sub-protocol of the chosen zone either owns the round or cannot be
  revived.
* `fs_chain_sound_of_zcomposed`: **a false statement is accepted with probability at most
  `q·εmax + B + collBound T + collBound (T + 1)`**, `εmax` the largest round error, `B` a bound on the zone charges
  along every transcript.
* `trSum_zone_le`: if every round charged along a transcript is owned by a sub-protocol of one set `Zb` (the
  hand-off path's sub-protocols), the charge is at most the sum of `Zb`'s round errors. **The query-free part is the
  maximum, over the paths, of the path's round-error sum.** `fs_chain_sound_of_zpath` states it.
* **The sharper count (task 1):** `Composed.toZ` (one fixed zone: every sub-protocol) and
  `fs_chain_sound_of_composed_sum`: for any composition of `FSCompose.lean`, the bound
  `q·εmax + Σ_{i<n} er i + collision terms`; each of the verifier's hash positions is charged its own round's error.
  On a schedule of `FSCompose.lean`, `fs_chain_sound_sched_sum`: `q·ε + Σ_k n_k·ε_k + collision terms`.
* Schedules with per-round errors and message-aware states are `FSPathSched.lean`'s (`SubProtP`).

**What this does not cover.** `hand`, `frame`, the start and final conditions, and the zone of each transcript are
premises: they say how the claims fit together (the arithmetization, step L2), as in `FSCompose.lean`.
`FSPathBlock.lean` instantiates the errors at the 8B parameters and states the run's zone structure.
-/
import ZK60Formal.FSPathRbr

set_option autoImplicit false

namespace ZK60.Sound

open scoped ENNReal
open Finset

/-! ## Zones -/

section Zone

variable {X M D J : Type}

/-- **The zone in force after a transcript**: `zone₀` before any round; after a round, the zone its message chose. -/
def lastZone (zone₀ : X → Finset J) (zone : X → List (M × List D) → M → Finset J) (x : X)
    (τ : List (M × List D)) : Finset J :=
  match τ.getLast? with
  | none => zone₀ x
  | some r => zone x τ.dropLast r.1

theorem lastZone_nil (zone₀ : X → Finset J) (zone : X → List (M × List D) → M → Finset J) (x : X) :
    lastZone zone₀ zone x [] = zone₀ x := rfl

theorem lastZone_snoc (zone₀ : X → Finset J) (zone : X → List (M × List D) → M → Finset J) (x : X)
    (τ : List (M × List D)) (r : M × List D) : lastZone zone₀ zone x (τ ++ [r]) = zone x τ r.1 := by
  simp [lastZone]

/-- With one fixed zone, it is in force after every transcript. -/
theorem lastZone_const (B : Finset J) (x : X) (τ : List (M × List D)) :
    lastZone (fun _ : X => B) (fun (_ : X) (_ : List (M × List D)) (_ : M) => B) x τ = B := by
  unfold lastZone
  split <;> rfl

variable [Fintype D] [Nonempty D]

/-- **A composition with zones.** `n` rounds of widths `w`; round `i` belongs to `own i`; `S j` is sub-protocol `j`'s
state, `pre j x τ m` its state after the message `m` of round `τ.length`; `er i` is round `i`'s error; `zone₀ x` is
the zone at the start, `zone x τ m` the zone the message `m` of round `τ.length` chooses. -/
structure ZComposed [LinearOrder J] (n : ℕ) (w : ℕ → ℕ) (own : ℕ → J) (S : J → X → List (M × List D) → Prop)
    (pre : J → X → List (M × List D) → M → Prop) (er : ℕ → ℝ≥0∞) (zone₀ : X → Finset J)
    (zone : X → List (M × List D) → M → Finset J) : Prop where
  own_round : ∀ x τ m, τ.length < n → ¬ pre (own τ.length) x τ m →
    (PMF.uniformOfFintype (Fin (w τ.length) → D)).toOuterMeasure
      {b | S (own τ.length) x (τ ++ [(m, List.ofFn b)])} ≤ er τ.length
  hand : ∀ x τ m, τ.length < n → (∃ j ∈ lastZone zone₀ zone x τ, ¬ S j x τ) → ∃ j ∈ zone x τ m, ¬ pre j x τ m
  frame : ∀ j x τ m (b : Fin (w τ.length) → D), τ.length < n → own τ.length ≠ j → j ∈ zone x τ m →
    ¬ pre j x τ m → S j x (τ ++ [(m, List.ofFn b)]) → ∃ j' ∈ zone x τ m, j < j' ∧ ¬ pre j' x τ m

/-- **The combined state**: every sub-protocol of the zone in force is alive. -/
def ZAlive (S : J → X → List (M × List D) → Prop) (zone₀ : X → Finset J)
    (zone : X → List (M × List D) → M → Finset J) (x : X) (τ : List (M × List D)) : Prop :=
  ∀ j ∈ lastZone zone₀ zone x τ, S j x τ

/-- **The zone charge**: a round's error when its owner is in the zone its message chose, else `0`. -/
def zEr [DecidableEq J] (own : ℕ → J) (er : ℕ → ℝ≥0∞) (zone : X → List (M × List D) → M → Finset J) :
    X → List (M × List D) → M → ℝ≥0∞ :=
  fun x τ m => if own τ.length ∈ zone x τ m then er τ.length else 0

/-- **The zones compose round by round**, each round charged only when its owner is in the chosen zone. -/
theorem ZComposed.rbrWideT [LinearOrder J] {n : ℕ} {w : ℕ → ℕ} {own : ℕ → J}
    {S : J → X → List (M × List D) → Prop} {pre : J → X → List (M × List D) → M → Prop} {er : ℕ → ℝ≥0∞}
    {zone₀ : X → Finset J} {zone : X → List (M × List D) → M → Finset J}
    (h : ZComposed n w own S pre er zone₀ zone) :
    RbrWideT n w (ZAlive S zone₀ zone) (zEr own er zone) where
  round x τ m hτ hns := by
    classical
    have hd : ∃ j ∈ lastZone zone₀ zone x τ, ¬ S j x τ := by
      by_contra hno
      push Not at hno
      exact hns hno
    obtain ⟨j₁, hj₁z, hj₁⟩ := h.hand x τ m hτ hd
    have hne : ((zone x τ m).filter (fun j => ¬ pre j x τ m)).Nonempty := ⟨j₁, mem_filter.mpr ⟨hj₁z, hj₁⟩⟩
    obtain ⟨j₀, hj₀m, hj₀max⟩ := ((zone x τ m).filter (fun j => ¬ pre j x τ m)).exists_max_image id hne
    obtain ⟨hj₀z, hj₀⟩ := mem_filter.mp hj₀m
    have hsub : {b : Fin (w τ.length) → D | ZAlive S zone₀ zone x (τ ++ [(m, List.ofFn b)])}
        ⊆ {b | S j₀ x (τ ++ [(m, List.ofFn b)])} := by
      intro b hb
      have hz : lastZone zone₀ zone x (τ ++ [(m, List.ofFn b)]) = zone x τ m := lastZone_snoc _ _ _ _ _
      exact hb j₀ (hz ▸ hj₀z)
    refine le_trans (MeasureTheory.measure_mono hsub) ?_
    by_cases ho : own τ.length = j₀
    · have hz : own τ.length ∈ zone x τ m := ho ▸ hj₀z
      simp only [zEr, hz, ↓reduceIte]
      rw [← ho] at hj₀ ⊢
      exact h.own_round x τ m hτ hj₀
    · have hempty : {b : Fin (w τ.length) → D | S j₀ x (τ ++ [(m, List.ofFn b)])} = ∅ := by
        refine Set.eq_empty_iff_forall_notMem.mpr (fun b hb => ?_)
        obtain ⟨j', hj'z, hlt, hj'⟩ := h.frame j₀ x τ m b hτ ho hj₀z hj₀ hb
        exact absurd (hj₀max j' (mem_filter.mpr ⟨hj'z, hj'⟩)) (not_le.mpr hlt)
      rw [hempty, MeasureTheory.measure_empty]
      exact zero_le

/-! ### Transcript sums -/

omit [Fintype D] [Nonempty D] in
/-- **A transcript sum is at most the sum of bounds along it.** If the round after `ptr ++ τ.take j` is charged at
most `g (ptr.length + j)`, the transcript sum is at most `Σ_{j < |τ|} g (ptr.length + j)`. -/
theorem trSum_le_along (er : X → List (M × List D) → M → ℝ≥0∞) (x : X) (g : ℕ → ℝ≥0∞) :
    ∀ (ptr τ : List (M × List D)),
      (∀ j (hj : j < τ.length), er x (ptr ++ τ.take j) (τ[j]).1 ≤ g (ptr.length + j)) →
      trSumFrom er x ptr τ ≤ ∑ j ∈ range τ.length, g (ptr.length + j)
  | ptr, [], _ => by simp [trSumFrom]
  | ptr, r :: rs, h => by
    rw [trSumFrom, List.length_cons, Finset.sum_range_succ', add_zero,
      add_comm (∑ j ∈ range rs.length, g (ptr.length + (j + 1)))]
    refine add_le_add ?_ ?_
    · have h0 := h 0 (by simp)
      simpa using h0
    · refine (trSum_le_along er x g (ptr ++ [r]) rs (fun j hj => ?_)).trans (le_of_eq ?_)
      · have hj' := h (j + 1) (by simp; omega)
        simp only [List.take_succ_cons, List.getElem_cons_succ] at hj'
        rw [List.length_append, List.length_singleton, show ptr.length + 1 + j = ptr.length + (j + 1) by omega,
          List.append_assoc, List.singleton_append]
        exact hj'
      · refine sum_congr rfl (fun j _ => ?_)
        rw [List.length_append, List.length_singleton, show ptr.length + 1 + j = ptr.length + (j + 1) by omega]

omit [Fintype D] [Nonempty D] in
/-- **The path-wise charge.** If every round charged along `τ` (its owner in the zone its message chose) is owned by a
sub-protocol of `Zb`, the zone charge of `τ` is at most the sum of `Zb`'s round errors over the first `n` rounds. -/
theorem trSum_zone_le [DecidableEq J] (own : ℕ → J) (er : ℕ → ℝ≥0∞)
    (zone : X → List (M × List D) → M → Finset J) (x : X) (τ : List (M × List D)) (n : ℕ) (hτ : τ.length ≤ n)
    (Zb : Finset J) (hZ : ∀ i (hi : i < τ.length), own i ∈ zone x (τ.take i) (τ[i]).1 → own i ∈ Zb) :
    trSumFrom (zEr own er zone) x [] τ ≤ ∑ i ∈ range n, (if own i ∈ Zb then er i else 0) := by
  refine (trSum_le_along (zEr own er zone) x (fun i => if own i ∈ Zb then er i else 0) [] τ
    (fun j hj => ?_)).trans ?_
  · simp only [zEr, List.nil_append, List.length_nil, zero_add, List.length_take, min_eq_left hj.le]
    split_ifs with h1 h2
    · exact le_rfl
    · exact absurd (hZ j hj h1) h2
    · exact zero_le
    · exact le_rfl
  · simp only [List.length_nil, zero_add]
    exact Finset.sum_le_sum_of_subset (range_subset_range.mpr hτ)

omit [Fintype D] [Nonempty D] in
/-- Every zone charge is at most the round's error. -/
theorem zEr_le [DecidableEq J] (own : ℕ → J) (er : ℕ → ℝ≥0∞) (zone : X → List (M × List D) → M → Finset J)
    (x : X) (τ : List (M × List D)) (m : M) : zEr own er zone x τ m ≤ er τ.length := by
  unfold zEr
  split_ifs
  · exact le_rfl
  · exact zero_le

end Zone

/-! ## The composition with zones on the chain -/

section ZoneFS

variable {X M D J Q : Type} [Fintype D] [Nonempty D] [Fintype Q] [DecidableEq Q] [DecidableEq D]

/-- **The path-wise bound on the code's chain.** For a composition with zones (`ZComposed`) whose false statements doom
some sub-protocol of the starting zone (`hstart`) and whose verifier rejects whenever a sub-protocol of the zone in
force at the end is doomed (`hfinal`): a prover making at most `q` hash queries gets a false statement accepted with
probability at most `q·εmax + B + collBound T D + collBound (T + 1) D`, `T = q + ℓW n w + 1`, for any `εmax` above
every round's error and any `B` above the zone charges along every transcript. -/
theorem fs_chain_sound_of_zcomposed [LinearOrder J] {n : ℕ} {w : ℕ → ℕ} {hasMsg : ℕ → Bool} {m₀ : M}
    (hw : ∀ i, 0 < w i) (C : ChainEnc (PItem X M) Q D) {Mf : Type} {L : X → Prop}
    {accept : X → List (M × List D) → Mf → Prop} {own : ℕ → J} {S : J → X → List (M × List D) → Prop}
    {pre : J → X → List (M × List D) → M → Prop} {er : ℕ → ℝ≥0∞} {zone₀ : X → Finset J}
    {zone : X → List (M × List D) → M → Finset J} (h : ZComposed n w own S pre er zone₀ zone)
    (εmax : ℝ≥0∞) (hε : ∀ i, i < n → er i ≤ εmax) (B : ℝ≥0∞)
    (hB : ∀ x τ, τ.length ≤ n → trSumFrom (zEr own er zone) x [] τ ≤ B)
    (hstart : ∀ x, ¬ L x → ∃ j ∈ zone₀ x, ¬ S j x [])
    (hfinal : ∀ x τ mf, τ.length = n → (∃ j ∈ lastZone zone₀ zone x τ, ¬ S j x τ) → ¬ accept x τ mf)
    (q : ℕ) (A : OC Q D (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1
        ∧ chainAcceptsW n w hw hasMsg m₀ accept C H (A.run H).1 (A.run H).2.1 (A.run H).2.2)
      ≤ (q : ℝ≥0∞) * εmax + B + collBound (q + ℓW n w + 1) D + collBound (q + ℓW n w + 1 + 1) D :=
  fs_chain_sound_of_rbrWideT hw C h.rbrWideT εmax
    (fun x τ m hτ => (zEr_le own er zone x τ m).trans (hε _ hτ)) B hB
    (fun x hx hall => by
      obtain ⟨j, hj, hd⟩ := hstart x hx
      exact hd (hall j (by rw [lastZone_nil]; exact hj)))
    (fun x τ mf hl hns => hfinal x τ mf hl (by
      by_contra hno
      push Not at hno
      exact hns hno)) q A hA

/-- **The path-wise bound, in its path form.** If along every transcript the rounds charged are owned by the
sub-protocols of one set `Zb` (the sub-protocols of the doom's hand-off path) whose round errors sum to at most `B`,
the query-free part is `B`: `q·εmax + B + collision terms`. -/
theorem fs_chain_sound_of_zpath [LinearOrder J] {n : ℕ} {w : ℕ → ℕ} {hasMsg : ℕ → Bool} {m₀ : M}
    (hw : ∀ i, 0 < w i) (C : ChainEnc (PItem X M) Q D) {Mf : Type} {L : X → Prop}
    {accept : X → List (M × List D) → Mf → Prop} {own : ℕ → J} {S : J → X → List (M × List D) → Prop}
    {pre : J → X → List (M × List D) → M → Prop} {er : ℕ → ℝ≥0∞} {zone₀ : X → Finset J}
    {zone : X → List (M × List D) → M → Finset J} (h : ZComposed n w own S pre er zone₀ zone)
    (εmax : ℝ≥0∞) (hε : ∀ i, i < n → er i ≤ εmax) (B : ℝ≥0∞)
    (hpath : ∀ x (τ : List (M × List D)), τ.length ≤ n → ∃ Zb : Finset J,
      (∀ i (hi : i < τ.length), own i ∈ zone x (τ.take i) (τ[i]).1 → own i ∈ Zb)
      ∧ ∑ i ∈ range n, (if own i ∈ Zb then er i else 0) ≤ B)
    (hstart : ∀ x, ¬ L x → ∃ j ∈ zone₀ x, ¬ S j x [])
    (hfinal : ∀ x τ mf, τ.length = n → (∃ j ∈ lastZone zone₀ zone x τ, ¬ S j x τ) → ¬ accept x τ mf)
    (q : ℕ) (A : OC Q D (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1
        ∧ chainAcceptsW n w hw hasMsg m₀ accept C H (A.run H).1 (A.run H).2.1 (A.run H).2.2)
      ≤ (q : ℝ≥0∞) * εmax + B + collBound (q + ℓW n w + 1) D + collBound (q + ℓW n w + 1 + 1) D :=
  fs_chain_sound_of_zcomposed hw C h εmax hε B
    (fun x τ hτ => by
      obtain ⟨Zb, hZ, hsum⟩ := hpath x τ hτ
      exact (trSum_zone_le own er zone x τ n hτ Zb hZ).trans hsum) hstart hfinal q A hA

end ZoneFS

/-! ## Task 1: the sharper count for `FSCompose.lean`'s compositions -/

section Sharper

variable {X M D J Q : Type} [Fintype D] [Nonempty D]

/-- **One fixed zone**: every sub-protocol that can be doomed. A composition of `FSCompose.lean` is a composition with
zones, each sub-protocol's `pre` state being its state before the round. -/
theorem Composed.toZ [LinearOrder J] {n : ℕ} {w : ℕ → ℕ} {own : ℕ → J}
    {S : J → X → List (M × List D) → Prop} {er : ℕ → ℝ≥0∞} (h : Composed n w own S er)
    (B : Finset J) (hB : ∀ j x τ, ¬ S j x τ → j ∈ B) :
    ZComposed n w own S (fun j x τ _ => S j x τ) er (fun _ => B) (fun _ _ _ => B) where
  own_round x τ m hτ hns := h.own_round x τ m hτ hns
  hand x τ m _ hd := by
    obtain ⟨j, hj, hd⟩ := hd
    rw [lastZone_const] at hj
    exact ⟨j, hj, hd⟩
  frame j x τ m b hτ ho _ hj hs := by
    obtain ⟨j', hlt, hd⟩ := h.frame j x τ m b hτ ho hj hs
    exact ⟨j', hB j' x τ hd, hlt, hd⟩

variable [Fintype Q] [DecidableEq Q] [DecidableEq D]

/-- **The sharper Fiat–Shamir count (task 1).** For a composition of `FSCompose.lean`: a prover making at most `q` hash
queries gets a false statement accepted with probability at most `q·εmax + Σ_{i<n} er i + collBound T D +
collBound (T + 1) D`. Each of the verifier's own hash positions is charged its own round's error, so the query-free
part is the interactive union of the rounds, not `(ℓW + 1)·εmax`. -/
theorem fs_chain_sound_of_composed_sum [LinearOrder J] {n : ℕ} {w : ℕ → ℕ} {hasMsg : ℕ → Bool} {m₀ : M}
    (hw : ∀ i, 0 < w i) (C : ChainEnc (PItem X M) Q D) {Mf : Type} {L : X → Prop}
    {accept : X → List (M × List D) → Mf → Prop} {own : ℕ → J} {S : J → X → List (M × List D) → Prop}
    {er : ℕ → ℝ≥0∞} (h : Composed n w own S er) (B : Finset J) (hB : ∀ j x τ, ¬ S j x τ → j ∈ B)
    (εmax : ℝ≥0∞) (hε : ∀ i, i < n → er i ≤ εmax)
    (hstart : ∀ x, ¬ L x → ∃ j, ¬ S j x [])
    (hfinal : ∀ x τ mf, τ.length = n → (∃ j, ¬ S j x τ) → ¬ accept x τ mf)
    (q : ℕ) (A : OC Q D (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1
        ∧ chainAcceptsW n w hw hasMsg m₀ accept C H (A.run H).1 (A.run H).2.1 (A.run H).2.2)
      ≤ (q : ℝ≥0∞) * εmax + ∑ i ∈ range n, er i + collBound (q + ℓW n w + 1) D
        + collBound (q + ℓW n w + 1 + 1) D := by
  classical
  refine fs_chain_sound_of_zcomposed hw C (h.toZ B hB) εmax hε _ (fun x τ hτ => ?_)
    (fun x hx => by
      obtain ⟨j, hj⟩ := hstart x hx
      exact ⟨j, hB j x [] hj, hj⟩)
    (fun x τ mf hl hd => by
      obtain ⟨j, -, hj⟩ := hd
      exact hfinal x τ mf hl ⟨j, hj⟩) q A hA
  refine (trSum_le_along _ x er [] τ (fun j hj => ?_)).trans ?_
  · simp only [List.length_nil, zero_add]
    refine (zEr_le own er _ x _ _).trans (le_of_eq ?_)
    rw [List.nil_append, List.length_take, min_eq_left hj.le]
  · simp only [List.length_nil, zero_add]
    exact Finset.sum_le_sum_of_subset (range_subset_range.mpr hτ)

/-- The error of round `i` of a schedule: its sub-protocol's error (`0` past the end). -/
noncomputable def erOf : List (SubProt X M D) → ℕ → ℝ≥0∞
  | [], _ => 0
  | c :: cs, i => if i < c.n then c.ε else erOf cs (i - c.n)

omit [DecidableEq D] in
/-- **A schedule's rounds' errors add up to `Σ_k n_k·ε_k`.** -/
theorem sum_erOf : ∀ cs : List (SubProt X M D),
    ∑ i ∈ range (nOf cs), erOf cs i = (cs.map (fun c => (c.n : ℝ≥0∞) * c.ε)).sum
  | [] => by simp [nOf, erOf]
  | c :: cs => by
    rw [nOf, Finset.sum_range_add, List.map_cons, List.sum_cons, ← sum_erOf cs]
    congr 1
    · rw [sum_congr rfl (fun i hi => (show erOf (c :: cs) i = c.ε by simp [erOf, mem_range.mp hi])),
        sum_const, card_range, nsmul_eq_mul]
    · exact sum_congr rfl (fun i _ => by simp [erOf])

omit [DecidableEq D] in
/-- A schedule's round error is at most its largest sub-protocol error. -/
theorem erOf_le : ∀ (cs : List (SubProt X M D)) (ε : ℝ≥0∞), (∀ c ∈ cs, c.ε ≤ ε) → ∀ i, erOf cs i ≤ ε
  | [], _, _, _ => zero_le
  | c :: cs, ε, h, i => by
    simp only [erOf]
    split_ifs
    · exact h c List.mem_cons_self
    · exact erOf_le cs ε (fun c' hc' => h c' (List.mem_cons_of_mem _ hc')) _

omit [DecidableEq D] in
/-- A schedule's own rounds are bounded by their sub-protocols' errors. -/
theorem sched_composed_erOf (cs : List (SubProt X M D))
    (hframe : ∀ k x τ m (b : Fin (wOf cs τ.length) → D), τ.length < nOf cs → ownOf cs τ.length ≠ k →
      ¬ SOf cs k x τ → SOf cs k x (τ ++ [(m, List.ofFn b)]) → ∃ k', k < k' ∧ ¬ SOf cs k' x τ) :
    Composed (nOf cs) (wOf cs) (ownOf cs) (SOf cs) (erOf cs) where
  own_round x τ m hτ hns := by
    obtain ⟨c, hc, h1, h2, hw, -⟩ := ownOf_spec cs τ.length hτ
    refine (window_round c.rbr (offs cs (ownOf cs τ.length)) (wOf cs) (SOf cs (ownOf cs τ.length))
      (fun x' τ' ha hb => SOf_win hc x' τ' ha hb) x τ m h1 h2 hw hns).trans (le_of_eq ?_)
    -- the round's error is its sub-protocol's
    have key : ∀ (cs : List (SubProt X M D)) (i : ℕ) (c : SubProt X M D), i < nOf cs →
        cs[ownOf cs i]? = some c → erOf cs i = c.ε := by
      intro cs
      induction cs with
      | nil => intro i c hi; simp [nOf] at hi
      | cons c' cs ih =>
        intro i c hi hc
        by_cases hlt : i < c'.n
        · simp only [ownOf, hlt, ↓reduceIte, List.getElem?_cons_zero, Option.some.injEq] at hc
          subst hc
          simp [erOf, hlt]
        · simp only [ownOf, hlt, ↓reduceIte, List.getElem?_cons_succ] at hc
          simp only [erOf, hlt, ↓reduceIte]
          exact ih (i - c'.n) c (by simp only [nOf] at hi; omega) hc
    exact (key cs τ.length c hτ hc).symm
  frame := hframe

/-- **The sharper count on a schedule (task 1).** `FSCompose.lean`'s `fs_chain_sound_sched` with each verifier hash
position charged its own round's error: `q·ε + Σ_k n_k·ε_k + collBound T D + collBound (T + 1) D`. -/
theorem fs_chain_sound_sched_sum (cs : List (SubProt X M D)) (hwpos : ∀ c ∈ cs, ∀ i, 0 < c.w i) {m₀ : M}
    (C : ChainEnc (PItem X M) Q D) {Mf : Type} {L : X → Prop} {accept : X → List (M × List D) → Mf → Prop}
    (ε : ℝ≥0∞) (hε : ∀ c ∈ cs, c.ε ≤ ε)
    (hframe : ∀ k x τ m (b : Fin (wOf cs τ.length) → D), τ.length < nOf cs → ownOf cs τ.length ≠ k →
      ¬ SOf cs k x τ → SOf cs k x (τ ++ [(m, List.ofFn b)]) → ∃ k', k < k' ∧ ¬ SOf cs k' x τ)
    (hstart : ∀ x, ¬ L x → ∃ k, ¬ SOf cs k x [])
    (hfinal : ∀ x τ mf, τ.length = nOf cs → (∃ k, ¬ SOf cs k x τ) → ¬ accept x τ mf)
    (q : ℕ) (A : OC Q D (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1
        ∧ chainAcceptsW (nOf cs) (wOf cs) (wOf_pos cs hwpos) (msgOf cs) m₀ accept C H (A.run H).1 (A.run H).2.1
          (A.run H).2.2)
      ≤ (q : ℝ≥0∞) * ε + (cs.map (fun c => (c.n : ℝ≥0∞) * c.ε)).sum
        + collBound (q + ℓW (nOf cs) (wOf cs) + 1) D + collBound (q + ℓW (nOf cs) (wOf cs) + 1 + 1) D := by
  rw [← sum_erOf cs]
  exact fs_chain_sound_of_composed_sum (wOf_pos cs hwpos) C (sched_composed_erOf cs hframe) (range cs.length)
    (SOf_doomed_mem cs) ε (fun i _ => erOf_le cs ε hε i) hstart hfinal q A hA

end Sharper

end ZK60.Sound
