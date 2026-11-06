/-
D63, step L2 (`CircuitIff`), family 1: REQUANTIZATION, the largest family of the W16R2 block (every remainder lookup
and almost every word lookup; 58% + 37% of its lookup rows, W16R3_DESIGN_B4_B5 §1).

The constraint, as the code builds it. Every requantized word `q` is hosted by its matmul's sumcheck through the term
`2^s·q + R − 2^(s−1)` (the "host" of argument_accuracy.rs: `host_o`, `host_d` at :496-497 for the output and down
projections, `host_g`, `host_u` at :530-531 for gate and up, `host1`, `host2` at :563-564 for Q/K/V/O, the RoPE
clause at :560-561, `host_s` at :620 for the score, and the product clause `f0` at :526), which the matmul's sumcheck
equates with the matmul value `a` (the accumulator times its public multiplier). `R` is the remainder in its W16 limbs,
`q` is looked up in its word class. So one requantization's constraints are
  `HostRel s a q R ∧ C.P q ∧ RemW16 s R`.

The integer spec (ModelInt.lean): `requantIn lo hi a 1 s`, i.e. `⌊(a + 2^(s−1))/2^s⌋` with its remainder, refused
outside the class `[lo, hi]`.

`requant_iff` (the iff, generic in the word class): for `|a| ≤ 2^62` (every honest hosted value is below 2^50, the
D56 inventory) and `s ≤ 24`, the constraints are satisfiable exactly when the spec admits `a` and `q` is the
image of the spec's word; the remainder is then the spec's remainder (`requant_witness`). The classes of W16R2:
* `word16Class`: int16 by `word + 32768` (Q, K, V, QR, KR, O, AO, U, Z; range16::word16);
* `wordS8Class`: the symmetric int8 score `[-127, 127]` by the two byte queries `s8 + 127`, `127 − s8`
  (accuracy_layout.rs:328-329);
* `word24Class`: the 24-bit product word `[-2^23, 2^23)` by a low expression and a signed top byte (range16::word24);
* `gateClass`: the gate word `[-2048, 2047]`, bounded by the ACT table's index coordinate `g + 2048 ∈ [0, 4096)`
  (argument_accuracy.rs:527; accuracy_act.rs), not by a range family.

The redundancy found while proving it (optimization candidate C4 of the findings document):
* `residual_pins_word`: with `x`, `x1` int16 and the residual clause `x1 − x − ao = 0` (argument_accuracy.rs:491), the
  attention output `ao` is ALREADY the image of an integer in `(−2^16, 2^16)`; `requant_of_residual` then pins it to the
  exact floor of its accumulator with no lookup of its own. Its own int16 lookup only enforces the int16 CLASS
  (`ao_class_gap`: field values that pass every other constraint with `ao = 65535`). The same holds for `z16` with
  `x2 − x1 − z = 0`.
* `run_inputs_bounded` (candidate C2): a block's input word check is implied by the previous block's output check
  once the boundary commitment equates the two planes.
-/
import ZK60Formal.CircuitField

namespace ZK60.Circuit

open ZK60.Model

/-! ## The constraints -/

/-- The host relation of one requantization at shift `s`: `2^s·q + R − 2^(s−1) = a`. -/
def HostRel (s : ℕ) (a q R : GF) : Prop := 2 ^ s * q + R - 2 ^ (s - 1) = a

/-- A word class: the lookup predicate on a committed word and the integer interval it certifies. -/
structure WordClass where
  P : GF → Prop
  lo : ℤ
  hi : ℤ
  lo_ge : -2 ^ 24 ≤ lo
  hi_le : hi ≤ 2 ^ 24
  iff : ∀ x, P x ↔ ∃ q : ℤ, lo ≤ q ∧ q ≤ hi ∧ x = (q : GF)

/-! ## The integer spec, unfolded -/

