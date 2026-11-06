/-
D63 step L6 (the executable verifier): the zero-knowledge pieces of the generic sumcheck, executable, as
`zkp-core/src/sumcheck.rs` runs them (`CfsMask`, `CfsMasker::mask_round`, `extension_round`, `masked_terminal`), and
proved to be `HidingSumcheckJoint.lean`'s CFS / Libra model and `SoundSumcheck.lean`'s extension model.

What is mirrored (read 2026-11-06; nothing there is changed), on `ExecField.lean`'s `Fp2`:
* `CfsMask::len(N, d) = N·d + 2`, the layout `[a_0, a', a_{0,1..d}, …, a_{N−1,1..d}]`, `a(j, e) =
  coeffs[2 + j·d + (e − 1)]`, `u(j, x) = Σ_{e=1..d} a(j, e)·x^e` (the power by repeated multiplication);
* `sum_weights(N, d)`: `vec![from_u64(1 << (N − 1)); len]`, then `w[0] = from_u64(1 << N)`, `w[1] = ONE`. The shifts are
  the release build's: `u64 << s` takes `s mod 64`, and `N − 1` wraps for `N = 0` (finding L6-2: the weights are
  right only for `1 ≤ N < 64`; `N = 0` happens to give `[1, 1]`, the right answer);
* `eval_weights(ρ, d)`: `[ONE, Π ρ_j]`, then for each `ρ_j` its powers `ρ_j^1, …, ρ_j^d`;
* `total` and `eval` (after its length assertion): `Σ w_i·c_i` from `ZERO` (`dot`);
* `round(j, prev)` (after its length assertion): `base = a_0 + Σ_{i<j} u(i, prev_i) + Σ_{j<i<N} u(i, 1)·2⁻¹`
  (`mul_base(Fp::new(2).inv())`), `scale = from_u64(1 << (N − 1 − j))`, `P = Π prev`; the value at `x = 0..d` is
  `scale·(base + u(j, x)) + a'·P·x`;
* `CfsMasker::mask_round`: `s_x + c·g_x`; `extension_round(fin, ext, d, poly)`: `poly(fin_t + x·(ext_t − fin_t))` at
  `x = 0..d`; `masked_terminal(fin, ext, ρ) = fin + ρ·(ext − fin)`.

