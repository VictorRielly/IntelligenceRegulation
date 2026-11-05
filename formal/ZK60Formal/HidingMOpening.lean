/-
D63, step L4 (zero knowledge): the WHOLE opening view of the mask commitment `M`, jointly with its a-row columns.

What the verifier sees of `M` (`hashline/src/zk.rs`, `mask_commit_tagged`, `mask_open`, `mask_verify_tagged`; the private
block commits `M` once and opens it once, `private_block/protocol.rs`). The base-field rows of `M` are:
* two a-rows per CFS mask `s` (`k = true`: the real parts, `k = false`: the imaginary parts of its `L_s` Fp2
  coefficients). Each a-row's MESSAGE is `[L_s coefficients, 256 pads, zeros]` on `G_512`; the committed row is its
  interpolant `p_{a_{s,k}}` (degree `< 512`, `a_coefs`);
* `b_re`, `b_im`: the blinding polynomial, `1024` uniform coefficients each, with `b_512 := −b_0`, so that
  `Σ_{x ∈ G_512} b(x) = 512·(b_0 + b_512) = 0`;
* `u_re`, `u_im`: the proximity mask, `1024` uniform coefficients each.
For one opening at FIXED challenges (`θ`, the proximity weights `r`, the sampled columns), the prover sends:
* `q' = Σ_s p_{a_s}·p_{W_s} + p_b` as `1024` Fp2 coefficients, where `p_{a_s} = p_{a_{s,re}} + U·p_{a_{s,im}}`, `U² = 7`,
  and `p_{W_s}` is the interpolant on `G_512` of the θ-combined functional weights of mask `s` (zero beyond `L_s`). The
  code computes it in components: `q_re = b_re + Σ (a_re·w_re + 7·a_im·w_im)`, `q_im = b_im + Σ (a_re·w_im + a_im·w_re)`;
* `prox = u + Σ_rows r_row · row` (over the a-rows and `b_re`, `b_im`; `r_row ∈ Fp2`, so in components
  `prox_re = u_re + Σ r_row.c0·row`, `prox_im = u_im + Σ r_row.c1·row`), `1024` Fp2 coefficients;
* at each sampled column, every base row's value there: the a-rows, `b_re`, `b_im`, `u_re`, `u_im`.
(Salts and Merkle paths are `HidingMerkle.lean`'s.) The verifier checks `512·(q'_0 + q'_512) = V`, the θ-combined value
of the functionals (the `g(ρ)`'s and the `Γ`'s), and both linear relations at every sampled column.

This file proves (honest verifier, fixed challenges):
* `mOpenView_shift`, `mOpenView_law_eq`: **the joint law of `(q', prox, every opened column of every row)` over the pads,
  `b` and `u` depends on the mask coefficients ONLY through the functional value `V`** (its two components): any two
  coefficient families with the same `V` give the same law. So a simulator that knows `V` (which the verifier computes
  from the rest of the transcript) runs the honest opening with ANY coefficients of value `V`. The proof is a coin
  shift: the a-row pads absorb the coefficients' opened values (`mPadBlock_surjective`), `b` absorbs the change of
  `Σ p_a p_W` (it keeps the zero-sum constraint exactly because `V` is unchanged), and `u` absorbs the change of the
  proximity vector; every shift vanishes at the opened points.
* `mOpenView_joint_law_eq`: the same jointly with any other part of the view computed from independent coins, when `V`
  is a function of that part. This is the form that composes with the masked sumcheck (`HidingSumcheckJoint.lean`),
  whose coins are the same mask coefficients.
* `mask_open_law_eq`: the statement on the code's layout (`mRowMsg`, `mPadPos`, weights zero beyond `L_s`, `G_m` the
  `m`-th roots of unity in natural order, the coset `h·⟨ω_N⟩`, samples with replacement, `q ≤ Q`).
* `fp2` lemmas: the reading of a code pair `(c0, c1)` as `c0 + U·c1` in an extension `K` with `U² = κ`
  (`fp2_mul` is the code's multiplication rule; `fp2_bijective` is "`{1, U}` is an `F`-basis of `K`", from
  `[K : F] = 2` and `κ` a non-square; `adjoinRoot_finrank` gives such a `K`, `F[u]/(u² − κ)`); `mOpenView_law_eq_fp2`
  states the hypothesis as an equality of `V` in `K`; `fp2_uniform`: a pair of uniform base-field values read as
  `c0 + U·c1` is uniform in `K` (the `u = u_re + U·u_im` reading of the proximity mask).

Hypotheses taken from the code: `m = 512 > 0` and `512 ≠ 0` in `F`; at most `Q = 256` distinct sampled points
(`MASK_Q` samples with replacement), outside `G_512` (`7^4096 ≠ 1`); the pads of a-row `(s, k)` sit at distinct
positions where the weights of mask `s` vanish (`L_s + 256 ≤ 512`, weights only on `0..L_s`); one opening.

NOT covered: the challenges' dependence on the transcript (Fiat–Shamir), and the salted Merkle layer (separate).
-/
import ZK60Formal.HidingM
import ZK60Formal.HidingOpening
import ZK60Formal.HidingSumcheckJoint
import Mathlib.RingTheory.AdjoinRoot
import Mathlib.FieldTheory.KummerPolynomial

namespace ZK60.Hiding

open scoped ENNReal
open Polynomial

section MOpen

variable {F : Type} [Field F]

/-! ## Coefficient vectors and the zero-sum blinding row -/

/-- A coefficient vector of length `n` read as the polynomial `Σ_{i<n} c_i X^i` (how `encode_coeffs_coset` reads `b`,
`u`, `q'` and `prox`: coefficient `i` is scaled by `h^i` and NTT-ed, i.e. the polynomial is evaluated on `h·G_N`). -/
noncomputable def cpoly {n : ℕ} (c : Fin n → F) : F[X] := ∑ i : Fin n, C (c i) * X ^ (i : ℕ)

/-- Reading coefficient vectors as polynomials is additive. -/
theorem cpoly_add {n : ℕ} (a b : Fin n → F) : cpoly (a + b) = cpoly a + cpoly b := by
  simp only [cpoly, Pi.add_apply, C_add, add_mul, Finset.sum_add_distrib]

