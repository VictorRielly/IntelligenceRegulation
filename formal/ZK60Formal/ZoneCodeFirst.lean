/-
D63 lane L24 (2026-11-07), part 2: **the first-doom count on the code's chain** (D66(4)'s path-wise count, carried to
the knowledge setting on the code's chain; finding L18-2).

L20's per-position count (`fs_code_chain_sound_sched_log_pos`) charges the verifier's own chain the SUM over every
sub-protocol of the schedule of its rounds times its error. On the whole classify run that sum covers 26 blocks and the
two stages, about `2^-99.5` (L18-2), and summing 26 per-block bounds of `εsTarget` is worse. D66(4)'s path-wise count
(`FSPath.lean`, the model chain) follows ONE doom inside one block zone. In the KNOWLEDGE setting the doom is even more
local: each sub-protocol's claim is about the data extracted from the prover's log, so a false claim is a doom of that
sub-protocol alone, and the proof can follow the FIRST sub-protocol that entered its window doomed. With no releases
(the knowledge schedules of L16, L20 and L21 release nothing) that sub-protocol can be revived only in its own rounds:

* `EntD`, `entD_append`: a sub-protocol entered its window with a false claim (a property of the header, so it does not
  change as the chain grows);
* `SortedA`, `IsFirst`, `exists_isFirst`, `isFirst_unique`, `isFirst_append`, `isFirst_take`, `firstK`,
  `firstK_eq_some_iff`: the first such sub-protocol (the smallest index; with windows in order it never changes once
  chosen);
* `firstSt`, **`firstSt_rbr`**: the state "the first doomed sub-protocol is alive" is round-by-round with the charge
  `firstCharge`: a step is charged the first doomed sub-protocol's error only when it starts one of ITS rounds;
