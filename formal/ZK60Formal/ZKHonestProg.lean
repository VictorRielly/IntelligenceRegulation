/-
D63 lane L33 (2026-11-09), part 1: **a prover written as an oracle program IS a Fiat–Shamir receipt model** (L14's
`FSModel`) **and a query-bounded oracle computation** (`pOC`), with the same output.

L14's zero-knowledge step (`ZKW16Step.fs_step`, L19's weighted `fs_step_w`) takes the honest prover in two forms: a
receipt model `FSModel` (its points, causal in the values the oracle returned; its receipt, a function of the input, the
coins and those values) and an oracle computation `pOC`. Lanes L25 and L29 wrote the classify run's honest provers as
functions of a hash function and as transcript programs. This file is the bridge, generic in the prover:

* `PProg`: a prover's oracle program. Each question is tagged: `dep` (a PUBLIC point, the same for every input and
  coin: the transcript's creation and the header absorbs before the first fresh root; it is read from the oracle and
  never programmed) or `pt` (a point of programmed kind: a column digest, a salted leaf, a Merkle node, a transcript
  absorb or squeeze after the first fresh root, a position tag);
* `PProg.oc`, `PProg.run`, **`oc_run`**: the program as `Statements.lean`'s `OC`, and its run;
* `res`, `ptAt`: the program driven by VALUES (the `i`-th `pt` question is answered `v i`, a `dep` question by the
  oracle): its result, and its `j`-th `pt` question;
* **`res_eq_run`**: if every `pt` question the value-driven walk asks has the oracle's own answer as its value, the walk
  IS the run against the oracle;
* `ptAt_congr` (causality: the `j`-th point reads only the values before `j`), `ptAt_sep` (the points read the oracle
  only at the `dep` questions), `ptAt_some_lt` (a program of at most `k` points);
* `ptsOf`, `outOf`, **`model`**: the `FSModel` of a family of programs: `k` points (the walk's points, then PAD points
  `pad j (v (j − 1))` when the program stopped early: a refusal), the receipt, the dependency set;
* **`model_prove`**: `(model …).prove H x c = (prog x c).run H`: the model's honest prover is the program's run, for
  every oracle, input and coin, whenever the program asks at most `k` points and its result does not read the `dep`
  answers directly (`hres`: they reach the receipt only through later points);
* `QLE`, **`oc_bounded`**: the program as a `q`-question computation.

Every premise is an explicit hypothesis.
-/
import ZK60Formal.ZKCountBudget

set_option autoImplicit false

namespace ZK60.ZKHonest

open ZK60 ZK60.ZKW16

/-- **A prover's oracle program**: `dep z k` reads the oracle at a public point `z`; `pt z k` asks it at a point of
programmed kind; each continuation reads the answer. -/
inductive PProg (Q D α : Type) where
  | ret : α → PProg Q D α
  | dep : Q → (D → PProg Q D α) → PProg Q D α
  | pt : Q → (D → PProg Q D α) → PProg Q D α

namespace PProg

variable {Q D α : Type}

/-- The program as an oracle computation (the tags forgotten). -/
def oc : PProg Q D α → OC Q D α
  | .ret a => .ret a
  | .dep z k => .ask z (fun d => oc (k d))
  | .pt z k => .ask z (fun d => oc (k d))

/-- Its run against an oracle. -/
def run (H : Q → D) : PProg Q D α → α
  | .ret a => a
  | .dep z k => run H (k (H z))
  | .pt z k => run H (k (H z))

/-- **The oracle computation runs the program.** -/
theorem oc_run (H : Q → D) : ∀ p : PProg Q D α, (oc p).run H = run H p
  | .ret _ => rfl
  | .dep z k => oc_run H (k (H z))
  | .pt z k => oc_run H (k (H z))

/-- At most `n` questions on every path. -/
def QLE : PProg Q D α → ℕ → Prop
  | .ret _, _ => True
  | .dep _ k, n => 0 < n ∧ ∀ d, QLE (k d) (n - 1)
  | .pt _ k, n => 0 < n ∧ ∀ d, QLE (k d) (n - 1)

