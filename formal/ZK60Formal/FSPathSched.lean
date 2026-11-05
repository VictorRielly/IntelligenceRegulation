/-
D63, step L3 (soundness): schedules of sub-protocols with PER-ROUND errors and MESSAGE-AWARE states, for the path-wise
bound of `FSPath.lean` (finding F25).

`FSCompose.lean`'s `SubProt` has one error for all its rounds, and its state reads the composed statement with the
transcript before its window. Two things the path-wise bound needs are missing:
* **per-round errors.** LogUp's two rounds have errors `2M/|F|` (the fold) and `(N + 2M − 1)/|F|` (the `α` step); an
  opening's two rounds have its field term and its column term. A sub-protocol's share of the query-free part is the SUM
  of its rounds' errors (`SubProtP.tot`), not `n·max`;
* **claims fixed by a round's own message.** In a D12a run, stage `k`'s commitments (`B_k`, then `A_k` and `M_k`) are
  absorbed in the message of the round whose challenge is LogUp's `(β, γ)` (`run.rs:1402-1407`, `protocol.rs:2023-2027`).
  The claim LogUp checks is fixed by that message, so LogUp's doom is a doom AFTER the message (`pre`), not before the
  round.

**What is proved.**
* `SubProtP`: a sub-protocol with per-round errors `er`, its state `St` and its state after a round's message `pre`,
  and its round-by-round soundness from a doomed `pre` (`rbr`); `pend`, `pendM` (before its window) and `post`.
* The schedule (`nOfP`, `offsP`, `ownOfP`, `wOfP`, `msgOfP`, `erOfP`, `SOfP`, `POfP`); `ownOfP_spec` locates a round;
  `schedP_own_round`: each round's own condition comes from its sub-protocol's `rbr`; `schedP_zcomposed`: a schedule
  is a composition with zones once `hand` and `frame` hold.
* `sumErOfP_zone`: the round errors of the rounds owned by a set of sub-protocols add up to their totals.
* `SubProt.toP`: `FSCompose.lean`'s sub-protocols, with their uniform error and `pre` their state before the round.
* `fs_chain_sound_schedP_path`: **a schedule on the chain, path-wise**: `q·εmax + B + collision terms`, `B` bounding the
  totals of the sub-protocols of the doom's path along every transcript.
-/
import ZK60Formal.FSPath

set_option autoImplicit false

namespace ZK60.Sound

open scoped ENNReal
open Finset

section SchedP

variable {X M D : Type} [Fintype D] [Nonempty D]

/-- **A sub-protocol with per-round errors and a state after the round's message.** `St` reads the composed statement
with the transcript before its window and its own rounds; `pre y τ m` is its state once round `τ.length` has sent `m`;
from a doomed `pre`, the round's digests revive `St` with probability at most `er τ.length` (`rbr`). -/
structure SubProtP (X M D : Type) [Fintype D] [Nonempty D] where
  n : ℕ
  w : ℕ → ℕ
  hasMsg : ℕ → Bool
  er : ℕ → ℝ≥0∞
  St : X × List (M × List D) → List (M × List D) → Prop
  pre : X × List (M × List D) → List (M × List D) → M → Prop
  rbr : ∀ y τ m, τ.length < n → ¬ pre y τ m →
    (PMF.uniformOfFintype (Fin (w τ.length) → D)).toOuterMeasure {b | St y (τ ++ [(m, List.ofFn b)])}
      ≤ er τ.length
  pend : X → List (M × List D) → Prop
  pendM : X → List (M × List D) → M → Prop
  post : X → List (M × List D) → Prop

/-- **A sub-protocol's total error**: the sum of its rounds' errors, its share of the query-free part. -/
noncomputable def SubProtP.tot (c : SubProtP X M D) : ℝ≥0∞ := ∑ i ∈ range c.n, c.er i

/-- The rounds of a schedule. -/
def nOfP : List (SubProtP X M D) → ℕ
  | [] => 0
  | c :: cs => c.n + nOfP cs