* `everG`, `everG_rbr`, `everG_congr`: doomed at some step's end, alive now, for any state;
* `vSumFrom_le_along`, `vSumFrom_zero`, **`firstCharge_vSum_le`**: along ANY chain the verifier's charge is at most
  `max_c n_c·ε_c` (one sub-protocol's rounds, NOT the sum over the schedule);
* **`fs_code_chain_first_log`**: a family of schedules indexed by the prover's log, each sub-protocol `RbrWide` with its
  error `≤ εmax`, no releases, windows in order and after `s` entries, `n_c·ε_c ≤ B` for every sub-protocol, the first-doom
  state stable at the escaping step (`hstab`): the probability that some sub-protocol enters its window with a false
  claim and yet every sub-protocol is alive at the end is at most `q·εmax + B + collBound T + collBound (T + 1)`,
  `T = q + ℓ + 1`. The prover's `q` queries keep the largest error; the verifier's whole chain costs ONE sub-protocol's
  rounds.

Applied to a schedule over all blocks of the run (and the stages), `B` is the largest single sub-protocol's `n·ε`
(LogUp's three squeezes, `M`'s three rounds, one opening's round), not 26 blocks' sum: that is the one-zone floor of
D66(4), here one sub-protocol. Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.ZoneCodeWide
import ZK60Formal.CountW16Chain

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Sound
open scoped ENNReal

/-! ## The first sub-protocol that entered its window doomed -/

section First

variable {D : Type}

/-- **A sub-protocol entered its window with a false claim** on a chain: its window has started at a step's end and
its state of the header with no rounds read is doomed. -/
def EntD (W : UInt64 → ℕ) (c : CSub D) (τ : List (TItem × D)) : Prop :=
  c.a ≤ τ.length ∧ tRem W (τ.take c.a) = some 0 ∧ ¬ c.St (τ.take c.a) []

/-- Entering doomed is a property of the header: extending the chain does not change it. -/
theorem entD_append (W : UInt64 → ℕ) (c : CSub D) (τ ext : List (TItem × D)) (ha : c.a ≤ τ.length) :
    EntD W c (τ ++ ext) ↔ EntD W c τ := by
  unfold EntD
  rw [List.take_append_of_le_length ha, List.length_append]
  constructor
  · rintro ⟨-, h2, h3⟩
    exact ⟨ha, h2, h3⟩
  · rintro ⟨-, h2, h3⟩
    exact ⟨by omega, h2, h3⟩

/-- **Windows in order**: a later sub-protocol of the schedule never opens its window before an earlier one. -/
def SortedA (cs : List (CSub D)) : Prop :=
  ∀ (i j : ℕ) (ci cj : CSub D), i < j → cs[i]? = some ci → cs[j]? = some cj → ci.a ≤ cj.a

/-- **Sub-protocol `k` is the first that entered its window doomed** (the smallest such index). -/
def IsFirst (W : UInt64 → ℕ) (cs : List (CSub D)) (τ : List (TItem × D)) (k : ℕ) : Prop :=
  (∃ c, cs[k]? = some c ∧ EntD W c τ) ∧ ∀ j, j < k → ∀ c, cs[j]? = some c → ¬ EntD W c τ

theorem exists_isFirst {W : UInt64 → ℕ} {cs : List (CSub D)} {τ : List (TItem × D)}
    (h : ∃ (k : ℕ) (c : CSub D), cs[k]? = some c ∧ EntD W c τ) : ∃ k, IsFirst W cs τ k := by
  classical
  exact ⟨Nat.find h, Nat.find_spec h, fun j hj c hc he => Nat.find_min h hj ⟨c, hc, he⟩⟩

theorem isFirst_unique {W : UInt64 → ℕ} {cs : List (CSub D)} {τ : List (TItem × D)} {k k' : ℕ}
    (h : IsFirst W cs τ k) (h' : IsFirst W cs τ k') : k = k' := by
  obtain ⟨⟨c, hc, he⟩, hmin⟩ := h
  obtain ⟨⟨c', hc', he'⟩, hmin'⟩ := h'
  rcases Nat.lt_trichotomy k k' with hlt | heq | hgt
  · exact absurd he (hmin' k hlt c hc)
  · exact heq
  · exact absurd he' (hmin k' hgt c' hc')

/-- **The first doomed entrant is kept as the chain grows** (windows in order: a smaller index opened its window no
later, so its status was already decided). -/
theorem isFirst_append (W : UInt64 → ℕ) (cs : List (CSub D)) (hs : SortedA cs) (τ ext : List (TItem × D)) {k : ℕ}
    (h : IsFirst W cs τ k) : IsFirst W cs (τ ++ ext) k := by
  obtain ⟨⟨ck, hck, hek⟩, hmin⟩ := h
  refine ⟨⟨ck, hck, (entD_append W ck τ ext hek.1).mpr hek⟩, fun j hj cj hcj hej => ?_⟩
  have hle : cj.a ≤ ck.a := hs j k cj ck hj hcj hck
  exact hmin j hj cj hcj ((entD_append W cj τ ext (hle.trans hek.1)).mp hej)

/-- **The first doomed entrant was already first at its own window's start.** -/
theorem isFirst_take (W : UInt64 → ℕ) (cs : List (CSub D)) (hs : SortedA cs) (τ : List (TItem × D)) {k : ℕ}
    {c : CSub D} (h : IsFirst W cs τ k) (hc : cs[k]? = some c) : IsFirst W cs (τ.take c.a) k := by
  obtain ⟨⟨ck, hck, hek⟩, hmin⟩ := h
  have hec : EntD W c τ := by
    rw [← Option.some.inj (hck.symm.trans hc)]
    exact hek
  have hlen : c.a ≤ (τ.take c.a).length := by
    rw [List.length_take]
    exact le_min le_rfl hec.1
  refine ⟨⟨c, hc, ?_⟩, fun j hj cj hcj hej => ?_⟩
  · have h1 := entD_append W c (τ.take c.a) (τ.drop c.a) hlen
    rw [List.take_append_drop] at h1
    exact h1.mp hec
  · have hle : cj.a ≤ c.a := hs j k cj c hj hcj hc
    have h1 := entD_append W cj (τ.take c.a) (τ.drop c.a) (hle.trans hlen)
    rw [List.take_append_drop] at h1
    exact hmin j hj cj hcj (h1.mpr hej)

/-- At its own window's start a doomed entrant is doomed (no release). -/
theorem not_subSt_of_entD_take (W : UInt64 → ℕ) (c : CSub D) (τ : List (TItem × D)) (he : EntD W c τ)
    (hrel : ¬ c.rel (τ.take c.a)) : ¬ subSt W c (τ.take c.a) := by
  rintro (h1 | ⟨-, h2⟩ | h3)
  · rw [List.length_take, min_eq_left he.1] at h1
    omega
  · rw [List.take_take, min_self, List.drop_eq_nil_of_le (by rw [List.length_take]; omega)] at h2
    exact he.2.2 h2
  · exact hrel h3

open Classical in
/-- The index of the first doomed entrant, if any. -/
noncomputable def firstK (W : UInt64 → ℕ) (cs : List (CSub D)) (τ : List (TItem × D)) : Option ℕ :=
  if h : ∃ k, IsFirst W cs τ k then some (Classical.choose h) else none

theorem firstK_eq_some_iff {W : UInt64 → ℕ} {cs : List (CSub D)} {τ : List (TItem × D)} {k : ℕ} :
    firstK W cs τ = some k ↔ IsFirst W cs τ k := by
  classical
  unfold firstK
  by_cases hex : ∃ k, IsFirst W cs τ k
  · rw [dite_eq_left hex]
    constructor
    · intro h
      obtain rfl := Option.some.inj h
      exact Classical.choose_spec hex
    · intro h
      exact congrArg some (isFirst_unique (Classical.choose_spec hex) h)
  · rw [dite_eq_right hex]
    constructor
    · intro h
      cases h
    · intro h
      exact absurd ⟨k, h⟩ hex

/-- **The first-doom state**: the first sub-protocol that entered its window doomed (if any) is alive. -/
def firstSt (W : UInt64 → ℕ) (cs : List (CSub D)) (τ : List (TItem × D)) : Prop :=
  ∀ (k : ℕ) (c : CSub D), IsFirst W cs τ k → cs[k]? = some c → subSt W c τ

open Classical in
/-- **The first-doom charge of a step**: the first doomed entrant's error when the step starts one of its rounds,
else `0`. -/
noncomputable def firstCharge (W : UInt64 → ℕ) (cs : List (CSub D)) (τ : List (TItem × D)) (h : TItem) : ℝ≥0∞ :=
  match firstK W cs τ with
  | none => 0
  | some k =>
    match cs[k]? with
    | none => 0
    | some c => if Charged W c.sk τ h then c.ε else 0

theorem firstCharge_of_charged {W : UInt64 → ℕ} {cs : List (CSub D)} {τ : List (TItem × D)} {h : TItem} {k : ℕ}
    {c : CSub D} (hk : IsFirst W cs τ k) (hc : cs[k]? = some c) (hch : Charged W c.sk τ h) :
    firstCharge W cs τ h = c.ε := by
  unfold firstCharge
  rw [firstK_eq_some_iff.mpr hk]
  dsimp only
  rw [hc]
  dsimp only
  exact ite_eq_left hch

theorem firstCharge_le (W : UInt64 → ℕ) (cs : List (CSub D)) (εmax : ℝ≥0∞) (hε : ∀ c ∈ cs, c.ε ≤ εmax)
    (τ : List (TItem × D)) (h : TItem) : firstCharge W cs τ h ≤ εmax := by
  unfold firstCharge
  rcases _hK : firstK W cs τ with _ | k
  · exact zero_le
  · dsimp only
    rcases hc : cs[k]? with _ | c
    · exact zero_le
    · dsimp only
      split_ifs
      · exact hε c (List.mem_of_getElem? hc)
      · exact zero_le

/-- A chain shorter than every window has no doomed entrant. -/
theorem firstSt_short (W : UInt64 → ℕ) (cs : List (CSub D)) (τ : List (TItem × D))
    (hsh : ∀ c ∈ cs, τ.length < c.a) : firstSt W cs τ := by
  intro k c hkf _
  obtain ⟨c', hc', he⟩ := hkf.1
  exact absurd he.1 (not_le.mpr (hsh c' (List.mem_of_getElem? hc')))

end First

/-! ## Doomed at some step's end, alive now -/

section Ever

variable {D : Type}

/-- **Doomed at some earlier step's end, alive now** (L8's `everSt`, for any state `Φ`). -/
def everG (W : UInt64 → ℕ) (Φ : List (TItem × D) → Prop) (τ : List (TItem × D)) : Prop :=
  Φ τ ∧ ∃ j, j ≤ τ.length ∧ tRem W (τ.take j) = some 0 ∧ ¬ Φ (τ.take j)

/-- Two states agreeing on every prefix of a chain have the same `everG` there. -/
theorem everG_congr (W : UInt64 → ℕ) (Φ Φ' : List (TItem × D) → Prop) (X : List (TItem × D))
    (h : ∀ τ', τ' <+: X → (Φ τ' ↔ Φ' τ')) : everG W Φ X ↔ everG W Φ' X := by
  unfold everG
  constructor
  · rintro ⟨h1, j, hj, ht, hc⟩
    exact ⟨(h X (List.prefix_refl X)).mp h1, j, hj, ht, fun h' => hc ((h _ (List.take_prefix j X)).mpr h')⟩
  · rintro ⟨h1, j, hj, ht, hc⟩
    exact ⟨(h X (List.prefix_refl X)).mpr h1, j, hj, ht, fun h' => hc ((h _ (List.take_prefix j X)).mp h')⟩

/-- A chain shorter than every window is never doomed-then-alive for the first-doom state. -/
theorem not_everG_first_short (W : UInt64 → ℕ) (cs : List (CSub D)) (τ : List (TItem × D))
    (hsh : ∀ c ∈ cs, τ.length < c.a) : ¬ everG W (firstSt W cs) τ := by
  rintro ⟨-, j, -, -, hc⟩
  refine hc (firstSt_short W cs _ (fun c hc' => lt_of_le_of_lt ?_ (hsh c hc')))
  rw [List.length_take]
  exact min_le_right _ _

/-- **From the event to the first-doom state**: if some sub-protocol entered its window doomed and every sub-protocol
is alive at the end, the first doomed entrant was doomed at its window's start and is alive at the end. -/
theorem everG_first_of_event (W : UInt64 → ℕ) (cs : List (CSub D)) (hs : SortedA cs)
    (hnorel : ∀ c ∈ cs, ∀ τ, ¬ c.rel τ) (τ : List (TItem × D))
    (hent : ∃ (k : ℕ) (c : CSub D), cs[k]? = some c ∧ EntD W c τ) (hall : allSt W cs τ) :
    everG W (firstSt W cs) τ := by
  obtain ⟨K, hK⟩ := exists_isFirst hent
  obtain ⟨cK, hcK, heK⟩ := hK.1
  refine ⟨fun k c _ hc => hall k c hc, cK.a, heK.1, heK.2.1, fun h => ?_⟩
  have hK' := isFirst_take W cs hs τ hK hcK
  exact not_subSt_of_entD_take W cK τ heK (hnorel cK (List.mem_of_getElem? hcK) _) (h K cK hK' hcK)

variable [Fintype D] [Nonempty D]

/-- **Doomed at a later step's end costs nothing extra** (L20's `everSt_rbr_pos` for any state). -/
theorem everG_rbr (W : UInt64 → ℕ) (Φ : List (TItem × D) → Prop) (e : List (TItem × D) → TItem → ℝ≥0∞)
    (hA : CodeRbrE W Φ e) : CodeRbrE W (everG W Φ) e := by
  intro τ h ks hτ hk hns
  by_cases hal : Φ τ
  · have hall : ∀ j, j ≤ τ.length → tRem W (τ.take j) = some 0 → Φ (τ.take j) := by
      intro j hj ht
      by_contra hc
      exact hns ⟨hal, j, hj, ht, hc⟩
    have hE : ∀ b : Fin (ks.length + 1) → D, ¬ everG W Φ (τ ++ stE h ks (List.ofFn b)) := by
      rintro b ⟨hb1, j, hj, ht, hc⟩
      have hlen : (stE h ks (List.ofFn b)).length = ks.length + 1 := stE_length _ _ _ List.length_ofFn
      rw [List.length_append, hlen] at hj
      by_cases hj1 : j ≤ τ.length
      · rw [List.take_append_of_le_length hj1] at ht hc
        exact hc (hall j hj1 ht)
      · by_cases hj2 : j = τ.length + (ks.length + 1)
        · rw [List.take_of_length_le (show (τ ++ stE h ks (List.ofFn b)).length ≤ j by
            rw [List.length_append, hlen]; omega)] at hc
          exact hc hb1
        · rw [List.take_append, List.take_of_length_le (show τ.length ≤ j by omega)] at ht
          exact tRem_stE_take W hτ h ks _ hk List.length_ofFn (j - τ.length) (by omega) (by omega) ht
    have hE' : {b : Fin (ks.length + 1) → D | everG W Φ (τ ++ stE h ks (List.ofFn b))} = ∅ :=
      Set.eq_empty_iff_forall_notMem.mpr (fun b hb => hE b hb)
    rw [hE', MeasureTheory.measure_empty]
    exact zero_le
  · exact (MeasureTheory.measure_mono (fun b hb => hb.1)).trans (hA τ h ks hτ hk hal)

/-- **The first-doom state is round-by-round with the first-doom charge.** From a doomed chain, the first doomed
entrant `c` is still first after the step (windows in order); it is revived only by its own reading (no release), with
probability at most its error, and only by a step that starts one of its rounds. -/
theorem firstSt_rbr (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) (cs : List (CSub D)) (hs : SortedA cs)
    (hR : ∀ c ∈ cs, RbrWide c.R.n c.R.w c.St c.ε) (hnorel : ∀ c ∈ cs, ∀ τ, ¬ c.rel τ) :
    CodeRbrE W (firstSt W cs) (firstCharge W cs) := by
  intro τ h ks hτ hk hns
  have hex : ∃ (k : ℕ) (c : CSub D), IsFirst W cs τ k ∧ cs[k]? = some c ∧ ¬ subSt W c τ := by
    by_contra hno
    apply hns
    intro k c hkf hc
    by_contra hd
    exact hno ⟨k, c, hkf, hc, hd⟩
  obtain ⟨k, c, hkf, hc, hd⟩ := hex
  have he : EntD W c τ := by
    obtain ⟨c', hc', he'⟩ := hkf.1
    have hcc : c' = c := Option.some.inj (hc'.symm.trans hc)
    rw [← hcc]
    exact he'
  have ha : c.a ≤ τ.length := he.1
  have hnsA : ¬ rdAlive W c τ := fun h' => hd (Or.inr (Or.inl h'))
  have hmem : c ∈ cs := List.mem_of_getElem? hc
  have hsub : {b : Fin (ks.length + 1) → D | firstSt W cs (τ ++ stE h ks (List.ofFn b))}
      ⊆ {b | rdAlive W c (τ ++ stE h ks (List.ofFn b))} := by
    intro b hb
    rcases hb k c (isFirst_append W cs hs τ _ hkf) hc with h1 | h1 | h1
    · simp only [List.length_append] at h1
      omega
    · exact h1
    · exact absurd h1 (hnorel c hmem _)
  have hstep := rdAlive_step W hW c (hR c hmem) τ h ks hτ hk ha hnsA
  by_cases hch : Charged W c.sk τ h
  · rw [firstCharge_of_charged hkf hc hch]
    exact (MeasureTheory.measure_mono hsub).trans hstep
  · have hempty : {b : Fin (ks.length + 1) → D | firstSt W cs (τ ++ stE h ks (List.ofFn b))} = ∅ := by
      refine Set.eq_empty_iff_forall_notMem.mpr (fun b hb => ?_)
      exact hch (rdAlive_charged W hW c τ h ks (List.ofFn b) hτ hk List.length_ofFn ha hnsA (hsub hb))
    rw [hempty, MeasureTheory.measure_empty]
    exact zero_le