/-- **The program is an `n`-question computation.** -/
theorem oc_bounded : ∀ (p : PProg Q D α) (n : ℕ), QLE p n → (oc p).Bounded n
  | .ret _, _, _ => trivial
  | .dep _ k, n, h => by
    obtain ⟨m, rfl⟩ : ∃ m, n = m + 1 := ⟨n - 1, by have := h.1; omega⟩
    intro d
    have hd := h.2 d
    rw [Nat.add_sub_cancel] at hd
    exact oc_bounded (k d) m hd
  | .pt _ k, n, h => by
    obtain ⟨m, rfl⟩ : ∃ m, n = m + 1 := ⟨n - 1, by have := h.1; omega⟩
    intro d
    have hd := h.2 d
    rw [Nat.add_sub_cancel] at hd
    exact oc_bounded (k d) m hd

/-! ## The program driven by values -/

/-- **The result of the value-driven walk** from point index `i`: a `dep` question is answered by the oracle, the
`pt` questions by `v i, v (i + 1), …` in order. -/
def res (H : Q → D) (v : ℕ → D) : PProg Q D α → ℕ → α
  | .ret a, _ => a
  | .dep z k, i => res H v (k (H z)) i
  | .pt _ k, i => res H v (k (v i)) (i + 1)

/-- **The `j`-th point of the value-driven walk** from point index `i` (`none` when the program stops before it). -/
def ptAt (H : Q → D) (v : ℕ → D) : PProg Q D α → ℕ → ℕ → Option Q
  | .ret _, _, _ => none
  | .dep z k, i, j => ptAt H v (k (H z)) i j
  | .pt z k, i, j => if j = i then some z else ptAt H v (k (v i)) (i + 1) j

/-- No point has an index below the walk's start. -/
theorem ptAt_lt (H : Q → D) (v : ℕ → D) : ∀ (p : PProg Q D α) (i j : ℕ), j < i → ptAt H v p i j = none
  | .ret _, _, _, _ => rfl
  | .dep z k, i, j, h => ptAt_lt H v (k (H z)) i j h
  | .pt z k, i, j, h => by
    show (if j = i then some z else ptAt H v (k (v i)) (i + 1) j) = none
    have hne : ¬ j = i := by omega
    rw [ite_eq_right hne]
    exact ptAt_lt H v (k (v i)) (i + 1) j (by omega)

/-- **Causality**: the `j`-th point reads only the values of index `i ≤ m < j`. -/
theorem ptAt_congr (H : Q → D) (v v' : ℕ → D) : ∀ (p : PProg Q D α) (i j : ℕ),
    (∀ m, i ≤ m → m < j → v m = v' m) → ptAt H v p i j = ptAt H v' p i j
  | .ret _, _, _, _ => rfl
  | .dep z k, i, j, h => ptAt_congr H v v' (k (H z)) i j h
  | .pt z k, i, j, h => by
    show (if j = i then some z else ptAt H v (k (v i)) (i + 1) j)
      = (if j = i then some z else ptAt H v' (k (v' i)) (i + 1) j)
    by_cases hji : j = i
    · rw [ite_eq_left hji, ite_eq_left hji]
    · rw [ite_eq_right hji, ite_eq_right hji]
      rcases Nat.lt_or_gt_of_ne hji with hlt | hgt
      · rw [ptAt_lt H v _ (i + 1) j (by omega), ptAt_lt H v' _ (i + 1) j (by omega)]
      · rw [h i le_rfl hgt]
        exact ptAt_congr H v v' (k (v' i)) (i + 1) j (fun m hm hmj => h m (by omega) hmj)

/-- Every `dep` question of the program, on every path, lies in `S`. -/
def DepIn (S : Set Q) : PProg Q D α → Prop
  | .ret _ => True
  | .dep z k => z ∈ S ∧ ∀ d, DepIn S (k d)
  | .pt _ k => ∀ d, DepIn S (k d)

