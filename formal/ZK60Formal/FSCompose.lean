/-
D63, step L3 (soundness): sub-protocols composed on ONE chain, round by round (finding F20).

Each Fiat–Shamir theorem of `FSSumcheck.lean`, `FSLogUp.lean` and `FSOpening.lean` charges `q·ε_i` for its own
sub-protocol, so their union charges `q·Σ ε_i`. Run as ONE round-by-round protocol on one hash chain, each query
attacks one round, and the rate is the MAXIMUM over the rounds. This file proves that composition and puts it on the
chain with `FSWideRbr.lean`'s `fs_chain_sound_of_rbr_wide`.

**The combined state** is "every sub-protocol is still alive" (`AllAlive`): a family `S j` of states on the composed
transcript, indexed by a linear order `J` (the order in which claims flow). A false statement makes some `S j` false
at the start. The rounds belong to the sub-protocols (`own`). `Composed` asks two things:
* `own_round`: from a doomed own state, a round of `j` revives `S j` with probability at most that round's error;
* `frame`: a round that `j` does not own never revives `S j`, unless a LATER sub-protocol `j' > j` is already doomed
  before that round. This is how a reduction hands its claim on: a sumcheck slot, once finished, may release its state
  (it becomes `True`), because the evaluation claim it reduced to is now the pending claim of a later opening, and that
  opening is doomed whenever the slot was. A sub-protocol whose state is fixed outside its own rounds meets the
  condition trivially.

**What is proved.**
* `Composed.rbrWide`: the combined state is round-by-round sound with vector challenges (`RbrWide`) with error any `ε`
  above every round's error. The proof: from a doomed transcript take the LARGEST doomed `j₀`. If `j₀` owns the round,
  its own bound applies. If not, the round cannot revive `j₀` (`frame`, and no `j' > j₀` is doomed), so the combined
  state cannot escape at all.
* `Composed.rbrWide_sup`: the same with `ε` the maximum of the per-round errors over the `n` rounds.
* `fs_chain_sound_of_composed`, `fs_chain_sound_of_composed_sup`: on the code's chain, a prover making at most `q`
  hash queries gets a false statement accepted with probability at most `T·ε + collBound T D + collBound (T + 1) D`,
  `T = q + ℓW n w + 1`. The per-query rate is the maximum over rounds, not the sum.
* `fs_chain_wide_flip_composed`: the same for states that READ THE LOG (knowledge soundness, the claims about data
  extracted from the prover's log), stable once the statement's link is logged.
* `window_round`, `RbrWide.mono`, `RbrWide.comap`: a sub-protocol placed in a window of the composed schedule gets its
  `own_round` condition from its own `RbrWide`, with its statement the composed statement together with the transcript
  before the window (the claim it checks may be fixed by earlier rounds), and its messages read through a projection.
* **Schedules** (`SubProt`, `nOf`, `offs`, `ownOf`, `wOf`, `msgOf`, `winSt`, `SOf`): sub-protocols run one after the
  other on one chain, each with its rounds, widths, messages, error, its own `RbrWide`, its state before its window
  (`pend`: the part of its claim fixed so far) and after it (`post`). `ownOf_spec` and `ownOf_eq_of_window` locate a
  round's window; `SOf_pend`, `SOf_win`, `SOf_post`, `SOf_none` unfold the windowed state. `sched_composed`: a
  schedule meets `Composed`, `own_round` from each sub-protocol's `RbrWide`, provided the `frame` condition.
  `fs_chain_sound_sched`: the schedule on the chain, with error `ε ≥` every sub-protocol's error (`epsMax`).

**What this does not cover.** The `frame`, start and final conditions of a concrete composition are premises: they
say how the claims of the sub-protocols fit together (the arithmetization and the extraction), which is not
formalized for the block. `FSComposeBlock.lean` instantiates the per-round errors with the proved lemmas. A claim
fixed by a round's OWN message (a D12a stage's commitments, finding F41), per-round errors and the query-free part
path by path are `FSPath.lean`'s (`ZComposed`, `fs_chain_sound_of_zpath`).
-/
import ZK60Formal.FSWideRbr