What is proved (only `propext`, `Classical.choice`, `Quot.sound`), under `toK U` into any field `K ⊇ GF` with
`U² = 7`, with `coeffsK` reading the code's layout as `HidingSumcheckJoint.lean`'s `CfsCoeffs K n d` (`N = n + 1`):
* `cubeSum_cfsEval`: in ANY field, the mask polynomial's sum over the cube is `cfsTotal` (`2^N a_0 + a' + 2^(N−1)
  Σ a_{j,e}`);
* **`toK_total`**, `toK_total_eq_cubeSum` (`N < 64`): `<coeffs, sum_weights(N, d)>` is `cfsTotal`, hence the cube
  sum of `g`;
* **`toK_evalDot`**, `toK_eval`: `<coeffs, eval_weights(ρ, d)>` is `cfsEval`, i.e. `g(ρ)` (no canonical premise);
* **`toK_roundBody`** (`1 ≤ d < 2^64`, `N < 64`, a canonical `a_0`): `round(j, prev)` at `x` is
  `peval (cfsMaskRound a r j) x` for every `r` that agrees with `prev` before `j`; so (`cfsMask_roundSum_zero`,
  `cfsMask_roundSum_succ`, `cfsMask_terminal`) the code's mask rounds are a consistent sumcheck of `g`, and
  (`toK_maskRound`) the masked message is `s_x + c·g_j(x)`, the value form of `cfsView`'s round message;
* `interpEval_peval`: interpolating the values at `0, …, d` of a polynomial of degree `≤ d` gives the polynomial
  (`d < char`), the bridge from the model's coefficient form to the code's value form; with it,
  **`round_chain_zero`**, **`round_chain_succ`**, **`round_chain_terminal`** (`1 ≤ d < p`, `N < 64`): the code's mask
  rounds pass the code's verifier's chain checks (round 0 sums to `total`, round `j + 1` sums to the interpolation of
  round `j` at `ρ_j`, the last ends at `g(ρ)`), the mask part of the masked prover's completeness;
* **`toK_maskedTerminal`**, **`toK_extensionRound`**: `masked_terminal` is `HidingSumcheckJoint.lean`'s
  `maskedTerminal` and `extension_round` is `extRoundFun` (for any `poly` the program's `poly` computes);
* **`extension_fe_round`**, **`extension_fe_terminal`**: the code's extension round, with `ext = R̃(ρ)` for a private
  table and `0` for a public one, IS the last round polynomial of `SoundSumcheck.lean`'s `fe` (`extension_halves`) at
  the challenge point, and the verifier's terminal `poly(masked terminals, (1 − ρ_k)·public)` is `fe(ρ, ρ_k)`.
-/
import ZK60Formal.ExecMle
import ZK60Formal.HidingSumcheckJoint

namespace ZK60.Exec

open ZK60.Circuit (gP GF)
open ZK60.Sound
open Finset

namespace Cfs

/-! ## The program -/

/-- `CfsMask::len`. -/
def len (nVars degree : ℕ) : ℕ := nVars * degree + 2

/-- `CfsMask::a(j, e)`. -/
def coef (coeffs : List Fp2) (degree j e : ℕ) : Fp2 := coeffs.getD (2 + j * degree + (e - 1)) Fp2.zero

/-- One step of `CfsMask::u`'s loop: `xp ← xp·x`, `acc ← acc + a(j, e)·xp`. -/
def uStep (coeffs : List Fp2) (degree j : ℕ) (x : Fp2) (st : Fp2 × Fp2) (e : ℕ) : Fp2 × Fp2 :=
  let xp := st.2.mul x
  (st.1.add ((coef coeffs degree j e).mul xp), xp)

/-- `CfsMask::u(j, x)`. -/
def u (coeffs : List Fp2) (degree j : ℕ) (x : Fp2) : Fp2 :=
  ((List.range' 1 degree).foldl (uStep coeffs degree j x) (Fp2.zero, Fp2.one)).1

/-- `1u64 << s` (the release build: the shift amount mod 64). -/
def shl1 (s : UInt64) : UInt64 := (1 : UInt64) <<< s

/-- **`CfsMask::sum_weights`**. -/
def sumWeights (nVars degree : ℕ) : List Fp2 :=
  ((List.replicate (len nVars degree) (Fp2.fromU64 (shl1 (UInt64.ofNat nVars - 1)))).set 0
    (Fp2.fromU64 (shl1 (UInt64.ofNat nVars)))).set 1 Fp2.one

/-- `eval_weights`' inner loop: the powers `r^1, …, r^k` of `r` (times `xp`). -/
def powers (r : Fp2) : ℕ → Fp2 → List Fp2
  | 0, _ => []
  | k + 1, xp => xp.mul r :: powers r k (xp.mul r)

/-- **`CfsMask::eval_weights`**. -/
def evalWeights (rho : List Fp2) (degree : ℕ) : List Fp2 :=
  Fp2.one :: rho.foldl (fun a r => a.mul r) Fp2.one :: rho.flatMap (fun r => powers r degree Fp2.one)

/-- `total`'s and `eval`'s fold: `Σ w_i·c_i`. -/
def dot (w c : List Fp2) : Fp2 := (w.zip c).foldl (fun acc p => acc.add (p.1.mul p.2)) Fp2.zero

/-- **`CfsMask::total`**. -/
def total (nVars degree : ℕ) (coeffs : List Fp2) : Fp2 := dot (sumWeights nVars degree) coeffs

/-- **`CfsMask::eval`**, its length assertion as a refusal. -/
def eval (nVars degree : ℕ) (coeffs rho : List Fp2) : Option Fp2 :=
  if rho.length = nVars then some (dot (evalWeights rho degree) coeffs) else none

/-- `round`'s first loop: `base ← base + u(i, prev_i)` over `prev.iter().enumerate()`. -/
def addPrev (coeffs : List Fp2) (degree : ℕ) : ℕ → Fp2 → List Fp2 → Fp2
  | _, b, [] => b
  | i, b, r :: rs => addPrev coeffs degree (i + 1) (b.add (u coeffs degree i r)) rs

/-- `CfsMask::round(j, prev)`'s body. -/
def roundBody (nVars degree : ℕ) (coeffs : List Fp2) (j : ℕ) (prev : List Fp2) : List Fp2 :=
  let half := (Fp.new 2).inv
  let base := addPrev coeffs degree 0 (coeffs.getD 0 Fp2.zero) prev
  let base := (List.range' (j + 1) (nVars - (j + 1))).foldl
    (fun b i => b.add ((u coeffs degree i Fp2.one).mulBase half)) base
  let scale := Fp2.fromU64 (shl1 (UInt64.ofNat nVars - 1 - UInt64.ofNat j))
  let prodPrev := prev.foldl (fun a r => a.mul r) Fp2.one
  (List.range (degree + 1)).map fun x =>
    let xv := Fp2.fromU64 (UInt64.ofNat x)
    (scale.mul (base.add (u coeffs degree j xv))).add (((coeffs.getD 1 Fp2.zero).mul prodPrev).mul xv)

/-- **`CfsMask::round`**, its length assertion as a refusal. -/
def round (nVars degree : ℕ) (coeffs : List Fp2) (j : ℕ) (prev : List Fp2) : Option (List Fp2) :=
  if prev.length = j then some (roundBody nVars degree coeffs j prev) else none

/-- **`CfsMasker::mask_round`** (after its length assertion): `s_x + c·g_x`. -/
def maskRound (sums g : List Fp2) (c : Fp2) : List Fp2 := (sums.zip g).map (fun p => p.1.add (c.mul p.2))

/-- `extension_round`'s body (after its length assertion). -/
def extensionRoundBody (finals exts : List Fp2) (degree : ℕ) (poly : List Fp2 → Fp2) : List Fp2 :=
  (List.range (degree + 1)).map fun x =>
    let xv := Fp2.fromU64 (UInt64.ofNat x)
    poly ((finals.zip exts).map (fun p => p.1.add (xv.mul (p.2.sub p.1))))

/-- **`sumcheck::extension_round`**, its length assertion as a refusal. -/
def extensionRound (finals exts : List Fp2) (degree : ℕ) (poly : List Fp2 → Fp2) : Option (List Fp2) :=
  if finals.length = exts.length then some (extensionRoundBody finals exts degree poly) else none

/-- **`sumcheck::masked_terminal`**. -/
def maskedTerminal (fin ext rho : Fp2) : Fp2 := fin.add (rho.mul (ext.sub fin))

end Cfs

/-! ## The model's reading of the code's layout -/

/-- The code's coefficient list as `HidingSumcheckJoint.lean`'s `CfsCoeffs K n d` (`N = n + 1` variables). -/
def coeffsK {K : Type} [Field K] [Algebra GF K] (U : K) (n d : ℕ) (c : List Fp2) : ZK60.Hiding.CfsCoeffs K n d :=
  ((c.getD 0 Fp2.zero).toK U, (c.getD 1 Fp2.zero).toK U, fun j e => (c.getD (2 + (j : ℕ) * d + (e : ℕ)) Fp2.zero).toK U)

/-! ## The cube sum of the mask, in any field -/

section Cube

variable {F : Type} [Field F]

theorem bit_pow_succ (b : Bool) (e : ℕ) : (bit b : F) ^ (e + 1) = bit b := by
  cases b <;> simp [bit]

theorem sum_cube_prod_bit (N : ℕ) : ∑ b : Fin N → Bool, ∏ j, (bit (b j) : F) = 1 := by
  rw [← Fintype.prod_sum (fun _ x => (bit x : F))]
  simp [bit]

theorem sum_cube_bit (N : ℕ) (j : Fin (N + 1)) : ∑ b : Fin (N + 1) → Bool, (bit (b j) : F) = 2 ^ N := by
  have h1 : ∀ b : Fin (N + 1) → Bool, (bit (b j) : F) = ∏ i, (if i = j then (bit (b i) : F) else 1) := by
    intro b
    rw [Finset.prod_ite_eq' univ j (fun i => (bit (b i) : F))]
    simp
  rw [Finset.sum_congr rfl (fun b _ => h1 b), ← Fintype.prod_sum (fun i x => if i = j then (bit x : F) else 1)]
  have h2 : ∀ i : Fin (N + 1), ∑ x : Bool, (if i = j then (bit x : F) else 1) = if i = j then 1 else 2 := by
    intro i
    split_ifs
    · simp [bit]
    · rw [Fintype.sum_bool]
      norm_num
  rw [Finset.prod_congr rfl (fun i _ => h2 i), ← Finset.mul_prod_erase univ (fun i => if i = j then (1 : F) else 2)
    (mem_univ j), ite_eq_left rfl, one_mul]
  rw [Finset.prod_congr rfl (fun i hi => ite_eq_right (Finset.ne_of_mem_erase hi)), Finset.prod_const,
    Finset.card_erase_of_mem (mem_univ j), card_univ, Fintype.card_fin, Nat.add_sub_cancel]

/-- **The mask's sum over the cube is `cfsTotal`**: `Σ_{x ∈ {0,1}^N} g(x) = 2^N a_0 + a' + 2^(N−1) Σ a_{j,e}`. -/
theorem cubeSum_cfsEval {n d : ℕ} (a : ZK60.Hiding.CfsCoeffs F n d) :
    cubeSum (fun x => ZK60.Hiding.cfsEval a x) = ZK60.Hiding.cfsTotal a := by
  simp only [cubeSum, ZK60.Hiding.cfsEval, ZK60.Hiding.cfsTotal]
  rw [Finset.sum_add_distrib, Finset.sum_add_distrib, Finset.sum_const, Finset.card_univ, Fintype.card_fun,
    Fintype.card_bool, Fintype.card_fin, nsmul_eq_mul, ← Finset.mul_sum, sum_cube_prod_bit]
  have h3 : ∑ x : Fin (n + 1) → Bool, ∑ j, ∑ e : Fin d, a.2.2 j e * (bit (x j) : F) ^ ((e : ℕ) + 1)
      = 2 ^ n * ∑ j, ∑ e, a.2.2 j e := by
    simp only [bit_pow_succ]
    rw [Finset.sum_comm, Finset.mul_sum]
    refine Finset.sum_congr rfl (fun j _ => ?_)
    rw [Finset.sum_comm, Finset.mul_sum]
    refine Finset.sum_congr rfl (fun e _ => ?_)
    rw [← Finset.mul_sum, sum_cube_bit]
    ring
  rw [h3]
  push_cast
  ring

end Cube

/-! ## Weights and dots -/