/-- **The points read the oracle only at the `dep` questions.** -/
theorem ptAt_sep (S : Set Q) (H H' : Q → D) (hH : ∀ z ∈ S, H z = H' z) (v : ℕ → D) :
    ∀ (p : PProg Q D α) (i j : ℕ), DepIn S p → ptAt H v p i j = ptAt H' v p i j
  | .ret _, _, _, _ => rfl
  | .dep z k, i, j, h => by
    show ptAt H v (k (H z)) i j = ptAt H' v (k (H' z)) i j
    rw [hH z h.1]
    exact ptAt_sep S H H' hH v (k (H' z)) i j (h.2 _)
  | .pt z k, i, j, h => by
    show (if j = i then some z else ptAt H v (k (v i)) (i + 1) j)
      = (if j = i then some z else ptAt H' v (k (v i)) (i + 1) j)
    rw [ptAt_sep S H H' hH v (k (v i)) (i + 1) j (h _)]

/-- At most `n` points (`pt` questions) on every path. -/
def PtLE : PProg Q D α → ℕ → Prop
  | .ret _, _ => True
  | .dep _ k, n => ∀ d, PtLE (k d) n
  | .pt _ k, n => 0 < n ∧ ∀ d, PtLE (k d) (n - 1)

/-- A program of at most `n` points has no point of index `i + n` or beyond. -/
theorem ptAt_some_lt (H : Q → D) (v : ℕ → D) : ∀ (p : PProg Q D α) (n i j : ℕ) (z : Q), PtLE p n →
    ptAt H v p i j = some z → j < i + n
  | .ret _, _, _, _, z, _, h => by
    have h' : (none : Option Q) = some z := h
    cases h'
  | .dep z' k, n, i, j, z, hp, h => ptAt_some_lt H v (k (H z')) n i j z (hp _) h
  | .pt z' k, n, i, j, z, hp, h => by
    have h' : (if j = i then some z' else ptAt H v (k (v i)) (i + 1) j) = some z := h
    have hn := hp.1
    by_cases hji : j = i
    · omega
    · rw [ite_eq_right hji] at h'
      have := ptAt_some_lt H v (k (v i)) (n - 1) (i + 1) j z (hp.2 _) h'
      omega

/-- **The value-driven walk is the run** when every point it asks has the oracle's own answer as its value. -/
theorem res_eq_run (H : Q → D) (v : ℕ → D) : ∀ (p : PProg Q D α) (i : ℕ),
    (∀ j z, ptAt H v p i j = some z → v j = H z) → res H v p i = run H p
  | .ret _, _, _ => rfl
  | .dep z k, i, h => res_eq_run H v (k (H z)) i h
  | .pt z k, i, h => by
    have hi : v i = H z := h i z (by
      show (if i = i then some z else ptAt H v (k (v i)) (i + 1) i) = some z
      rw [ite_eq_left rfl])
    show res H v (k (v i)) (i + 1) = run H (k (H z))
    rw [hi]
    refine res_eq_run H v (k (H z)) (i + 1) (fun j z' hj => h j z' ?_)
    show (if j = i then some z else ptAt H v (k (v i)) (i + 1) j) = some z'
    have hne : ¬ j = i := by
      intro hji
      rw [hji, ptAt_lt H v _ (i + 1) i (by omega)] at hj
      cases hj
    rw [ite_eq_right hne, hi]
    exact hj

/-! ## The receipt model of a program -/

section Model

variable [Inhabited D] {k : ℕ}

/-- **The `k` points of a program** at the values `v`: the walk's points; where the program stopped early (a refusal),
PAD points `pad j (v (j − 1))`, which carry the previous value (so they are as fresh as a transcript state) and no
data. -/
def ptsOf (pad : ℕ → D → Q) (p : PProg Q D α) (H : Q → D) (v : Fin k → D) (i : Fin k) : Q :=
  (ptAt H (extend v) p 0 i).getD (pad i (if (i : ℕ) = 0 then default else extend v ((i : ℕ) - 1)))

/-- **The receipt of a program** at the values `v` (the `dep` questions answered by a fixed oracle: `model_prove`
asks that the result not read them). -/
def outOf (p : PProg Q D α) (v : Fin k → D) : α := res (fun _ => default) (extend v) p 0

