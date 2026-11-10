/-
D63 lane L31 (2026-11-09), part 5: **the mask half of the slot polynomials over the extracted data** (L23 §5 item 2,
the `c·mask` part; L23's `MLin`).

A slot's masked polynomial is `Poly + c·mask`: `Poly` the slot polynomial over the extracted tables, `mask` the CFS
mask polynomial whose coefficients are the slot's row of the mask table `M`. This file does the `mask` part, for the
reading definition `msOfTab` (what `msX` is, `BlockInstProf.lean`'s `msXof`) and ANY block shape.

* `list_range_sum`; `mRowX`: the extracted mask rows (the decoded mask polynomials' values at the 512 points), by slot
  and position;
* `mrow_term`, **`msOfTab_mlin`**, **`msXof_mlin`**: `M`'s semantics reads a functional linearly on those rows (L23's
  `MLin`, the premise `hlin` of `unmask_slots`);
* `mdot_eq_dot`, `exists_words`, `maskA`, `coeffsK_words`: a term's dot with a row is the code's `dot` with any word
  list reading the row, and such canonical words exist;
* `maskPoly`, `maskPoly_succ`, `indDeg_prod`, **`maskPoly_indDeg`**: the CFS mask polynomial of slot `k`'s extracted row
  on `N` variables, `a_0 + a'·∏ x_j + Σ_j Σ_e a_{j,e}·x_j^(e+1)`, of individual degree `≤ d`;
* **`maskPoly_point`**: the row's dot with `eval_weights(ρ, d)` is the mask polynomial at `ρ` (L5's `toK_evalDot` on
  the extracted row): the value of the slot's `M` functional;
* **`maskPoly_cubeSum`**: the row's dot with `sum_weights(N, d)` is the mask polynomial's cube sum (`toK_total`,
  `cubeSum_cfsEval`): what the `Γ` functionals weigh.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockInstProf
import ZK60Formal.HonestClassifySum

set_option autoImplicit false

namespace ZK60.Exec.Link

open ZK60.Sound
open ZK60.Exec
open ZK60.Circuit (gP GF)
open Polynomial

/-- A list sum over `0, …, n − 1` is the range sum. -/
theorem list_range_sum {M : Type} [AddCommMonoid M] (n : ℕ) (f : ℕ → M) :
    ((List.range n).map f).sum = ∑ i ∈ Finset.range n, f i := by
  rw [list_sum_map_getD f 0 (List.range n), List.length_range]
  exact Finset.sum_congr rfl (fun i hi => by rw [range_getD i n (Finset.mem_range.mp hi)])

section Rows

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **The extracted mask rows**: slot `s`'s decoded mask polynomial at the `j`-th of the 512 points (`0` outside the
`S` slots and the 512 positions). What `msOfTab` reads. -/
noncomputable def mRowX (S : ℕ) (cols : Fin (2 ^ 12) → List Fp) (s j : ℕ) : K :=
  if h : s < S ∧ j < 512 then
    (mDecA (mDataOf U S 0 [] cols).La (mRhOf U S cols) ⟨s, h.1⟩).eval
      (mPts (m := 512) (mOmega (K := K)) ⟨j, h.2⟩)
  else 0