theorem requantIn_eq_some {lo hi a : ℤ} {s : ℕ} {w r : ℤ} :
    requantIn lo hi a 1 s = some (w, r) ↔
      lo ≤ (a + 2 ^ (s - 1)) / 2 ^ s ∧ (a + 2 ^ (s - 1)) / 2 ^ s ≤ hi ∧
        w = (a + 2 ^ (s - 1)) / 2 ^ s ∧ r = (a + 2 ^ (s - 1)) % 2 ^ s := by
  unfold requantIn requant
  simp only [Nat.cast_one, mul_one]
  split_ifs with h
  · constructor
    · intro he
      simp only [Option.some.injEq, Prod.mk.injEq] at he
      exact ⟨h.1, h.2, he.1.symm, he.2.symm⟩
    · rintro ⟨_, _, rfl, rfl⟩
      rfl
  · constructor
    · intro he
      exact absurd he (by simp)
    · rintro ⟨h1, h2, _, _⟩
      exact absurd ⟨h1, h2⟩ h

/-! ## The iff -/

/-- **`CircuitIff` for one requantization**, generic in its word class. -/
theorem requant_iff (C : WordClass) (s : ℕ) (hs : s ≤ 24) (a : ℤ) (ha1 : -2 ^ 62 ≤ a)
    (ha2 : a ≤ 2 ^ 62) (q : GF) :
    (∃ R : GF, HostRel s (a : GF) q R ∧ C.P q ∧ RemW16 s R) ↔
      ∃ w r : ℤ, requantIn C.lo C.hi a 1 s = some (w, r) ∧ q = (w : GF) := by
  have hS0 : (0 : ℤ) < 2 ^ s := by positivity
  have hS : (2 : ℤ) ^ s ≤ 2 ^ 24 := pow_le_pow_right₀ (by norm_num) hs
  have hS1 : (2 : ℤ) ^ (s - 1) ≤ 2 ^ s := pow_le_pow_right₀ (by norm_num) (Nat.sub_le s 1)
  have hS1' : (0 : ℤ) < 2 ^ (s - 1) := by positivity
  constructor
  · rintro ⟨R, hH, hq, hR⟩
    obtain ⟨qi, hlo, hhi, rfl⟩ := (C.iff q).mp hq
    obtain ⟨ri, hr0, hr1, rfl⟩ := (remW16_iff s R).mp hR
    -- the host relation as an integer identity: no wrap
    have hcast : (((2 ^ s * qi + ri - 2 ^ (s - 1) - a : ℤ)) : GF) = 0 := by
      unfold HostRel at hH
      push_cast
      linear_combination hH
    have hqb : |qi| ≤ 2 ^ 24 := abs_le_of_mem hlo hhi C.lo_ge C.hi_le
    have hSb : |(2 : ℤ) ^ s| ≤ 2 ^ 24 := by rw [abs_of_pos hS0]; exact hS
    obtain ⟨hm1, hm2⟩ := mul_bounds hSb hqb
    have hE := int_eq_zero_of_cast hcast (by nlinarith) (by nlinarith)
    have hdiv : (a + 2 ^ (s - 1)) / 2 ^ s = qi ∧ (a + 2 ^ (s - 1)) % 2 ^ s = ri :=
      (Int.ediv_emod_unique hS0).mpr ⟨by linarith, hr0, hr1⟩
    refine ⟨qi, ri, requantIn_eq_some.mpr ⟨?_, ?_, hdiv.1.symm, hdiv.2.symm⟩, rfl⟩
    · rw [hdiv.1]; exact hlo
    · rw [hdiv.1]; exact hhi
  · rintro ⟨w, r, hspec, rfl⟩
    obtain ⟨hlo, hhi, hw, hr⟩ := requantIn_eq_some.mp hspec
    refine ⟨(r : GF), ?_, (C.iff _).mpr ⟨w, hlo.trans_eq hw.symm, by rw [hw]; exact hhi, rfl⟩, ?_⟩
    · have h := Int.mul_ediv_add_emod (a + 2 ^ (s - 1)) (2 ^ s)
      unfold HostRel
      have hint : 2 ^ s * w + r - 2 ^ (s - 1) = a := by rw [hw, hr]; linarith
      have : (((2 ^ s * w + r - 2 ^ (s - 1) : ℤ)) : GF) = (a : GF) := by rw [hint]
      push_cast at this
      exact this
    · refine (remW16_iff s _).mpr ⟨r, ?_, ?_, rfl⟩
      · rw [hr]; exact Int.emod_nonneg _ (ne_of_gt hS0)
      · rw [hr]; exact Int.emod_lt_of_pos _ hS0

