/-
D63 lane L35 (2026-11-09), part 1: **the degree calculus of a slot polynomial read on its tables.**

A slot polynomial is `irEval ir (tables x)`: the slot's expression IR (`SlotW16Ir.lean`) evaluated on the values of
its tables at the point `x`. Two facts make its individual degree a function of the IR's SHAPE alone:

* every table of a slot is affine in each variable (multilinear): `AffAt`, `ConstAt` and their closure rules, with
  **`AffAt.prod_one`** (a product in which at most one factor depends on a variable is affine in it) and
  `indDegLE_one_of_affAt`;
* **`irEval_indDeg`**: if every table has individual degree `≤ 1`, the slot polynomial has individual degree
  `≤ irDeg ir`, where `irDeg` counts table factors through the nodes (an affine node counts `1`, a sum node the largest
  of its subterms, a term its wrappers plus its inner factors). `irDeg` reads no coefficient: `irDeg_map`.

Nothing here names a profile. Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.SlotPolyInstEval

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Exec.Slot

/-! ## Affine and constant in one variable -/

section Aff

variable {K : Type} [Field K] {N : ℕ}

/-- `f` does not read variable `i`. -/
def ConstAt (i : Fin N) (f : (Fin N → K) → K) : Prop :=
  ∀ (x : Fin N → K) (t : K), f (Function.update x i t) = f x

/-- `f` is affine in variable `i` (the others fixed). -/
def AffAt (i : Fin N) (f : (Fin N → K) → K) : Prop :=
  ∀ x : Fin N → K, ∃ a b : K, ∀ t : K, f (Function.update x i t) = a + b * t

theorem ConstAt.affAt {i : Fin N} {f : (Fin N → K) → K} (h : ConstAt i f) : AffAt i f :=
  fun x => ⟨f x, 0, fun t => by rw [h x t, zero_mul, add_zero]⟩

omit [Field K] in
theorem constAt_const (i : Fin N) (c : K) : ConstAt i (fun _ : Fin N → K => c) := fun _ _ => rfl

theorem ConstAt.add {i : Fin N} {f g : (Fin N → K) → K} (hf : ConstAt i f) (hg : ConstAt i g) :
    ConstAt i (fun x => f x + g x) := fun x t => by
  show f (Function.update x i t) + g (Function.update x i t) = f x + g x
  rw [hf x t, hg x t]

theorem ConstAt.sub {i : Fin N} {f g : (Fin N → K) → K} (hf : ConstAt i f) (hg : ConstAt i g) :
    ConstAt i (fun x => f x - g x) := fun x t => by
  show f (Function.update x i t) - g (Function.update x i t) = f x - g x
  rw [hf x t, hg x t]

theorem ConstAt.mul {i : Fin N} {f g : (Fin N → K) → K} (hf : ConstAt i f) (hg : ConstAt i g) :
    ConstAt i (fun x => f x * g x) := fun x t => by
  show f (Function.update x i t) * g (Function.update x i t) = f x * g x
  rw [hf x t, hg x t]

omit [Field K] in
theorem ConstAt.ite {i : Fin N} {f g : (Fin N → K) → K} (c : Prop) [Decidable c] (hf : ConstAt i f)
    (hg : ConstAt i g) : ConstAt i (fun x => if c then f x else g x) := fun x t => by
  show (if c then f (Function.update x i t) else g (Function.update x i t)) = if c then f x else g x
  rw [hf x t, hg x t]

theorem ConstAt.sum {ι : Type} [Fintype ι] {i : Fin N} (F : ι → (Fin N → K) → K) (h : ∀ j, ConstAt i (F j)) :
    ConstAt i (fun x => ∑ j, F j x) := fun x t => by
  show ∑ j, F j (Function.update x i t) = ∑ j, F j x
  exact Finset.sum_congr rfl (fun j _ => h j x t)

theorem ConstAt.prodOn {ι : Type} (s : Finset ι) {i : Fin N} (F : ι → (Fin N → K) → K)
    (h : ∀ j ∈ s, ConstAt i (F j)) : ConstAt i (fun x => ∏ j ∈ s, F j x) := fun x t => by
  show ∏ j ∈ s, F j (Function.update x i t) = ∏ j ∈ s, F j x
  exact Finset.prod_congr rfl (fun j hj => h j hj x t)

