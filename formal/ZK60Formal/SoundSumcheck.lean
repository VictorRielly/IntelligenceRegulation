/-
D63, step L3 (soundness of the IOP): the sumcheck, one round and then `n` rounds, interactive (no Fiat–Shamir).

The protocol as `zkp_core::sumcheck` runs it (`prove`, `verify`, `mle::interpolate_eval`):
* the claim is `Σ_{x ∈ {0,1}^n} f(x) = C`, where `f` has degree at most `d` in each variable separately (the code's
  `f` is `poly(T̃₁(x), …, T̃ₖ(x))` with multilinear tables `T̃` and `poly` of total degree `≤ d`, the `degree`
  argument);
* round `j` fixes variable `j` (the most significant bit first);
* the prover sends the round polynomial as its `d + 1` VALUES `s(0), s(1), …, s(d)`, not as coefficients;
* the verifier checks that it received exactly `d + 1` values, that `s(0) + s(1)` equals the current claim, draws
  `r_j`, and continues with the claim `s(r_j)`, computed by Lagrange interpolation through the nodes `0, …, d`
  (`interpolate_eval`);
* after the last round the CALLER checks the final claim against `f` at the challenge point (the terminal check:
  `poly` of the tables' terminal values, which the PCS opens).

What is proved (challenges uniform and independent; Fiat–Shamir is out of scope here):
* `interpEval_eq`, `roundPoly_natDegree_le`, `roundPoly_eval_node`: the value form is exact. Any `d + 1` values
  define one polynomial of degree `≤ d`, the verifier's `interpolate_eval` is its evaluation, and so the degree bound
  is AUTOMATIC: the verifier never needs a separate degree check. This needs the nodes `0, …, d` to be distinct in
  `F`, i.e. `d < char F` (`node_injective`), a real hypothesis that the code meets with `d ≤ 5` and
  `char Fp2 = 2^64 − 2^32 + 1`.
* `card_accepts_le` (counting) and `sumcheck_sound` (probability): if the claim is false, then for EVERY prover
  strategy the verifier accepts with probability at most `n·d / |F|`.
* `sumcheck_sound_one_round`: the one-round step alone (a false claim makes the next claim false except with
  probability `d / |F|`).
* `sumcheck_sound_masked`: the same bound for the masked sumcheck the code runs under `--zk`, on `f + c·g` with the
  claim `S + c·G`, `G = Σ g`, for any mask `g` of individual degree `≤ d` and any `c`: a false `S` stays false.
* `sumcheck_sound_extended`: the same bound, `(n + 1)·d / |F|`, for the last-round extension (one trailing variable
  `y` whose `y = 1` half vanishes on the cube), and `extension_halves`: the code's extension has that property
  whenever `poly` vanishes once its public inputs are zero (the code's "the eq / public factors carry `(1 − y)`").

The prover is modelled as a strategy TREE (`Prover`): the first message, and for every challenge a strategy for the
rest. That is exactly "every round message is a function of the challenges drawn before it". The prover may be
arbitrary, unbounded and adaptive.
-/
import ZK60Formal.SoundSchwartzZippel
import Mathlib.LinearAlgebra.Lagrange

namespace ZK60.Sound

open scoped ENNReal
open Polynomial Finset

variable {F : Type} [Field F]

/-! ## Round messages in the code's value form -/

/-- The interpolation nodes `0, 1, …, d` at which the code sends a round polynomial's values. -/
def node (d : ℕ) (i : Fin (d + 1)) : F := ((i : ℕ) : F)

/-- The code's interpolation, `mle::interpolate_eval`, written as the code computes it: the value at `x` of the
polynomial through the points `(i, s i)`, `i = 0, …, d`, namely `Σ_i s_i · Π_{j ≠ i} (x − j) · (Π_{j ≠ i} (i − j))⁻¹`.
The verifier's next claim is `interpEval s r`. -/
def interpEval {d : ℕ} (s : Fin (d + 1) → F) (x : F) : F :=
  ∑ i, s i * (∏ j ∈ univ.erase i, (x - node d j)) * (∏ j ∈ univ.erase i, (node d i - node d j))⁻¹

/-- The round polynomial a message `s` stands for: the Lagrange interpolant of its `d + 1` values. -/
noncomputable def roundPoly {d : ℕ} (s : Fin (d + 1) → F) : F[X] :=
  Lagrange.interpolate univ (node d) s

/-- The nodes `0, …, d` are distinct in `F` when `d` is below the characteristic. -/
theorem node_injective {d : ℕ} (hd : d < ringChar F) : Function.Injective (node (F := F) d) := by
  intro i j h
  have := CharP.natCast_injOn_Iio F (ringChar F)
    (show (i : ℕ) ∈ Set.Iio (ringChar F) from lt_of_le_of_lt (Nat.lt_succ_iff.mp i.isLt) hd)
    (show (j : ℕ) ∈ Set.Iio (ringChar F) from lt_of_le_of_lt (Nat.lt_succ_iff.mp j.isLt) hd) h
  exact Fin.ext this

/-- The code's `interpolate_eval` is the evaluation of the round polynomial. -/
theorem interpEval_eq {d : ℕ} (s : Fin (d + 1) → F) (x : F) : interpEval s x = (roundPoly s).eval x := by
  classical
  simp only [interpEval, roundPoly, Lagrange.interpolate_apply, eval_finsetSum, eval_mul, eval_C,
    Lagrange.basis, eval_prod, Lagrange.basisDivisor, eval_X, eval_sub, prod_mul_distrib, prod_inv_distrib]
  refine sum_congr rfl (fun i _ => ?_)
  ring

/-- A round polynomial has degree at most `d`: the value form bounds the degree by itself. -/
theorem roundPoly_natDegree_le {d : ℕ} (hd : d < ringChar F) (s : Fin (d + 1) → F) :
    (roundPoly s).natDegree ≤ d := by
  have h := Lagrange.degree_interpolate_le (s := (univ : Finset (Fin (d + 1)))) s
    ((node_injective (F := F) hd).injOn)
  rw [card_univ, Fintype.card_fin, Nat.add_sub_cancel] at h
  exact natDegree_le_iff_degree_le.mpr h

/-- The round polynomial takes the sent values at the nodes. -/
theorem roundPoly_eval_node {d : ℕ} (hd : d < ringChar F) (s : Fin (d + 1) → F) (i : Fin (d + 1)) :
    (roundPoly s).eval (node d i) = s i :=
  Lagrange.eval_interpolate_at_node s ((node_injective (F := F) hd).injOn) (mem_univ i)

/-- The verifier's check `s(0) + s(1)` reads the round polynomial at `0` and `1` (also when `d = 0`, where the code's
message has one value and the polynomial is constant). -/
theorem msg_zero_add_one {d : ℕ} (hd : d < ringChar F) (s : Fin (d + 1) → F) :
    s 0 + s 1 = (roundPoly s).eval 0 + (roundPoly s).eval 1 := by
  have h0 : (roundPoly s).eval 0 = s 0 := by
    have := roundPoly_eval_node hd s 0
    simpa [node] using this
  rcases Nat.eq_zero_or_pos d with rfl | hpos
  · have hc : roundPoly s = C ((roundPoly s).coeff 0) :=
      eq_C_of_natDegree_le_zero (roundPoly_natDegree_le hd s)
    have h1 : (roundPoly s).eval 1 = (roundPoly s).eval 0 := by
      rw [hc, eval_C, eval_C]
    rw [h1, h0, Subsingleton.elim (1 : Fin 1) 0]
  · have h1 : (roundPoly s).eval 1 = s 1 := by
      have := roundPoly_eval_node hd s 1
      have hv : ((1 : Fin (d + 1)) : ℕ) = 1 := by
        rw [Fin.val_one', Nat.mod_eq_of_lt (by omega)]
      have hn : (node d (1 : Fin (d + 1)) : F) = 1 := by
        unfold node
        rw [hv, Nat.cast_one]
      rwa [hn] at this
    rw [h0, h1]

/-! ## The Boolean hypercube and individual degree -/

/-- The two bits as field elements. -/
def bit (b : Bool) : F := if b then 1 else 0

/-- The sum of `f` over the Boolean hypercube `{0,1}^n`, the quantity a sumcheck claims. -/
def cubeSum {n : ℕ} (f : (Fin n → F) → F) : F := ∑ b : Fin n → Bool, f (fun i => bit (b i))

/-- With no variables the hypercube is one point. -/
theorem cubeSum_zero (f : (Fin 0 → F) → F) : cubeSum f = f Fin.elim0 := by
  simp only [cubeSum, Fintype.sum_unique]
  congr 1
  funext i
  exact i.elim0

/-- Splitting the hypercube on the FIRST variable (the one round 0 fixes). -/
theorem cubeSum_succ {n : ℕ} (f : (Fin (n + 1) → F) → F) :
    cubeSum f = cubeSum (fun x => f (Fin.cons 0 x)) + cubeSum (fun x => f (Fin.cons 1 x)) := by
  simp only [cubeSum]
  rw [← Fintype.sum_equiv (Fin.consEquiv (fun _ => Bool)) _ _ (fun _ => rfl), Fintype.sum_prod_type,
    Fintype.sum_bool, add_comm]
  congr 1 <;> refine sum_congr rfl (fun b _ => ?_) <;> congr 1 <;> funext i <;>
    refine Fin.cases ?_ (fun j => ?_) i <;> simp [bit]

/-- Splitting the hypercube on the LAST variable (the one the extension round fixes). -/
theorem cubeSum_snoc {n : ℕ} (f : (Fin (n + 1) → F) → F) :
    cubeSum f = cubeSum (fun x => f (Fin.snoc x 0)) + cubeSum (fun x => f (Fin.snoc x 1)) := by
  simp only [cubeSum]
  rw [← Fintype.sum_equiv (Fin.snocEquiv (fun _ => Bool)) _ _ (fun _ => rfl), Fintype.sum_prod_type,
    Fintype.sum_bool, add_comm]
  congr 1 <;> refine sum_congr rfl (fun b _ => ?_) <;> congr 1 <;> funext i <;>
    refine Fin.lastCases ?_ (fun j => ?_) i <;> simp [bit]

/-- The hypercube sum is linear: `Σ (f + c·g) = Σ f + c·Σ g`. -/
theorem cubeSum_add_smul {n : ℕ} (f g : (Fin n → F) → F) (c : F) :
    cubeSum (fun x => f x + c * g x) = cubeSum f + c * cubeSum g := by
  simp only [cubeSum, sum_add_distrib, mul_sum]

/-- `f` has degree at most `d` in each variable separately: fixing every variable but one leaves a polynomial of
degree `≤ d` in the remaining one. This is the hypothesis the sumcheck needs. It holds for a multivariate polynomial
of individual degree `≤ d`, and for the code's `poly(T̃₁(x), …, T̃ₖ(x))` with multilinear `T̃` and `poly` of total
degree `≤ d`. -/
def IndDegLE {n : ℕ} (d : ℕ) (f : (Fin n → F) → F) : Prop :=
  ∀ (i : Fin n) (x : Fin n → F), ∃ p : F[X], p.natDegree ≤ d ∧ ∀ t, f (Function.update x i t) = p.eval t

/-- Fixing the first variable keeps the individual degree. -/
theorem IndDegLE.cons {n d : ℕ} {f : (Fin (n + 1) → F) → F} (h : IndDegLE d f) (r : F) :
    IndDegLE d (fun x => f (Fin.cons r x)) := by
  intro i x
  obtain ⟨p, hp, hpe⟩ := h i.succ (Fin.cons r x)
  exact ⟨p, hp, fun t => by simpa [Fin.cons_update] using hpe t⟩

/-- In the first variable, `f` is a polynomial of degree `≤ d` once the others are fixed. -/
theorem IndDegLE.first {n d : ℕ} {f : (Fin (n + 1) → F) → F} (h : IndDegLE d f) (x : Fin n → F) :
    ∃ p : F[X], p.natDegree ≤ d ∧ ∀ t, f (Fin.cons t x) = p.eval t := by
  obtain ⟨p, hp, hpe⟩ := h 0 (Fin.cons 0 x)
  exact ⟨p, hp, fun t => by simpa [Fin.update_cons_zero] using hpe t⟩

/-- The TRUE round polynomial of round 0: `t ↦ Σ_{x ∈ {0,1}^n} f(t, x)` is a polynomial of degree `≤ d`. -/
theorem IndDegLE.roundSum {n d : ℕ} {f : (Fin (n + 1) → F) → F} (h : IndDegLE d f) :
    ∃ p : F[X], p.natDegree ≤ d ∧ ∀ t, cubeSum (fun x => f (Fin.cons t x)) = p.eval t := by
  classical
  choose q hq hqe using fun b : Fin n → Bool => h.first (fun i => bit (b i))
  refine ⟨∑ b, q b, natDegree_sum_le_of_forall_le _ _ (fun b _ => hq b), fun t => ?_⟩
  simp only [cubeSum, eval_finsetSum, hqe]

/-- `f + c·g` keeps the individual degree. -/
theorem IndDegLE.add_smul {n d : ℕ} {f g : (Fin n → F) → F} (hf : IndDegLE d f) (hg : IndDegLE d g) (c : F) :
    IndDegLE d (fun x => f x + c * g x) := by
  intro i x
  obtain ⟨p, hp, hpe⟩ := hf i x
  obtain ⟨q, hq, hqe⟩ := hg i x
  refine ⟨p + C c * q, natDegree_add_le_of_degree_le hp ((natDegree_C_mul_le c q).trans hq), fun t => ?_⟩
  simp [hpe, hqe]

/-! ## Prover strategies and the verifier -/

/-- A prover strategy for an `n`-round sumcheck of round degree `d`: the first round message (the `d + 1` values
`s(0), …, s(d)` the code sends) and, for every challenge `r`, a strategy for the remaining rounds. Every way of
choosing each round message as a function of the challenges drawn before it is such a tree, and conversely. -/
def Prover (F : Type) (d : ℕ) : ℕ → Type
  | 0 => PUnit
  | n + 1 => (Fin (d + 1) → F) × (F → Prover F d n)

/-- The verifier's verdict on the claim `cubeSum f = C` against prover `P` with challenges `r`, as
`zkp_core::sumcheck::verify` and its caller compute it. In each round: check `s(0) + s(1) = claim`, then continue with
the claim `interpolate_eval(s, r_j)` about `f` with variable `j` fixed to `r_j`. After the last round: the caller's
terminal check, final claim `= f(r)`. (The message length `d + 1` that `verify` checks is the type of a message.) -/
def Accepts {d : ℕ} : (n : ℕ) → ((Fin n → F) → F) → F → Prover F d n → (Fin n → F) → Prop
  | 0, f, C, _, _ => C = f Fin.elim0
  | n + 1, f, C, P, r =>
      P.1 0 + P.1 1 = C ∧
        Accepts n (fun x => f (Fin.cons (r 0) x)) (interpEval P.1 (r 0)) (P.2 (r 0)) (Fin.tail r)

/-! ## Counting -/

/-- Counting tuples of length `n + 1` by their first entry. -/
theorem card_filter_cons {α : Type} [Fintype α] [DecidableEq α] {n : ℕ} (E : (Fin (n + 1) → α) → Prop)
    [DecidablePred E] :
    (univ.filter E).card = ∑ a : α, (univ.filter (fun x : Fin n → α => E (Fin.cons a x))).card := by
  rw [card_filter]
  rw [← Fintype.sum_equiv (Fin.consEquiv (fun _ => α)) _ _ (fun _ => rfl), Fintype.sum_prod_type]
  refine sum_congr rfl (fun a _ => ?_)
  rw [card_filter]
  rfl

variable [Fintype F] [DecidableEq F]

/-- **One round.** Let the claim `C` be false, and let `s` be the first message. Either the check `s(0) + s(1) = C`
fails, or `s`'s polynomial differs from the true round polynomial, so they agree at no more than `d` challenges:
outside at most `d` challenges, the next claim is again false. -/
theorem sumcheck_one_round {n d : ℕ} (hd : d < ringChar F) {f : (Fin (n + 1) → F) → F} (hf : IndDegLE d f)
    {C : F} (hC : C ≠ cubeSum f) (s : Fin (d + 1) → F) (hs : s 0 + s 1 = C) :
    (univ.filter (fun r => interpEval s r = cubeSum (fun x => f (Fin.cons r x)))).card ≤ d := by
  obtain ⟨p, hp, hpe⟩ := hf.roundSum
  have hne : roundPoly s - p ≠ 0 := by
    intro h0
    have hq : roundPoly s = p := sub_eq_zero.mp h0
    apply hC
    rw [← hs, msg_zero_add_one hd, hq, cubeSum_succ, hpe, hpe]
  refine le_trans (Finset.card_le_card ?_) ((card_roots_le _ hne).trans
    ((natDegree_sub_le _ _).trans (max_le (roundPoly_natDegree_le hd s) hp)))
  intro r hr
  simp only [mem_filter, mem_univ, true_and] at hr ⊢
  rw [eval_sub, ← interpEval_eq, hr, hpe, sub_self]

open Classical in
/-- **The sumcheck, counted.** If the claim is false, the challenge tuples on which the verifier accepts number at
most `n·d·|F|^(n−1)` (written without subtraction: times `|F|`, at most `n·d·|F|^n`), whatever the prover does. -/
theorem card_accepts_le {d : ℕ} (hd : d < ringChar F) :
    ∀ (n : ℕ) (f : (Fin n → F) → F), IndDegLE d f → ∀ (C : F), C ≠ cubeSum f → ∀ (P : Prover F d n),
      (univ.filter (fun r => Accepts n f C P r)).card * Fintype.card F ≤ n * d * Fintype.card F ^ n := by
  classical
  intro n
  induction n with
  | zero =>
    intro f _ C hC P
    have : ∀ r, ¬ Accepts 0 f C P r := fun r h => hC (h.trans (cubeSum_zero f).symm)
    simp [this]
  | succ n ih =>
    intro f hf C hC P
    obtain ⟨s, P'⟩ := P
    rw [card_filter_cons]
    by_cases hs : s 0 + s 1 = C
    · set B := univ.filter (fun r => interpEval s r = cubeSum (fun x => f (Fin.cons r x))) with hB
      have hBcard : B.card ≤ d := sumcheck_one_round hd hf hC s hs
      have hslice : ∀ a : F,
          (univ.filter (fun x : Fin n → F => Accepts (n + 1) f C ⟨s, P'⟩ (Fin.cons a x))).card * Fintype.card F
            ≤ (if a ∈ B then Fintype.card F ^ (n + 1) else 0) + n * d * Fintype.card F ^ n := by
        intro a
        have hset : univ.filter (fun x : Fin n → F => Accepts (n + 1) f C ⟨s, P'⟩ (Fin.cons a x))
            = univ.filter (fun x => Accepts n (fun y => f (Fin.cons a y)) (interpEval s a) (P' a) x) := by
          refine filter_congr (fun x _ => ?_)
          simp only [Accepts, Fin.cons_zero, Fin.tail_cons, hs, true_and]
        rw [hset]
        by_cases ha : a ∈ B
        · simp only [ha, ↓reduceIte]
          refine le_trans ?_ (Nat.le_add_right _ _)
          rw [pow_succ]
          refine Nat.mul_le_mul_right _ ((card_le_univ _).trans ?_)
          simp
        · simp only [ha, ↓reduceIte, zero_add]
          have hclaim : interpEval s a ≠ cubeSum (fun y => f (Fin.cons a y)) := by
            intro h
            exact ha (by simp [hB, h])
          exact ih _ (hf.cons a) _ hclaim (P' a)
      rw [sum_mul]
      refine le_trans (sum_le_sum (fun a _ => hslice a)) ?_
      rw [sum_add_distrib, sum_ite_mem, univ_inter, sum_const, sum_const, card_univ, smul_eq_mul,
        smul_eq_mul]
      have hrest : Fintype.card F * (n * d * Fintype.card F ^ n) = n * d * Fintype.card F ^ (n + 1) := by
        rw [pow_succ]
        ring
      calc B.card * Fintype.card F ^ (n + 1) + Fintype.card F * (n * d * Fintype.card F ^ n)
          ≤ d * Fintype.card F ^ (n + 1) + n * d * Fintype.card F ^ (n + 1) :=
            Nat.add_le_add (Nat.mul_le_mul_right _ hBcard) (le_of_eq hrest)
        _ = (n + 1) * d * Fintype.card F ^ (n + 1) := by ring
    · have : ∀ a : F, univ.filter (fun x : Fin n → F => Accepts (n + 1) f C ⟨s, P'⟩ (Fin.cons a x)) = ∅ := by
        intro a
        apply filter_false_of_mem
        intro x _ h
        exact hs (by simpa [Accepts] using h.1)
      simp [this]

/-! ## Probability -/

omit [DecidableEq F] in
/-- From a count over `F^n` to a probability: `c·|F| ≤ n·d·|F|^n` gives `c / |F|^n ≤ n·d / |F|`. -/
theorem prob_of_count {n : ℕ} (E : (Fin n → F) → Prop) (k : ℕ)
    (h : ∀ [DecidablePred E], (univ.filter E).card * Fintype.card F ≤ k * Fintype.card F ^ n) :
    (PMF.uniformOfFintype (Fin n → F)).toOuterMeasure {r | E r} ≤ (k : ℝ≥0∞) / Fintype.card F := by
  classical
  rw [PMF.toOuterMeasure_uniformOfFintype_apply, Fintype.card_fun, Fintype.card_fin,
    Fintype.card_ofFinset]
  have hq0 : (Fintype.card F : ℝ≥0∞) ≠ 0 := by exact_mod_cast Fintype.card_ne_zero
  have hqt : (Fintype.card F : ℝ≥0∞) ≠ ⊤ := ENNReal.natCast_ne_top _
  have hpn0 : ((Fintype.card F ^ n : ℕ) : ℝ≥0∞) ≠ 0 := by exact_mod_cast pow_ne_zero n Fintype.card_ne_zero
  have hpnt : ((Fintype.card F ^ n : ℕ) : ℝ≥0∞) ≠ ⊤ := ENNReal.natCast_ne_top _
  have hfilt : (univ.filter (fun r => r ∈ {r | E r})) = univ.filter E := by
    ext r
    simp
  rw [hfilt]
  calc ((univ.filter E).card : ℝ≥0∞) / ((Fintype.card F ^ n : ℕ) : ℝ≥0∞)
      = ((univ.filter E).card * Fintype.card F : ℝ≥0∞) / ((Fintype.card F ^ n : ℕ) * Fintype.card F) :=
        (ENNReal.mul_div_mul_right _ _ hq0 hqt).symm
    _ ≤ ((k * Fintype.card F ^ n : ℕ) : ℝ≥0∞) / ((Fintype.card F ^ n : ℕ) * Fintype.card F) := by
        gcongr
        exact_mod_cast h
    _ = (k : ℝ≥0∞) / Fintype.card F := by
        rw [Nat.cast_mul, mul_comm ((Fintype.card F ^ n : ℕ) : ℝ≥0∞)]
        exact ENNReal.mul_div_mul_right _ _ hpn0 hpnt

/-- **Sumcheck soundness (interactive).** If the claim `C` is false (`C ≠ Σ_{x ∈ {0,1}^n} f(x)`) and `f` has degree at
most `d` in each variable, then for ANY prover strategy `P` the verifier accepts with probability at most `n·d / |F|`
over uniform independent challenges. Hypothesis `d < char F`: the code's value form needs distinct nodes
`0, …, d`. -/
theorem sumcheck_sound {n d : ℕ} (hd : d < ringChar F) {f : (Fin n → F) → F} (hf : IndDegLE d f) {C : F}
    (hC : C ≠ cubeSum f) (P : Prover F d n) :
    (PMF.uniformOfFintype (Fin n → F)).toOuterMeasure {r | Accepts n f C P r}
      ≤ ((n * d : ℕ) : ℝ≥0∞) / Fintype.card F := by
  refine prob_of_count _ (n * d) ?_
  intro _
  convert card_accepts_le hd n f hf C hC P

/-- **One round, as a probability.** If the claim is false and the first message passes the check
`s(0) + s(1) = C`, the next claim is TRUE with probability at most `d / |F|` over the round's challenge. -/
theorem sumcheck_sound_one_round {n d : ℕ} (hd : d < ringChar F) {f : (Fin (n + 1) → F) → F}
    (hf : IndDegLE d f) {C : F} (hC : C ≠ cubeSum f) (s : Fin (d + 1) → F) (hs : s 0 + s 1 = C) :
    (PMF.uniformOfFintype F).toOuterMeasure {r | interpEval s r = cubeSum (fun x => f (Fin.cons r x))}
      ≤ (d : ℝ≥0∞) / Fintype.card F :=
  prob_le_of_card_filter _ d (sumcheck_one_round hd hf hC s hs)

/-- **The masked sumcheck (`--zk`).** The code runs the sumcheck on `f + c·g`, where `g` is the committed mask
polynomial, with the claim `S + c·G`, `G = Σ g` (opened from the mask commitment). For ANY mask `g` of individual
degree `≤ d` (`CfsMask` is: `a₀ + a'·Π x_j + Σ_j Σ_{e ≤ d} a_{j,e} x_j^e`, degree `≤ max(1, d)` in each variable) and
ANY `c`, a false `S` gives a false masked claim, so the bound is unchanged. This needs `G` to be the true cube sum of
the same `g` whose terminal `g(ρ)` the verifier uses: both come from the binding mask commitment. -/
theorem sumcheck_sound_masked {n d : ℕ} (hd : d < ringChar F) {f g : (Fin n → F) → F} (hf : IndDegLE d f)
    (hg : IndDegLE d g) (c : F) {S : F} (hS : S ≠ cubeSum f) (P : Prover F d n) :
    (PMF.uniformOfFintype (Fin n → F)).toOuterMeasure
        {r | Accepts n (fun x => f x + c * g x) (S + c * cubeSum g) P r}
      ≤ ((n * d : ℕ) : ℝ≥0∞) / Fintype.card F := by
  refine sumcheck_sound hd (hf.add_smul hg c) ?_ P
  rw [cubeSum_add_smul]
  exact fun h => hS (add_right_cancel h)

/-- **The last-round extension.** The code extends every private table by a trailing variable `y` and sums
`fe(x, y)` over `{0,1}^(n+1)`. If `fe` restricts to `f` at `y = 0` and vanishes at `y = 1` on the cube, then a false
claim about `Σ f` is accepted with probability at most `(n + 1)·d / |F|`: the extension costs one round. -/
theorem sumcheck_sound_extended {n d : ℕ} (hd : d < ringChar F) {fe : (Fin (n + 1) → F) → F}
    (hfe : IndDegLE d fe) (f : (Fin n → F) → F)
    (h0 : ∀ b : Fin n → Bool, fe (Fin.snoc (fun i => bit (b i)) 0) = f (fun i => bit (b i)))
    (h1 : ∀ b : Fin n → Bool, fe (Fin.snoc (fun i => bit (b i)) 1) = 0)
    {C : F} (hC : C ≠ cubeSum f) (P : Prover F d (n + 1)) :
    (PMF.uniformOfFintype (Fin (n + 1) → F)).toOuterMeasure {r | Accepts (n + 1) fe C P r}
      ≤ (((n + 1) * d : ℕ) : ℝ≥0∞) / Fintype.card F := by
  refine sumcheck_sound hd hfe ?_ P
  have : cubeSum fe = cubeSum f := by
    rw [cubeSum_snoc]
    simp only [cubeSum, h0, h1, sum_const_zero, add_zero]
  rw [this]
  exact hC

omit [Fintype F] [DecidableEq F] in
/-- **The code's extension has the two halves.** `T_ext(x, y) = (1 − y)·T(x) + y·R_T(x)` for each private table,
`(1 − y)·P(x)` for each public one, and `fe = poly(private, public)`. At `y = 0` this is `poly(T, P)`; at `y = 1` it
is `poly(R, 0)`, which is zero whenever `poly` vanishes once all its public inputs are zero (every term carries a
public factor: an `eq`, a selector, a public weight). That condition is what makes the extension sound; a slot whose
`poly` had a term with no public factor would let the mask rows `R` pay for a false claim. -/
theorem extension_halves {n k l : ℕ} (poly : (Fin k → F) → (Fin l → F) → F)
    (hpoly : ∀ u, poly u 0 = 0) (T R : Fin k → (Fin n → F) → F) (Pub : Fin l → (Fin n → F) → F) (x : Fin n → F) :
    (let fe := fun z : Fin (n + 1) → F =>
        poly (fun t => (1 - z (Fin.last n)) * T t (Fin.init z) + z (Fin.last n) * R t (Fin.init z))
          (fun t => (1 - z (Fin.last n)) * Pub t (Fin.init z))
     fe (Fin.snoc x 0) = poly (fun t => T t x) (fun t => Pub t x) ∧ fe (Fin.snoc x 1) = 0) := by
  intro fe
  constructor
  · simp only [fe, Fin.snoc_last, Fin.init_snoc, sub_zero, one_mul, zero_mul, add_zero]
  · simp only [fe, Fin.snoc_last, Fin.init_snoc, sub_self, zero_mul, zero_add, one_mul]
    exact hpoly _

end ZK60.Sound
