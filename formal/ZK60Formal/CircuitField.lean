/-
D63, step L2 (`CircuitIff`), the foundation: Goldilocks, no-wrap, and what a range lookup certifies.

Every committed plane of the W16R2 profile is a vector over Goldilocks `p = 2^64 − 2^32 + 1` (`GF` below; the
challenges live in `Fp2`, but every constraint of this part is an identity among base-field values with
base-field-cast integer constants). The constraints are field identities; the integer model is integer arithmetic.
They agree exactly when nothing WRAPS: `int_eq_of_cast_eq` is the one fact used everywhere, two integers with the same
image in `GF` and difference below `p` are equal.

What a lookup gives (finding F4 of the L3 findings: "the LogUp conclusion is about FIELD tuples"): L3's
`logup_block_bound` (SoundLogUpBlock.lean) concludes that every looked-up TUPLE `(x, tag, y, z)` equals some table
tuple, as field elements. For a range family of width `w` the table tuples are `(v, TAG_RANGE0 + w, 0, 0)` for the
integers `0 ≤ v < 2^w` (range16.rs:24-40, `table_column` range16.rs:216-219; the byte family is `TAG_U8`'s with
`w = 8`). `rangeTup_query_iff` turns "the query tuple of width `w` is a table tuple of some family" into `InRange w x`,
"x is the image of an integer in `[0, 2^w)`", provided the family tags are distinct naturals below `p` (the code's
test `the_range_tags_are_distinct_from_every_other_family`, range16.rs:262-283). That is the canonical-representative
obligation F4 asks of L2, discharged for the range families.

The shapes of the W16 range facts (range16.rs, accuracy_layout.rs:289-344):
* `Word16 x` — a signed 16-bit word looked up directly as `x + 32768` (`word16`, range16.rs:133-136);
* `RemW16 b R` — a `b`-bit remainder: one `b`-bit query if `b ≤ 16`, else a 16-bit low limb and a `(b − 16)`-bit top
  limb with `R = lo + 2^16·hi` (`rem_lookups`, range16.rs:121-130; `limbs16` in argument_accuracy.rs);
* `remW16_iff`: the two-limb form certifies EXACTLY what one direct `b`-bit query would, `InRange b R`. The proofs of
  the families below use only `InRange b R`; the limb split is a representation (optimization candidate C3 of the
  findings document).
-/
import Mathlib.Data.ZMod.Basic
import Mathlib.Tactic.Linarith
import Mathlib.Tactic.LinearCombination
import Mathlib.Tactic.NormNum
import Mathlib.Tactic.Positivity
import Mathlib.Tactic.Ring
import ZK60Formal.SoundLogUpBlock
import ZK60Formal.ModelInt

namespace ZK60.Circuit

/-- Goldilocks, `p = 2^64 − 2^32 + 1` (zkp-core `field.rs`). -/
abbrev gP : ℕ := 18446744069414584321

/-- The base field of every committed plane. -/
abbrev GF := ZMod gP

theorem gP_eq : gP = 2 ^ 64 - 2 ^ 32 + 1 := by norm_num

theorem gP_int : (gP : ℤ) = 18446744069414584321 := by norm_num

/-! ## No wrap -/

/-- **No wrap.** Two integers with the same image in `GF` that differ by less than `p` are equal. -/
theorem int_eq_of_cast_eq {a b : ℤ} (h : (a : GF) = (b : GF)) (h1 : -(gP : ℤ) < a - b) (h2 : a - b < gP) :
    a = b := by
  have hd : (gP : ℤ) ∣ b - a := (ZMod.intCast_eq_intCast_iff_dvd_sub a b gP).mp h
  have h0 : b - a = 0 := Int.eq_zero_of_abs_lt_dvd hd (abs_lt.mpr ⟨by linarith, by linarith⟩)
  linarith

/-- The no-wrap fact in the form the families use: an integer expression `E` whose image in `GF` is zero and
whose magnitude is below `2^63` is zero. -/
theorem int_eq_zero_of_cast {E : ℤ} (h : (E : GF) = 0) (h1 : -(2 : ℤ) ^ 63 ≤ E) (h2 : E ≤ 2 ^ 63) : E = 0 := by
  have h' : (E : GF) = ((0 : ℤ) : GF) := by rw [h]; simp
  exact int_eq_of_cast_eq h' (by rw [gP_int]; norm_num at h1 ⊢; linarith)
    (by rw [gP_int]; norm_num at h2 ⊢; linarith)

