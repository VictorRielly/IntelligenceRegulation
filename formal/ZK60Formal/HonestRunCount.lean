/-
D63 Lean lane L32 (2026-11-09), part 3: **one opening's refusal sites as one family, their exact count, and the run's
count with stage IN-C's correction** (ClassifyOpen's field O10, finding L29-3's count).

* `openSite`, `openK`, **`openSite_k`**, **`openK_sum`**, **`openSite_cover`**: the sites of ONE `check_opening`'s
  challenge refusals (`HonestOpenSites.lean`) as a family indexed by `Option (Fin n ⊕ Unit)` (`n = Σ counts`, the
  number of claims on the commitment, whatever the grouping): `n` zero-member sites and the pair's zero first draw with one bad value each, the
  dependent pair with at most `p`; every `δ = 0`; EXACTLY `p + n + 1` bad values in all; and
  `check_opening_challenges` refuses only when one of them fires (or the geometry has no pair: deterministic);
* **`open_refusal_eq`**: the family's part of the completeness total, `(p + n + 1)·fibC/|Dig|` (`Site.prob_le`'s terms
  summed);
* **`shield_k_le_inc`**, **`shield_refusal_total_le_inc`**: lane L25's count at the Shieldstral classify run with
  stage IN-C's D66(3) refusal counted as `kEmb + 1` sites of at most `V ≤ 2^17` values (finding L29-3: one at `α`, one
  per coordinate of `r_emb`; `kEmb = 12` at `d_pad = 4096`) beside at most `2^7` other LogUp sites: the total is still
  at most `2^85` bad values, and the completeness total at most `εcTarget = 2^-40`.

The counts per kind other than the per-opening one stay CODE counts (L18 §4.1); the `kEmb + 1` sites of stage IN-C are
counted here, not built (finding L32-5).
-/
import ZK60Formal.HonestOpenSites

set_option autoImplicit false

namespace ZK60.HonestRun

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.HonestClassify ZK60.ProtocolClassify ZK60.HonestOracle ZK60.HonestOpen
open ZK60.Circuit (gP GF)

/-! ## One opening's sites -/

section OpenSites

variable (Lq : ℕ) (hLq : 47 ≤ Lq) {α : Type} {Coins : Type} [Fintype Coins] [Nonempty Coins]
  {K : Type} [Field K] [DecidableEq K] [Algebra GF K] (U : K)

/-- **One opening's refusal sites** (`check_opening_challenges` after the prefix `pre`, on a commitment with `n` claims:
`n` member draws in all, whatever the grouping): `some (inl i)` the zero draw of member `i`, `some (inr ())` the zero
first draw of the proximity pair, `none` the dependent pair. -/
noncomputable def openSite (n prox : ℕ) (pre : Coins → TProg α) (t0 : Coins → Tr)
    (hs : ∀ c, TProg.Sep (t0 c).key (pre c)) (hn : ∀ (j : ℕ) (c : Coins), TProg.NoWrap (drawProg j (pre c)) (t0 c)) :
    Option (Fin n ⊕ Unit) → Site (QB Lq) Coins K
  | some (.inl i) => drawZeroSite Lq hLq i pre t0 hs (hn i)
  | some (.inr _) => drawZeroSite Lq hLq (n + prox) pre t0 hs (hn (n + prox))
  | none => depPairSite Lq hLq U (n + prox) pre t0 hs (hn (n + prox + 1))

/-- The bad values per site of an opening: `p` for the dependent pair, `1` for a zero draw. -/
def openK {n : ℕ} : Option (Fin n ⊕ Unit) → ℕ
  | none => gP
  | some _ => 1

