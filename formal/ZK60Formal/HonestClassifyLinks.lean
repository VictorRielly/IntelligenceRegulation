/-
D63 Lean lane L25 (2026-11-07), part 5: **for obligation O12 (zero knowledge), the honest rounds in lane L19's
coefficient form**: L19's `hHV_of_blockLinks` takes the honest prover's rounds as a family `S` of round polynomials in
coefficient form with named properties ("honest rounds: zero gaps, a standalone's claimed sum `0`", `slotDefect_honest`,
`terminal_of_claims`'s `h0` / `hchain`). Here the honest prover's rounds ARE such a family, from the polynomial:
* `coeffsOf`, `peval_coeffsOf`: a polynomial of degree `≤ d` as its coefficient vector (`peval` is its evaluation);
* **`honestCo`**: the honest prover's round polynomials along the challenges `r`, in coefficient form (round `j` is the
  true round polynomial of `f` with its first `j` variables fixed to `r_0, …, r_{j−1}`; `Complete.honestMsg` read
  through its interpolant `roundPoly`: the polynomial whose values at the nodes the code's words carry,
  `HonestClassifySum.lean`'s `WHonest`);
* **`chainDefect_honestCo`**: their chain defects are `(Σ f, 0, f(r))`: the claimed sum is the true sum, EVERY gap is
  zero, the terminal is `f` at the challenges, at every `r`;
* **`chainDefect_honestCo_masked`**: the rounds the code SENDS, `s_j + c·g_j` with the CFS mask's rounds
  (`cfsMaskRound`, ExecCfs's `toK_roundBody`), have the defects `(Σ f + c·G, 0, f(r) + c·g(r))` (`cfs_masked_honest`);
* **`slotDefect_honestCo`**: L19's `slotDefect` of the honest rounds is `(0, 0, f(r))` for either kind, given a
  standalone's true sum `0` (`slotDefect_honest`'s `hmid`, `hsum`, `hT` DISCHARGED from the polynomial).

Every premise is an explicit hypothesis.
-/
import ZK60Formal.HonestClassifySum
import ZK60Formal.ZKLinksM

set_option autoImplicit false

namespace ZK60.HonestClassify

open Polynomial
open ZK60 ZK60.Sound ZK60.Hiding

variable {K : Type} [Field K]

/-- A polynomial's coefficients up to degree `d`. -/
noncomputable def coeffsOf (d : ℕ) (q : K[X]) : Fin (d + 1) → K := fun e => q.coeff e

/-- For `q` of degree `≤ d`, `peval` of its coefficients is its evaluation. -/
theorem peval_coeffsOf {d : ℕ} (q : K[X]) (hq : q.natDegree ≤ d) (x : K) : peval (coeffsOf d q) x = q.eval x := by
  rw [eval_eq_sum_range' (Nat.lt_succ_of_le hq), ← Fin.sum_univ_eq_sum_range]
  rfl

/-- The honest round polynomial of `f` (round `0`), in coefficient form. -/
noncomputable def roundCo (d : ℕ) {n : ℕ} (f : (Fin (n + 1) → K) → K) : Fin (d + 1) → K :=
  coeffsOf d (roundPoly (Complete.honestMsg d f))

/-- The honest round polynomial evaluates to the true round sum. -/
theorem peval_roundCo {d : ℕ} (hd : d < ringChar K) {n : ℕ} {f : (Fin (n + 1) → K) → K} (hf : IndDegLE d f) (t : K) :
    peval (roundCo d f) t = cubeSum (fun x => f (Fin.cons t x)) := by
  rw [roundCo, peval_coeffsOf _ (roundPoly_natDegree_le hd _), ← interpEval_eq, Complete.interpEval_honestMsg hd hf]

theorem roundSum_roundCo {d : ℕ} (hd : d < ringChar K) {n : ℕ} {f : (Fin (n + 1) → K) → K} (hf : IndDegLE d f) :
    roundSum (roundCo d f) = cubeSum f := by
  rw [roundSum, peval_roundCo hd hf, peval_roundCo hd hf, cubeSum_succ]

/-- **The honest prover's rounds along the challenges `r`, in coefficient form.** -/
noncomputable def honestCo (d : ℕ) : (n : ℕ) → ((Fin (n + 1) → K) → K) → (Fin (n + 1) → K) → Fin (n + 1) → Fin (d + 1) → K
  | 0, f, _ => fun _ => roundCo d f
  | n + 1, f, r => Fin.cons (roundCo d f) (honestCo d n (fun x => f (Fin.cons (r 0) x)) (Fin.tail r))

/-- **The honest rounds' chain defects are `(Σ f, 0, f(r))`** at every challenge vector: the claimed sum is the true
sum, every gap is zero, and the terminal is `f(r)`. -/
theorem chainDefect_honestCo {d : ℕ} (hd : d < ringChar K) :
    ∀ (n : ℕ) (f : (Fin (n + 1) → K) → K) (r : Fin (n + 1) → K), IndDegLE d f →
      chainDefect (honestCo d n f r) r = (cubeSum f, 0, f r)
  | 0, f, r, hf => by
    refine Prod.ext ?_ (Prod.ext ?_ ?_)
    · exact roundSum_roundCo hd hf
    · funext j
      exact j.elim0
    · show peval (roundCo d f) (r (Fin.last 0)) = f r
      rw [peval_roundCo hd hf, cubeSum_zero]
      show f (Fin.cons (r (Fin.last 0)) Fin.elim0) = f r
      congr 1
      funext i
      have hi : i = 0 := Fin.ext (Nat.lt_one_iff.mp i.isLt)
      subst hi
      rfl
  | n + 1, f, r, hf => by
    have ih := chainDefect_honestCo hd n (fun x => f (Fin.cons (r 0) x)) (Fin.tail r) (hf.cons (r 0))
    simp only [chainDefect, Prod.mk.injEq] at ih
    obtain ⟨h1, h2, h3⟩ := ih
    refine Prod.ext ?_ (Prod.ext ?_ ?_)
    · show roundSum (roundCo d f) = cubeSum f
      exact roundSum_roundCo hd hf
    · funext j
      refine Fin.cases ?_ (fun k => ?_) j
      · show roundSum (honestCo d n (fun x => f (Fin.cons (r 0) x)) (Fin.tail r) 0) - peval (roundCo d f) (r 0) = 0
        rw [h1, peval_roundCo hd hf]
        exact sub_self _
      · have hk := congrFun h2 k
        show roundSum (honestCo d (n + 1) f r k.succ.succ) - peval (honestCo d (n + 1) f r k.succ.castSucc)
          (r k.succ.castSucc) = 0
        rw [← Fin.succ_castSucc]
        exact hk
    · show peval (honestCo d (n + 1) f r (Fin.last (n + 1))) (r (Fin.last (n + 1))) = f r
      rw [← Fin.succ_last]
      show peval (honestCo d n (fun x => f (Fin.cons (r 0) x)) (Fin.tail r) (Fin.last n)) (Fin.tail r (Fin.last n)) = f r
      rw [h3]
      exact congrArg f (Fin.cons_self_tail r)

/-- **The rounds the code sends** (`s_j + c·g_j`, the CFS mask's rounds `cfsMaskRound`) **on the honest rounds**: the
defects `(Σ f + c·G, 0, f(r) + c·g(r))`, for every mask and every `c` (`cfs_masked_honest`). -/
theorem chainDefect_honestCo_masked {d : ℕ} (hd : d < ringChar K) (hd1 : 1 ≤ d) (h2 : (2 : K) ≠ 0) (n : ℕ)
    (f : (Fin (n + 1) → K) → K) (r : Fin (n + 1) → K) (hf : IndDegLE d f) (c : K) (a : CfsCoeffs K n d) :
    chainDefect (fun j e => honestCo d n f r j e + c * cfsMaskRound a r j e) r
      = (cubeSum f + c * cfsTotal a, 0, f r + c * cfsEval a r) :=
  Complete.cfs_masked_honest hd1 h2 (honestCo d n f r) c r a (chainDefect_honestCo hd n f r hf)

/-- **L19's `slotDefect` of the honest rounds** is `(0, 0, f(r))` for either kind (masked: a private or host slot;
unmasked: a standalone slot, whose true sum is `0`): `slotDefect_honest`'s three premises from the polynomial. -/
theorem slotDefect_honestCo {d : ℕ} (hd : d < ringChar K) (masked : Bool) (n : ℕ) (f : (Fin (n + 1) → K) → K)
    (r : Fin (n + 1) → K) (hf : IndDegLE d f) (hstd : masked = false → cubeSum f = 0) :
    ZKLinks.slotDefect masked (honestCo d n f r) r = (0, 0, f r) :=
  ZKLinks.slotDefect_honest masked _ r (f r)
    (by rw [chainDefect_honestCo hd n f r hf])
    (fun h => by rw [chainDefect_honestCo hd n f r hf]; exact hstd h)
    (by rw [chainDefect_honestCo hd n f r hf])

end ZK60.HonestClassify