/-- The first round of the `k`-th sub-protocol. -/
def offsP : List (SubProtP X M D) → ℕ → ℕ
  | _, 0 => 0
  | [], _ + 1 => 0
  | c :: cs, k + 1 => c.n + offsP cs k

/-- The sub-protocol that round `i` belongs to. -/
def ownOfP : List (SubProtP X M D) → ℕ → ℕ
  | [], _ => 0
  | c :: cs, i => if i < c.n then 0 else ownOfP cs (i - c.n) + 1

/-- The width of round `i`. -/
def wOfP : List (SubProtP X M D) → ℕ → ℕ
  | [], _ => 1
  | c :: cs, i => if i < c.n then c.w i else wOfP cs (i - c.n)

/-- Whether round `i` has a message. -/
def msgOfP : List (SubProtP X M D) → ℕ → Bool
  | [], _ => false
  | c :: cs, i => if i < c.n then c.hasMsg i else msgOfP cs (i - c.n)

/-- The error of round `i`: its sub-protocol's error for its place in it (`0` past the end). -/
noncomputable def erOfP : List (SubProtP X M D) → ℕ → ℝ≥0∞
  | [], _ => 0
  | c :: cs, i => if i < c.n then c.er i else erOfP cs (i - c.n)

/-- The windowed state of a sub-protocol whose window starts at round `a`. -/
def winStP (c : SubProtP X M D) (a : ℕ) (x : X) (τ : List (M × List D)) : Prop :=
  if τ.length < a then c.pend x τ
  else if τ.length ≤ a + c.n then c.St (x, τ.take a) (τ.drop a)
  else c.post x τ

/-- The windowed state after the message of round `τ.length`. -/
def winPreP (c : SubProtP X M D) (a : ℕ) (x : X) (τ : List (M × List D)) (m : M) : Prop :=
  if τ.length < a then c.pendM x τ m
  else if τ.length < a + c.n then c.pre (x, τ.take a) (τ.drop a) m
  else c.post x τ

/-- The schedule's sub-protocol states (`True` past the list). -/
def SOfP (cs : List (SubProtP X M D)) (k : ℕ) (x : X) (τ : List (M × List D)) : Prop :=
  match cs[k]? with
  | some c => winStP c (offsP cs k) x τ
  | none => True

/-- The schedule's sub-protocol states after a round's message (`True` past the list). -/
def POfP (cs : List (SubProtP X M D)) (k : ℕ) (x : X) (τ : List (M × List D)) (m : M) : Prop :=
  match cs[k]? with
  | some c => winPreP c (offsP cs k) x τ m
  | none => True

/-- **Where round `i` sits**, with its width, message flag and error. -/
theorem ownOfP_spec : ∀ (cs : List (SubProtP X M D)) (i : ℕ), i < nOfP cs →
    ∃ c, cs[ownOfP cs i]? = some c ∧ offsP cs (ownOfP cs i) ≤ i ∧ i < offsP cs (ownOfP cs i) + c.n
      ∧ wOfP cs i = c.w (i - offsP cs (ownOfP cs i)) ∧ msgOfP cs i = c.hasMsg (i - offsP cs (ownOfP cs i))
      ∧ erOfP cs i = c.er (i - offsP cs (ownOfP cs i))
  | [], i, h => by simp [nOfP] at h
  | c :: cs, i, h => by
    by_cases hi : i < c.n
    · exact ⟨c, by simp [ownOfP, hi], by simp [ownOfP, hi, offsP], by simp [ownOfP, hi, offsP],
        by simp [ownOfP, hi, offsP, wOfP], by simp [ownOfP, hi, offsP, msgOfP], by simp [ownOfP, hi, offsP, erOfP]⟩
    · have h' : i - c.n < nOfP cs := by simp only [nOfP] at h; omega
      obtain ⟨c', h1, h2, h3, h4, h5, h6⟩ := ownOfP_spec cs (i - c.n) h'
      refine ⟨c', ?_, ?_, ?_, ?_, ?_, ?_⟩
      · simp only [ownOfP, hi, ↓reduceIte, List.getElem?_cons_succ]
        exact h1
      · simp only [ownOfP, hi, ↓reduceIte, offsP]
        omega
      · simp only [ownOfP, hi, ↓reduceIte, offsP]
        omega
      · simp only [ownOfP, hi, ↓reduceIte, offsP, wOfP]
        rw [h4]
        congr 1
        omega
      · simp only [ownOfP, hi, ↓reduceIte, offsP, msgOfP]
        rw [h5]
        congr 1
        omega
      · simp only [ownOfP, hi, ↓reduceIte, offsP, erOfP]
        rw [h6]
        congr 1
        omega

