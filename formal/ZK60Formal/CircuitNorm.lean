/-
D63, step L2 (`CircuitIff`), family 2: RMSNORM, the isqrt witness and the rounded division (both norms of the block,
`norm_a` on the input, `norm_m` on the first residual; `Dom::D` carries their eight remainder lookups, a third of the
domain's nineteen).

The constraints, as the code builds them:
* the isqrt (`SC_TZC`, argument.rs:2088-2095): `dsq − d² = 0`, `2d − a1 − a2 = 0`, and the term
  `dsq + a1 − ceps` hosted by the sum-of-squares sumcheck (`SC_SS`), i.e. `dsq + a1 = ss` with
  `ss = ceps + Σ x²`; `d`, `a1`, `a2` are each three byte limbs (`LIMBS_ISQRT = 3`, `d = dl` at :2090), certified
  here as `InRange 24`;
* the division (`dzc_w16`, argument_accuracy.rs:490-493): `γ·x·(2cn) + d·2^tn − (2^(tn+1)·d)·y − nr = 0` and
  `nr + ns + 1 − 2^(tn+1)·d = 0`, with `nr`, `ns` 24-bit remainders (two W16 limbs each, accuracy_layout.rs:308-310)
  and `y` int16.

The spec (ModelInt.lean): `isqrtWitness` and `normElem`, the loop body of `witness_accuracy::normalized`.

Proved: `isqrt_iff` and `normDiv_iff`. Two byte-preserving observations for the prover (candidates C8):
* `isqrt_pos`: `ss ≥ 1` forces `d ≥ 1`, so the builder's `d == 0` refusal (witness_accuracy.rs:422) never fires when
  `ceps ≥ 1` (it is 1 at every registered shape, 123 at the fixture);
* `normDiv_d_zero`: with `d = 0` the division constraints are unsatisfiable anyway, so the circuit needs no
  `d ≠ 0` check either.
-/
import ZK60Formal.CircuitRequant

namespace ZK60.Circuit

open ZK60.Model

/-! ## The isqrt -/

/-- `SC_TZC`'s clauses at one token, with the hosted sum of squares `ss = ceps + Σ x²`. -/
def IsqrtRel (ss d dsq a1 a2 : GF) : Prop := dsq - d * d = 0 ∧ 2 * d - a1 - a2 = 0 ∧ dsq + a1 = ss

/-- **`CircuitIff` for the isqrt.** For `0 ≤ ss < 2^60`, the clauses and the three 24-bit facts hold exactly when the
spec's witness is in its window and `d` is the image of `isqrt ss`. -/
theorem isqrt_iff (ss : ℤ) (hss0 : 0 ≤ ss) (hss : ss < 2 ^ 60) (d : GF) :
    (∃ dsq a1 a2 : GF, IsqrtRel (ss : GF) d dsq a1 a2 ∧ InRange 24 d ∧ InRange 24 a1 ∧ InRange 24 a2) ↔
      (inIsqrtWindow (isqrtWitness ss).1 = true ∧ inIsqrtWindow (isqrtWitness ss).2.1 = true ∧
        inIsqrtWindow (isqrtWitness ss).2.2 = true ∧ d = ((isqrtWitness ss).1 : GF)) := by
  have hn : ((ss.toNat : ℕ) : ℤ) = ss := Int.toNat_of_nonneg hss0
  constructor
  · rintro ⟨dsq, a1, a2, ⟨h1, h2, h3⟩, ⟨di, hd0, hd1, rfl⟩, ⟨b, hb0, hb1, rfl⟩, ⟨c, hc0, hc1, rfl⟩⟩
    have hdsq : dsq = ((di * di : ℤ) : GF) := by push_cast; linear_combination h1
    have e3 : (((di * di + b - ss : ℤ)) : GF) = 0 := by
      rw [hdsq] at h3; push_cast at h3 ⊢; linear_combination h3
    have e2 : (((2 * di - b - c : ℤ)) : GF) = 0 := by push_cast; linear_combination h2
    have hdd : 0 ≤ di * di := mul_self_nonneg di
    have hdd2 : di * di ≤ 2 ^ 48 := by nlinarith
    have E3 := int_eq_zero_of_cast e3 (by nlinarith) (by nlinarith)
    have E2 := int_eq_zero_of_cast e2 (by linarith) (by linarith)
    -- d² ≤ ss ≤ d² + 2d < (d + 1)²: d is the isqrt
    have hk : ((di.toNat : ℕ) : ℤ) = di := Int.toNat_of_nonneg hd0
    have hsq : di.toNat = Nat.sqrt ss.toNat := by
      rw [Nat.eq_sqrt]
      constructor
      · have : ((di.toNat : ℤ)) * (di.toNat : ℤ) ≤ ((ss.toNat : ℕ) : ℤ) := by rw [hk, hn]; linarith
        exact_mod_cast this
      · have : ((ss.toNat : ℕ) : ℤ) < ((di.toNat : ℤ) + 1) * ((di.toNat : ℤ) + 1) := by rw [hk, hn]; nlinarith
        exact_mod_cast this
    have hw : (isqrtWitness ss).1 = di := by
      unfold isqrtWitness
      simp only
      rw [← hsq, hk]
    have hw1 : (isqrtWitness ss).2.1 = b := by
      unfold isqrtWitness; simp only; rw [← hsq, hk]; linarith
    have hw2 : (isqrtWitness ss).2.2 = c := by
      unfold isqrtWitness; simp only; rw [← hsq, hk]; linarith
    refine ⟨?_, ?_, ?_, by rw [hw]⟩
    · rw [hw]; unfold inIsqrtWindow; exact decide_eq_true ⟨hd0, hd1⟩
    · rw [hw1]; unfold inIsqrtWindow; exact decide_eq_true ⟨hb0, hb1⟩
    · rw [hw2]; unfold inIsqrtWindow; exact decide_eq_true ⟨hc0, hc1⟩
  · rintro ⟨w0, w1, w2, hd⟩
    unfold inIsqrtWindow at w0 w1 w2
    have w0' := of_decide_eq_true w0
    have w1' := of_decide_eq_true w1
    have w2' := of_decide_eq_true w2
    set dd := (isqrtWitness ss).1 with hdd
    have h1v : (isqrtWitness ss).2.1 = ss - dd * dd := by rw [hdd]; rfl
    have h2v : (isqrtWitness ss).2.2 = 2 * dd - (ss - dd * dd) := by rw [hdd]; rfl
    refine ⟨((dd * dd : ℤ) : GF), (((isqrtWitness ss).2.1 : ℤ) : GF), (((isqrtWitness ss).2.2 : ℤ) : GF),
      ⟨?_, ?_, ?_⟩, ⟨dd, w0'.1, w0'.2, hd⟩, ⟨_, w1'.1, w1'.2, rfl⟩, ⟨_, w2'.1, w2'.2, rfl⟩⟩
    · rw [hd]; push_cast; ring
    · rw [hd, h1v, h2v]; push_cast; ring
    · rw [h1v]; push_cast; ring

/-- `ss ≥ 1` forces a positive isqrt: the builder's `d == 0` refusal is unreachable when `ceps ≥ 1`. -/
theorem isqrt_pos (ss : ℤ) (h : 1 ≤ ss) : 1 ≤ (isqrtWitness ss).1 := by
  unfold isqrtWitness
  simp only
  have : 0 < Nat.sqrt ss.toNat := Nat.sqrt_pos.mpr (by omega)
  exact_mod_cast this

/-! ## The rounded division -/

/-- `dzc_w16`'s two division clauses at one position. -/
def NormDivRel (tn : ℕ) (cn g x d y nr ns : GF) : Prop :=
  g * x * (2 * cn) + d * 2 ^ tn - 2 ^ (tn + 1) * d * y - nr = 0 ∧ nr + ns + 1 - 2 ^ (tn + 1) * d = 0

theorem normElem_eq_some {tn : ℕ} {cn d x g q r s : ℤ} :
    normElem tn cn d x g = some (q, r, s) ↔
      (int16Lo ≤ (2 * x * g * cn + d * 2 ^ tn) / (2 * (d * 2 ^ tn)) ∧
        (2 * x * g * cn + d * 2 ^ tn) / (2 * (d * 2 ^ tn)) ≤ int16Hi ∧
        (2 * x * g * cn + d * 2 ^ tn) % (2 * (d * 2 ^ tn)) < 2 ^ 24 ∧
        2 * (d * 2 ^ tn) - 1 - (2 * x * g * cn + d * 2 ^ tn) % (2 * (d * 2 ^ tn)) < 2 ^ 24) ∧
      q = (2 * x * g * cn + d * 2 ^ tn) / (2 * (d * 2 ^ tn)) ∧
      r = (2 * x * g * cn + d * 2 ^ tn) % (2 * (d * 2 ^ tn)) ∧
      s = 2 * (d * 2 ^ tn) - 1 - (2 * x * g * cn + d * 2 ^ tn) % (2 * (d * 2 ^ tn)) := by
  simp only [normElem]
  split_ifs with h
  · constructor
    · intro he
      simp only [Option.some.injEq, Prod.mk.injEq] at he
      exact ⟨h, he.1.symm, he.2.1.symm, he.2.2.symm⟩
    · rintro ⟨_, rfl, rfl, rfl⟩
      rfl
  · constructor
    · intro he
      exact absurd he (by simp)
    · rintro ⟨h', _⟩
      exact absurd h' h

/-- **`CircuitIff` for one element of a norm row.** Given the row's `d` (`1 ≤ d < 2^24`, from `isqrt_iff`), an
int16 input `x`, a symmetric int8 gain `γ`, `|cn| ≤ 2^24` and `tn ≤ 16`: the division clauses, the two 24-bit
remainders and `y`'s int16 lookup hold exactly when the spec admits the element and `y` is its word. -/
theorem normDiv_iff (tn : ℕ) (htn : tn ≤ 16) (cn g x d : ℤ) (hcn : |cn| ≤ 2 ^ 24) (hg : |g| ≤ 127)
    (hx : |x| ≤ 2 ^ 15) (hd1 : 1 ≤ d) (hd2 : d < 2 ^ 24) (y : GF) :
    ((∃ nr ns : GF, NormDivRel tn (cn : GF) (g : GF) (x : GF) (d : GF) y nr ns ∧ RemW16 24 nr ∧ RemW16 24 ns) ∧
        Word16 y) ↔
      ∃ q r s, normElem tn cn d x g = some (q, r, s) ∧ y = (q : GF) := by
  have hT0 : (0 : ℤ) < 2 ^ tn := by positivity
  have hT : (2 : ℤ) ^ tn ≤ 2 ^ 16 := pow_le_pow_right₀ (by norm_num) htn
  have hden : (2 : ℤ) ^ (tn + 1) * d = 2 * (d * 2 ^ tn) := by ring
  have hdT1 : 0 < d * 2 ^ tn := mul_pos (by linarith) hT0
  have hdT2 : d * 2 ^ tn ≤ 2 ^ 40 := by
    have h1 : d * 2 ^ tn ≤ 2 ^ 24 * 2 ^ tn := mul_le_mul_of_nonneg_right (le_of_lt hd2) (le_of_lt hT0)
    have h2 : (2 : ℤ) ^ 24 * 2 ^ tn ≤ 2 ^ 24 * 2 ^ 16 := mul_le_mul_of_nonneg_left hT (by norm_num)
    linarith
  have hdT : 0 < d * 2 ^ tn ∧ d * 2 ^ tn ≤ 2 ^ 40 := ⟨hdT1, hdT2⟩
  have hden0 : (0 : ℤ) < 2 * (d * 2 ^ tn) := by linarith
  -- the bounds of every product in the clauses
  have hgx := mul_bounds hg hx
  have hc2 : |2 * cn| ≤ 2 ^ 25 := by
    rw [abs_mul, abs_two]; linarith
  have hgxc := mul_bounds (abs_le.mpr ⟨by linarith [hgx.1], by linarith [hgx.2]⟩ : |g * x| ≤ 127 * 2 ^ 15) hc2
  constructor
  · rintro ⟨⟨nr, ns, ⟨h1, h2⟩, hnr, hns⟩, hy⟩
    obtain ⟨yi, hy0, hy1, rfl⟩ := (word16_iff y).mp hy
    obtain ⟨a, ha0, ha1, rfl⟩ := (remW16_iff 24 nr).mp hnr
    obtain ⟨b, hb0, hb1, rfl⟩ := (remW16_iff 24 ns).mp hns
    have hyb : |yi| ≤ 2 ^ 15 := abs_le.mpr ⟨by linarith, by linarith⟩
    have hKb : |2 * (d * 2 ^ tn)| ≤ 2 ^ 41 := by
      rw [abs_of_pos hden0]; linarith [hdT.2]
    have hKy := mul_bounds hKb hyb
    have e1 : ((g * x * (2 * cn) + d * 2 ^ tn - 2 * (d * 2 ^ tn) * yi - a : ℤ) : GF) = 0 := by
      push_cast; linear_combination h1
    have e2 : ((a + b + 1 - 2 * (d * 2 ^ tn) : ℤ) : GF) = 0 := by
      push_cast; linear_combination h2
    have E1 := int_eq_zero_of_cast e1 (by nlinarith [hgxc.1, hKy.2]) (by nlinarith [hgxc.2, hKy.1])
    have E2 := int_eq_zero_of_cast e2 (by linarith [hdT.2]) (by linarith [hdT.2])
    have hdiv : (2 * x * g * cn + d * 2 ^ tn) / (2 * (d * 2 ^ tn)) = yi ∧
        (2 * x * g * cn + d * 2 ^ tn) % (2 * (d * 2 ^ tn)) = a :=
      (Int.ediv_emod_unique hden0).mpr ⟨by linarith, ha0, by linarith⟩
    refine ⟨yi, a, b, normElem_eq_some.mpr ⟨⟨?_, ?_, ?_, ?_⟩, hdiv.1.symm, hdiv.2.symm, ?_⟩, rfl⟩
    · rw [hdiv.1]; unfold int16Lo; norm_num at hy0 ⊢; linarith
    · rw [hdiv.1]; unfold int16Hi; norm_num at hy1 ⊢; linarith
    · rw [hdiv.2]; exact ha1
    · rw [hdiv.2]; linarith
    · rw [hdiv.2]; linarith
  · rintro ⟨q, r, s, hspec, rfl⟩
    obtain ⟨⟨hq0, hq1, hr1, hs1⟩, hq, hr, hs⟩ := normElem_eq_some.mp hspec
    have hm := Int.mul_ediv_add_emod (2 * x * g * cn + d * 2 ^ tn) (2 * (d * 2 ^ tn))
    have hr0 : 0 ≤ r := by rw [hr]; exact Int.emod_nonneg _ (ne_of_gt hden0)
    have hrl : r < 2 * (d * 2 ^ tn) := by rw [hr]; exact Int.emod_lt_of_pos _ hden0
    have hsr : 0 ≤ s := by rw [hs, ← hr]; linarith
    refine ⟨⟨(r : GF), (s : GF), ⟨?_, ?_⟩, (remW16_iff 24 _).mpr ⟨r, hr0, by rw [hr]; exact hr1, rfl⟩,
      (remW16_iff 24 _).mpr ⟨s, hsr, by rw [hs]; exact hs1, rfl⟩⟩,
      (word16_iff _).mpr ⟨q, by rw [hq]; unfold int16Lo at hq0; linarith,
        by rw [hq]; unfold int16Hi at hq1; linarith, rfl⟩⟩
    · have hint : g * x * (2 * cn) + d * 2 ^ tn - 2 ^ (tn + 1) * d * q - r = 0 := by
        rw [hden, hq, hr]; linarith
      have : ((g * x * (2 * cn) + d * 2 ^ tn - 2 ^ (tn + 1) * d * q - r : ℤ) : GF) = 0 := by
        rw [hint]; simp
      push_cast at this
      exact this
    · have hint : r + s + 1 - 2 ^ (tn + 1) * d = 0 := by rw [hden, hs, hr]; ring
      have : ((r + s + 1 - 2 ^ (tn + 1) * d : ℤ) : GF) = 0 := by rw [hint]; simp
      push_cast at this
      exact this

/-- With `d = 0` the division is unsatisfiable (`nr + ns + 1 = 0` with two 24-bit remainders): the circuit needs no
`d ≠ 0` check of its own. -/
theorem normDiv_d_zero (tn : ℕ) (cn g x y nr ns : GF) (hnr : RemW16 24 nr) (hns : RemW16 24 ns) :
    ¬ NormDivRel tn cn g x 0 y nr ns := by
  rintro ⟨_, h2⟩
  obtain ⟨a, ha0, ha1, rfl⟩ := (remW16_iff 24 nr).mp hnr
  obtain ⟨b, hb0, hb1, rfl⟩ := (remW16_iff 24 ns).mp hns
  have e : ((a + b + 1 : ℤ) : GF) = 0 := by push_cast; linear_combination h2
  have := int_eq_zero_of_cast e (by linarith) (by norm_num at ha1 hb1 ⊢; linarith)
  linarith

end ZK60.Circuit