section Weights

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem list_sum_map_getD {α M : Type} [AddCommMonoid M] (f : α → M) (dflt : α) :
    ∀ l : List α, (l.map f).sum = ∑ k ∈ range l.length, f (l.getD k dflt)
  | [] => by simp
  | a :: l => by
    rw [List.map_cons, List.sum_cons, list_sum_map_getD f dflt l, List.length_cons, Finset.sum_range_succ']
    simp only [List.getD_cons_zero, List.getD_cons_succ]
    rw [add_comm]

theorem list_prod_map_getD {α M : Type} [CommMonoid M] (f : α → M) (dflt : α) :
    ∀ l : List α, (l.map f).prod = ∏ k ∈ range l.length, f (l.getD k dflt)
  | [] => by simp
  | a :: l => by
    rw [List.map_cons, List.prod_cons, list_prod_map_getD f dflt l, List.length_cons, Finset.prod_range_succ']
    simp only [List.getD_cons_zero, List.getD_cons_succ]
    rw [mul_comm]

/-- `Σ w_i·c_i`, read in `K` (no canonical input is needed: `mul`'s output is canonical). -/
theorem toK_dot (hU : U ^ 2 = algebraMap GF K 7) (w c : List Fp2) (h : w.length = c.length) :
    (Cfs.dot w c).toK U = ∑ i ∈ range c.length, (w.getD i Fp2.zero).toK U * (c.getD i Fp2.zero).toK U := by
  unfold Cfs.dot
  rw [toK_foldl_add U (fun p : Fp2 × Fp2 => p.1.mul p.2) _ _ Fp2.canon_zero (fun p _ => Fp2.canon_mul _ _),
    Fp2.toK_zero, zero_add,
    list_sum_zip_map (fun a b => (Fp2.mul a b).toK U) Fp2.zero Fp2.zero w c h, h]
  refine Finset.sum_congr rfl (fun i _ => ?_)
  rw [Fp2.toK_mul U hU]

/-- The split of a coefficient vector's index range: `0`, `1`, and the pairs `(j, e)` at `2 + j·d + e`. -/
theorem sum_layout {M : Type} [AddCommMonoid M] (n d : ℕ) (G : ℕ → M) :
    ∑ i ∈ range ((n + 1) * d + 2), G i = G 0 + G 1 + ∑ j : Fin (n + 1), ∑ e : Fin d, G (2 + (j : ℕ) * d + (e : ℕ)) := by
  rw [Finset.sum_range_succ', Finset.sum_range_succ', ← Fin.sum_univ_eq_sum_range (fun i => G (i + 1 + 1)),
    ← (finProdFinEquiv (m := n + 1) (n := d)).sum_comp, Fintype.sum_prod_type]
  rw [add_comm, add_comm (∑ x : Fin (n + 1), _), ← add_assoc]
  congr 1
  refine Finset.sum_congr rfl (fun j _ => Finset.sum_congr rfl (fun e _ => ?_))
  rw [finProdFinEquiv_apply_val]
  congr 1
  ring

theorem shl1_toNat (m : ℕ) (hm : m < 64) : (Cfs.shl1 (UInt64.ofNat m)).toNat = 2 ^ m := by
  unfold Cfs.shl1
  rw [UInt64.toNat_shiftLeft, UInt64.toNat_ofNat', Nat.mod_eq_of_lt (by omega : m < 2 ^ 64),
    Nat.mod_eq_of_lt hm, show (1 : UInt64).toNat = 1 from rfl, Nat.one_shiftLeft,
    Nat.mod_eq_of_lt (Nat.pow_lt_pow_right (by norm_num) hm)]

theorem toK_fromU64_shl1 (m : ℕ) (hm : m < 64) : (Fp2.fromU64 (Cfs.shl1 (UInt64.ofNat m))).toK U = 2 ^ m := by
  rw [Fp2.toK_fromU64, shl1_toNat m hm, Nat.cast_pow, Nat.cast_ofNat]

theorem sumWeights_length (nVars degree : ℕ) : (Cfs.sumWeights nVars degree).length = Cfs.len nVars degree := by
  simp [Cfs.sumWeights]

theorem sumWeights_getD (nVars degree k : ℕ) (hk : k < Cfs.len nVars degree) :
    (Cfs.sumWeights nVars degree).getD k Fp2.zero
      = if k = 1 then Fp2.one else if k = 0 then Fp2.fromU64 (Cfs.shl1 (UInt64.ofNat nVars))
        else Fp2.fromU64 (Cfs.shl1 (UInt64.ofNat nVars - 1)) := by
  have h2 : 2 ≤ Cfs.len nVars degree := by unfold Cfs.len; omega
  unfold Cfs.sumWeights
  rw [List.getD_eq_getElem?_getD, List.getElem?_set, List.getElem?_set]
  simp only [List.length_set, List.length_replicate]
  by_cases h1 : k = 1
  · subst h1
    simp [show 1 < Cfs.len nVars degree by omega]
  · by_cases h0 : k = 0
    · subst h0
      simp [show 0 < Cfs.len nVars degree by omega]
    · simp [h1, h0, Ne.symm h1, Ne.symm h0, hk]

/-- **`<coeffs, sum_weights(N, d)>` is `cfsTotal`** (for `N = n + 1 < 64`): the mask's sum over the cube
(`cubeSum_cfsEval`). `total` is this dot product. -/
theorem toK_total (hU : U ^ 2 = algebraMap GF K 7) (n d : ℕ) (hn : n + 1 < 64) (c : List Fp2)
    (hc : c.length = (n + 1) * d + 2) :
    (Cfs.total (n + 1) d c).toK U = ZK60.Hiding.cfsTotal (coeffsK U n d c) := by
  unfold Cfs.total
  rw [toK_dot U hU _ _ (by rw [sumWeights_length, hc]; rfl), hc, sum_layout]
  have hlen : ∀ k, k < (n + 1) * d + 2 → k < Cfs.len (n + 1) d := fun k hk => by unfold Cfs.len; exact hk
  rw [sumWeights_getD _ _ 0 (hlen 0 (by omega)), sumWeights_getD _ _ 1 (hlen 1 (by omega))]
  simp only [ite_true, one_ne_zero, ite_false, zero_ne_one, Fp2.toK_one, one_mul]
  rw [toK_fromU64_shl1 U (n + 1) hn]
  have hrest : ∀ (j : Fin (n + 1)) (e : Fin d),
      ((Cfs.sumWeights (n + 1) d).getD (2 + (j : ℕ) * d + (e : ℕ)) Fp2.zero).toK U = 2 ^ n := by
    intro j e
    have hj := j.isLt
    have he := e.isLt
    have hb : 2 + (j : ℕ) * d + (e : ℕ) < (n + 1) * d + 2 := by nlinarith
    rw [sumWeights_getD _ _ _ (hlen _ hb), ite_eq_right (by omega), ite_eq_right (by omega),
      show UInt64.ofNat (n + 1) - 1 = UInt64.ofNat n by
        apply UInt64.toNat_inj.mp
        rw [UInt64.toNat_sub_of_le _ _ (by rw [UInt64.le_iff_toNat_le, UInt64.toNat_ofNat']; simp; omega),
          UInt64.toNat_ofNat', UInt64.toNat_ofNat', show (1 : UInt64).toNat = 1 from rfl,
          Nat.mod_eq_of_lt (by omega : n + 1 < 2 ^ 64), Nat.mod_eq_of_lt (by omega : n < 2 ^ 64)]
        omega,
      toK_fromU64_shl1 U n (by omega)]
  simp only [hrest, coeffsK, ZK60.Hiding.cfsTotal, Finset.mul_sum]

/-- The powers `xp·r^1, …, xp·r^k`. -/
theorem powers_spec (hU : U ^ 2 = algebraMap GF K 7) (r : Fp2) :
    ∀ (k : ℕ) (xp : Fp2), (Cfs.powers r k xp).length = k ∧
      ∀ e < k, ((Cfs.powers r k xp).getD e Fp2.zero).toK U = xp.toK U * r.toK U ^ (e + 1)
  | 0, _ => ⟨rfl, fun e he => absurd he (Nat.not_lt_zero e)⟩
  | k + 1, xp => by
    obtain ⟨hl, he⟩ := powers_spec hU r k (xp.mul r)
    refine ⟨by simp [Cfs.powers, hl], fun e hek => ?_⟩
    rcases e with _ | e
    · simp only [Cfs.powers, List.getD_cons_zero, Fp2.toK_mul U hU, zero_add, pow_one]
    · simp only [Cfs.powers, List.getD_cons_succ]
      rw [he e (by omega), Fp2.toK_mul U hU]
      ring

end Weights

theorem powers_length (r : Fp2) : ∀ (k : ℕ) (xp : Fp2), (Cfs.powers r k xp).length = k
  | 0, _ => rfl
  | k + 1, xp => by simp [Cfs.powers, powers_length r k]

theorem flatMap_powers_length (d : ℕ) : ∀ rho : List Fp2,
    (rho.flatMap (fun r => Cfs.powers r d Fp2.one)).length = rho.length * d
  | [] => by simp
  | r :: rho => by
    rw [List.flatMap_cons, List.length_append, flatMap_powers_length d rho, powers_length, List.length_cons]
    ring

theorem evalWeights_length (rho : List Fp2) (d : ℕ) : (Cfs.evalWeights rho d).length = rho.length * d + 2 := by
  unfold Cfs.evalWeights
  rw [List.length_cons, List.length_cons, flatMap_powers_length]

theorem range_getD (x m : ℕ) (h : x < m) : (List.range m).getD x 0 = x := by
  rw [getD_eq_get (List.range m) x 0 (by simpa using h), List.getElem_range]

theorem getD_zip_map {α β γ : Type} (l1 : List α) (l2 : List β) (F : α × β → γ) (d1 : α) (d2 : β) (dz : γ) (i : ℕ)
    (h1 : i < l1.length) (h2 : i < l2.length) :
    ((l1.zip l2).map F).getD i dz = F (l1.getD i d1, l2.getD i d2) := by
  rw [getD_map_lt (l1.zip l2) F (d1, d2) dz i (by simp; omega), getD_eq_get (l1.zip l2) i (d1, d2) (by simp; omega),
    List.getElem_zip, getD_eq_get l1 i d1 h1, getD_eq_get l2 i d2 h2]

theorem sum_filter_lt {M : Type} [AddCommMonoid M] (N : ℕ) (j : Fin N) (G : ℕ → M) :
    ∑ i ∈ univ.filter (fun i : Fin N => i < j), G i = ∑ k ∈ range j, G k := by
  rw [Finset.sum_filter]
  rw [show (∑ i : Fin N, if i < j then G i else 0) = ∑ i : Fin N, (fun k => if k < (j : ℕ) then G k else 0) i from
    Finset.sum_congr rfl (fun i _ => by simp only [Fin.lt_def])]
  rw [Fin.sum_univ_eq_sum_range (fun k => if k < (j : ℕ) then G k else 0) N, ← Finset.sum_filter]
  congr 1
  ext k
  have := j.isLt
  simp only [Finset.mem_filter, Finset.mem_range]
  constructor
  · intro h
    exact h.2
  · intro h
    exact ⟨by omega, h⟩

theorem prod_filter_lt {M : Type} [CommMonoid M] (N : ℕ) (j : Fin N) (G : ℕ → M) :
    ∏ i ∈ univ.filter (fun i : Fin N => i < j), G i = ∏ k ∈ range j, G k := by
  rw [Finset.prod_filter]
  rw [show (∏ i : Fin N, if i < j then G i else 1) = ∏ i : Fin N, (fun k => if k < (j : ℕ) then G k else 1) i from
    Finset.prod_congr rfl (fun i _ => by simp only [Fin.lt_def])]
  rw [Fin.prod_univ_eq_prod_range (fun k => if k < (j : ℕ) then G k else 1) N, ← Finset.prod_filter]
  congr 1
  ext k
  have := j.isLt
  simp only [Finset.mem_filter, Finset.mem_range]
  constructor
  · intro h
    exact h.2
  · intro h
    exact ⟨by omega, h⟩

theorem sum_filter_gt {M : Type} [AddCommMonoid M] (N : ℕ) (j : Fin N) (G : ℕ → M) :
    ∑ i ∈ univ.filter (fun i : Fin N => j < i), G i = ∑ k ∈ range (N - (j + 1)), G (j + 1 + k) := by
  rw [Finset.sum_filter]
  rw [show (∑ i : Fin N, if j < i then G i else 0) = ∑ i : Fin N, (fun k => if (j : ℕ) < k then G k else 0) i from
    Finset.sum_congr rfl (fun i _ => by simp only [Fin.lt_def])]
  rw [Fin.sum_univ_eq_sum_range (fun k => if (j : ℕ) < k then G k else 0) N, ← Finset.sum_filter,
    ← Finset.sum_Ico_eq_sum_range]
  congr 1
  ext k
  simp only [Finset.mem_filter, Finset.mem_range, Finset.mem_Ico]
  constructor
  · intro h
    exact ⟨by omega, h.1⟩
  · intro h
    exact ⟨h.2, by omega⟩

section Rounds

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem flatMap_powers_getD (hU : U ^ 2 = algebraMap GF K 7) (d : ℕ) :
    ∀ (rho : List Fp2) (j e : ℕ), j < rho.length → e < d →
      ((rho.flatMap (fun r => Cfs.powers r d Fp2.one)).getD (j * d + e) Fp2.zero).toK U
        = (rho.getD j Fp2.zero).toK U ^ (e + 1)
  | [], _, _, hj, _ => absurd hj (Nat.not_lt_zero _)
  | r :: rho, 0, e, _, he => by
    rw [List.flatMap_cons, zero_mul, zero_add, getD_append_lt _ _ _ _ (by rw [powers_length]; exact he),
      (powers_spec U hU r d Fp2.one).2 e he, Fp2.toK_one, one_mul, List.getD_cons_zero]
  | r :: rho, j + 1, e, hj, he => by
    rw [List.flatMap_cons, getD_append_ge _ _ _ _ (by rw [powers_length]; nlinarith), powers_length,
      show (j + 1) * d + e - d = j * d + e by rw [add_mul, one_mul]; omega, List.getD_cons_succ]
    exact flatMap_powers_getD hU d rho j e (by simp only [List.length_cons] at hj; omega) he

/-- **`<coeffs, eval_weights(ρ, d)>` is `cfsEval`**, the mask's value `g(ρ)`: `eval` is this dot product. -/
theorem toK_evalDot (hU : U ^ 2 = algebraMap GF K 7) (n d : ℕ) (rho c : List Fp2) (hrho : rho.length = n + 1)
    (hc : c.length = (n + 1) * d + 2) :
    (Cfs.dot (Cfs.evalWeights rho d) c).toK U = ZK60.Hiding.cfsEval (coeffsK U n d c) (vecK U (n + 1) rho) := by
  rw [toK_dot U hU _ _ (by rw [evalWeights_length, hc, hrho]), hc, sum_layout]
  have h0 : ((Cfs.evalWeights rho d).getD 0 Fp2.zero).toK U = 1 := by
    simp [Cfs.evalWeights, Fp2.toK_one]
  have h1 : ((Cfs.evalWeights rho d).getD 1 Fp2.zero).toK U = ∏ j : Fin (n + 1), vecK U (n + 1) rho j := by
    simp only [Cfs.evalWeights, List.getD_cons_succ, List.getD_cons_zero]
    rw [toK_foldl_mul U hU (fun a => a), Fp2.toK_one, one_mul, list_prod_map_getD _ Fp2.zero, hrho,
      ← Fin.prod_univ_eq_prod_range (fun k => (rho.getD k Fp2.zero).toK U)]
    rfl
  have h2 : ∀ (j : Fin (n + 1)) (e : Fin d),
      ((Cfs.evalWeights rho d).getD (2 + (j : ℕ) * d + (e : ℕ)) Fp2.zero).toK U
        = vecK U (n + 1) rho j ^ ((e : ℕ) + 1) := by
    intro j e
    rw [show 2 + (j : ℕ) * d + (e : ℕ) = ((j : ℕ) * d + e) + 1 + 1 by ring]
    simp only [Cfs.evalWeights, List.getD_cons_succ]
    exact flatMap_powers_getD U hU d rho j e (by rw [hrho]; exact j.isLt) e.isLt
  rw [h0, h1, one_mul]
  simp only [coeffsK, ZK60.Hiding.cfsEval]
  congr 1
  · rw [mul_comm]
  · refine Finset.sum_congr rfl (fun j _ => Finset.sum_congr rfl (fun e _ => ?_))
    rw [h2, mul_comm]

theorem uFold_spec (hU : U ^ 2 = algebraMap GF K 7) (c : List Fp2) (d j : ℕ) (x : Fp2) :
    ∀ (m s : ℕ) (acc xp : Fp2), acc.Canon →
      ((List.range' s m).foldl (Cfs.uStep c d j x) (acc, xp)).1.Canon
      ∧ ((List.range' s m).foldl (Cfs.uStep c d j x) (acc, xp)).1.toK U
          = acc.toK U + ∑ t ∈ range m, (Cfs.coef c d j (s + t)).toK U * (xp.toK U * x.toK U ^ (t + 1))
      ∧ ((List.range' s m).foldl (Cfs.uStep c d j x) (acc, xp)).2.toK U = xp.toK U * x.toK U ^ m
  | 0, s, acc, xp, h => by simp [h]
  | m + 1, s, acc, xp, h => by
    rw [List.range'_succ, List.foldl_cons]
    simp only [Cfs.uStep]
    obtain ⟨h1, h2, h3⟩ := uFold_spec hU c d j x m (s + 1) _ (xp.mul x) (Fp2.canon_add _ _)
    refine ⟨h1, ?_, ?_⟩
    · rw [h2, Fp2.toK_add U _ _ h (Fp2.canon_mul _ _), Fp2.toK_mul U hU, Fp2.toK_mul U hU, Finset.sum_range_succ']
      have e : ∀ t ∈ range m, (Cfs.coef c d j (s + 1 + t)).toK U * (xp.toK U * x.toK U * x.toK U ^ (t + 1))
          = (Cfs.coef c d j (s + (t + 1))).toK U * (xp.toK U * x.toK U ^ (t + 1 + 1)) := by
        intro t _
        rw [show s + 1 + t = s + (t + 1) by omega]
        ring
      rw [Finset.sum_congr rfl e, add_zero]
      ring
    · rw [h3, Fp2.toK_mul U hU]
      ring

/-- **`CfsMask::u(j, x)` is `cfsU`** of variable `j`'s coefficients (the code's layout). -/
theorem toK_u (hU : U ^ 2 = algebraMap GF K 7) (c : List Fp2) (d j : ℕ) (x : Fp2) :
    (Cfs.u c d j x).toK U
        = ZK60.Hiding.cfsU (fun e : Fin d => (c.getD (2 + j * d + (e : ℕ)) Fp2.zero).toK U) (x.toK U)
      ∧ (Cfs.u c d j x).Canon := by
  obtain ⟨h1, h2, -⟩ := uFold_spec U hU c d j x d 1 Fp2.zero Fp2.one Fp2.canon_zero
  refine ⟨?_, h1⟩
  unfold Cfs.u
  rw [h2, Fp2.toK_zero, zero_add, Fp2.toK_one, ZK60.Hiding.cfsU,
    ← Fin.sum_univ_eq_sum_range (fun t => (Cfs.coef c d j (1 + t)).toK U * (1 * x.toK U ^ (t + 1))) d]
  refine Finset.sum_congr rfl (fun e _ => ?_)
  simp only [Cfs.coef, one_mul, show 1 + (e : ℕ) - 1 = (e : ℕ) by omega]

theorem addPrev_spec (hU : U ^ 2 = algebraMap GF K 7) (c : List Fp2) (d : ℕ) :
    ∀ (prev : List Fp2) (i : ℕ) (b : Fp2), b.Canon →
      (Cfs.addPrev c d i b prev).Canon ∧ (Cfs.addPrev c d i b prev).toK U
        = b.toK U + ∑ k ∈ range prev.length, (Cfs.u c d (i + k) (prev.getD k Fp2.zero)).toK U
  | [], i, b, h => by simp [Cfs.addPrev, h]
  | r :: prev, i, b, h => by
    obtain ⟨hc, he⟩ := addPrev_spec hU c d prev (i + 1) (b.add (Cfs.u c d i r)) (Fp2.canon_add _ _)
    refine ⟨hc, ?_⟩
    simp only [Cfs.addPrev]
    rw [he, Fp2.toK_add U _ _ h (toK_u U hU c d i r).2, List.length_cons, Finset.sum_range_succ']
    have e : ∀ k ∈ range prev.length, (Cfs.u c d (i + 1 + k) (prev.getD k Fp2.zero)).toK U
        = (Cfs.u c d (i + (k + 1)) ((r :: prev).getD (k + 1) Fp2.zero)).toK U := by
      intro k _
      rw [show i + 1 + k = i + (k + 1) by omega, List.getD_cons_succ]
    rw [Finset.sum_congr rfl e, List.getD_cons_zero, add_zero]
    ring

theorem half_toGF : ((Fp.new 2).inv).toGF = (2 : GF)⁻¹ := by
  rw [Fp.toGF_inv', Fp.toGF_new, show (2 : UInt64).toNat = 2 from rfl, Nat.cast_ofNat]

theorem scale_toNat (n j : ℕ) (hj : j ≤ n) (hn : n + 1 < 64) :
    UInt64.ofNat (n + 1) - 1 - UInt64.ofNat j = UInt64.ofNat (n - j) := by
  apply UInt64.toNat_inj.mp
  have h1 : (1 : UInt64) ≤ UInt64.ofNat (n + 1) := by
    rw [UInt64.le_iff_toNat_le, UInt64.toNat_ofNat', Nat.mod_eq_of_lt (by omega)]
    exact Nat.le_add_left 1 n
  have h2 : UInt64.ofNat (n + 1) - 1 = UInt64.ofNat n := by
    apply UInt64.toNat_inj.mp
    rw [UInt64.toNat_sub_of_le _ _ h1, UInt64.toNat_ofNat', UInt64.toNat_ofNat', Nat.mod_eq_of_lt (by omega),
      Nat.mod_eq_of_lt (by omega), show (1 : UInt64).toNat = 1 from rfl]
    omega
  have h3 : UInt64.ofNat j ≤ UInt64.ofNat n := by
    rw [UInt64.le_iff_toNat_le, UInt64.toNat_ofNat', UInt64.toNat_ofNat', Nat.mod_eq_of_lt (by omega),
      Nat.mod_eq_of_lt (by omega)]
    exact hj
  rw [h2, UInt64.toNat_sub_of_le _ _ h3, UInt64.toNat_ofNat', UInt64.toNat_ofNat', UInt64.toNat_ofNat',
    Nat.mod_eq_of_lt (by omega), Nat.mod_eq_of_lt (by omega), Nat.mod_eq_of_lt (by omega)]

/-- **`CfsMask::round(j, prev)` is the model's mask round** in value form: at `x = 0, …, d`, its value is
`peval (cfsMaskRound a r j) x` for the code's coefficients `a = coeffsK c` and EVERY `r` that agrees with `prev`
before `j` (`cfsMaskRound` reads `r` only there). -/
theorem toK_roundBody (hU : U ^ 2 = algebraMap GF K 7) (n d : ℕ) (hd : 1 ≤ d) (hd64 : d < 2 ^ 64) (hn : n + 1 < 64)
    (c : List Fp2)
    (hc0 : (c.getD 0 Fp2.zero).Canon) (j : Fin (n + 1)) (prev : List Fp2) (hp : prev.length = j)
    (r : Fin (n + 1) → K) (hr : ∀ i : Fin (n + 1), i < j → r i = (prev.getD i Fp2.zero).toK U) (x : ℕ)
    (hx : x ≤ d) :
    ((Cfs.roundBody (n + 1) d c j prev).getD x Fp2.zero).toK U
      = ZK60.Hiding.peval (ZK60.Hiding.cfsMaskRound (coeffsK U n d c) r j) (x : K) := by
  have hjn : (j : ℕ) ≤ n := Nat.lt_succ_iff.mp j.isLt
  rw [ZK60.Hiding.peval_cfsMaskRound hd]
  unfold Cfs.roundBody
  simp only
  rw [getD_map_lt _ _ 0 _ _ (by simp; omega), range_getD x (d + 1) (by omega)]
  obtain ⟨hb1c, hb1⟩ := addPrev_spec U hU c d prev 0 _ hc0
  have hb2 := toK_foldl_add U (fun i => (Cfs.u c d i Fp2.one).mulBase (Fp.new 2).inv)
    (List.range' ((j : ℕ) + 1) (n + 1 - ((j : ℕ) + 1))) (Cfs.addPrev c d 0 (c.getD 0 Fp2.zero) prev) hb1c
    (fun i _ => Fp2.canon_mulBase _ _)
  have hb2c := canon_foldl_add (fun i => (Cfs.u c d i Fp2.one).mulBase (Fp.new 2).inv)
    (List.range' ((j : ℕ) + 1) (n + 1 - ((j : ℕ) + 1))) (Cfs.addPrev c d 0 (c.getD 0 Fp2.zero) prev) hb1c
  obtain ⟨huj, hujc⟩ := toK_u U hU c d j (Fp2.fromU64 (UInt64.ofNat x))
  rw [Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _), Fp2.toK_mul U hU, Fp2.toK_mul U hU,
    Fp2.toK_mul U hU, Fp2.toK_add U _ _ hb2c hujc, hb2, hb1, huj, scale_toNat n j hjn hn,
    toK_fromU64_shl1 U (n - j) (by omega), Fp2.toK_fromU64_ofNat U x (by omega),
    toK_foldl_mul U hU (fun a => a), Fp2.toK_one, one_mul, list_prod_map_getD _ Fp2.zero, hp,
    List.range'_eq_map_range, List.map_map, list_sum_range]
  -- the model's side
  have hbase : ZK60.Hiding.cfsBase (coeffsK U n d c) r j
      = (c.getD 0 Fp2.zero).toK U
        + ∑ k ∈ range j, ZK60.Hiding.cfsU (fun e : Fin d => (c.getD (2 + k * d + (e : ℕ)) Fp2.zero).toK U)
            ((prev.getD k Fp2.zero).toK U)
        + (2 : K)⁻¹ * ∑ k ∈ range (n + 1 - ((j : ℕ) + 1)),
            ZK60.Hiding.cfsU (fun e : Fin d => (c.getD (2 + ((j : ℕ) + 1 + k) * d + (e : ℕ)) Fp2.zero).toK U) 1 := by
    have e1 : ∑ i ∈ univ.filter (fun i : Fin (n + 1) => i < j),
        ZK60.Hiding.cfsU ((coeffsK U n d c).2.2 i) (r i)
          = ∑ i ∈ univ.filter (fun i : Fin (n + 1) => i < j), (fun k => ZK60.Hiding.cfsU
            (fun e : Fin d => (c.getD (2 + k * d + (e : ℕ)) Fp2.zero).toK U) ((prev.getD k Fp2.zero).toK U)) (i : ℕ) := by
      refine Finset.sum_congr rfl (fun i hi => ?_)
      rw [hr i (Finset.mem_filter.mp hi).2]
      rfl
    have e2 : ∑ i ∈ univ.filter (fun i : Fin (n + 1) => j < i), ZK60.Hiding.cfsU ((coeffsK U n d c).2.2 i) 1
        = ∑ i ∈ univ.filter (fun i : Fin (n + 1) => j < i), (fun k => ZK60.Hiding.cfsU
            (fun e : Fin d => (c.getD (2 + k * d + (e : ℕ)) Fp2.zero).toK U) 1) (i : ℕ) := rfl
    unfold ZK60.Hiding.cfsBase
    rw [e1, e2, sum_filter_lt (n + 1) j (fun k => ZK60.Hiding.cfsU
      (fun e : Fin d => (c.getD (2 + k * d + (e : ℕ)) Fp2.zero).toK U) ((prev.getD k Fp2.zero).toK U)),
      sum_filter_gt (n + 1) j (fun k => ZK60.Hiding.cfsU
      (fun e : Fin d => (c.getD (2 + k * d + (e : ℕ)) Fp2.zero).toK U) 1)]
    rfl
  have hpre : ZK60.Hiding.cfsPrefix r j = ∏ k ∈ range j, (prev.getD k Fp2.zero).toK U := by
    unfold ZK60.Hiding.cfsPrefix
    rw [Finset.prod_congr rfl (fun i hi => hr i (Finset.mem_filter.mp hi).2)]
    exact prod_filter_lt (n + 1) j (fun k => (prev.getD k Fp2.zero).toK U)
  rw [hbase, hpre]
  have hsum : ∀ k ∈ range (n + 1 - ((j : ℕ) + 1)),
      (Function.comp (fun i => ((Cfs.u c d i Fp2.one).mulBase (Fp.new 2).inv).toK U) (fun t => (j : ℕ) + 1 + t)) k
        = (2 : K)⁻¹ * ZK60.Hiding.cfsU
            (fun e : Fin d => (c.getD (2 + ((j : ℕ) + 1 + k) * d + (e : ℕ)) Fp2.zero).toK U) 1 := by
    intro k _
    simp only [Function.comp_apply]
    rw [Fp2.toK_mulBase, half_toGF, map_inv₀, map_ofNat, (toK_u U hU c d _ Fp2.one).1, Fp2.toK_one, mul_comm]
  have hpv : ∀ k ∈ range (j : ℕ), (Cfs.u c d (0 + k) (prev.getD k Fp2.zero)).toK U
      = ZK60.Hiding.cfsU (fun e : Fin d => (c.getD (2 + k * d + (e : ℕ)) Fp2.zero).toK U)
          ((prev.getD k Fp2.zero).toK U) := by
    intro k _
    rw [zero_add, (toK_u U hU c d k _).1]
  rw [Finset.sum_congr rfl hsum, Finset.sum_congr rfl hpv, ← Finset.mul_sum]
  simp only [ZK60.Hiding.cfsScale, coeffsK]

/-- **`CfsMasker::mask_round`**: the masked message's value at `x` is `s_x + c·g_j(x)`. -/
theorem toK_maskRound (hU : U ^ 2 = algebraMap GF K 7) (sums g : List Fp2) (c : Fp2) (hs : ∀ a ∈ sums, a.Canon)
    (x : ℕ) (hx1 : x < sums.length) (hx2 : x < g.length) :
    ((Cfs.maskRound sums g c).getD x Fp2.zero).toK U
      = (sums.getD x Fp2.zero).toK U + c.toK U * (g.getD x Fp2.zero).toK U := by
  unfold Cfs.maskRound
  rw [getD_zip_map _ _ _ Fp2.zero Fp2.zero _ _ hx1 hx2]
  simp only
  rw [Fp2.toK_add U _ _ (Fp2.canon_getD hs x) (Fp2.canon_mul _ _), Fp2.toK_mul U hU]

/-- **`masked_terminal` is `HidingSumcheckJoint.lean`'s `maskedTerminal`** on canonical values. -/
theorem toK_maskedTerminal (hU : U ^ 2 = algebraMap GF K 7) (fin ext rho : Fp2) (hf : fin.Canon)
    (he : ext.Canon) :
    (Cfs.maskedTerminal fin ext rho).toK U = ZK60.Hiding.maskedTerminal (fin.toK U) (ext.toK U) (rho.toK U) := by
  unfold Cfs.maskedTerminal ZK60.Hiding.maskedTerminal
  rw [Fp2.toK_add U _ _ hf (Fp2.canon_mul _ _), Fp2.toK_mul U hU, Fp2.toK_sub U _ _ he hf]

/-- **`extension_round` is `extRoundFun`**: for any `poly` that the program's `poly` computes on canonical inputs,
the value at `x = 0, …, d` is `P(fin + x·(ext − fin))`. -/
theorem toK_extensionRound (hU : U ^ 2 = algebraMap GF K 7) (t d : ℕ) (hd64 : d < 2 ^ 64) (P : (Fin t → K) → K)
    (poly : List Fp2 → Fp2)
    (hpoly : ∀ v : List Fp2, v.length = t → (∀ a ∈ v, a.Canon) → (poly v).toK U = P (vecK U t v))
    (finals exts : List Fp2) (hf : finals.length = t) (he : exts.length = t) (hfc : ∀ a ∈ finals, a.Canon)
    (hec : ∀ a ∈ exts, a.Canon) (x : ℕ) (hx : x ≤ d) :
    ((Cfs.extensionRoundBody finals exts d poly).getD x Fp2.zero).toK U
      = ZK60.Hiding.extRoundFun P (vecK U t finals) (vecK U t exts) (x : K) := by
  have hx64 : x < 2 ^ 64 := by omega
  unfold Cfs.extensionRoundBody
  rw [getD_map_lt _ _ 0 _ _ (by simp; omega), range_getD x (d + 1) (by omega)]
  simp only
  set v := (finals.zip exts).map (fun p => p.1.add ((Fp2.fromU64 (UInt64.ofNat x)).mul (p.2.sub p.1)))
  have hvl : v.length = t := by simp [v, hf, he]
  have hvc : ∀ a ∈ v, a.Canon := by
    intro a ha
    obtain ⟨p, _, rfl⟩ := List.mem_map.mp ha
    exact Fp2.canon_add _ _
  rw [hpoly v hvl hvc]
  unfold ZK60.Hiding.extRoundFun
  congr 1
  funext i
  have hi := i.isLt
  unfold vecK
  rw [show v = (finals.zip exts).map (fun p => p.1.add ((Fp2.fromU64 (UInt64.ofNat x)).mul (p.2.sub p.1))) from rfl,
    getD_zip_map _ _ _ Fp2.zero Fp2.zero _ _ (by omega) (by omega)]
  simp only
  rw [Fp2.toK_add U _ _ (Fp2.canon_getD hfc i) (Fp2.canon_mul _ _), Fp2.toK_mul U hU,
    Fp2.toK_sub U _ _ (Fp2.canon_getD hec i) (Fp2.canon_getD hfc i), Fp2.toK_fromU64_ofNat U x hx64]

end Rounds

/-! ## The extension round is the last round of `SoundSumcheck.lean`'s `fe` -/

section Extension

variable {F : Type} [Field F]

/-- `SoundSumcheck.lean`'s extended polynomial (`extension_halves`): private tables `(1 − y)·T + y·R`, public ones
`(1 − y)·Pub`, `y` the trailing variable. -/
def extFe {n k l : ℕ} (poly : (Fin k → F) → (Fin l → F) → F) (T R : Fin k → (Fin n → F) → F)
    (Pub : Fin l → (Fin n → F) → F) (z : Fin (n + 1) → F) : F :=
  poly (fun t => (1 - z (Fin.last n)) * T t (Fin.init z) + z (Fin.last n) * R t (Fin.init z))
    (fun t => (1 - z (Fin.last n)) * Pub t (Fin.init z))

/-- `extFe` is the `fe` of `extension_halves`, so it has the two halves `SoundSumcheck.lean` needs. -/
theorem extFe_halves {n k l : ℕ} (poly : (Fin k → F) → (Fin l → F) → F) (hpoly : ∀ u, poly u 0 = 0)
    (T R : Fin k → (Fin n → F) → F) (Pub : Fin l → (Fin n → F) → F) (x : Fin n → F) :
    extFe poly T R Pub (Fin.snoc x 0) = poly (fun t => T t x) (fun t => Pub t x)
      ∧ extFe poly T R Pub (Fin.snoc x 1) = 0 :=
  extension_halves poly hpoly T R Pub x

/-- **The code's extension round is `fe`'s last round polynomial at the challenge point**: with `fin` the tables'
terminal values (`T(x)`, `Pub(x)`) and `ext` the mask rows' (`R(x)`) for a private table and `0` for a public one,
`poly(fin + X·(ext − fin))` (`extension_round`, `extRoundFun`) is `fe(x, X)`. -/
theorem extension_fe_round {n k l : ℕ} (poly : (Fin k → F) → (Fin l → F) → F) (T R : Fin k → (Fin n → F) → F)
    (Pub : Fin l → (Fin n → F) → F) (x : Fin n → F) (X : F) :
    extFe poly T R Pub (Fin.snoc x X) = poly (fun t => T t x + X * (R t x - T t x)) (fun t => Pub t x + X * (0 - Pub t x)) := by
  simp only [extFe, Fin.snoc_last, Fin.init_snoc]
  congr 1 <;> funext t <;> ring

/-- **The verifier's terminal is `fe` at `(x, ρ_k)`**: `poly` of the masked terminals of the private tables and of
`(1 − ρ_k)·Pub` for the public ones (`masked_terminal` with `ext = 0`; `argument.rs`'s `sel.mul(…)`). -/
theorem extension_fe_terminal {n k l : ℕ} (poly : (Fin k → F) → (Fin l → F) → F) (T R : Fin k → (Fin n → F) → F)
    (Pub : Fin l → (Fin n → F) → F) (x : Fin n → F) (ρ : F) :
    extFe poly T R Pub (Fin.snoc x ρ)
      = poly (fun t => ZK60.Hiding.maskedTerminal (T t x) (R t x) ρ) (fun t => ZK60.Hiding.maskedTerminal (Pub t x) 0 ρ) := by
  simp only [extFe, Fin.snoc_last, Fin.init_snoc, ZK60.Hiding.maskedTerminal]
  congr 1 <;> funext t <;> ring

theorem maskedTerminal_zero (p ρ : F) : ZK60.Hiding.maskedTerminal p 0 ρ = (1 - ρ) * p := by
  unfold ZK60.Hiding.maskedTerminal
  ring

end Extension

/-! ## The value form and the mask's chain, in the code's terms -/

section ValueForm

variable {F : Type} [Field F]

/-- **Interpolating a degree-`≤ d` polynomial's values gives the polynomial** (Lagrange uniqueness at the `d + 1`
distinct nodes, `d < char F`): the verifier's `interpolate_eval` of a message sent in value form is the coefficient
form's `peval`. This is the bridge between `HidingSumcheckJoint.lean`'s coefficient form and the code's value form. -/
theorem interpEval_peval {d : ℕ} (hd : d < ringChar F) (p : Fin (d + 1) → F) (x : F) :
    interpEval (fun i : Fin (d + 1) => ZK60.Hiding.peval p (node d i)) x = ZK60.Hiding.peval p x := by
  classical
  let P : Polynomial F := ∑ e : Fin (d + 1), Polynomial.C (p e) * Polynomial.X ^ (e : ℕ)
  have hP : ∀ y, P.eval y = ZK60.Hiding.peval p y := by
    intro y
    simp [P, ZK60.Hiding.peval, Polynomial.eval_finsetSum]
  have hdeg : P.natDegree ≤ d := by
    refine Polynomial.natDegree_sum_le_of_forall_le _ _ (fun e _ => ?_)
    refine (Polynomial.natDegree_C_mul_le _ _).trans ?_
    rw [Polynomial.natDegree_X_pow]
    exact Nat.lt_succ_iff.mp e.isLt
  have hs : (fun i : Fin (d + 1) => ZK60.Hiding.peval p (node d i)) = fun i => P.eval (node d i) := by
    funext i
    rw [hP]
  have hrp : roundPoly (fun i : Fin (d + 1) => P.eval (node d i)) = P := by
    unfold roundPoly
    symm
    refine Lagrange.eq_interpolate_of_eval_eq (s := Finset.univ) (v := node d) (fun i => P.eval (node d i))
      ((node_injective hd).injOn) ?_ (fun i _ => rfl)
    rw [Finset.card_univ, Fintype.card_fin]
    exact (Polynomial.degree_le_of_natDegree_le hdeg).trans_lt (WithBot.coe_lt_coe.mpr (Nat.lt_succ_self d))
  rw [hs, interpEval_eq, hrp, hP]

end ValueForm

section Chain

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem two_ne_zero_K : (2 : K) ≠ 0 := by
  intro h
  have h2 : ((2 : ℕ) : K) = 0 := by exact_mod_cast h
  have := ringChar.dvd h2
  rw [ringChar_eq_gP] at this
  exact absurd (Nat.le_of_dvd (by norm_num) this) (by rw [Fp.gP_val]; norm_num)

/-- **`total` is the mask's sum over the cube** (`toK_total`, `cubeSum_cfsEval`). -/
theorem toK_total_eq_cubeSum (hU : U ^ 2 = algebraMap GF K 7) (n d : ℕ) (hn : n + 1 < 64) (c : List Fp2)
    (hc : c.length = (n + 1) * d + 2) :
    (Cfs.total (n + 1) d c).toK U = cubeSum (fun x => ZK60.Hiding.cfsEval (coeffsK U n d c) x) := by
  rw [toK_total U hU n d hn c hc, cubeSum_cfsEval]

/-- **`eval` is the mask's value `g(ρ)`** (`toK_evalDot`). -/
theorem toK_eval (hU : U ^ 2 = algebraMap GF K 7) (n d : ℕ) (rho c : List Fp2) (hrho : rho.length = n + 1)
    (hc : c.length = (n + 1) * d + 2) :
    (Cfs.eval (n + 1) d c rho).map (Fp2.toK U) = some (ZK60.Hiding.cfsEval (coeffsK U n d c) (vecK U (n + 1) rho)) := by
  rw [Cfs.eval, ite_eq_left hrho]
  exact congrArg some (toK_evalDot U hU n d rho c hrho hc)

theorem canon_roundBody (nVars d : ℕ) (c : List Fp2) (j : ℕ) (prev : List Fp2) :
    ∀ a ∈ Cfs.roundBody nVars d c j prev, a.Canon := by
  intro a ha
  unfold Cfs.roundBody at ha
  simp only at ha
  obtain ⟨x, _, rfl⟩ := List.mem_map.mp ha
  exact Fp2.canon_add _ _

theorem roundBody_length (nVars d : ℕ) (c : List Fp2) (j : ℕ) (prev : List Fp2) :
    (Cfs.roundBody nVars d c j prev).length = d + 1 := by
  simp [Cfs.roundBody]

/-- **The verifier's interpolation of the code's mask round is the model's `g_j(r_j)`.** -/
theorem toK_interpolate_round (hU : U ^ 2 = algebraMap GF K 7) (n d : ℕ) (hd : 1 ≤ d) (hdp : d < gP)
    (hn : n + 1 < 64) (c : List Fp2) (hc0 : (c.getD 0 Fp2.zero).Canon) (j : Fin (n + 1)) (prev : List Fp2)
    (hp : prev.length = j) (r : Fin (n + 1) → K) (hr : ∀ i : Fin (n + 1), i < j → r i = (prev.getD i Fp2.zero).toK U)
    (rj : Fp2) (hrj : rj.Canon) (hrjr : r j = rj.toK U) :
    (interpolateEval (Cfs.roundBody (n + 1) d c j prev) rj).toK U
      = ZK60.Hiding.peval (ZK60.Hiding.cfsMaskRound (coeffsK U n d c) r j) (r j) := by
  have hd64 : d < 2 ^ 64 := by rw [Fp.gP_val] at hdp; omega
  rw [toK_interpolateEval U hU d hdp _ (roundBody_length _ _ _ _ _) rj hrj, hrjr]
  have hmsg : (fun i : Fin (d + 1) => ((Cfs.roundBody (n + 1) d c j prev).getD i Fp2.zero).toK U)
      = fun i : Fin (d + 1) => ZK60.Hiding.peval (ZK60.Hiding.cfsMaskRound (coeffsK U n d c) r j) (node d i) := by
    funext i
    rw [toK_roundBody U hU n d hd hd64 hn c hc0 j prev hp r hr i (Nat.lt_succ_iff.mp i.isLt)]
    rfl
  rw [hmsg, interpEval_peval (by rw [ringChar_eq_gP]; exact hdp)]

/-- **The code's mask round 0 sums to the code's `total`** (`cfsMask_roundSum_zero`): the masked prover's round-0
check `s(0) + s(1) = S + c·G` holds for the mask part. -/
theorem round_chain_zero (hU : U ^ 2 = algebraMap GF K 7) (n d : ℕ) (hd : 1 ≤ d) (hd64 : d < 2 ^ 64)
    (hn : n + 1 < 64) (c : List Fp2) (hc : c.length = (n + 1) * d + 2) (hc0 : (c.getD 0 Fp2.zero).Canon) :
    ((Cfs.roundBody (n + 1) d c 0 []).getD 0 Fp2.zero).toK U + ((Cfs.roundBody (n + 1) d c 0 []).getD 1 Fp2.zero).toK U
      = (Cfs.total (n + 1) d c).toK U := by
  have hr : ∀ i : Fin (n + 1), i < 0 → (0 : K) = (([] : List Fp2).getD i Fp2.zero).toK U :=
    fun i hi => absurd hi (Fin.not_lt_zero i)
  have h0 := toK_roundBody U hU n d hd hd64 hn c hc0 0 [] (by simp) (fun _ => 0) hr 0 (Nat.zero_le _)
  have h1 := toK_roundBody U hU n d hd hd64 hn c hc0 0 [] (by simp) (fun _ => 0) hr 1 hd
  rw [Fin.val_zero] at h0 h1
  rw [h0, h1, toK_total U hU n d hn c hc, ← ZK60.Hiding.cfsMask_roundSum_zero hd (two_ne_zero_K (K := K))
    (coeffsK U n d c) (fun _ => 0), ZK60.Hiding.roundSum, Nat.cast_zero, Nat.cast_one]

/-- **The code's mask round `j + 1` sums to the verifier's interpolation of round `j` at `r_j`**
(`cfsMask_roundSum_succ`): the masked prover's later round checks hold for the mask part. -/
theorem round_chain_succ (hU : U ^ 2 = algebraMap GF K 7) (n d : ℕ) (hd : 1 ≤ d) (hdp : d < gP) (hn : n + 1 < 64)
    (c : List Fp2) (hc0 : (c.getD 0 Fp2.zero).Canon) (j : Fin n) (prev : List Fp2) (hp : prev.length = j)
    (rj : Fp2) (hrj : rj.Canon) :
    ((Cfs.roundBody (n + 1) d c (j.succ : Fin (n + 1)) (prev ++ [rj])).getD 0 Fp2.zero).toK U
        + ((Cfs.roundBody (n + 1) d c (j.succ : Fin (n + 1)) (prev ++ [rj])).getD 1 Fp2.zero).toK U
      = (interpolateEval (Cfs.roundBody (n + 1) d c (j.castSucc : Fin (n + 1)) prev) rj).toK U := by
  have hd64 : d < 2 ^ 64 := by rw [Fp.gP_val] at hdp; omega
  let r : Fin (n + 1) → K := fun i => ((prev ++ [rj]).getD i Fp2.zero).toK U
  have hl : (prev ++ [rj]).length = (j.succ : Fin (n + 1)) := by
    rw [List.length_append, hp, Fin.val_succ, List.length_singleton]
  have hr1 : ∀ i : Fin (n + 1), i < j.succ → r i = ((prev ++ [rj]).getD i Fp2.zero).toK U := fun _ _ => rfl
  have hr0 : ∀ i : Fin (n + 1), i < j.castSucc → r i = (prev.getD i Fp2.zero).toK U := by
    intro i hi
    have hi' : (i : ℕ) < prev.length := by rw [hp]; exact hi
    show ((prev ++ [rj]).getD i Fp2.zero).toK U = _
    rw [getD_append_lt _ _ _ _ hi']
  have hrj' : r j.castSucc = rj.toK U := by
    show ((prev ++ [rj]).getD (j.castSucc : Fin (n + 1)) Fp2.zero).toK U = _
    rw [getD_append_ge _ _ _ _ (by rw [hp, Fin.val_castSucc]), hp, Fin.val_castSucc, Nat.sub_self,
      List.getD_cons_zero]
  have h0 := toK_roundBody U hU n d hd hd64 hn c hc0 j.succ (prev ++ [rj]) hl r hr1 0 (Nat.zero_le _)
  have h1 := toK_roundBody U hU n d hd hd64 hn c hc0 j.succ (prev ++ [rj]) hl r hr1 1 hd
  rw [h0, h1, toK_interpolate_round U hU n d hd hdp hn c hc0 j.castSucc prev (by rw [hp, Fin.val_castSucc]) r hr0 rj
    hrj hrj', ← ZK60.Hiding.cfsMask_roundSum_succ hd (two_ne_zero_K (K := K)) (coeffsK U n d c) r j,
    ZK60.Hiding.roundSum, Nat.cast_zero, Nat.cast_one]

/-- **The code's last mask round ends at the code's `eval`** (`cfsMask_terminal`): the verifier's interpolation of
round `N − 1` at `ρ_{N−1}` is `g(ρ)`. -/
theorem round_chain_terminal (hU : U ^ 2 = algebraMap GF K 7) (n d : ℕ) (hd : 1 ≤ d) (hdp : d < gP)
    (hn : n + 1 < 64) (c : List Fp2) (hc : c.length = (n + 1) * d + 2) (hc0 : (c.getD 0 Fp2.zero).Canon)
    (rho : List Fp2) (hrho : rho.length = n + 1) (hrc : ∀ a ∈ rho, a.Canon) :
    (interpolateEval (Cfs.roundBody (n + 1) d c n (rho.take n)) (rho.getD n Fp2.zero)).toK U
      = (Cfs.dot (Cfs.evalWeights rho d) c).toK U := by
  have hlast : ((Fin.last n : Fin (n + 1)) : ℕ) = n := Fin.val_last n
  have hr : ∀ i : Fin (n + 1), i < Fin.last n → vecK U (n + 1) rho i = ((rho.take n).getD i Fp2.zero).toK U := by
    intro i hi
    have hi' : (i : ℕ) < n := hi
    unfold vecK
    rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_take, ite_eq_left hi']
  have h := toK_interpolate_round U hU n d hd hdp hn c hc0 (Fin.last n) (rho.take n)
    (by rw [List.length_take, hrho, hlast]; omega) (vecK U (n + 1) rho) hr (rho.getD n Fp2.zero)
    (Fp2.canon_getD hrc n) (by unfold vecK; rw [hlast])
  rw [hlast] at h
  rw [h, ZK60.Hiding.cfsMask_terminal hd, toK_evalDot U hU n d rho c hrho hc]

end Chain

end ZK60.Exec