/-- Every round is at least one squeeze wide when every sub-protocol's rounds are. -/
theorem wOfP_pos : ∀ (cs : List (SubProtP X M D)), (∀ c ∈ cs, ∀ i, 0 < c.w i) → ∀ i, 0 < wOfP cs i
  | [], _, _ => one_pos
  | c :: cs, h, i => by
    simp only [wOfP]
    split_ifs
    · exact h c List.mem_cons_self i
    · exact wOfP_pos cs (fun c' hc' => h c' (List.mem_cons_of_mem _ hc')) _

/-- A schedule's round error is at most `ε` when every sub-protocol's rounds' errors are. -/
theorem erOfP_le (cs : List (SubProtP X M D)) (ε : ℝ≥0∞) (h : ∀ c ∈ cs, ∀ i, i < c.n → c.er i ≤ ε)
    (i : ℕ) (hi : i < nOfP cs) : erOfP cs i ≤ ε := by
  obtain ⟨c, hc, h1, h2, -, -, her⟩ := ownOfP_spec cs i hi
  rw [her]
  exact h c (List.mem_of_getElem? hc) _ (by omega)

/-- **A round of the schedule is bounded by its sub-protocol's `rbr`**, from a doomed state after its message. -/
theorem schedP_own_round (cs : List (SubProtP X M D)) (x : X) (τ : List (M × List D)) (m : M)
    (hτ : τ.length < nOfP cs) (hns : ¬ POfP cs (ownOfP cs τ.length) x τ m) :
    (PMF.uniformOfFintype (Fin (wOfP cs τ.length) → D)).toOuterMeasure
        {b | SOfP cs (ownOfP cs τ.length) x (τ ++ [(m, List.ofFn b)])} ≤ erOfP cs τ.length := by
  obtain ⟨c, hc, h1, h2, hw, -, her⟩ := ownOfP_spec cs τ.length hτ
  have hpre : POfP cs (ownOfP cs τ.length) x τ m
      ↔ c.pre (x, τ.take (offsP cs (ownOfP cs τ.length))) (τ.drop (offsP cs (ownOfP cs τ.length))) m := by
    simp only [POfP, hc, winPreP, show ¬ τ.length < offsP cs (ownOfP cs τ.length) by omega, h2, ↓reduceIte]
  have hset : {b : Fin (wOfP cs τ.length) → D | SOfP cs (ownOfP cs τ.length) x (τ ++ [(m, List.ofFn b)])}
      = {b | c.St (x, τ.take (offsP cs (ownOfP cs τ.length)))
          (τ.drop (offsP cs (ownOfP cs τ.length)) ++ [(m, List.ofFn b)])} := by
    ext b
    simp only [Set.mem_ofPred_eq, SOfP, hc, winStP, List.length_append, List.length_singleton,
      show ¬ τ.length + 1 < offsP cs (ownOfP cs τ.length) by omega,
      show τ.length + 1 ≤ offsP cs (ownOfP cs τ.length) + c.n by omega, ↓reduceIte,
      List.take_append_of_le_length h1, List.drop_append_of_le_length h1]
  rw [hset, prob_ofFn_congr hw (fun ds => c.St (x, τ.take (offsP cs (ownOfP cs τ.length)))
    (τ.drop (offsP cs (ownOfP cs τ.length)) ++ [(m, ds)])), her]
  have h := c.rbr (x, τ.take (offsP cs (ownOfP cs τ.length))) (τ.drop (offsP cs (ownOfP cs τ.length))) m
    (by rw [List.length_drop]; omega) (hpre.not.mp hns)
  rwa [List.length_drop] at h

