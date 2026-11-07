/-
D63 lane L27 (2026-11-07), part 2: **each kind's schedule on the classify run's ONE transcript, part by part** (L24's
`FirstKind`, deliverable 1).

L24 counts the run's extraction by kinds of sub-protocols (`FirstKind`): one schedule per kind on the run's chain,
holding that kind's sub-protocols of every part (stage IN-C, the blocks, stage OUT-C), with every premise of the
first-doom count. This file builds such a kind from the parts:

* `runCat`, `mem_runCat`, `pairwise_runCat`, `sortedA_of_pairwise`: the parts' lists in the run's order; windows in
  order across the parts when each part's windows lie between its offsets on the run's chain;
* `AgreeOn`, `forall₂_getElem?`, `isFirst_congr`, **`firstSt_congr`**, `forall₂_runCat`: two schedules whose
  sub-protocols agree one by one (entered doomed alike, alive alike) have the same first-doom state;
* `liftC_congr`, **`agreeOn_of_st`**: two sub-protocols with the same window, rounds and release agree on a chain when
  their states agree on its header (what a log-reading state needs);
* **`RunChain`**: the run's ONE transcript as a chain (the code's chain encoding of `ItB Lq` items, the step parse `W`,
  the steps, the verifier's heads read off the statement and receipt, `ℓ`, the header `s`);
* **`KindRun`**: one kind, part by part: `np` parts with offsets, each part's sub-protocols at their absolute windows
  between its offsets, round-by-round sound (`RbrWide`), errors `≤ εmax`, `n·ε ≤ B`, no releases, and every state
  reading the prover's log only through the cuts at the roots its header absorbs (`hcut`);
* **`KindRun.toFirstKind`**: the kind as L24's `FirstKind` on the run's chain: windows in order (`sortedA_run`), no
  releases, the rbr lemmas, and **L24-2's weak stability `hstab` PROVED** from `hcut` (`RunChainStab.lean`'s
  `cutEq_esc`);
* `allSt_iff_mem`, **`KindRun.ev_of_parts`**: the kind's event from the parts: some part's sub-protocol entered doomed
  and every part's sub-protocols alive at the end;
* the per-kind constants: `PowForm` (one error per round: `M`, the openings' `opA`, `opB`), `SqForm` (squeeze runs:
  the slots, the define draws, LogUp's three squeezes, the stages' single challenges), **`lin_of_powForm`**,
  **`lin_of_sqForm`**, **`lin_of_lkForm`**: each kind's linear part `q·εmax + B ≤ (q + 1)·c/2^126` at L20/L21's figures.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunChainStab

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## The parts in the run's order -/

section Cat

variable {β : Type _}

/-- **The parts' lists in the run's order**: part `0`, …, part `n − 1` (D12a: stage IN-C, the blocks, stage OUT-C). -/
def runCat (f : ℕ → List β) : ℕ → List β
  | 0 => []
  | n + 1 => runCat f n ++ f n

theorem mem_runCat (f : ℕ → List β) (x : β) : ∀ n, x ∈ runCat f n ↔ ∃ i, i < n ∧ x ∈ f i
  | 0 => by simp [runCat]
  | n + 1 => by
    rw [runCat, List.mem_append, mem_runCat f x n]
    constructor
    · rintro (⟨i, hi, hx⟩ | hx)
      · exact ⟨i, by omega, hx⟩
      · exact ⟨n, by omega, hx⟩
    · rintro ⟨i, hi, hx⟩
      by_cases h : i < n
      · exact Or.inl ⟨i, h, hx⟩
      · obtain rfl : i = n := by omega
        exact Or.inr hx

/-- **Ordered across the parts**: each part ordered, and every element of an earlier part related to every element
of a later one. -/
theorem pairwise_runCat (R : β → β → Prop) (f : ℕ → List β) (hf : ∀ i, (f i).Pairwise R)
    (hcross : ∀ i j, i < j → ∀ x ∈ f i, ∀ y ∈ f j, R x y) : ∀ n, (runCat f n).Pairwise R
  | 0 => List.Pairwise.nil
  | n + 1 => by
    rw [runCat, List.pairwise_append]
    refine ⟨pairwise_runCat R f hf hcross n, hf n, fun x hx y hy => ?_⟩
    obtain ⟨i, hi, hxi⟩ := (mem_runCat f x n).mp hx
    exact hcross i n hi x hxi y hy