/-- One term of a functional, summed against the rows, is its `mdot`. -/
theorem mrow_term (S : ℕ) (cols : Fin (2 ^ 12) → List Fp) (t : ℕ × List Fp2) :
    ∑ s : Fin S, ∑ j : Fin 512, (if t.1 = (s : ℕ) then (t.2.getD (j : ℕ) Fp2.zero).toK U else 0)
        * (mDecA (mDataOf U S 0 [] cols).La (mRhOf U S cols) s).eval (mPts (mOmega (K := K)) j)
      = Block.mdot U (mRowX U S cols) 512 t := by
  unfold Block.mdot
  rw [list_range_sum, Finset.sum_range]
  by_cases h : t.1 < S
  · rw [Finset.sum_eq_single (⟨t.1, h⟩ : Fin S)]
    · refine Finset.sum_congr rfl (fun j _ => ?_)
      have e1 : mRowX U S cols t.1 (j : ℕ)
          = (mDecA (mDataOf U S 0 [] cols).La (mRhOf U S cols) ⟨t.1, h⟩).eval (mPts (mOmega (K := K)) j) := by
        unfold mRowX
        exact dite_eq_left ⟨h, j.isLt⟩
      rw [e1, ite_eq_left rfl]
    · intro s _ hs
      refine Finset.sum_eq_zero (fun j _ => ?_)
      rw [ite_eq_right (fun e => hs (Fin.ext e.symm)), zero_mul]
    · intro hn
      exact absurd (Finset.mem_univ _) hn
  · have hl : ∀ s : Fin S, ∑ j : Fin 512, (if t.1 = (s : ℕ) then (t.2.getD (j : ℕ) Fp2.zero).toK U else 0)
        * (mDecA (mDataOf U S 0 [] cols).La (mRhOf U S cols) s).eval (mPts (mOmega (K := K)) j) = 0 := by
      intro s
      refine Finset.sum_eq_zero (fun j _ => ?_)
      rw [ite_eq_right (fun e => h (by rw [e]; exact s.isLt)), zero_mul]
    rw [Finset.sum_eq_zero (fun s _ => hl s)]
    refine (Finset.sum_eq_zero (fun j _ => ?_)).symm
    have e0 : mRowX U S cols t.1 (j : ℕ) = 0 := by
      unfold mRowX
      exact dite_eq_right (fun hh => h hh.1)
    rw [e0, mul_zero]

/-- **`M`'s semantics reads a functional linearly on the extracted mask rows** (L23's `MLin`): the value of a
functional is the sum of its terms' dots with their slots' rows. -/
theorem msOfTab_mlin (S : ℕ) (cols : Fin (2 ^ 12) → List Fp) :
    Block.MLin U (msOfTab U S cols) (mRowX U S cols) 512 := by
  intro ts
  induction ts with
  | nil =>
    unfold msOfTab
    simp [fwt]
  | cons t ts ih =>
    rw [List.map_cons, List.sum_cons, ← ih, ← mrow_term U S cols t]
    unfold msOfTab
    rw [← Finset.sum_add_distrib]
    refine Finset.sum_congr rfl (fun s _ => ?_)
    rw [← Finset.sum_add_distrib]
    refine Finset.sum_congr rfl (fun j _ => ?_)
    rw [← add_mul]
    rfl