theorem ptsOf_causal (pad : ℕ → D → Q) (p : PProg Q D α) (H : Q → D) : Causal (ptsOf (k := k) pad p H) := by
  intro v v' i h
  have hext : ∀ m, m < (i : ℕ) → extend v m = extend v' m := by
    intro m hm
    have hmk : m < k := lt_trans hm i.isLt
    show (if h : m < k then v ⟨m, h⟩ else default) = (if h : m < k then v' ⟨m, h⟩ else default)
    rw [dite_eq_left hmk, dite_eq_left hmk]
    exact h ⟨m, hmk⟩ hm
  show (ptAt H (extend v) p 0 i).getD (pad i (if (i : ℕ) = 0 then default else extend v ((i : ℕ) - 1)))
    = (ptAt H (extend v') p 0 i).getD (pad i (if (i : ℕ) = 0 then default else extend v' ((i : ℕ) - 1)))
  rw [ptAt_congr H (extend v) (extend v') p 0 i (fun m _ hm => hext m hm)]
  by_cases h0 : (i : ℕ) = 0
  · rw [ite_eq_left h0, ite_eq_left h0]
  · rw [ite_eq_right h0, ite_eq_right h0, hext ((i : ℕ) - 1) (by omega)]

theorem ptsOf_sep (pad : ℕ → D → Q) (p : PProg Q D α) (S : Set Q) (hS : DepIn S p) (H H' : Q → D)
    (hH : ∀ z ∈ S, H z = H' z) (v : Fin k → D) : ptsOf pad p H v = ptsOf pad p H' v := by
  funext i
  show (ptAt H (extend v) p 0 i).getD _ = (ptAt H' (extend v) p 0 i).getD _
  rw [ptAt_sep S H H' hH (extend v) p 0 i hS]

/-- **The receipt at the honest chain is the program's run.** For a program of at most `k` points whose result does not
read the `dep` answers (`hres`), the receipt at the chain of values the oracle gives at the program's own points is the
program's run against that oracle. -/
theorem outOf_chain (pad : ℕ → D → Q) (p : PProg Q D α) (H : Q → D) (hk : PtLE p k)
    (hres : ∀ (H' : Q → D) (v : ℕ → D), res H' v p 0 = res (fun _ => default) v p 0) :
    outOf p (chainVals (ptsOf (k := k) pad p H) H) = run H p := by
  have hc := ptsOf_causal (k := k) pad p H
  show res (fun _ => default) (extend (chainVals (ptsOf pad p H) H)) p 0 = run H p
  rw [← hres H]
  refine res_eq_run H _ p 0 (fun j z hj => ?_)
  have hjk : j < k := by
    have := ptAt_some_lt H _ p k 0 j z hk hj
    omega
  have hfix := chainVals_fix hc H ⟨j, hjk⟩
  have hpt : ptsOf pad p H (chainVals (ptsOf pad p H) H) ⟨j, hjk⟩ = z := by
    show (ptAt H (extend (chainVals (ptsOf pad p H) H)) p 0 j).getD _ = z
    rw [hj]
    rfl
  rw [hpt] at hfix
  show (if h : j < k then chainVals (ptsOf pad p H) H ⟨j, h⟩ else default) = H z
  rw [dite_eq_left hjk]
  exact hfix

variable {X C Out : Type}

/-- **The Fiat–Shamir receipt model of a family of prover programs** (L14's `FSModel`): the points and the receipt are
the programs'; the dependency set contains every `dep` question (`hdep`); the visible points and how the receipt shows
them (`vis`, `vp`, `hvis`) are the instance's. -/
def model (k : ℕ) (pad : ℕ → D → Q) (prog : X → C → PProg Q D Out) (dep : X → C → Set Q)
    (hdep : ∀ x c, DepIn (dep x c) (prog x c)) (vis : (Fin k → D) → Fin k → Prop)
    (vp : Out → (Q → D) → (Fin k → D) → Fin k → Q)
    (hvis : ∀ x c H v i, vis v i → ptsOf pad (prog x c) H v i = vp (outOf (prog x c) v) H v i) :
    FSModel Q D X C Out where
  k := k
  dep := dep
  pts x c H v := ptsOf pad (prog x c) H v
  out x c v := outOf (prog x c) v
  vis := vis
  vp := vp
  causal x c H := ptsOf_causal pad (prog x c) H
  sep x c H H' v h := ptsOf_sep pad (prog x c) (dep x c) (hdep x c) H H' h v
  vis_pts := hvis

/-- **The model's honest prover is the program's run** (the same receipt for every oracle, input and coin). -/
theorem model_prove (k : ℕ) (pad : ℕ → D → Q) (prog : X → C → PProg Q D Out) (dep : X → C → Set Q)
    (hdep : ∀ x c, DepIn (dep x c) (prog x c)) (vis : (Fin k → D) → Fin k → Prop)
    (vp : Out → (Q → D) → (Fin k → D) → Fin k → Q)
    (hvis : ∀ x c H v i, vis v i → ptsOf pad (prog x c) H v i = vp (outOf (prog x c) v) H v i)
    (H : Q → D) (x : X) (c : C) (hk : PtLE (prog x c) k)
    (hres : ∀ (H' : Q → D) (v : ℕ → D), res H' v (prog x c) 0 = res (fun _ => default) v (prog x c) 0) :
    (model k pad prog dep hdep vis vp hvis).prove H x c = run H (prog x c) :=
  outOf_chain pad (prog x c) H hk hres

end Model

end PProg

end ZK60.ZKHonest