/-- `|a·b| ≤ A·B` from `|a| ≤ A`, `|b| ≤ B`, as two-sided bounds (what `linarith` consumes). -/
theorem mul_bounds {a b A B : ℤ} (ha : |a| ≤ A) (hb : |b| ≤ B) : -(A * B) ≤ a * b ∧ a * b ≤ A * B := by
  have h : |a * b| ≤ A * B := by
    rw [abs_mul]
    exact mul_le_mul ha hb (abs_nonneg _) (le_trans (abs_nonneg _) ha)
  exact abs_le.mp h

/-- An integer in `[lo, hi]` has absolute value at most `max (-lo) hi`, in the form used below. -/
theorem abs_le_of_mem {a lo hi B : ℤ} (h1 : lo ≤ a) (h2 : a ≤ hi) (hlo : -B ≤ lo) (hhi : hi ≤ B) : |a| ≤ B :=
  abs_le.mpr ⟨by linarith, by linarith⟩

/-! ## Range facts -/

/-- **What a range lookup of width `w` certifies:** `x` is the image of an integer in `[0, 2^w)`. -/
def InRange (w : ℕ) (x : GF) : Prop := ∃ t : ℤ, 0 ≤ t ∧ t < 2 ^ w ∧ x = (t : GF)

/-- The integer behind an `InRange` fact is unique (for `w ≤ 62`). -/
theorem inRange_unique {w : ℕ} (hw : w ≤ 62) {t t' : ℤ} (h0 : 0 ≤ t) (h1 : t < 2 ^ w) (h0' : 0 ≤ t') (h1' : t' < 2 ^ w)
    (h : (t : GF) = (t' : GF)) : t = t' := by
  have hp : (2 : ℤ) ^ w ≤ 2 ^ 62 := pow_le_pow_right₀ (by norm_num) hw
  exact int_eq_of_cast_eq h (by rw [gP_int]; linarith) (by rw [gP_int]; linarith)

/-- `Word16 x`: the signed 16-bit word `x` looked up directly as `x + 32768` (range16::word16). -/
def Word16 (x : GF) : Prop := InRange 16 (x + 32768)

theorem word16_iff (x : GF) : Word16 x ↔ ∃ q : ℤ, -2 ^ 15 ≤ q ∧ q ≤ 2 ^ 15 - 1 ∧ x = (q : GF) := by
  constructor
  · rintro ⟨t, h0, h1, h⟩
    refine ⟨t - 32768, by linarith, by norm_num at h1 ⊢; linarith, ?_⟩
    push_cast
    rw [← h]
    ring
  · rintro ⟨q, h0, h1, rfl⟩
    exact ⟨q + 32768, by norm_num at h0 ⊢; linarith, by norm_num at h1 ⊢; linarith, by push_cast; ring⟩

/-- `RemW16 b R`: a `b`-bit remainder in its W16 limbs (range16::rem_lookups): one `b`-bit query if `b ≤ 16`, else a
16-bit low limb `lo` and a `(b − 16)`-bit top limb `hi`, the remainder being the expression `lo + 2^16·hi`. -/
def RemW16 (b : ℕ) (R : GF) : Prop :=
  if b ≤ 16 then InRange b R else ∃ lo hi : GF, R = lo + 2 ^ 16 * hi ∧ InRange 16 lo ∧ InRange (b - 16) hi

/-- **Two limbs certify exactly one direct query.** A `16 + k`-bit remainder held as a 16-bit and a `k`-bit limb is
proved in `[0, 2^(16+k))`, and every such remainder has its limbs. -/
theorem twoLimbs_iff (k : ℕ) (R : GF) :
    (∃ lo hi : GF, R = lo + 2 ^ 16 * hi ∧ InRange 16 lo ∧ InRange k hi) ↔ InRange (16 + k) R := by
  have hpow : (2 : ℤ) ^ (16 + k) = 2 ^ 16 * 2 ^ k := pow_add 2 16 k
  have hk : (0 : ℤ) < 2 ^ k := by positivity
  constructor
  · rintro ⟨lo, hi, hR, ⟨t1, h10, h11, rfl⟩, ⟨t2, h20, h21, rfl⟩⟩
    refine ⟨t1 + 2 ^ 16 * t2, by positivity, ?_, by rw [hR]; push_cast; ring⟩
    rw [hpow]
    have : t2 ≤ 2 ^ k - 1 := by linarith
    nlinarith
  · rintro ⟨t, h0, h1, rfl⟩
    have h16 : (0 : ℤ) < 2 ^ 16 := by norm_num
    refine ⟨((t % 2 ^ 16 : ℤ) : GF), ((t / 2 ^ 16 : ℤ) : GF), ?_, ⟨t % 2 ^ 16, Int.emod_nonneg _ (by norm_num),
      Int.emod_lt_of_pos _ h16, rfl⟩, ⟨t / 2 ^ 16, Int.ediv_nonneg h0 (by norm_num), ?_, rfl⟩⟩
    · have h := Int.mul_ediv_add_emod t (2 ^ 16)
      have h' : ((t : ℤ) : GF) = (((t % 2 ^ 16 + 2 ^ 16 * (t / 2 ^ 16) : ℤ)) : GF) := by
        congr 1
        linarith
      rw [h']
      push_cast
      ring
    · rw [Int.ediv_lt_iff_lt_mul h16]
      linarith

/-- Limbs of any widths: an `m`-bit low limb and a `k`-bit high limb certify exactly `InRange (m + k)`. -/
theorem limbs_iff (m k : ℕ) (R : GF) :
    (∃ lo hi : GF, R = lo + 2 ^ m * hi ∧ InRange m lo ∧ InRange k hi) ↔ InRange (m + k) R := by
  have hpow : (2 : ℤ) ^ (m + k) = 2 ^ m * 2 ^ k := pow_add 2 m k
  have hm : (0 : ℤ) < 2 ^ m := by positivity
  constructor
  · rintro ⟨lo, hi, hR, ⟨t1, h10, h11, rfl⟩, ⟨t2, h20, h21, rfl⟩⟩
    refine ⟨t1 + 2 ^ m * t2, by positivity, ?_, by rw [hR]; push_cast; ring⟩
    rw [hpow]
    have h3 : t2 ≤ 2 ^ k - 1 := by linarith
    have h4 : 2 ^ m * t2 ≤ 2 ^ m * (2 ^ k - 1) := mul_le_mul_of_nonneg_left h3 (le_of_lt hm)
    linarith
  · rintro ⟨t, h0, h1, rfl⟩
    refine ⟨((t % 2 ^ m : ℤ) : GF), ((t / 2 ^ m : ℤ) : GF), ?_, ⟨t % 2 ^ m, Int.emod_nonneg _ (ne_of_gt hm),
      Int.emod_lt_of_pos _ hm, rfl⟩, ⟨t / 2 ^ m, Int.ediv_nonneg h0 (le_of_lt hm), ?_, rfl⟩⟩
    · have h := Int.mul_ediv_add_emod t (2 ^ m)
      have h' : ((t : ℤ) : GF) = (((t % 2 ^ m + 2 ^ m * (t / 2 ^ m) : ℤ)) : GF) := by
        congr 1
        linarith
      rw [h']
      push_cast
      ring
    · rw [Int.ediv_lt_iff_lt_mul hm]
      linarith

/-- **The isqrt's three byte limbs** (`LIMBS_ISQRT = 3`, the `l3` sum of `SC_TZC`, argument.rs:2088) certify exactly
`InRange 24`. -/
theorem threeBytes_iff (R : GF) :
    (∃ b0 b1 b2 : GF, R = b0 + 2 ^ 8 * b1 + 2 ^ 16 * b2 ∧ InRange 8 b0 ∧ InRange 8 b1 ∧ InRange 8 b2) ↔
      InRange 24 R := by
  constructor
  · rintro ⟨b0, b1, b2, hR, h0, h1, h2⟩
    have hlo : InRange 16 (b0 + 2 ^ 8 * b1) := (limbs_iff 8 8 _).mp ⟨b0, b1, rfl, h0, h1⟩
    exact (limbs_iff 16 8 R).mp ⟨_, b2, hR, hlo, h2⟩
  · intro h
    obtain ⟨lo, b2, hR, hlo, h2⟩ := (limbs_iff 16 8 R).mpr h
    obtain ⟨b0, b1, hlo', h0, h1⟩ := (limbs_iff 8 8 lo).mpr hlo
    exact ⟨b0, b1, b2, by rw [hR, hlo'], h0, h1, h2⟩

/-- The W16 remainder form certifies exactly `InRange b`. -/
theorem remW16_iff (b : ℕ) (R : GF) : RemW16 b R ↔ InRange b R := by
  unfold RemW16
  split_ifs with hb
  · exact Iff.rfl
  · have hb' : b = 16 + (b - 16) := by omega
    conv_rhs => rw [hb']
    exact twoLimbs_iff (b - 16) R

/-- A decision procedure for `InRange` (used by the L1 check to evaluate the lookups on the Rust witness): the
canonical representative of `x` is below `2^w`. -/
def inRangeB (w : ℕ) (x : GF) : Bool := decide (x.val < 2 ^ w)

theorem inRangeB_iff {w : ℕ} (hw : w ≤ 63) (x : GF) : inRangeB w x = true ↔ InRange w x := by
  have hp : 2 ^ w ≤ gP := le_trans (Nat.pow_le_pow_right (by norm_num) hw) (by norm_num)
  unfold inRangeB
  rw [decide_eq_true_iff]
  constructor
  · intro h
    refine ⟨(x.val : ℤ), by positivity, by exact_mod_cast h, ?_⟩
    rw [Int.cast_natCast, ZMod.natCast_zmod_val]
  · rintro ⟨t, h0, h1, rfl⟩
    have ht : ((t.toNat : ℕ) : ℤ) = t := Int.toNat_of_nonneg h0
    have hlt' : ((t.toNat : ℕ) : ℤ) < (2 : ℤ) ^ w := by rw [ht]; exact h1
    have hlt : t.toNat < 2 ^ w := by exact_mod_cast hlt'
    rw [← ht, Int.cast_natCast, ZMod.val_natCast, Nat.mod_eq_of_lt (lt_of_lt_of_le hlt hp)]
    exact hlt

/-! ## From LogUp's tuple conclusion to the range fact (finding F4) -/

open ZK60.Sound (Tup)

/-- A range family's table tuple: the value `v`, the family tag, two zero coordinates (range16.rs:216-219). -/
def rangeTup (tag : ℕ) (v : ℤ) : Tup GF := ⟨(v : GF), (tag : GF), 0, 0⟩

/-- The table of a list of range families `(tag, width)`: every `(v, tag)` with `0 ≤ v < 2^width`. -/
def RangeTable (fams : List (ℕ × ℕ)) (u : Tup GF) : Prop :=
  ∃ f ∈ fams, ∃ v : ℤ, 0 ≤ v ∧ v < 2 ^ f.2 ∧ u = rangeTup f.1 v

/-- The query tuple of a range lookup: the looked-up expression `x` and its family's tag (range16::g_of). -/
def rangeQuery (tag : ℕ) (x : GF) : Tup GF := ⟨x, (tag : GF), 0, 0⟩

/-- **F4 for the range families.** If the families' tags are distinct naturals below `p`, the query tuple
`(x, tag, 0, 0)` of family `(tag, w)` is a table tuple of SOME family exactly when `InRange w x`: the tag coordinate
selects the family, and the value coordinate is the image of an integer in `[0, 2^w)`. -/
theorem rangeQuery_mem_iff (fams : List (ℕ × ℕ)) (hlt : ∀ f ∈ fams, f.1 < gP)
    (hdist : ∀ f ∈ fams, ∀ g ∈ fams, f.1 = g.1 → f = g) {tag w : ℕ} (hmem : (tag, w) ∈ fams) (x : GF) :
    RangeTable fams (rangeQuery tag x) ↔ InRange w x := by
  constructor
  · rintro ⟨f, hf, v, h0, h1, he⟩
    have hx : x = (v : GF) := congrArg Tup.x he
    have ht : ((tag : ℕ) : GF) = ((f.1 : ℕ) : GF) := congrArg Tup.tag he
    have htag : tag = f.1 := by
      have := (ZMod.natCast_eq_natCast_iff' tag f.1 gP).mp ht
      rwa [Nat.mod_eq_of_lt (hlt _ hmem), Nat.mod_eq_of_lt (hlt _ hf)] at this
    have hfeq : (tag, w) = f := hdist _ hmem _ hf htag
    subst hfeq
    exact ⟨v, h0, h1, hx⟩
  · rintro ⟨t, h0, h1, rfl⟩
    exact ⟨(tag, w), hmem, t, h0, h1, rfl⟩

/-- The W16R2 range families as `(tag, width)`: `TAG_RANGE0 + w` for every width the profile looks up
(range16::widths at LowH24, 8B shifts: 2, 4, 5, 7, 12, 13, 15, 16), and the byte family U8 at its own tag
(`TAG_U8 = 133`, tables_attn.rs; the test range16.rs:262-283 checks it lies outside `200..=224`). -/
def w16r2Fams : List (ℕ × ℕ) :=
  [(133, 8), (202, 2), (204, 4), (205, 5), (207, 7), (212, 12), (213, 13), (215, 15), (216, 16)]

/-- The W16R2 families satisfy the premises of `rangeQuery_mem_iff`. -/
theorem w16r2Fams_ok : (∀ f ∈ w16r2Fams, f.1 < gP) ∧ (∀ f ∈ w16r2Fams, ∀ g ∈ w16r2Fams, f.1 = g.1 → f = g) := by
  refine ⟨?_, ?_⟩ <;> decide

end ZK60.Circuit