/-- **`msXof` is linear on the rows of the mask table it extracts** (`hlin` of `unmask_slots`, at every statement). -/
theorem msXof_mlin (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (S : ℕ) (cu : Block.Cuts3 L) (rt : Block.RootsO) :
    Block.MLin U (msXof U tag L h64 S cu rt) (mRowX U S (colsC tag L h64 cu.2.1 rt.2.1)) 512 :=
  msOfTab_mlin U S _

end Rows

section Mask

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **A term's dot with a row is the code's `dot`** with any word list that reads the row (the weights past the
list's length are zero words). -/
theorem mdot_eq_dot (hU : U ^ 2 = algebraMap GF K 7) (R : ℕ → ℕ → K) (Wd k : ℕ) (w c : List Fp2)
    (hlen : w.length = c.length) (hW : c.length ≤ Wd)
    (hc : ∀ i, i < c.length → (c.getD i Fp2.zero).toK U = R k i) :
    Block.mdot U R Wd (k, w) = (Cfs.dot w c).toK U := by
  rw [toK_dot U hU w c hlen]
  unfold Block.mdot
  rw [list_range_sum]
  have h1 : ∑ i ∈ Finset.range c.length, (w.getD i Fp2.zero).toK U * (c.getD i Fp2.zero).toK U
      = ∑ i ∈ Finset.range c.length, (w.getD i Fp2.zero).toK U * R k i :=
    Finset.sum_congr rfl (fun i hi => by rw [hc i (Finset.mem_range.mp hi)])
  rw [h1]
  exact (Finset.sum_subset (fun x hx => Finset.mem_range.mpr (lt_of_lt_of_le (Finset.mem_range.mp hx) hW))
    (fun i _ hi => by
    have hi' : c.length ≤ i := by simpa using hi
    show (w.getD i Fp2.zero).toK U * R k i = 0
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_none_iff.mpr (by omega), Option.getD_none, Fp2.toK_zero,
      zero_mul])).symm

/-- Canonical words reading the first `m` entries of a row exist (`toK U` is onto `K`). -/
theorem exists_words (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (R : ℕ → ℕ → K) (k m : ℕ) :
    ∃ c : List Fp2, c.length = m ∧ ∀ i, i < m → (c.getD i Fp2.zero).toK U = R k i := by
  refine ⟨List.ofFn (fun i : Fin m => ZK60.HonestClassify.ofK U hbij (R k i)), by simp, fun i hi => ?_⟩
  have e : (List.ofFn (fun i : Fin m => ZK60.HonestClassify.ofK U hbij (R k i))).getD i Fp2.zero
      = ZK60.HonestClassify.ofK U hbij (R k i) := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_ofFn]
    split
    · rfl
    · rename_i hn
      exact absurd hi hn
  rw [e]
  exact ZK60.HonestClassify.toK_ofK U hbij _

/-- **The CFS mask coefficients of slot `k`'s row** (`a_0`, `a'`, `a_{j,e}` at `2 + j·d + e`, the code's layout). -/
def maskA (R : ℕ → ℕ → K) (k n d : ℕ) : ZK60.Hiding.CfsCoeffs K n d :=
  (R k 0, R k 1, fun j e => R k (2 + (j : ℕ) * d + (e : ℕ)))

theorem coeffsK_words (R : ℕ → ℕ → K) (k n d : ℕ) (c : List Fp2)
    (hc : ∀ i, i < (n + 1) * d + 2 → (c.getD i Fp2.zero).toK U = R k i) : coeffsK U n d c = maskA R k n d := by
  unfold coeffsK maskA
  refine Prod.ext (hc 0 (by omega)) (Prod.ext (hc 1 (by omega)) ?_)
  funext j e
  have hj := j.isLt
  have he := e.isLt
  exact hc _ (by nlinarith)

/-- **The row's dot with `eval_weights(ρ, d)` is the mask's value at `ρ`** (`n + 1` variables). -/
theorem mdot_evalWeights (hU : U ^ 2 = algebraMap GF K 7)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (R : ℕ → ℕ → K) (Wd k n d : ℕ) (rho : List Fp2)
    (hrho : rho.length = n + 1) (hW : (n + 1) * d + 2 ≤ Wd) :
    Block.mdot U R Wd (k, Cfs.evalWeights rho d) = ZK60.Hiding.cfsEval (maskA R k n d) (vecK U (n + 1) rho) := by
  obtain ⟨c, hcl, hc⟩ := exists_words U hbij R k ((n + 1) * d + 2)
  rw [mdot_eq_dot U hU R Wd k _ c (by rw [evalWeights_length, hcl, hrho]) (by rw [hcl]; exact hW)
    (fun i hi => hc i (by rw [← hcl]; exact hi)), toK_evalDot U hU n d rho c hrho hcl, coeffsK_words U R k n d c hc]

/-- **The row's dot with `sum_weights(n + 1, d)` is the mask's cube sum.** -/
theorem mdot_sumWeights (hU : U ^ 2 = algebraMap GF K 7)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (R : ℕ → ℕ → K) (Wd k n d : ℕ) (hn : n + 1 < 64)
    (hW : (n + 1) * d + 2 ≤ Wd) :
    Block.mdot U R Wd (k, Cfs.sumWeights (n + 1) d)
      = cubeSum (fun x => ZK60.Hiding.cfsEval (maskA R k n d) x) := by
  obtain ⟨c, hcl, hc⟩ := exists_words U hbij R k ((n + 1) * d + 2)
  rw [mdot_eq_dot U hU R Wd k _ c (by simp only [sumWeights_length, hcl, Cfs.len]) (by rw [hcl]; exact hW)
    (fun i hi => hc i (by rw [← hcl]; exact hi)), cubeSum_cfsEval, ← coeffsK_words U R k n d c hc,
    ← toK_total U hU n d hn c hcl]
  rfl

/-- **The CFS mask polynomial of slot `k`'s row**, on `N` variables with degree `d`:
`a_0 + a'·∏ x_j + Σ_j Σ_e a_{j,e}·x_j^(e+1)`. -/
def maskPoly (R : ℕ → ℕ → K) (k N d : ℕ) (x : Fin N → K) : K :=
  R k 0 + R k 1 * ∏ j, x j + ∑ j : Fin N, ∑ e : Fin d, R k (2 + (j : ℕ) * d + (e : ℕ)) * x j ^ ((e : ℕ) + 1)

omit [Algebra GF K] in
/-- On `n + 1` variables it is L5's `cfsEval`. -/
theorem maskPoly_succ (R : ℕ → ℕ → K) (k n d : ℕ) (x : Fin (n + 1) → K) :
    maskPoly R k (n + 1) d x = ZK60.Hiding.cfsEval (maskA R k n d) x := rfl

omit [Algebra GF K] in
/-- The product of the coordinates has degree `1` in each. -/
theorem indDeg_prod (N : ℕ) : IndDegLE 1 (fun x : Fin N → K => ∏ j, x j) := by
  intro i x
  refine ⟨C (∏ j ∈ Finset.univ \ {i}, x j) * X, (natDegree_C_mul_le _ _).trans natDegree_X_le, fun t => ?_⟩
  show ∏ j, Function.update x i t j = _
  rw [Finset.prod_update_of_mem (Finset.mem_univ i), eval_mul, eval_C, eval_X, mul_comm]

omit [Algebra GF K] in
/-- **The mask polynomial has individual degree `≤ d`** (`d ≥ 1`). -/
theorem maskPoly_indDeg (R : ℕ → ℕ → K) (k N d : ℕ) (hd : 1 ≤ d) : IndDegLE d (maskPoly R k N d) := by
  have h1 : IndDegLE d (fun x : Fin N → K => R k 0 + R k 1 * ∏ j, x j) :=
    ZK60.StageX.IndDegLE.add (ZK60.StageX.IndDegLE.const (R k 0))
      (ZK60.StageX.IndDegLE.cmul (R k 1) (ZK60.StageX.IndDegLE.mono (indDeg_prod N) hd))
  have hc : ∀ (j : Fin N) (e : Fin d), IndDegLE d (fun x : Fin N → K => x j ^ ((e : ℕ) + 1)) := by
    intro j e
    have h := ZK60.Sound.SlotW16.indDeg_pow (ZK60.Sound.SlotW16.indDeg_coord (F := K) j) ((e : ℕ) + 1)
    rw [Nat.one_mul] at h
    exact ZK60.StageX.IndDegLE.mono h (Nat.succ_le_of_lt e.isLt)
  have h2 : IndDegLE d (fun x : Fin N → K =>
      ∑ j : Fin N, ∑ e : Fin d, R k (2 + (j : ℕ) * d + (e : ℕ)) * x j ^ ((e : ℕ) + 1)) :=
    ZK60.Sound.SlotW16.indDeg_sum (fun j => ZK60.Sound.SlotW16.indDeg_sum (fun e =>
      ZK60.StageX.IndDegLE.cmul (R k (2 + (j : ℕ) * d + (e : ℕ))) (hc j e)))
  exact ZK60.StageX.IndDegLE.add h1 h2

/-- **The value of a slot's `M` functional on its row is the mask polynomial at the point**: for `N ≥ 1` challenges
`ρ`, the row's dot with `eval_weights(ρ, d)` is `maskPoly` at `ρ` read in `K`. -/
theorem maskPoly_point (hU : U ^ 2 = algebraMap GF K 7)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (R : ℕ → ℕ → K) (Wd k N d : ℕ) (hN : 0 < N)
    (rho : List Fp2) (hrho : rho.length = N) (hW : N * d + 2 ≤ Wd) :
    Block.mdot U R Wd (k, Cfs.evalWeights rho d)
      = maskPoly R k N d (fun i : Fin N => (rho.getD i Fp2.zero).toK U) := by
  obtain ⟨n, rfl⟩ : ∃ n, N = n + 1 := ⟨N - 1, by omega⟩
  rw [mdot_evalWeights U hU hbij R Wd k n d rho hrho hW]
  rfl

/-- **The row's dot with `sum_weights(N, d)` is the mask polynomial's cube sum** (`1 ≤ N < 64`): what a slot's `Γ`
functional weighs is `Σ_cube mask`. -/
theorem maskPoly_cubeSum (hU : U ^ 2 = algebraMap GF K 7)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (R : ℕ → ℕ → K) (Wd k N d : ℕ) (hN : 0 < N)
    (hN64 : N < 64) (hW : N * d + 2 ≤ Wd) :
    Block.mdot U R Wd (k, Cfs.sumWeights N d) = cubeSum (maskPoly R k N d) := by
  obtain ⟨n, rfl⟩ : ∃ n, N = n + 1 := ⟨N - 1, by omega⟩
  rw [mdot_sumWeights U hU hbij R Wd k n d hN64 hW]
  rfl

end Mask

end ZK60.Exec.Link
