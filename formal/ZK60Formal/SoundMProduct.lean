/-
D63, step L3 (soundness): the mask commitment `M`'s PRODUCT-FORM linear test as `zk::mask_verify_tagged` runs it,
and `M`'s whole opening (the affine proximity test, the product test, the column test).

The code (`zk.rs:356-372`, `530-547`, `612-698`):
* the committed base rows (over `F_p`, each evaluated on the coset `7·G_4096`): per mask `s` the rows `a_{s,re}`,
  `a_{s,im}` (the message, as VALUES on `G_512`: the mask's coefficients, 256 pads, zeros; the row is its interpolant,
  degree `< 512`); `b_re, b_im` (degree `< 1024`; the honest prover sets `b_512 = −b_0`); `u_re, u_im` (degree
  `< 1024`);
* functionals `F_i = Σ_{(s, w) ∈ terms_i} ⟨a_s, w⟩` with claimed values `value_i`;
* the verifier draws ONE `θ` and combines with its POWERS starting at `θ^0 = 1` (`combined_weights`):
  `W_s = Σ_i θ^i·w_{i,s}` and `V = Σ_i θ^i·value_i`;
* the prover sends `q'` (1024 coefficients); the verifier checks `512·(q'_0 + q'_512) = V`;
* then independent uniform proximity weights `r` over the `2·masks + 2` rows `a, b`, the proximity vector `prox`
  (1024 coefficients), and 256 uniform column indices; at each column `j`:
  `b(η_j) + Σ_s a_s(η_j)·p_{W_s}(η_j) = q'(η_j)` and `u(η_j) + Σ_row r_row·row(η_j) = prox(η_j)`, where
  `a_s = a_{s,re} + i·a_{s,im}`, `b = b_re + i·b_im`, `u = u_re + i·u_im` and `p_W` interpolates `W` on `G_512`.

The model is over one field `E` (`F_p²`). The message points are `ω^j` (`ω` a primitive `m`-th root of unity); the
columns are distinct points `η_j`; the product test reads `E`-rows `a_s`, `b` (in `mopening_sound`, fixed
`E`-linear combinations of the committed rows, as `a_{s,re} + i·a_{s,im}` is); `θ` is drawn with an exponent offset
`o` (`o = 0` is the code; `o = 1` is the fix of finding F12).

**What `M`'s check certifies (finding F12).** Suppose the rows agree, outside `e` columns, with polynomials `Ah_s`, `Bh`
(the proximity part gives this). The decoded message of `a_s` is its values on `G_m`, so the true value of
functional `i` is `tru_i = Σ_s Σ_j w_{i,s,j}·Ah_s(ω^j)` (`mTrue`). If `q'` equals the product polynomial
`P = Bh + Σ_s Ah_s·p_{W_s}`, the sum check gives `Σ_i θ^(i + o)·(value_i − tru_i) = off` with
`off = Σ_{x ∈ G_m} Bh(x) = m·(Bh_0 + Bh_m)` (`mResidual_root`). NOTHING in the verifier makes `off` zero: the
proximity test only bounds the degree of `b`. So with `o = 0` the check certifies the functionals only up to ONE
additive constant on the FIRST functional, chosen by the prover when it commits `M`:
* `mproduct_sound_code`: if some `value_i ≠ tru_i + [i = 0]·off`, the product test accepts with probability at most
  `(k − 1)/|E| + ((e + dd)/N)^Q`;
* `mproduct_offset_accepts`: an honest-looking prover with any `b` of offset `off` and `value_0 = tru_0 + off` passes
  every check for EVERY `θ` and every column sample. The statement "a false functional is caught" is false for the
  code's check whenever the first functional's value is the prover's to choose;
* `mproduct_sound_shift`: with `o = 1` (powers starting at `θ`), every false functional is caught:
  `k/|E| + ((e + dd)/N)^Q`.
`dd` bounds the degree of `P − q'`: `K + m − 1` (the a-rows are only KNOWN to have degree `≤ K = 2m − 1`, since the
proximity vector has `2m` coefficients) and `2m − 1`.

`mopening_sound`: `M`'s whole opening, the far case by `affine_proximity_third` (F6), the close case by the product
test: `max((e + 1)/(|E| − 1) + ((N − (e + 1))/N)^Q, (k − 1 + o)/|E| + ((e + dd)/N)^Q)`;
`mopening_sound_absorbed`: at the code's parameters the second term is dominated by the first.

Interactive: the committed rows fixed (the extracted matrix of `SoundOpeningRO.lean` can be substituted), `θ`, `r` and
the indices exactly uniform and independent, the prover's `q'` any function of `θ` and its `prox` any function of
`(θ, r)`. Fiat–Shamir is not modelled.
-/
import ZK60Formal.SoundGroups
import ZK60Formal.HidingMOpening

namespace ZK60.Sound

open scoped ENNReal
open Finset Prob Code Polynomial

variable {E ι σ κ : Type} [Field E]

/-! ## The model -/

/-- The message points `ω^j`, `j < m` (`G_m` in natural order). -/
def mPts {m : ℕ} (ω : E) : Fin m → E := fun j => ω ^ (j : ℕ)

/-- The verifier's interpolant of a weight vector on the message points (`weight_polys`: degree `< m`). -/
noncomputable def mInterp {m : ℕ} (ω : E) (W : Fin m → E) : E[X] := Lagrange.interpolate univ (mPts ω) W

/-- The combined weights of mask `s` (`combined_weights`): `W_s(θ) = Σ_i θ^(i + o)·w_{i,s}`. The code has `o = 0`
(`th` starts at `Fp2::ONE`). -/
def mW {k m : ℕ} (o : ℕ) (wt : Fin k → σ → Fin m → E) (θ : E) (s : σ) : Fin m → E :=
  fun j => ∑ i : Fin k, θ ^ ((i : ℕ) + o) * wt i s j

/-- The combined claimed value `V(θ) = Σ_i θ^(i + o)·value_i`. -/
def mV {k : ℕ} (o : ℕ) (val : Fin k → E) (θ : E) : E := ∑ i : Fin k, θ ^ ((i : ℕ) + o) * val i

/-- **The product test** (`mask_verify_tagged` without the Merkle layer and the proximity vector): the sum check
`m·(q'_0 + q'_m) = V(θ)`, and at every sampled column `j`: `b_j + Σ_s a_{s,j}·p_{W_s(θ)}(η_j) = q'(η_j)`. -/
def MProdAccept [Fintype σ] {k m Q : ℕ} (η : ι → E) (ω : E) (o : ℕ) (wt : Fin k → σ → Fin m → E)
    (val : Fin k → E) (a : σ → ι → E) (b : ι → E) (q : E → E[X]) (θ : E) (J : Fin Q → ι) : Prop :=
  (m : E) * ((q θ).coeff 0 + (q θ).coeff m) = mV o val θ
    ∧ ∀ t, b (J t) + ∑ s, a s (J t) * (mInterp ω (mW o wt θ s)).eval (η (J t)) = (q θ).eval (η (J t))

