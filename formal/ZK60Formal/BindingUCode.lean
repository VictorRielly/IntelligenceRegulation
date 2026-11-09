/-
D63 lane L30 (2026-11-09), part 1: **finding L26-3's code fact, proved** (the step from the extension field to the
base field in the input endpoint's column test).

The endpoint's column test draws its weights in the extension field `K` (`F_p²`), so it is analysed for the code over
`K` with the commitment's base-field columns embedded, while `OpensU` speaks of the base-field code. L26 reduced the
link to ONE fact about the two codes (`closeIn_base`'s premise `hbc`): a `K`-codeword whose values on a set of columns
are base-field values agrees on that set with a base-field codeword. L26 did not prove it. This file proves it for
the code of the tree, the row encoder `encLin` (`ExecOpeningCode.lean`):

* `RowFormExt`: the extension field's row form is the base one with scalars extended (on a base-field message its
  polynomial is the base polynomial with coefficients embedded); `coefForm_ext` (W16R3's coefficient rows),
  **`lagForm_ext`** (W16R2's and R13's interpolant rows, at the embedded root of unity);
* `encPoly_map_base`, **`encLin_map_base`**: the `K`-encoder of an embedded message is the embedded base codeword;
* `exists_base_proj`: an `F`-linear projection `π : K → F` that is the identity on the base field;
* `encLin_proj_single`, **`encLin_proj`**: `π`, applied coordinate by coordinate, sends the `K`-codeword of a message
  to the base codeword of the projected message (both sides are `F`-linear in the message; on a message with one
  entry `x` the `K`-codeword is `x` times an embedded base codeword);
* **`encLin_base_fact`**: THE FACT. It needs no bound on the size of the set (L26 stated it for sets of all but `e`
  columns; the projection gives it for every set);
* **`closeIn_enc_base`**, `closeIn_enc_ext`, **`closeIn_enc_iff`**: the embedded matrix is close inside `X` over `K`
  if and only if the base-field matrix is close inside `X` over the base field;
* `closeIn_base_encLin`: L26's `closeIn_base` with its premise discharged;
* `rowFormK14`, `rowFormK14_ext_w16r2`, `rowFormK14_ext_r13`, **`closeIn_w16r2_iff`**, **`closeIn_r13_iff`**: at the two
  registered codes (W16R2: `N = 2^15`, `Q = 280`; R13: `N = 2^16`, `Q = 256`; the interpolant rows on `G_{2^14}`).

Nothing here is specific to `F_p²`: any field extension of the base field will do. Only `propext`,
`Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BindingUDecode
import Mathlib.LinearAlgebra.Basis.VectorSpace

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Sound Code
open ZK60.Circuit (gP GF)
open scoped Polynomial

/-- **A base-field projection**: an `F`-linear map `K → F` that is the identity on the base field (a left inverse of
the embedding, which is injective). -/
theorem exists_base_proj (F K : Type) [Field F] [Field K] [Algebra F K] :
    ∃ π : K →ₗ[F] F, ∀ a : F, π (algebraMap F K a) = a := by
  have hinj : Function.Injective (Algebra.linearMap F K) :=
    fun a b hab => (algebraMap F K).injective (by simpa only [Algebra.linearMap_apply] using hab)
  obtain ⟨g, hg⟩ := LinearMap.exists_leftInverse_of_injective (Algebra.linearMap F K)
    (LinearMap.ker_eq_bot.mpr hinj)
  exact ⟨g, fun a => by simpa using LinearMap.congr_fun hg a⟩

/-! ## A row form with its scalars extended -/

section Ext

variable {F K : Type} [Field F] [Field K] [Algebra F K]

/-- **The extension field's row form is the base one with scalars extended**: on a base-field message, its polynomial
is the base row polynomial with its coefficients embedded. -/
def RowFormExt {n : ℕ} (R : RowForm F n) (RK : RowForm K n) : Prop :=
  ∀ d : Fin n → F, RK.poly (fun i => algebraMap F K (d i)) = (R.poly d).map (algebraMap F K)

/-- The coefficient polynomial of an embedded vector is the embedded coefficient polynomial. -/
theorem coefPoly_map_base {k : ℕ} (v : Fin k → F) :
    (coefPoly v).map (algebraMap F K) = coefPoly (fun i => algebraMap F K (v i)) := by
  rw [coefPoly_apply, coefPoly_apply, Polynomial.map_sum]
  refine Finset.sum_congr rfl (fun i _ => ?_)
  rw [Polynomial.map_monomial]

/-- **W16R3's coefficient rows extend** (B1). -/
theorem coefForm_ext {n : ℕ} (hn : 0 < n) : RowFormExt (coefForm (F := F) hn) (coefForm (F := K) hn) :=
  fun d => (coefPoly_map_base d).symm

/-- **The interpolant rows extend** (W16R2, R13): the interpolant on the embedded `G_n` of an embedded message is the
embedded interpolant (both have degree `< n` and take the embedded message at the `n` embedded points). -/
theorem lagForm_ext {n : ℕ} (hn : 0 < n) {ω : F} (hω : IsPrimitiveRoot ω n) :
    RowFormExt (lagForm hn hω) (lagForm hn (hω.map_of_injective (algebraMap F K).injective)) := by
  intro d
  have hωK : IsPrimitiveRoot (algebraMap F K ω) n := hω.map_of_injective (algebraMap F K).injective
  rw [lagForm_poly, lagForm_poly]
  refine Polynomial.eq_of_natDegree_lt_card_of_eval_eq _ _ (f := mPts (m := n) (algebraMap F K ω))
    (mPts_injective hωK) (fun j => ?_) ?_
  · have hp : mPts (m := n) (algebraMap F K ω) j = algebraMap F K (mPts (m := n) ω j) :=
      (map_pow (algebraMap F K) ω (j : ℕ)).symm
    have h1 := mInterp_eval hωK (fun i => algebraMap F K (d i)) j
    have h2 : ((mInterp ω d).map (algebraMap F K)).eval (algebraMap F K (mPts (m := n) ω j))
        = algebraMap F K ((mInterp ω d).eval (mPts (m := n) ω j)) :=
      Polynomial.eval_map_apply (algebraMap F K) (mPts (m := n) ω j)
    rw [mInterp_eval hω d j] at h2
    rw [h1, hp, h2]
  · rw [Fintype.card_fin]
    exact max_lt (mInterp_natDegree_lt hn hωK _)
      (lt_of_le_of_lt Polynomial.natDegree_map_le (mInterp_natDegree_lt hn hω d))

/-- **The encoded polynomial of an embedded message and pad is the embedded encoded polynomial.** -/
theorem encPoly_map_base {n Q : ℕ} (R : RowForm F n) (RK : RowForm K n) (hext : RowFormExt R RK)
    (d : Fin n → F) (g : Fin Q → F) :
    encPoly RK (fun i => algebraMap F K (d i)) (fun k => algebraMap F K (g k))
      = (encPoly R d g).map (algebraMap F K) := by
  unfold encPoly
  rw [Polynomial.map_add, Polynomial.map_mul, Polynomial.map_sub, Polynomial.map_pow, Polynomial.map_X,
    Polynomial.map_one, hext d, coefPoly_map_base]

/-- **The `K`-encoder of an embedded clear vector is the embedded base codeword**, column by column: the code over `K`
is the base code with its scalars extended. -/
theorem encLin_map_base {n Q N : ℕ} (pts : Fin N → F) (R : RowForm F n) (RK : RowForm K n)
    (hext : RowFormExt R RK) (v : Fin (n + Q) → F) (j : Fin N) :
    encLin (Q := Q) (fun j => algebraMap F K (pts j)) RK (fun t => algebraMap F K (v t)) j
      = algebraMap F K (encLin (Q := Q) pts R v j) := by
  have h := encPoly_map_base (Q := Q) R RK hext (fun i => v (Fin.castAdd Q i)) (fun k => v (Fin.natAdd n k))
  have h2 : ((encPoly R (fun i => v (Fin.castAdd Q i)) (fun k => v (Fin.natAdd n k))).map
        (algebraMap F K)).eval (algebraMap F K (pts j))
      = algebraMap F K ((encPoly R (fun i => v (Fin.castAdd Q i)) (fun k => v (Fin.natAdd n k))).eval (pts j)) :=
    Polynomial.eval_map_apply (algebraMap F K) (pts j)
  rw [encLin_apply, encLin_apply]
  exact (congrArg (fun q : K[X] => q.eval (algebraMap F K (pts j))) h).trans h2

/-- The projection of the `K`-codeword of a clear vector with ONE entry `x`: that codeword is `x` times an embedded
base codeword, and `π` is `F`-linear. -/
theorem encLin_proj_single {n Q N : ℕ} (pts : Fin N → F) (R : RowForm F n) (RK : RowForm K n)
    (hext : RowFormExt R RK) (π : K →ₗ[F] F) (i : Fin (n + Q)) (x : K) (j : Fin N) :
    π (encLin (Q := Q) (fun j => algebraMap F K (pts j)) RK (Pi.single i x) j)
      = encLin (Q := Q) pts R (Pi.single i (π x)) j := by
  have hsK : (Pi.single i x : Fin (n + Q) → K)
      = x • (fun t => algebraMap F K ((Pi.single i (1 : F) : Fin (n + Q) → F) t)) := by
    funext t
    show (Pi.single i x : Fin (n + Q) → K) t
      = x * algebraMap F K ((Pi.single i (1 : F) : Fin (n + Q) → F) t)
    rw [Pi.single_apply, Pi.single_apply]
    split_ifs with ht
    · rw [map_one, mul_one]
    · rw [map_zero, mul_zero]
  have hsF : (Pi.single i (π x) : Fin (n + Q) → F) = π x • (Pi.single i (1 : F) : Fin (n + Q) → F) := by
    funext t
    show (Pi.single i (π x) : Fin (n + Q) → F) t = π x * (Pi.single i (1 : F) : Fin (n + Q) → F) t
    rw [Pi.single_apply, Pi.single_apply]
    split_ifs with ht
    · rw [mul_one]
    · rw [mul_zero]
  have hy := encLin_map_base (Q := Q) pts R RK hext (Pi.single i (1 : F)) j
  have hK : encLin (Q := Q) (fun j => algebraMap F K (pts j)) RK (Pi.single i x) j
      = x * algebraMap F K (encLin (Q := Q) pts R (Pi.single i (1 : F)) j) := by
    rw [hsK, _root_.map_smul, Pi.smul_apply, hy, smul_eq_mul]
  have hF : encLin (Q := Q) pts R (Pi.single i (π x)) j
      = π x * encLin (Q := Q) pts R (Pi.single i (1 : F)) j := by
    rw [hsF, _root_.map_smul, Pi.smul_apply, smul_eq_mul]
  rw [hK, hF, mul_comm x, ← Algebra.smul_def, _root_.map_smul, smul_eq_mul]
  exact mul_comm _ _

/-- **The base-field projection sends `K`-codewords to base codewords**, column by column: the projection of the
`K`-codeword of a clear vector is the base codeword of the projected clear vector. -/
theorem encLin_proj {n Q N : ℕ} (pts : Fin N → F) (R : RowForm F n) (RK : RowForm K n)
    (hext : RowFormExt R RK) (π : K →ₗ[F] F) (vK : Fin (n + Q) → K) (j : Fin N) :
    π (encLin (Q := Q) (fun j => algebraMap F K (pts j)) RK vK j)
      = encLin (Q := Q) pts R (fun t => π (vK t)) j := by
  calc π (encLin (Q := Q) (fun j => algebraMap F K (pts j)) RK vK j)
      = π (encLin (Q := Q) (fun j => algebraMap F K (pts j)) RK (∑ i, Pi.single i (vK i)) j) :=
        (congrArg (fun w => π (encLin (Q := Q) (fun j => algebraMap F K (pts j)) RK w j))
          (Finset.univ_sum_single vK)).symm
    _ = ∑ i, π (encLin (Q := Q) (fun j => algebraMap F K (pts j)) RK (Pi.single i (vK i)) j) := by
        rw [_root_.map_sum, Finset.sum_apply, _root_.map_sum]
    _ = ∑ i, encLin (Q := Q) pts R (Pi.single i (π (vK i))) j :=
        Finset.sum_congr rfl (fun i _ => encLin_proj_single pts R RK hext π i (vK i) j)
    _ = encLin (Q := Q) pts R (∑ i, Pi.single i (π (vK i))) j := by
        rw [_root_.map_sum, Finset.sum_apply]
    _ = encLin (Q := Q) pts R (fun t => π (vK t)) j :=
        congrArg (fun w => encLin (Q := Q) pts R w j) (Finset.univ_sum_single (fun t => π (vK t)))

/-- **THE CODE FACT of finding L26-3** (the premise `hbc` of L26's `closeIn_base`), for the row encoder: a codeword of
the code over `K` whose values on a set `S` of columns are base-field values agrees on `S` with (the embedding of) a
base-field codeword: its coordinate-wise projection. No bound on the size of `S` is needed. -/
theorem encLin_base_fact {n Q N : ℕ} (pts : Fin N → F) (R : RowForm F n) (RK : RowForm K n)
    (hext : RowFormExt R RK) (c : Fin N → K)
    (hc : c ∈ LinearMap.range (encLin (Q := Q) (fun j => algebraMap F K (pts j)) RK)) (S : Finset (Fin N))
    (hS : ∀ j ∈ S, ∃ a : F, c j = algebraMap F K a) :
    ∃ c' ∈ LinearMap.range (encLin (Q := Q) pts R), ∀ j ∈ S, c j = algebraMap F K (c' j) := by
  obtain ⟨π, hπ⟩ := exists_base_proj F K
  obtain ⟨vK, rfl⟩ := hc
  refine ⟨encLin (Q := Q) pts R (fun t => π (vK t)), LinearMap.mem_range_self _ _, fun j hj => ?_⟩
  obtain ⟨a, ha⟩ := hS j hj
  rw [← encLin_proj pts R RK hext π vK j, ha, hπ]

/-- **From the extension field to the base field**: the embedded matrix close inside `X` to the code over `K` gives
the base-field matrix close inside `X` to the base code (the same set of columns; each row's `K`-codeword replaced
by its projection). -/
theorem closeIn_enc_base {κ' : Type} {n Q N : ℕ} (pts : Fin N → F) (R : RowForm F n) (RK : RowForm K n)
    (hext : RowFormExt R RK) (e : ℕ) (X : Finset (Fin N)) (U : κ' → Fin N → F)
    (h : CloseIn (LinearMap.range (encLin (Q := Q) (fun j => algebraMap F K (pts j)) RK)) e X
      (fun i j => algebraMap F K (U i j))) :
    CloseIn (LinearMap.range (encLin (Q := Q) pts R)) e X U := by
  obtain ⟨S, hSX, hS, hagr⟩ := h
  refine ⟨S, hSX, hS, fun i => ?_⟩
  obtain ⟨c, hc, hcU⟩ := mem_agreeOn.mp (hagr i)
  obtain ⟨c', hc', hcc⟩ := encLin_base_fact pts R RK hext c hc S (fun j hj => ⟨U i j, (hcU j hj).symm⟩)
  exact mem_agreeOn.mpr ⟨c', hc', fun j hj => (algebraMap F K).injective ((hcU j hj).trans (hcc j hj))⟩

/-- **From the base field to the extension field**: a base-field matrix close inside `X` is, embedded, close inside
`X` to the code over `K` (each row's codeword embedded). -/
theorem closeIn_enc_ext {κ' : Type} {n Q N : ℕ} (pts : Fin N → F) (R : RowForm F n) (RK : RowForm K n)
    (hext : RowFormExt R RK) (e : ℕ) (X : Finset (Fin N)) (U : κ' → Fin N → F)
    (h : CloseIn (LinearMap.range (encLin (Q := Q) pts R)) e X U) :
    CloseIn (LinearMap.range (encLin (Q := Q) (fun j => algebraMap F K (pts j)) RK)) e X
      (fun i j => algebraMap F K (U i j)) := by
  obtain ⟨S, hSX, hS, hagr⟩ := h
  refine ⟨S, hSX, hS, fun i => ?_⟩
  obtain ⟨c, hc, hcU⟩ := mem_agreeOn.mp (hagr i)
  obtain ⟨v, rfl⟩ := hc
  refine mem_agreeOn.mpr ⟨encLin (Q := Q) (fun j => algebraMap F K (pts j)) RK (fun t => algebraMap F K (v t)),
    LinearMap.mem_range_self _ _, fun j hj => ?_⟩
  rw [encLin_map_base pts R RK hext v j]
  exact congrArg (algebraMap F K) (hcU j hj)

/-- **The extension-field closeness of the embedded matrix IS the base-field closeness** (finding L26-3 closed for the
row encoder): the column test, analysed over `K`, speaks of the base-field commitment. -/
theorem closeIn_enc_iff {κ' : Type} {n Q N : ℕ} (pts : Fin N → F) (R : RowForm F n) (RK : RowForm K n)
    (hext : RowFormExt R RK) (e : ℕ) (X : Finset (Fin N)) (U : κ' → Fin N → F) :
    CloseIn (LinearMap.range (encLin (Q := Q) (fun j => algebraMap F K (pts j)) RK)) e X
        (fun i j => algebraMap F K (U i j))
      ↔ CloseIn (LinearMap.range (encLin (Q := Q) pts R)) e X U :=
  ⟨closeIn_enc_base pts R RK hext e X U, closeIn_enc_ext pts R RK hext e X U⟩

end Ext

/-! ## L26's reduction, discharged, and the two registered codes -/

section Registered

variable {K : Type} [Field K] [Algebra GF K]

/-- **L26's `closeIn_base` with its code premise discharged** for the row encoder over any extension of the Goldilocks
field (`encLin_base_fact`). -/
theorem closeIn_base_encLin {κ' : Type} {n Q N : ℕ} (pts : Fin N → GF) (R : RowForm GF n) (RK : RowForm K n)
    (hext : RowFormExt R RK) (e : ℕ) (X : Finset (Fin N)) (U : κ' → Fin N → GF)
    (h : CloseIn (LinearMap.range (encLin (Q := Q) (fun j => algebraMap GF K (pts j)) RK)) e X
      (fun i j => algebraMap GF K (U i j))) :
    CloseIn (LinearMap.range (encLin (Q := Q) pts R)) e X U :=
  closeIn_base (algebraMap GF K) (algebraMap GF K).injective _ _ e X U
    (fun c hc S _ hS => encLin_base_fact pts R RK hext c hc S hS) h

variable (K)

/-- **The registered row form over an extension field** (W16R2 and R13 use the same rows: the interpolant on
`G_{2^14}`): the interpolant on the embedded `G_{2^14}`. -/
noncomputable def rowFormK14 : RowForm K (2 ^ 14) :=
  lagForm (by norm_num)
    ((rootGF_isPrimitiveRoot (k := 14) (by norm_num)).map_of_injective (algebraMap GF K).injective)

/-- It extends W16R2's row form. -/
theorem rowFormK14_ext_w16r2 : RowFormExt w16r2Form (rowFormK14 K) :=
  lagForm_ext (by norm_num) (rootGF_isPrimitiveRoot (k := 14) (by norm_num))

/-- It extends R13's row form. -/
theorem rowFormK14_ext_r13 : RowFormExt R13.r13Form (rowFormK14 K) :=
  lagForm_ext (by norm_num) (rootGF_isPrimitiveRoot (k := 14) (by norm_num))

/-- **W16R2's code** (`N = 2^15`, `Q = 280`): the embedded matrix is close inside `X` over `K` exactly when the
base-field matrix is close inside `X`. -/
theorem closeIn_w16r2_iff {κ' : Type} (e : ℕ) (X : Finset (Fin (2 ^ 15))) (U : κ' → Fin (2 ^ 15) → GF) :
    CloseIn (LinearMap.range (encLin (Q := 280) (fun j => algebraMap GF K (w16r2Pts j)) (rowFormK14 K))) e X
        (fun i j => algebraMap GF K (U i j))
      ↔ CloseIn (LinearMap.range (encLin (Q := 280) w16r2Pts w16r2Form)) e X U :=
  closeIn_enc_iff w16r2Pts w16r2Form (rowFormK14 K) (rowFormK14_ext_w16r2 K) e X U

/-- **R13's code, the media app's** (`N = 2^16`, `Q = 256`): the same. -/
theorem closeIn_r13_iff {κ' : Type} (e : ℕ) (X : Finset (Fin (2 ^ 16))) (U : κ' → Fin (2 ^ 16) → GF) :
    CloseIn (LinearMap.range (encLin (Q := 256) (fun j => algebraMap GF K (R13.r13Pts j)) (rowFormK14 K))) e X
        (fun i j => algebraMap GF K (U i j))
      ↔ CloseIn (LinearMap.range (encLin (Q := 256) R13.r13Pts R13.r13Form)) e X U :=
  closeIn_enc_iff R13.r13Pts R13.r13Form (rowFormK14 K) (rowFormK14_ext_r13 K) e X U

end Registered

end ZK60.Exec