theorem forall₂_append' {α γ : Type _} {R : α → γ → Prop} {l₁ l₂ : List α} {m₁ m₂ : List γ}
    (h₁ : List.Forall₂ R l₁ m₁) (h₂ : List.Forall₂ R l₂ m₂) : List.Forall₂ R (l₁ ++ l₂) (m₁ ++ m₂) := by
  induction h₁ with
  | nil => simpa using h₂
  | cons hab _ ih => exact List.Forall₂.cons hab ih

theorem forall₂_runCat {α γ : Type _} {R : α → γ → Prop} (f : ℕ → List α) (g : ℕ → List γ)
    (h : ∀ i, List.Forall₂ R (f i) (g i)) : ∀ n, List.Forall₂ R (runCat f n) (runCat g n)
  | 0 => List.Forall₂.nil
  | n + 1 => forall₂_append' (forall₂_runCat f g h n) (h n)

theorem forall₂_getElem? {α γ : Type _} {R : α → γ → Prop} {l₁ : List α} {l₂ : List γ}
    (h : List.Forall₂ R l₁ l₂) :
    ∀ k : ℕ, (l₁[k]? = none ∧ l₂[k]? = none) ∨ ∃ x y, l₁[k]? = some x ∧ l₂[k]? = some y ∧ R x y := by
  induction h with
  | nil => exact fun k => Or.inl ⟨by simp, by simp⟩
  | cons hab _ ih =>
    intro k
    cases k with
    | zero => exact Or.inr ⟨_, _, rfl, rfl, hab⟩
    | succ k => simpa only [List.getElem?_cons_succ] using ih k

end Cat

/-! ## Windows in order -/

section Sorted

variable {D : Type}

/-- **Windows in order from the list's order**: L24's `SortedA` from `Pairwise`. -/
theorem sortedA_of_pairwise (cs : List (CSub D)) (h : cs.Pairwise (fun c c' => c.a ≤ c'.a)) : SortedA cs := by
  intro i j ci cj hij hi hj
  obtain ⟨hi1, hi2⟩ := List.getElem?_eq_some_iff.mp hi
  obtain ⟨hj1, hj2⟩ := List.getElem?_eq_some_iff.mp hj
  rw [← hi2, ← hj2]
  exact List.pairwise_iff_getElem.mp h i j hi1 hj1 hij

/-- Offsets that never decrease. -/
theorem off_mono (off : ℕ → ℕ) (hoff : ∀ i, off i ≤ off (i + 1)) : ∀ i j, i ≤ j → off i ≤ off j := by
  intro i j hij
  induction j with
  | zero =>
    obtain rfl : i = 0 := by omega
    exact le_rfl
  | succ j ih =>
    rcases Nat.lt_or_ge i (j + 1) with h | h
    · exact (ih (by omega)).trans (hoff j)
    · obtain rfl : i = j + 1 := by omega
      exact le_rfl

/-- **The run's schedule of a kind has its windows in order** when each part's are, and each part's windows lie
between its offsets (`off i ≤ a ≤ off (i + 1)`, offsets nondecreasing). -/
theorem sortedA_run (off : ℕ → ℕ) (hoff : ∀ i, off i ≤ off (i + 1)) (f : ℕ → List (CSub D))
    (hseg : ∀ i, ∀ c ∈ f i, off i ≤ c.a ∧ c.a ≤ off (i + 1)) (hsort : ∀ i, (f i).Pairwise (fun c c' => c.a ≤ c'.a))
    (n : ℕ) : SortedA (runCat f n) :=
  sortedA_of_pairwise _ (pairwise_runCat _ f hsort (fun i j hij x hx y hy =>
    (hseg i x hx).2.trans ((off_mono off hoff (i + 1) j hij).trans (hseg j y hy).1)) n)

