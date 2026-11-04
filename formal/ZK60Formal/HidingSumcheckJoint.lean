/-
D63, step L4 (zero knowledge): the masked sumcheck over ALL its rounds (the CFS / Libra joint lemma), with the last-
round extension.

What the code computes (`zkp-core/src/sumcheck.rs`, `CfsMask`; `hashline/src/private_block/argument.rs`, `run_slot`;
`hashline/src/zk.rs`, `masked_prove_rounds` and `extension`). One slot of the private block is a sumcheck over
`N = n_vars + ext` variables (`ext` trailing extension variables, 1 or 2):
* the mask `g(x) = a_0 + a'·∏_j x_j + Σ_j Σ_{e=1..d} a_{j,e} x_j^e` has `N·d + 2` uniform `Fp2` coefficients
  (`CfsMask::random`);
* a verifier challenge `c`, refused when zero (`run_slot`: "zero CFS mask challenge; discard attempt");
* round `j` sends `s_j + c·g_j` at `X = 0..d`, where `s_j` is the unmasked round polynomial (the rounds of the
  original sumcheck for `j < n_vars`, then the extension rounds `s_k(X) = poly((1 − X)·fin + X·ext)`,
  `extension_round`) and `g_j` is `CfsMask::round(j, prev)` in closed form;
* the total `G = Σ_x g(x)` (`CfsMask::total`, `sum_weights`) enters the scalar: `S + c·G` for a private slot
  (`SlotKind::Private`), `c·G` for a standalone one;
* `g(ρ)` (`CfsMask::eval`, `eval_weights`) is what the verifier recovers from the terminal check
  (`g_val = (fin − poly(vals))/c`) and proves from `M`.

This file proves, at FIXED challenges (honest verifier, before Fiat–Shamir):
* `cfsMask_roundSum_zero`, `cfsMask_roundSum_succ`, `cfsMask_terminal`: the closed forms are a consistent sumcheck of
  `g` (`g_0(0) + g_0(1) = G`, `g_{j+1}(0) + g_{j+1}(1) = g_j(r_j)`, `g_N(r_N) = g(ρ)`), so the honest masked proof
  verifies;