/-- **Each site of an opening has its `k` and `δ = 0`.** -/
theorem openSite_k (n prox : ℕ) (pre : Coins → TProg α) (t0 : Coins → Tr)
    (hs : ∀ c, TProg.Sep (t0 c).key (pre c)) (hn : ∀ (j : ℕ) (c : Coins), TProg.NoWrap (drawProg j (pre c)) (t0 c)) :
    ∀ i, (openSite Lq hLq U n prox pre t0 hs hn i).k = openK i
      ∧ (openSite Lq hLq U n prox pre t0 hs hn i).δ = 0
  | some (.inl _) => ⟨rfl, rfl⟩
  | some (.inr _) => ⟨rfl, rfl⟩
  | none => ⟨rfl, rfl⟩

/-- **One opening has exactly `p + n + 1` bad values** over its `n + 2` sites. -/
theorem openK_sum (n : ℕ) : ∑ i : Option (Fin n ⊕ Unit), openK i = gP + (n + 1) := by
  rw [Fintype.sum_option, Fintype.sum_sum_type]
  simp [openK]

variable (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **`check_opening_challenges` refuses only when a site of the opening's family fires** (or the geometry has no
proximity pair, a deterministic fact of the registered layout), for member counts that add up to the commitment's `n`
claims. -/
theorem openSite_cover (counts : List ℕ) (n : ℕ) (hsum : counts.sum = n) (rows prox : ℕ) (pre : Coins → TProg α)
    (t0 : Coins → Tr) (hs : ∀ c, TProg.Sep (t0 c).key (pre c))
    (hn : ∀ (j : ℕ) (c : Coins), TProg.NoWrap (drawProg j (pre c)) (t0 c)) (G : QB Lq → Dig) (c : Coins) (e : String)
    (h : Block.openingChallenges (liftH G) counts rows prox ((pre c).final (liftH G) (t0 c)).1 = .error e) :
    rows ≤ prox + 1 ∨ ∃ i, (openSite Lq hLq U n prox pre t0 hs hn i).fires U G c := by
  subst hsum
  rcases openingChallenges_cover Lq hLq U hU counts rows prox pre t0 hs hn G c e h with h1 | ⟨j, hj, hf⟩ | hf | hf
  · exact Or.inl h1
  · exact Or.inr ⟨some (.inl ⟨j, hj⟩), hf⟩
  · exact Or.inr ⟨some (.inr ()), hf⟩
  · exact Or.inr ⟨none, hf⟩

