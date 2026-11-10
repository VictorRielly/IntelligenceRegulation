/-
D63 lane L35 (2026-11-09), part 3: **a slot's tables as functions of the slot's point**, in the field.

The block verifier (`ExecBlockVerify.lean`) holds three kinds of table: `eq` over a point of challenges, a public
table of the slot's cube, and a private table, whose value it never computes: it takes the prover's terminal and hands
on a claim (`build_claim`) to the table's commitment. Here each kind is written as a function of the slot's point
`x = (ρ, e)` (`n` main variables, then the extension variables):

* `xg`, `xrK`, `yeK`, `selK`, `cmK`: the readers of a point (`ρ_k`, `e_j`, `sel = Π(1 − e_j)`, the mask coefficient
  `e_r·Π_{j > r}(1 − e_j)`), with what they are on the verifier's words (`toK_oneMinusProd`, `toK_maskCoef`);
* `coordK`, `ptK`, `claimPoint_getD_toK`: a private table's claim point, coordinate by coordinate;
* `PartSpec`, `privSpecs`, `specPart`, **`tabK`**: the tables' extensions. A private table's is L10's claim functional
  on the committed matrix `D.X cm` (`claimK`, `BlockDefineClaim.lean`) of `build_claim`'s parts:
  `cd·plane(point) + cm·(R_re + u·R_im)(tail)`;
* **`tabVals_toK`**: on an accepting slot (canonical challenges), every terminal value the verifier computes, and
  every masked terminal whose claim is TRUE of the matrices, is its table's extension at the slot's point;