/-- A polynomial of degree `< n` is the polynomial of its first `n` coefficients. -/
theorem cpoly_coeff {n : ℕ} (P : F[X]) (hP : P.natDegree < n) : cpoly (fun i : Fin n => P.coeff i) = P := by
  rw [cpoly, Fin.sum_univ_eq_sum_range (fun i => C (P.coeff i) * X ^ i) n]
  exact (as_sum_range_C_mul_X_pow' P hP).symm

/-- The code's blinding coefficients (`mask_commit`: `b = rng.fp_vec(2m); b[m] = -b[0]`): `2m` uniform values, with the
value at position `m` overwritten by `−b_0`. -/
def bfix {m : ℕ} (hm : 0 < m) (b : Fin (2 * m) → F) : Fin (2 * m) → F :=
  fun i => if (i : ℕ) = m then -b ⟨0, by omega⟩ else b i

/-- The overwrite is additive. -/
theorem bfix_add {m : ℕ} (hm : 0 < m) (a b : Fin (2 * m) → F) : bfix hm (a + b) = bfix hm a + bfix hm b := by
  funext i
  simp only [bfix, Pi.add_apply]
  split_ifs <;> ring

/-- A coefficient vector that already satisfies `c_m = −c_0` is unchanged by the overwrite. -/
theorem bfix_of_zeroSum {m : ℕ} (hm : 0 < m) (c : Fin (2 * m) → F) (hc : c ⟨0, by omega⟩ + c ⟨m, by omega⟩ = 0) :
    bfix hm c = c := by
  funext i
  simp only [bfix]
  split_ifs with h
  · have hi : i = ⟨m, by omega⟩ := Fin.ext h
    rw [hi]
    linear_combination -hc
  · rfl

/-! ## The public data and the coins of one `M` opening -/

/-- The public data of one `M` opening at fixed challenges. `r` masks (sumchecks), message size `m`, `Q` pads per
a-row, `q` sampled columns.
* `y`: the message domain (`G_512` in the NTT's natural order: position `i` is `ω_512^i`);
* `π s`: the pad positions of both a-rows of mask `s` (`L_s + l`);
* `Wre s`, `Wim s`: the components of the θ-combined functional weights of mask `s` over the message positions
  (`combined_weights`; zero beyond `L_s`);
* `ρa s k`, `ρb k`: the proximity weights `(c0, c1)` of a-row `(s, k)` and of `b_k` (`challenge_fp2_vec`);
* `x t`: the point of sampled column `t` (`h·ω_N^{idx_t}`; repeats allowed). -/
structure MOpenPub (F : Type) (m r Q q : ℕ) where
  y : Fin m → F
  π : Fin r → Fin Q → Fin m
  Wre : Fin r → Fin m → F
  Wim : Fin r → Fin m → F
  ρa : Fin r → Bool → F × F
  ρb : Bool → F × F
  x : Fin q → F

/-- The prover's coins of `M` beyond the mask coefficients: the pads of every a-row, the `2m` drawn coefficients of
`b_re`, `b_im` (before the overwrite) and the `2m` coefficients of `u_re`, `u_im`, all independent and uniform (the
draw order of `mask_commit`). Index `true` is the real part, `false` the imaginary part. -/
abbrev MCoins (F : Type) (m r Q : ℕ) :=
  (Fin r → Bool → Fin Q → F) × (Bool → Fin (2 * m) → F) × (Bool → Fin (2 * m) → F)

variable {m r Q q : ℕ}

/-- The committed a-row `(s, k)`: the interpolant on the message domain of the fixed message `w s k` (the
coefficients and the zero positions) plus the pads at their positions. -/
noncomputable def mA (P : MOpenPub F m r Q q) (w : Fin r → Bool → Fin m → F) (G : Fin r → Bool → Fin Q → F)
    (s : Fin r) (k : Bool) : F[X] :=
  Lagrange.interpolate Finset.univ P.y (w s k + placePads (P.π s) (G s k))

/-- The real part of mask `s`'s weight polynomial `p_{W_s}` (`weight_polys`, the inverse NTT of the weights). -/
noncomputable def mWre (P : MOpenPub F m r Q q) (s : Fin r) : F[X] := Lagrange.interpolate Finset.univ P.y (P.Wre s)

/-- The imaginary part of mask `s`'s weight polynomial. -/
noncomputable def mWim (P : MOpenPub F m r Q q) (s : Fin r) : F[X] := Lagrange.interpolate Finset.univ P.y (P.Wim s)

/-- The committed blinding row `b_k`. -/
noncomputable def mB (hm : 0 < m) (b : Bool → Fin (2 * m) → F) (k : Bool) : F[X] := cpoly (bfix hm (b k))

/-- The committed proximity-mask row `u_k`. -/
noncomputable def mU (u : Bool → Fin (2 * m) → F) (k : Bool) : F[X] := cpoly (u k)

/-- The real part of the clear product polynomial `q'` (`mask_open`: `q_re = b_re + Σ_s (rr + 7·ii)`). -/
noncomputable def mQre (κ : F) (P : MOpenPub F m r Q q) (hm : 0 < m) (w : Fin r → Bool → Fin m → F)
    (c : MCoins F m r Q) : F[X] :=
  mB hm c.2.1 true + ∑ s, (mA P w c.1 s true * mWre P s + C κ * (mA P w c.1 s false * mWim P s))

/-- The imaginary part of `q'` (`q_im = b_im + Σ_s (ri + ir)`). -/
noncomputable def mQim (P : MOpenPub F m r Q q) (hm : 0 < m) (w : Fin r → Bool → Fin m → F)
    (c : MCoins F m r Q) : F[X] :=
  mB hm c.2.1 false + ∑ s, (mA P w c.1 s true * mWim P s + mA P w c.1 s false * mWre P s)

/-- The real part of the proximity vector (`prox = u + Σ_rows r_row.mul_base(row)`, component `c0`). -/
noncomputable def mPre (P : MOpenPub F m r Q q) (hm : 0 < m) (w : Fin r → Bool → Fin m → F)
    (c : MCoins F m r Q) : F[X] :=
  mU c.2.2 true + ∑ s, ∑ k, C (P.ρa s k).1 * mA P w c.1 s k + ∑ k, C (P.ρb k).1 * mB hm c.2.1 k

/-- The imaginary part of the proximity vector (component `c1`). -/
noncomputable def mPim (P : MOpenPub F m r Q q) (hm : 0 < m) (w : Fin r → Bool → Fin m → F)
    (c : MCoins F m r Q) : F[X] :=
  mU c.2.2 false + ∑ s, ∑ k, C (P.ρa s k).2 * mA P w c.1 s k + ∑ k, C (P.ρb k).2 * mB hm c.2.1 k

/-- What the verifier sees of `M`'s opening: `q'` and `prox` as `2m` coefficient pairs `(c0, c1)` (`MaskOpening.q`,
`.prox`), and at each sampled column every row's value (`MaskOpening.columns`: the a-rows, then `b_re`, `b_im`, `u_re`,
`u_im`). -/
abbrev MView (F : Type) (m r q : ℕ) :=
  (Fin (2 * m) → F × F) × (Fin (2 * m) → F × F) × (Fin r → Bool → Fin q → F) × (Bool → Fin q → F)
    × (Bool → Fin q → F)

/-- The view of one `M` opening, for mask-coefficient messages `w` and coins `c`. -/
noncomputable def mOpenView (κ : F) (P : MOpenPub F m r Q q) (hm : 0 < m) (w : Fin r → Bool → Fin m → F)
    (c : MCoins F m r Q) : MView F m r q :=
  ( fun i => ((mQre κ P hm w c).coeff i, (mQim P hm w c).coeff i),
    fun i => ((mPre P hm w c).coeff i, (mPim P hm w c).coeff i),
    fun s k t => (mA P w c.1 s k).eval (P.x t),
    fun k t => (mB hm c.2.1 k).eval (P.x t),
    fun k t => (mU c.2.2 k).eval (P.x t) )

/-- The real part of the θ-combined functional value `V = Σ_s ⟨a_s, W_s⟩` (Fp2 products in components, `U² = κ`). -/
def mValRe (κ : F) (P : MOpenPub F m r Q q) (w : Fin r → Bool → Fin m → F) : F :=
  ∑ s, ∑ i, (w s true i * P.Wre s i + κ * (w s false i * P.Wim s i))

/-- The imaginary part of the functional value. -/
def mValIm (P : MOpenPub F m r Q q) (w : Fin r → Bool → Fin m → F) : F :=
  ∑ s, ∑ i, (w s true i * P.Wim s i + w s false i * P.Wre s i)

/-! ## Facts about the message domain -/

/-- An interpolant on `m` distinct nodes has degree `< m`. -/
theorem natDegree_interpolate_lt (hm : 0 < m) (y : Fin m → F) (hy : Function.Injective y) (v : Fin m → F) :
    (Lagrange.interpolate Finset.univ y v).natDegree < m := by
  have hdeg := Lagrange.degree_interpolate_lt (s := (Finset.univ : Finset (Fin m))) v hy.injOn
  by_cases h0 : Lagrange.interpolate Finset.univ y v = 0
  · rw [h0, natDegree_zero]
    exact hm
  · rw [natDegree_lt_iff_degree_lt h0]
    simpa using hdeg

/-- **The power sums of the message domain.** The hypothesis the zero-sum argument uses: `Σ_i y_i^j` is `m` for
`j ∈ {0, m}` and `0` for every other `j < 2m` (true for the `m`-th roots of unity, `rootsOfUnity_powSum`). Then the
sum over the domain of a polynomial of degree `< 2m` is `m·(c_0 + c_m)`: the verifier's check `512·(q'_0 + q'_512) = V`
is a check of `Σ_{x ∈ G_512} q'(x)`. -/
theorem sum_eval_nodes (hm : 0 < m) (y : Fin m → F)
    (hsum : ∀ j < 2 * m, ∑ i, y i ^ j = if j = 0 ∨ j = m then (m : F) else 0)
    (P : F[X]) (hP : P.natDegree < 2 * m) :
    ∑ i, P.eval (y i) = (m : F) * (P.coeff 0 + P.coeff m) := by
  have h1 : ∀ i, P.eval (y i) = ∑ j ∈ Finset.range (2 * m), P.coeff j * y i ^ j :=
    fun i => eval_eq_sum_range' hP (y i)
  simp_rw [h1]
  rw [Finset.sum_comm]
  have h2 : ∀ j ∈ Finset.range (2 * m), ∑ i, P.coeff j * y i ^ j
      = if j = 0 ∨ j = m then P.coeff j * (m : F) else 0 := by
    intro j hj
    rw [← Finset.mul_sum, hsum j (Finset.mem_range.mp hj)]
    split_ifs <;> simp
  rw [Finset.sum_congr rfl h2, Finset.sum_ite, Finset.sum_const_zero, add_zero]
  have hfilt : (Finset.range (2 * m)).filter (fun j => j = 0 ∨ j = m) = {0, m} := by
    ext j
    simp only [Finset.mem_filter, Finset.mem_range, Finset.mem_insert, Finset.mem_singleton]
    omega
  have hne : (0 : ℕ) ∉ ({m} : Finset ℕ) := by simp; omega
  rw [hfilt, Finset.sum_insert hne, Finset.sum_singleton]
  ring

/-- **The `m`-th roots of unity in natural order have the power sums of `sum_eval_nodes`.** -/
theorem rootsOfUnity_powSum {ω : F} (hω : IsPrimitiveRoot ω m) (j : ℕ) (hj : j < 2 * m) :
    ∑ i : Fin m, (ω ^ (i : ℕ)) ^ j = if j = 0 ∨ j = m then (m : F) else 0 := by
  have hs : ∑ i : Fin m, (ω ^ (i : ℕ)) ^ j = ∑ i ∈ Finset.range m, (ω ^ j) ^ i := by
    rw [Fin.sum_univ_eq_sum_range (fun i => (ω ^ i) ^ j) m]
    refine Finset.sum_congr rfl (fun i _ => ?_)
    rw [← pow_mul, ← pow_mul, mul_comm]
  rw [hs]
  by_cases h : j = 0 ∨ j = m
  · have h1 : ω ^ j = 1 := by
      rcases h with h | h
      · rw [h, pow_zero]
      · rw [h]
        exact hω.pow_eq_one
    simp [h1, h]
  · have hne : ω ^ j ≠ 1 := by
      intro h1
      rw [hω.pow_eq_one_iff_dvd] at h1
      obtain ⟨c, hc⟩ := h1
      apply h
      rcases c with _ | _ | c
      · left
        simpa using hc
      · right
        simpa using hc
      · exfalso
        have : j ≥ 2 * m := by rw [hc]; nlinarith
        omega
    rw [geom_sum_eq hne, ← pow_mul, mul_comm, pow_mul, hω.pow_eq_one, one_pow, sub_self, zero_div]
    simp [h]

/-- The pads meet the weights only at the pad positions: `Σ_i pads_i · W_i = Σ_l g_l · W_{π l}`. -/
theorem sum_placePads_mul {Q' : ℕ} (π : Fin Q' → Fin m) (g : Fin Q' → F) (W : Fin m → F) :
    ∑ i, placePads π g i * W i = ∑ l, g l * W (π l) := by
  classical
  simp only [placePads, Finset.sum_mul, ite_mul, zero_mul]
  rw [Finset.sum_comm]
  refine Finset.sum_congr rfl (fun l _ => ?_)
  rw [Finset.sum_ite_eq]
  simp

/-- At the nodes, the product of two interpolants is the product of their values. -/
theorem sum_interp_mul_nodes (y : Fin m → F) (hy : Function.Injective y) (a b : Fin m → F) :
    ∑ i, (Lagrange.interpolate Finset.univ y a * Lagrange.interpolate Finset.univ y b).eval (y i)
      = ∑ i, a i * b i := by
  refine Finset.sum_congr rfl (fun i _ => ?_)
  rw [eval_mul, Lagrange.eval_interpolate_at_node a hy.injOn (Finset.mem_univ i),
    Lagrange.eval_interpolate_at_node b hy.injOn (Finset.mem_univ i)]

/-! ## The pad block reaches every target at the sampled points -/

/-- **The a-row pads absorb any change of message at the sampled points.** With at most `Q` distinct sampled
indices, distinct points outside the message domain and pads at distinct positions, for every message change `v` there
are pads `g` with `interp(v − pads(g))` zero at every sampled point (`mPadBlock_surjective` on the distinct points). -/
theorem mPad_reach [Fintype F] {Q' N : ℕ} (y : Fin m → F) (hy : Function.Injective y) (π : Fin Q' → Fin m)
    (hπ : Function.Injective π) (X : Fin N → F) (hX : Function.Injective X) (hXy : ∀ j i, X j ≠ y i)
    (smp : Fin q → Fin N) (hs : (Finset.univ.image smp).card ≤ Q') (v : Fin m → F) :
    ∃ g : Fin Q' → F, ∀ t, (Lagrange.interpolate Finset.univ y (v - placePads π g)).eval (X (smp t)) = 0 := by
  have hinj : Function.Injective (X ∘ distinctPoints smp) := hX.comp (distinctPoints_injective smp)
  obtain ⟨g, hg⟩ := mPadBlock_surjective y hy π hπ hs (X ∘ distinctPoints smp) hinj (fun j i => hXy _ i)
    (mOpened y (X ∘ distinctPoints smp) v)
  refine ⟨g, fun t => ?_⟩
  have h1 := congrFun hg (distinctIndex smp t)
  simp only [mOpened, Function.comp_apply, distinctPoints_index] at h1
  rw [map_sub, eval_sub, h1, sub_self]

/-! ## The coin shift -/

/-- Degree bookkeeping: a product of two polynomials of degree `< m` has degree `≤ 2m − 2`. -/
theorem natDegree_mul_le_of_lt {p p' : F[X]} (hp : p.natDegree < m) (hp' : p'.natDegree < m) :
    (p * p').natDegree ≤ 2 * m - 2 := by
  have := natDegree_mul_le (p := p) (q := p')
  omega

/-- **The coin shift of `M`'s opening.** If two mask-coefficient families `w`, `w'` have the same functional value
(both components), there is a FIXED translate `Δ` of the coins with `view(w, c) = view(w', c + Δ)` for every `c`. -/
theorem mOpenView_shift (κ : F) (P : MOpenPub F m r Q q) (hm : 0 < m) (hmF : (m : F) ≠ 0)
    (hy : Function.Injective P.y)
    (hsum : ∀ j < 2 * m, ∑ i, P.y i ^ j = if j = 0 ∨ j = m then (m : F) else 0)
    (hW : ∀ s l, P.Wre s (P.π s l) = 0 ∧ P.Wim s (P.π s l) = 0)
    (hpad : ∀ s (v : Fin m → F), ∃ g : Fin Q → F,
      ∀ t, (Lagrange.interpolate Finset.univ P.y (v - placePads (P.π s) g)).eval (P.x t) = 0)
    (w w' : Fin r → Bool → Fin m → F) (hre : mValRe κ P w = mValRe κ P w') (him : mValIm P w = mValIm P w') :
    ∃ Δ : MCoins F m r Q, ∀ c, mOpenView κ P hm w c = mOpenView κ P hm w' (c + Δ) := by
  classical
  -- Step 1: pad shifts, and the difference rows `δ` they leave, zero at every sampled point.
  choose g hg using fun s k => hpad s (w s k - w' s k)
  set δ : Fin r → Bool → F[X] := fun s k =>
    Lagrange.interpolate Finset.univ P.y (w s k - w' s k - placePads (P.π s) (g s k)) with hδdef
  have hδx : ∀ s k t, (δ s k).eval (P.x t) = 0 := fun s k t => hg s k t
  have hδdeg : ∀ s k, (δ s k).natDegree < m := fun s k => natDegree_interpolate_lt hm P.y hy _
  have hWre : ∀ s, (mWre P s).natDegree < m := fun s => natDegree_interpolate_lt hm P.y hy _
  have hWim : ∀ s, (mWim P s).natDegree < m := fun s => natDegree_interpolate_lt hm P.y hy _
  have hA : ∀ G s k, mA P w G s k = mA P w' (G + g) s k + δ s k := by
    intro G s k
    simp only [mA, hδdef, Pi.add_apply, placePads_add, ← map_add]
    congr 1
    funext i
    simp only [Pi.add_apply, Pi.sub_apply]
    ring
  -- Step 2: the change of `Σ p_a p_W`, absorbed by `b`.
  set Dre : F[X] := ∑ s, (δ s true * mWre P s + C κ * (δ s false * mWim P s)) with hDre
  set Dim : F[X] := ∑ s, (δ s true * mWim P s + δ s false * mWre P s) with hDim
  have hDre_deg : Dre.natDegree < 2 * m := by
    have : Dre.natDegree ≤ 2 * m - 2 := by
      refine natDegree_sum_le_of_forall_le _ _ (fun s _ => ?_)
      refine (natDegree_add_le _ _).trans (max_le ?_ ?_)
      · exact natDegree_mul_le_of_lt (hδdeg s true) (hWre s)
      · exact (natDegree_C_mul_le _ _).trans (natDegree_mul_le_of_lt (hδdeg s false) (hWim s))
    omega
  have hDim_deg : Dim.natDegree < 2 * m := by
    have : Dim.natDegree ≤ 2 * m - 2 := by
      refine natDegree_sum_le_of_forall_le _ _ (fun s _ => ?_)
      refine (natDegree_add_le _ _).trans (max_le ?_ ?_)
      · exact natDegree_mul_le_of_lt (hδdeg s true) (hWim s)
      · exact natDegree_mul_le_of_lt (hδdeg s false) (hWre s)
    omega
  -- the values of `δ` at the nodes: the coefficient change, minus the pads
  have hδnode : ∀ s k i, (δ s k).eval (P.y i) = w s k i - w' s k i - placePads (P.π s) (g s k) i := by
    intro s k i
    simp only [hδdef]
    rw [Lagrange.eval_interpolate_at_node _ hy.injOn (Finset.mem_univ i)]
    simp only [Pi.sub_apply]
  have hpadW : ∀ s k, (∑ i, placePads (P.π s) (g s k) i * P.Wre s i = 0)
      ∧ ∑ i, placePads (P.π s) (g s k) i * P.Wim s i = 0 := by
    intro s k
    rw [sum_placePads_mul, sum_placePads_mul]
    constructor
    · exact Finset.sum_eq_zero (fun l _ => by rw [(hW s l).1, mul_zero])
    · exact Finset.sum_eq_zero (fun l _ => by rw [(hW s l).2, mul_zero])
  have hWnode : ∀ s i, (mWre P s).eval (P.y i) = P.Wre s i ∧ (mWim P s).eval (P.y i) = P.Wim s i := by
    intro s i
    exact ⟨Lagrange.eval_interpolate_at_node _ hy.injOn (Finset.mem_univ i),
      Lagrange.eval_interpolate_at_node _ hy.injOn (Finset.mem_univ i)⟩
  -- the zero sums: `Σ_{G_m} D = V(w) − V(w') = 0`
  have hDre_sum : Dre.coeff 0 + Dre.coeff m = 0 := by
    have hs := sum_eval_nodes hm P.y hsum Dre hDre_deg
    have hval : ∑ i, Dre.eval (P.y i) = mValRe κ P w - mValRe κ P w' := by
      simp only [hDre, eval_finsetSum, eval_add, eval_mul, eval_C, hδnode, (hWnode _ _).1, (hWnode _ _).2]
      rw [Finset.sum_comm]
      simp only [mValRe, ← Finset.sum_sub_distrib]
      refine Finset.sum_congr rfl (fun s _ => ?_)
      have h1 := (hpadW s true).1
      have h2 := (hpadW s false).2
      have e : ∀ i, (w s true i - w' s true i - placePads (P.π s) (g s true) i) * P.Wre s i
            + κ * ((w s false i - w' s false i - placePads (P.π s) (g s false) i) * P.Wim s i)
          = ((w s true i * P.Wre s i + κ * (w s false i * P.Wim s i))
              - (w' s true i * P.Wre s i + κ * (w' s false i * P.Wim s i)))
            - (placePads (P.π s) (g s true) i * P.Wre s i
              + κ * (placePads (P.π s) (g s false) i * P.Wim s i)) := fun i => by ring
      rw [Finset.sum_congr rfl (fun i _ => e i), Finset.sum_sub_distrib, Finset.sum_add_distrib, h1,
        ← Finset.mul_sum, h2, mul_zero, add_zero, sub_zero]
    rw [hval, hre, sub_self] at hs
    exact (mul_eq_zero.mp hs.symm).resolve_left hmF
  have hDim_sum : Dim.coeff 0 + Dim.coeff m = 0 := by
    have hs := sum_eval_nodes hm P.y hsum Dim hDim_deg
    have hval : ∑ i, Dim.eval (P.y i) = mValIm P w - mValIm P w' := by
      simp only [hDim, eval_finsetSum, eval_add, eval_mul, hδnode, (hWnode _ _).1, (hWnode _ _).2]
      rw [Finset.sum_comm]
      simp only [mValIm, ← Finset.sum_sub_distrib]
      refine Finset.sum_congr rfl (fun s _ => ?_)
      have h1 := (hpadW s true).2
      have h2 := (hpadW s false).1
      have e : ∀ i, (w s true i - w' s true i - placePads (P.π s) (g s true) i) * P.Wim s i
            + (w s false i - w' s false i - placePads (P.π s) (g s false) i) * P.Wre s i
          = ((w s true i * P.Wim s i + w s false i * P.Wre s i)
              - (w' s true i * P.Wim s i + w' s false i * P.Wre s i))
            - (placePads (P.π s) (g s true) i * P.Wim s i
              + placePads (P.π s) (g s false) i * P.Wre s i) := fun i => by ring
      rw [Finset.sum_congr rfl (fun i _ => e i), Finset.sum_sub_distrib, Finset.sum_add_distrib, h1, h2,
        add_zero, sub_zero]
    rw [hval, him, sub_self] at hs
    exact (mul_eq_zero.mp hs.symm).resolve_left hmF
  set D : Bool → F[X] := fun k => cond k Dre Dim with hDdef
  have hDdeg : ∀ k, (D k).natDegree < 2 * m := by
    intro k
    cases k
    · exact hDim_deg
    · exact hDre_deg
  have hDsum : ∀ k, (D k).coeff 0 + (D k).coeff m = 0 := by
    intro k
    cases k
    · exact hDim_sum
    · exact hDre_sum
  have hDx : ∀ k t, (D k).eval (P.x t) = 0 := by
    intro k t
    cases k
    · simp [hDdef, hDim, eval_finsetSum, hδx]
    · simp [hDdef, hDre, eval_finsetSum, hδx]
  set Δb : Bool → Fin (2 * m) → F := fun k i => (D k).coeff i with hΔb
  have hB : ∀ b k, mB hm (b + Δb) k = mB hm b k + D k := by
    intro b k
    have hfix : bfix hm (Δb k) = Δb k := bfix_of_zeroSum hm _ (by simpa [hΔb] using hDsum k)
    simp only [mB, Pi.add_apply, bfix_add, hfix, cpoly_add]
    rw [hΔb, cpoly_coeff _ (hDdeg k)]
  have hBdeg : ∀ k, (D k).natDegree ≤ 2 * m - 2 := by
    intro k
    cases k
    · refine natDegree_sum_le_of_forall_le _ _ (fun s _ => ?_)
      refine (natDegree_add_le _ _).trans (max_le ?_ ?_)
      · exact natDegree_mul_le_of_lt (hδdeg s true) (hWim s)
      · exact natDegree_mul_le_of_lt (hδdeg s false) (hWre s)
    · refine natDegree_sum_le_of_forall_le _ _ (fun s _ => ?_)
      refine (natDegree_add_le _ _).trans (max_le ?_ ?_)
      · exact natDegree_mul_le_of_lt (hδdeg s true) (hWre s)
      · exact (natDegree_C_mul_le _ _).trans (natDegree_mul_le_of_lt (hδdeg s false) (hWim s))
  -- Step 3: the change of the proximity vector, absorbed by `u`.
  set E : Bool → F[X] := fun k =>
    (∑ s, ∑ j, C ((fun p : F × F => cond k p.1 p.2) (P.ρa s j)) * δ s j)
      - ∑ j, C ((fun p : F × F => cond k p.1 p.2) (P.ρb j)) * D j with hEdef
  have hEdeg : ∀ k, (E k).natDegree < 2 * m := by
    intro k
    have : (E k).natDegree ≤ 2 * m - 2 := by
      refine (natDegree_sub_le _ _).trans (max_le ?_ ?_)
      · refine natDegree_sum_le_of_forall_le _ _ (fun s _ => ?_)
        refine natDegree_sum_le_of_forall_le _ _ (fun j _ => ?_)
        refine (natDegree_C_mul_le _ _).trans ?_
        have := hδdeg s j
        omega
      · refine natDegree_sum_le_of_forall_le _ _ (fun j _ => ?_)
        exact (natDegree_C_mul_le _ _).trans (hBdeg j)
    omega
  have hEx : ∀ k t, (E k).eval (P.x t) = 0 := by
    intro k t
    simp [hEdef, eval_finsetSum, hδx, hDx]
  set Δu : Bool → Fin (2 * m) → F := fun k i => (E k).coeff i with hΔu
  have hU : ∀ u k, mU (u + Δu) k = mU u k + E k := by
    intro u k
    simp only [mU, Pi.add_apply, cpoly_add]
    rw [hΔu, cpoly_coeff _ (hEdeg k)]
  -- Step 4: the view at `w` equals the view at `w'` with shifted coins.
  refine ⟨(g, Δb, Δu), fun c => ?_⟩
  obtain ⟨G, b, u⟩ := c
  have hsplit2 : ∀ (a a' d d' W W' : F[X]), (a + d) * W + C κ * ((a' + d') * W')
      = (a * W + C κ * (a' * W')) + (d * W + C κ * (d' * W')) := fun _ _ _ _ _ _ => by ring
  have hsplit3 : ∀ (a a' d d' W W' : F[X]), (a + d) * W + (a' + d') * W' = (a * W + a' * W') + (d * W + d' * W') :=
    fun _ _ _ _ _ _ => by ring
  have hQre : mQre κ P hm w (G, b, u) = mQre κ P hm w' ((G, b, u) + (g, Δb, Δu)) := by
    simp only [mQre, Prod.mk_add_mk, hA G, hB b, hsplit2, Finset.sum_add_distrib]
    simp only [hDdef, Bool.cond_true, hDre, Finset.sum_add_distrib]
    ring
  have hQim : mQim P hm w (G, b, u) = mQim P hm w' ((G, b, u) + (g, Δb, Δu)) := by
    simp only [mQim, Prod.mk_add_mk, hA G, hB b, hsplit3, Finset.sum_add_distrib]
    simp only [hDdef, Bool.cond_false, hDim, Finset.sum_add_distrib]
    ring
  have hP : ∀ k : Bool, mU u k + ∑ s, ∑ j, C ((fun p : F × F => cond k p.1 p.2) (P.ρa s j)) * mA P w G s j
        + ∑ j, C ((fun p : F × F => cond k p.1 p.2) (P.ρb j)) * mB hm b j
      = mU (u + Δu) k + ∑ s, ∑ j, C ((fun p : F × F => cond k p.1 p.2) (P.ρa s j)) * mA P w' (G + g) s j
        + ∑ j, C ((fun p : F × F => cond k p.1 p.2) (P.ρb j)) * mB hm (b + Δb) j := by
    intro k
    simp only [hU u k, hB b, hA G, mul_add, Finset.sum_add_distrib, hEdef]
    ring
  have hPre : mPre P hm w (G, b, u) = mPre P hm w' ((G, b, u) + (g, Δb, Δu)) := by
    simpa [mPre] using hP true
  have hPim : mPim P hm w (G, b, u) = mPim P hm w' ((G, b, u) + (g, Δb, Δu)) := by
    simpa [mPim] using hP false
  simp only [mOpenView, Prod.mk.injEq]
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · rw [hQre, hQim]
  · rw [hPre, hPim]
  · funext s k t
    simp only [Prod.mk_add_mk, hA G s k, eval_add, hδx, add_zero]
  · funext k t
    simp only [Prod.mk_add_mk, hB b k, eval_add, hDx, add_zero]
  · funext k t
    simp only [Prod.mk_add_mk, hU u k, eval_add, hEx, add_zero]

/-- **`M`'s whole opening view depends on the mask coefficients only through the functional value.** Fix the
challenges (θ, through the weights; the proximity weights; the sampled points). Suppose: the message domain has `m`
distinct points with the power sums of the `m`-th roots of unity and `m ≠ 0` in `F`; the weights of each mask vanish at
its pad positions; and the pad block reaches every target at the sampled points (`mPad_reach`: at most `Q` distinct
sampled points, outside the message domain). Then for any two mask-coefficient families `w`, `w'` with the same value
`V` (both components), the joint law of (`q'`, the proximity vector, every opened column of every row of `M`) over
uniform pads, `b` and `u` is the same. For privacy: `M`'s opening reveals nothing about the CFS masks beyond `V`, which
the verifier computes itself from the rest of the transcript (the `g(ρ)`'s and the `Γ`'s). -/
theorem mOpenView_law_eq [Fintype F] (κ : F) (P : MOpenPub F m r Q q) (hm : 0 < m) (hmF : (m : F) ≠ 0)
    (hy : Function.Injective P.y)
    (hsum : ∀ j < 2 * m, ∑ i, P.y i ^ j = if j = 0 ∨ j = m then (m : F) else 0)
    (hW : ∀ s l, P.Wre s (P.π s l) = 0 ∧ P.Wim s (P.π s l) = 0)
    (hpad : ∀ s (v : Fin m → F), ∃ g : Fin Q → F,
      ∀ t, (Lagrange.interpolate Finset.univ P.y (v - placePads (P.π s) g)).eval (P.x t) = 0)
    (w w' : Fin r → Bool → Fin m → F) (hre : mValRe κ P w = mValRe κ P w') (him : mValIm P w = mValIm P w') :
    (PMF.uniformOfFintype (MCoins F m r Q)).map (mOpenView κ P hm w)
      = (PMF.uniformOfFintype (MCoins F m r Q)).map (mOpenView κ P hm w') := by
  obtain ⟨Δ, hΔ⟩ := mOpenView_shift κ P hm hmF hy hsum hW hpad w w' hre him
  have hfun : mOpenView κ P hm w = (mOpenView κ P hm w') ∘ (fun c => c + Δ) := funext hΔ
  rw [hfun, ← PMF.map_comp, map_uniform_add_right]

/-- **The joint form, for composition with the masked sumcheck.** Let `ω` be other coins of the proof (for example the
CFS mask coefficients themselves), `X ω` the rest of the view (for example every slot's masked rounds, totals and
`g(ρ)`), `w ω` the mask-coefficient messages, and `w'` any choice computed from the rest of the view with the same
functional value. Then `(X ω, M's view at w ω)` and `(X ω, M's view at w' (X ω))` have the same joint law. So `M`'s
opening adds nothing beyond what `X` already shows. -/
theorem mOpenView_joint_law_eq [Fintype F] (κ : F) (P : MOpenPub F m r Q q) (hm : 0 < m) (hmF : (m : F) ≠ 0)
    (hy : Function.Injective P.y)
    (hsum : ∀ j < 2 * m, ∑ i, P.y i ^ j = if j = 0 ∨ j = m then (m : F) else 0)
    (hW : ∀ s l, P.Wre s (P.π s l) = 0 ∧ P.Wim s (P.π s l) = 0)
    (hpad : ∀ s (v : Fin m → F), ∃ g : Fin Q → F,
      ∀ t, (Lagrange.interpolate Finset.univ P.y (v - placePads (P.π s) g)).eval (P.x t) = 0)
    {Ω β : Type} [Fintype Ω] [Nonempty Ω] (X : Ω → β) (w : Ω → Fin r → Bool → Fin m → F)
    (w' : β → Fin r → Bool → Fin m → F)
    (hV : ∀ ω, mValRe κ P (w ω) = mValRe κ P (w' (X ω)) ∧ mValIm P (w ω) = mValIm P (w' (X ω))) :
    (PMF.uniformOfFintype (Ω × MCoins F m r Q)).map (fun p => (X p.1, mOpenView κ P hm (w p.1) p.2))
      = (PMF.uniformOfFintype (Ω × MCoins F m r Q)).map
          (fun p => (X p.1, mOpenView κ P hm (w' (X p.1)) p.2)) := by
  choose Δ hΔ using fun ω => mOpenView_shift κ P hm hmF hy hsum hW hpad (w ω) (w' (X ω)) (hV ω).1 (hV ω).2
  have hfun : (fun p : Ω × MCoins F m r Q => (X p.1, mOpenView κ P hm (w p.1) p.2))
      = (fun p : Ω × MCoins F m r Q => (X p.1, mOpenView κ P hm (w' (X p.1)) p.2))
        ∘ (fun p => (p.1, p.2 + Δ p.1)) := by
    funext p
    simp only [Function.comp_apply, hΔ]
  rw [hfun, ← PMF.map_comp, map_uniform_shift_snd]

/-! ## The code's layout -/

/-- A vector over the first `L` positions, extended by zeros to `m` positions (the combined weights of a mask live on
its `L_s` coefficient positions only). -/
def zext {L m' : ℕ} (a : Fin L → F) : Fin m' → F := fun i => if h : (i : ℕ) < L then a ⟨i, h⟩ else 0

/-- An a-row message with zero pads is the coefficient vector extended by zeros. -/
theorem mRowMsg_zero_eq_zext {L Q' : ℕ} (coef : Fin L → F) :
    mRowMsg m coef (0 : Fin Q' → F) = zext coef := by
  funext i
  simp only [mRowMsg, zext, Pi.zero_apply]
  split_ifs <;> rfl

/-- Two zero-extended vectors have the inner product of the originals. -/
theorem sum_zext_mul {L : ℕ} (hLm : L ≤ m) (a b : Fin L → F) :
    ∑ i : Fin m, zext a i * zext b i = ∑ j, a j * b j := by
  symm
  refine Fintype.sum_of_injective (Fin.castLE hLm) (Fin.castLE_injective hLm) _ _ ?_ ?_
  · intro i hi
    have hiL : ¬ ((i : ℕ) < L) := by
      intro h
      exact hi ⟨⟨i, h⟩, Fin.ext (by simp)⟩
    simp [zext, hiL]
  · intro j
    simp [zext, j.isLt]

/-- The public data of `M`'s opening in the code's layout: message domain `y_i = ω^i` (`G_m`, natural order); the pads
of mask `s` at `L_s + l`; the combined weights `Wc` on the first `L_s` positions; sampled column `t` at `h·ω_N^{idx_t}`. -/
def codePub {N : ℕ} (L : Fin r → ℕ) (hLQ : ∀ s, L s + Q ≤ m) (ω : F)
    (Wcre Wcim : ∀ s, Fin (L s) → F) (ρa : Fin r → Bool → F × F) (ρb : Bool → F × F) (h ωN : F)
    (smp : Fin q → Fin N) : MOpenPub F m r Q q where
  y := fun i => ω ^ (i : ℕ)
  π := fun s => mPadPos (hLQ s)
  Wre := fun s => zext (Wcre s)
  Wim := fun s => zext (Wcim s)
  ρa := ρa
  ρb := ρb
  x := fun t => h * ωN ^ ((smp t : Fin N) : ℕ)

/-- **`M`'s opening hides the CFS masks beyond `V` (the protocol statement, the code's layout).** The message domain is
`G_m` (`ω` a primitive `m`-th root, `m ≠ 0` in `F`; `m = 512`); a-row `(s, k)` holds the `L_s` coefficients
`coef s k`, then `Q` pads, then zeros (`L_s + Q ≤ m`); the functional weights `Wc s` live on the first `L_s`
positions; the evaluation domain is `h·⟨ω_N⟩` with `ω_N` of order `N`, `m ∣ N`, `h ≠ 0`, `h^N ≠ 1` (`7`, `4096`);
the verifier samples `q ≤ Q` columns with replacement. Then for any two coefficient families with the same functional
value (`Σ_s Σ_j W_{s,j}·a_{s,j}` in components), the joint law of `M`'s whole opening view is the same. -/
theorem mask_open_law_eq [Fintype F] {N : ℕ} (κ : F) (L : Fin r → ℕ) (hLQ : ∀ s, L s + Q ≤ m) (hm : 0 < m)
    (hmF : (m : F) ≠ 0) {ω : F} (hω : IsPrimitiveRoot ω m) (hmN : m ∣ N) (h ωN : F) (hh0 : h ≠ 0)
    (hh : h ^ N ≠ 1) (hωN : IsPrimitiveRoot ωN N) (smp : Fin q → Fin N) (hq : q ≤ Q)
    (Wcre Wcim : ∀ s, Fin (L s) → F) (ρa : Fin r → Bool → F × F) (ρb : Bool → F × F)
    (coef coef' : ∀ s, Bool → Fin (L s) → F)
    (hre : ∑ s, ∑ j, (coef s true j * Wcre s j + κ * (coef s false j * Wcim s j))
      = ∑ s, ∑ j, (coef' s true j * Wcre s j + κ * (coef' s false j * Wcim s j)))
    (him : ∑ s, ∑ j, (coef s true j * Wcim s j + coef s false j * Wcre s j)
      = ∑ s, ∑ j, (coef' s true j * Wcim s j + coef' s false j * Wcre s j)) :
    (PMF.uniformOfFintype (MCoins F m r Q)).map
        (mOpenView κ (codePub L hLQ ω Wcre Wcim ρa ρb h ωN smp) hm
          (fun s k => mRowMsg m (coef s k) (0 : Fin Q → F)))
      = (PMF.uniformOfFintype (MCoins F m r Q)).map
        (mOpenView κ (codePub L hLQ ω Wcre Wcim ρa ρb h ωN smp) hm
          (fun s k => mRowMsg m (coef' s k) (0 : Fin Q → F))) := by
  set P := codePub (N := N) L hLQ ω Wcre Wcim ρa ρb h ωN smp with hPdef
  have hy : Function.Injective P.y := by
    intro i j hij
    exact Fin.ext (hω.pow_inj i.isLt j.isLt hij)
  have hsum : ∀ j < 2 * m, ∑ i, P.y i ^ j = if j = 0 ∨ j = m then (m : F) else 0 :=
    fun j hj => rootsOfUnity_powSum hω j hj
  have hW : ∀ s l, P.Wre s (P.π s l) = 0 ∧ P.Wim s (P.π s l) = 0 := by
    intro s l
    have : ¬ (((mPadPos (hLQ s) l : Fin m) : ℕ) < L s) := by simp [mPadPos]
    simp [hPdef, codePub, zext, this]
  have hX : Function.Injective (fun j : Fin N => h * ωN ^ (j : ℕ)) := coset_points_injective h ωN hh0 hωN
  have hXy : ∀ (j : Fin N) (i : Fin m), (fun j : Fin N => h * ωN ^ (j : ℕ)) j ≠ P.y i :=
    fun j i => coset_ne_root hmN h ωN hωN.pow_eq_one hh (P.y i) (by
      simp only [hPdef, codePub]
      rw [← pow_mul, mul_comm, pow_mul, hω.pow_eq_one, one_pow]) j
  have hpad : ∀ s (v : Fin m → F), ∃ g : Fin Q → F,
      ∀ t, (Lagrange.interpolate Finset.univ P.y (v - placePads (P.π s) g)).eval (P.x t) = 0 :=
    fun s v => mPad_reach P.y hy (P.π s) (mPadPos_injective (hLQ s)) _ hX hXy smp (card_image_le_of_le smp hq) v
  have hLm : ∀ s, L s ≤ m := fun s => by have := hLQ s; omega
  have hval : ∀ (cc : ∀ s, Bool → Fin (L s) → F),
      mValRe κ P (fun s k => mRowMsg m (cc s k) (0 : Fin Q → F))
        = ∑ s, ∑ j, (cc s true j * Wcre s j + κ * (cc s false j * Wcim s j))
      ∧ mValIm P (fun s k => mRowMsg m (cc s k) (0 : Fin Q → F))
        = ∑ s, ∑ j, (cc s true j * Wcim s j + cc s false j * Wcre s j) := by
    intro cc
    simp only [mValRe, mValIm, hPdef, codePub, mRowMsg_zero_eq_zext]
    constructor
    · refine Finset.sum_congr rfl (fun s _ => ?_)
      rw [Finset.sum_add_distrib, Finset.sum_add_distrib, ← Finset.mul_sum, ← Finset.mul_sum,
        sum_zext_mul (hLm s), sum_zext_mul (hLm s)]
    · refine Finset.sum_congr rfl (fun s _ => ?_)
      rw [Finset.sum_add_distrib, Finset.sum_add_distrib, sum_zext_mul (hLm s), sum_zext_mul (hLm s)]
  exact mOpenView_law_eq κ P hm hmF hy hsum hW hpad _ _
    (by rw [(hval coef).1, (hval coef').1, hre]) (by rw [(hval coef).2, (hval coef').2, him])

end MOpen

/-! ## Reading the code's Fp2 pairs in an extension field -/

section Fp2

variable {F K : Type} [Field F] [Field K] [Algebra F K]

/-- The code's Fp2 element `(c0, c1)` (`Fp2::new`) read in an extension `K` of `F`: `c0 + U·c1`. -/
def fp2 (U : K) (p : F × F) : K := algebraMap F K p.1 + U * algebraMap F K p.2

/-- The reading is additive (the code adds components). -/
theorem fp2_add (U : K) (a b : F × F) : fp2 U (a + b) = fp2 U a + fp2 U b := by
  simp only [fp2, Prod.fst_add, Prod.snd_add, map_add]
  ring

/-- **The code's multiplication rule is the product in `K`** when `U² = κ` (`Fp2::mul`, `κ = 7`):
`(a0 + U a1)(b0 + U b1) = (a0 b0 + κ a1 b1) + U (a0 b1 + a1 b0)`. -/
theorem fp2_mul (U : K) (κ : F) (hU : U ^ 2 = algebraMap F K κ) (a b : F × F) :
    fp2 U a * fp2 U b = fp2 U (a.1 * b.1 + κ * (a.2 * b.2), a.1 * b.2 + a.2 * b.1) := by
  simp only [fp2, map_add, map_mul]
  linear_combination (algebraMap F K a.2 * algebraMap F K b.2) * hU

/-- Scaling a base-field value: `(c0 + U c1)·x = c0 x + U c1 x` (`Fp2::mul_base`). -/
theorem fp2_mul_base (U : K) (p : F × F) (x : F) : fp2 U p * algebraMap F K x = fp2 U (p.1 * x, p.2 * x) := by
  simp only [fp2, map_mul]
  ring

/-- `U ∉ F` when `U² = κ` and `κ` is not a square in `F` (`7` is a non-residue mod the Goldilocks prime). -/
theorem not_mem_range_of_sq {U : K} {κ : F} (hU : U ^ 2 = algebraMap F K κ) (hκ : ∀ s : F, s * s ≠ κ) :
    U ∉ Set.range (algebraMap F K) := by
  rintro ⟨s, hs⟩
  apply hκ s
  apply (algebraMap F K).injective
  rw [map_mul, hs, ← pow_two, hU]

/-- **`1, U` are independent over `F`**: the reading `(c0, c1) ↦ c0 + U c1` is injective when `U ∉ F`. -/
theorem fp2_injective {U : K} (hU : U ∉ Set.range (algebraMap F K)) : Function.Injective (fp2 (F := F) U) := by
  intro a b hab
  have hz : algebraMap F K (a.1 - b.1) + U * algebraMap F K (a.2 - b.2) = 0 := by
    simp only [fp2] at hab
    simp only [map_sub]
    linear_combination hab
  by_cases hy : a.2 - b.2 = 0
  · rw [hy, map_zero, mul_zero, add_zero, map_eq_zero_iff _ (algebraMap F K).injective] at hz
    exact Prod.ext (sub_eq_zero.mp hz) (sub_eq_zero.mp hy)
  · exfalso
    apply hU
    refine ⟨-(a.1 - b.1) / (a.2 - b.2), ?_⟩
    have hy' : algebraMap F K (a.2 - b.2) ≠ 0 := (map_ne_zero_iff _ (algebraMap F K).injective).mpr hy
    rw [map_div₀, map_neg, div_eq_iff hy']
    linear_combination -hz

/-- **`1, U` span `K` when `[K : F] = 2`**: every element is `c0 + U c1`. -/
theorem fp2_surjective (hK : Module.finrank F K = 2) {U : K} (hU : U ∉ Set.range (algebraMap F K)) :
    Function.Surjective (fp2 (F := F) U) := by
  have hli : LinearIndependent F ![(1 : K), U] := by
    rw [LinearIndependent.pair_iff' one_ne_zero]
    intro s hs
    apply hU
    exact ⟨s, by rw [Algebra.smul_def, mul_one] at hs; exact hs⟩
  intro z
  obtain ⟨s, t, hst⟩ := pair_decomp hK hli z
  exact ⟨(s, t), by simp only [fp2]; linear_combination hst⟩

/-- **`{1, U}` is an `F`-basis of `K`** (the `u = u_re + U·u_im` reading): for `[K : F] = 2`, `U² = κ` and `κ` a
non-square in `F`, every element of `K` is `c0 + U c1` for exactly one pair `(c0, c1)`. -/
theorem fp2_bijective (hK : Module.finrank F K = 2) {U : K} {κ : F} (hU : U ^ 2 = algebraMap F K κ)
    (hκ : ∀ s : F, s * s ≠ κ) : Function.Bijective (fp2 (F := F) U) :=
  ⟨fp2_injective (not_mem_range_of_sq hU hκ), fp2_surjective hK (not_mem_range_of_sq hU hκ)⟩

/-- **The code's Fp2 is such a `K`.** For `κ` a non-square in `F`, `F[u]/(u² − κ)` has degree `2` over `F` and its
root squares to `κ` (the irreducibility of `u² − κ` is what makes it a field). -/
theorem adjoinRoot_finrank {κ : F} (hκ : ∀ s : F, s * s ≠ κ) :
    haveI : Fact (Irreducible (X ^ 2 - C κ : F[X])) :=
      ⟨X_pow_sub_C_irreducible_of_prime Nat.prime_two (fun b hb => hκ b (by rw [← hb]; ring))⟩
    Module.finrank F (AdjoinRoot (X ^ 2 - C κ : F[X])) = 2
      ∧ AdjoinRoot.root (X ^ 2 - C κ : F[X]) ^ 2 = algebraMap F (AdjoinRoot (X ^ 2 - C κ : F[X])) κ := by
  have hne : (X ^ 2 - C κ : F[X]) ≠ 0 := X_pow_sub_C_ne_zero (by norm_num) κ
  refine ⟨?_, ?_⟩
  · rw [(AdjoinRoot.powerBasis hne).finrank, AdjoinRoot.powerBasis_dim, natDegree_X_pow_sub_C]
  · have h := AdjoinRoot.eval₂_root (X ^ 2 - C κ : F[X])
    simp only [eval₂_sub, eval₂_X_pow, eval₂_C] at h
    rw [← AdjoinRoot.algebraMap_eq] at h
    linear_combination h

/-- **A pair of uniform base-field values, read as `c0 + U c1`, is uniform in `K`** (for `{1, U}` a basis): the
proximity mask `u = u_re + U·u_im`, coefficient by coefficient, is a uniform Fp2 value. -/
theorem fp2_uniform [Fintype F] [Fintype K] {U : K} (hb : Function.Bijective (fp2 (F := F) U)) :
    (PMF.uniformOfFintype (F × F)).map (fp2 U) = PMF.uniformOfFintype K := by
  classical
  have hcard : Fintype.card (F × F) = Fintype.card K := Fintype.card_of_bijective hb
  ext z
  obtain ⟨p, rfl⟩ := hb.2 z
  rw [PMF.map_apply, tsum_eq_single p, PMF.uniformOfFintype_apply, PMF.uniformOfFintype_apply, hcard]
  · simp
  · intro p' hp'
    have : fp2 U p ≠ fp2 U p' := fun h => hp' (hb.1 h).symm
    simp [this]

/-- The functional value in `K`: `Σ_s Σ_i W_{s,i}·a_{s,i}`, with the weights and the coefficients read from their code
pairs, is the reading of the component formulas `mValRe`, `mValIm`. -/
theorem fp2_mVal {m r Q q : ℕ} (U : K) (κ : F) (hU : U ^ 2 = algebraMap F K κ) (P : MOpenPub F m r Q q)
    (w : Fin r → Bool → Fin m → F) :
    ∑ s, ∑ i, fp2 U (w s true i, w s false i) * fp2 U (P.Wre s i, P.Wim s i)
      = fp2 U (mValRe κ P w, mValIm P w) := by
  have h : ∀ s i, fp2 U (w s true i, w s false i) * fp2 U (P.Wre s i, P.Wim s i)
      = fp2 U (w s true i * P.Wre s i + κ * (w s false i * P.Wim s i),
          w s true i * P.Wim s i + w s false i * P.Wre s i) := fun s i => fp2_mul U κ hU _ _
  rw [Finset.sum_congr rfl (fun s _ => Finset.sum_congr rfl (fun i _ => h s i))]
  simp only [fp2, mValRe, mValIm, map_sum, Finset.mul_sum, ← Finset.sum_add_distrib]

/-- **`mOpenView_law_eq` with the hypothesis read in `K`**: two coefficient families whose functional values agree as
Fp2 elements give the same law of `M`'s opening view (`U ∉ F` makes the K-equality the two component equalities). -/
theorem mOpenView_law_eq_fp2 [Fintype F] {m r Q q : ℕ} (U : K) (κ : F) (hU2 : U ^ 2 = algebraMap F K κ)
    (hU : U ∉ Set.range (algebraMap F K)) (P : MOpenPub F m r Q q) (hm : 0 < m) (hmF : (m : F) ≠ 0)
    (hy : Function.Injective P.y)
    (hsum : ∀ j < 2 * m, ∑ i, P.y i ^ j = if j = 0 ∨ j = m then (m : F) else 0)
    (hW : ∀ s l, P.Wre s (P.π s l) = 0 ∧ P.Wim s (P.π s l) = 0)
    (hpad : ∀ s (v : Fin m → F), ∃ g : Fin Q → F,
      ∀ t, (Lagrange.interpolate Finset.univ P.y (v - placePads (P.π s) g)).eval (P.x t) = 0)
    (w w' : Fin r → Bool → Fin m → F)
    (hV : ∑ s, ∑ i, fp2 U (w s true i, w s false i) * fp2 U (P.Wre s i, P.Wim s i)
      = ∑ s, ∑ i, fp2 U (w' s true i, w' s false i) * fp2 U (P.Wre s i, P.Wim s i)) :
    (PMF.uniformOfFintype (MCoins F m r Q)).map (mOpenView κ P hm w)
      = (PMF.uniformOfFintype (MCoins F m r Q)).map (mOpenView κ P hm w') := by
  rw [fp2_mVal U κ hU2, fp2_mVal U κ hU2] at hV
  have h := fp2_injective hU hV
  simp only [Prod.mk.injEq] at h
  exact mOpenView_law_eq κ P hm hmF hy hsum hW hpad w w' h.1 h.2

end Fp2

end ZK60.Hiding