/-- **The true value of functional `i`** on the decoded mask polynomials `Ah`: `Σ_s Σ_j w_{i,s,j}·Ah_s(ω^j)`. The
decoded message of a row is its values on `G_m`: on the a-rows' code (degree `< m`) this is the inverse of the
encoder; for a row of degree `< 2m` it is the reading the sum check makes. -/
def mTrue [Fintype σ] {k m : ℕ} (ω : E) (wt : Fin k → σ → Fin m → E) (Ah : σ → E[X]) (i : Fin k) : E :=
  ∑ s, ∑ j, wt i s j * (Ah s).eval (mPts ω j)

/-- **The blinding offset** of the decoded `b`: its sum over `G_m`, `m·(Bh_0 + Bh_m)` for degree `< 2m`
(`mOff_eq`). The honest prover makes it zero (`b_512 = −b_0`); the verifier never checks it. -/
def mOff (m : ℕ) (ω : E) (Bh : E[X]) : E := ∑ j : Fin m, Bh.eval (mPts ω j)

/-- **The residual** in `θ`: `Σ_i (value_i − tru_i)·X^(i + o) − off`. When `q'` is the product polynomial, the sum
check says exactly that `θ` is a root of it (`mResidual_root`). -/
noncomputable def mResidual {k : ℕ} (o : ℕ) (val tru : Fin k → E) (off : E) : E[X] :=
  ∑ i : Fin k, C (val i - tru i) * X ^ ((i : ℕ) + o) - C off

/-- The product polynomial of the decoded rows, `P(θ) = Bh + Σ_s Ah_s·p_{W_s(θ)}`: what an honest prover sends as
`q'`, and the only `q'` the column checks let through except with small probability. -/
noncomputable def mProduct [Fintype σ] {k m : ℕ} (ω : E) (o : ℕ) (wt : Fin k → σ → Fin m → E) (Ah : σ → E[X])
    (Bh : E[X]) (θ : E) : E[X] :=
  Bh + ∑ s, Ah s * mInterp ω (mW o wt θ s)

/-! ## Algebra -/

/-- The message points of a primitive root are distinct. -/
theorem mPts_injective {m : ℕ} {ω : E} (hω : IsPrimitiveRoot ω m) :
    Function.Injective (mPts (m := m) ω) :=
  fun i j h => Fin.ext (hω.pow_inj i.isLt j.isLt h)

/-- The interpolant has degree `< m`. -/
theorem mInterp_natDegree_lt {m : ℕ} (hm : 0 < m) {ω : E} (hω : IsPrimitiveRoot ω m) (W : Fin m → E) :
    (mInterp ω W).natDegree < m :=
  ZK60.Hiding.natDegree_interpolate_lt hm (mPts ω) (mPts_injective hω) W

/-- The interpolant takes the weights at the message points. -/
theorem mInterp_eval {m : ℕ} {ω : E} (hω : IsPrimitiveRoot ω m) (W : Fin m → E) (j : Fin m) :
    (mInterp ω W).eval (mPts ω j) = W j :=
  Lagrange.eval_interpolate_at_node W (mPts_injective hω).injOn (mem_univ j)

/-- **The sum check reads the sum over `G_m`.** For a polynomial of degree `< 2m`,
`Σ_{x ∈ G_m} p(x) = m·(p_0 + p_m)`: the code's `512·(q'_0 + q'_512)`. -/
theorem sum_mPts_eval {m : ℕ} (hm : 0 < m) {ω : E} (hω : IsPrimitiveRoot ω m) (p : E[X])
    (hp : p.natDegree < 2 * m) :
    ∑ j : Fin m, p.eval (mPts ω j) = (m : E) * (p.coeff 0 + p.coeff m) :=
  ZK60.Hiding.sum_eval_nodes hm (mPts ω) (fun j hj => ZK60.Hiding.rootsOfUnity_powSum hω j hj) p hp

/-- The offset is `m·(Bh_0 + Bh_m)` for `Bh` of degree `< 2m`: zero exactly when `Bh_m = −Bh_0` (if `m ≠ 0` in `E`). -/
theorem mOff_eq {m : ℕ} (hm : 0 < m) {ω : E} (hω : IsPrimitiveRoot ω m) (Bh : E[X]) (hB : Bh.natDegree < 2 * m) :
    mOff m ω Bh = (m : E) * (Bh.coeff 0 + Bh.coeff m) :=
  sum_mPts_eval hm hω Bh hB

/-- The residual at `θ`: `V(θ) − Σ_i θ^(i + o)·tru_i − off`. -/
theorem mResidual_eval {k : ℕ} (o : ℕ) (val tru : Fin k → E) (off θ : E) :
    (mResidual o val tru off).eval θ = mV o val θ - ∑ i : Fin k, θ ^ ((i : ℕ) + o) * tru i - off := by
  simp only [mResidual, mV, eval_sub, eval_finsetSum, eval_mul, eval_C, eval_pow, eval_X]
  congr 1
  rw [← Finset.sum_sub_distrib]
  exact Finset.sum_congr rfl fun i _ => by ring

/-- The residual has degree at most `k − 1 + o`. -/
theorem mResidual_natDegree_le {k : ℕ} (o : ℕ) (val tru : Fin k → E) (off : E) :
    (mResidual o val tru off).natDegree ≤ k - 1 + o := by
  refine (natDegree_sub_le _ _).trans (max_le ?_ (by rw [natDegree_C]; exact Nat.zero_le _))
  refine natDegree_sum_le_of_forall_le _ _ fun i _ => (natDegree_C_mul_X_pow_le _ _).trans ?_
  have := i.isLt
  omega

/-- The coefficient of `X^(i + o)` in the residual: `value_i − tru_i`, less `off` when `i + o = 0`. -/
theorem mResidual_coeff {k : ℕ} (o : ℕ) (val tru : Fin k → E) (off : E) (i₀ : Fin k) :
    (mResidual o val tru off).coeff ((i₀ : ℕ) + o)
      = (val i₀ - tru i₀) - if (i₀ : ℕ) + o = 0 then off else 0 := by
  simp only [mResidual, coeff_sub, finsetSum_coeff, coeff_C_mul_X_pow, coeff_C]
  congr 1
  rw [Finset.sum_eq_single i₀]
  · simp
  · intro i _ hi
    have hne : ¬ ((i₀ : ℕ) + o = (i : ℕ) + o) := fun h => hi (Fin.ext (by omega))
    simp only [hne, ↓reduceIte]
  · intro h
    exact absurd (mem_univ i₀) h

