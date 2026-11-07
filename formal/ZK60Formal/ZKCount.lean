/-
D63 step L19 (Statement 2, zero knowledge), part 3: WEIGHTED query budgets and the per-point counts, for the sharper
count of finding L14-1 (its fix (a)).

L14's budget charges every query of the hybrid's context at ONE worst-case rate: `q₁·K` before the request and
`q₂·KU` after it, with `q₁ = q + j·qp` and `q₂ = q + R·qp`. The other receipts' honest provers sit inside each step's
context, so their `qp` queries are charged at the distinguisher's worst-case rate, which gives the `R²·qp·δ` term that
caps `R`. But the provers' queries have KINDS (the code keys every hash by its role, D19 T-1: column digest, salted
leaf, Merkle node, Fiat–Shamir), and a query of one kind can only hit points of that kind; most of a prover's queries
(its column digests, leaves and nodes) can only hit points of 300 to 512 bits of freshness. This file gives the tools to
charge each query at ITS OWN rate:

* **`WB`** (a weighted budget): on every path, the questions' weights `wt z` add up to at most `W`; `WB.mono`,
  `WB.bind`, `WB_of_bounded` (an `n`-question computation with weights at most `w` is within `n·w`),
  `WB.queries_sum` (along the run, the weights of the questions asked add up to at most `W`), `sum_toFinset_le`;
* `wtrunc`, `wtrunc_wb`, `wtrunc_eq`: the weighted truncation (stop asking once the budget would be exceeded);
* `within_mono`: `OC.Within` budgets can be raised;
* the per-point counts the instance needs, generic: `hit_card_le_sum` (a query is hit by some point at most as often
  as the sum over the points), **`hit_card_label`** (if every point carries a fixed label read off the query, e.g. its
  key, its squeeze counter, its absorb label and data, then only the points of the query's label count: the
  MULTIPLICITY bound), **`fresh_card`** (a point that is injective in a fresh coordinate is hit at most `|rest|` times:
  the `2^-256` of a fresh state or salt, the `2^-512` of a salted leaf whose column digest is itself fresh), and
  **`hidden_card_of_cond`** (a hidden point with conditional min-entropy given the receipt: `hU` in weighted form).

Every premise is an explicit hypothesis.
-/
import ZK60Formal.ZKW16Shape

namespace ZK60.ZKCount

open scoped ENNReal
open Finset

/-! ## Weighted query budgets -/

section WB

variable {I O α β : Type}

/-- **A weighted query budget**: on every path, the weights `wt z` of the questions asked add up to at most `W`. -/
def WB (wt : I → ℕ) : OC I O α → ℕ → Prop
  | .ret _, _ => True
  | .ask z k, W => wt z ≤ W ∧ ∀ o, WB wt (k o) (W - wt z)