* `cfsView_law_eq`: **the joint law of (`G`, every round message, `g(ρ)`) depends on the unmasked rounds only through
  their chain defects** `(s_0(0) + s_0(1), s_{j+1}(0) + s_{j+1}(1) − s_j(r_j), s_N(r_N))`. For an honest prover these
  are `(S, 0, F)`: the claimed sum and the terminal value (`cfsView_values_law_eq`: the same with the rounds in the
  code's value form, their values at `X = 0..d`);
* `cfsViewMasked_law_eq`: with the scalar sent as `S + c·G` instead of `G` (a private slot), the law does not depend on
  `S` either: only on the terminal value `F`;
* `cfsView_joint_law_eq`, `cfsViewMasked_joint_law_eq`: the same jointly with any other part of the view `X(ω)` that
  is computed from independent coins `ω`, when the defects are a function of `X(ω)`. This is the form that composes
  with the opening lemmas, whose claim values include the masked terminals;
* `extRound_terminal`, `slot_chainDefect`: the extension round's terminal value is `poly(masked terminals)`, and when
  the extension is an identity (`poly(ext) = 0`), a slot whose original rounds are an honest sumcheck has defects
  `(S, 0, poly(masked terminals))`;
* `slot_view_law_eq`: hence a private slot's view depends on its data only through `poly(masked terminals)`.

Hypotheses used, all enforced or structural: `c ≠ 0` (refused); `2 ≠ 0` (Goldilocks is odd); the round degree
`d ≥ 1` (every slot has degree at least 2, `Shape::degree_range`; `CfsMask::round`'s `a'·P·x` term needs it); and,
for the honest defects, that each extension round is an identity, `poly(ext) = 0`. That last one is NOT checked by
the prover; if it fails, the honest proof is rejected by the verifier's round check (a completeness failure that
publishes the defect `poly(ext)`), so every accepted proof satisfies it. The two bilinear slots (`SC_SCORE`, `SC_PV`)
have two extension rounds, one per private factor; `slot_chainDefect` is stated for one, and each extension round's
defect is its own `poly(ext)`.

An observation: the proof never moves `a'` (its coin shift has `Δa' = 0`), so the joint statement holds equally for
the mask WITHOUT `a'`. The code's comment that `a'` is "needed so that BOTH the mask's total G and its terminal g(rho)
are uniform given the round messages" is not what this proof uses; `a'` is harmless.

NOT covered: the challenges' dependence on the transcript (Fiat–Shamir), the refusal bit, and the composition of the
slots (each slot has its own mask; a host slot's scalar combines other slots' totals) with `A`, `H` and `M`.
-/
import ZK60Formal.HidingSumcheck

namespace ZK60.Hiding

open scoped ENNReal

section CfsJoint

variable {K : Type} [Field K]

/-! ## Round polynomials in coefficient form -/

/-- A round polynomial of degree `≤ d` in coefficient form, evaluated at `x`. The code sends the values at
`X = 0..d`, an invertible linear image of the coefficients, so every law statement below holds for them too. -/
def peval {d : ℕ} (p : Fin (d + 1) → K) (x : K) : K := ∑ e, p e * x ^ (e : ℕ)

/-- `p(0) + p(1)`: what the verifier's round check compares with the running claim. -/
def roundSum {d : ℕ} (p : Fin (d + 1) → K) : K := peval p 0 + peval p 1

/-- A round polynomial is its constant coefficient plus its non-constant part. -/
theorem peval_succ_form {d : ℕ} (p : Fin (d + 1) → K) (x : K) :
    peval p x = p 0 + ∑ i : Fin d, p i.succ * x ^ ((i : ℕ) + 1) := by
  unfold peval
  rw [Fin.sum_univ_succ]
  simp

/-- A round polynomial's value at `0` is its constant coefficient. -/
theorem peval_zero {d : ℕ} (p : Fin (d + 1) → K) : peval p 0 = p 0 := by
  rw [peval_succ_form]
  simp

/-- Evaluation is additive: the value of a difference of round polynomials. -/
theorem peval_sub {d : ℕ} (p q : Fin (d + 1) → K) (x : K) : peval (p - q) x = peval p x - peval q x := by
  simp [peval, sub_mul, Finset.sum_sub_distrib]

/-- Evaluation is additive: the value of a sum of round polynomials. -/
theorem peval_add {d : ℕ} (p q : Fin (d + 1) → K) (x : K) : peval (p + q) x = peval p x + peval q x := by
  simp [peval, add_mul, Finset.sum_add_distrib]

/-- Evaluation commutes with scaling by the mask challenge `c`. -/
theorem peval_smul {d : ℕ} (c : K) (p : Fin (d + 1) → K) (x : K) :
    peval (fun e => c * p e) x = c * peval p x := by
  simp [peval, Finset.mul_sum, mul_assoc]

/-! ## The CFS mask, as `CfsMask` computes it -/

/-- The mask's coefficients, relabelled from `CfsMask`'s layout `[a_0, a', a_{0,1..d}, …, a_{N−1,1..d}]`: `a_0`,
`a'`, and `A j e = a_{j,e+1}`, for `N = n + 1` variables. Uniform `CfsMask::random` coefficients are the uniform law on
this product type. -/
abbrev CfsCoeffs (K : Type) (n d : ℕ) := K × K × (Fin (n + 1) → Fin d → K)

/-- `u_j(x) = Σ_{e=1..d} a_{j,e} x^e` (`CfsMask::u`). -/
def cfsU {d : ℕ} (aj : Fin d → K) (x : K) : K := ∑ e : Fin d, aj e * x ^ ((e : ℕ) + 1)

/-- `base_j = a_0 + Σ_{i<j} u_i(r_i) + Σ_{i>j} u_i(1)/2` (`CfsMask::round`). -/
def cfsBase {n d : ℕ} (a : CfsCoeffs K n d) (r : Fin (n + 1) → K) (j : Fin (n + 1)) : K :=
  a.1 + ∑ i ∈ Finset.univ.filter (· < j), cfsU (a.2.2 i) (r i)
    + (2 : K)⁻¹ * ∑ i ∈ Finset.univ.filter (j < ·), cfsU (a.2.2 i) 1

/-- `κ_j = 2^(N−1−j)`, `N = n + 1`. -/
def cfsScale (n : ℕ) (j : Fin (n + 1)) : K := 2 ^ (n - (j : ℕ))

/-- `P_j = ∏_{i<j} r_i`. -/
def cfsPrefix {n : ℕ} (r : Fin (n + 1) → K) (j : Fin (n + 1)) : K := ∏ i ∈ Finset.univ.filter (· < j), r i

/-- The mask's round-`j` polynomial (`CfsMask::round(j, prev)`), in coefficient form (`cfsRoundCoeffs`). -/
def cfsMaskRound {n d : ℕ} (a : CfsCoeffs K n d) (r : Fin (n + 1) → K) (j : Fin (n + 1)) : Fin (d + 1) → K :=
  cfsRoundCoeffs (cfsScale n j) (cfsBase a r j) a.2.1 (cfsPrefix r j) (a.2.2 j)

/-- `G = Σ_x g(x) = 2^N a_0 + a' + 2^(N−1) Σ a_{j,e}` (`CfsMask::sum_weights`, `total`). -/
def cfsTotal {n d : ℕ} (a : CfsCoeffs K n d) : K :=
  2 ^ (n + 1) * a.1 + a.2.1 + 2 ^ n * ∑ j, ∑ e, a.2.2 j e

/-- `g(ρ) = a_0 + a'·∏ ρ_j + Σ_j Σ_e a_{j,e} ρ_j^e` (`CfsMask::eval_weights`, `eval`). -/
def cfsEval {n d : ℕ} (a : CfsCoeffs K n d) (r : Fin (n + 1) → K) : K :=
  a.1 + a.2.1 * ∏ j, r j + ∑ j, ∑ e, a.2.2 j e * r j ^ ((e : ℕ) + 1)

/-- What the verifier sees of one masked sumcheck, at fixed challenges `r`: the mask total `G`, every round message
`s_j + c·g_j`, and `g(ρ)`. -/
def cfsView {n d : ℕ} (s : Fin (n + 1) → Fin (d + 1) → K) (c : K) (r : Fin (n + 1) → K)
    (a : CfsCoeffs K n d) : K × (Fin (n + 1) → Fin (d + 1) → K) × K :=
  (cfsTotal a, fun j e => s j e + c * cfsMaskRound a r j e, cfsEval a r)

/-- The same with the scalar the private block sends for a private slot: `S + c·G`, with `S = s_0(0) + s_0(1)` the
unmasked claimed sum. -/
def cfsViewMasked {n d : ℕ} (s : Fin (n + 1) → Fin (d + 1) → K) (c : K) (r : Fin (n + 1) → K)
    (a : CfsCoeffs K n d) : K × (Fin (n + 1) → Fin (d + 1) → K) × K :=
  (roundSum (s 0) + c * cfsTotal a, fun j e => s j e + c * cfsMaskRound a r j e, cfsEval a r)

/-- The chain defects of round polynomials `s` at challenges `r`: the round-0 sum, the gaps
`s_{j+1}(0) + s_{j+1}(1) − s_j(r_j)`, and the terminal value `s_N(r_N)`. An honest sumcheck of a true sum `S` with
terminal value `F` has defects `(S, 0, F)`. -/
def chainDefect {n d : ℕ} (s : Fin (n + 1) → Fin (d + 1) → K) (r : Fin (n + 1) → K) :
    K × (Fin n → K) × K :=
  (roundSum (s 0), fun j => roundSum (s j.succ) - peval (s j.castSucc) (r j.castSucc),
    peval (s (Fin.last n)) (r (Fin.last n)))

/-! ## Index bookkeeping -/

/-- No round comes before round `0` (index bookkeeping). -/
theorem filter_lt_zero (n : ℕ) : Finset.univ.filter (fun i : Fin (n + 1) => i < 0) = ∅ :=
  Finset.filter_eq_empty_iff.mpr (fun i _ => Fin.not_lt_zero i)

/-- No round comes after the last round (index bookkeeping). -/
theorem filter_last_lt (n : ℕ) : Finset.univ.filter (fun i : Fin (n + 1) => Fin.last n < i) = ∅ :=
  Finset.filter_eq_empty_iff.mpr (fun i _ => not_lt.mpr (Fin.le_last i))

/-- The rounds before `j + 1` are round `j` and the rounds before it (index bookkeeping). -/
theorem filter_lt_succ {n : ℕ} (j : Fin n) :
    Finset.univ.filter (fun i : Fin (n + 1) => i < j.succ)
      = insert j.castSucc (Finset.univ.filter (fun i : Fin (n + 1) => i < j.castSucc)) := by
  ext i
  simp only [Finset.mem_filter, Finset.mem_univ, true_and, Finset.mem_insert, Fin.lt_def,
    Fin.ext_iff, Fin.val_succ, Fin.val_castSucc]
  omega

/-- The rounds after `j` are round `j + 1` and the rounds after it (index bookkeeping). -/
theorem filter_castSucc_lt {n : ℕ} (j : Fin n) :
    Finset.univ.filter (fun i : Fin (n + 1) => j.castSucc < i)
      = insert j.succ (Finset.univ.filter (fun i : Fin (n + 1) => j.succ < i)) := by
  ext i
  simp only [Finset.mem_filter, Finset.mem_univ, true_and, Finset.mem_insert, Fin.lt_def,
    Fin.ext_iff, Fin.val_succ, Fin.val_castSucc]
  omega

/-- Every round is round `0` or a later one (index bookkeeping). -/
theorem univ_eq_insert_zero (n : ℕ) :
    (Finset.univ : Finset (Fin (n + 1))) = insert 0 (Finset.univ.filter (fun i : Fin (n + 1) => 0 < i)) := by
  ext i
  simp only [Finset.mem_univ, Finset.mem_insert, Finset.mem_filter, true_and, true_iff]
  rcases Fin.eq_zero_or_eq_succ i with h | ⟨k, rfl⟩
  · exact Or.inl h
  · exact Or.inr (Fin.succ_pos k)

/-- Every round is the last round or an earlier one (index bookkeeping). -/
theorem univ_eq_insert_last (n : ℕ) :
    (Finset.univ : Finset (Fin (n + 1)))
      = insert (Fin.last n) (Finset.univ.filter (fun i : Fin (n + 1) => i < Fin.last n)) := by
  ext i
  simp only [Finset.mem_univ, Finset.mem_insert, Finset.mem_filter, true_and, true_iff]
  rcases (Fin.le_last i).eq_or_lt with h | h
  · exact Or.inl h
  · exact Or.inr h

/-- A sum over all rounds splits off round `0` (index bookkeeping). -/
theorem sum_univ_zero_add {M : Type} [AddCommMonoid M] (n : ℕ) (f : Fin (n + 1) → M) :
    ∑ i, f i = f 0 + ∑ i ∈ Finset.univ.filter (fun i : Fin (n + 1) => 0 < i), f i := by
  have h1 : (0 : Fin (n + 1)) ∉ Finset.univ.filter (fun i : Fin (n + 1) => 0 < i) := by simp
  conv_lhs => rw [univ_eq_insert_zero n]
  rw [Finset.sum_insert h1]

/-- A sum over all rounds splits off the last round (index bookkeeping). -/
theorem sum_univ_last_add {M : Type} [AddCommMonoid M] (n : ℕ) (f : Fin (n + 1) → M) :
    ∑ i, f i = f (Fin.last n) + ∑ i ∈ Finset.univ.filter (fun i : Fin (n + 1) => i < Fin.last n), f i := by
  have h1 : Fin.last n ∉ Finset.univ.filter (fun i : Fin (n + 1) => i < Fin.last n) := by simp
  conv_lhs => rw [univ_eq_insert_last n]
  rw [Finset.sum_insert h1]

/-! ## The closed forms -/

/-- `u_j(0) = 0`: the per-variable part of the mask has no constant term. -/
theorem cfsU_zero {d : ℕ} (aj : Fin d → K) : cfsU aj 0 = 0 := by
  simp [cfsU]

/-- `u_j(1)` is the sum of the variable's coefficients (what `sum_weights` weighs by `2^(N−1)`). -/
theorem cfsU_one {d : ℕ} (aj : Fin d → K) : cfsU aj 1 = ∑ e, aj e := by
  simp [cfsU]

/-- `u_j` is additive in the mask coefficients. -/
theorem cfsU_add {d : ℕ} (aj bj : Fin d → K) (x : K) : cfsU (aj + bj) x = cfsU aj x + cfsU bj x := by
  simp [cfsU, add_mul, Finset.sum_add_distrib]

/-- **`CfsMask::round` in value form.** The coefficient form `cfsRoundCoeffs` evaluates to the code's
`κ·(base + u_j(x)) + a'·P·x` (for round degree `d ≥ 1`). -/
theorem peval_cfsRoundCoeffs {d : ℕ} (hd : 1 ≤ d) (κ base a' P : K) (aj : Fin d → K) (x : K) :
    peval (cfsRoundCoeffs κ base a' P aj) x = κ * (base + cfsU aj x) + a' * P * x := by
  rw [peval_succ_form]
  have h0 : cfsRoundCoeffs κ base a' P aj 0 = κ * base := by simp [cfsRoundCoeffs]
  have hs : ∀ i : Fin d, cfsRoundCoeffs κ base a' P aj i.succ
      = κ * aj i + (if (i : ℕ) + 1 = 1 then a' * P else 0) := by
    intro i
    simp only [cfsRoundCoeffs, Fin.cases_succ, Fin.val_succ]
  simp only [h0, hs, add_mul, Finset.sum_add_distrib]
  have hsingle : ∑ i : Fin d, (if (i : ℕ) + 1 = 1 then a' * P else 0) * x ^ ((i : ℕ) + 1) = a' * P * x := by
    rw [Finset.sum_eq_single (⟨0, hd⟩ : Fin d)]
    · simp
    · intro i _ hi
      have : (i : ℕ) ≠ 0 := fun h => hi (Fin.ext h)
      simp [this]
    · simp
  rw [hsingle, cfsU, mul_add, Finset.mul_sum]
  have : ∀ i : Fin d, κ * aj i * x ^ ((i : ℕ) + 1) = κ * (aj i * x ^ ((i : ℕ) + 1)) := fun i => by ring
  simp only [this]
  ring

/-- The mask's round-`j` polynomial in value form: `κ_j·(base_j + u_j(x)) + a'·P_j·x`. -/
theorem peval_cfsMaskRound {n d : ℕ} (hd : 1 ≤ d) (a : CfsCoeffs K n d) (r : Fin (n + 1) → K)
    (j : Fin (n + 1)) (x : K) :
    peval (cfsMaskRound a r j) x = cfsScale n j * (cfsBase a r j + cfsU (a.2.2 j) x) + a.2.1 * cfsPrefix r j * x :=
  peval_cfsRoundCoeffs hd _ _ _ _ _ x

/-- Round 0's base: `a_0` plus half of every later variable's `u_i(1)`. -/
theorem cfsBase_zero {n d : ℕ} (a : CfsCoeffs K n d) (r : Fin (n + 1) → K) :
    cfsBase a r 0 = a.1 + (2 : K)⁻¹ * ∑ i ∈ Finset.univ.filter (fun i : Fin (n + 1) => 0 < i), cfsU (a.2.2 i) 1 := by
  simp only [cfsBase, filter_lt_zero, Finset.sum_empty, add_zero]

/-- The last round's base: `a_0` plus every earlier variable's `u_i(r_i)`. -/
theorem cfsBase_last {n d : ℕ} (a : CfsCoeffs K n d) (r : Fin (n + 1) → K) :
    cfsBase a r (Fin.last n)
      = a.1 + ∑ i ∈ Finset.univ.filter (fun i : Fin (n + 1) => i < Fin.last n), cfsU (a.2.2 i) (r i) := by
  simp only [cfsBase, filter_last_lt, Finset.sum_empty, mul_zero, add_zero]

/-- The local identity between consecutive rounds: `base_{j+1} = base_j + u_j(r_j) − u_{j+1}(1)/2`. -/
theorem cfsBase_succ {n d : ℕ} (a : CfsCoeffs K n d) (r : Fin (n + 1) → K) (j : Fin n) :
    cfsBase a r j.succ
      = cfsBase a r j.castSucc + cfsU (a.2.2 j.castSucc) (r j.castSucc) - (2 : K)⁻¹ * cfsU (a.2.2 j.succ) 1 := by
  have h1 : j.castSucc ∉ Finset.univ.filter (fun i : Fin (n + 1) => i < j.castSucc) := by simp
  have h2 : j.succ ∉ Finset.univ.filter (fun i : Fin (n + 1) => j.succ < i) := by simp
  unfold cfsBase
  rw [filter_lt_succ, filter_castSucc_lt, Finset.sum_insert h1, Finset.sum_insert h2]
  ring

/-- Consecutive round scales differ by a factor 2: `κ_j = 2·κ_{j+1}`. -/
theorem cfsScale_castSucc {n : ℕ} (j : Fin n) : (cfsScale n j.castSucc : K) = 2 * cfsScale n j.succ := by
  unfold cfsScale
  have : n - ((j.castSucc : Fin (n + 1)) : ℕ) = (n - ((j.succ : Fin (n + 1)) : ℕ)) + 1 := by
    simp only [Fin.val_castSucc, Fin.val_succ]
    omega
  rw [this, pow_succ, mul_comm]

/-- The last round has scale `κ = 1`. -/
theorem cfsScale_last (n : ℕ) : (cfsScale n (Fin.last n) : K) = 1 := by
  simp [cfsScale]

/-- Every round scale `κ_j = 2^(N−1−j)` is nonzero in odd characteristic. -/
theorem cfsScaleAt_ne_zero (h2 : (2 : K) ≠ 0) (n : ℕ) (j : Fin (n + 1)) : (cfsScale n j : K) ≠ 0 :=
  pow_ne_zero _ h2

/-- The challenge prefix product before round 0 is empty: `P_0 = 1`. -/
theorem cfsPrefix_zero {n : ℕ} (r : Fin (n + 1) → K) : cfsPrefix r 0 = 1 := by
  simp only [cfsPrefix, filter_lt_zero, Finset.prod_empty]

/-- The challenge prefix grows by one challenge per round: `P_{j+1} = P_j·r_j`. -/
theorem cfsPrefix_succ {n : ℕ} (r : Fin (n + 1) → K) (j : Fin n) :
    cfsPrefix r j.succ = cfsPrefix r j.castSucc * r j.castSucc := by
  have h1 : j.castSucc ∉ Finset.univ.filter (fun i : Fin (n + 1) => i < j.castSucc) := by simp
  unfold cfsPrefix
  rw [filter_lt_succ, Finset.prod_insert h1, mul_comm]

/-- The last prefix times the last challenge is the product of all challenges (`a'`'s weight in `g(ρ)`). -/
theorem cfsPrefix_last {n : ℕ} (r : Fin (n + 1) → K) :
    cfsPrefix r (Fin.last n) * r (Fin.last n) = ∏ j, r j := by
  have h1 : Fin.last n ∉ Finset.univ.filter (fun i : Fin (n + 1) => i < Fin.last n) := by simp
  rw [univ_eq_insert_last n, Finset.prod_insert h1, cfsPrefix, mul_comm]

/-! ## The mask is a consistent sumcheck of `g` -/

/-- **Round 0 of the mask sums to its total**: `g_0(0) + g_0(1) = G`. -/
theorem cfsMask_roundSum_zero {n d : ℕ} (hd : 1 ≤ d) (h2 : (2 : K) ≠ 0) (a : CfsCoeffs K n d)
    (r : Fin (n + 1) → K) : roundSum (cfsMaskRound a r 0) = cfsTotal a := by
  have hsum : ∑ j, ∑ e, a.2.2 j e
      = cfsU (a.2.2 0) 1 + ∑ i ∈ Finset.univ.filter (fun i : Fin (n + 1) => 0 < i), cfsU (a.2.2 i) 1 := by
    have : ∀ j, ∑ e, a.2.2 j e = cfsU (a.2.2 j) 1 := fun j => (cfsU_one _).symm
    rw [Finset.sum_congr rfl (fun j _ => this j), sum_univ_zero_add n]
  have hκ : (cfsScale n 0 : K) = 2 ^ n := by simp [cfsScale]
  have hi : (2 : K) * 2⁻¹ = 1 := mul_inv_cancel₀ h2
  rw [roundSum, peval_cfsMaskRound hd, peval_cfsMaskRound hd, cfsU_zero, cfsPrefix_zero, cfsBase_zero, hκ,
    cfsTotal, hsum, pow_succ]
  linear_combination (2 ^ n * ∑ i ∈ Finset.univ.filter (fun i : Fin (n + 1) => 0 < i), cfsU (a.2.2 i) 1) * hi

/-- **Consecutive rounds of the mask chain**: `g_{j+1}(0) + g_{j+1}(1) = g_j(r_j)`. -/
theorem cfsMask_roundSum_succ {n d : ℕ} (hd : 1 ≤ d) (h2 : (2 : K) ≠ 0) (a : CfsCoeffs K n d)
    (r : Fin (n + 1) → K) (j : Fin n) :
    roundSum (cfsMaskRound a r j.succ) = peval (cfsMaskRound a r j.castSucc) (r j.castSucc) := by
  have hi : (2 : K) * 2⁻¹ = 1 := mul_inv_cancel₀ h2
  rw [roundSum, peval_cfsMaskRound hd, peval_cfsMaskRound hd, peval_cfsMaskRound hd, cfsU_zero,
    cfsBase_succ, cfsScale_castSucc, cfsPrefix_succ]
  linear_combination (-(cfsScale n j.succ : K) * cfsU (a.2.2 j.succ) 1) * hi

/-- **The last round of the mask ends at `g(ρ)`**: `g_N(r_N) = g(ρ)`. -/
theorem cfsMask_terminal {n d : ℕ} (hd : 1 ≤ d) (a : CfsCoeffs K n d) (r : Fin (n + 1) → K) :
    peval (cfsMaskRound a r (Fin.last n)) (r (Fin.last n)) = cfsEval a r := by
  have hsum : ∑ j, ∑ e, a.2.2 j e * r j ^ ((e : ℕ) + 1)
      = cfsU (a.2.2 (Fin.last n)) (r (Fin.last n))
        + ∑ i ∈ Finset.univ.filter (fun i : Fin (n + 1) => i < Fin.last n), cfsU (a.2.2 i) (r i) := by
    have : ∀ j, ∑ e, a.2.2 j e * r j ^ ((e : ℕ) + 1) = cfsU (a.2.2 j) (r j) := fun j => rfl
    rw [Finset.sum_congr rfl (fun j _ => this j), sum_univ_last_add n]
  rw [peval_cfsMaskRound hd, cfsScale_last, cfsBase_last, cfsEval, hsum, ← cfsPrefix_last r]
  ring

/-! ## Additivity in the coefficients -/

/-- A round polynomial of the mask is additive in its parameters. -/
theorem cfsRoundCoeffs_add {d : ℕ} (κ b b' a' a'' P : K) (aj bj : Fin d → K) :
    cfsRoundCoeffs κ (b + b') (a' + a'') P (aj + bj)
      = cfsRoundCoeffs κ b a' P aj + cfsRoundCoeffs κ b' a'' P bj := by
  funext e
  refine Fin.cases ?_ (fun i => ?_) e
  · simp only [cfsRoundCoeffs, Fin.cases_zero, Pi.add_apply]
    split_ifs <;> ring
  · simp only [cfsRoundCoeffs, Fin.cases_succ, Pi.add_apply]
    split_ifs <;> ring

/-- `base_j` is additive in the mask coefficients. -/
theorem cfsBase_add {n d : ℕ} (a b : CfsCoeffs K n d) (r : Fin (n + 1) → K) (j : Fin (n + 1)) :
    cfsBase (a + b) r j = cfsBase a r j + cfsBase b r j := by
  simp only [cfsBase, Prod.fst_add, Prod.snd_add, Pi.add_apply, cfsU_add, Finset.sum_add_distrib]
  ring

/-- The mask's round polynomials are additive in the mask coefficients. -/
theorem cfsMaskRound_add {n d : ℕ} (a b : CfsCoeffs K n d) (r : Fin (n + 1) → K) (j : Fin (n + 1)) :
    cfsMaskRound (a + b) r j = cfsMaskRound a r j + cfsMaskRound b r j := by
  simp only [cfsMaskRound, cfsBase_add, Prod.snd_add, Pi.add_apply]
  rw [← cfsRoundCoeffs_add]
  rfl

/-- The total `G` is additive in the mask coefficients. -/
theorem cfsTotal_add {n d : ℕ} (a b : CfsCoeffs K n d) : cfsTotal (a + b) = cfsTotal a + cfsTotal b := by
  simp only [cfsTotal, Prod.fst_add, Prod.snd_add, Pi.add_apply, Finset.sum_add_distrib]
  ring

/-- `g(ρ)` is additive in the mask coefficients. -/
theorem cfsEval_add {n d : ℕ} (a b : CfsCoeffs K n d) (r : Fin (n + 1) → K) :
    cfsEval (a + b) r = cfsEval a r + cfsEval b r := by
  simp only [cfsEval, Prod.fst_add, Prod.snd_add, Pi.add_apply, add_mul, Finset.sum_add_distrib]
  ring

/-! ## Solving for the coin shift -/

/-- **Any defect-free difference of round polynomials is the mask's rounds for some coefficients.** Let `δ` be a
family of round polynomials whose middle defects vanish, `δ_{j+1}(0) + δ_{j+1}(1) = δ_j(r_j)` (its round-0 sum and
its terminal are arbitrary). Then some mask coefficients `Δ`, with `Δa' = 0`, have `c·g_j(Δ) = δ_j` for every round.
This is the coin shift behind every law statement below. -/
theorem cfs_solve {n d : ℕ} (h2 : (2 : K) ≠ 0) {c : K} (hc : c ≠ 0) (r : Fin (n + 1) → K)
    (δ : Fin (n + 1) → Fin (d + 1) → K)
    (hmid : ∀ j : Fin n, roundSum (δ j.succ) = peval (δ j.castSucc) (r j.castSucc)) :
    ∃ Δ : CfsCoeffs K n d, Δ.2.1 = 0 ∧ ∀ j e, c * cfsMaskRound Δ r j e = δ j e := by
  have hκ0 : ∀ j, (cfsScale n j : K) ≠ 0 := fun j => cfsScaleAt_ne_zero h2 n j
  have hκ : ∀ j, c * (cfsScale n j : K) ≠ 0 := fun j => mul_ne_zero hc (hκ0 j)
  let ΔA : Fin (n + 1) → Fin d → K := fun j e => δ j e.succ / (c * cfsScale n j)
  let Δ0 : K := δ 0 0 / (c * cfsScale n 0)
    - (2 : K)⁻¹ * ∑ i ∈ Finset.univ.filter (fun i : Fin (n + 1) => 0 < i), cfsU (ΔA i) 1
  let Δ : CfsCoeffs K n d := (Δ0, 0, ΔA)
  have hU : ∀ j x, c * cfsScale n j * cfsU (ΔA j) x = peval (δ j) x - δ j 0 := by
    intro j x
    rw [peval_succ_form, cfsU, Finset.mul_sum]
    simp only [ΔA]
    have : ∀ e : Fin d, c * cfsScale n j * (δ j e.succ / (c * cfsScale n j) * x ^ ((e : ℕ) + 1))
        = δ j e.succ * x ^ ((e : ℕ) + 1) := by
      intro e
      field_simp [hκ j, hκ0 j]
    simp only [this]
    ring
  have hbase : ∀ j, c * cfsScale n j * cfsBase Δ r j = δ j 0 := by
    intro j
    induction j using Fin.induction with
    | zero =>
      rw [cfsBase_zero]
      simp only [Δ, Δ0]
      field_simp [hκ 0, hκ0 0]
      ring
    | succ j ih =>
      rw [cfsBase_succ]
      have hcs : (cfsScale n j.castSucc : K) = 2 * cfsScale n j.succ := cfsScale_castSucc j
      have huc := hU j.castSucc (r j.castSucc)
      have hus := hU j.succ 1
      have hm := hmid j
      rw [roundSum, peval_zero] at hm
      have hi : (2 : K) * 2⁻¹ = 1 := mul_inv_cancel₀ h2
      simp only [Δ] at ih huc hus ⊢
      rw [hcs] at ih huc
      linear_combination (2 : K)⁻¹ * ih + (2 : K)⁻¹ * huc - (2 : K)⁻¹ * hus - (2 : K)⁻¹ * hm
        + (δ j.succ 0 - c * cfsScale n j.succ * cfsBase (Δ0, 0, ΔA) r j.castSucc
          - c * cfsScale n j.succ * cfsU (ΔA j.castSucc) (r j.castSucc)) * hi
  refine ⟨Δ, rfl, fun j e => ?_⟩
  refine Fin.cases ?_ (fun i => ?_) e
  · have := hbase j
    simp only [cfsMaskRound, cfsRoundCoeffs, Fin.cases_zero, Fin.val_zero]
    simp only [Δ] at this ⊢
    simp only [zero_ne_one, ite_false, add_zero]
    rw [← this]
    ring
  · simp only [cfsMaskRound, cfsRoundCoeffs, Fin.cases_succ, Δ, zero_mul, ite_self, add_zero]
    simp only [ΔA]
    field_simp [hκ j, hκ0 j]

/-! ## The joint law -/

/-- The coin shift for the full view: two families of round polynomials with the same chain defects give views that
differ by a fixed translate of the coins. -/
theorem cfsView_shift {n d : ℕ} (hd : 1 ≤ d) (h2 : (2 : K) ≠ 0) {c : K} (hc : c ≠ 0) (r : Fin (n + 1) → K)
    (s s' : Fin (n + 1) → Fin (d + 1) → K) (hdef : chainDefect s r = chainDefect s' r) :
    ∃ Δ : CfsCoeffs K n d, ∀ a, cfsView s c r a = cfsView s' c r (a + Δ) := by
  simp only [chainDefect, Prod.mk.injEq] at hdef
  obtain ⟨h0, hmid, hlast⟩ := hdef
  have hmid' : ∀ j : Fin n, roundSum ((s - s') j.succ) = peval ((s - s') j.castSucc) (r j.castSucc) := by
    intro j
    have := congrFun hmid j
    simp only [roundSum, Pi.sub_apply, peval_sub] at this ⊢
    linear_combination this
  obtain ⟨Δ, _, hΔ⟩ := cfs_solve h2 hc r (s - s') hmid'
  have hround : ∀ j, (fun e => c * cfsMaskRound Δ r j e) = s j - s' j := fun j => funext (hΔ j)
  have hG : cfsTotal Δ = 0 := by
    have e1 := congrArg roundSum (hround 0)
    rw [roundSum, peval_smul, peval_smul, ← mul_add, ← roundSum, cfsMask_roundSum_zero hd h2] at e1
    rw [roundSum, peval_sub, peval_sub] at e1
    rw [roundSum, roundSum] at h0
    have : c * cfsTotal Δ = 0 := by rw [e1]; linear_combination h0
    exact (mul_eq_zero.mp this).resolve_left hc
  have hγ : cfsEval Δ r = 0 := by
    have e1 := congrArg (fun p => peval p (r (Fin.last n))) (hround (Fin.last n))
    simp only [peval_smul, cfsMask_terminal hd, peval_sub] at e1
    have : c * cfsEval Δ r = 0 := by rw [e1]; linear_combination hlast
    exact (mul_eq_zero.mp this).resolve_left hc
  refine ⟨Δ, fun a => ?_⟩
  simp only [cfsView, cfsTotal_add, cfsEval_add, hG, hγ, add_zero, Prod.mk.injEq, true_and, and_true]
  funext j e
  rw [cfsMaskRound_add, Pi.add_apply, mul_add, hΔ j e, Pi.sub_apply, Pi.sub_apply]
  ring

/-- **The masked sumcheck, all rounds jointly: the view depends on the unmasked rounds only through their chain
defects.** Fix the challenges `r` and `c ≠ 0`. If two families of unmasked round polynomials `s`, `s'` have the same
chain defects (the same claimed sum, the same zero gaps, the same terminal value), then the joint law of
(`G`, every round message, `g(ρ)`) over uniform mask coefficients is the same for both. For privacy: an honest
prover's masked rounds, total and `g(ρ)` reveal the data only through the claimed sum `S` and the terminal value `F`.
A simulator knowing `S` and `F` runs the honest masking on ANY round polynomials with those defects. -/
theorem cfsView_law_eq [Fintype K] {n d : ℕ} (hd : 1 ≤ d) (h2 : (2 : K) ≠ 0) {c : K} (hc : c ≠ 0)
    (r : Fin (n + 1) → K) (s s' : Fin (n + 1) → Fin (d + 1) → K)
    (hdef : chainDefect s r = chainDefect s' r) :
    (PMF.uniformOfFintype (CfsCoeffs K n d)).map (cfsView s c r)
      = (PMF.uniformOfFintype (CfsCoeffs K n d)).map (cfsView s' c r) := by
  obtain ⟨Δ, hΔ⟩ := cfsView_shift hd h2 hc r s s' hdef
  have hfun : cfsView s c r = (cfsView s' c r) ∘ (fun a => a + Δ) := funext hΔ
  rw [hfun, ← PMF.map_comp, map_uniform_add_right]

/-- **Anything computed from the view inherits it.** For any fixed map `φ` (the sent form of the rounds, the claims
and checks the verifier derives from them), the law of `φ` of the view is the same for two families of unmasked rounds
with the same chain defects. -/
theorem cfsView_law_eq_comp [Fintype K] {n d : ℕ} {β : Type}
    (φ : K × (Fin (n + 1) → Fin (d + 1) → K) × K → β) (hd : 1 ≤ d) (h2 : (2 : K) ≠ 0) {c : K} (hc : c ≠ 0)
    (r : Fin (n + 1) → K) (s s' : Fin (n + 1) → Fin (d + 1) → K)
    (hdef : chainDefect s r = chainDefect s' r) :
    (PMF.uniformOfFintype (CfsCoeffs K n d)).map (φ ∘ cfsView s c r)
      = (PMF.uniformOfFintype (CfsCoeffs K n d)).map (φ ∘ cfsView s' c r) := by
  rw [← PMF.map_comp, ← PMF.map_comp, cfsView_law_eq hd h2 hc r s s' hdef]

/-- A round polynomial as the code sends it: its values at `X = 0, 1, …, d` (`CfsMask::round`,
`SumcheckProof::rounds`). -/
def roundValues {d : ℕ} (p : Fin (d + 1) → K) : Fin (d + 1) → K := fun x => peval p ((x : ℕ) : K)

/-- **The sent messages, in the code's value form, have the same law.** The joint law of (`G`, every round message as
its values at `0..d`, `g(ρ)`) depends on the unmasked rounds only through their chain defects. -/
theorem cfsView_values_law_eq [Fintype K] {n d : ℕ} (hd : 1 ≤ d) (h2 : (2 : K) ≠ 0) {c : K} (hc : c ≠ 0)
    (r : Fin (n + 1) → K) (s s' : Fin (n + 1) → Fin (d + 1) → K)
    (hdef : chainDefect s r = chainDefect s' r) :
    (PMF.uniformOfFintype (CfsCoeffs K n d)).map
        (fun a => ((cfsView s c r a).1, fun j => roundValues ((cfsView s c r a).2.1 j), (cfsView s c r a).2.2))
      = (PMF.uniformOfFintype (CfsCoeffs K n d)).map
        (fun a => ((cfsView s' c r a).1, fun j => roundValues ((cfsView s' c r a).2.1 j),
          (cfsView s' c r a).2.2)) :=
  cfsView_law_eq_comp (fun v => (v.1, fun j => roundValues (v.2.1 j), v.2.2)) hd h2 hc r s s' hdef

/-- The coin shift for the masked-scalar view. -/
theorem cfsViewMasked_shift {n d : ℕ} (hd : 1 ≤ d) (h2 : (2 : K) ≠ 0) {c : K} (hc : c ≠ 0)
    (r : Fin (n + 1) → K) (s s' : Fin (n + 1) → Fin (d + 1) → K)
    (hdef : (chainDefect s r).2 = (chainDefect s' r).2) :
    ∃ Δ : CfsCoeffs K n d, ∀ a, cfsViewMasked s c r a = cfsViewMasked s' c r (a + Δ) := by
  simp only [chainDefect, Prod.mk.injEq] at hdef
  obtain ⟨hmid, hlast⟩ := hdef
  have hmid' : ∀ j : Fin n, roundSum ((s - s') j.succ) = peval ((s - s') j.castSucc) (r j.castSucc) := by
    intro j
    have := congrFun hmid j
    simp only [roundSum, Pi.sub_apply, peval_sub] at this ⊢
    linear_combination this
  obtain ⟨Δ, _, hΔ⟩ := cfs_solve h2 hc r (s - s') hmid'
  have hround : ∀ j, (fun e => c * cfsMaskRound Δ r j e) = s j - s' j := fun j => funext (hΔ j)
  have hG : c * cfsTotal Δ = roundSum (s 0) - roundSum (s' 0) := by
    have e1 := congrArg roundSum (hround 0)
    rw [roundSum, peval_smul, peval_smul, ← mul_add, ← roundSum, cfsMask_roundSum_zero hd h2] at e1
    rw [e1, roundSum, peval_sub, peval_sub, roundSum, roundSum]
    ring
  have hγ : cfsEval Δ r = 0 := by
    have e1 := congrArg (fun p => peval p (r (Fin.last n))) (hround (Fin.last n))
    simp only [peval_smul, cfsMask_terminal hd, peval_sub] at e1
    have : c * cfsEval Δ r = 0 := by rw [e1]; linear_combination hlast
    exact (mul_eq_zero.mp this).resolve_left hc
  refine ⟨Δ, fun a => ?_⟩
  simp only [cfsViewMasked, cfsTotal_add, cfsEval_add, hγ, add_zero, Prod.mk.injEq, and_true]
  constructor
  · rw [mul_add, hG]
    ring
  · funext j e
    rw [cfsMaskRound_add, Pi.add_apply, mul_add, hΔ j e, Pi.sub_apply, Pi.sub_apply]
    ring

/-- **A private slot: the masked scalar hides the claimed sum too.** With the scalar sent as `S + c·G`
(`SlotKind::Private`), two families of unmasked rounds with the same middle defects and the same terminal value give
the same joint law of (scalar, every round message, `g(ρ)`), whatever their claimed sums. For privacy: an honest
private slot reveals its data only through the terminal value `F`. -/
theorem cfsViewMasked_law_eq [Fintype K] {n d : ℕ} (hd : 1 ≤ d) (h2 : (2 : K) ≠ 0) {c : K} (hc : c ≠ 0)
    (r : Fin (n + 1) → K) (s s' : Fin (n + 1) → Fin (d + 1) → K)
    (hdef : (chainDefect s r).2 = (chainDefect s' r).2) :
    (PMF.uniformOfFintype (CfsCoeffs K n d)).map (cfsViewMasked s c r)
      = (PMF.uniformOfFintype (CfsCoeffs K n d)).map (cfsViewMasked s' c r) := by
  obtain ⟨Δ, hΔ⟩ := cfsViewMasked_shift hd h2 hc r s s' hdef
  have hfun : cfsViewMasked s c r = (cfsViewMasked s' c r) ∘ (fun a => a + Δ) := funext hΔ
  rw [hfun, ← PMF.map_comp, map_uniform_add_right]

/-- A per-coin translate of a uniform law on a product is uniform: `(ω, a) ↦ (ω, a + Δ ω)` is a bijection. -/
theorem map_uniform_shift_snd {Ω C : Type} [Fintype Ω] [Nonempty Ω] [AddGroup C] [Fintype C] [Nonempty C]
    (Δ : Ω → C) :
    (PMF.uniformOfFintype (Ω × C)).map (fun p => (p.1, p.2 + Δ p.1)) = PMF.uniformOfFintype (Ω × C) := by
  apply map_uniform_of_bijective
  refine ⟨fun p q h => ?_, fun q => ⟨(q.1, q.2 - Δ q.1), by simp⟩⟩
  simp only [Prod.mk.injEq] at h
  obtain ⟨h1, h2⟩ := h
  have h3 : p.2 = q.2 := by rw [h1] at h2; exact add_right_cancel h2
  exact Prod.ext h1 h3

/-- **The joint form, for composition.** Let `ω` be the other coins of the proof (uniform, independent of the mask),
`X ω` the rest of the view (for example the opened claim values, which include the masked terminals), `s ω` the
unmasked rounds, and `s'` any choice of rounds computed from the rest of the view with the same chain defects. Then
the joint law of `(X ω, cfsView (s ω) …)` equals that of `(X ω, cfsView (s' (X ω)) …)`. So the sumcheck adds nothing
beyond what `X` already shows: if `X`'s law does not depend on the data, neither does the joint view. -/
theorem cfsView_joint_law_eq [Fintype K] {n d : ℕ} (hd : 1 ≤ d) (h2 : (2 : K) ≠ 0) {c : K} (hc : c ≠ 0)
    (r : Fin (n + 1) → K) {Ω β : Type} [Fintype Ω] [Nonempty Ω] (X : Ω → β)
    (s : Ω → Fin (n + 1) → Fin (d + 1) → K) (s' : β → Fin (n + 1) → Fin (d + 1) → K)
    (hdef : ∀ ω, chainDefect (s ω) r = chainDefect (s' (X ω)) r) :
    (PMF.uniformOfFintype (Ω × CfsCoeffs K n d)).map (fun p => (X p.1, cfsView (s p.1) c r p.2))
      = (PMF.uniformOfFintype (Ω × CfsCoeffs K n d)).map (fun p => (X p.1, cfsView (s' (X p.1)) c r p.2)) := by
  choose Δ hΔ using fun ω => cfsView_shift hd h2 hc r (s ω) (s' (X ω)) (hdef ω)
  have hfun : (fun p : Ω × CfsCoeffs K n d => (X p.1, cfsView (s p.1) c r p.2))
      = (fun p : Ω × CfsCoeffs K n d => (X p.1, cfsView (s' (X p.1)) c r p.2))
        ∘ (fun p => (p.1, p.2 + Δ p.1)) := by
    funext p
    simp only [Function.comp_apply, hΔ]
  rw [hfun, ← PMF.map_comp, map_uniform_shift_snd]

/-- **The joint form for a private slot (masked scalar).** As `cfsView_joint_law_eq`, with the scalar `S + c·G`;
only the middle defects and the terminal value must be functions of the rest of the view. -/
theorem cfsViewMasked_joint_law_eq [Fintype K] {n d : ℕ} (hd : 1 ≤ d) (h2 : (2 : K) ≠ 0) {c : K} (hc : c ≠ 0)
    (r : Fin (n + 1) → K) {Ω β : Type} [Fintype Ω] [Nonempty Ω] (X : Ω → β)
    (s : Ω → Fin (n + 1) → Fin (d + 1) → K) (s' : β → Fin (n + 1) → Fin (d + 1) → K)
    (hdef : ∀ ω, (chainDefect (s ω) r).2 = (chainDefect (s' (X ω)) r).2) :
    (PMF.uniformOfFintype (Ω × CfsCoeffs K n d)).map (fun p => (X p.1, cfsViewMasked (s p.1) c r p.2))
      = (PMF.uniformOfFintype (Ω × CfsCoeffs K n d)).map
          (fun p => (X p.1, cfsViewMasked (s' (X p.1)) c r p.2)) := by
  choose Δ hΔ using fun ω => cfsViewMasked_shift hd h2 hc r (s ω) (s' (X ω)) (hdef ω)
  have hfun : (fun p : Ω × CfsCoeffs K n d => (X p.1, cfsViewMasked (s p.1) c r p.2))
      = (fun p : Ω × CfsCoeffs K n d => (X p.1, cfsViewMasked (s' (X p.1)) c r p.2))
        ∘ (fun p => (p.1, p.2 + Δ p.1)) := by
    funext p
    simp only [Function.comp_apply, hΔ]
  rw [hfun, ← PMF.map_comp, map_uniform_shift_snd]

/-! ## The last-round extension -/

/-- The extension round's unmasked polynomial (`sumcheck::extension_round`): `s_k(X) = poly((1 − X)·fin + X·ext)`,
with `fin` the tables' terminal values and `ext` their extension values (`R_T~` at the claim point's tail for a
private table, `0` for a public or `eq` table). -/
def extRoundFun {t : ℕ} (P : (Fin t → K) → K) (fin ext : Fin t → K) (X : K) : K :=
  P (fun i => fin i + X * (ext i - fin i))

/-- The masked terminal of one table after the extension round (`sumcheck::masked_terminal`):
`(1 − ρ_k)·fin + ρ_k·ext`. -/
def maskedTerminal (fin ext ρ : K) : K := fin + ρ * (ext - fin)

/-- **The extension round ends at `poly` of the masked terminals.** So the terminal check, and with it the slot's
terminal value `F`, involves the private tables only through their masked terminals. -/
theorem extRound_terminal {t : ℕ} (P : (Fin t → K) → K) (fin ext : Fin t → K) (ρ : K) :
    extRoundFun P fin ext ρ = P (fun i => maskedTerminal (fin i) (ext i) ρ) := rfl

/-- The extension round's two ends: `s_k(0) = poly(fin)` and `s_k(1) = poly(ext)`. -/
theorem extRound_ends {t : ℕ} (P : (Fin t → K) → K) (fin ext : Fin t → K) :
    extRoundFun P fin ext 0 = P fin ∧ extRoundFun P fin ext 1 = P ext := by
  constructor
  · simp [extRoundFun]
  · simp [extRoundFun]

/-- **A slot with its extension round has defects `(S, 0, poly(masked terminals))`.** The slot has `n + 2` rounds:
`n + 1` rounds of an honest sumcheck of `poly` over the original tables (round-0 sum `S`, zero gaps, and the last
original round ending at `poly(fin)`, the standard sumcheck identity), then the extension round, whose polynomial
agrees with `poly((1 − X)·fin + X·ext)` (its degree is the round degree). If the extension is an identity,
`poly(ext) = 0` (every term of `poly` carries a public or `eq` factor whose extension value is `0`), the defects are
the claimed sum, zeros, and `poly` of the masked terminals. -/
theorem slot_chainDefect {n d t : ℕ} (P : (Fin t → K) → K) (fin ext : Fin t → K) (S : K)
    (s : Fin (n + 2) → Fin (d + 1) → K) (r : Fin (n + 2) → K)
    (h0 : roundSum (s 0) = S)
    (hchain : ∀ j : Fin n, roundSum (s j.succ.castSucc) = peval (s j.castSucc.castSucc) (r j.castSucc.castSucc))
    (hfin : peval (s (Fin.last n).castSucc) (r (Fin.last n).castSucc) = P fin)
    (hext : ∀ x, peval (s (Fin.last (n + 1))) x = extRoundFun P fin ext x)
    (hP : P ext = 0) :
    chainDefect s r = (S, 0, P (fun i => maskedTerminal (fin i) (ext i) (r (Fin.last (n + 1))))) := by
  simp only [chainDefect, Prod.mk.injEq]
  refine ⟨h0, ?_, by rw [hext, extRound_terminal]⟩
  funext j
  simp only [Pi.zero_apply]
  refine Fin.lastCases ?_ (fun j' => ?_) j
  · rw [Fin.succ_last, roundSum, hext, hext, (extRound_ends P fin ext).1, (extRound_ends P fin ext).2, hfin, hP]
    ring
  · rw [Fin.succ_castSucc, hchain j', sub_self]

/-- **A private slot's whole view depends on its data only through `poly` of the masked terminals.** Two honest
private slots (scalar `S + c·G`) with extension rounds that are identities, whose `poly` of the masked terminals agree,
have the same joint law of (scalar, every round message, `g(ρ)`), whatever their tables and claimed sums. The masked
terminals are the claim values that `HidingOpening.lean` shows are hidden with the opened columns. -/
theorem slot_view_law_eq [Fintype K] {n d t : ℕ} (hd : 1 ≤ d) (h2 : (2 : K) ≠ 0) {c : K} (hc : c ≠ 0)
    (r : Fin (n + 2) → K) (P : (Fin t → K) → K)
    (fin ext fin' ext' : Fin t → K) (S S' : K) (s s' : Fin (n + 2) → Fin (d + 1) → K)
    (h0 : roundSum (s 0) = S) (h0' : roundSum (s' 0) = S')
    (hchain : ∀ j : Fin n, roundSum (s j.succ.castSucc) = peval (s j.castSucc.castSucc) (r j.castSucc.castSucc))
    (hchain' : ∀ j : Fin n,
      roundSum (s' j.succ.castSucc) = peval (s' j.castSucc.castSucc) (r j.castSucc.castSucc))
    (hfin : peval (s (Fin.last n).castSucc) (r (Fin.last n).castSucc) = P fin)
    (hfin' : peval (s' (Fin.last n).castSucc) (r (Fin.last n).castSucc) = P fin')
    (hext : ∀ x, peval (s (Fin.last (n + 1))) x = extRoundFun P fin ext x)
    (hext' : ∀ x, peval (s' (Fin.last (n + 1))) x = extRoundFun P fin' ext' x)
    (hP : P ext = 0) (hP' : P ext' = 0)
    (hterm : P (fun i => maskedTerminal (fin i) (ext i) (r (Fin.last (n + 1))))
      = P (fun i => maskedTerminal (fin' i) (ext' i) (r (Fin.last (n + 1))))) :
    (PMF.uniformOfFintype (CfsCoeffs K (n + 1) d)).map (cfsViewMasked s c r)
      = (PMF.uniformOfFintype (CfsCoeffs K (n + 1) d)).map (cfsViewMasked s' c r) := by
  refine cfsViewMasked_law_eq hd h2 hc r s s' ?_
  rw [slot_chainDefect P fin ext S s r h0 hchain hfin hext hP,
    slot_chainDefect P fin' ext' S' s' r h0' hchain' hfin' hext' hP', hterm]

end CfsJoint

end ZK60.Hiding