/-- **The code's residual is nonzero** as soon as some functional is false beyond the offset on the first one. -/
theorem mResidual_ne_zero_code {k : ℕ} (val tru : Fin k → E) (off : E)
    (h : ∃ i : Fin k, val i ≠ tru i + if (i : ℕ) = 0 then off else 0) : mResidual 0 val tru off ≠ 0 := by
  obtain ⟨i, hi⟩ := h
  intro h0
  have hc := mResidual_coeff 0 val tru off i
  rw [h0, coeff_zero, add_zero] at hc
  apply hi
  linear_combination -hc

/-- **The fixed residual (`o = 1`) is nonzero** as soon as some functional is false, whatever the offset. -/
theorem mResidual_ne_zero_shift {k : ℕ} (val tru : Fin k → E) (off : E) (h : ∃ i : Fin k, val i ≠ tru i) :
    mResidual 1 val tru off ≠ 0 := by
  obtain ⟨i, hi⟩ := h
  intro h0
  have hc := mResidual_coeff 1 val tru off i
  rw [h0, coeff_zero] at hc
  simp only [Nat.add_one_ne_zero, ↓reduceIte, sub_zero] at hc
  exact hi (sub_eq_zero.mp hc.symm)

/-- At the message points the product polynomial sums to the offset plus the `θ`-combination of the true values. -/
theorem sum_mProduct [Fintype σ] {k m : ℕ} {ω : E} (hω : IsPrimitiveRoot ω m) (o : ℕ)
    (wt : Fin k → σ → Fin m → E) (Ah : σ → E[X]) (Bh : E[X]) (θ : E) :
    ∑ j : Fin m, (mProduct ω o wt Ah Bh θ).eval (mPts ω j)
      = mOff m ω Bh + ∑ i : Fin k, θ ^ ((i : ℕ) + o) * mTrue ω wt Ah i := by
  have h1 : ∀ j : Fin m, (mProduct ω o wt Ah Bh θ).eval (mPts ω j)
      = Bh.eval (mPts ω j) + ∑ s, (Ah s).eval (mPts ω j) * mW o wt θ s j := by
    intro j
    rw [mProduct, eval_add, eval_finsetSum]
    congr 1
    exact Finset.sum_congr rfl fun s _ => by rw [eval_mul, mInterp_eval hω]
  rw [Finset.sum_congr rfl (fun j _ => h1 j), Finset.sum_add_distrib, mOff]
  congr 1
  simp only [mW, mTrue, Finset.mul_sum]
  calc ∑ j, ∑ s, ∑ i : Fin k, (Ah s).eval (mPts ω j) * (θ ^ ((i : ℕ) + o) * wt i s j)
      = ∑ s, ∑ j, ∑ i : Fin k, (Ah s).eval (mPts ω j) * (θ ^ ((i : ℕ) + o) * wt i s j) := Finset.sum_comm
    _ = ∑ s, ∑ i : Fin k, ∑ j, (Ah s).eval (mPts ω j) * (θ ^ ((i : ℕ) + o) * wt i s j) :=
        Finset.sum_congr rfl fun s _ => Finset.sum_comm
    _ = ∑ i : Fin k, ∑ s, ∑ j, (Ah s).eval (mPts ω j) * (θ ^ ((i : ℕ) + o) * wt i s j) := Finset.sum_comm
    _ = ∑ i : Fin k, ∑ s, ∑ j, θ ^ ((i : ℕ) + o) * (wt i s j * (Ah s).eval (mPts ω j)) := by
        refine Finset.sum_congr rfl fun i _ => Finset.sum_congr rfl fun s _ =>
          Finset.sum_congr rfl fun j _ => ?_
        ring

/-- **What the sum check says when `q'` is the product polynomial**: `θ` is a root of the residual. -/
theorem mResidual_root [Fintype σ] {k m : ℕ} (hm : 0 < m) {ω : E} (hω : IsPrimitiveRoot ω m) (o : ℕ)
    (wt : Fin k → σ → Fin m → E) (val : Fin k → E) (Ah : σ → E[X]) (Bh : E[X]) (θ : E) (qθ : E[X])
    (hq : qθ.natDegree < 2 * m) (hP : qθ = mProduct ω o wt Ah Bh θ)
    (hsum : (m : E) * (qθ.coeff 0 + qθ.coeff m) = mV o val θ) :
    (mResidual o val (mTrue ω wt Ah) (mOff m ω Bh)).eval θ = 0 := by
  rw [mResidual_eval, ← hsum, ← sum_mPts_eval hm hω qθ hq, hP, sum_mProduct hω]
  ring

/-- The product polynomial and any `q'` of degree `< 2m` differ by a polynomial of degree at most `dd`. -/
theorem mProduct_sub_natDegree_le [Fintype σ] {k m K dd : ℕ} (hm : 0 < m) {ω : E} (hω : IsPrimitiveRoot ω m)
    (o : ℕ) (wt : Fin k → σ → Fin m → E) (Ah : σ → E[X]) (Bh : E[X]) (hAh : ∀ s, (Ah s).natDegree ≤ K)
    (hB : Bh.natDegree ≤ K) (hdd : K + (m - 1) ≤ dd) (hdq : 2 * m - 1 ≤ dd) (θ : E) (qθ : E[X])
    (hq : qθ.natDegree < 2 * m) :
    (mProduct ω o wt Ah Bh θ - qθ).natDegree ≤ dd := by
  refine (natDegree_sub_le _ _).trans (max_le ?_ (by omega))
  refine (natDegree_add_le _ _).trans (max_le (by omega) ?_)
  refine natDegree_sum_le_of_forall_le _ _ fun s _ => (natDegree_mul_le).trans ?_
  have h1 := hAh s
  have h2 := mInterp_natDegree_lt hm hω (mW o wt θ s)
  omega

/-! ## Two counting facts -/

/-- A nonzero polynomial of degree `≤ dd` vanishes at no more than `dd` of the distinct points `η_j`. -/
theorem card_eval_zero_le [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] {η : ι → E}
    (hη : Function.Injective η) {p : E[X]} (hp : p ≠ 0) {dd : ℕ} (hdd : p.natDegree ≤ dd) :
    (univ.filter (fun j => p.eval (η j) = 0)).card ≤ dd := by
  refine le_trans ?_ ((card_roots_le p hp).trans hdd)
  refine card_le_card_of_injOn η (fun j hj => ?_) hη.injOn
  simp only [coe_filter, mem_univ, true_and, Set.mem_ofPred_eq] at hj ⊢
  exact hj