theorem WB.mono {wt : I → ℕ} : ∀ {A : OC I O α} {W W' : ℕ}, WB wt A W → W ≤ W' → WB wt A W' := by
  intro A
  induction A with
  | ret a => intros; trivial
  | ask z k ih =>
    intro W W' hA hW
    exact ⟨hA.1.trans hW, fun o => ih o (hA.2 o) (by omega)⟩

/-- The weighted budgets of a composition add up. -/
theorem WB.bind {wt : I → ℕ} {k : α → OC I O β} {W₂ : ℕ} (hk : ∀ a, WB wt (k a) W₂) :
    ∀ {A : OC I O α} {W₁ : ℕ}, WB wt A W₁ → WB wt (A.bind k) (W₁ + W₂) := by
  intro A
  induction A with
  | ret a =>
    intro W₁ _
    exact (hk a).mono (by omega)
  | ask z c ih =>
    intro W₁ hA
    refine ⟨by have := hA.1; omega, fun o => ?_⟩
    have h := ih o (hA.2 o)
    exact h.mono (by have := hA.1; omega)

/-- A computation of at most `n` questions, each of weight at most `w`, is within the weighted budget `n·w`. -/
theorem WB_of_bounded {wt : I → ℕ} {w : ℕ} (hw : ∀ z, wt z ≤ w) :
    ∀ {A : OC I O α} {n : ℕ}, A.Bounded n → WB wt A (n * w) := by
  intro A
  induction A with
  | ret a => intros; trivial
  | ask z k ih =>
    intro n hA
    cases n with
    | zero => exact absurd hA (by simp [OC.Bounded])
    | succ n =>
      refine ⟨(hw z).trans (Nat.le_mul_of_pos_left w (Nat.succ_pos n)), fun o => (ih o (hA o)).mono ?_⟩
      have e : (n + 1) * w = n * w + w := by ring
      rw [e]
      exact Nat.le_sub_of_add_le (Nat.add_le_add_left (hw z) _)

/-- Along the run against any oracle, the weights of the questions asked add up to at most the budget. -/
theorem WB.queries_sum {wt : I → ℕ} (f : I → O) :
    ∀ {A : OC I O α} {W : ℕ}, WB wt A W → ((OC.queries f A).map wt).sum ≤ W := by
  intro A
  induction A with
  | ret a => intro W _; simp [OC.queries, OC.runLog]
  | ask z k ih =>
    intro W hA
    rw [OC.queries_ask, List.map_cons, List.sum_cons]
    have := ih (f z) (hA.2 (f z))
    have := hA.1
    omega

/-- A sum over the distinct elements of a list is at most the sum over the list (nonnegative weights). -/
theorem sum_toFinset_le [DecidableEq I] (f : I → ℕ) : ∀ L : List I, ∑ z ∈ L.toFinset, f z ≤ (L.map f).sum := by
  intro L
  induction L with
  | nil => simp
  | cons a L ih =>
    rw [List.toFinset_cons, List.map_cons, List.sum_cons]
    by_cases ha : a ∈ L.toFinset
    · rw [Finset.insert_eq_of_mem ha]
      omega
    · rw [Finset.sum_insert ha]
      omega

/-- The distinct questions of a run within a weighted budget weigh at most the budget. -/
theorem WB.toFinset_sum [DecidableEq I] {wt : I → ℕ} (f : I → O) {A : OC I O α} {W : ℕ} (hA : WB wt A W) :
    ∑ z ∈ (OC.queries f A).toFinset, wt z ≤ W :=
  (sum_toFinset_le wt _).trans (hA.queries_sum f)

/-- **The weighted truncation**: ask while the budget allows, answer `false` once a question would exceed it. -/
def wtrunc (wt : I → ℕ) : OC I O Bool → ℕ → OC I O Bool
  | .ret b, _ => .ret b
  | .ask z k, W => if wt z ≤ W then .ask z (fun o => wtrunc wt (k o) (W - wt z)) else .ret false

theorem wtrunc_wb (wt : I → ℕ) : ∀ (A : OC I O Bool) (W : ℕ), WB wt (wtrunc wt A W) W := by
  intro A
  induction A with
  | ret b => intro W; trivial
  | ask z k ih =>
    intro W
    by_cases h : wt z ≤ W
    · show WB wt (if wt z ≤ W then OC.ask z (fun o => wtrunc wt (k o) (W - wt z)) else OC.ret false) W
      rw [ite_eq_left h]
      exact ⟨h, fun o => ih o (W - wt z)⟩
    · show WB wt (if wt z ≤ W then OC.ask z (fun o => wtrunc wt (k o) (W - wt z)) else OC.ret false) W
      rw [ite_eq_right h]
      trivial

/-- A computation within the weighted budget is unchanged by the weighted truncation. -/
theorem wtrunc_eq (wt : I → ℕ) : ∀ (A : OC I O Bool) (W : ℕ), WB wt A W → wtrunc wt A W = A := by
  intro A
  induction A with
  | ret b => intro W _; rfl
  | ask z k ih =>
    intro W hA
    show (if wt z ≤ W then OC.ask z (fun o => wtrunc wt (k o) (W - wt z)) else OC.ret false) = OC.ask z k
    rw [ite_eq_left hA.1]
    exact congrArg (OC.ask z) (funext fun o => ih o (W - wt z) (hA.2 o))

end WB

/-- `OC.Within` budgets can be raised. -/
theorem within_mono {Q X O α : Type} : ∀ {A : OC (Q ⊕ X) O α} {q r q' r' : ℕ}, A.Within q r → q ≤ q' → r ≤ r' →
    A.Within q' r' := by
  intro A
  induction A with
  | ret a => intros; trivial
  | ask i k ih =>
    intro q r q' r' hA hq hr
    cases i with
    | inl z =>
      cases q with
      | zero => exact absurd hA (by simp [OC.Within])
      | succ q =>
        obtain ⟨q'', rfl⟩ : ∃ q'', q' = q'' + 1 := ⟨q' - 1, by omega⟩
        exact fun o => ih o (hA o) (by omega) hr
    | inr x =>
      cases r with
      | zero => exact absurd hA (by simp [OC.Within])
      | succ r =>
        obtain ⟨r'', rfl⟩ : ∃ r'', r' = r'' + 1 := ⟨r' - 1, by omega⟩
        exact fun o => ih o (hA o) hq (by omega)

/-! ## Per-point counts (the instance's tools) -/

section Points

variable {Ω Q : Type} [Fintype Ω] [DecidableEq Q] {k : ℕ}

open Classical in
/-- A query is hit by some point at most as often as the sum over the points. -/
theorem hit_card_le_sum (P : Ω → Fin k → Q) (z : Q) :
    (univ.filter (fun s => ∃ i, P s i = z)).card ≤ ∑ i, (univ.filter (fun s => P s i = z)).card := by
  classical
  calc (univ.filter (fun s => ∃ i, P s i = z)).card
      ≤ (univ.biUnion (fun i => univ.filter (fun s => P s i = z))).card := by
        refine card_le_card (fun s hs => ?_)
        obtain ⟨i, hi⟩ := (mem_filter.mp hs).2
        exact mem_biUnion.mpr ⟨i, mem_univ _, mem_filter.mpr ⟨mem_univ _, hi⟩⟩
    _ ≤ ∑ i, (univ.filter (fun s => P s i = z)).card := card_biUnion_le

open Classical in
/-- **The multiplicity bound.** If every point carries a fixed label read off the point itself (`lab (P s i) = ℓ i`: its
hash key, a squeeze's counter, an absorb's label and data), and each point is hit by a query at most `κ` times, then a
query is hit by some point at most `m·κ` times, `m` the number of points with the query's label. -/
theorem hit_card_label {L : Type} [DecidableEq L] (P : Ω → Fin k → Q) (lab : Q → L) (ℓ : Fin k → L)
    (hlab : ∀ s i, lab (P s i) = ℓ i) (z : Q) (κ : ℕ) (hκ : ∀ i, (univ.filter (fun s => P s i = z)).card ≤ κ) :
    (univ.filter (fun s => ∃ i, P s i = z)).card ≤ (univ.filter (fun i => ℓ i = lab z)).card * κ := by
  classical
  calc (univ.filter (fun s => ∃ i, P s i = z)).card
      ≤ ((univ.filter (fun i => ℓ i = lab z)).biUnion (fun i => univ.filter (fun s => P s i = z))).card := by
        refine card_le_card (fun s hs => ?_)
        obtain ⟨i, hi⟩ := (mem_filter.mp hs).2
        refine mem_biUnion.mpr ⟨i, mem_filter.mpr ⟨mem_univ _, ?_⟩, mem_filter.mpr ⟨mem_univ _, hi⟩⟩
        rw [← hlab s i, hi]
    _ ≤ ∑ i ∈ univ.filter (fun i => ℓ i = lab z), (univ.filter (fun s => P s i = z)).card := card_biUnion_le
    _ ≤ ∑ _i ∈ univ.filter (fun i => ℓ i = lab z), κ := sum_le_sum (fun i _ => hκ i)
    _ = (univ.filter (fun i => ℓ i = lab z)).card * κ := by rw [sum_const, smul_eq_mul]

end Points

section Fresh

variable {A B Q : Type} [Fintype A] [Fintype B] [DecidableEq Q]

open Classical in
/-- **A fresh coordinate.** A point that is injective in a uniform coordinate `B` (a fresh state, a salt, a fresh
column digest and a salt together) equals a given query for at most `|A|` of the `|A × B|` outcomes: rate `1/|B|`. -/
theorem fresh_card (P : A × B → Q) (hinj : ∀ a, Function.Injective (fun b => P (a, b))) (z : Q) :
    (univ.filter (fun s : A × B => P s = z)).card ≤ Fintype.card A := by
  classical
  rw [ZK60.ZKW16.card_filter_prod]
  calc ∑ a : A, (univ.filter (fun b : B => P (a, b) = z)).card ≤ ∑ _a : A, 1 := by
        refine sum_le_sum (fun a _ => ?_)
        exact card_le_one.mpr (fun b hb b' hb' =>
          hinj a ((mem_filter.mp hb).2.trans (mem_filter.mp hb').2.symm))
    _ = Fintype.card A := by simp

end Fresh

section Hidden

variable {C Q Out : Type} [Fintype C] [DecidableEq Q] [DecidableEq Out] {k : ℕ}

open Classical in
/-- **Hidden points with conditional min-entropy given the receipt** (`hU` in weighted form). Suppose that for every
receipt value `o`, hidden point `i` and query `z`, among the coins that give the receipt `o`, at most a `1/N` share
put the hidden point `i` at `z` (`hcond`: the point keeps `log N` bits given the receipt; an unopened column's entries
beyond the view's linear constraints, an unopened leaf's salt). Then for every query set `Z o` read off the receipt,
the coins that put some hidden point in it number at most `k·|Z|·|C|/N`: `N·count ≤ k·Σ|Z o|·...`, stated here as
`N · count ≤ k · B · |C|` when every `|Z o| ≤ B`. -/
theorem hidden_card_of_cond (pts : C → Fin k → Q) (hid : Fin k → Prop) (out : C → Out) (N : ℕ)
    (hcond : ∀ o i z, hid i →
      N * (univ.filter (fun c => out c = o ∧ pts c i = z)).card ≤ (univ.filter (fun c => out c = o)).card)
    (Z : Out → Finset Q) (B : ℕ) (hZ : ∀ o, (Z o).card ≤ B) :
    N * (univ.filter (fun c => ∃ i, hid i ∧ pts c i ∈ Z (out c))).card ≤ k * B * Fintype.card C := by
  classical
  -- split the coins by their receipt
  have hsplit : (univ.filter (fun c => ∃ i, hid i ∧ pts c i ∈ Z (out c))).card
      ≤ ∑ o ∈ univ.image out, ∑ i ∈ univ.filter hid, ∑ z ∈ Z o,
          (univ.filter (fun c => out c = o ∧ pts c i = z)).card := by
    calc (univ.filter (fun c => ∃ i, hid i ∧ pts c i ∈ Z (out c))).card
        ≤ ((univ.image out).biUnion (fun o => (univ.filter hid).biUnion (fun i => (Z o).biUnion
            (fun z => univ.filter (fun c => out c = o ∧ pts c i = z))))).card := by
          refine card_le_card (fun c hc => ?_)
          obtain ⟨i, hi, hz⟩ := (mem_filter.mp hc).2
          refine mem_biUnion.mpr ⟨out c, mem_image_of_mem _ (mem_univ _), ?_⟩
          refine mem_biUnion.mpr ⟨i, mem_filter.mpr ⟨mem_univ _, hi⟩, ?_⟩
          exact mem_biUnion.mpr ⟨pts c i, hz, mem_filter.mpr ⟨mem_univ _, rfl, rfl⟩⟩
      _ ≤ ∑ o ∈ univ.image out, ((univ.filter hid).biUnion (fun i => (Z o).biUnion
            (fun z => univ.filter (fun c => out c = o ∧ pts c i = z)))).card := card_biUnion_le
      _ ≤ ∑ o ∈ univ.image out, ∑ i ∈ univ.filter hid, ((Z o).biUnion
            (fun z => univ.filter (fun c => out c = o ∧ pts c i = z))).card :=
          sum_le_sum (fun o _ => card_biUnion_le)
      _ ≤ _ := sum_le_sum (fun o _ => sum_le_sum (fun i _ => card_biUnion_le))
  -- each receipt class: `N · Σ_i Σ_z count ≤ k · B · #{out = o}`
  have hclass : ∀ o, N * ∑ i ∈ univ.filter hid, ∑ z ∈ Z o,
      (univ.filter (fun c => out c = o ∧ pts c i = z)).card ≤ k * B * (univ.filter (fun c => out c = o)).card := by
    intro o
    rw [mul_sum]
    calc ∑ i ∈ univ.filter hid, N * ∑ z ∈ Z o, (univ.filter (fun c => out c = o ∧ pts c i = z)).card
        ≤ ∑ _i ∈ univ.filter hid, B * (univ.filter (fun c => out c = o)).card := by
          refine sum_le_sum (fun i hi => ?_)
          rw [mul_sum]
          calc ∑ z ∈ Z o, N * (univ.filter (fun c => out c = o ∧ pts c i = z)).card
              ≤ ∑ _z ∈ Z o, (univ.filter (fun c => out c = o)).card :=
                sum_le_sum (fun z _ => hcond o i z (mem_filter.mp hi).2)
            _ = (Z o).card * (univ.filter (fun c => out c = o)).card := by rw [sum_const, smul_eq_mul]
            _ ≤ B * (univ.filter (fun c => out c = o)).card := Nat.mul_le_mul_right _ (hZ o)
      _ = (univ.filter hid).card * (B * (univ.filter (fun c => out c = o)).card) := by rw [sum_const, smul_eq_mul]
      _ ≤ k * (B * (univ.filter (fun c => out c = o)).card) := by
          refine Nat.mul_le_mul_right _ ?_
          exact (card_filter_le _ _).trans (by simp)
      _ = k * B * (univ.filter (fun c => out c = o)).card := by ring
  -- the receipt classes partition the coins
  have hpart : ∑ o ∈ univ.image out, (univ.filter (fun c => out c = o)).card = Fintype.card C :=
    (card_eq_sum_card_image out univ).symm.trans card_univ
  calc N * (univ.filter (fun c => ∃ i, hid i ∧ pts c i ∈ Z (out c))).card
      ≤ N * ∑ o ∈ univ.image out, ∑ i ∈ univ.filter hid, ∑ z ∈ Z o,
          (univ.filter (fun c => out c = o ∧ pts c i = z)).card := Nat.mul_le_mul_left _ hsplit
    _ = ∑ o ∈ univ.image out, N * ∑ i ∈ univ.filter hid, ∑ z ∈ Z o,
          (univ.filter (fun c => out c = o ∧ pts c i = z)).card := by rw [mul_sum]
    _ ≤ ∑ o ∈ univ.image out, k * B * (univ.filter (fun c => out c = o)).card := sum_le_sum (fun o _ => hclass o)
    _ = k * B * Fintype.card C := by rw [← mul_sum, hpart]

end Hidden

end ZK60.ZKCount