end Sorted

/-! ## Two schedules that agree sub-protocol by sub-protocol -/

section Agree

variable {D : Type}

/-- **Two sub-protocols agree on a chain**: they entered their windows doomed alike and are alive alike there. -/
def AgreeOn (W : UInt64 → ℕ) (τ : List (TItem × D)) (c c' : CSub D) : Prop :=
  (EntD W c τ ↔ EntD W c' τ) ∧ (subSt W c τ ↔ subSt W c' τ)

theorem isFirst_congr (W : UInt64 → ℕ) (τ : List (TItem × D)) {cs cs' : List (CSub D)}
    (h : List.Forall₂ (AgreeOn W τ) cs cs') (k : ℕ) : IsFirst W cs τ k ↔ IsFirst W cs' τ k := by
  have hk := forall₂_getElem? h
  have hent : ∀ j : ℕ, (∃ c, cs[j]? = some c ∧ EntD W c τ) ↔ (∃ c, cs'[j]? = some c ∧ EntD W c τ) := by
    intro j
    rcases hk j with ⟨h1, h2⟩ | ⟨x, y, h1, h2, hxy⟩
    · simp [h1, h2]
    · rw [h1, h2]
      constructor
      · rintro ⟨c, hc, he⟩
        obtain rfl := Option.some.inj hc
        exact ⟨y, rfl, hxy.1.mp he⟩
      · rintro ⟨c, hc, he⟩
        obtain rfl := Option.some.inj hc
        exact ⟨x, rfl, hxy.1.mpr he⟩
  unfold IsFirst
  constructor
  · rintro ⟨h1, h2⟩
    refine ⟨(hent k).mp h1, fun j hj c hc he => ?_⟩
    obtain ⟨c', hc', he'⟩ := (hent j).mpr ⟨c, hc, he⟩
    exact h2 j hj c' hc' he'
  · rintro ⟨h1, h2⟩
    refine ⟨(hent k).mpr h1, fun j hj c hc he => ?_⟩
    obtain ⟨c', hc', he'⟩ := (hent j).mp ⟨c, hc, he⟩
    exact h2 j hj c' hc' he'

/-- **Two schedules that agree sub-protocol by sub-protocol have the same first-doom state.** -/
theorem firstSt_congr (W : UInt64 → ℕ) (τ : List (TItem × D)) {cs cs' : List (CSub D)}
    (h : List.Forall₂ (AgreeOn W τ) cs cs') : firstSt W cs τ ↔ firstSt W cs' τ := by
  have hk := forall₂_getElem? h
  unfold firstSt
  constructor
  · intro hf k c hfk hc
    rcases hk k with ⟨_, h2⟩ | ⟨x, y, h1, h2, hxy⟩
    · rw [h2] at hc
      cases hc
    · rw [h2] at hc
      obtain rfl := Option.some.inj hc
      exact hxy.2.mp (hf k x ((isFirst_congr W τ h k).mpr hfk) h1)
  · intro hf k c hfk hc
    rcases hk k with ⟨h1, _⟩ | ⟨x, y, h1, h2, hxy⟩
    · rw [h1] at hc
      cases hc
    · rw [h1] at hc
      obtain rfl := Option.some.inj hc
      exact hxy.2.mpr (hf k y ((isFirst_congr W τ h k).mp hfk) h2)

theorem liftC_congr (P P' : List (List UInt8 × List D) → Prop) (h : ∀ ptr, P ptr ↔ P' ptr) :
    ∀ st : CRS D, liftC P st ↔ liftC P' st
  | none => Iff.rfl
  | some (ptr, _, _) => h ptr

/-- **Two sub-protocols with the same window, rounds and release agree on a chain when their states agree on its
header** (the form of a log-reading state at two logs). -/
theorem agreeOn_of_st (W : UInt64 → ℕ) (τ : List (TItem × D)) (c c' : CSub D) (ha : c.a = c'.a) (hR : c.R = c'.R)
    (hSt : ∀ τr, c.St (τ.take c.a) τr ↔ c'.St (τ.take c.a) τr) (hrel : c.rel τ ↔ c'.rel τ) : AgreeOn W τ c c' := by
  unfold AgreeOn EntD subSt rdAlive
  rw [← ha, ← hR]
  refine ⟨?_, ?_⟩
  · rw [hSt []]
  · rw [liftC_congr _ _ hSt, hrel]

end Agree

/-! ## The run's chain and one kind on it -/

section Kind

variable {Lq : ℕ} {α : Type}

/-- **The classify run's ONE transcript as a chain** (D12a: the run header, stage IN-C, the blocks, stage OUT-C on one
keyed transcript): the code's chain encoding of `ItB Lq` items, the step parse `W` and steps `S` (a step's continuation
its head or squeezes, `StepCont`), the verifier's heads read off the prover's output (statement and receipt), the
chain's length bound `ℓ` and a header of `s` entries before every window. -/
structure RunChain (Lq : ℕ) (α : Type) where
  W : UInt64 → ℕ
  hW : ∀ k, 0 < W k
  C : ChainEnc (ItB Lq) (QB Lq) Dig
  S : Steps (ItB Lq)
  hS : StepsOK W (fun it : ItB Lq => it.1) S
  hcont : StepCont S
  heads : α → List (ItB Lq)
  ℓ : ℕ
  hℓ : ∀ o, ((heads o).flatMap S.items).length ≤ ℓ
  s : ℕ
  hhd : ∀ o, (((heads o).take s).flatMap S.items).length ≤ s

/-- The run's chain at an oracle, for a prover's output. -/
def RunChain.chain (RC : RunChain Lq α) (G : QB Lq → Dig) (o : α) : List (TItem × Dig) :=
  cChain RC.C (fun it : ItB Lq => it.1) RC.S G (RC.heads o)

/-- **One kind of sub-protocol on the run's chain, part by part** (D63 lane L27). `tr G o` is the run's ONE transcript
(the code's trace of the run verifier's operations on the prover's output `o`); the kind reads it through its own
parse `RC` (its step parse `W` and steps: L21's squeeze runs use single steps, L20/L22's `M` and openings the wide runs),
whose chain IS that transcript (`htr`). The run's `np` parts in the D12a order (stage IN-C, the blocks, stage OUT-C):
part `i`'s sub-protocols of this kind at their ABSOLUTE windows on the run's chain, between the part's offsets
`off i ≤ a ≤ off (i + 1)`, each round-by-round sound with its error at most `εmax`, `n·ε ≤ B`, no releases, every window
after the header (`s < off 0`), and every state reading the prover's log only through the cuts at the roots its header
absorbs (`hcut`). -/
structure KindRun (tr : (QB Lq → Dig) → α → List (TItem × Dig)) where
  RC : RunChain Lq α
  htr : ∀ G o, RC.chain G o = tr G o
  np : ℕ
  off : ℕ → ℕ
  hoff : ∀ i, off i ≤ off (i + 1)
  hs0 : RC.s < off 0
  cs : ℕ → List (QB Lq × Dig) → List (CSub Dig)
  hseg : ∀ i P, ∀ c ∈ cs i P, off i ≤ c.a ∧ c.a ≤ off (i + 1)
  hsort : ∀ i P, (cs i P).Pairwise (fun c c' => c.a ≤ c'.a)
  εmax : ℝ≥0∞
  hR : ∀ i P, ∀ c ∈ cs i P, RbrWide c.R.n c.R.w c.St c.ε
  hε : ∀ i P, ∀ c ∈ cs i P, c.ε ≤ εmax
  hnorel : ∀ i P, ∀ c ∈ cs i P, ∀ τ, ¬ c.rel τ
  B : ℝ≥0∞
  hB : ∀ i P, ∀ c ∈ cs i P, (c.R.n : ℝ≥0∞) * c.ε ≤ B
  hcut : ∀ (i : ℕ) (P P' : List (QB Lq × Dig)) (τ : List (TItem × Dig)), CutEq (Exec.Block.absOfC RC.C) τ P P' →
    List.Forall₂ (AgreeOn RC.W τ) (cs i P) (cs i P')

variable {tr : (QB Lq → Dig) → α → List (TItem × Dig)}

/-- **The kind's schedule on the run's chain**: every part's sub-protocols, in the run's order. -/
def KindRun.sched (K : KindRun tr) (P : List (QB Lq × Dig)) : List (CSub Dig) := runCat (fun i => K.cs i P) K.np

theorem KindRun.mem_sched (K : KindRun tr) (P : List (QB Lq × Dig)) (c : CSub Dig) :
    c ∈ K.sched P ↔ ∃ i, i < K.np ∧ c ∈ K.cs i P :=
  mem_runCat _ c K.np

/-- **The kind as L24's `FirstKind`** on the run's chain: windows in order, the rbr lemmas, no releases, windows after
the header, and L24-2's weak stability at the escaping step from the cut-reading states (`cutEq_esc`). -/
noncomputable def KindRun.toFirstKind (K : KindRun tr) : FirstKind Lq α where
  It := ItB Lq
  W := K.RC.W
  hW := K.RC.hW
  C := K.RC.C
  toT := fun it => it.1
  S := K.RC.S
  hS := K.RC.hS
  heads := K.RC.heads
  ℓ := K.RC.ℓ
  hℓ := K.RC.hℓ
  s := K.RC.s
  hhd := K.RC.hhd
  cs := K.sched
  hsort := fun P => sortedA_run K.off K.hoff (fun i => K.cs i P) (fun i => K.hseg i P) (fun i => K.hsort i P) K.np
  εmax := K.εmax
  hR := fun P c hc => by
    obtain ⟨i, -, hci⟩ := (K.mem_sched P c).mp hc
    exact K.hR i P c hci
  hε := fun P c hc => by
    obtain ⟨i, -, hci⟩ := (K.mem_sched P c).mp hc
    exact K.hε i P c hci
  hnorel := fun P c hc => by
    obtain ⟨i, -, hci⟩ := (K.mem_sched P c).mp hc
    exact K.hnorel i P c hci
  B := K.B
  hB := fun P c hc => by
    obtain ⟨i, -, hci⟩ := (K.mem_sched P c).mp hc
    exact K.hB i P c hci
  hwin := fun P c hc => by
    obtain ⟨i, -, hci⟩ := (K.mem_sched P c).mp hc
    exact lt_of_lt_of_le K.hs0 ((off_mono K.off K.hoff 0 i (Nat.zero_le _)).trans (K.hseg i P c hci).1)
  hstab := by
    intro A H L t τ qs it e2 hc _ _ hq _ ht _ ext hext τ' hτ'
    exact firstSt_congr K.RC.W τ' (forall₂_runCat (fun i => K.cs i (proverLog A (L.take t)))
      (fun i => K.cs i (proverLog A L)) (fun i => K.hcut i _ _ τ'
        (cutEq_esc K.RC.C K.RC.S K.RC.hcont A H L t τ qs it e2 hc hq ht ext hext τ' hτ')) K.np)

theorem KindRun.toFirstKind_cs (K : KindRun tr) : K.toFirstKind.cs = K.sched := rfl
theorem KindRun.toFirstKind_εmax (K : KindRun tr) : K.toFirstKind.εmax = K.εmax := rfl
theorem KindRun.toFirstKind_B (K : KindRun tr) : K.toFirstKind.B = K.B := rfl
theorem KindRun.toFirstKind_ℓ (K : KindRun tr) : K.toFirstKind.ℓ = K.RC.ℓ := rfl

/-- The combined state, sub-protocol by sub-protocol. -/
theorem allSt_iff_mem {D : Type} (W : UInt64 → ℕ) (cs : List (CSub D)) (τ : List (TItem × D)) :
    allSt W cs τ ↔ ∀ c ∈ cs, subSt W c τ := by
  constructor
  · intro h c hc
    obtain ⟨k, hk⟩ := List.mem_iff_getElem?.mp hc
    exact h k c hk
  · intro h k c hc
    exact h c (List.mem_of_getElem? hc)

/-- **The kind's event from the parts**: if some part's sub-protocol of the kind entered its window doomed on the run's
transcript, and every part's sub-protocols of the kind are alive at its end, the kind's event (L24's `FirstKind.Ev`)
holds. -/
theorem KindRun.ev_of_parts (K : KindRun tr) (A : OC (QB Lq) Dig α) (G : QB Lq → Dig)
    (hent : ∃ i, i < K.np ∧ ∃ c ∈ K.cs i (A.runLog G).2, EntD K.RC.W c (tr G (A.run G)))
    (hall : ∀ i, i < K.np → allSt K.RC.W (K.cs i (A.runLog G).2) (tr G (A.run G))) :
    K.toFirstKind.Ev A G := by
  obtain ⟨i, hi, c, hc, he⟩ := hent
  have hcm : c ∈ K.sched (A.runLog G).2 := (K.mem_sched _ c).mpr ⟨i, hi, hc⟩
  obtain ⟨k, hk⟩ := List.mem_iff_getElem?.mp hcm
  have hch : cChain K.RC.C (fun it : ItB Lq => it.1) K.RC.S G (K.RC.heads (A.run G)) = tr G (A.run G) :=
    K.htr G (A.run G)
  unfold FirstKind.Ev
  show (∃ (k : ℕ) (c : CSub Dig), (K.sched (A.runLog G).2)[k]? = some c
      ∧ EntD K.RC.W c (cChain K.RC.C (fun it : ItB Lq => it.1) K.RC.S G (K.RC.heads (A.run G))))
    ∧ allSt K.RC.W (K.sched (A.runLog G).2) (cChain K.RC.C (fun it : ItB Lq => it.1) K.RC.S G (K.RC.heads (A.run G)))
  rw [hch]
  refine ⟨⟨k, c, hk, he⟩, (allSt_iff_mem _ _ _).mpr (fun c' hc' => ?_)⟩
  obtain ⟨j, hj, hcj⟩ := (K.mem_sched _ c').mp hc'
  exact (allSt_iff_mem _ _ _).mp (hall j hj) c' hcj

end Kind

/-! ## The per-kind constants -/

section Constants

variable {Lq : ℕ} {α : Type} {tr : (QB Lq → Dig) → α → List (TItem × Dig)}

/-- **A kind of one error per round** (`M`: three rounds `≤ 2^-106`; the openings' `opA`, `opB`: one round each):
`εmax ≤ 2^-j`, `B ≤ n·2^-j`. -/
def KindRun.PowForm (K : KindRun tr) (n j : ℕ) : Prop :=
  K.εmax ≤ (2⁻¹ : ℝ≥0∞) ^ j ∧ K.B ≤ (n : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ j

/-- **A kind of squeeze runs** (the slots, the define draws, LogUp, the stages' single challenges): each round's error
at most `emax·fibC/|Dig|` and every sub-protocol's `n·ε` at most `ND·fibC/|Dig|` (`fibC` the digests per
`challenge_fp2` value). -/
def KindRun.SqForm (K : KindRun tr) (emax ND : ℕ) : Prop :=
  K.εmax ≤ ((emax * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig ∧ K.B ≤ ((ND * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig

/-- **The one-error-per-round kinds' linear part** (L20's `lin_le_u126`): `q·εmax + B ≤ (q + 1)·n·2^(126 − j)/2^126`. -/
theorem lin_of_powForm (K : KindRun tr) (n j : ℕ) (hj : j ≤ 126) (hn : 1 ≤ n) (h : K.PowForm n j) (q : ℕ) :
    (q : ℝ≥0∞) * K.εmax + K.B ≤ u126 q (n * 2 ^ (126 - j)) :=
  (add_le_add (mul_le_mul' le_rfl h.1) h.2).trans (lin_le_u126 q n j hj hn _ le_rfl)

/-- `challenge_fp2`'s digest count against `p²` (L21's arithmetic): `a·fibC/|Dig| ≤ a/p²·(1 + p/2^128)²`. -/
theorem fibC_div_le (a : ℕ) :
    ((a * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig
      ≤ (a : ℝ≥0∞) / ((gP ^ 2 : ℕ) : ℝ≥0∞) * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2 := by
  have hF : Fintype.card (Fin gP × Fin gP) = gP ^ 2 := by
    rw [Fintype.card_prod, Fintype.card_fin, sq]
  have h := dig_bound_le (K := Fin gP × Fin gP) gP hF a
  rw [hF] at h
  exact h

/-- **The squeeze-run kinds' linear part** (L20's `slots_le_u126`): `q·εmax + B ≤ (q + 1)·(emax + ND)/2^126`. -/
theorem lin_of_sqForm (K : KindRun tr) (emax ND : ℕ) (h : K.SqForm emax ND) (q : ℕ) :
    (q : ℝ≥0∞) * K.εmax + K.B ≤ u126 q (emax + ND) := by
  refine (add_le_add (mul_le_mul' le_rfl h.1) h.2).trans ?_
  have harith : (q : ℝ≥0∞) * (((emax * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig)
      + ((ND * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig
      = (((q * emax + ND) * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig := by
    rw [← mul_div_assoc, ENNReal.div_add_div_same, ← Nat.cast_mul, ← Nat.cast_add]
    congr 2
    ring
  rw [harith]
  exact (fibC_div_le _).trans (slots_le_u126 gP (by norm_num [gP]) (by norm_num [gP]) q emax ND)

/-- **LogUp's kind** (three squeezes, each escaping on at most `e` challenges, and the stages' LogUp `α` no more):
`SqForm e (3e)`, so its linear part is within `(q + 1)·c/2^126` for any `c` bounding `(q·e + 3e)/p²·(1 + p/2^128)²`
(L21's `lk_main_le_u126`: `26,370,000` for `e ≤ 35,153,256`; L24's `lk_main_le_u126_r13`: `50,331,700` for
`e ≤ 2^26`). -/
theorem lin_of_lkForm (K : KindRun tr) (e : ℕ) (h : K.SqForm e (3 * e)) (q c : ℕ)
    (hc : ((q * e + 3 * e : ℕ) : ℝ≥0∞) / ((gP ^ 2 : ℕ) : ℝ≥0∞) * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      ≤ u126 q c) :
    (q : ℝ≥0∞) * K.εmax + K.B ≤ u126 q c := by
  refine (add_le_add (mul_le_mul' le_rfl h.1) h.2).trans ?_
  have harith : (q : ℝ≥0∞) * (((e * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig)
      + ((3 * e * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig
      = (((q * e + 3 * e) * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig := by
    rw [← mul_div_assoc, ENNReal.div_add_div_same, ← Nat.cast_mul, ← Nat.cast_add]
    congr 2
    ring
  rw [harith]
  exact (fibC_div_le _).trans hc

/-- LogUp's kind at W16R2 (`e ≤ 35,153,256`): within `(q + 1)·26,370,000/2^126`. -/
theorem lin_lk_w16r2 (K : KindRun tr) (e : ℕ) (he : e ≤ 35153256) (h : K.SqForm e (3 * e)) (q : ℕ) :
    (q : ℝ≥0∞) * K.εmax + K.B ≤ u126 q 26370000 :=
  lin_of_lkForm K e h q _ (Exec.Block.lk_main_le_u126 gP (by norm_num [gP]) (by norm_num [gP]) q e he)

/-- LogUp's kind at R13 (`e ≤ 2^26`): within `(q + 1)·50,331,700/2^126`. -/
theorem lin_lk_r13 (K : KindRun tr) (e : ℕ) (he : e ≤ 2 ^ 26) (h : K.SqForm e (3 * e)) (q : ℕ) :
    (q : ℝ≥0∞) * K.εmax + K.B ≤ u126 q 50331700 :=
  lin_of_lkForm K e h q _ (lk_main_le_u126_r13 gP (by norm_num [gP]) (by norm_num [gP]) q e he)

end Constants

end ZK60.ProtocolClassify