/-- **A schedule is a composition with zones** once its `hand` and `frame` conditions hold. -/
theorem schedP_zcomposed (cs : List (SubProtP X M D)) (zone₀ : X → Finset ℕ)
    (zone : X → List (M × List D) → M → Finset ℕ)
    (hhand : ∀ x τ m, τ.length < nOfP cs → (∃ j ∈ lastZone zone₀ zone x τ, ¬ SOfP cs j x τ) →
      ∃ j ∈ zone x τ m, ¬ POfP cs j x τ m)
    (hframe : ∀ j x τ m (b : Fin (wOfP cs τ.length) → D), τ.length < nOfP cs → ownOfP cs τ.length ≠ j →
      j ∈ zone x τ m → ¬ POfP cs j x τ m → SOfP cs j x (τ ++ [(m, List.ofFn b)]) →
        ∃ j' ∈ zone x τ m, j < j' ∧ ¬ POfP cs j' x τ m) :
    ZComposed (nOfP cs) (wOfP cs) (ownOfP cs) (SOfP cs) (POfP cs) (erOfP cs) zone₀ zone where
  own_round x τ m hτ hns := schedP_own_round cs x τ m hτ hns
  hand := hhand
  frame := hframe

/-- A sub-protocol's total, by index (`0` past the list). -/
noncomputable def totAtP (cs : List (SubProtP X M D)) (k : ℕ) : ℝ≥0∞ :=
  match cs[k]? with
  | some c => c.tot
  | none => 0

/-- **The rounds owned by a set of sub-protocols add up to the sub-protocols' totals.** -/
theorem sumErOfP_zone : ∀ (cs : List (SubProtP X M D)) (R : ℕ → Bool),
    ∑ i ∈ range (nOfP cs), (if R (ownOfP cs i) then erOfP cs i else 0)
      = ∑ k ∈ range cs.length, (if R k then totAtP cs k else 0)
  | [], R => by simp [nOfP]
  | c :: cs, R => by
    rw [nOfP, Finset.sum_range_add, List.length_cons, Finset.sum_range_succ', add_comm (∑ k ∈ range cs.length, _)]
    congr 1
    · have h : ∀ i ∈ range c.n, (if R (ownOfP (c :: cs) i) then erOfP (c :: cs) i else 0)
          = (if R 0 then c.er i else 0) := by
        intro i hi
        simp [ownOfP, erOfP, mem_range.mp hi]
      rw [sum_congr rfl h]
      by_cases hR : R 0
      · simp [hR, totAtP, SubProtP.tot]
      · simp [hR]
    · have h : ∀ i ∈ range (nOfP cs), (if R (ownOfP (c :: cs) (c.n + i)) then erOfP (c :: cs) (c.n + i) else 0)
          = (if (fun k => R (k + 1)) (ownOfP cs i) then erOfP cs i else 0) := by
        intro i _
        simp [ownOfP, erOfP]
      rw [sum_congr rfl h, sumErOfP_zone cs (fun k => R (k + 1))]
      refine sum_congr rfl (fun k _ => ?_)
      simp [totAtP]

/-- **`FSCompose.lean`'s sub-protocols as `SubProtP`**: their uniform error for each round, and `pre` their state before
the round (a claim fixed before the round). -/
def SubProt.toP (c : SubProt X M D) : SubProtP X M D where
  n := c.n
  w := c.w
  hasMsg := c.hasMsg
  er := fun _ => c.ε
  St := c.St
  pre := fun y τ _ => c.St y τ
  rbr := fun y τ m hτ hns => c.rbr.round y τ m hτ hns
  pend := c.pend
  pendM := fun x τ _ => c.pend x τ
  post := c.post

/-- The total of a carried-over sub-protocol is `n·ε`. -/
theorem SubProt.toP_tot (c : SubProt X M D) : c.toP.tot = (c.n : ℝ≥0∞) * c.ε := by
  simp [SubProtP.tot, SubProt.toP, sum_const, card_range, nsmul_eq_mul]

end SchedP

section SchedPFS

variable {X M D Q : Type} [Fintype D] [Nonempty D] [Fintype Q] [DecidableEq Q] [DecidableEq D]

/-- **A schedule on the code's chain, path-wise.** Sub-protocols with per-round errors (at most `εmax`) and
message-aware states run one after the other on one chain; the zones meet `hand` and `frame`; a false statement dooms
a sub-protocol of the starting zone, and the verifier rejects when a sub-protocol of the final zone is doomed. If along
every transcript the charged rounds are owned by the sub-protocols of a set `Zb` whose totals sum to at most `B`, a
prover making at most `q` hash queries gets a false statement accepted with probability at most
`q·εmax + B + collBound T D + collBound (T + 1) D`, `T = q + ℓW + 1`. -/
theorem fs_chain_sound_schedP_path (cs : List (SubProtP X M D)) (hwpos : ∀ c ∈ cs, ∀ i, 0 < c.w i) {m₀ : M}
    (C : ChainEnc (PItem X M) Q D) {Mf : Type} {L : X → Prop} {accept : X → List (M × List D) → Mf → Prop}
    (zone₀ : X → Finset ℕ) (zone : X → List (M × List D) → M → Finset ℕ)
    (hhand : ∀ x τ m, τ.length < nOfP cs → (∃ j ∈ lastZone zone₀ zone x τ, ¬ SOfP cs j x τ) →
      ∃ j ∈ zone x τ m, ¬ POfP cs j x τ m)
    (hframe : ∀ j x τ m (b : Fin (wOfP cs τ.length) → D), τ.length < nOfP cs → ownOfP cs τ.length ≠ j →
      j ∈ zone x τ m → ¬ POfP cs j x τ m → SOfP cs j x (τ ++ [(m, List.ofFn b)]) →
        ∃ j' ∈ zone x τ m, j < j' ∧ ¬ POfP cs j' x τ m)
    (εmax : ℝ≥0∞) (hε : ∀ c ∈ cs, ∀ i, i < c.n → c.er i ≤ εmax) (B : ℝ≥0∞)
    (hpath : ∀ x (τ : List (M × List D)), τ.length ≤ nOfP cs → ∃ Zb : Finset ℕ,
      (∀ i (hi : i < τ.length), ownOfP cs i ∈ zone x (τ.take i) (τ[i]).1 → ownOfP cs i ∈ Zb)
      ∧ ∑ k ∈ range cs.length, (if k ∈ Zb then totAtP cs k else 0) ≤ B)
    (hstart : ∀ x, ¬ L x → ∃ j ∈ zone₀ x, ¬ SOfP cs j x [])
    (hfinal : ∀ x τ mf, τ.length = nOfP cs → (∃ j ∈ lastZone zone₀ zone x τ, ¬ SOfP cs j x τ) →
      ¬ accept x τ mf)
    (q : ℕ) (A : OC Q D (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1
        ∧ chainAcceptsW (nOfP cs) (wOfP cs) (wOfP_pos cs hwpos) (msgOfP cs) m₀ accept C H (A.run H).1
          (A.run H).2.1 (A.run H).2.2)
      ≤ (q : ℝ≥0∞) * εmax + B + collBound (q + ℓW (nOfP cs) (wOfP cs) + 1) D
        + collBound (q + ℓW (nOfP cs) (wOfP cs) + 1 + 1) D := by
  classical
  refine fs_chain_sound_of_zpath (wOfP_pos cs hwpos) C (schedP_zcomposed cs zone₀ zone hhand hframe) εmax
    (fun i hi => erOfP_le cs εmax hε i hi) B (fun x τ hτ => ?_) hstart hfinal q A hA
  obtain ⟨Zb, hZ, hsum⟩ := hpath x τ hτ
  refine ⟨Zb, hZ, le_of_eq_of_le ?_ hsum⟩
  have h := sumErOfP_zone cs (fun k => decide (k ∈ Zb))
  simp only [decide_eq_true_eq] at h
  exact h

end SchedPFS

end ZK60.Sound