* `PtFam`, `affAt_eqFam`, `affAt_partRowFam`, `affAt_keyColFam`, **`affAt_tabK`**, **`tabK_indDeg`**: every table's
  extension is affine in each variable (individual degree `≤ 1`), provided a private table's coordinates read each
  challenge at most once (`varsOKb`, the code's comment at `argument.rs:250`, here a checked condition).

Generic in the profile. Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockDefineAff
import ZK60Formal.BlockDefineClaim

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Exec
open ZK60.Circuit (gP GF)

/-! ## Reading a point -/

section Readers

variable {K : Type} [Field K] {N : ℕ}

/-- Variable `q` of a point (zero past its end). -/
def xg (x : Fin N → K) (q : ℕ) : K := if h : q < N then x ⟨q, h⟩ else 0

theorem affAt_xg (i : Fin N) (q : ℕ) : AffAt i (fun x : Fin N → K => xg x q) := by
  by_cases h : q < N
  · have e : (fun x : Fin N → K => xg x q) = fun x => x ⟨q, h⟩ := by
      funext x
      exact dite_eq_left h
    rw [e]
    exact affAt_coord i ⟨q, h⟩
  · have e : (fun x : Fin N → K => xg x q) = fun _ => (0 : K) := by
      funext x
      exact dite_eq_right h
    rw [e]
    exact (constAt_const i (0 : K)).affAt

theorem constAt_xg (i : Fin N) (q : ℕ) (hq : (i : ℕ) ≠ q) : ConstAt i (fun x : Fin N → K => xg x q) := by
  by_cases h : q < N
  · have e : (fun x : Fin N → K => xg x q) = fun x => x ⟨q, h⟩ := by
      funext x
      exact dite_eq_left h
    rw [e]
    exact constAt_coord i ⟨q, h⟩ (fun he => hq (congrArg Fin.val he).symm)
  · have e : (fun x : Fin N → K => xg x q) = fun _ => (0 : K) := by
      funext x
      exact dite_eq_right h
    rw [e]
    exact constAt_const i (0 : K)

/-- Main variable `k` of a slot with `n` main variables (zero past them). -/
def xrK (n : ℕ) (x : Fin N → K) (k : ℕ) : K := if k < n then xg x k else 0

/-- Extension variable `j`. -/
def yeK (n : ℕ) (x : Fin N → K) (j : ℕ) : K := xg x (n + j)

/-- `sel = Π_j (1 − e_j)`. -/
def selK (n e : ℕ) (x : Fin N → K) : K := ∏ j ∈ Finset.range e, (1 - yeK n x j)

/-- The mask coefficient of extension round `r`: `e_r·Π_{j > r} (1 − e_j)`. -/
def cmK (n e : ℕ) (x : Fin N → K) (r : ℕ) : K :=
  yeK n x r * ∏ j ∈ Finset.range e, (if r < j then 1 - yeK n x j else 1)

theorem affAt_xrK (n : ℕ) (i : Fin N) (k : ℕ) : AffAt i (fun x : Fin N → K => xrK n x k) := by
  by_cases h : k < n
  · have e : (fun x : Fin N → K => xrK n x k) = fun x => xg x k := by
      funext x
      exact ite_eq_left h
    rw [e]
    exact affAt_xg i k
  · have e : (fun x : Fin N → K => xrK n x k) = fun _ => (0 : K) := by
      funext x
      exact ite_eq_right h
    rw [e]
    exact (constAt_const i (0 : K)).affAt

theorem constAt_xrK (n : ℕ) (i : Fin N) (k : ℕ) (hik : n ≤ (i : ℕ) ∨ (i : ℕ) ≠ k) :
    ConstAt i (fun x : Fin N → K => xrK n x k) := by
  by_cases h : k < n
  · have e : (fun x : Fin N → K => xrK n x k) = fun x => xg x k := by
      funext x
      exact ite_eq_left h
    rw [e]
    exact constAt_xg i k (by omega)
  · have e : (fun x : Fin N → K => xrK n x k) = fun _ => (0 : K) := by
      funext x
      exact ite_eq_right h
    rw [e]
    exact constAt_const i (0 : K)

theorem affAt_yeK (n : ℕ) (i : Fin N) (j : ℕ) : AffAt i (fun x : Fin N → K => yeK n x j) := affAt_xg i (n + j)

theorem constAt_yeK (n : ℕ) (i : Fin N) (j : ℕ) (h : (i : ℕ) ≠ n + j) : ConstAt i (fun x : Fin N → K => yeK n x j) :=
  constAt_xg i (n + j) h

theorem affAt_selK (n e : ℕ) (i : Fin N) : AffAt i (fun x : Fin N → K => selK n e x) := by
  show AffAt i (fun x : Fin N → K => ∏ j ∈ Finset.range e, (1 - yeK n x j))
  refine AffAt.prodOn_one (Finset.range e) (fun j (x : Fin N → K) => 1 - yeK n x j) ((i : ℕ) - n)
    ((constAt_const i (1 : K)).affAt.sub (affAt_yeK n i _)) (fun j _ hne => ?_)
  exact (constAt_const i (1 : K)).sub (constAt_yeK n i j (fun h => hne (by omega)))

theorem constAt_selK (n e : ℕ) (i : Fin N) (h : (i : ℕ) < n) : ConstAt i (fun x : Fin N → K => selK n e x) := by
  show ConstAt i (fun x : Fin N → K => ∏ j ∈ Finset.range e, (1 - yeK n x j))
  exact ConstAt.prodOn (Finset.range e) (fun j (x : Fin N → K) => 1 - yeK n x j)
    (fun j _ => (constAt_const i (1 : K)).sub (constAt_yeK n i j (by omega)))

theorem affAt_cmK (n e : ℕ) (i : Fin N) (r : ℕ) : AffAt i (fun x : Fin N → K => cmK n e x r) := by
  show AffAt i (fun x : Fin N → K => yeK n x r * ∏ j ∈ Finset.range e, (if r < j then 1 - yeK n x j else 1))
  by_cases h : (i : ℕ) = n + r
  · refine (affAt_yeK n i r).mul_const (ConstAt.prodOn (Finset.range e)
      (fun j (x : Fin N → K) => if r < j then 1 - yeK n x j else 1) (fun j _ => ?_))
    by_cases hr : r < j
    · have e1 : (fun x : Fin N → K => if r < j then 1 - yeK n x j else 1) = fun x => 1 - yeK n x j := by
        funext x
        exact ite_eq_left hr
      rw [e1]
      exact (constAt_const i (1 : K)).sub (constAt_yeK n i j (by omega))
    · have e1 : (fun x : Fin N → K => if r < j then 1 - yeK n x j else 1) = fun _ => (1 : K) := by
        funext x
        exact ite_eq_right hr
      rw [e1]
      exact constAt_const i (1 : K)
  · refine AffAt.const_mul (constAt_yeK n i r h) (AffAt.prodOn_one (Finset.range e)
      (fun j (x : Fin N → K) => if r < j then 1 - yeK n x j else 1) ((i : ℕ) - n) ?_ (fun j _ hne => ?_))
    · exact AffAt.ite _ ((constAt_const i (1 : K)).affAt.sub (affAt_yeK n i _)) (constAt_const i (1 : K)).affAt
    · exact ConstAt.ite _ ((constAt_const i (1 : K)).sub (constAt_yeK n i j (fun h' => hne (by omega))))
        (constAt_const i (1 : K))

theorem constAt_cmK (n e : ℕ) (i : Fin N) (r : ℕ) (h : (i : ℕ) < n) :
    ConstAt i (fun x : Fin N → K => cmK n e x r) := by
  show ConstAt i (fun x : Fin N → K => yeK n x r * ∏ j ∈ Finset.range e, (if r < j then 1 - yeK n x j else 1))
  exact (constAt_yeK n i r (by omega)).mul (ConstAt.prodOn (Finset.range e)
    (fun j (x : Fin N → K) => if r < j then 1 - yeK n x j else 1)
    (fun j _ => ConstAt.ite _ ((constAt_const i (1 : K)).sub (constAt_yeK n i j (by omega)))
      (constAt_const i (1 : K))))

/-! ## Families of point coordinates -/

/-- A family of coordinates `g x q`, each affine in variable `i`, of which at most one reads it. -/
structure PtFam (i : Fin N) (g : (Fin N → K) → ℕ → K) : Prop where
  aff : ∀ q, AffAt i (fun x => g x q)
  uniq : ∀ q q', q ≠ q' → ConstAt i (fun x => g x q) ∨ ConstAt i (fun x => g x q')

theorem PtFam.shift {i : Fin N} {g : (Fin N → K) → ℕ → K} (h : PtFam i g) (s : ℕ) :
    PtFam i (fun x a => g x (s + a)) :=
  ⟨fun q => h.aff (s + q), fun q q' hne => h.uniq (s + q) (s + q') (by omega)⟩

theorem ptFam_xrK (n : ℕ) (i : Fin N) : PtFam i (fun (x : Fin N → K) q => xrK n x q) :=
  ⟨fun q => affAt_xrK n i q, fun q q' hne => by
    by_cases h : (i : ℕ) = q
    · exact Or.inr (constAt_xrK n i q' (Or.inr (by omega)))
    · exact Or.inl (constAt_xrK n i q (Or.inr h))⟩

theorem eqFactor_affAt {i : Fin N} {f : (Fin N → K) → K} (hf : AffAt i f) (b : K) :
    AffAt i (fun x => f x * b + (1 - f x) * (1 - b)) :=
  (hf.mul_const (constAt_const i b)).add
    (((constAt_const i (1 : K)).affAt.sub hf).mul_const (constAt_const i (1 - b)))

theorem eqFactor_constAt {i : Fin N} {f : (Fin N → K) → K} (hf : ConstAt i f) (b : K) :
    ConstAt i (fun x => f x * b + (1 - f x) * (1 - b)) :=
  (hf.mul (constAt_const i b)).add (((constAt_const i (1 : K)).sub hf).mul (constAt_const i (1 - b)))

theorem eqFactor_affAt' {i : Fin N} {f : (Fin N → K) → K} (hf : AffAt i f) (c : K) :
    AffAt i (fun x => c * f x + (1 - c) * (1 - f x)) :=
  (AffAt.const_mul (constAt_const i c) hf).add
    (AffAt.const_mul (constAt_const i (1 - c)) ((constAt_const i (1 : K)).affAt.sub hf))

theorem eqFactor_constAt' {i : Fin N} {f : (Fin N → K) → K} (hf : ConstAt i f) (c : K) :
    ConstAt i (fun x => c * f x + (1 - c) * (1 - f x)) :=
  ((constAt_const i c).mul hf).add ((constAt_const i (1 - c)).mul ((constAt_const i (1 : K)).sub hf))

/-- `eq(g x, b)` is affine in each variable. -/
theorem affAt_eqFam {i : Fin N} {g : (Fin N → K) → ℕ → K} (h : PtFam i g) (m : ℕ) (b : Fin m → K) :
    AffAt i (fun x => eqPoly (fun a : Fin m => g x a) b) := by
  show AffAt i (fun x => ∏ a : Fin m, (g x a * b a + (1 - g x a) * (1 - b a)))
  by_cases hex : ∃ a0 : Fin m, ¬ ConstAt i (fun x => g x a0)
  · obtain ⟨a0, ha0⟩ := hex
    refine AffAt.prod_one (fun (a : Fin m) x => g x a * b a + (1 - g x a) * (1 - b a)) a0
      (eqFactor_affAt (h.aff a0) (b a0)) (fun a hne => ?_)
    rcases h.uniq a a0 (fun e => hne (Fin.ext e)) with hc | hc
    · exact eqFactor_constAt hc (b a)
    · exact absurd hc ha0
  · have hall : ∀ a : Fin m, ConstAt i (fun x => g x a) := fun a => by
      by_contra hn
      exact hex ⟨a, hn⟩
    exact (ConstAt.prod (fun (a : Fin m) x => g x a * b a + (1 - g x a) * (1 - b a))
      (fun a => eqFactor_constAt (hall a) (b a))).affAt

theorem constAt_eqFam {i : Fin N} {g : (Fin N → K) → ℕ → K} (m : ℕ) (b : Fin m → K)
    (h : ∀ a : Fin m, ConstAt i (fun x => g x a)) : ConstAt i (fun x => eqPoly (fun a : Fin m => g x a) b) := by
  show ConstAt i (fun x => ∏ a : Fin m, (g x a * b a + (1 - g x a) * (1 - b a)))
  exact ConstAt.prod (fun (a : Fin m) x => g x a * b a + (1 - g x a) * (1 - b a))
    (fun a => eqFactor_constAt (h a) (b a))

/-- `eq(c, g x)` is affine in each variable. -/
theorem affAt_eqFam' {i : Fin N} {g : (Fin N → K) → ℕ → K} (h : PtFam i g) (m : ℕ) (c : Fin m → K) :
    AffAt i (fun x => eqPoly c (fun a : Fin m => g x a)) := by
  show AffAt i (fun x => ∏ a : Fin m, (c a * g x a + (1 - c a) * (1 - g x a)))
  by_cases hex : ∃ a0 : Fin m, ¬ ConstAt i (fun x => g x a0)
  · obtain ⟨a0, ha0⟩ := hex
    refine AffAt.prod_one (fun (a : Fin m) x => c a * g x a + (1 - c a) * (1 - g x a)) a0
      (eqFactor_affAt' (h.aff a0) (c a0)) (fun a hne => ?_)
    rcases h.uniq a a0 (fun e => hne (Fin.ext e)) with hc | hc
    · exact eqFactor_constAt' hc (c a)
    · exact absurd hc ha0
  · have hall : ∀ a : Fin m, ConstAt i (fun x => g x a) := fun a => by
      by_contra hn
      exact hex ⟨a, hn⟩
    exact (ConstAt.prod (fun (a : Fin m) x => c a * g x a + (1 - c a) * (1 - g x a))
      (fun a => eqFactor_constAt' (hall a) (c a))).affAt

theorem constAt_eqFam' {i : Fin N} {g : (Fin N → K) → ℕ → K} (m : ℕ) (c : Fin m → K)
    (h : ∀ a : Fin m, ConstAt i (fun x => g x a)) : ConstAt i (fun x => eqPoly c (fun a : Fin m => g x a)) := by
  show ConstAt i (fun x => ∏ a : Fin m, (c a * g x a + (1 - c a) * (1 - g x a)))
  exact ConstAt.prod (fun (a : Fin m) x => c a * g x a + (1 - c a) * (1 - g x a))
    (fun a => eqFactor_constAt' (h a) (c a))

/-- A part's row weight, read on a family. -/
theorem affAt_partRowFam {i : Fin N} {g : (Fin N → K) → ℕ → K} (h : PtFam i g) (logN off ls row : ℕ) :
    AffAt i (fun x => partRowK logN off ls (g x) row) := by
  unfold partRowK
  exact AffAt.ite _ (AffAt.ite _ (affAt_eqFam h _ _) (constAt_const i (0 : K)).affAt)
    (AffAt.ite _ (constAt_const i (1 : K)).affAt (constAt_const i (0 : K)).affAt)

theorem constAt_partRowFam {i : Fin N} {g : (Fin N → K) → ℕ → K} (logN off ls row : ℕ)
    (h : logN ≤ ls → ∀ a : Fin (ls - logN), ConstAt i (fun x => g x a)) :
    ConstAt i (fun x => partRowK logN off ls (g x) row) := by
  intro x t
  show partRowK logN off ls (g (Function.update x i t)) row = partRowK logN off ls (g x) row
  unfold partRowK
  by_cases hl : logN ≤ ls
  · rw [ite_eq_left hl, ite_eq_left hl]
    by_cases hc : off / 2 ^ logN ≤ row ∧ row < off / 2 ^ logN + 2 ^ (ls - logN)
    · rw [ite_eq_left hc, ite_eq_left hc]
      exact constAt_eqFam (ls - logN) _ (h hl) x t
    · rw [ite_eq_right hc, ite_eq_right hc]
  · rw [ite_eq_right hl, ite_eq_right hl]

/-- The key's column weight, read on a family. -/
theorem affAt_keyColFam {i : Fin N} {g : (Fin N → K) → ℕ → K} (h : PtFam i g) (logN off ls t : ℕ) :
    AffAt i (fun x => keyColK logN off ls (g x) t) := by
  unfold keyColK
  exact AffAt.ite _ (affAt_eqFam (h.shift (ls - logN)) _ _)
    (AffAt.ite _ (affAt_eqFam h _ _) (constAt_const i (0 : K)).affAt)

theorem constAt_keyColFam {i : Fin N} {g : (Fin N → K) → ℕ → K} (logN off ls t : ℕ)
    (h1 : logN ≤ ls → ∀ a : Fin logN, ConstAt i (fun x => g x (ls - logN + a)))
    (h2 : ¬ logN ≤ ls → ∀ a : Fin ls, ConstAt i (fun x => g x a)) :
    ConstAt i (fun x => keyColK logN off ls (g x) t) := by
  intro x u
  show keyColK logN off ls (g (Function.update x i u)) t = keyColK logN off ls (g x) t
  unfold keyColK
  by_cases hl : logN ≤ ls
  · rw [ite_eq_left hl, ite_eq_left hl]
    exact constAt_eqFam (g := fun x a => g x (ls - logN + a)) logN _ (h1 hl) x u
  · rw [ite_eq_right hl, ite_eq_right hl]
    by_cases hc : off % 2 ^ logN ≤ t ∧ t < off % 2 ^ logN + 2 ^ ls
    · rw [ite_eq_left hc, ite_eq_left hc]
      exact constAt_eqFam ls _ (h2 hl) x u
    · rw [ite_eq_right hc, ite_eq_right hc]

end Readers

/-! ## The words of an accepting slot, read as a point -/

section Words

variable {K : Type} [Field K] [Algebra GF K] (U : K) {N : ℕ}

/-- A list of words as a point. -/
def xOf (l : List Fp2) : Fin N → K := fun i => (l.getD i Fp2.zero).toK U

theorem getD_ge_zero (l : List Fp2) (q : ℕ) (h : l.length ≤ q) : l.getD q Fp2.zero = Fp2.zero := by
  rw [List.getD_eq_getElem?_getD, List.getElem?_eq_none_iff.mpr h, Option.getD_none]

theorem xg_xOf (l : List Fp2) (hl : l.length ≤ N) (q : ℕ) :
    xg (xOf U l : Fin N → K) q = (l.getD q Fp2.zero).toK U := by
  unfold xg
  by_cases h : q < N
  · rw [dite_eq_left h]
    rfl
  · rw [dite_eq_right h, getD_ge_zero l q (by omega), Fp2.toK_zero]

theorem xrK_xOf (n : ℕ) (rho es : List Fp2) (hrho : rho.length = n) (hN : (rho ++ es).length ≤ N) (k : ℕ) :
    xrK n (xOf U (rho ++ es) : Fin N → K) k = (rho.getD k Fp2.zero).toK U := by
  unfold xrK
  by_cases h : k < n
  · rw [ite_eq_left h, xg_xOf U _ hN, getD_append_lt _ _ _ _ (by rw [hrho]; exact h)]
  · rw [ite_eq_right h, getD_ge_zero rho k (by omega), Fp2.toK_zero]

theorem yeK_xOf (n : ℕ) (rho es : List Fp2) (hrho : rho.length = n) (hN : (rho ++ es).length ≤ N) (j : ℕ) :
    yeK n (xOf U (rho ++ es) : Fin N → K) j = (es.getD j Fp2.zero).toK U := by
  unfold yeK
  rw [xg_xOf U _ hN, getD_append_ge _ _ _ _ (by rw [hrho]; exact Nat.le_add_right n j), hrho,
    Nat.add_sub_cancel_left]

theorem prod_drop_range {α M : Type} [CommMonoid M] (f : α → M) (d : α) : ∀ (l : List α) (m : ℕ),
    ((l.drop m).map f).prod = ∏ i ∈ Finset.range l.length, (if m ≤ i then f (l.getD i d) else 1)
  | [], m => by simp
  | a :: l, 0 => by
    rw [List.drop_zero, list_prod_map_getD f d (a :: l)]
    exact Finset.prod_congr rfl (fun i _ => (ite_eq_left (Nat.zero_le i)).symm)
  | a :: l, m + 1 => by
    rw [List.drop_succ_cons, prod_drop_range f d l m, List.length_cons, Finset.prod_range_succ']
    have h0 : ¬ (m + 1 ≤ 0) := by omega
    rw [ite_eq_right h0, mul_one]
    refine Finset.prod_congr rfl (fun i _ => ?_)
    rw [List.getD_cons_succ]
    by_cases h : m ≤ i
    · have h' : m + 1 ≤ i + 1 := by omega
      exact (ite_eq_left h).trans (ite_eq_left h').symm
    · have h' : ¬ (m + 1 ≤ i + 1) := by omega
      exact (ite_eq_right h).trans (ite_eq_right h').symm

/-- **`sel` on the verifier's words.** -/
theorem toK_oneMinusProd (hU : U ^ 2 = algebraMap GF K 7) (n e : ℕ) (rho es : List Fp2) (hrho : rho.length = n)
    (hes : es.length = e) (hN : (rho ++ es).length ≤ N) (hec : ∀ a ∈ es, a.Canon) :
    (oneMinusProd es).toK U = selK n e (xOf U (rho ++ es) : Fin N → K) := by
  unfold oneMinusProd selK
  rw [toK_foldl_mul U hU (fun a => Fp2.one.sub a), Fp2.toK_one, one_mul, list_prod_map_getD _ Fp2.zero es, hes]
  refine Finset.prod_congr rfl (fun j _ => ?_)
  rw [Fp2.toK_sub U _ _ Fp2.canon_one (Fp2.canon_getD hec j), Fp2.toK_one, yeK_xOf U n rho es hrho hN]

/-- **The mask coefficient on the verifier's words.** -/
theorem toK_maskCoef (hU : U ^ 2 = algebraMap GF K 7) (n e : ℕ) (rho es : List Fp2) (hrho : rho.length = n)
    (hes : es.length = e) (hN : (rho ++ es).length ≤ N) (hec : ∀ a ∈ es, a.Canon) (r : ℕ) :
    (maskCoef es r).toK U = cmK n e (xOf U (rho ++ es) : Fin N → K) r := by
  unfold maskCoef cmK
  rw [toK_foldl_mul U hU (fun a => Fp2.one.sub a), prod_drop_range _ Fp2.zero es (r + 1), hes,
    yeK_xOf U n rho es hrho hN]
  refine congrArg (fun z => (es.getD r Fp2.zero).toK U * z) (Finset.prod_congr rfl (fun j _ => ?_))
  by_cases h : r < j
  · have h1 : r + 1 ≤ j := h
    refine (ite_eq_left h1).trans (Eq.trans ?_ (ite_eq_left h).symm)
    rw [Fp2.toK_sub U _ _ Fp2.canon_one (Fp2.canon_getD hec j), Fp2.toK_one, yeK_xOf U n rho es hrho hN]
  · have h1 : ¬ (r + 1 ≤ j) := h
    exact (ite_eq_right h1).trans (ite_eq_right h).symm

/-! ## A private table's claim point -/

/-- One coordinate of a claim point, on a reader `xr` of the main variables. -/
def coordK (xr : ℕ → K) : Coord → K
  | .rho k => xr k
  | .flip k => 1 - xr k
  | .fixed v => v.toK U

/-- Coordinate `q` of a claim point (zero past its end). -/
def ptK (xr : ℕ → K) (coords : List Coord) (q : ℕ) : K := ((coords[q]?).map (coordK U xr)).getD 0

theorem claimPoint_getD_toK (p : Priv) (rho : List Fp2) (hrc : ∀ a ∈ rho, a.Canon) (xr : ℕ → K)
    (hxr : ∀ k, xr k = (rho.getD k Fp2.zero).toK U) (q : ℕ) :
    ((claimPoint p rho).getD q Fp2.zero).toK U = ptK U xr p.coords q := by
  unfold claimPoint ptK
  rw [List.getD_eq_getElem?_getD, List.getElem?_map]
  cases p.coords[q]? with
  | none => exact Fp2.toK_zero U
  | some c =>
    cases c with
    | rho k => exact (hxr k).symm
    | flip k =>
      show (Fp2.one.sub (rho.getD k Fp2.zero)).toK U = 1 - xr k
      rw [Fp2.toK_sub U _ _ Fp2.canon_one (Fp2.canon_getD hrc k), Fp2.toK_one, hxr k]
    | fixed v => rfl

/-- The challenge a coordinate reads, if any. -/
def coordVar : Coord → Option ℕ
  | .rho k => some k
  | .flip k => some k
  | .fixed _ => none

/-- **Every challenge is read by at most one coordinate** (`priv_table`'s comment, argument.rs:250: "multilinear in x
because every challenge index occurs at most once among the coordinates"), as a check on the list of the coordinates'
challenges. -/
def varsOKb (vs : List (Option ℕ)) : Bool :=
  (List.range vs.length).all fun q => (List.range vs.length).all fun q' =>
    decide (q = q') || decide (vs.getD q none = none) || decide (vs.getD q none ≠ vs.getD q' none)

theorem varsOK_spec (vs : List (Option ℕ)) (h : varsOKb vs = true) (q q' v : ℕ) (hne : q ≠ q')
    (hq : vs.getD q none = some v) : vs.getD q' none ≠ some v := by
  intro hq'
  have hlt : ∀ a w, vs.getD a none = some w → a < vs.length := by
    intro a w ha
    by_contra hge
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_none_iff.mpr (by omega), Option.getD_none] at ha
    cases ha
  have h1 := List.all_eq_true.mp h q (List.mem_range.mpr (hlt q v hq))
  have h2 := List.all_eq_true.mp h1 q' (List.mem_range.mpr (hlt q' v hq'))
  simp only [Bool.or_eq_true, decide_eq_true_eq] at h2
  rcases h2 with (h3 | h3) | h3
  · exact hne h3
  · rw [hq] at h3
    cases h3
  · exact h3 (hq.trans hq'.symm)

theorem affAt_coordK (n : ℕ) (i : Fin N) (c : Coord) : AffAt i (fun x : Fin N → K => coordK U (xrK n x) c) := by
  cases c with
  | rho k => exact affAt_xrK n i k
  | flip k => exact (constAt_const i (1 : K)).affAt.sub (affAt_xrK n i k)
  | fixed v => exact (constAt_const i (v.toK U)).affAt

theorem constAt_coordK (n : ℕ) (i : Fin N) (c : Coord) (h : n ≤ (i : ℕ) ∨ coordVar c ≠ some (i : ℕ)) :
    ConstAt i (fun x : Fin N → K => coordK U (xrK n x) c) := by
  cases c with
  | rho k =>
    exact constAt_xrK n i k (h.imp id (fun h' he => h' (by rw [he]; rfl)))
  | flip k =>
    exact (constAt_const i (1 : K)).sub (constAt_xrK n i k (h.imp id (fun h' he => h' (by rw [he]; rfl))))
  | fixed v => exact constAt_const i (v.toK U)

theorem affAt_ptK (n : ℕ) (coords : List Coord) (i : Fin N) (q : ℕ) :
    AffAt i (fun x : Fin N → K => ptK U (xrK n x) coords q) := by
  unfold ptK
  cases coords[q]? with
  | none => exact (constAt_const i (0 : K)).affAt
  | some c => exact affAt_coordK U n i c

theorem constAt_ptK (n : ℕ) (coords : List Coord) (i : Fin N) (q : ℕ)
    (h : n ≤ (i : ℕ) ∨ (coords.map coordVar).getD q none ≠ some (i : ℕ)) :
    ConstAt i (fun x : Fin N → K => ptK U (xrK n x) coords q) := by
  have hv : (coords.map coordVar).getD q none = ((coords[q]?).map coordVar).getD none := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_map]
  rw [hv] at h
  unfold ptK
  cases hc : coords[q]? with
  | none => exact constAt_const i (0 : K)
  | some c =>
    rw [hc] at h
    exact constAt_coordK U n i c h

theorem ptFam_ptK (n : ℕ) (coords : List Coord) (hv : varsOKb (coords.map coordVar) = true) (i : Fin N) :
    PtFam i (fun (x : Fin N → K) q => ptK U (xrK n x) coords q) :=
  ⟨fun q => affAt_ptK U n coords i q, fun q q' hne => by
    by_cases h : (coords.map coordVar).getD q none = some (i : ℕ)
    · exact Or.inr (constAt_ptK U n coords i q' (Or.inr (varsOK_spec _ hv q q' i hne h)))
    · exact Or.inl (constAt_ptK U n coords i q (Or.inr h))⟩

/-! ## The tables' extensions -/

/-- **The committed matrices the claims are read on**, one per commitment: `rows cm` rows of `2^row_log + Q cm`
message coordinates. -/
structure CmData (K : Type) (P : BlockParams) where
  rows : Cm → ℕ
  Q : Cm → ℕ
  X : (cm : Cm) → Fin (rows cm) → Fin (2 ^ rowLog P cm + Q cm) → K

/-- One part of a private table's claim, as a function of the point: its slice, its coefficient, and where its point
starts in the table's claim point. -/
structure PartSpec (K : Type) (N : ℕ) where
  off : ℕ
  ls : ℕ
  coef : (Fin N → K) → K
  sh : ℕ

/-- A data part: `coef·sel` on the slice at `off`, at the whole claim point. -/
def dataSpec (n e ls : ℕ) (sc : ℕ × Fp2) : PartSpec K N := ⟨sc.1, ls, fun x => sc.2.toK U * selK n e x, 0⟩

/-- A mask part: `cm·u` on the reserved row, at the point's tail. -/
def maskSpec (n e off ls sh r : ℕ) (u : K) : PartSpec K N := ⟨off, ls, fun x => cmK n e x r * u, sh⟩

/-- `build_claim`'s column offset of the reserved pair. -/
def privC0 (P : BlockParams) (p : Priv) : ℕ :=
  if p.log < rowLog P p.cm then (p.slices.headD (0, Fp2.zero)).1 % 2 ^ rowLog P p.cm else 0

/-- **`build_claim`'s parts, as functions of the point**: the data slices, then the reserved pair `(1, u)`. -/
def privSpecs (P : BlockParams) (n e : ℕ) (p : Priv) : List (PartSpec K N) :=
  p.slices.map (dataSpec U n e p.log)
    ++ [maskSpec n e (p.maskRow * 2 ^ rowLog P p.cm + privC0 P p) (min p.log (rowLog P p.cm))
          (p.log - min p.log (rowLog P p.cm)) p.extRound (Fp2.one.toK U),
        maskSpec n e ((p.maskRow + 1) * 2 ^ rowLog P p.cm + privC0 P p) (min p.log (rowLog P p.cm))
          (p.log - min p.log (rowLog P p.cm)) p.extRound (fp2U.toK U)]

/-- A part at a point. -/
def specPart (ptf : ℕ → K) (x : Fin N → K) (sp : PartSpec K N) : PartK K :=
  ⟨sp.off, sp.ls, sp.coef x, fun a => ptf (sp.sh + a)⟩

/-- **A table's extension at the point `x`** (`n` main variables, `e` extension variables): `sel·eq(point, x[start..])`,
`sel·T̃(ρ)`, or the claim functional of a private table on its commitment's matrix. -/
def tabK (P : BlockParams) (D : CmData K P) (n e : ℕ) (x : Fin N → K) : Tab → K
  | .eq point start =>
    selK n e x * eqPoly (fun a : Fin point.length => (point.getD a Fp2.zero).toK U)
      (fun a : Fin point.length => xrK n x (start + a))
  | .pub v =>
    selK n e x * mleAt (fun b : Fin n → Bool => (v.getD (msbIndex n b) Fp2.zero).toK U) (fun a : Fin n => xrK n x a)
  | .priv p =>
    claimK (rowLog P p.cm) (D.rows p.cm) (D.Q p.cm) (D.X p.cm)
      ((privSpecs U P n e p).map (specPart (ptK U (xrK n x) p.coords) x))

/-- What the unfolding needs of a private table's SHAPE: at least one slice, a nonempty point of the slice's length,
a positive row log, and coordinates that read each challenge at most once. -/
def PrivOK (P : BlockParams) (p : Priv) : Prop :=
  p.slices ≠ [] ∧ 0 < p.log ∧ p.coords.length = p.log ∧ 0 < rowLog P p.cm
    ∧ varsOKb (p.coords.map coordVar) = true

def TabOK (P : BlockParams) : Tab → Prop
  | .priv p => PrivOK P p
  | _ => True

/-- The challenge words a table carries are canonical (an `eq` point, a private table's fixed coordinates). -/
def TabCanon : Tab → Prop
  | .eq point _ => ∀ a ∈ point, a.Canon
  | .pub _ => True
  | .priv p => ∀ c ∈ p.coords, ∀ v, c = Coord.fixed v → v.Canon

theorem buildClaim_parts (P : BlockParams) (p : Priv) (point : List Fp2) (cd cm v : Fp2) :
    (buildClaim P p point cd cm v).parts
      = p.slices.map (fun sc => (⟨sc.1, p.log, sc.2.mul cd, point⟩ : ZPart))
        ++ [⟨p.maskRow * 2 ^ rowLog P p.cm + privC0 P p, min p.log (rowLog P p.cm), cm.mul Fp2.one,
              point.drop (p.log - min p.log (rowLog P p.cm))⟩,
            ⟨(p.maskRow + 1) * 2 ^ rowLog P p.cm + privC0 P p, min p.log (rowLog P p.cm), cm.mul fp2U,
              point.drop (p.log - min p.log (rowLog P p.cm))⟩] := rfl

/-- **`build_claim`'s parts read in the field are the table's parts at the point.** -/
theorem buildClaim_partsK (hU : U ^ 2 = algebraMap GF K 7) (P : BlockParams) (n e : ℕ) (p : Priv)
    (point : List Fp2) (cd cm v : Fp2) (x : Fin N → K)
    (hpt : ∀ a, (point.getD a Fp2.zero).toK U = ptK U (xrK n x) p.coords a) (hcd : cd.toK U = selK n e x)
    (hcm : cm.toK U = cmK n e x p.extRound) :
    (buildClaim P p point cd cm v).parts.map (partK U)
      = (privSpecs U P n e p).map (specPart (ptK U (xrK n x) p.coords) x) := by
  have e2 : (fun a : ℕ => (point.getD a Fp2.zero).toK U) = fun a => ptK U (xrK n x) p.coords (0 + a) := by
    funext a
    rw [Nat.zero_add]
    exact hpt a
  have e4 : (fun a : ℕ => ((point.drop (p.log - min p.log (rowLog P p.cm))).getD a Fp2.zero).toK U)
      = fun a => ptK U (xrK n x) p.coords (p.log - min p.log (rowLog P p.cm) + a) := by
    funext a
    rw [getD_drop]
    exact hpt _
  rw [buildClaim_parts]
  unfold privSpecs
  rw [List.map_append, List.map_append, List.map_map, List.map_map]
  refine congrArg₂ (· ++ ·) (List.map_congr_left (fun sc _ => ?_)) ?_
  · show (⟨sc.1, p.log, (sc.2.mul cd).toK U, fun a => (point.getD a Fp2.zero).toK U⟩ : PartK K)
      = ⟨sc.1, p.log, sc.2.toK U * selK n e x, fun a => ptK U (xrK n x) p.coords (0 + a)⟩
    rw [Fp2.toK_mul U hU, hcd, e2]
  · show [(⟨p.maskRow * 2 ^ rowLog P p.cm + privC0 P p, min p.log (rowLog P p.cm), (cm.mul Fp2.one).toK U,
          fun a => ((point.drop (p.log - min p.log (rowLog P p.cm))).getD a Fp2.zero).toK U⟩ : PartK K),
        ⟨(p.maskRow + 1) * 2 ^ rowLog P p.cm + privC0 P p, min p.log (rowLog P p.cm), (cm.mul fp2U).toK U,
          fun a => ((point.drop (p.log - min p.log (rowLog P p.cm))).getD a Fp2.zero).toK U⟩]
      = [⟨p.maskRow * 2 ^ rowLog P p.cm + privC0 P p, min p.log (rowLog P p.cm),
          cmK n e x p.extRound * Fp2.one.toK U,
          fun a => ptK U (xrK n x) p.coords (p.log - min p.log (rowLog P p.cm) + a)⟩,
        ⟨(p.maskRow + 1) * 2 ^ rowLog P p.cm + privC0 P p, min p.log (rowLog P p.cm),
          cmK n e x p.extRound * fp2U.toK U,
          fun a => ptK U (xrK n x) p.coords (p.log - min p.log (rowLog P p.cm) + a)⟩]
    rw [Fp2.toK_mul U hU, Fp2.toK_mul U hU, hcm, e4]

/-! ## The verifier's terminal values are the tables' extensions -/

theorem tabVal_eq_ok {sel : Fp2} {rho terms point : List Fp2} {start k k' : ℕ} {v : Fp2}
    (h : tabVal sel rho terms (.eq point start) k = .ok (v, k')) :
    start + point.length ≤ rho.length
      ∧ v = sel.mul (eqPointBody point ((rho.drop start).take point.length)) ∧ k' = k := by
  simp only [tabVal] at h
  by_cases hle : start + point.length ≤ rho.length
  · rw [ite_eq_left hle] at h
    have hl : point.length = ((rho.drop start).take point.length).length := by
      rw [List.length_take, List.length_drop]
      omega
    unfold eqPoint at h
    rw [ite_eq_left hl] at h
    simp only [Except.ok.injEq, Prod.mk.injEq] at h
    exact ⟨hle, h.1.symm, h.2.symm⟩
  · rw [ite_eq_right hle] at h
    cases h

theorem tabVal_pub_ok {sel : Fp2} {rho terms pv : List Fp2} {k k' : ℕ} {v : Fp2}
    (h : tabVal sel rho terms (.pub pv) k = .ok (v, k')) :
    pv.length = 2 ^ rho.length ∧ v = sel.mul (mleSumExt pv (eqTableMsb rho)) ∧ k' = k := by
  simp only [tabVal] at h
  unfold evalMleExt at h
  by_cases hl : pv.length = 2 ^ rho.length
  · rw [ite_eq_left hl] at h
    simp only [Except.ok.injEq, Prod.mk.injEq] at h
    exact ⟨hl, h.1.symm, h.2.symm⟩
  · rw [ite_eq_right hl] at h
    simp at h

theorem tabVal_priv_ok {sel : Fp2} {rho terms : List Fp2} {p : Priv} {k k' : ℕ} {v : Fp2}
    (h : tabVal sel rho terms (.priv p) k = .ok (v, k')) : v = terms.getD k Fp2.zero ∧ k' = k + 1 := by
  simp only [tabVal, Except.ok.injEq, Prod.mk.injEq] at h
  exact ⟨h.1.symm, h.2.symm⟩

theorem tabVals_cons_ok {sel : Fp2} {rho terms : List Fp2} {t : Tab} {ts : List Tab} {k : ℕ} {vals : List Fp2}
    (h : tabVals sel rho terms (t :: ts) k = .ok vals) :
    ∃ v k' vs, tabVal sel rho terms t k = .ok (v, k') ∧ tabVals sel rho terms ts k' = .ok vs ∧ vals = v :: vs := by
  simp only [tabVals] at h
  cases h1 : tabVal sel rho terms t k with
  | error e =>
    rw [h1] at h
    simp at h
  | ok r =>
    obtain ⟨v, k'⟩ := r
    rw [h1] at h
    simp only at h
    cases h2 : tabVals sel rho terms ts k' with
    | error e =>
      rw [h2] at h
      simp at h
    | ok vs =>
      rw [h2] at h
      simp only [Except.ok.injEq] at h
      exact ⟨v, k', vs, rfl, h2, h.symm⟩

/-- **One terminal value is its table's extension at the slot's point**: for canonical challenges `ρ` (`n` of them)
and `e`, a table with canonical challenge words, and, for a private table, a claim that is TRUE of the commitment's
matrix (`cs`, read by `claimSem` on `D`). -/
theorem tabVal_toK (hU : U ^ 2 = algebraMap GF K 7) (P : BlockParams) (D : CmData K P) (cs : Cm → ZClaim → K)
    (hcs : ∀ cm z, cs cm z = Link.claimSem U (D.rows cm) (rowLog P cm) (D.Q cm) (D.X cm) z) (n e : ℕ)
    (rho es terms : List Fp2) (hrho : rho.length = n) (hes : es.length = e) (hN : (rho ++ es).length ≤ N)
    (hrc : ∀ a ∈ rho, a.Canon) (hec : ∀ a ∈ es, a.Canon) (tab : Tab) (hok : TabOK P tab) (hcan : TabCanon tab)
    (k k' : ℕ) (v : Fp2) (hv : tabVal (oneMinusProd es) rho terms tab k = .ok (v, k'))
    (hcl : ∀ p, tab = .priv p → cs p.cm (buildClaim P p (claimPoint p rho) (oneMinusProd es)
      (maskCoef es p.extRound) (terms.getD k Fp2.zero)) = (terms.getD k Fp2.zero).toK U) :
    v.toK U = tabK U P D n e (xOf U (rho ++ es) : Fin N → K) tab := by
  have hsel := toK_oneMinusProd U hU n e rho es hrho hes hN hec
  cases tab with
  | eq point start =>
    obtain ⟨hle, rfl, -⟩ := tabVal_eq_ok hv
    have hl : point.length = ((rho.drop start).take point.length).length := by
      rw [List.length_take, List.length_drop]
      omega
    have hsc : ∀ a ∈ (rho.drop start).take point.length, a.Canon :=
      fun a ha => hrc a (List.mem_of_mem_drop (List.mem_of_mem_take ha))
    have e2 : vecK U point.length ((rho.drop start).take point.length)
        = fun a : Fin point.length => xrK n (xOf U (rho ++ es) : Fin N → K) (start + a) := by
      funext a
      show (((rho.drop start).take point.length).getD a Fp2.zero).toK U = _
      rw [getD_take_lt _ _ _ a.isLt, getD_drop, xrK_xOf U n rho es hrho hN]
    rw [Fp2.toK_mul U hU, hsel, toK_eqPointBody U hU point _ hcan hsc hl, e2]
    rfl
  | pub pv =>
    obtain ⟨hlen, rfl, -⟩ := tabVal_pub_ok hv
    subst hrho
    have e2 : vecK U rho.length rho = fun a : Fin rho.length => xrK rho.length (xOf U (rho ++ es) : Fin N → K) a := by
      funext a
      show (rho.getD a Fp2.zero).toK U = _
      rw [xrK_xOf U rho.length rho es rfl hN]
    rw [Fp2.toK_mul U hU, hsel, toK_mleSumExt U hU pv rho hrc hlen, e2]
    rfl
  | priv p =>
    obtain ⟨rfl, -⟩ := tabVal_priv_ok hv
    obtain ⟨hsl, hlog, hlen, hLN, -⟩ := hok
    obtain ⟨sc0, rest, hs⟩ := List.exists_cons_of_ne_nil hsl
    have hpl : (claimPoint p rho).length = p.log := by
      unfold claimPoint
      rw [List.length_map, hlen]
    have hpc : ∀ a ∈ claimPoint p rho, a.Canon := by
      intro a ha
      unfold claimPoint at ha
      obtain ⟨c, hc, rfl⟩ := List.mem_map.mp ha
      cases c with
      | rho j => exact Fp2.canon_getD hrc j
      | flip j => exact Fp2.canon_sub _ _ Fp2.canon_one (Fp2.canon_getD hrc j)
      | fixed w => exact hcan _ hc w rfl
    have hparts := buildClaim_parts P p (claimPoint p rho) (oneMinusProd es) (maskCoef es p.extRound)
      (terms.getD k Fp2.zero)
    have hz : (buildClaim P p (claimPoint p rho) (oneMinusProd es) (maskCoef es p.extRound)
        (terms.getD k Fp2.zero)).parts
          = (⟨sc0.1, p.log, sc0.2.mul (oneMinusProd es), claimPoint p rho⟩ : ZPart)
            :: (rest.map (fun sc => (⟨sc.1, p.log, sc.2.mul (oneMinusProd es), claimPoint p rho⟩ : ZPart))
              ++ [⟨p.maskRow * 2 ^ rowLog P p.cm + privC0 P p, min p.log (rowLog P p.cm),
                    (maskCoef es p.extRound).mul Fp2.one,
                    (claimPoint p rho).drop (p.log - min p.log (rowLog P p.cm))⟩,
                  ⟨(p.maskRow + 1) * 2 ^ rowLog P p.cm + privC0 P p, min p.log (rowLog P p.cm),
                    (maskCoef es p.extRound).mul fp2U,
                    (claimPoint p rho).drop (p.log - min p.log (rowLog P p.cm))⟩]) := by
      rw [hparts, hs]
      rfl
    have hokp : ∀ b ∈ (buildClaim P p (claimPoint p rho) (oneMinusProd es) (maskCoef es p.extRound)
        (terms.getD k Fp2.zero)).parts, PartOK b := by
      intro b hb
      rw [hparts] at hb
      have hdrop : ((claimPoint p rho).drop (p.log - min p.log (rowLog P p.cm))).length
          = min p.log (rowLog P p.cm) := by
        rw [List.length_drop, hpl]
        omega
      have hdc : ∀ a ∈ (claimPoint p rho).drop (p.log - min p.log (rowLog P p.cm)), a.Canon :=
        fun a ha => hpc a (List.mem_of_mem_drop ha)
      rcases List.mem_append.mp hb with hb | hb
      · obtain ⟨sc, -, rfl⟩ := List.mem_map.mp hb
        exact ⟨hlog, hpl, hpc, Fp2.canon_mul _ _⟩
      · simp only [List.mem_cons, List.not_mem_nil, or_false] at hb
        rcases hb with rfl | rfl
        · exact ⟨lt_min hlog hLN, hdrop, hdc, Fp2.canon_mul _ _⟩
        · exact ⟨lt_min hlog hLN, hdrop, hdc, Fp2.canon_mul _ _⟩
    have hxr : ∀ j, xrK n (xOf U (rho ++ es) : Fin N → K) j = (rho.getD j Fp2.zero).toK U :=
      fun j => xrK_xOf U n rho es hrho hN j
    rw [← hcl p rfl, hcs, claimSem_parts U hU _ _ _ _ hLN _ _ _ hz hokp,
      buildClaim_partsK U hU P n e p (claimPoint p rho) (oneMinusProd es) (maskCoef es p.extRound)
        (terms.getD k Fp2.zero) (xOf U (rho ++ es) : Fin N → K)
        (fun a => claimPoint_getD_toK U p rho hrc _ hxr a) hsel
        (toK_maskCoef U hU n e rho es hrho hes hN hec p.extRound)]
    rfl

/-- **The terminal values of an accepting slot are the tables' extensions at its point.** -/
theorem tabVals_toK (hU : U ^ 2 = algebraMap GF K 7) (P : BlockParams) (D : CmData K P) (cs : Cm → ZClaim → K)
    (hcs : ∀ cm z, cs cm z = Link.claimSem U (D.rows cm) (rowLog P cm) (D.Q cm) (D.X cm) z) (n e : ℕ)
    (rho es terms : List Fp2) (hrho : rho.length = n) (hes : es.length = e) (hN : (rho ++ es).length ≤ N)
    (hrc : ∀ a ∈ rho, a.Canon) (hec : ∀ a ∈ es, a.Canon) :
    ∀ (tabs : List Tab) (k : ℕ) (vals : List Fp2), (∀ t ∈ tabs, TabOK P t) → (∀ t ∈ tabs, TabCanon t) →
      tabVals (oneMinusProd es) rho terms tabs k = .ok vals →
      (∀ q ∈ slotClaimList P rho es terms tabs k, cs q.1 q.2 = q.2.value.toK U) →
      vals.map (Fp2.toK U) = tabs.map (tabK U P D n e (xOf U (rho ++ es) : Fin N → K))
  | [], _, vals, _, _, hv, _ => by
    simp only [tabVals, Except.ok.injEq] at hv
    rw [← hv]
    rfl
  | t :: ts, k, vals, hok, hcan, hv, hcl => by
    obtain ⟨v, k', vs, h1, h2, rfl⟩ := tabVals_cons_ok hv
    have hok' : ∀ t' ∈ ts, TabOK P t' := fun t' ht => hok t' (List.mem_cons_of_mem t ht)
    have hcan' : ∀ t' ∈ ts, TabCanon t' := fun t' ht => hcan t' (List.mem_cons_of_mem t ht)
    have hhead : v.toK U = tabK U P D n e (xOf U (rho ++ es) : Fin N → K) t := by
      refine tabVal_toK U hU P D cs hcs n e rho es terms hrho hes hN hrc hec t (hok t List.mem_cons_self)
        (hcan t List.mem_cons_self) k k' v h1 (fun p hp => ?_)
      subst hp
      exact hcl (p.cm, buildClaim P p (claimPoint p rho) (oneMinusProd es) (maskCoef es p.extRound)
        (terms.getD k Fp2.zero)) List.mem_cons_self
    have htail : ∀ q ∈ slotClaimList P rho es terms ts k', cs q.1 q.2 = q.2.value.toK U := by
      intro q hq
      cases t with
      | eq point start =>
        obtain ⟨-, -, rfl⟩ := tabVal_eq_ok h1
        exact hcl q hq
      | pub pv =>
        obtain ⟨-, -, rfl⟩ := tabVal_pub_ok h1
        exact hcl q hq
      | priv p =>
        obtain ⟨-, rfl⟩ := tabVal_priv_ok h1
        exact hcl q (List.mem_cons_of_mem _ hq)
    rw [List.map_cons, List.map_cons, hhead,
      tabVals_toK hU P D cs hcs n e rho es terms hrho hes hN hrc hec ts k' vs hok' hcan' h2 htail]

/-! ## Every table's extension is affine in each variable -/

omit [Algebra GF K] in
theorem claimK_specs (L R Q : ℕ) (X : Fin R → Fin (2 ^ L + Q) → K) (ptf : ℕ → K) (x : Fin N → K)
    (sp0 : PartSpec K N) (sps : List (PartSpec K N)) :
    claimK L R Q X ((sp0 :: sps).map (specPart ptf x))
      = ∑ row : Fin R,
        ((sp0 :: sps).map fun sp => sp.coef x * partRowK L sp.off sp.ls (fun a => ptf (sp.sh + a)) row).sum
        * ∑ t : Fin (2 ^ L + Q), X row t
          * (if (t : ℕ) < 2 ^ L then keyColK L sp0.off sp0.ls (fun a => ptf (sp0.sh + a)) t else 0) := by
  show (∑ row : Fin R,
      ((specPart ptf x sp0 :: sps.map (specPart ptf x)).map
        fun b => b.coef * partRowK L b.off b.ls b.pt row).sum
      * ∑ t : Fin (2 ^ L + Q), X row t
        * (if (t : ℕ) < 2 ^ L then keyColK L (specPart ptf x sp0).off (specPart ptf x sp0).ls
            (specPart ptf x sp0).pt t else 0)) = _
  refine Finset.sum_congr rfl (fun row _ => ?_)
  rw [List.map_cons, List.map_cons, List.map_map]
  rfl

theorem mem_privSpecs (P : BlockParams) (n e : ℕ) (p : Priv) (sp : PartSpec K N)
    (h : sp ∈ privSpecs U P n e p) :
    (∃ sc : ℕ × Fp2, sp = dataSpec U n e p.log sc)
      ∨ (∃ (off : ℕ) (u : K), sp = maskSpec n e off (min p.log (rowLog P p.cm))
          (p.log - min p.log (rowLog P p.cm)) p.extRound u) := by
  unfold privSpecs at h
  rcases List.mem_append.mp h with h | h
  · obtain ⟨sc, -, rfl⟩ := List.mem_map.mp h
    exact Or.inl ⟨sc, rfl⟩
  · simp only [List.mem_cons, List.not_mem_nil, or_false] at h
    rcases h with rfl | rfl
    · exact Or.inr ⟨_, _, rfl⟩
    · exact Or.inr ⟨_, _, rfl⟩

theorem affAt_eqTab (n e : ℕ) (point : List Fp2) (start : ℕ) (i : Fin N) :
    AffAt i (fun x : Fin N → K => selK n e x
      * eqPoly (fun a : Fin point.length => (point.getD a Fp2.zero).toK U)
        (fun a : Fin point.length => xrK n x (start + a))) := by
  by_cases hi : n ≤ (i : ℕ)
  · exact (affAt_selK n e i).mul_const (constAt_eqFam' (g := fun x a => xrK n x (start + a)) point.length _
      (fun a => constAt_xrK n i (start + a) (Or.inl hi)))
  · exact AffAt.const_mul (constAt_selK n e i (by omega))
      (affAt_eqFam' ((ptFam_xrK n i).shift start) point.length _)

omit [Algebra GF K] in
theorem affAt_pubTab (n e : ℕ) (T : (Fin n → Bool) → K) (i : Fin N) :
    AffAt i (fun x : Fin N → K => selK n e x * mleAt T (fun a : Fin n => xrK n x a)) := by
  by_cases hi : n ≤ (i : ℕ)
  · refine (affAt_selK n e i).mul_const ?_
    show ConstAt i (fun x : Fin N → K =>
      ∑ b : Fin n → Bool, eqPoly (fun a : Fin n => xrK n x a) (fun j => bit (b j)) * T b)
    exact ConstAt.sum _ (fun b => (constAt_eqFam (g := fun x a => xrK n x a) n _
      (fun a => constAt_xrK n i a (Or.inl hi))).mul (constAt_const i (T b)))
  · refine AffAt.const_mul (constAt_selK n e i (by omega)) ?_
    show AffAt i (fun x : Fin N → K =>
      ∑ b : Fin n → Bool, eqPoly (fun a : Fin n => xrK n x a) (fun j => bit (b j)) * T b)
    exact AffAt.sum _ (fun b => (affAt_eqFam (ptFam_xrK n i) n _).mul_const (constAt_const i (T b)))

/-- **A private table's extension is affine in each variable**: in an extension variable through `cd` and `cm`
alone; in a main variable through the one coordinate of the claim point that reads it, which sits either in the row
half of the point or in its column half. -/
theorem affAt_privTab (P : BlockParams) (D : CmData K P) (n e : ℕ) (p : Priv) (hok : PrivOK P p) (i : Fin N) :
    AffAt i (fun x : Fin N → K => tabK U P D n e x (.priv p)) := by
  obtain ⟨hsl, -, -, -, hvars⟩ := hok
  obtain ⟨sc0, rest, hs⟩ := List.exists_cons_of_ne_nil hsl
  have hfam := ptFam_ptK (N := N) U n p.coords hvars i
  obtain ⟨sps, hspecs⟩ : ∃ sps : List (PartSpec K N),
      privSpecs U P n e p = dataSpec U n e p.log sc0 :: sps := by
    unfold privSpecs
    rw [hs]
    exact ⟨_, rfl⟩
  have hmem : ∀ sp ∈ dataSpec (N := N) U n e p.log sc0 :: sps,
      (∃ sc : ℕ × Fp2, sp = dataSpec U n e p.log sc)
        ∨ (∃ (off : ℕ) (u : K), sp = maskSpec n e off (min p.log (rowLog P p.cm))
            (p.log - min p.log (rowLog P p.cm)) p.extRound u) :=
    fun sp hsp => mem_privSpecs U P n e p sp (by rw [hspecs]; exact hsp)
  have hcoefA : ∀ sp ∈ dataSpec (N := N) U n e p.log sc0 :: sps, AffAt i sp.coef := by
    intro sp hsp
    rcases hmem sp hsp with ⟨sc, rfl⟩ | ⟨off, u, rfl⟩
    · exact AffAt.const_mul (constAt_const i (sc.2.toK U)) (affAt_selK n e i)
    · exact (affAt_cmK n e i p.extRound).mul_const (constAt_const i u)
  have hcoefC : ∀ sp ∈ dataSpec (N := N) U n e p.log sc0 :: sps, (i : ℕ) < n → ConstAt i sp.coef := by
    intro sp hsp hi
    rcases hmem sp hsp with ⟨sc, rfl⟩ | ⟨off, u, rfl⟩
    · exact (constAt_const i (sc.2.toK U)).mul (constAt_selK n e i hi)
    · exact (constAt_cmK n e i p.extRound hi).mul (constAt_const i u)
  have e1 : (fun x : Fin N → K => tabK U P D n e x (.priv p))
      = fun x => ∑ row : Fin (D.rows p.cm),
        ((dataSpec U n e p.log sc0 :: sps).map fun sp => sp.coef x
          * partRowK (rowLog P p.cm) sp.off sp.ls (fun a => ptK U (xrK n x) p.coords (sp.sh + a)) row).sum
        * ∑ t : Fin (2 ^ rowLog P p.cm + D.Q p.cm), D.X p.cm row t
          * (if (t : ℕ) < 2 ^ rowLog P p.cm then
              keyColK (rowLog P p.cm) sc0.1 p.log (fun a => ptK U (xrK n x) p.coords (0 + a)) t
            else 0) := by
    funext x
    show claimK _ _ _ _ ((privSpecs U P n e p).map (specPart (ptK U (xrK n x) p.coords) x)) = _
    rw [hspecs]
    exact claimK_specs _ _ _ _ _ x _ sps
  rw [e1]
  refine AffAt.sum _ (fun row => ?_)
  refine AffAt.mul_or
    (f := fun x : Fin N → K => ((dataSpec U n e p.log sc0 :: sps).map fun sp => sp.coef x
      * partRowK (rowLog P p.cm) sp.off sp.ls (fun a => ptK U (xrK n x) p.coords (sp.sh + a)) row).sum)
    (g := fun x : Fin N → K => ∑ t : Fin (2 ^ rowLog P p.cm + D.Q p.cm), D.X p.cm row t
      * (if (t : ℕ) < 2 ^ rowLog P p.cm then
          keyColK (rowLog P p.cm) sc0.1 p.log (fun a => ptK U (xrK n x) p.coords (0 + a)) t
        else 0)) ?_ ?_ ?_
  · -- the row weights are affine
    refine AffAt.listSum (fun (sp : PartSpec K N) (x : Fin N → K) => sp.coef x
      * partRowK (rowLog P p.cm) sp.off sp.ls (fun a => ptK U (xrK n x) p.coords (sp.sh + a)) row) _
      (fun sp hsp => ?_)
    by_cases hi : n ≤ (i : ℕ)
    · exact (hcoefA sp hsp).mul_const (constAt_partRowFam
        (g := fun x a => ptK U (xrK n x) p.coords (sp.sh + a)) (rowLog P p.cm) sp.off sp.ls row
        (fun _ a => constAt_ptK U n p.coords i (sp.sh + a) (Or.inl hi)))
    · exact AffAt.const_mul (hcoefC sp hsp (by omega))
        (affAt_partRowFam (hfam.shift sp.sh) (rowLog P p.cm) sp.off sp.ls row)
  · -- the column weights are affine
    exact AffAt.sum _ (fun t => AffAt.const_mul (constAt_const i (D.X p.cm row t))
      (AffAt.ite _ (affAt_keyColFam (hfam.shift 0) (rowLog P p.cm) sc0.1 p.log t)
        (constAt_const i (0 : K)).affAt))
  · -- one of the two does not read the variable
    by_cases hi : n ≤ (i : ℕ)
    · exact Or.inr (ConstAt.sum _ (fun t => (constAt_const i (D.X p.cm row t)).mul
        (ConstAt.ite _ (constAt_keyColFam (g := fun x a => ptK U (xrK n x) p.coords (0 + a))
          (rowLog P p.cm) sc0.1 p.log t
          (fun _ a => constAt_ptK U n p.coords i _ (Or.inl hi))
          (fun _ a => constAt_ptK U n p.coords i _ (Or.inl hi))) (constAt_const i (0 : K)))))
    · have hi' : (i : ℕ) < n := by omega
      by_cases hq : rowLog P p.cm ≤ p.log
          ∧ ∃ q, q < p.log - rowLog P p.cm ∧ (p.coords.map coordVar).getD q none = some (i : ℕ)
      · obtain ⟨hL, q, hq1, hq2⟩ := hq
        exact Or.inr (ConstAt.sum _ (fun t => (constAt_const i (D.X p.cm row t)).mul
          (ConstAt.ite _ (constAt_keyColFam (g := fun x a => ptK U (xrK n x) p.coords (0 + a))
            (rowLog P p.cm) sc0.1 p.log t
            (fun _ a => constAt_ptK U n p.coords i _
              (Or.inr (varsOK_spec _ hvars q _ i (by omega) hq2)))
            (fun hn _ => absurd hL hn)) (constAt_const i (0 : K)))))
      · refine Or.inl (ConstAt.listSum (fun (sp : PartSpec K N) (x : Fin N → K) => sp.coef x
          * partRowK (rowLog P p.cm) sp.off sp.ls (fun a => ptK U (xrK n x) p.coords (sp.sh + a)) row) _
          (fun sp hsp => (hcoefC sp hsp hi').mul (constAt_partRowFam
            (g := fun x a => ptK U (xrK n x) p.coords (sp.sh + a)) (rowLog P p.cm) sp.off sp.ls row ?_)))
        rcases hmem sp hsp with ⟨sc, rfl⟩ | ⟨off, u, rfl⟩
        · intro hL a
          have ha : (a : ℕ) < p.log - rowLog P p.cm := a.isLt
          exact constAt_ptK U n p.coords i _
            (Or.inr (fun hv => hq ⟨hL, 0 + (a : ℕ), by omega, hv⟩))
        · intro _ a
          have ha : (a : ℕ) < min p.log (rowLog P p.cm) - rowLog P p.cm := a.isLt
          exact absurd ha (by omega)

/-- **Every table's extension is affine in each variable.** -/
theorem affAt_tabK (P : BlockParams) (D : CmData K P) (n e : ℕ) (tab : Tab) (hok : TabOK P tab) (i : Fin N) :
    AffAt i (fun x : Fin N → K => tabK U P D n e x tab) := by
  cases tab with
  | eq point start => exact affAt_eqTab U n e point start i
  | pub v => exact affAt_pubTab n e _ i
  | priv p => exact affAt_privTab U P D n e p hok i

/-- **Every table's extension has individual degree `≤ 1`.** -/
theorem tabK_indDeg (P : BlockParams) (D : CmData K P) (n e : ℕ) (tab : Tab) (hok : TabOK P tab) :
    IndDegLE 1 (fun x : Fin N → K => tabK U P D n e x tab) :=
  indDegLE_one_of_affAt (fun i => affAt_tabK U P D n e tab hok i)

end Words

end ZK60.Exec.Block