set_option autoImplicit false

namespace ZK60.Sound

open scoped ENNReal
open Finset

/-! ## Two small facts about `RbrWide` -/

section RbrWideFacts

variable {X M D : Type} [Fintype D] [Nonempty D]

/-- A larger error bound is still a bound. -/
theorem RbrWide.mono {n : ℕ} {w : ℕ → ℕ} {St : X → List (M × List D) → Prop} {ε ε' : ℝ≥0∞}
    (h : RbrWide n w St ε) (hle : ε ≤ ε') : RbrWide n w St ε' :=
  ⟨fun x τ m h1 h2 => (h.round x τ m h1 h2).trans hle⟩

/-- **Reading the statement and the messages through maps.** A protocol stays round-by-round sound, with the same
error, when its statement is computed from another (`f`) and its messages are read off other messages (`g`). -/
theorem RbrWide.comap {X' M' : Type} {n : ℕ} {w : ℕ → ℕ} {St : X → List (M × List D) → Prop} {ε : ℝ≥0∞}
    (h : RbrWide n w St ε) (f : X' → X) (g : M' → M) :
    RbrWide n w (fun x τ => St (f x) (τ.map (fun e => (g e.1, e.2)))) ε where
  round x τ m h1 h2 := by
    have hl : (τ.map (fun e : M' × List D => (g e.1, e.2))).length = τ.length := List.length_map _
    have h := h.round (f x) (τ.map (fun e : M' × List D => (g e.1, e.2))) (g m) (by rw [hl]; exact h1) h2
    have hset : {b : Fin (w τ.length) → D |
        St (f x) ((τ ++ [(m, List.ofFn b)]).map (fun e : M' × List D => (g e.1, e.2)))}
        = {b | St (f x) (τ.map (fun e : M' × List D => (g e.1, e.2)) ++ [(g m, List.ofFn b)])} := by
      ext b
      simp only [Set.mem_ofPred_eq, List.map_append, List.map_cons, List.map_nil]
    rw [hset, prob_ofFn_congr (show w τ.length = w (τ.map (fun e : M' × List D => (g e.1, e.2))).length by rw [hl])
      (fun ds => St (f x) (τ.map (fun e : M' × List D => (g e.1, e.2)) ++ [(g m, ds)]))]
    exact h

end RbrWideFacts

/-! ## The composition -/

section Compose

variable {X M D J : Type} [Fintype D] [Nonempty D]

/-- **The combined state**: every sub-protocol is still alive. -/
def AllAlive (S : J → X → List (M × List D) → Prop) (x : X) (τ : List (M × List D)) : Prop := ∀ j, S j x τ

/-- **Sub-protocols composed on one schedule.** `n` rounds of widths `w`; round `i` belongs to the sub-protocol
`own i`; `S j` is sub-protocol `j`'s state on the composed transcript; `er i` is round `i`'s error.
* `own_round`: from a doomed own state, the round's uniform digests revive it with probability at most `er`;
* `frame`: a round that `j` does not own never revives `S j`, unless some later `j' > j` is doomed before the round
  (the claim of `j` has been handed on to `j'`). -/
structure Composed [LT J] (n : ℕ) (w : ℕ → ℕ) (own : ℕ → J) (S : J → X → List (M × List D) → Prop)
    (er : ℕ → ℝ≥0∞) : Prop where
  own_round : ∀ x τ m, τ.length < n → ¬ S (own τ.length) x τ →
    (PMF.uniformOfFintype (Fin (w τ.length) → D)).toOuterMeasure
      {b | S (own τ.length) x (τ ++ [(m, List.ofFn b)])} ≤ er τ.length
  frame : ∀ j x τ m (b : Fin (w τ.length) → D), τ.length < n → own τ.length ≠ j → ¬ S j x τ →
    S j x (τ ++ [(m, List.ofFn b)]) → ∃ j', j < j' ∧ ¬ S j' x τ

/-- **The composition is round-by-round sound, with the maximum error.** If only the sub-protocols in a finite set `B`
can be doomed, the combined state "every sub-protocol alive" is `RbrWide` with error any `ε` above every round's
error. From a doomed transcript, the largest doomed `j₀` either owns the round (its own bound) or cannot be revived
(`frame`), and then the combined state cannot escape. -/
theorem Composed.rbrWide [LinearOrder J] {n : ℕ} {w : ℕ → ℕ} {own : ℕ → J}
    {S : J → X → List (M × List D) → Prop} {er : ℕ → ℝ≥0∞} (h : Composed n w own S er)
    (B : Finset J) (hB : ∀ j x τ, ¬ S j x τ → j ∈ B) (ε : ℝ≥0∞) (hε : ∀ i, i < n → er i ≤ ε) :
    RbrWide n w (AllAlive S) ε where
  round x τ m hτ hns := by
    classical
    have hne : (B.filter (fun j => ¬ S j x τ)).Nonempty := by
      obtain ⟨j, hj⟩ := not_forall.mp hns
      exact ⟨j, mem_filter.mpr ⟨hB j x τ hj, hj⟩⟩
    obtain ⟨j₀, hj₀m, hj₀max⟩ := (B.filter (fun j => ¬ S j x τ)).exists_max_image id hne
    have hj₀ : ¬ S j₀ x τ := (mem_filter.mp hj₀m).2
    have hmax : ∀ j', j₀ < j' → S j' x τ := by
      intro j' hlt
      by_contra hd
      exact absurd (hj₀max j' (mem_filter.mpr ⟨hB j' x τ hd, hd⟩)) (not_le.mpr hlt)
    have hsub : {b : Fin (w τ.length) → D | AllAlive S x (τ ++ [(m, List.ofFn b)])}
        ⊆ {b | S j₀ x (τ ++ [(m, List.ofFn b)])} := fun b hb => hb j₀
    refine le_trans (MeasureTheory.measure_mono hsub) ?_
    by_cases ho : own τ.length = j₀
    · subst ho
      exact (h.own_round x τ m hτ hj₀).trans (hε _ hτ)
    · have hempty : {b : Fin (w τ.length) → D | S j₀ x (τ ++ [(m, List.ofFn b)])} = ∅ := by
        refine Set.eq_empty_iff_forall_notMem.mpr (fun b hb => ?_)
        obtain ⟨j', hlt, hd⟩ := h.frame j₀ x τ m b hτ ho hj₀ hb
        exact hd (hmax j' hlt)
      rw [hempty, MeasureTheory.measure_empty]
      exact zero_le

/-- **The composition with the error the maximum over all rounds.** -/
theorem Composed.rbrWide_sup [LinearOrder J] {n : ℕ} {w : ℕ → ℕ} {own : ℕ → J}
    {S : J → X → List (M × List D) → Prop} {er : ℕ → ℝ≥0∞} (h : Composed n w own S er)
    (B : Finset J) (hB : ∀ j x τ, ¬ S j x τ → j ∈ B) :
    RbrWide n w (AllAlive S) ((range n).sup er) :=
  h.rbrWide B hB _ (fun _ hi => le_sup (f := er) (mem_range.mpr hi))

variable {Q : Type} [Fintype Q] [DecidableEq Q] [DecidableEq D]

/-- **The composition on the code's chain.** For a composed protocol (`Composed`) whose false statements doom some
sub-protocol at the start (`hstart`) and whose verifier rejects whenever some sub-protocol is doomed at the end
(`hfinal`): a prover making at most `q` hash queries gets a false statement accepted with probability at most
`T·ε + collBound T D + collBound (T + 1) D`, `T = q + ℓW n w + 1`, for any `ε` above every round's error. -/
theorem fs_chain_sound_of_composed [LinearOrder J] {n : ℕ} {w : ℕ → ℕ} {hasMsg : ℕ → Bool} {m₀ : M}
    (hw : ∀ i, 0 < w i) (C : ChainEnc (PItem X M) Q D) {Mf : Type} {L : X → Prop}
    {accept : X → List (M × List D) → Mf → Prop} {own : ℕ → J} {S : J → X → List (M × List D) → Prop}
    {er : ℕ → ℝ≥0∞} (h : Composed n w own S er) (B : Finset J) (hB : ∀ j x τ, ¬ S j x τ → j ∈ B)
    (ε : ℝ≥0∞) (hε : ∀ i, i < n → er i ≤ ε)
    (hstart : ∀ x, ¬ L x → ∃ j, ¬ S j x [])
    (hfinal : ∀ x τ mf, τ.length = n → (∃ j, ¬ S j x τ) → ¬ accept x τ mf)
    (q : ℕ) (A : OC Q D (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1
        ∧ chainAcceptsW n w hw hasMsg m₀ accept C H (A.run H).1 (A.run H).2.1 (A.run H).2.2)
      ≤ ((q + ℓW n w + 1 : ℕ) : ℝ≥0∞) * ε + collBound (q + ℓW n w + 1) D
        + collBound (q + ℓW n w + 1 + 1) D :=
  fs_chain_sound_of_rbr_wide hw C ε (h.rbrWide B hB ε hε)
    (fun x hx hall => by
      obtain ⟨j, hj⟩ := hstart x hx
      exact hj (hall j))
    (fun x τ mf hl hns => hfinal x τ mf hl (not_forall.mp hns)) q A hA

/-- **The per-query rate is the maximum over the rounds**: `fs_chain_sound_of_composed` with
`ε = max_{i < n} er i`. -/
theorem fs_chain_sound_of_composed_sup [LinearOrder J] {n : ℕ} {w : ℕ → ℕ} {hasMsg : ℕ → Bool} {m₀ : M}
    (hw : ∀ i, 0 < w i) (C : ChainEnc (PItem X M) Q D) {Mf : Type} {L : X → Prop}
    {accept : X → List (M × List D) → Mf → Prop} {own : ℕ → J} {S : J → X → List (M × List D) → Prop}
    {er : ℕ → ℝ≥0∞} (h : Composed n w own S er) (B : Finset J) (hB : ∀ j x τ, ¬ S j x τ → j ∈ B)
    (hstart : ∀ x, ¬ L x → ∃ j, ¬ S j x [])
    (hfinal : ∀ x τ mf, τ.length = n → (∃ j, ¬ S j x τ) → ¬ accept x τ mf)
    (q : ℕ) (A : OC Q D (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1
        ∧ chainAcceptsW n w hw hasMsg m₀ accept C H (A.run H).1 (A.run H).2.1 (A.run H).2.2)
      ≤ ((q + ℓW n w + 1 : ℕ) : ℝ≥0∞) * (range n).sup er + collBound (q + ℓW n w + 1) D
        + collBound (q + ℓW n w + 1 + 1) D :=
  fs_chain_sound_of_composed hw C h B hB _ (fun _ hi => le_sup (f := er) (mem_range.mpr hi)) hstart hfinal q A hA

/-- **The composition with states that read the log** (for knowledge soundness: a sub-protocol's claim may be about
data extracted from the prover's log, as in `FSOpening.lean`). For every log the sub-protocols compose
(`Composed`), and each state is frozen once the statement's link is logged (`hstab`): `fs_chain_wide_flip` for the
combined state. -/
theorem fs_chain_wide_flip_composed [LinearOrder J] {n : ℕ} {w : ℕ → ℕ} {hasMsg : ℕ → Bool} {m₀ : M}
    (hw : ∀ i, 0 < w i) (C : ChainEnc (PItem X M) Q D) {own : ℕ → J}
    (S : List (Q × D) → J → X → List (M × List D) → Prop) {er : ℕ → ℝ≥0∞}
    (h : ∀ P, Composed n w own (S P) er) (B : Finset J) (hB : ∀ P j x τ, ¬ S P j x τ → j ∈ B)
    (ε : ℝ≥0∞) (hε : ∀ i, i < n → er i ≤ ε)
    (hstab : ∀ (H : Q → D) (P P' : List (Q × D)) (x : X) (τ : List (M × List D)), C.start ∈ P.map Prod.fst →
      C.link (H C.start) (PItem.stmt x) ∈ P.map Prod.fst → P <+: P' → (∀ e ∈ P', e.2 = H e.1) →
        ∀ j, (S P j x τ ↔ S P' j x τ))
    {Mf : Type} (q : ℕ) (A : OC Q D (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H =>
        ¬ AllAlive (S ((C.stepRun (pSteps n w hw) (fun o => pHeadsW n w hasMsg o.1 o.2.1) A).runLog H).2)
            (A.run H).1 []
        ∧ ∃ ptr pm, rDecodeW n w hasMsg m₀ ((C.chainFrom H []
            ((pHeadsW n w hasMsg (A.run H).1 (A.run H).2.1).flatMap (pSteps n w hw).items)).drop 1)
              = some (ptr, pm, [])
          ∧ AllAlive (S ((C.stepRun (pSteps n w hw) (fun o => pHeadsW n w hasMsg o.1 o.2.1) A).runLog H).2)
            (A.run H).1 ptr)
      ≤ ((q + ℓW n w + 1 : ℕ) : ℝ≥0∞) * ε + collBound (q + ℓW n w + 1) D
        + collBound (q + ℓW n w + 1 + 1) D :=
  fs_chain_wide_flip (hasMsg := hasMsg) (m₀ := m₀) hw C (fun P => AllAlive (S P)) ε
    (fun P => (h P).rbrWide B (hB P) ε hε)
    (fun H P P' x τ h1 h2 h3 h4 => forall_congr' (fun j => hstab H P P' x τ h1 h2 h3 h4 j)) q A hA

end Compose

/-! ## A sub-protocol in a window of the schedule -/

section Window

variable {X M D : Type} [Fintype D] [Nonempty D]

/-- **The own round of a sub-protocol in a window.** A sub-protocol with `n'` rounds of widths `w'` and its own
`RbrWide` (statement: the composed statement and the transcript before the window), placed at rounds
`a, …, a + n' − 1` of the composed schedule, where its state `Sj` reads its own rounds `τ.drop a`: from a doomed state,
a round of the window revives it with probability at most its own error. -/
theorem window_round {n' : ℕ} {w' : ℕ → ℕ} {St : X × List (M × List D) → List (M × List D) → Prop} {ε : ℝ≥0∞}
    (hR : RbrWide n' w' St ε) (a : ℕ) (w : ℕ → ℕ) (Sj : X → List (M × List D) → Prop)
    (hS : ∀ x τ, a ≤ τ.length → τ.length ≤ a + n' → (Sj x τ ↔ St (x, τ.take a) (τ.drop a)))
    (x : X) (τ : List (M × List D)) (m : M) (h1 : a ≤ τ.length) (h2 : τ.length < a + n')
    (hw : w τ.length = w' (τ.length - a)) (hns : ¬ Sj x τ) :
    (PMF.uniformOfFintype (Fin (w τ.length) → D)).toOuterMeasure {b | Sj x (τ ++ [(m, List.ofFn b)])} ≤ ε := by
  have hset : {b : Fin (w τ.length) → D | Sj x (τ ++ [(m, List.ofFn b)])}
      = {b | St (x, τ.take a) (τ.drop a ++ [(m, List.ofFn b)])} := by
    ext b
    simp only [Set.mem_ofPred_eq]
    rw [hS x _ (by simp only [List.length_append, List.length_singleton]; omega)
      (by simp only [List.length_append, List.length_singleton]; omega),
      List.take_append_of_le_length h1, List.drop_append_of_le_length h1]
  rw [hset, prob_ofFn_congr (show w τ.length = w' (τ.drop a).length by rw [List.length_drop, hw])
    (fun ds => St (x, τ.take a) (τ.drop a ++ [(m, ds)]))]
  exact hR.round (x, τ.take a) (τ.drop a) m (by rw [List.length_drop]; omega) ((hS x τ h1 h2.le).not.mp hns)

end Window

/-! ## Schedules: sub-protocols one after the other on one chain -/

section Schedule

variable {X M D : Type} [Fintype D] [Nonempty D]

/-- **A sub-protocol of a schedule.** `n` rounds of widths `w`, messages where `hasMsg`, error `ε`, and its state
`St`, which reads the composed statement with the composed transcript BEFORE its window (so the claim it checks may
be fixed by earlier rounds) and its own rounds; `rbr` is its round-by-round soundness. `pend` is its state before its
window (the part of its claim fixed so far), `post` its state after (`True` once its claim is handed on). -/
structure SubProt (X M D : Type) [Fintype D] [Nonempty D] where
  n : ℕ
  w : ℕ → ℕ
  hasMsg : ℕ → Bool
  ε : ℝ≥0∞
  St : X × List (M × List D) → List (M × List D) → Prop
  rbr : RbrWide n w St ε
  pend : X → List (M × List D) → Prop
  post : X → List (M × List D) → Prop

/-- The rounds of a schedule. -/
def nOf : List (SubProt X M D) → ℕ
  | [] => 0
  | c :: cs => c.n + nOf cs

/-- The first round of the `k`-th sub-protocol. -/
def offs : List (SubProt X M D) → ℕ → ℕ
  | _, 0 => 0
  | [], _ + 1 => 0
  | c :: cs, k + 1 => c.n + offs cs k

/-- The sub-protocol that round `i` belongs to. -/
def ownOf : List (SubProt X M D) → ℕ → ℕ
  | [], _ => 0
  | c :: cs, i => if i < c.n then 0 else ownOf cs (i - c.n) + 1

/-- The width of round `i`: its sub-protocol's width there (`1` past the end). -/
def wOf : List (SubProt X M D) → ℕ → ℕ
  | [], _ => 1
  | c :: cs, i => if i < c.n then c.w i else wOf cs (i - c.n)

/-- Whether round `i` has a message: as its sub-protocol says. -/
def msgOf : List (SubProt X M D) → ℕ → Bool
  | [], _ => false
  | c :: cs, i => if i < c.n then c.hasMsg i else msgOf cs (i - c.n)

/-- **The windowed state** of a sub-protocol whose window starts at round `a`: `pend` before it, its own state in it
(the statement with the transcript before the window, and its own rounds), `post` after it. -/
def winSt (c : SubProt X M D) (a : ℕ) (x : X) (τ : List (M × List D)) : Prop :=
  if τ.length < a then c.pend x τ
  else if τ.length ≤ a + c.n then c.St (x, τ.take a) (τ.drop a)
  else c.post x τ

/-- **The schedule's sub-protocol states**: the `k`-th sub-protocol's windowed state (`True` past the list). -/
def SOf (cs : List (SubProt X M D)) (k : ℕ) (x : X) (τ : List (M × List D)) : Prop :=
  match cs[k]? with
  | some c => winSt c (offs cs k) x τ
  | none => True

/-- The largest error of a schedule. -/
noncomputable def epsMax (cs : List (SubProt X M D)) : ℝ≥0∞ := (cs.map SubProt.ε).foldr max 0

/-- Every sub-protocol's error is at most `epsMax`. -/
theorem le_epsMax : ∀ (cs : List (SubProt X M D)) (c : SubProt X M D), c ∈ cs → c.ε ≤ epsMax cs
  | [], _, h => absurd h List.not_mem_nil
  | c' :: cs, c, h => by
    simp only [epsMax, List.map_cons, List.foldr_cons]
    rcases List.mem_cons.mp h with rfl | h
    · exact le_max_left _ _
    · exact (le_epsMax cs c h).trans (le_max_right _ _)

/-- **Where round `i` sits**: its sub-protocol exists, its window contains `i`, and the round's width is the
sub-protocol's width at `i`'s place in it (and so is its message flag). -/
theorem ownOf_spec : ∀ (cs : List (SubProt X M D)) (i : ℕ), i < nOf cs →
    ∃ c, cs[ownOf cs i]? = some c ∧ offs cs (ownOf cs i) ≤ i ∧ i < offs cs (ownOf cs i) + c.n
      ∧ wOf cs i = c.w (i - offs cs (ownOf cs i)) ∧ msgOf cs i = c.hasMsg (i - offs cs (ownOf cs i))
  | [], i, h => by simp [nOf] at h
  | c :: cs, i, h => by
    by_cases hi : i < c.n
    · exact ⟨c, by simp [ownOf, hi], by simp [ownOf, hi, offs], by simp [ownOf, hi, offs],
        by simp [ownOf, hi, offs, wOf], by simp [ownOf, hi, offs, msgOf]⟩
    · have h' : i - c.n < nOf cs := by simp only [nOf] at h; omega
      obtain ⟨c', h1, h2, h3, h4, h5⟩ := ownOf_spec cs (i - c.n) h'
      refine ⟨c', ?_, ?_, ?_, ?_, ?_⟩
      · simp only [ownOf, hi, ↓reduceIte, List.getElem?_cons_succ]
        exact h1
      · simp only [ownOf, hi, ↓reduceIte, offs]
        omega
      · simp only [ownOf, hi, ↓reduceIte, offs]
        omega
      · simp only [ownOf, hi, ↓reduceIte, offs, wOf]
        rw [h4]
        congr 1
        omega
      · simp only [ownOf, hi, ↓reduceIte, offs, msgOf]
        rw [h5]
        congr 1
        omega

/-- **A round inside a sub-protocol's window belongs to it.** -/
theorem ownOf_eq_of_window : ∀ (cs : List (SubProt X M D)) (k i : ℕ) (c : SubProt X M D), cs[k]? = some c →
    offs cs k ≤ i → i < offs cs k + c.n → ownOf cs i = k
  | [], k, i, c, h, _, _ => by simp at h
  | c' :: cs, 0, i, c, h, _, h2 => by
    simp only [List.getElem?_cons_zero, Option.some.injEq] at h
    subst h
    simp only [offs, zero_add] at h2
    simp [ownOf, h2]
  | c' :: cs, k + 1, i, c, h, h1, h2 => by
    simp only [List.getElem?_cons_succ] at h
    simp only [offs] at h1 h2
    have hi : ¬ i < c'.n := by omega
    simp only [ownOf, hi, ↓reduceIte]
    rw [ownOf_eq_of_window cs k (i - c'.n) c h (by omega) (by omega)]

/-- Every round is at least one squeeze wide when every sub-protocol's rounds are. -/
theorem wOf_pos : ∀ (cs : List (SubProt X M D)), (∀ c ∈ cs, ∀ i, 0 < c.w i) → ∀ i, 0 < wOf cs i
  | [], _, _ => one_pos
  | c :: cs, h, i => by
    simp only [wOf]
    split_ifs
    · exact h c List.mem_cons_self i
    · exact wOf_pos cs (fun c' hc' => h c' (List.mem_cons_of_mem _ hc')) _

/-- Before its window, a sub-protocol's state is `pend`. -/
theorem SOf_pend {cs : List (SubProt X M D)} {k : ℕ} {c : SubProt X M D} (hc : cs[k]? = some c) (x : X)
    (τ : List (M × List D)) (h : τ.length < offs cs k) : SOf cs k x τ ↔ c.pend x τ := by
  simp only [SOf, hc, winSt, h, ↓reduceIte]

/-- In its window, a sub-protocol's state is its own state on its own rounds. -/
theorem SOf_win {cs : List (SubProt X M D)} {k : ℕ} {c : SubProt X M D} (hc : cs[k]? = some c) (x : X)
    (τ : List (M × List D)) (h1 : offs cs k ≤ τ.length) (h2 : τ.length ≤ offs cs k + c.n) :
    SOf cs k x τ ↔ c.St (x, τ.take (offs cs k)) (τ.drop (offs cs k)) := by
  simp only [SOf, hc, winSt, not_lt.mpr h1, h2, ↓reduceIte]

/-- After its window, a sub-protocol's state is `post`. -/
theorem SOf_post {cs : List (SubProt X M D)} {k : ℕ} {c : SubProt X M D} (hc : cs[k]? = some c) (x : X)
    (τ : List (M × List D)) (h : offs cs k + c.n < τ.length) : SOf cs k x τ ↔ c.post x τ := by
  simp only [SOf, hc, winSt, show ¬ τ.length < offs cs k by omega, not_le.mpr h, ↓reduceIte]

/-- Past the list, the state is `True`. -/
theorem SOf_none {cs : List (SubProt X M D)} {k : ℕ} (hk : cs.length ≤ k) (x : X) (τ : List (M × List D)) :
    SOf cs k x τ := by
  simp only [SOf, List.getElem?_eq_none hk]

/-- **A schedule is a composition.** Each sub-protocol's own rounds are bounded by its `RbrWide` (`window_round`); the
`frame` condition is the premise `hframe`. -/
theorem sched_composed (cs : List (SubProt X M D)) (ε : ℝ≥0∞) (hε : ∀ c ∈ cs, c.ε ≤ ε)
    (hframe : ∀ k x τ m (b : Fin (wOf cs τ.length) → D), τ.length < nOf cs → ownOf cs τ.length ≠ k →
      ¬ SOf cs k x τ → SOf cs k x (τ ++ [(m, List.ofFn b)]) → ∃ k', k < k' ∧ ¬ SOf cs k' x τ) :
    Composed (nOf cs) (wOf cs) (ownOf cs) (SOf cs) (fun _ => ε) where
  own_round x τ m hτ hns := by
    obtain ⟨c, hc, h1, h2, hw, -⟩ := ownOf_spec cs τ.length hτ
    refine (window_round c.rbr (offs cs (ownOf cs τ.length)) (wOf cs) (SOf cs (ownOf cs τ.length))
      (fun x' τ' ha hb => SOf_win hc x' τ' ha hb) x τ m h1 h2 hw hns).trans ?_
    exact hε c (List.mem_of_getElem? hc)
  frame := hframe

/-- Only the sub-protocols of the list can be doomed. -/
theorem SOf_doomed_mem (cs : List (SubProt X M D)) (k : ℕ) (x : X) (τ : List (M × List D))
    (h : ¬ SOf cs k x τ) : k ∈ range cs.length := by
  by_contra hk
  exact h (SOf_none (by simpa using hk) x τ)

variable {Q : Type} [Fintype Q] [DecidableEq Q] [DecidableEq D]

/-- **A schedule on the code's chain.** Sub-protocols run one after the other, each with its own `RbrWide`; a false
statement dooms one of them at the start (`hstart`); the verifier rejects when one is doomed at the end (`hfinal`);
claims are handed on only forward (`hframe`). A prover making at most `q` hash queries gets a false statement accepted
with probability at most `T·ε + collBound T D + collBound (T + 1) D`, `T = q + ℓW + 1`, for any `ε` above every
sub-protocol's error: the per-query rate is the largest error, not the sum. -/
theorem fs_chain_sound_sched (cs : List (SubProt X M D)) (hwpos : ∀ c ∈ cs, ∀ i, 0 < c.w i) {m₀ : M}
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
      ≤ ((q + ℓW (nOf cs) (wOf cs) + 1 : ℕ) : ℝ≥0∞) * ε + collBound (q + ℓW (nOf cs) (wOf cs) + 1) D
        + collBound (q + ℓW (nOf cs) (wOf cs) + 1 + 1) D :=
  fs_chain_sound_of_composed (wOf_pos cs hwpos) C (sched_composed cs ε hε hframe) (range cs.length)
    (SOf_doomed_mem cs) ε (fun _ _ => le_rfl) hstart hfinal q A hA

end Schedule

end ZK60.Sound