/-- The remainder of a satisfying witness is the spec's remainder (the witness is unique). -/
theorem requant_witness (C : WordClass) (s : ℕ) (hs : s ≤ 24) (a : ℤ) (ha1 : -2 ^ 62 ≤ a)
    (ha2 : a ≤ 2 ^ 62) (q R : GF) (hH : HostRel s (a : GF) q R) (hq : C.P q) (hR : RemW16 s R) :
    R = (((a + 2 ^ (s - 1)) % 2 ^ s : ℤ) : GF) := by
  obtain ⟨w, _, hspec, hqw⟩ := (requant_iff C s hs a ha1 ha2 q).mp ⟨R, hH, hq, hR⟩
  have h1 : R = (a : GF) - 2 ^ s * q + 2 ^ (s - 1) := by unfold HostRel at hH; linear_combination hH
  have h := Int.mul_ediv_add_emod (a + 2 ^ (s - 1)) (2 ^ s)
  obtain ⟨-, -, hw, -⟩ := requantIn_eq_some.mp hspec
  rw [h1, hqw, hw]
  have : ((((a + 2 ^ (s - 1)) % 2 ^ s : ℤ)) : GF) =
      (((a + 2 ^ (s - 1) - 2 ^ s * ((a + 2 ^ (s - 1)) / 2 ^ s) : ℤ)) : GF) := by
    congr 1; linarith
  rw [this]
  push_cast
  ring

/-! ## The word classes of W16R2 -/

/-- int16 by `word + 32768` (range16::word16). -/
def word16Class : WordClass where
  P := Word16
  lo := -2 ^ 15
  hi := 2 ^ 15 - 1
  lo_ge := by norm_num
  hi_le := by norm_num
  iff := word16_iff

/-- The symmetric int8 score: the two byte queries `s8 + 127` and `127 − s8` (accuracy_layout.rs:328-329). -/
def WordS8 (x : GF) : Prop := InRange 8 (x + 127) ∧ InRange 8 (-x + 127)

