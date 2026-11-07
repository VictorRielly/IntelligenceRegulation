/-
D63 lane L10 (2026-11-07): the CODE of the hiding Ligero PCS, as `encode_row_zk` builds it, parametrized so that W16R3's
coefficient rows (B1) are an instance swap.

What is modelled (`zkp-core/src/pcs.rs` `encode_row_zk`, `pcs/encode_buffer.rs`, `ntt.rs`, read 2026-11-07; nothing there
is changed). A row's message `d ∈ F^n` and its pad `g ∈ F^Q` become the polynomial
  `f = rowPoly d + (X^n − 1)·Σ_k g_k X^k`
evaluated at the `N` points `η_j = h·ω_N^j` (the coset `h·G_N`, `h = 7`). The ROW FORM `rowPoly` is the profile's:
* W16R2 (`lagForm`): `rowPoly d` interpolates `d` on `G_n` (the code's inverse NTT, `ntt.inverse`);
* W16R3, B1 (`coefForm`): `rowPoly d = Σ_i d_i X^i` (no inverse NTT; `W16R3_DESIGN_B1_B3_20261105.md` §2).
`encode_row_zk`'s coefficient loop (`out[i] -= pad[i]`, `out[n + i] = pad[i]`, also when `Q > n`) is exactly this `f`;
the coset powers and the forward NTT evaluate it at `h·ω_N^j` in natural order (`ntt.rs`: "evaluations at omega^i,
i = 0..n (natural order)").

What is proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `RowForm`, `coefForm`, `lagForm`: a row form is an injective linear map onto polynomials of degree `< n`; both
  profiles' forms are row forms (`coefPoly_coeff`, `coefPoly_injective`, `lagForm` from `mInterp_eval`);
* **`encPoly_inj`**: the encoder is injective in `(d, g)`: `rowPoly (d − d')` has degree `< n`, a nonzero multiple of
  the monic `X^n − 1` has degree `≥ n`; `encPoly_natDegree_lt`: `f` has degree `< n + Q`;
* **`encWord_inj`**: at `N ≥ n + Q` distinct points the `N` values determine `(d, g)` (`col_inj`'s code argument);
* `encLin`, `encLin_apply`, `encLin_injective`: the encoder as the injective `F`-linear map of `SoundGroups.lean`
  (`enc : (μ → E) →ₗ (ι → E)`, clear vector = message then pads);
* `cosetPts_injective`: the coset points are distinct;
* the Goldilocks roots: `rootGF k = 7^((p − 1)/2^k)` is a primitive `2^k`-th root of unity for `k ≤ 32`
  (`rootGF_isPrimitiveRoot`, from `Goldilocks.lean`'s `pow7_full` and `pow7_2`); `7^(2^k) ≠ 1` for `k ≤ 31`
  (`seven_pow_two_pow_ne_one`), so the coset `7·G_N` misses `G_n` (`coset_pow_ne_one`): every `η_j^n ≠ 1`;
* **the barycentric form** of `SoundMProduct.lean`'s `mInterp` (the interpolant on `G_n`): `nodal_mPts`
  (`Π_j (X − ω^j) = X^n − 1`), `nodalWeight_mPts` (`(n·ω^{j(n−1)})⁻¹ = n⁻¹·ω^j`), and **`bary_eval`**: off `G_n`,
  `p_W(x) = (x^n − 1)·n⁻¹·Σ_j W_j·ω^j/(x − ω^j)`. This is what the executable verifier computes in place of the NTT
  (`ExecOpening.lean`).

L7-4 is respected: every fact about the concrete `p` is either `Goldilocks.lean`'s (`pow7_full`, `pow7_2`) or exponent
arithmetic on natural numbers; nothing enumerates a concrete `Finset.univ`.
-/
import ZK60Formal.SoundMProduct
import ZK60Formal.Goldilocks
import Mathlib.RingTheory.Polynomial.Cyclotomic.Basic

set_option autoImplicit false

namespace ZK60.Exec

open Polynomial Finset
open ZK60.Circuit (gP GF)
open ZK60.Sound (mPts mInterp mPts_injective mInterp_natDegree_lt mInterp_eval)

/-! ## Row forms and the encoder, over any field -/

section Code

variable {F : Type} [Field F]

/-- **A row form**: how a row's `n` message symbols become its message polynomial: an injective linear map onto
polynomials of degree `< n`. W16R2: the interpolant on `G_n` (`lagForm`); W16R3 (B1): the coefficients (`coefForm`). -/
structure RowForm (F : Type) [Field F] (n : ℕ) where
  poly : (Fin n → F) →ₗ[F] F[X]
  inj : Function.Injective poly
  deg : ∀ d, (poly d).natDegree < n

/-- The polynomial with the given coefficients, `Σ_i v_i X^i` (the pad polynomial `g`; W16R3's row polynomial). -/
noncomputable def coefPoly {k : ℕ} : (Fin k → F) →ₗ[F] F[X] where
  toFun v := ∑ i : Fin k, monomial (i : ℕ) (v i)
  map_add' a b := by simp only [Pi.add_apply, map_add, Finset.sum_add_distrib]
  map_smul' c a := by simp only [Pi.smul_apply, map_smul, RingHom.id_apply, Finset.smul_sum]

theorem coefPoly_apply {k : ℕ} (v : Fin k → F) : coefPoly v = ∑ i : Fin k, monomial (i : ℕ) (v i) := rfl

theorem coefPoly_coeff {k : ℕ} (v : Fin k → F) (t : ℕ) :
    (coefPoly v).coeff t = if h : t < k then v ⟨t, h⟩ else 0 := by
  rw [coefPoly_apply, finsetSum_coeff]
  simp only [coeff_monomial]
  split_ifs with h
  · rw [Finset.sum_eq_single ⟨t, h⟩]
    · simp
    · intro i _ hi
      have : (i : ℕ) ≠ t := fun e => hi (Fin.ext e)
      simp [this]
    · intro h'
      exact absurd (mem_univ _) h'
  · refine Finset.sum_eq_zero fun i _ => ?_
    have : (i : ℕ) ≠ t := fun e => h (e ▸ i.isLt)
    simp [this]

theorem coefPoly_injective {k : ℕ} : Function.Injective (coefPoly (F := F) (k := k)) := by
  intro a b h
  funext i
  have := congrArg (fun p : F[X] => p.coeff i) h
  simp only [coefPoly_coeff, i.isLt, ↓reduceDIte, Fin.eta] at this
  exact this

theorem coefPoly_natDegree_le {k : ℕ} (v : Fin k → F) : (coefPoly v).natDegree ≤ k - 1 := by
  rw [coefPoly_apply]
  refine natDegree_sum_le_of_forall_le _ _ fun i _ => (natDegree_monomial_le _).trans ?_
  have := i.isLt
  omega

theorem coefPoly_natDegree_lt {k : ℕ} (hk : 0 < k) (v : Fin k → F) : (coefPoly v).natDegree < k :=
  lt_of_le_of_lt (coefPoly_natDegree_le v) (by omega)

/-- **W16R3's row form (B1)**: the message symbols are the coefficients. -/
noncomputable def coefForm {n : ℕ} (hn : 0 < n) : RowForm F n where
  poly := coefPoly
  inj := coefPoly_injective
  deg := coefPoly_natDegree_lt hn

/-- **W16R2's row form**: the interpolant of the message on `G_n = {ω^j}` (`encode_row_zk`'s `ntt.inverse`). -/
noncomputable def lagForm {n : ℕ} (hn : 0 < n) {ω : F} (hω : IsPrimitiveRoot ω n) : RowForm F n where
  poly := Lagrange.interpolate univ (mPts ω)
  inj a b h := by
    funext j
    have h1 := mInterp_eval hω a j
    have h2 := mInterp_eval hω b j
    unfold mInterp at h1 h2
    rw [h] at h1
    exact h1.symm.trans h2
  deg d := mInterp_natDegree_lt hn hω d

theorem lagForm_poly {n : ℕ} (hn : 0 < n) {ω : F} (hω : IsPrimitiveRoot ω n) (d : Fin n → F) :
    (lagForm hn hω).poly d = mInterp ω d := rfl

/-- **The encoded row's polynomial** (`encode_row_zk`): `rowPoly d + (X^n − 1)·Σ_k g_k X^k`. -/
noncomputable def encPoly {n Q : ℕ} (R : RowForm F n) (d : Fin n → F) (g : Fin Q → F) : F[X] :=
  R.poly d + (X ^ n - 1) * coefPoly g

theorem natDegree_Z (n : ℕ) : ((X : F[X]) ^ n - 1).natDegree = n := by
  simpa using (natDegree_X_pow_sub_C (n := n) (r := (1 : F)))

theorem monic_Z {n : ℕ} (hn : 0 < n) : ((X : F[X]) ^ n - 1).Monic := by
  simpa using monic_X_pow_sub_C (1 : F) (Nat.pos_iff_ne_zero.mp hn)

/-- The encoded polynomial has degree `< n + Q` (the code is `RS[n + Q]`). -/
theorem encPoly_natDegree_lt {n Q : ℕ} (R : RowForm F n) (hn : 0 < n) (d : Fin n → F) (g : Fin Q → F) :
    (encPoly R d g).natDegree < n + Q := by
  unfold encPoly
  refine lt_of_le_of_lt (natDegree_add_le _ _) (max_lt (lt_of_lt_of_le (R.deg d) (Nat.le_add_right n Q)) ?_)
  rcases Nat.eq_zero_or_pos Q with hQ | hQ
  · subst hQ
    have : coefPoly g = 0 := by simp [coefPoly_apply]
    rw [this, mul_zero, natDegree_zero]
    omega
  · refine lt_of_le_of_lt natDegree_mul_le ?_
    rw [natDegree_Z]
    have := coefPoly_natDegree_le g
    omega

/-- **The encoder is injective**: the message and the pad are determined by the encoded polynomial. A difference of
row polynomials has degree `< n`; a nonzero multiple of the monic `X^n − 1` has degree `≥ n`. -/
theorem encPoly_inj {n Q : ℕ} (R : RowForm F n) (hn : 0 < n) {d d' : Fin n → F} {g g' : Fin Q → F}
    (h : encPoly R d g = encPoly R d' g') : d = d' ∧ g = g' := by
  have key : R.poly (d - d') = (X ^ n - 1) * (coefPoly g' - coefPoly g) := by
    rw [map_sub, mul_sub]
    unfold encPoly at h
    linear_combination h
  have hg : coefPoly g' - coefPoly g = 0 := by
    by_contra hne
    have h1 := (monic_Z (F := F) hn).natDegree_mul' hne
    have h2 := R.deg (d - d')
    rw [key, h1, natDegree_Z] at h2
    omega
  have hgg : g' = g := coefPoly_injective (sub_eq_zero.mp hg)
  refine ⟨?_, hgg.symm⟩
  rw [hg, mul_zero, map_sub, sub_eq_zero] at key
  exact R.inj key

/-- **The encoded word**: the encoded polynomial at the `N` evaluation points. -/
noncomputable def encWord {n Q N : ℕ} (pts : Fin N → F) (R : RowForm F n) (d : Fin n → F) (g : Fin Q → F) :
    Fin N → F :=
  fun j => (encPoly R d g).eval (pts j)

/-- **The words determine the message** (the code argument of `col_inj`): at `N ≥ n + Q` distinct points the encoded
word determines the message and the pad. -/
theorem encWord_inj {n Q N : ℕ} {pts : Fin N → F} (hpts : Function.Injective pts) (R : RowForm F n) (hn : 0 < n)
    (hNQ : n + Q ≤ N) {d d' : Fin n → F} {g g' : Fin Q → F} (h : encWord pts R d g = encWord pts R d' g') :
    d = d' ∧ g = g' := by
  refine encPoly_inj R hn (eq_of_natDegree_lt_card_of_eval_eq _ _ hpts (fun j => congrFun h j) ?_)
  rw [Fintype.card_fin]
  exact max_lt (lt_of_lt_of_le (encPoly_natDegree_lt R hn d g) hNQ)
    (lt_of_lt_of_le (encPoly_natDegree_lt R hn d' g') hNQ)

/-- The encoder's polynomial as a linear map of the clear vector (message, then pads). -/
noncomputable def encPolyLin {n Q : ℕ} (R : RowForm F n) : (Fin (n + Q) → F) →ₗ[F] F[X] :=
  R.poly ∘ₗ LinearMap.funLeft F F (Fin.castAdd Q)
    + (LinearMap.mulLeft F ((X : F[X]) ^ n - 1)) ∘ₗ (coefPoly ∘ₗ LinearMap.funLeft F F (Fin.natAdd n))

/-- **The encoder as a linear map** (`SoundGroups.lean`'s `enc`): a clear vector of `n + Q` entries (message, then
pad combination) to its word at the `N` points. -/
noncomputable def encLin {n Q N : ℕ} (pts : Fin N → F) (R : RowForm F n) : (Fin (n + Q) → F) →ₗ[F] (Fin N → F) :=
  LinearMap.pi (fun j => Polynomial.leval (pts j) ∘ₗ encPolyLin R)

theorem encLin_apply {n Q N : ℕ} (pts : Fin N → F) (R : RowForm F n) (v : Fin (n + Q) → F) (j : Fin N) :
    encLin pts R v j = (encPoly R (fun i => v (Fin.castAdd Q i)) (fun k => v (Fin.natAdd n k))).eval (pts j) := by
  rfl

theorem encLin_injective {n Q N : ℕ} {pts : Fin N → F} (hpts : Function.Injective pts) (R : RowForm F n)
    (hn : 0 < n) (hNQ : n + Q ≤ N) : Function.Injective (encLin (Q := Q) pts R) := by
  intro v w h
  have hw : encWord pts R (fun i => v (Fin.castAdd Q i)) (fun k => v (Fin.natAdd n k))
      = encWord pts R (fun i => w (Fin.castAdd Q i)) (fun k => w (Fin.natAdd n k)) := by
    funext j
    have := congrFun h j
    rw [encLin_apply, encLin_apply] at this
    exact this
  obtain ⟨h1, h2⟩ := encWord_inj hpts R hn hNQ hw
  funext i
  induction i using Fin.addCases with
  | left a => exact congrFun h1 a
  | right b => exact congrFun h2 b

/-- **The evaluation points** `η_j = h·ω^j` (the coset `h·G_N` in the forward NTT's natural order). -/
def cosetPts {N : ℕ} (h ω : F) : Fin N → F := fun j => h * ω ^ (j : ℕ)

theorem cosetPts_injective {N : ℕ} {h ω : F} (hh : h ≠ 0) (hω : IsPrimitiveRoot ω N) :
    Function.Injective (cosetPts (N := N) h ω) :=
  fun i j hij => Fin.ext (hω.pow_inj i.isLt j.isLt (mul_left_cancel₀ hh hij))

end Code

/-! ## The barycentric form of the interpolant on `G_n` -/

section Bary

variable {F : Type} [Field F]

/-- **The nodal polynomial of `G_n` is `X^n − 1`.** -/
theorem nodal_mPts {n : ℕ} (hn : 0 < n) {ω : F} (hω : IsPrimitiveRoot ω n) :
    Lagrange.nodal univ (mPts (m := n) ω) = X ^ n - 1 := by
  classical
  rw [Lagrange.nodal_eq, X_pow_sub_one_eq_prod hn hω]
  have himg : univ.image (mPts (m := n) ω) = nthRootsFinset n (1 : F) := by
    refine Finset.eq_of_subset_of_card_le ?_ ?_
    · intro x hx
      obtain ⟨j, -, rfl⟩ := Finset.mem_image.mp hx
      refine (mem_nthRootsFinset hn (1 : F)).mpr ?_
      simp only [mPts]
      rw [← pow_mul, mul_comm, pow_mul, hω.pow_eq_one, one_pow]
    · rw [hω.card_nthRootsFinset, Finset.card_image_of_injective _ (mPts_injective hω), card_univ,
        Fintype.card_fin]
  rw [← himg, Finset.prod_image (fun i _ j _ h => mPts_injective hω h)]

/-- **The nodal weights of `G_n`**: `(n·(ω^j)^(n−1))⁻¹ = n⁻¹·ω^j`. -/
theorem nodalWeight_mPts {n : ℕ} (hn : 0 < n) {ω : F} (hω : IsPrimitiveRoot ω n) (i : Fin n) :
    Lagrange.nodalWeight univ (mPts ω) i = (n : F)⁻¹ * ω ^ (i : ℕ) := by
  classical
  rw [Lagrange.nodalWeight_eq_eval_derivative_nodal (mem_univ i), nodal_mPts hn hω, derivative_sub,
    derivative_X_pow, derivative_one, sub_zero, eval_mul, eval_C, eval_pow, eval_X, mul_inv]
  simp only [mPts]
  congr 1
  refine inv_eq_of_mul_eq_one_right ?_
  rw [← pow_succ, Nat.sub_add_cancel hn, ← pow_mul, mul_comm, pow_mul, hω.pow_eq_one, one_pow]

/-- **The barycentric form** of the interpolant on `G_n`, off `G_n`:
`p_W(x) = (x^n − 1)·n⁻¹·Σ_j W_j·(ω^j·(x − ω^j)⁻¹)`. -/
theorem bary_eval {n : ℕ} (hn : 0 < n) {ω : F} (hω : IsPrimitiveRoot ω n) (W : Fin n → F) (x : F)
    (hx : x ^ n ≠ 1) :
    (mInterp ω W).eval x = (x ^ n - 1) * (n : F)⁻¹ * ∑ i, W i * (ω ^ (i : ℕ) * (x - ω ^ (i : ℕ))⁻¹) := by
  classical
  have hnode : ∀ i ∈ (univ : Finset (Fin n)), x ≠ mPts ω i := by
    intro i _ h
    apply hx
    have h1 : (mPts ω i) ^ n = 1 := by
      simp only [mPts]
      rw [← pow_mul, mul_comm, pow_mul, hω.pow_eq_one, one_pow]
    rw [h]
    exact h1
  unfold mInterp
  rw [Lagrange.eval_interpolate_not_at_node W hnode, nodal_mPts hn hω]
  simp only [nodalWeight_mPts hn hω]
  simp only [mPts, eval_sub, eval_pow, eval_X, eval_one, mul_assoc, Finset.mul_sum]
  refine Finset.sum_congr rfl fun i _ => ?_
  ring

end Bary

/-! ## The Goldilocks roots of unity and the coset -/

section Roots

theorem gP_sub_one_eq : gP - 1 = 2 ^ 32 * 4294967295 := by norm_num

/-- **The two-adic root of order `2^k`**: `7^((p − 1)/2^k)` (the code's `Fp::two_adic_root(k)` is
`(7^((p − 1)/2^32))^(2^(32 − k))`, the same element; the corpus checks the values). -/
noncomputable def rootGF (k : ℕ) : GF := 7 ^ ((gP - 1) / 2 ^ k)

theorem gP_div_two_pow {k : ℕ} (hk : k ≤ 32) : (gP - 1) / 2 ^ k = 2 ^ (32 - k) * 4294967295 := by
  rw [gP_sub_one_eq, show (2 : ℕ) ^ 32 = 2 ^ k * 2 ^ (32 - k) by rw [← pow_add]; congr 1; omega, mul_assoc,
    Nat.mul_div_cancel_left _ (by positivity)]

/-- `7^((p − 1)/2) ≠ 1` in the exponent form the proofs below use. -/
theorem seven_pow_half_ne_one : (7 : GF) ^ (2 ^ 31 * 4294967295) ≠ 1 := by
  rw [show (2 : ℕ) ^ 31 * 4294967295 = 9223372034707292160 by norm_num]
  exact ZK60.Circuit.pow7_2

/-- **`rootGF k` is a primitive `2^k`-th root of unity** (`k ≤ 32`). -/
theorem rootGF_isPrimitiveRoot {k : ℕ} (hk : k ≤ 32) : IsPrimitiveRoot (rootGF k) (2 ^ k) := by
  rcases k with _ | k
  · have h1 : rootGF 0 = 1 := by
      rw [rootGF, pow_zero, Nat.div_one]
      exact (ZK60.Circuit.pow7_full : (7 : GF) ^ (gP - 1) = 1)
    rw [h1, pow_zero]
    exact IsPrimitiveRoot.one
  · have e1 : 2 ^ (32 - (k + 1)) * 4294967295 * 2 ^ (k + 1) = 18446744069414584320 := by
      rw [mul_comm, ← mul_assoc, ← pow_add, show k + 1 + (32 - (k + 1)) = 32 by omega]
      norm_num
    have e2 : 2 ^ (32 - (k + 1)) * 4294967295 * 2 ^ k = 2 ^ 31 * 4294967295 := by
      rw [mul_comm, ← mul_assoc, ← pow_add, show k + (32 - (k + 1)) = 31 by omega]
    have hfin : rootGF (k + 1) ^ 2 ^ (k + 1) = 1 := by
      rw [rootGF, ← pow_mul, gP_div_two_pow hk, e1]
      exact ZK60.Circuit.pow7_full
    have hnot : ¬ rootGF (k + 1) ^ 2 ^ k = 1 := by
      rw [rootGF, ← pow_mul, gP_div_two_pow hk, e2]
      exact seven_pow_half_ne_one
    have hord := orderOf_eq_prime_pow (p := 2) hnot hfin
    rw [← hord]
    exact IsPrimitiveRoot.orderOf _

/-- **`7^(2^k) ≠ 1` for `k ≤ 31`**: `7` is not a square (`2^k ∣ (p − 1)/2` and `7^((p − 1)/2) ≠ 1`). -/
theorem seven_pow_two_pow_ne_one {k : ℕ} (hk : k ≤ 31) : (7 : GF) ^ (2 ^ k) ≠ 1 := by
  intro h
  apply seven_pow_half_ne_one
  rw [show (2 : ℕ) ^ 31 * 4294967295 = 2 ^ k * (2 ^ (31 - k) * 4294967295) by
    rw [← mul_assoc, ← pow_add, show k + (31 - k) = 31 by omega], pow_mul, h, one_pow]

/-- **The coset `7·G_N` misses `G_n`** (`n ∣ N = 2^k`, `k ≤ 31`): no point `7·ω^j` has `(7·ω^j)^n = 1`, so the
interpolant's barycentric form applies at every column (`coset_powers`' assertion `7^nn ≠ 1`). -/
theorem coset_pow_ne_one {n N k : ℕ} (hnN : n ∣ N) (hN : N = 2 ^ k) (hk : k ≤ 31) {ω : GF}
    (hω : IsPrimitiveRoot ω N) (j : ℕ) : (7 * ω ^ j) ^ n ≠ 1 := by
  intro h
  obtain ⟨c, hc⟩ := hnN
  apply seven_pow_two_pow_ne_one hk
  have h1 : (7 * ω ^ j) ^ (n * c) = 1 := by rw [pow_mul, h, one_pow]
  rw [← hc, mul_pow, ← pow_mul, show j * N = N * j by ring, pow_mul, hω.pow_eq_one, one_pow, mul_one, hN] at h1
  exact h1

/-- The coset generator is not zero. -/
theorem seven_ne_zero_GF : (7 : GF) ≠ 0 := by
  intro h
  have h1 : (7 : GF) ^ (gP - 1) = 1 := ZK60.Circuit.pow7_full
  rw [h, zero_pow (by norm_num)] at h1
  exact zero_ne_one h1

end Roots

end ZK60.Exec
