/-
D63, step L4 (zero knowledge): one round of a masked sumcheck (Chiesa–Forbes–Spooner / Libra masking).

The code (`zkp-core/src/sumcheck.rs`, `CfsMask`, `CfsMasker`): the prover runs the sumcheck on `f + c·g`, where
`c ≠ 0` is a verifier challenge (`zk.rs` `mask_challenge` refuses `c = 0`) and the mask polynomial is
  `g(x) = a_0 + a'·∏_j x_j + Σ_j Σ_{e=1..d} a_{j,e} x_j^e`
with uniform Fp2 coefficients. `CfsMask::round` gives round `j`'s contribution in closed form:
  `g_j(X) = κ·(base + Σ_{e=1..d} a_{j,e} X^e) + a'·P·X`,  `κ = 2^(N−1−j)`,  `P = ∏_{i<j} r_i`,
where `base = a_0 + Σ_{i<j} u_i(r_i) + Σ_{i>j} u_i(1)/2` collects the other variables' coefficients
(`u_i(X) = Σ_e a_{i,e} X^e`). The prover sends `s_j + c·g_j` (`s_j` the unmasked round polynomial).

This file proves the one-round statement: round `j`'s own coefficients `a_{j,1..d}` make the `d` non-constant
coefficients of the sent polynomial exactly uniform, whatever the unmasked polynomial is; the constant coefficient
is fixed by the rest. `cfsRound_law`: the whole message is "uniform in the relevant space".

What it does NOT give, and why it is only one ingredient: `a_{j,·}` also enter the other rounds (through `u_j(1)/2`
in the earlier rounds' `base` and `u_j(r_j)` in the later ones), the masked total `G` and the terminal `g(ρ)`
(opened from the mask commitment `M`). The joint statement over all rounds, `G` and `g(ρ)` (the CFS/Libra lemma;
the reason for the extra coefficient `a'`) is further L4 work, as are `M`'s product-form opening and the last-round
extension of the private tables.
-/
import ZK60Formal.HidingRows

namespace ZK60.Hiding

open scoped ENNReal

variable {K : Type} [Field K] [Fintype K]

/-- Round `j`'s mask polynomial in coefficient form (degree `d`), as `CfsMask::round` computes it:
coefficient `0` is `κ·base`, coefficient `e ≥ 1` is `κ·a_{j,e}`, plus `a'·P` on coefficient `1`. -/
def cfsRoundCoeffs {d : ℕ} (κ base a' P : K) (aj : Fin d → K) : Fin (d + 1) → K :=
  fun e => κ * Fin.cases (motive := fun _ => K) base aj e + (if (e : ℕ) = 1 then a' * P else 0)

/-- The sent round polynomial (coefficient form): the unmasked `s` plus `c` times the mask's round polynomial. -/
def cfsMaskedRound {d : ℕ} (s : Fin (d + 1) → K) (c κ base a' P : K) (aj : Fin d → K) : Fin (d + 1) → K :=
  fun e => s e + c * cfsRoundCoeffs κ base a' P aj e

/-- **One masked round: the non-constant coefficients are exactly uniform, for every unmasked polynomial.** With
`c ≠ 0` and `κ = 2^(N−1−j) ≠ 0` (odd characteristic), and all other mask coefficients fixed, the `d` non-constant
coefficients of the sent round polynomial are uniform on `K^d` over the round's own fresh coefficients. -/
theorem cfsRound_tail_uniform {d : ℕ} (s : Fin (d + 1) → K) (c κ base a' P : K) (hc : c ≠ 0) (hκ : κ ≠ 0) :
    (PMF.uniformOfFintype (Fin d → K)).map
        (fun aj => fun i : Fin d => cfsMaskedRound s c κ base a' P aj i.succ)
      = PMF.uniformOfFintype (Fin d → K) := by
  have h : (fun aj : Fin d → K => fun i : Fin d => cfsMaskedRound s c κ base a' P aj i.succ)
      = fun aj => (fun i : Fin d => s i.succ + c * (if ((i.succ : Fin (d + 1)) : ℕ) = 1 then a' * P else 0))
          + fun i => (c * κ) * aj i := by
    funext aj i
    simp only [cfsMaskedRound, cfsRoundCoeffs, Fin.cases_succ, Pi.add_apply]
    ring
  rw [h]
  refine map_uniform_add_left_of_surjective (fun aj : Fin d → K => fun i => (c * κ) * aj i) ?_ ?_ _
  · intro x y
    funext i
    simp only [Pi.add_apply, mul_add]
  · intro y
    refine ⟨fun i => (c * κ)⁻¹ * y i, ?_⟩
    funext i
    simp only
    rw [← mul_assoc, mul_inv_cancel₀ (mul_ne_zero hc hκ), one_mul]

/-- **One masked round is uniform in its space.** The sent round polynomial has the law of
`Fin.cons m₀ U` with `U` uniform on `K^d`, where `m₀ = s₀ + c·κ·base` is its constant coefficient. The verifier's
round check `p(0) + p(1) = claim` ties `m₀` to the running claim; that link, and the correlation with the other
rounds through `base`, is the joint statement this file does not prove. The sent object is the polynomial's values at
`X = 0..d`, an invertible linear image of the coefficients, so the same holds for it. -/
theorem cfsRound_law {d : ℕ} (s : Fin (d + 1) → K) (c κ base a' P : K) (hc : c ≠ 0) (hκ : κ ≠ 0) :
    (PMF.uniformOfFintype (Fin d → K)).map (cfsMaskedRound s c κ base a' P)
      = (PMF.uniformOfFintype (Fin d → K)).map
          (Fin.cons (α := fun _ => K) (s 0 + c * (κ * base))) := by
  have h : cfsMaskedRound s c κ base a' P
      = (Fin.cons (α := fun _ => K) (s 0 + c * (κ * base)))
        ∘ fun aj => fun i : Fin d => cfsMaskedRound s c κ base a' P aj i.succ := by
    funext aj e
    refine Fin.cases ?_ (fun i => ?_) e
    · simp [cfsMaskedRound, cfsRoundCoeffs]
    · simp only [Function.comp_apply, Fin.cons_succ]
  rw [h, ← PMF.map_comp, cfsRound_tail_uniform s c κ base a' P hc hκ]

omit [Fintype K] in
/-- The round scale `κ = 2^m` is nonzero in odd characteristic (Goldilocks: `p` odd). -/
theorem cfsScale_ne_zero (h2 : (2 : K) ≠ 0) (m : ℕ) : (2 : K) ^ m ≠ 0 := pow_ne_zero m h2

end ZK60.Hiding