theorem wordS8_iff (x : GF) : WordS8 x ↔ ∃ q : ℤ, -127 ≤ q ∧ q ≤ 127 ∧ x = (q : GF) := by
  constructor
  · rintro ⟨⟨t, h0, h1, h⟩, ⟨t', h0', h1', h'⟩⟩
    have hx : x = ((t - 127 : ℤ) : GF) := by push_cast; rw [← h]; ring
    -- the second query: (127 − (t − 127)) is the image of t'; no wrap gives 254 − t = t'
    have h2 : (((254 - t : ℤ)) : GF) = ((t' : ℤ) : GF) := by rw [← h']; rw [hx]; push_cast; ring
    have he : 254 - t = t' := int_eq_of_cast_eq h2 (by rw [gP_int]; norm_num at h1 h1' ⊢; linarith)
      (by rw [gP_int]; norm_num at h1 h1' ⊢; linarith)
    exact ⟨t - 127, by linarith, by linarith, hx⟩
  · rintro ⟨q, h0, h1, rfl⟩
    exact ⟨⟨q + 127, by linarith, by norm_num; linarith, by push_cast; ring⟩,
      ⟨127 - q, by linarith, by norm_num; linarith, by push_cast; ring⟩⟩

def wordS8Class : WordClass where
  P := WordS8
  lo := -127
  hi := 127
  lo_ge := by norm_num
  hi_le := by norm_num
  iff := wordS8_iff

/-- The 24-bit product word (range16::word24 at bias `2^23`): the low expression `h − 2^16·top` in 16 bits and the
signed top limb `top + 128` in a byte. -/
def Word24 (h : GF) : Prop := ∃ top : GF, InRange 16 (h - 2 ^ 16 * top) ∧ InRange 8 (top + 128)

theorem word24_iff (h : GF) : Word24 h ↔ ∃ q : ℤ, -2 ^ 23 ≤ q ∧ q ≤ 2 ^ 23 - 1 ∧ h = (q : GF) := by
  constructor
  · rintro ⟨top, ⟨t, h0, h1, hl⟩, ⟨u, u0, u1, hu⟩⟩
    have htop : top = ((u - 128 : ℤ) : GF) := by push_cast; rw [← hu]; ring
    refine ⟨t + 2 ^ 16 * (u - 128), ?_, ?_, ?_⟩
    · norm_num at u0 ⊢; nlinarith
    · norm_num at h1 u1 ⊢; nlinarith
    · have : h = (h - 2 ^ 16 * top) + 2 ^ 16 * top := by ring
      rw [this, hl, htop]; push_cast; ring
  · rintro ⟨q, h0, h1, rfl⟩
    have h16 : (0 : ℤ) < 2 ^ 16 := by norm_num
    refine ⟨(((q + 2 ^ 23) / 2 ^ 16 - 128 : ℤ) : GF), ⟨(q + 2 ^ 23) % 2 ^ 16, Int.emod_nonneg _ (by norm_num),
      Int.emod_lt_of_pos _ h16, ?_⟩, ⟨(q + 2 ^ 23) / 2 ^ 16, Int.ediv_nonneg (by linarith) (by norm_num), ?_, ?_⟩⟩
    · have hm := Int.mul_ediv_add_emod (q + 2 ^ 23) (2 ^ 16)
      have : (((q + 2 ^ 23) % 2 ^ 16 : ℤ) : GF) =
          (((q - 2 ^ 16 * ((q + 2 ^ 23) / 2 ^ 16 - 128)) : ℤ) : GF) := by congr 1; linarith
      rw [this]; push_cast; ring
    · rw [Int.ediv_lt_iff_lt_mul h16]; norm_num at h1 ⊢; linarith
    · push_cast; ring

def word24Class : WordClass where
  P := Word24
  lo := -2 ^ 23
  hi := 2 ^ 23 - 1
  lo_ge := by norm_num
  hi_le := by norm_num
  iff := word24_iff

/-- The gate word, bounded by the ACT table's index coordinate `g + 2048 ∈ [0, 4096)` (argument_accuracy.rs:527:
`query = g + 2048 + β·a + β²·group + tag`; the table's index column runs over `0..4096`, accuracy_act.rs). -/
def GateWord (g : GF) : Prop := InRange 12 (g + 2048)

theorem gateWord_iff (g : GF) : GateWord g ↔ ∃ q : ℤ, -2048 ≤ q ∧ q ≤ 2047 ∧ g = (q : GF) := by
  constructor
  · rintro ⟨t, h0, h1, h⟩
    refine ⟨t - 2048, by linarith, by norm_num at h1 ⊢; linarith, ?_⟩
    push_cast; rw [← h]; ring
  · rintro ⟨q, h0, h1, rfl⟩
    exact ⟨q + 2048, by linarith, by norm_num; linarith, by push_cast; ring⟩

def gateClass : WordClass where
  P := GateWord
  lo := -2048
  hi := 2047
  lo_ge := by norm_num
  hi_le := by norm_num
  iff := gateWord_iff

/-- **The W16R2 requantization sites, each an instance of `requant_iff`** (8B LowH24 shifts,
accuracy_precision.rs:113-118 and the group folds): Q and K at 15, V at 16, O at 12 (`pv`), the RoPE rotations at
`SH_ROPE = 7`, AO at 21, up at 12, down at 20 (all int16); the score at 18 (symmetric int8); the gate at the folded
shift 18 (the ACT index class); the product word at 16 (24-bit). -/
theorem requant_iff_sites (a : ℤ) (ha1 : -2 ^ 62 ≤ a) (ha2 : a ≤ 2 ^ 62) (q : GF) :
    ((∃ R, HostRel 15 a q R ∧ Word16 q ∧ RemW16 15 R) ↔
        ∃ w r, requantIn (-2 ^ 15) (2 ^ 15 - 1) a 1 15 = some (w, r) ∧ q = (w : GF)) ∧
      ((∃ R, HostRel 21 a q R ∧ Word16 q ∧ RemW16 21 R) ↔
        ∃ w r, requantIn (-2 ^ 15) (2 ^ 15 - 1) a 1 21 = some (w, r) ∧ q = (w : GF)) ∧
      ((∃ R, HostRel 18 a q R ∧ WordS8 q ∧ RemW16 18 R) ↔
        ∃ w r, requantIn (-127) 127 a 1 18 = some (w, r) ∧ q = (w : GF)) ∧
      ((∃ R, HostRel 18 a q R ∧ GateWord q ∧ RemW16 18 R) ↔
        ∃ w r, requantIn (-2048) 2047 a 1 18 = some (w, r) ∧ q = (w : GF)) ∧
      ((∃ R, HostRel 16 a q R ∧ Word24 q ∧ RemW16 16 R) ↔
        ∃ w r, requantIn (-2 ^ 23) (2 ^ 23 - 1) a 1 16 = some (w, r) ∧ q = (w : GF)) :=
  ⟨requant_iff word16Class 15 (by norm_num) a ha1 ha2 q,
    requant_iff word16Class 21 (by norm_num) a ha1 ha2 q,
    requant_iff wordS8Class 18 (by norm_num) a ha1 ha2 q,
    requant_iff gateClass 18 (by norm_num) a ha1 ha2 q,
    requant_iff word24Class 16 (by norm_num) a ha1 ha2 q⟩

/-! ## The residuals, and what they make redundant -/

/-- The residual clause `x1 − x − y = 0` (argument_accuracy.rs:491, `x1.sub(x).sub(ao)`; :493 for `x2 − x1 − z`). -/
def ResidualRel (x y x1 : GF) : Prop := x1 - x - y = 0

/-- **`CircuitIff` for one residual**: given int16 inputs, the clause and the output's int16 lookup hold exactly when
the spec `residual` admits the sum and `x1` is its image. -/
theorem residual_iff (x y : ℤ) (hx1 : -2 ^ 15 ≤ x) (hx2 : x ≤ 2 ^ 15 - 1) (hy1 : -2 ^ 15 ≤ y) (hy2 : y ≤ 2 ^ 15 - 1)
    (x1 : GF) : (ResidualRel (x : GF) (y : GF) x1 ∧ Word16 x1) ↔ ∃ v, ZK60.Model.residual x y = some v ∧ x1 = (v : GF) := by
  constructor
  · rintro ⟨hr, hw⟩
    obtain ⟨v, hv0, hv1, rfl⟩ := (word16_iff _).mp hw
    have hc : ((v - x - y : ℤ) : GF) = 0 := by push_cast; exact hr
    have he := int_eq_zero_of_cast hc (by linarith) (by linarith)
    refine ⟨v, ?_, rfl⟩
    unfold ZK60.Model.residual int16Lo int16Hi
    split_ifs with h
    · congr 1
      linarith
    · exact absurd ⟨by norm_num at hv0; linarith, by norm_num at hv1; linarith⟩ h
  · rintro ⟨v, hv, rfl⟩
    unfold ZK60.Model.residual int16Lo int16Hi at hv
    split_ifs at hv with h
    · simp only [Option.some.injEq] at hv
      subst hv
      refine ⟨by unfold ResidualRel; push_cast; ring, (word16_iff _).mpr ⟨x + y, ?_, ?_, rfl⟩⟩
      · linarith [h.1]
      · linarith [h.2]

/-- **The residual pins the attention output without its own lookup** (candidate C4): `x`, `x1` int16 and
`x1 − x − ao = 0` make `ao` the image of an integer strictly inside `(−2^16, 2^16)`. -/
theorem residual_pins_word (x x1 y : GF) (hx : Word16 x) (hx1 : Word16 x1) (h : ResidualRel x y x1) :
    ∃ v : ℤ, -2 ^ 16 < v ∧ v < 2 ^ 16 ∧ y = (v : GF) := by
  obtain ⟨a, ha0, ha1, rfl⟩ := (word16_iff x).mp hx
  obtain ⟨b, hb0, hb1, rfl⟩ := (word16_iff x1).mp hx1
  refine ⟨b - a, by linarith, by linarith, ?_⟩
  unfold ResidualRel at h
  push_cast
  linear_combination -h

/-- **With the residual, the requantization of `ao` is exact without `ao`'s lookup**: the host relation and the
remainder's lookups alone force `ao` to be the floor of its accumulator (the spec's word, in the wider class
`(−2^16, 2^16)`). -/
theorem requant_of_residual (s : ℕ) (hs : s ≤ 24) (a : ℤ) (ha1 : -2 ^ 62 ≤ a) (ha2 : a ≤ 2 ^ 62)
    (x x1 ao R : GF) (hx : Word16 x) (hx1 : Word16 x1) (hres : ResidualRel x ao x1) (hH : HostRel s (a : GF) ao R)
    (hR : RemW16 s R) :
    ∃ w r, requantIn (-2 ^ 16 + 1) (2 ^ 16 - 1) a 1 s = some (w, r) ∧ ao = (w : GF) := by
  obtain ⟨v, hv0, hv1, hv⟩ := residual_pins_word x x1 ao hx hx1 hres
  let C : WordClass :=
    { P := fun y => ∃ q : ℤ, -2 ^ 16 + 1 ≤ q ∧ q ≤ 2 ^ 16 - 1 ∧ y = (q : GF)
      lo := -2 ^ 16 + 1
      hi := 2 ^ 16 - 1
      lo_ge := by norm_num
      hi_le := by norm_num
      iff := fun _ => Iff.rfl }
  exact (requant_iff C s hs a ha1 ha2 ao).mp ⟨R, hH, ⟨v, by linarith, by linarith, hv⟩, hR⟩