theorem ConstAt.listSum {ι : Type} {i : Fin N} (F : ι → (Fin N → K) → K) :
    ∀ l : List ι, (∀ j ∈ l, ConstAt i (F j)) → ConstAt i (fun x => (l.map fun j => F j x).sum)
  | [], _ => fun _ _ => rfl
  | a :: l, h => by
    have h1 := h a List.mem_cons_self
    have h2 := ConstAt.listSum F l (fun j hj => h j (List.mem_cons_of_mem a hj))
    intro x t
    show ((a :: l).map fun j => F j (Function.update x i t)).sum = ((a :: l).map fun j => F j x).sum
    rw [List.map_cons, List.sum_cons, List.map_cons, List.sum_cons, h1 x t]
    exact congrArg (fun z => F a x + z) (h2 x t)

theorem AffAt.add {i : Fin N} {f g : (Fin N → K) → K} (hf : AffAt i f) (hg : AffAt i g) :
    AffAt i (fun x => f x + g x) := by
  intro x
  obtain ⟨a1, b1, e1⟩ := hf x
  obtain ⟨a2, b2, e2⟩ := hg x
  refine ⟨a1 + a2, b1 + b2, fun t => ?_⟩
  show f (Function.update x i t) + g (Function.update x i t) = _
  rw [e1 t, e2 t]
  ring

theorem AffAt.sub {i : Fin N} {f g : (Fin N → K) → K} (hf : AffAt i f) (hg : AffAt i g) :
    AffAt i (fun x => f x - g x) := by
  intro x
  obtain ⟨a1, b1, e1⟩ := hf x
  obtain ⟨a2, b2, e2⟩ := hg x
  refine ⟨a1 - a2, b1 - b2, fun t => ?_⟩
  show f (Function.update x i t) - g (Function.update x i t) = _
  rw [e1 t, e2 t]
  ring

/-- Affine times a factor that does not read the variable. -/
theorem AffAt.mul_const {i : Fin N} {f g : (Fin N → K) → K} (hf : AffAt i f) (hg : ConstAt i g) :
    AffAt i (fun x => f x * g x) := by
  intro x
  obtain ⟨a, b, e⟩ := hf x
  refine ⟨a * g x, b * g x, fun t => ?_⟩
  show f (Function.update x i t) * g (Function.update x i t) = _
  rw [e t, hg x t]
  ring

theorem AffAt.const_mul {i : Fin N} {f g : (Fin N → K) → K} (hg : ConstAt i g) (hf : AffAt i f) :
    AffAt i (fun x => g x * f x) := by
  intro x
  obtain ⟨a, b, e⟩ := hf x
  refine ⟨g x * a, g x * b, fun t => ?_⟩
  show g (Function.update x i t) * f (Function.update x i t) = _
  rw [e t, hg x t]
  ring

theorem AffAt.ite {i : Fin N} {f g : (Fin N → K) → K} (c : Prop) [Decidable c] (hf : AffAt i f) (hg : AffAt i g) :
    AffAt i (fun x => if c then f x else g x) := by
  by_cases h : c
  · have e : (fun x => if c then f x else g x) = f := by
      funext x
      exact ite_eq_left h
    rw [e]
    exact hf
  · have e : (fun x => if c then f x else g x) = g := by
      funext x
      exact ite_eq_right h
    rw [e]
    exact hg

theorem AffAt.sum {ι : Type} [Fintype ι] {i : Fin N} (F : ι → (Fin N → K) → K) (h : ∀ j, AffAt i (F j)) :
    AffAt i (fun x => ∑ j, F j x) := by
  intro x
  choose a b hab using fun j => h j x
  refine ⟨∑ j, a j, ∑ j, b j, fun t => ?_⟩
  show ∑ j, F j (Function.update x i t) = _
  rw [Finset.sum_mul, ← Finset.sum_add_distrib]
  exact Finset.sum_congr rfl (fun j _ => hab j t)

theorem AffAt.listSum {ι : Type} {i : Fin N} (F : ι → (Fin N → K) → K) :
    ∀ l : List ι, (∀ j ∈ l, AffAt i (F j)) → AffAt i (fun x => (l.map fun j => F j x).sum)
  | [], _ => by
    show AffAt i (fun _ : Fin N → K => (0 : K))
    exact (constAt_const i (0 : K)).affAt
  | a :: l, h => by
    have h1 := h a List.mem_cons_self
    have h2 := AffAt.listSum F l (fun j hj => h j (List.mem_cons_of_mem a hj))
    show AffAt i (fun x => F a x + (l.map fun j => F j x).sum)
    exact h1.add h2