/-- **One opening's part of the completeness total**: `Σ (k·fibC/|Dig| + δ)` over its sites is
`(p + n + 1)·fibC/|Dig|`. -/
theorem open_refusal_eq (n prox : ℕ) (pre : Coins → TProg α) (t0 : Coins → Tr)
    (hs : ∀ c, TProg.Sep (t0 c).key (pre c)) (hn : ∀ (j : ℕ) (c : Coins), TProg.NoWrap (drawProg j (pre c)) (t0 c)) :
    ∑ i, ((((openSite Lq hLq U n prox pre t0 hs hn i).k * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig
        + (openSite Lq hLq U n prox pre t0 hs hn i).δ)
      = (((gP + (n + 1)) * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig := by
  have e : ∀ i, ((((openSite Lq hLq U n prox pre t0 hs hn i).k * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig
      + (openSite Lq hLq U n prox pre t0 hs hn i).δ) = ((openK i * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig := by
    intro i
    rw [(openSite_k Lq hLq U n prox pre t0 hs hn i).1, (openSite_k Lq hLq U n prox pre t0 hs hn i).2, add_zero]
  rw [Finset.sum_congr rfl (fun i _ => e i)]
  simp only [div_eq_mul_inv]
  rw [← Finset.sum_mul, ← Nat.cast_sum, ← Finset.sum_mul, openK_sum]

end OpenSites

/-! ## The sequential zero test behind stage IN-C's `kEmb + 1` sites -/

section SeqZero

/-- **A value built one coordinate at a time vanishes only at a listed place** (the count of finding L29-3). Let
`f 0, …, f k` be the values of one table row's difference `τ(v)(r_1, …, r_i, 0, …, 0) − α` as the coordinates of
`r_emb` are drawn (`f 0`: before any; `f k`: the row's entry minus `α`), each step affine in its own coordinate:
`f (i + 1) = f i + r_i·s_i` with the slope `s_i` a function of the earlier draws (a multilinear `E~`). If the final
value is zero (`α` is the row's entry: D66(3)'s refusal), then either `f 0 = 0` (an event at `α`'s draw, one value of
`α` per row), or at the first coordinate `i` where the value becomes zero the draw `r_i` is the ONE value
`−f_i / s_i` fixed by the earlier draws. So the refusal is covered by `k + 1` sites of one bad value per row: at most
`V` values each over the `V` vocabulary rows. -/
theorem seq_zero {K : Type} [Field K] (f r s : ℕ → K) : ∀ (k : ℕ), (∀ i, i < k → f (i + 1) = f i + r i * s i) →
    f k = 0 → f 0 = 0 ∨ ∃ i, i < k ∧ f i ≠ 0 ∧ s i ≠ 0 ∧ r i = -(f i) / s i
  | 0, _, h => Or.inl h
  | k + 1, hstep, h => by
    by_cases hk : f k = 0
    · rcases seq_zero f r s k (fun i hi => hstep i (by omega)) hk with h0 | ⟨i, hi, h1, h2, h3⟩
      · exact Or.inl h0
      · exact Or.inr ⟨i, by omega, h1, h2, h3⟩
    · have e := hstep k (by omega)
      rw [h] at e
      have hs : s k ≠ 0 := by
        intro hs
        rw [hs, mul_zero, add_zero] at e
        exact hk e.symm
      refine Or.inr ⟨k, by omega, hk, hs, ?_⟩
      rw [eq_div_iff hs]
      linear_combination -e

end SeqZero

/-! ## The run's count with stage IN-C's correction -/

section Counts

/-- **The Shieldstral count with stage IN-C's D66(3) refusal as `kEmb + 1` sites** (finding L29-3): L25's
`shield_k_le` with the LogUp kind made of at most `2^7` sites and stage IN-C's `kEmb + 1` (one at `α`, one per
coordinate of `r_emb`: `kEmb = clog2(d_pad) ≤ 12`), each of at most `M ≤ 2^17` values. -/
theorem shield_k_le_inc (count : Fin 7 → ℕ) (M cap kEmb : ℕ) (h0 : count 0 ≤ 2 ^ 7) (h1 : count 1 ≤ 2 ^ 20)
    (h2 : count 2 ≤ 2 ^ 12) (h3 : count 3 ≤ 2 ^ 12) (h4 : count 4 ≤ 2 ^ 12) (hk : kEmb ≤ 12)
    (h5 : count 5 ≤ 2 ^ 7 + (kEmb + 1)) (h6 : count 6 ≤ 2 ^ 5) (hM : M ≤ 2 ^ 17) (hcap : cap ≤ 2 ^ 20) :
    ∑ i : SiteIdx count, kPer gP M cap i.1 ≤ 2 ^ 85 :=
  shield_k_le count M cap h0 h1 h2 h3 h4 (by omega) h6 hM hcap

/-- **The completeness total with stage IN-C's correction** is within the approved `εcTarget = 2^-40`. -/
theorem shield_refusal_total_le_inc (count : Fin 7 → ℕ) (M cap kEmb : ℕ) (h0 : count 0 ≤ 2 ^ 7)
    (h1 : count 1 ≤ 2 ^ 20) (h2 : count 2 ≤ 2 ^ 12) (h3 : count 3 ≤ 2 ^ 12) (h4 : count 4 ≤ 2 ^ 12)
    (hk : kEmb ≤ 12) (h5 : count 5 ≤ 2 ^ 7 + (kEmb + 1)) (h6 : count 6 ≤ 2 ^ 5) (hM : M ≤ 2 ^ 17)
    (hcap : cap ≤ 2 ^ 20) :
    ∑ i : SiteIdx count, (((kPer gP M cap i.1 * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig + 0) ≤ εcTarget :=
  shield_refusal_total_le count M cap h0 h1 h2 h3 h4 (by omega) h6 hM hcap

end Counts

end ZK60.HonestRun