/-- `Q` uniform indices all land in a set of at most `n` of the `N` columns with probability at most `(n/N)^Q`. -/
theorem prob_all_mem_le [Fintype ι] [DecidableEq ι] [Nonempty ι] (T : Finset ι) {n : ℕ} (hT : T.card ≤ n)
    (Q : ℕ) :
    (PMF.uniformOfFintype (Fin Q → ι)).toOuterMeasure {J | ∀ t, J t ∈ T}
      ≤ (((n : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q := by
  have hset : {J : Fin Q → ι | ∀ t, J t ∈ T} = {J | ∀ t, J t ∉ Tᶜ} := by
    ext J
    simp
  rw [hset, column_miss_prob]
  have hTc : Fintype.card ι - Tᶜ.card = T.card := by
    rw [card_compl]
    have := card_le_univ T
    omega
  rw [hTc]
  refine pow_le_pow_left₀ zero_le (ENNReal.div_le_div_right (by exact_mod_cast hT) _) Q

/-- **The column part of the product test.** If `q'(θ)` is NOT the product polynomial of the decoded rows, the
column checks pass at a column only off the agreement set `S` or at a root of `P − q'`: at most `e + dd` columns, so
all `Q` checks pass with probability at most `((e + dd)/N)^Q`. -/
theorem mprod_columns_prob [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] [Nonempty ι] [Fintype σ]
    {k m Q e K dd : ℕ} (hm : 0 < m) {ω : E} (hω : IsPrimitiveRoot ω m) (η : ι → E) (hη : Function.Injective η)
    (o : ℕ) (wt : Fin k → σ → Fin m → E) (a : σ → ι → E) (b : ι → E) (Ah : σ → E[X]) (Bh : E[X])
    (hAh : ∀ s, (Ah s).natDegree ≤ K) (hB : Bh.natDegree ≤ K) (S : Finset ι) (hS : Fintype.card ι ≤ S.card + e)
    (haS : ∀ j ∈ S, ∀ s, a s j = (Ah s).eval (η j)) (hbS : ∀ j ∈ S, b j = Bh.eval (η j))
    (hdd : K + (m - 1) ≤ dd) (hdq : 2 * m - 1 ≤ dd) (θ : E) (qθ : E[X]) (hq : qθ.natDegree < 2 * m)
    (hne : qθ ≠ mProduct ω o wt Ah Bh θ) :
    (PMF.uniformOfFintype (Fin Q → ι)).toOuterMeasure
        {J | ∀ t, b (J t) + ∑ s, a s (J t) * (mInterp ω (mW o wt θ s)).eval (η (J t)) = qθ.eval (η (J t))}
      ≤ (((e + dd : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q := by
  classical
  set p := mProduct ω o wt Ah Bh θ - qθ with hp
  have hp0 : p ≠ 0 := sub_ne_zero.mpr (Ne.symm hne)
  have hTcard : (Sᶜ ∪ univ.filter (fun j => p.eval (η j) = 0)).card ≤ e + dd := by
    have h1 := card_union_le Sᶜ (univ.filter (fun j => p.eval (η j) = 0))
    have h2 := card_eval_zero_le hη hp0 (mProduct_sub_natDegree_le hm hω o wt Ah Bh hAh hB hdd hdq θ qθ hq)
    rw [card_compl] at h1
    omega
  refine le_trans (MeasureTheory.measure_mono (fun J hJ => ?_)) (prob_all_mem_le _ hTcard Q)
  intro t
  by_cases hjS : J t ∈ S
  · refine mem_union_right _ (mem_filter.mpr ⟨mem_univ _, ?_⟩)
    have hcol := hJ t
    rw [hbS _ hjS] at hcol
    simp only [haS _ hjS] at hcol
    rw [hp, eval_sub, sub_eq_zero, ← hcol]
    simp only [mProduct, eval_add, eval_finsetSum, eval_mul]
  · exact mem_union_left _ (mem_compl.mpr hjS)

/-! ## The product test -/

/-- **The product test is sound up to its residual (task 2).** Let the rows the product test reads agree, outside at
most `e` of the `N` columns, with polynomials `Ah_s`, `Bh` of degree `≤ K` (the proximity part), and let the residual
`Σ_i (value_i − tru_i)·X^(i + o) − off` of the decoded data be nonzero. For any prover (`q'` any function of `θ` of
degree `< 2m`), the product test accepts with probability at most `(k − 1 + o)/|E| + ((e + dd)/N)^Q`, over uniform
`θ` and `Q` column indices drawn uniformly with replacement. -/
theorem mproduct_sound [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] [Nonempty ι] [Fintype σ]
    {k m Q e K dd : ℕ} (hm : 0 < m) {ω : E} (hω : IsPrimitiveRoot ω m) (η : ι → E) (hη : Function.Injective η)
    (o : ℕ) (wt : Fin k → σ → Fin m → E) (val : Fin k → E) (a : σ → ι → E) (b : ι → E)
    (Ah : σ → E[X]) (Bh : E[X]) (hAh : ∀ s, (Ah s).natDegree ≤ K) (hB : Bh.natDegree ≤ K)
    (S : Finset ι) (hS : Fintype.card ι ≤ S.card + e)
    (haS : ∀ j ∈ S, ∀ s, a s j = (Ah s).eval (η j)) (hbS : ∀ j ∈ S, b j = Bh.eval (η j))
    (hdd : K + (m - 1) ≤ dd) (hdq : 2 * m - 1 ≤ dd)
    (hres : mResidual o val (mTrue ω wt Ah) (mOff m ω Bh) ≠ 0)
    (q : E → E[X]) (hq : ∀ θ, (q θ).natDegree < 2 * m) :
    (PMF.uniformOfFintype (E × (Fin Q → ι))).toOuterMeasure
        {x | MProdAccept η ω o wt val a b q x.1 x.2}
      ≤ ((k - 1 + o : ℕ) : ℝ≥0∞) / Fintype.card E + (((e + dd : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q := by
  classical
  have hsplit : {x : E × (Fin Q → ι) | MProdAccept η ω o wt val a b q x.1 x.2}
      ⊆ {x | (mResidual o val (mTrue ω wt Ah) (mOff m ω Bh)).eval x.1 = 0}
        ∪ {x | q x.1 ≠ mProduct ω o wt Ah Bh x.1
          ∧ ∀ t, b (x.2 t) + ∑ s, a s (x.2 t) * (mInterp ω (mW o wt x.1 s)).eval (η (x.2 t))
            = (q x.1).eval (η (x.2 t))} := by
    intro x hx
    by_cases hP : q x.1 = mProduct ω o wt Ah Bh x.1
    · exact Or.inl (mResidual_root hm hω o wt val Ah Bh x.1 (q x.1) (hq x.1) hP hx.1)
    · exact Or.inr ⟨hP, hx.2⟩
  refine le_trans (MeasureTheory.measure_mono hsplit)
    (le_trans (MeasureTheory.measure_union_le _ _) (add_le_add ?_ ?_))
  · refine prob_prod_le_of_forall_snd
      (fun x : E × (Fin Q → ι) => (mResidual o val (mTrue ω wt Ah) (mOff m ω Bh)).eval x.1 = 0) _ (fun _ => ?_)
    exact schwartzZippel hres (mResidual_natDegree_le o val _ _)
  · refine prob_prod_le_of_forall_fst _ _ (fun θ => ?_)
    by_cases hP : q θ = mProduct ω o wt Ah Bh θ
    · exact prob_le_of_forall_not (fun J hJ => hJ.1 hP) _
    · exact le_trans (MeasureTheory.measure_mono (fun J hJ => hJ.2))
        (mprod_columns_prob hm hω η hη o wt a b Ah Bh hAh hB S hS haS hbS hdd hdq θ (q θ) (hq θ) hP)

/-- **The code's product test (`o = 0`).** If some functional is false beyond an additive `off` on the FIRST one
(`value_i ≠ tru_i + [i = 0]·off`, `off` the decoded `b`'s sum over `G_m`), the product test accepts with probability
at most `(k − 1)/|E| + ((e + dd)/N)^Q`. With `off = 0` this is "a false functional is caught"; the code never checks
`off = 0` (finding F12, `mproduct_offset_accepts`). -/
theorem mproduct_sound_code [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] [Nonempty ι] [Fintype σ]
    {k m Q e K dd : ℕ} (hm : 0 < m) {ω : E} (hω : IsPrimitiveRoot ω m) (η : ι → E) (hη : Function.Injective η)
    (wt : Fin k → σ → Fin m → E) (val : Fin k → E) (a : σ → ι → E) (b : ι → E)
    (Ah : σ → E[X]) (Bh : E[X]) (hAh : ∀ s, (Ah s).natDegree ≤ K) (hB : Bh.natDegree ≤ K)
    (S : Finset ι) (hS : Fintype.card ι ≤ S.card + e)
    (haS : ∀ j ∈ S, ∀ s, a s j = (Ah s).eval (η j)) (hbS : ∀ j ∈ S, b j = Bh.eval (η j))
    (hdd : K + (m - 1) ≤ dd) (hdq : 2 * m - 1 ≤ dd)
    (hfalse : ∃ i : Fin k, val i ≠ mTrue ω wt Ah i + if (i : ℕ) = 0 then mOff m ω Bh else 0)
    (q : E → E[X]) (hq : ∀ θ, (q θ).natDegree < 2 * m) :
    (PMF.uniformOfFintype (E × (Fin Q → ι))).toOuterMeasure
        {x | MProdAccept η ω 0 wt val a b q x.1 x.2}
      ≤ ((k - 1 : ℕ) : ℝ≥0∞) / Fintype.card E + (((e + dd : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q :=
  mproduct_sound hm hω η hη 0 wt val a b Ah Bh hAh hB S hS haS hbS hdd hdq
    (mResidual_ne_zero_code val _ _ hfalse) q hq

/-- **The fixed product test (`o = 1`: powers of `θ` from `θ^1`).** Any false functional is caught, whatever `b`:
probability at most `k/|E| + ((e + dd)/N)^Q`. -/
theorem mproduct_sound_shift [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] [Nonempty ι] [Fintype σ]
    {k m Q e K dd : ℕ} (hk : 0 < k) (hm : 0 < m) {ω : E} (hω : IsPrimitiveRoot ω m) (η : ι → E)
    (hη : Function.Injective η) (wt : Fin k → σ → Fin m → E) (val : Fin k → E) (a : σ → ι → E) (b : ι → E)
    (Ah : σ → E[X]) (Bh : E[X]) (hAh : ∀ s, (Ah s).natDegree ≤ K) (hB : Bh.natDegree ≤ K)
    (S : Finset ι) (hS : Fintype.card ι ≤ S.card + e)
    (haS : ∀ j ∈ S, ∀ s, a s j = (Ah s).eval (η j)) (hbS : ∀ j ∈ S, b j = Bh.eval (η j))
    (hdd : K + (m - 1) ≤ dd) (hdq : 2 * m - 1 ≤ dd) (hfalse : ∃ i : Fin k, val i ≠ mTrue ω wt Ah i)
    (q : E → E[X]) (hq : ∀ θ, (q θ).natDegree < 2 * m) :
    (PMF.uniformOfFintype (E × (Fin Q → ι))).toOuterMeasure
        {x | MProdAccept η ω 1 wt val a b q x.1 x.2}
      ≤ ((k : ℕ) : ℝ≥0∞) / Fintype.card E + (((e + dd : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q := by
  have h := mproduct_sound (Q := Q) hm hω η hη 1 wt val a b Ah Bh hAh hB S hS haS hbS hdd hdq
    (mResidual_ne_zero_shift val _ _ hfalse) q hq
  rwa [show k - 1 + 1 = k by omega] at h

/-- **The offset attack on the code's check (finding F12).** Take any decoded rows: `Ah_s` of degree `< m` (honest
a-rows) and `Bh` of degree `< 2m`, the committed rows their exact evaluations. Shift the FIRST functional's value by
the offset `off = Σ_{x ∈ G_m} Bh(x)`. The prover that sends the product polynomial as `q'` passes the product test for
EVERY `θ` and EVERY column sample, while functional 0 is false whenever `off ≠ 0`. -/
theorem mproduct_offset_accepts [Fintype σ] {k m Q : ℕ} (hk : 0 < k) (hm : 0 < m) {ω : E}
    (hω : IsPrimitiveRoot ω m) (η : ι → E) (wt : Fin k → σ → Fin m → E) (Ah : σ → E[X]) (Bh : E[X])
    (hAh : ∀ s, (Ah s).natDegree < m) (hB : Bh.natDegree < 2 * m) (θ : E) (J : Fin Q → ι) :
    MProdAccept η ω 0 wt (fun i => mTrue ω wt Ah i + if (i : ℕ) = 0 then mOff m ω Bh else 0)
        (fun s j => (Ah s).eval (η j)) (fun j => Bh.eval (η j)) (mProduct ω 0 wt Ah Bh) θ J := by
  have hdeg : (mProduct ω 0 wt Ah Bh θ).natDegree < 2 * m := by
    refine lt_of_le_of_lt (natDegree_add_le _ _) (max_lt hB (lt_of_le_of_lt ?_ (show 2 * m - 2 < 2 * m by omega)))
    refine natDegree_sum_le_of_forall_le _ _ fun s _ => (natDegree_mul_le).trans ?_
    have h1 := hAh s
    have h2 := mInterp_natDegree_lt hm hω (mW 0 wt θ s)
    omega
  refine ⟨?_, fun t => ?_⟩
  · rw [← sum_mPts_eval hm hω _ hdeg, sum_mProduct hω, mV]
    simp only [mul_add, Finset.sum_add_distrib, mul_ite, mul_zero, add_zero]
    have h0 : ∑ i : Fin k, (if (i : ℕ) = 0 then θ ^ (i : ℕ) * mOff m ω Bh else 0) = mOff m ω Bh := by
      rw [Finset.sum_eq_single ⟨0, hk⟩]
      · simp
      · intro i _ hi
        have : (i : ℕ) ≠ 0 := fun h => hi (Fin.ext h)
        simp [this]
      · intro h
        exact absurd (mem_univ _) h
    rw [h0, add_comm]
  · simp only [mProduct, eval_add, eval_finsetSum, eval_mul]

/-- In the offset attack, functional 0 is false exactly when the offset is nonzero. -/
theorem mproduct_offset_false [Fintype σ] {k m : ℕ} (hk : 0 < k) {ω : E} (wt : Fin k → σ → Fin m → E)
    (Ah : σ → E[X]) (Bh : E[X]) (hoff : mOff m ω Bh ≠ 0) :
    (fun i : Fin k => mTrue ω wt Ah i + if (i : ℕ) = 0 then mOff m ω Bh else 0) ⟨0, hk⟩ ≠ mTrue ω wt Ah ⟨0, hk⟩ := by
  simp only [↓reduceIte, ne_eq, add_eq_left]
  exact hoff

/-! ## `M`'s whole opening -/

/-- **`M`'s verifier** (`mask_verify_tagged` without the Merkle layer). The committed rows are `Ub` (in the code the
`2·masks + 2` base rows `a_{s,re}, a_{s,im}, b_re, b_im`) and the proximity mask `u`; the product test reads the fixed
combinations `a_s = Σ_κ La_{s,κ}·Ub_κ` and `b = Σ_κ Lb_κ·Ub_κ` (the code: `a_{s,re} + i·a_{s,im}`,
`b_re + i·b_im`). Accepted: the product test, and at every sampled column `u_j + Σ_κ r_κ·Ub_{κ,j} = prox(η_j)`. -/
def MAccept [Fintype σ] [Fintype κ] {k m Q : ℕ} (η : ι → E) (ω : E) (o : ℕ) (wt : Fin k → σ → Fin m → E)
    (val : Fin k → E) (Ub : κ → ι → E) (u : ι → E) (La : σ → κ → E) (Lb : κ → E) (q : E → E[X])
    (prox : E → (κ → E) → E[X]) (θ : E) (r : κ → E) (J : Fin Q → ι) : Prop :=
  MProdAccept η ω o wt val (fun s => comb Ub (La s)) (comb Ub Lb) q θ J
    ∧ ∀ t, u (J t) + comb Ub r (J t) = (prox θ r).eval (η (J t))

/-- The decoded mask polynomials, from decoded base rows `Rh`: `Ah_s = Σ_κ La_{s,κ}·Rh_κ`. -/
noncomputable def mDecA [Fintype κ] (La : σ → κ → E) (Rh : κ → E[X]) (s : σ) : E[X] := ∑ i, C (La s i) * Rh i

/-- The decoded blinding polynomial, from decoded base rows `Rh`: `Bh = Σ_κ Lb_κ·Rh_κ`. -/
noncomputable def mDecB [Fintype κ] (Lb : κ → E) (Rh : κ → E[X]) : E[X] := ∑ i, C (Lb i) * Rh i

/-- **The good case of `M`'s opening.** The table `(u, Ub)` agrees, outside at most `e` columns, with polynomials of
degree `≤ K` (the rows `Ub` with `Rh`), and the residual of the decoded data vanishes: with `o = 0`,
`value_i = tru_i + [i = 0]·off`. -/
def MGood [Fintype ι] [Fintype σ] [Fintype κ] {k m : ℕ} (η : ι → E) (ω : E) (o : ℕ) (e K : ℕ)
    (wt : Fin k → σ → Fin m → E) (val : Fin k → E) (Ub : κ → ι → E) (u : ι → E) (La : σ → κ → E) (Lb : κ → E) :
    Prop :=
  ∃ (S : Finset ι) (uh : E[X]) (Rh : κ → E[X]), Fintype.card ι ≤ S.card + e ∧ uh.natDegree ≤ K
    ∧ (∀ i, (Rh i).natDegree ≤ K) ∧ (∀ j ∈ S, u j = uh.eval (η j)) ∧ (∀ j ∈ S, ∀ i, Ub i j = (Rh i).eval (η j))
    ∧ mResidual o val (mTrue ω wt (mDecA La Rh)) (mOff m ω (mDecB Lb Rh)) = 0

/-- **The decoded rows are unique.** Two decodings of the same rows, each agreeing outside at most `e` of the `N`
columns with polynomials of degree `≤ K`, have the same polynomials when `2e + K < N`. So the `Rh` of `MGood` is THE
decoded data, and `¬ MGood` says that the decoded data's residual is nonzero (or that the rows are far). -/
theorem mDecoded_unique [Fintype ι] [DecidableEq ι] (dom : ι ↪ E) {K e : ℕ} (h2 : 2 * e + K < Fintype.card ι)
    {Ub : κ → ι → E} {S S' : Finset ι} (hS : Fintype.card ι ≤ S.card + e) (hS' : Fintype.card ι ≤ S'.card + e)
    {Rh Rh' : κ → E[X]} (hR : ∀ i, (Rh i).natDegree ≤ K) (hR' : ∀ i, (Rh' i).natDegree ≤ K)
    (hU : ∀ j ∈ S, ∀ i, Ub i j = (Rh i).eval (dom j)) (hU' : ∀ j ∈ S', ∀ i, Ub i j = (Rh' i).eval (dom j)) :
    Rh = Rh' := by
  funext i
  have hI := card_inter_large hS hS'
  refine eq_of_natDegree_lt_card_of_eval_eq (Rh i) (Rh' i) (f := fun j : {j // j ∈ S ∩ S'} => dom j.1)
    (fun a b h => Subtype.ext (dom.injective h)) (fun j => ?_) ?_
  · have hj := mem_inter.mp j.2
    rw [← hU j.1 hj.1 i, hU' j.1 hj.2 i]
  · rw [Fintype.card_coe]
    have h1 := hR i
    have h1' := hR' i
    exact max_lt (by omega) (by omega)

/-- The decoded combination agrees with the combined rows on the agreement set. -/
theorem comb_eval_dec [Fintype κ] (η : ι → E) (Ub : κ → ι → E) (Rh : κ → E[X]) (L : κ → E) {S : Finset ι}
    (hS : ∀ j ∈ S, ∀ i, Ub i j = (Rh i).eval (η j)) :
    ∀ j ∈ S, comb Ub L j = (∑ i, C (L i) * Rh i).eval (η j) := by
  intro j hj
  rw [comb_apply, eval_finsetSum]
  exact Finset.sum_congr rfl fun i _ => by rw [eval_mul, eval_C, hS j hj i]

/-- The decoded combination has degree `≤ K`. -/
theorem dec_natDegree_le [Fintype κ] {K : ℕ} (Rh : κ → E[X]) (hR : ∀ i, (Rh i).natDegree ≤ K) (L : κ → E) :
    (∑ i, C (L i) * Rh i).natDegree ≤ K :=
  natDegree_sum_le_of_forall_le _ _ fun i _ => (natDegree_C_mul_le _ _).trans (hR i)

/-- **`M`'s whole opening is sound (task 2).** The code is the RS code of degree `≤ K` at the `N` distinct points
`dom`, with `3e < N − K`. For any committed rows `(u, Ub)`, any claimed functionals and any prover (`q'` of degree
`< 2m` any function of `θ`, `prox` of degree `≤ K` any function of `(θ, r)`), the verifier accepts while the opening is
not good with probability at most the larger of
* the far case: `(e + 1)/(|E| − 1) + ((N − (e + 1))/N)^Q` (the affine proximity test, F6, and its column test), and
* the close case: `(k − 1 + o)/|E| + ((e + dd)/N)^Q` (`mproduct_sound`).
`U` decides the case before any challenge, so the two do not add. -/
theorem mopening_sound [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] [Nonempty ι] [Fintype σ]
    [Fintype κ] [DecidableEq κ] {k m Q e K dd : ℕ} (hm : 0 < m) {ω : E} (hω : IsPrimitiveRoot ω m)
    (dom : ι ↪ E) (h3 : 3 * e < Fintype.card ι - K) (hdd : K + (m - 1) ≤ dd) (hdq : 2 * m - 1 ≤ dd)
    (o : ℕ) (wt : Fin k → σ → Fin m → E) (val : Fin k → E) (Ub : κ → ι → E) (u : ι → E) (La : σ → κ → E)
    (Lb : κ → E) (q : E → E[X]) (hq : ∀ θ, (q θ).natDegree < 2 * m) (prox : E → (κ → E) → E[X])
    (hprox : ∀ θ r, (prox θ r).natDegree ≤ K) :
    (PMF.uniformOfFintype ((E × (κ → E)) × (Fin Q → ι))).toOuterMeasure
        {x | MAccept dom ω o wt val Ub u La Lb q prox x.1.1 x.1.2 x.2
          ∧ ¬ MGood dom ω o e K wt val Ub u La Lb}
      ≤ max (((e + 1 : ℕ) : ℝ≥0∞) / (Fintype.card E - 1 : ℕ)
              + (((Fintype.card ι - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q)
            (((k - 1 + o : ℕ) : ℝ≥0∞) / Fintype.card E + (((e + dd : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q) := by
  classical
  have hd := minDist_rsCode dom K
  by_cases hc : Close (rsCode dom K) e (withFirst u Ub)
  · -- close: decode the rows
    refine le_trans ?_ (le_max_right _ _)
    obtain ⟨V, S, hV, hS, hUV⟩ := hc.exists_table
    choose Rh hRh hVR using fun o' => mem_rsCode.mp (hV o')
    have hu : ∀ j ∈ S, u j = (Rh none).eval (dom j) := fun j hj => by
      rw [show u j = withFirst u Ub none j from rfl, hUV j hj none, hVR none j]
    have hUb : ∀ j ∈ S, ∀ i, Ub i j = (Rh (some i)).eval (dom j) := fun j hj i => by
      rw [show Ub i j = withFirst u Ub (some i) j from rfl, hUV j hj (some i), hVR (some i) j]
    set Rb : κ → E[X] := fun i => Rh (some i)
    by_cases hres : mResidual o val (mTrue ω wt (mDecA La Rb)) (mOff m ω (mDecB Lb Rb)) = 0
    · exact prob_le_of_forall_not
        (fun x hx => hx.2 ⟨S, Rh none, Rb, hS, hRh none, fun i => hRh (some i), hu, hUb, hres⟩) _
    · have haS : ∀ s, ∀ j ∈ S, comb Ub (La s) j = (mDecA La Rb s).eval (dom j) :=
        fun s => comb_eval_dec dom Ub Rb (La s) hUb
      have hAh : ∀ s, (mDecA La Rb s).natDegree ≤ K := fun s => dec_natDegree_le Rb (fun i => hRh (some i)) _
      have hB : (mDecB Lb Rb).natDegree ≤ K := dec_natDegree_le Rb (fun i => hRh (some i)) _
      have hsplit : {x : (E × (κ → E)) × (Fin Q → ι) | MAccept dom ω o wt val Ub u La Lb q prox x.1.1 x.1.2 x.2
            ∧ ¬ MGood dom ω o e K wt val Ub u La Lb}
          ⊆ {x | (mResidual o val (mTrue ω wt (mDecA La Rb)) (mOff m ω (mDecB Lb Rb))).eval x.1.1 = 0}
            ∪ {x | q x.1.1 ≠ mProduct ω o wt (mDecA La Rb) (mDecB Lb Rb) x.1.1
              ∧ ∀ t, comb Ub Lb (x.2 t)
                  + ∑ s, comb Ub (La s) (x.2 t) * (mInterp ω (mW o wt x.1.1 s)).eval (dom (x.2 t))
                = (q x.1.1).eval (dom (x.2 t))} := by
        intro x hx
        by_cases hP : q x.1.1 = mProduct ω o wt (mDecA La Rb) (mDecB Lb Rb) x.1.1
        · exact Or.inl (mResidual_root hm hω o wt val _ _ x.1.1 (q x.1.1) (hq x.1.1) hP hx.1.1.1)
        · exact Or.inr ⟨hP, hx.1.1.2⟩
      refine le_trans (MeasureTheory.measure_mono hsplit)
        (le_trans (MeasureTheory.measure_union_le _ _) (add_le_add ?_ ?_))
      · refine prob_prod_le_of_forall_snd (fun x : (E × (κ → E)) × (Fin Q → ι) =>
          (mResidual o val (mTrue ω wt (mDecA La Rb)) (mOff m ω (mDecB Lb Rb))).eval x.1.1 = 0) _ (fun _ => ?_)
        refine prob_prod_le_of_forall_snd (fun y : E × (κ → E) =>
          (mResidual o val (mTrue ω wt (mDecA La Rb)) (mOff m ω (mDecB Lb Rb))).eval y.1 = 0) _ (fun _ => ?_)
        exact schwartzZippel hres (mResidual_natDegree_le o val _ _)
      · refine prob_prod_le_of_forall_fst _ _ (fun y => ?_)
        by_cases hP : q y.1 = mProduct ω o wt (mDecA La Rb) (mDecB Lb Rb) y.1
        · exact prob_le_of_forall_not (fun J hJ => hJ.1 hP) _
        · exact le_trans (MeasureTheory.measure_mono (fun J hJ => hJ.2))
            (mprod_columns_prob hm hω dom dom.injective o wt (fun s => comb Ub (La s)) (comb Ub Lb)
              (mDecA La Rb) (mDecB Lb Rb) hAh hB S hS (fun j hj s => haS s j hj)
              (comb_eval_dec dom Ub Rb Lb hUb) hdd hdq y.1 (q y.1) (hq y.1) hP)
  · -- far: the affine proximity test, then the column test against the proximity vector
    refine le_trans ?_ (le_max_left _ _)
    have hsplit : {x : (E × (κ → E)) × (Fin Q → ι) | MAccept dom ω o wt val Ub u La Lb q prox x.1.1 x.1.2 x.2
          ∧ ¬ MGood dom ω o e K wt val Ub u La Lb}
        ⊆ {x | Close (rsCode dom K) e (fun _ : Unit => u + comb Ub x.1.2)}
          ∪ {x | ¬ Close (rsCode dom K) e (fun _ : Unit => u + comb Ub x.1.2)
            ∧ ∀ t, (prox x.1.1 x.1.2).eval (dom (x.2 t)) = (u + comb Ub x.1.2) (x.2 t)} := by
      intro x hx
      by_cases h1 : Close (rsCode dom K) e (fun _ : Unit => u + comb Ub x.1.2)
      · exact Or.inl h1
      · exact Or.inr ⟨h1, fun t => (hx.1.2 t).symm⟩
    refine le_trans (MeasureTheory.measure_mono hsplit)
      (le_trans (MeasureTheory.measure_union_le _ _) (add_le_add ?_ ?_))
    · refine prob_prod_le_of_forall_snd (fun x : (E × (κ → E)) × (Fin Q → ι) =>
        Close (rsCode dom K) e (fun _ : Unit => u + comb Ub x.1.2)) _ (fun _ => ?_)
      refine prob_prod_le_of_forall_fst (fun y : E × (κ → E) =>
        Close (rsCode dom K) e (fun _ : Unit => u + comb Ub y.2)) _ (fun _ => ?_)
      exact affine_proximity_third hd h3 u Ub hc
    · refine prob_prod_le_of_forall_fst _ _ (fun y => ?_)
      by_cases hρ : Close (rsCode dom K) e (fun _ : Unit => u + comb Ub y.2)
      · exact prob_le_of_forall_not (fun J hJ => hJ.1 hρ) _
      · have hw : (fun j => (prox y.1 y.2).eval (dom j)) ∈ rsCode dom K :=
          mem_rsCode.mpr ⟨prox y.1 y.2, hprox y.1 y.2, fun _ => rfl⟩
        have ht : e + 1 ≤ (univ.filter (fun j => (prox y.1 y.2).eval (dom j) ≠ (u + comb Ub y.2) j)).card := by
          by_contra hlt
          have hle : (univ.filter (fun j => (prox y.1 y.2).eval (dom j) ≠ (u + comb Ub y.2) j)).card ≤ e := by
            omega
          exact hρ (close_of_card_ne_le hw hle)
        exact le_trans (MeasureTheory.measure_mono (fun J hJ => hJ.2)) (column_test_sound _ _ ht Q)

/-- **`M`'s opening at the code's parameters: the product test adds nothing.** When `k − 1 + o ≤ e + 1` and
`e + dd ≤ N − (e + 1)`, the close case is dominated by the far case and the bound is the proximity-only
`(e + 1)/(|E| − 1) + ((N − (e + 1))/N)^Q`. For `M` (`N = 4096`, `K = 1023`, `m = 512`, `e = 1024`, `dd = 1534`,
`k = 34` functionals per block, `Q = 256`): `1025/(p² − 1) + (3071/4096)^256`. -/
theorem mopening_sound_absorbed [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] [Nonempty ι] [Fintype σ]
    [Fintype κ] [DecidableEq κ] {k m Q e K dd : ℕ} (hm : 0 < m) {ω : E} (hω : IsPrimitiveRoot ω m)
    (dom : ι ↪ E) (h3 : 3 * e < Fintype.card ι - K) (hdd : K + (m - 1) ≤ dd) (hdq : 2 * m - 1 ≤ dd)
    (o : ℕ) (hko : k - 1 + o ≤ e + 1) (hcol : e + dd ≤ Fintype.card ι - (e + 1))
    (wt : Fin k → σ → Fin m → E) (val : Fin k → E) (Ub : κ → ι → E) (u : ι → E) (La : σ → κ → E)
    (Lb : κ → E) (q : E → E[X]) (hq : ∀ θ, (q θ).natDegree < 2 * m) (prox : E → (κ → E) → E[X])
    (hprox : ∀ θ r, (prox θ r).natDegree ≤ K) :
    (PMF.uniformOfFintype ((E × (κ → E)) × (Fin Q → ι))).toOuterMeasure
        {x | MAccept dom ω o wt val Ub u La Lb q prox x.1.1 x.1.2 x.2
          ∧ ¬ MGood dom ω o e K wt val Ub u La Lb}
      ≤ ((e + 1 : ℕ) : ℝ≥0∞) / (Fintype.card E - 1 : ℕ)
        + (((Fintype.card ι - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q := by
  refine le_trans (mopening_sound hm hω dom h3 hdd hdq o wt val Ub u La Lb q hq prox hprox) (max_le le_rfl ?_)
  refine add_le_add (ENNReal.div_le_div (by exact_mod_cast hko) (by exact_mod_cast Nat.sub_le _ 1)) ?_
  exact pow_le_pow_left₀ zero_le (ENNReal.div_le_div_right (by exact_mod_cast hcol) _) Q

end ZK60.Sound