end Ever

/-! ## The verifier's first-doom charge along any chain: one sub-protocol's rounds -/

section Charge

variable {D : Type}

/-- **The verifier's charge is monotone along a chain**: pointwise at every step of the chain. -/
theorem vSumFrom_le_along {It' Q : Type} (C : ChainEnc It' Q D) (e e' : List (It' × D) → It' → ℝ≥0∞) (H : Q → D) :
    ∀ (τ : List (It' × D)) (its : List It'),
      (∀ (j : ℕ) (hj : j < its.length),
        e (C.chainFrom H τ (its.take j)) its[j] ≤ e' (C.chainFrom H τ (its.take j)) its[j]) →
      C.vSumFrom e H τ its ≤ C.vSumFrom e' H τ its
  | τ, [], _ => by simp [ChainEnc.vSumFrom]
  | τ, it :: its, h => by
    simp only [ChainEnc.vSumFrom]
    refine add_le_add ?_ (vSumFrom_le_along C e e' H _ its (fun j hj => ?_))
    · exact h 0 (by simp)
    · exact h (j + 1) (by simp only [List.length_cons]; omega)

theorem vSumFrom_zero {It' Q : Type} (C : ChainEnc It' Q D) (H : Q → D) :
    ∀ (τ : List (It' × D)) (its : List It'), C.vSumFrom (fun _ _ => (0 : ℝ≥0∞)) H τ its = 0
  | _, [] => rfl
  | τ, it :: its => by
    simp only [ChainEnc.vSumFrom, zero_add]
    exact vSumFrom_zero C H _ its

/-- **The verifier's first-doom charge along ANY chain is at most one sub-protocol's `n·ε`**: the first doomed entrant
of the whole chain is the only one charged (at a prefix the first entrant, if any, is the whole chain's), and its
charged steps are at most its rounds (L20's potential, `vSumFrom_chargeC_nil_le`, for that one sub-protocol). -/
theorem firstCharge_vSum_le {It' Q : Type} (C : ChainEnc It' Q D) (toT : It' → TItem) (W : UInt64 → ℕ)
    (cs : List (CSub D)) (hs : SortedA cs) (B : ℝ≥0∞) (hB : ∀ c ∈ cs, (c.R.n : ℝ≥0∞) * c.ε ≤ B) (H : Q → D)
    (its : List It') :
    C.vSumFrom (fun τ it => firstCharge W cs (τ.map (toTE toT)) (toT it)) H [] its ≤ B := by
  have hpre : ∀ j, j ≤ its.length → ∃ ext, (C.chainFrom H [] its).map (toTE toT)
      = (C.chainFrom H [] (its.take j)).map (toTE toT) ++ ext := by
    intro j hj
    refine ⟨((C.chainFrom H [] its).drop j).map (toTE toT), ?_⟩
    rw [← C.chainFrom_take H its j hj, ← List.map_append, List.take_append_drop]
  rcases hKf : firstK W cs ((C.chainFrom H [] its).map (toTE toT)) with _ | k
  · -- no sub-protocol entered doomed on the whole chain: every charge is `0`
    refine (vSumFrom_le_along C _ (fun _ _ => (0 : ℝ≥0∞)) H [] its (fun j hj => ?_)).trans ?_
    · obtain ⟨ext, hext⟩ := hpre j hj.le
      show firstCharge W cs _ _ ≤ 0
      unfold firstCharge
      rcases hj' : firstK W cs ((C.chainFrom H [] (its.take j)).map (toTE toT)) with _ | k'
      · exact le_rfl
      · exfalso
        have h1 := isFirst_append W cs hs _ ext (firstK_eq_some_iff.mp hj')
        rw [← hext] at h1
        rw [firstK_eq_some_iff.mpr h1] at hKf
        cases hKf
    · rw [vSumFrom_zero]
      exact zero_le
  · obtain ⟨⟨c, hc, -⟩, -⟩ := firstK_eq_some_iff.mp hKf
    refine (vSumFrom_le_along C _ (fun τ it => chargeC W [c.sk] ⊤ (τ.map (toTE toT)) (toT it)) H [] its
      (fun j hj => ?_)).trans ((vSumFrom_chargeC_nil_le C toT W [c.sk] ⊤ H its).trans ?_)
    · obtain ⟨ext, hext⟩ := hpre j hj.le
      show firstCharge W cs _ _ ≤ chargeC W [c.sk] ⊤ _ _
      unfold firstCharge
      rcases hj' : firstK W cs ((C.chainFrom H [] (its.take j)).map (toTE toT)) with _ | k'
      · exact zero_le
      · have h1 := isFirst_append W cs hs _ ext (firstK_eq_some_iff.mp hj')
        rw [← hext] at h1
        have hkk : k' = k := Option.some.inj ((firstK_eq_some_iff.mpr h1).symm.trans hKf)
        rw [hkk]
        dsimp only
        rw [hc]
        dsimp only
        unfold chargeC
        refine le_min le_top ?_
        simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero]
        exact le_rfl
    · simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero]
      exact hB c (List.mem_of_getElem? hc)

end Charge

/-! ## The first-doom count on the code's chain -/

section Main

variable {D It' : Type} [Fintype D] [Nonempty D] [DecidableEq D] {Q : Type} [Fintype Q] [DecidableEq Q]

/-- **The first-doom count: the knowledge version of L8's composition with the verifier's chain charged ONE
sub-protocol's rounds** (D63 lane L24; finding L18-2, D66(4)). A family of schedules `cs P` indexed by the prover's log
(each sub-protocol's state may read the data extracted from it), each sub-protocol `RbrWide` with its error `≤ εmax`,
NO releases, windows in order and after `s` entries, `n_c·ε_c ≤ B` for every sub-protocol, and the first-doom state at
the log before the escaping step's first query agreeing with the state at the whole log on that chain and step
(`hstab`). A prover making at most `q` hash queries gets SOME sub-protocol to enter its window with a false claim and
yet EVERY sub-protocol alive at the end with probability at most `q·εmax + B + collBound T + collBound (T + 1)`,
`T = q + ℓ + 1`: the prover's queries at the largest error; the verifier's whole chain one sub-protocol's `n·ε`. -/
theorem fs_code_chain_first_log (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) {α : Type} (A : OC Q D α)
    (cs : List (Q × D) → List (CSub D)) (hsort : ∀ P, SortedA (cs P))
    (εmax : ℝ≥0∞) (hR : ∀ P, ∀ c ∈ cs P, RbrWide c.R.n c.R.w c.St c.ε) (hε : ∀ P, ∀ c ∈ cs P, c.ε ≤ εmax)
    (hnorel : ∀ P, ∀ c ∈ cs P, ∀ τ, ¬ c.rel τ)
    (B : ℝ≥0∞) (hB : ∀ P, ∀ c ∈ cs P, (c.R.n : ℝ≥0∞) * c.ε ≤ B)
    (C : ChainEnc It' Q D) (toT : It' → TItem) (S : Steps It') (hS : StepsOK W toT S)
    (heads : α → List It') (ℓ : ℕ) (hℓ : ∀ o, ((heads o).flatMap S.items).length ≤ ℓ)
    (s : ℕ) (hwin : ∀ P, ∀ c ∈ cs P, s < c.a) (hhd : ∀ o, (((heads o).take s).flatMap S.items).length ≤ s)
    (hstab : ∀ (H : Q → D) (L : List (Q × D)) (t : ℕ) (τ : List (It' × D)) (qs : List Q) (it : It') (e2 : D),
      C.Chain H τ qs → s ≤ τ.length → (∃ hs : List It', τ.map Prod.fst = hs.flatMap S.items) →
      (∀ z ∈ qs, z ∈ (L.take t).map Prod.fst) → (∀ e ∈ L, e.2 = H e.1) →
      L[t]? = some (C.link (C.lastD H τ) it, e2) → C.link (C.lastD H τ) it ∉ (L.take t).map Prod.fst →
      ∀ ext : List (It' × D), (ext = [] ∨ ∃ ds, ext = S.ents it ds) →
      ∀ τ' : List (TItem × D), τ' <+: (τ ++ ext).map (toTE toT) →
        (firstSt W (cs (proverLog A (L.take t))) τ' ↔ firstSt W (cs (proverLog A L)) τ'))
    (q : ℕ) (hA : A.Bounded q) :
    prH (fun H => (∃ (k : ℕ) (c : CSub D), (cs (A.runLog H).2)[k]? = some c
          ∧ EntD W c (cChain C toT S H (heads (A.run H))))
        ∧ allSt W (cs (A.runLog H).2) (cChain C toT S H (heads (A.run H))))
      ≤ (q : ℝ≥0∞) * εmax + B + collBound (q + ℓ + 1) D + collBound (q + ℓ + 1 + 1) D := by
  have he : ∀ (P : List (Q × D)) (τ : List (It' × D)) (it : It'),
      firstCharge W (cs P) (τ.map (toTE toT)) (toT it) ≤ εmax :=
    fun P τ it => firstCharge_le W (cs P) εmax (hε P) _ _
  have hround : ∀ (P : List (Q × D)) (τ : List (It' × D)) (it : It'), s ≤ τ.length →
      (∃ hs : List It', τ.map Prod.fst = hs.flatMap S.items) →
      ¬ everG W (firstSt W (cs (proverLog A P))) (τ.map (toTE toT)) →
      (PMF.uniformOfFintype (Fin (S.wd it) → D)).toOuterMeasure
        {b | everG W (firstSt W (cs (proverLog A P))) ((τ ++ S.ents it (List.ofFn b)).map (toTE toT))}
        ≤ firstCharge W (cs (proverLog A P)) (τ.map (toTE toT)) (toT it) := by
    intro P τ it _ hbd hns
    exact codeRbr_step_pos W toT S hS
      (everG_rbr W _ _ (firstSt_rbr W hW (cs (proverLog A P)) (hsort _) (hR _) (hnorel _))) τ it hbd hns
  have hstabW : ∀ (H : Q → D) (L : List (Q × D)) (t : ℕ) (τ : List (It' × D)) (qs : List Q) (it : It') (e2 : D),
      C.Chain H τ qs → s ≤ τ.length → (∃ hs : List It', τ.map Prod.fst = hs.flatMap S.items) →
      (∀ z ∈ qs, z ∈ (L.take t).map Prod.fst) → (∀ e ∈ L, e.2 = H e.1) →
      L[t]? = some (C.link (C.lastD H τ) it, e2) → C.link (C.lastD H τ) it ∉ (L.take t).map Prod.fst →
        (everG W (firstSt W (cs (proverLog A (L.take t)))) (τ.map (toTE toT))
            ↔ everG W (firstSt W (cs (proverLog A L))) (τ.map (toTE toT)))
        ∧ ∀ ds : List D, (everG W (firstSt W (cs (proverLog A (L.take t)))) ((τ ++ S.ents it ds).map (toTE toT))
            ↔ everG W (firstSt W (cs (proverLog A L))) ((τ ++ S.ents it ds).map (toTE toT))) := by
    intro H L t τ qs it e2 hc hs hbd hq hL ht hfirst
    have key : ∀ ext : List (It' × D), (ext = [] ∨ ∃ ds, ext = S.ents it ds) →
        (everG W (firstSt W (cs (proverLog A (L.take t)))) ((τ ++ ext).map (toTE toT))
          ↔ everG W (firstSt W (cs (proverLog A L))) ((τ ++ ext).map (toTE toT))) :=
      fun ext hext => everG_congr W _ _ _
        (fun τ' hτ' => hstab H L t τ qs it e2 hc hs hbd hq hL ht hfirst ext hext τ' hτ')
    refine ⟨?_, fun ds => key (S.ents it ds) (Or.inr ⟨ds, rfl⟩)⟩
    have h := key [] (Or.inl rfl)
    rw [List.append_nil] at h
    exact h
  have hB' : ∀ H : Q → D, C.vSumFrom (fun τ it => firstCharge W (cs (A.runLog H).2) (τ.map (toTE toT)) (toT it))
      H [] ((heads (A.run H)).flatMap S.items) ≤ B :=
    fun H => firstCharge_vSum_le C toT W (cs (A.runLog H).2) (hsort _) B (hB _) H _
  have hmain := chain_sound_wide_seq_L C S
    (fun P τ => everG W (firstSt W (cs (proverLog A P))) (τ.map (toTE toT))) s
    (fun P τ it => firstCharge W (cs P) (τ.map (toTE toT)) (toT it)) εmax he A hround hstabW heads ℓ hℓ B hB' q hA
  refine le_trans (MeasureTheory.measure_mono ?_) hmain
  intro H hH
  rw [Set.mem_ofPred_eq] at hH ⊢
  obtain ⟨hent, hall⟩ := hH
  have hpl : proverLog A ((C.stepRun S heads A).runLog H).2 = (A.runLog H).2 := by
    rw [ChainEnc.stepRun, OC.runLog_bind]
    exact proverLog_runLog A H _
  refine ⟨?_, ?_⟩
  · -- the chain of the first `s` heads opens no window
    refine not_everG_first_short W _ _ (fun c hc => lt_of_le_of_lt ?_ (hwin _ c hc))
    rw [List.length_map, ChainEnc.chainFrom_length, List.length_nil, zero_add]
    exact hhd _
  · show everG W (firstSt W (cs (proverLog A ((C.stepRun S heads A).runLog H).2)))
      ((C.chainFrom H [] ((heads (A.run H)).flatMap S.items)).map (toTE toT))
    rw [hpl]
    exact everG_first_of_event W _ (hsort _) (hnorel _) _ hent hall

end Main

end ZK60.Exec