/-- **The class gap: `ao`'s own lookup is not redundant for the int16 CLASS.** Field values that satisfy the
residual, the int16 lookups of `x` and `x1`, the host relation and the remainder's lookups, with `ao = 65535`
outside int16. Dropping `ao`'s lookup therefore widens the admissible class of `ao` from int16 to `(−2^16, 2^16)`:
a change of the integer model (a new profile), not a free saving. -/
theorem ao_class_gap :
    ∃ x x1 ao R : GF, Word16 x ∧ Word16 x1 ∧ ResidualRel x ao x1 ∧
      HostRel 21 ((2 ^ 21 * 65535 - 2 ^ 20 : ℤ) : GF) ao R ∧ RemW16 21 R ∧ ¬ Word16 ao := by
  refine ⟨((-32768 : ℤ) : GF), ((32767 : ℤ) : GF), ((65535 : ℤ) : GF), 0, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · exact (word16_iff _).mpr ⟨-32768, by norm_num, by norm_num, rfl⟩
  · exact (word16_iff _).mpr ⟨32767, by norm_num, by norm_num, rfl⟩
  · unfold ResidualRel; push_cast; ring
  · unfold HostRel; norm_num
  · exact (remW16_iff 21 0).mpr ⟨0, le_refl _, by norm_num, by simp⟩
  · intro hw
    obtain ⟨q, hq0, hq1, hq⟩ := (word16_iff _).mp hw
    have := int_eq_of_cast_eq hq (by rw [gP_int]; norm_num at hq0 hq1 ⊢; linarith)
      (by rw [gP_int]; norm_num at hq0 hq1 ⊢; linarith)
    norm_num at hq1
    linarith

/-! ## Block boundaries -/

/-- **A block's input check is implied by the previous block's output check** (candidate C2). If the boundary
commitment equates block `k + 1`'s input plane with block `k`'s output plane at every position, then the int16
lookups of every block's output and of block 0's input bound every block's input. -/
theorem run_inputs_bounded {Pos : Type} (X X2 : ℕ → Pos → GF) (hlink : ∀ k i, X (k + 1) i = X2 k i)
    (h0 : ∀ i, Word16 (X 0 i)) (h2 : ∀ k i, Word16 (X2 k i)) : ∀ k i, Word16 (X k i) := by
  intro k i
  cases k with
  | zero => exact h0 i
  | succ k => rw [hlink]; exact h2 k i

end ZK60.Circuit