/-- **A product in which at most one factor reads the variable** (affinely) is affine in it. -/
theorem AffAt.prod_one {ι : Type} [Fintype ι] [DecidableEq ι] {i : Fin N} (F : ι → (Fin N → K) → K) (j0 : ι)
    (h0 : AffAt i (F j0)) (hc : ∀ j, j ≠ j0 → ConstAt i (F j)) : AffAt i (fun x => ∏ j, F j x) := by
  have e : (fun x => ∏ j, F j x) = fun x => F j0 x * ∏ j ∈ Finset.univ.erase j0, F j x := by
    funext x
    exact (Finset.mul_prod_erase Finset.univ (fun j => F j x) (Finset.mem_univ j0)).symm
  rw [e]
  exact h0.mul_const (ConstAt.prodOn _ F (fun j hj => hc j (Finset.ne_of_mem_erase hj)))

theorem ConstAt.prod {ι : Type} [Fintype ι] {i : Fin N} (F : ι → (Fin N → K) → K) (h : ∀ j, ConstAt i (F j)) :
    ConstAt i (fun x => ∏ j, F j x) := ConstAt.prodOn Finset.univ F (fun j _ => h j)

/-- The same over a finite set of indices. -/
theorem AffAt.prodOn_one {ι : Type} [DecidableEq ι] (s : Finset ι) {i : Fin N} (F : ι → (Fin N → K) → K) (j0 : ι)
    (h0 : AffAt i (F j0)) (hc : ∀ j ∈ s, j ≠ j0 → ConstAt i (F j)) : AffAt i (fun x => ∏ j ∈ s, F j x) := by
  by_cases hj : j0 ∈ s
  · have e : (fun x => ∏ j ∈ s, F j x) = fun x => F j0 x * ∏ j ∈ s.erase j0, F j x := by
      funext x
      exact (Finset.mul_prod_erase s (fun j => F j x) hj).symm
    rw [e]
    exact h0.mul_const (ConstAt.prodOn _ F
      (fun j hj' => hc j (Finset.mem_of_mem_erase hj') (Finset.ne_of_mem_erase hj')))
  · exact (ConstAt.prodOn s F (fun j hj' => hc j hj' (fun e => hj (e ▸ hj')))).affAt

/-- A product of two affine functions of which one does not read the variable. -/
theorem AffAt.mul_or {i : Fin N} {f g : (Fin N → K) → K} (hf : AffAt i f) (hg : AffAt i g)
    (h : ConstAt i f ∨ ConstAt i g) : AffAt i (fun x => f x * g x) := by
  rcases h with h | h
  · exact AffAt.const_mul h hg
  · exact hf.mul_const h

/-- A coordinate is affine in every variable. -/
theorem affAt_coord (i j : Fin N) : AffAt i (fun x : Fin N → K => x j) := by
  intro x
  by_cases h : j = i
  · subst h
    exact ⟨0, 1, fun t => by simp⟩
  · exact ⟨x j, 0, fun t => by simp [Function.update_of_ne h]⟩

omit [Field K] in
theorem constAt_coord (i j : Fin N) (h : j ≠ i) : ConstAt i (fun x : Fin N → K => x j) :=
  fun x t => Function.update_of_ne h t x

/-- **Affine in every variable gives individual degree `≤ 1`.** -/
theorem indDegLE_one_of_affAt {f : (Fin N → K) → K} (h : ∀ i, AffAt i f) : IndDegLE 1 f := by
  intro i x
  obtain ⟨a, b, hab⟩ := h i x
  refine ⟨Polynomial.C a + Polynomial.C b * Polynomial.X, ?_, fun t => ?_⟩
  · refine (Polynomial.natDegree_add_le _ _).trans (max_le ?_ ?_)
    · rw [Polynomial.natDegree_C]
      exact Nat.zero_le 1
    · exact (Polynomial.natDegree_C_mul_le _ _).trans Polynomial.natDegree_X_le
  · rw [hab t]
    simp

end Aff

/-! ## The IR's degree in its tables -/

section Deg

variable {α : Type}

/-- A factor's degree: a table counts `1`, a node its own degree. -/
def facDeg (nd : List ℕ) : Factor → ℕ
  | .tab _ => 1
  | .node i => nd.getD i 0

/-- A subterm's degree: the sum of its factors'. -/
def subDeg (nd : List ℕ) (s : SubTerm α) : ℕ := (s.factors.map (facDeg nd)).sum

/-- A node's degree: `1` for an affine node, the largest subterm for a sum node. -/
def bodyDeg (nd : List ℕ) : Body α → ℕ
  | .affine _ _ => 1
  | .sum ss => (ss.map (subDeg nd)).foldr max 0

/-- The nodes' degrees, in node order. -/
def nodeDegs : List (Body α) → List ℕ → List ℕ
  | [], nd => nd
  | b :: bs, nd => nodeDegs bs (nd ++ [bodyDeg nd b])

/-- A term's degree: its wrappers and its inner factors. -/
def termDeg (nd : List ℕ) (t : Term α) : ℕ := t.wrapper.length + (t.inner.map (facDeg nd)).sum

/-- **The slot polynomial's degree in its tables** (the largest term). -/
def irDeg (ir : Ir α) : ℕ := (ir.terms.map (termDeg (nodeDegs ir.nodes []))).foldr max 0

theorem bodyDeg_map {β : Type} (f : α → β) (nd : List ℕ) (b : Body α) : bodyDeg nd (b.map f) = bodyDeg nd b := by
  cases b with
  | affine k ts => rfl
  | sum ss =>
    show ((ss.map (SubTerm.map f)).map (subDeg nd)).foldr max 0 = (ss.map (subDeg nd)).foldr max 0
    rw [List.map_map]
    exact congrArg (List.foldr max 0) (List.map_congr_left fun s _ => rfl)

theorem nodeDegs_map {β : Type} (f : α → β) : ∀ (bs : List (Body α)) (nd : List ℕ),
    nodeDegs (bs.map (Body.map f)) nd = nodeDegs bs nd
  | [], _ => rfl
  | b :: bs, nd => by
    show nodeDegs (bs.map (Body.map f)) (nd ++ [bodyDeg nd (b.map f)]) = nodeDegs bs (nd ++ [bodyDeg nd b])
    rw [bodyDeg_map, nodeDegs_map f bs]

/-- **The degree reads no coefficient.** -/
theorem irDeg_map {β : Type} (f : α → β) (ir : Ir α) : irDeg (ir.map f) = irDeg ir := by
  show ((ir.terms.map (Term.map f)).map (termDeg (nodeDegs (ir.nodes.map (Body.map f)) []))).foldr max 0
    = (ir.terms.map (termDeg (nodeDegs ir.nodes []))).foldr max 0
  rw [nodeDegs_map, List.map_map]
  exact congrArg (List.foldr max 0) (List.map_congr_left fun t _ => rfl)

end Deg

section DegK

variable {K : Type} [Field K] {N : ℕ}

theorem getD_snoc {β : Type} (l : List β) (a d : β) (i : ℕ) :
    (l ++ [a]).getD i d = if i < l.length then l.getD i d else if i = l.length then a else d := by
  by_cases h : i < l.length
  · rw [ite_eq_left h, getD_append_lt _ _ _ _ h]
  · rw [ite_eq_right h, getD_append_ge _ _ _ _ (not_lt.mp h)]
    by_cases h2 : i = l.length
    · rw [ite_eq_left h2, h2, Nat.sub_self]
      rfl
    · rw [ite_eq_right h2]
      have h3 : 1 ≤ i - l.length := by omega
      rw [List.getD_eq_getElem?_getD, List.getElem?_eq_none_iff.mpr (by simpa using h3), Option.getD_none]

/-- A list sum of functions of degree `≤ d`. -/
theorem indDeg_listSum {ι : Type} (d : ℕ) (G : ι → (Fin N → K) → K) :
    ∀ l : List ι, (∀ j ∈ l, IndDegLE d (G j)) → IndDegLE d (fun x => (l.map fun j => G j x).sum)
  | [], _ => by
    show IndDegLE d (fun _ : Fin N → K => (0 : K))
    exact ZK60.StageX.IndDegLE.const (0 : K)
  | a :: l, h => by
    have h1 := h a List.mem_cons_self
    have h2 := indDeg_listSum d G l (fun j hj => h j (List.mem_cons_of_mem a hj))
    show IndDegLE d (fun x => G a x + (l.map fun j => G j x).sum)
    exact ZK60.StageX.IndDegLE.add h1 h2

/-- A list sum of functions, each with its own degree: the largest. -/
theorem indDeg_listSum_max {ι : Type} (D : ι → ℕ) (G : ι → (Fin N → K) → K) :
    ∀ l : List ι, (∀ j ∈ l, IndDegLE (D j) (G j)) →
      IndDegLE ((l.map D).foldr max 0) (fun x => (l.map fun j => G j x).sum)
  | [], _ => by
    show IndDegLE 0 (fun _ : Fin N → K => (0 : K))
    exact ZK60.StageX.IndDegLE.const (0 : K)
  | a :: l, h => by
    have h1 := h a List.mem_cons_self
    have h2 := indDeg_listSum_max D G l (fun j hj => h j (List.mem_cons_of_mem a hj))
    show IndDegLE (max (D a) ((l.map D).foldr max 0)) (fun x => G a x + (l.map fun j => G j x).sum)
    exact ZK60.StageX.IndDegLE.add (ZK60.StageX.IndDegLE.mono h1 (le_max_left _ _))
      (ZK60.StageX.IndDegLE.mono h2 (le_max_right _ _))

/-- A list product of functions, each with its own degree: the sum. -/
theorem indDeg_listProd {ι : Type} (D : ι → ℕ) (G : ι → (Fin N → K) → K) :
    ∀ l : List ι, (∀ j ∈ l, IndDegLE (D j) (G j)) →
      IndDegLE ((l.map D).sum) (fun x => (l.map fun j => G j x).prod)
  | [], _ => by
    show IndDegLE 0 (fun _ : Fin N → K => (1 : K))
    exact ZK60.StageX.IndDegLE.const (1 : K)
  | a :: l, h => by
    have h1 := h a List.mem_cons_self
    have h2 := indDeg_listProd D G l (fun j hj => h j (List.mem_cons_of_mem a hj))
    show IndDegLE (D a + (l.map D).sum) (fun x => G a x * (l.map fun j => G j x).prod)
    exact ZK60.StageX.IndDegLE.mul h1 h2

variable (v : (Fin N → K) → List K) (hv : ∀ i, IndDegLE 1 (fun x => (v x).getD i 0))

include hv

theorem fval_indDeg (nv : (Fin N → K) → List K) (nd : List ℕ)
    (hn : ∀ i, IndDegLE (nd.getD i 0) (fun x => (nv x).getD i 0)) (f : Factor) :
    IndDegLE (facDeg nd f) (fun x => fval (v x) (nv x) f) := by
  cases f with
  | tab i => exact hv i
  | node i => exact hn i

theorem bodyVal_indDeg (nv : (Fin N → K) → List K) (nd : List ℕ)
    (hn : ∀ i, IndDegLE (nd.getD i 0) (fun x => (nv x).getD i 0)) (b : Body K) :
    IndDegLE (bodyDeg nd b) (fun x => bodyVal (v x) (nv x) b) := by
  cases b with
  | affine k ts =>
    show IndDegLE 1 (fun x => k + (ts.map fun p => p.1 * (v x).getD p.2 0).sum)
    exact ZK60.StageX.IndDegLE.add (ZK60.StageX.IndDegLE.const k)
      (indDeg_listSum 1 (fun (p : K × ℕ) x => p.1 * (v x).getD p.2 0) ts
        (fun p _ => ZK60.StageX.IndDegLE.cmul p.1 (hv p.2)))
  | sum ss =>
    show IndDegLE ((ss.map (subDeg nd)).foldr max 0)
      (fun x => (ss.map fun s => s.coef * (s.factors.map (fval (v x) (nv x))).prod).sum)
    exact indDeg_listSum_max (subDeg nd) (fun (s : SubTerm K) x => s.coef * (s.factors.map (fval (v x) (nv x))).prod)
      ss (fun s _ => ZK60.StageX.IndDegLE.cmul s.coef
        (indDeg_listProd (facDeg nd) (fun f x => fval (v x) (nv x) f) s.factors
          (fun f _ => fval_indDeg v hv nv nd hn f)))

theorem nodeVals_indDeg : ∀ (bs : List (Body K)) (nv : (Fin N → K) → List K) (nd : List ℕ),
    (∀ x, (nv x).length = nd.length) → (∀ i, IndDegLE (nd.getD i 0) (fun x => (nv x).getD i 0)) →
    ∀ i, IndDegLE ((nodeDegs bs nd).getD i 0) (fun x => (nodeVals (v x) bs (nv x)).getD i 0)
  | [], _, _, _, hn => hn
  | b :: bs, nv, nd, hl, hn => by
    show ∀ i, IndDegLE ((nodeDegs bs (nd ++ [bodyDeg nd b])).getD i 0)
      (fun x => (nodeVals (v x) bs (nv x ++ [bodyVal (v x) (nv x) b])).getD i 0)
    refine nodeVals_indDeg bs (fun x => nv x ++ [bodyVal (v x) (nv x) b]) (nd ++ [bodyDeg nd b]) ?_ ?_
    · intro x
      show (nv x ++ [bodyVal (v x) (nv x) b]).length = (nd ++ [bodyDeg nd b]).length
      simp [hl x]
    · intro i
      show IndDegLE ((nd ++ [bodyDeg nd b]).getD i 0) (fun x => (nv x ++ [bodyVal (v x) (nv x) b]).getD i 0)
      have e : (fun x => (nv x ++ [bodyVal (v x) (nv x) b]).getD i 0)
          = fun x => if i < nd.length then (nv x).getD i 0 else if i = nd.length then bodyVal (v x) (nv x) b
            else 0 := by
        funext x
        rw [getD_snoc, hl x]
      rw [e, getD_snoc]
      by_cases h1 : i < nd.length
      · simp only [ite_eq_left h1]
        exact hn i
      · simp only [ite_eq_right h1]
        by_cases h2 : i = nd.length
        · simp only [ite_eq_left h2]
          exact bodyVal_indDeg v hv nv nd hn b
        · simp only [ite_eq_right h2]
          exact ZK60.StageX.IndDegLE.const (0 : K)

theorem termVal_indDeg (nv : (Fin N → K) → List K) (nd : List ℕ)
    (hn : ∀ i, IndDegLE (nd.getD i 0) (fun x => (nv x).getD i 0)) (t : Term K) :
    IndDegLE (termDeg nd t) (fun x => termVal (v x) (nv x) t) := by
  have hw : IndDegLE ((t.wrapper.map fun _ => 1).sum) (fun x => (t.wrapper.map fun w => (v x).getD w 0).prod) :=
    indDeg_listProd (fun _ => 1) (fun (w : ℕ) x => (v x).getD w 0) t.wrapper (fun w _ => hv w)
  have hi := indDeg_listProd (facDeg nd) (fun f x => fval (v x) (nv x) f) t.inner
    (fun f _ => fval_indDeg v hv nv nd hn f)
  have hlen : (t.wrapper.map fun _ => 1).sum = t.wrapper.length := by
    induction t.wrapper with
    | nil => rfl
    | cons a l ih =>
      rw [List.map_cons, List.sum_cons, ih, List.length_cons]
      omega
  rw [hlen] at hw
  show IndDegLE (t.wrapper.length + (t.inner.map (facDeg nd)).sum)
    (fun x => t.coef * (t.wrapper.map fun w => (v x).getD w 0).prod * (t.inner.map (fval (v x) (nv x))).prod)
  exact ZK60.StageX.IndDegLE.mul (ZK60.StageX.IndDegLE.cmul t.coef hw) hi

/-- **The slot polynomial's individual degree is at most the IR's degree in its tables**, when every table has
individual degree `≤ 1`. -/
theorem irEval_indDeg (ir : Ir K) : IndDegLE (irDeg ir) (fun x => irEval ir (v x)) := by
  have hn := nodeVals_indDeg v hv ir.nodes (fun _ => []) [] (fun _ => rfl)
    (fun i => by
      have e : (fun _ : Fin N → K => ([] : List K).getD i 0) = fun _ => (0 : K) := by
        funext _
        simp
      show IndDegLE (([] : List ℕ).getD i 0) (fun _ : Fin N → K => ([] : List K).getD i 0)
      rw [e]
      exact ZK60.StageX.IndDegLE.const (0 : K))
  show IndDegLE ((ir.terms.map (termDeg (nodeDegs ir.nodes []))).foldr max 0)
    (fun x => (ir.terms.map (termVal (v x) (nodeVals (v x) ir.nodes []))).sum)
  exact indDeg_listSum_max (termDeg (nodeDegs ir.nodes []))
    (fun (t : Term K) x => termVal (v x) (nodeVals (v x) ir.nodes []) t) ir.terms
    (fun t _ => termVal_indDeg v hv (fun x => nodeVals (v x) ir.nodes []) (nodeDegs ir.nodes []) hn t)

end DegK

end ZK60.Exec.Block
