/-
D63 step L5 (the executable verifier), the foundation: Goldilocks `Fp` and `Fp2 = Fp[u]/(u² − 7)` as the code computes
them, executable, and proved equal to Mathlib's field `ZMod gP` (`Goldilocks.lean`, `CircuitField.lean`).

What is mirrored (`ops/zkp-mvp/gpu-metal/zkp-core/src/field.rs`, read 2026-11-06; nothing there is changed):
* `Fp(pub u64)`, canonical `< p` everywhere; `Fp::new` (one conditional subtraction), `add` (`overflowing_add`, then
  `+ EPSILON` on a carry, then `new`), `sub` (`overflowing_sub`, then `− EPSILON` on a borrow), `neg`, `mul` (the exact
  128-bit product, then `reduce128`), `reduce128` itself (the Goldilocks reduction: `2^64 ≡ 2^32 − 1`, `2^96 ≡ −1`),
  `from_u128` (= `reduce128`), `pow` (square and multiply over the bits of a `u64`), `inv` (`pow(p − 2)`, refused at
  zero), `to_bytes` (8 bytes little-endian);
* `Fp2 { c0, c1 }`: `add`, `sub`, `neg`, `mul` (`ac + 7·bd`, `ad + bc`), `mul_base`, `add_base`, `sub_base`, `inv`
  (`(a − b u)/(a² − 7 b²)`), `to_bytes` (`c0` then `c1`), `from_bytes` (`Fp::new` of each word).
The Rust words are `UInt64` here and every wrapping operation is `UInt64`'s, so the Lean text follows the Rust line by
line; a `u128` is a `Nat` below `2^128` (`x as u64` is `UInt64.ofNat x`, `(x >> 64) as u64` is `UInt64.ofNat (x >>> 64)`).

What is proved (every premise explicit; only `propext`, `Classical.choice`, `Quot.sound`):
* `reduce128_toNat`: for EVERY `x < 2^128`, `reduce128 x` is the canonical residue `x % p`: the code's reduction is
  correct on its whole domain (the claim of `field.rs`'s A11 comment, now a theorem);
* `add_toNat`, `sub_toNat`, `neg_toNat`, `mul_toNat` and the cast forms `toGF_add`, `toGF_sub`, `toGF_neg`, `toGF_mul`,
  `toGF_pow`, `toGF_inv`: on canonical inputs each operation is the field operation of `GF = ZMod gP` under
  `toGF a = (a.v.toNat : GF)`, and its output is canonical (`mul` and `pow` need no canonical input at all);
* `toGF_ofGF`, `ofGF_toGF`, `toGF_injective`: canonical words and `GF` are in bijection;
* `seven_not_square`: `7` is not a square in `GF` (Euler's criterion with `Goldilocks.lean`'s `pow7_2`);
* `Fp2`: under `toK U a = fp2 U (toGF a.c0, toGF a.c1)` (`HidingMOpening.lean`'s reading of a code pair) into ANY field
  `K ⊇ GF` with `U² = 7`, `add`, `sub`, `neg`, `mul`, `mul_base` are the field operations (`toK_add` …, `toK_mul`), a
  canonical nonzero value has a nonzero norm (`norm_ne_zero`), and `inv` is the inverse (`toK_inv`); for
  `K = GF[u]/(u² − 7)` the reading is a bijection (`toK_bijective`);
* the byte encodings: `le64` / `leNat` round-trip (`leNat_le64`), and `Fp2.fromBytes (Fp2.toBytes a) = a` for canonical
  `a` (`Fp2.fromBytes_toBytes`).
-/
import Mathlib.FieldTheory.Finite.Basic
import Mathlib.NumberTheory.LegendreSymbol.Basic
import ZK60Formal.Goldilocks
import ZK60Formal.HidingMOpening

namespace ZK60.Exec

open ZK60.Circuit

/-! ## Bytes -/

/-- `k` bytes little-endian of `n` (the low `8k` bits): `u64::to_le_bytes` for `k = 8`. -/
def leBytes : ℕ → ℕ → List UInt8
  | 0, _ => []
  | k + 1, n => UInt8.ofNat n :: leBytes k (n / 256)

/-- A little-endian byte string's value (`u64::from_le_bytes` for 8 bytes). -/
def leNat : List UInt8 → ℕ
  | [] => 0
  | b :: bs => b.toNat + 256 * leNat bs

theorem leBytes_length (k n : ℕ) : (leBytes k n).length = k := by
  induction k generalizing n with
  | zero => rfl
  | succ k ih => simp [leBytes, ih]

theorem leNat_leBytes (k n : ℕ) : leNat (leBytes k n) = n % 256 ^ k := by
  induction k generalizing n with
  | zero => simp [leBytes, leNat, Nat.mod_one]
  | succ k ih =>
    simp only [leBytes, leNat, ih, UInt8.toNat_ofNat']
    rw [show (256 : ℕ) ^ (k + 1) = 256 * 256 ^ k from pow_succ' _ _, show n % 2 ^ 8 = n % 256 from rfl]
    exact Nat.mod_mul.symm

theorem leNat_lt (bs : List UInt8) : leNat bs < 256 ^ bs.length := by
  induction bs with
  | nil => simp [leNat]
  | cons b bs ih =>
    simp only [leNat, List.length_cons, pow_succ']
    have := b.toNat_lt
    omega

/-- `u64::to_le_bytes`. -/
def le64 (v : UInt64) : List UInt8 := leBytes 8 v.toNat

/-- `u64::from_le_bytes` (on any byte string; the code reads exactly 8). -/
def ofLE64 (bs : List UInt8) : UInt64 := UInt64.ofNat (leNat bs)

theorem le64_length (v : UInt64) : (le64 v).length = 8 := leBytes_length 8 _

theorem leNat_le64 (v : UInt64) : leNat (le64 v) = v.toNat := by
  rw [le64, leNat_leBytes]
  exact Nat.mod_eq_of_lt (by simpa using v.toNat_lt)

theorem ofLE64_le64 (v : UInt64) : ofLE64 (le64 v) = v := by
  rw [ofLE64, leNat_le64, UInt64.ofNat_toNat]

/-! ## The base field -/

/-- `field.rs` `P = 0xFFFF_FFFF_0000_0001`. -/
def P64 : UInt64 := 0xFFFFFFFF00000001
/-- `field.rs` `EPSILON = 0xFFFF_FFFF = 2^64 mod p`. -/
def EPS : UInt64 := 0xFFFFFFFF

theorem P64_toNat : P64.toNat = 18446744069414584321 := rfl
theorem EPS_toNat : EPS.toNat = 4294967295 := rfl

/-- `field.rs` `Fp(pub u64)`. -/
structure Fp where
  v : UInt64
  deriving DecidableEq, Repr, Inhabited

namespace Fp

def zero : Fp := ⟨0⟩
def one : Fp := ⟨1⟩

/-- `Fp::new`: one conditional subtraction. -/
def new (x : UInt64) : Fp := if x ≥ P64 then ⟨x - P64⟩ else ⟨x⟩

/-- `Fp::add`: `overflowing_add`; on a carry `wrapping_add(EPSILON)`; then `Fp::new`. -/
def add (a b : Fp) : Fp :=
  let r := a.v + b.v
  let r := if r < a.v then r + EPS else r
  new r

/-- `Fp::sub`: `overflowing_sub`; on a borrow `wrapping_sub(EPSILON)`. -/
def sub (a b : Fp) : Fp :=
  let r := a.v - b.v
  ⟨if a.v < b.v then r - EPS else r⟩

/-- `Fp::neg`. -/
def neg (a : Fp) : Fp := if a.v = 0 then a else ⟨P64 - a.v⟩

/-- `reduce128`, lines 1–2: `x_lo = x as u64`, `x_hi = (x >> 64) as u64`. -/
def lo64 (x : ℕ) : UInt64 := UInt64.ofNat x
def hi64 (x : ℕ) : UInt64 := UInt64.ofNat (x >>> 64)

/-- `reduce128`, lines 3–6: `let (mut t0, borrow) = x_lo.overflowing_sub(x_hi_hi); if borrow { t0 =
t0.wrapping_sub(EPSILON) }`, with `x_hi_hi = x_hi >> 32`. -/
def r128t0 (xlo xhi : UInt64) : UInt64 :=
  let xhihi := xhi >>> 32
  if xlo < xhihi then xlo - xhihi - EPS else xlo - xhihi

/-- `reduce128`, line 7: `t1 = x_hi_lo * EPSILON`, with `x_hi_lo = x_hi & EPSILON`. -/
def r128t1 (xhi : UInt64) : UInt64 := (xhi &&& EPS) * EPS

/-- `reduce128`, lines 8–9: `let (res, carry) = t0.overflowing_add(t1); if carry { res.wrapping_add(EPSILON) }`. -/
def r128res (t0 t1 : UInt64) : UInt64 := if t0 + t1 < t0 then t0 + t1 + EPS else t0 + t1

/-- `reduce128` of a `u128` (`x < 2^128`), line by line; the last line is `Fp::new(res)`. -/
def reduce128 (x : ℕ) : Fp := new (r128res (r128t0 (lo64 x) (hi64 x)) (r128t1 (hi64 x)))

/-- `Fp::mul`: the exact 128-bit product, reduced. -/
def mul (a b : Fp) : Fp := reduce128 (a.v.toNat * b.v.toNat)

/-- `Fp::from_u128` (A11: the same reduction). -/
def fromU128 (x : ℕ) : Fp := reduce128 x

/-- `Fp::square`. -/
def square (a : Fp) : Fp := a.mul a

theorem shr1_toNat (e : UInt64) : (e >>> 1).toNat = e.toNat / 2 := by
  rw [UInt64.toNat_shiftRight]; rfl

theorem shr1_lt (e : UInt64) (h : e ≠ 0) : (e >>> 1).toNat < e.toNat := by
  have h1 : e.toNat ≠ 0 := fun h0 => h (UInt64.toNat_inj.mp (by simpa using h0))
  rw [shr1_toNat]
  omega

theorem and1_eq_one_iff (e : UInt64) : e &&& 1 = 1 ↔ e.toNat % 2 = 1 := by
  rw [← UInt64.toNat_inj, UInt64.toNat_and]
  simp [Nat.and_one_is_mod]

/-- The loop of `Fp::pow`: `if e & 1 == 1 { acc = acc·base }; base = base²; e >>= 1`. -/
def powAux (base acc : Fp) (e : UInt64) : Fp :=
  if _h : e = 0 then acc
  else powAux (base.mul base) (if e &&& 1 = 1 then acc.mul base else acc) (e >>> 1)
termination_by e.toNat
decreasing_by exact shr1_lt e _h

/-- `Fp::pow`. -/
def pow (a : Fp) (e : UInt64) : Fp := powAux a one e

/-- `Fp::inv` without its assertion (`pow(p − 2)`). -/
def inv (a : Fp) : Fp := a.pow (P64 - 2)

/-- `Fp::inv` with its assertion `self.0 != 0` as a refusal. -/
def invChecked (a : Fp) : Option Fp := if a.v = 0 then none else some a.inv

/-- `Fp::to_bytes`. -/
def toBytes (a : Fp) : List UInt8 := le64 a.v

/-- The canonical representation (`< p`), the invariant `field.rs` keeps. -/
def Canon (a : Fp) : Prop := a.v.toNat < gP

instance (a : Fp) : Decidable a.Canon := inferInstanceAs (Decidable (_ < _))

/-- The value in Mathlib's field. -/
def toGF (a : Fp) : GF := (a.v.toNat : GF)

/-- From the field: the canonical word. -/
def ofGF (x : GF) : Fp := ⟨UInt64.ofNat x.val⟩

/-! ### Each operation is the field's -/

theorem gP_val : gP = 18446744069414584321 := rfl

theorem new_toNat (x : UInt64) : (new x).v.toNat = x.toNat % gP := by
  have hx := x.toNat_lt
  unfold new
  split_ifs with h
  · have h' : P64.toNat ≤ x.toNat := UInt64.le_iff_toNat_le.mp h
    rw [P64_toNat] at h'
    show (x - P64).toNat = _
    rw [UInt64.toNat_sub_of_le _ _ h, P64_toNat, gP_val]
    omega
  · have h' : ¬ P64.toNat ≤ x.toNat := fun h' => h (UInt64.le_iff_toNat_le.mpr h')
    rw [P64_toNat] at h'
    show x.toNat = _
    rw [gP_val]
    omega

theorem new_canon (x : UInt64) : (new x).Canon := by
  unfold Canon
  rw [new_toNat]
  exact Nat.mod_lt _ (by rw [gP_val]; omega)

theorem add_toNat (a b : Fp) (ha : a.Canon) (hb : b.Canon) : (add a b).v.toNat = (a.v.toNat + b.v.toNat) % gP := by
  unfold Canon at ha hb
  rw [gP_val] at ha hb ⊢
  unfold add
  simp only
  rw [new_toNat, gP_val]
  have h1 : (a.v + b.v).toNat = (a.v.toNat + b.v.toNat) % 2 ^ 64 := UInt64.toNat_add _ _
  split_ifs with hc
  · rw [UInt64.lt_iff_toNat_lt, h1] at hc
    rw [UInt64.toNat_add, h1, EPS_toNat]
    omega
  · rw [UInt64.lt_iff_toNat_lt, h1] at hc
    rw [h1]
    omega

theorem sub_toNat (a b : Fp) (ha : a.Canon) (hb : b.Canon) :
    (sub a b).v.toNat = (a.v.toNat + gP - b.v.toNat) % gP := by
  unfold Canon at ha hb
  rw [gP_val] at ha hb ⊢
  unfold sub
  simp only
  split_ifs with hc
  · rw [UInt64.lt_iff_toNat_lt] at hc
    rw [UInt64.toNat_sub, UInt64.toNat_sub, EPS_toNat]
    omega
  · rw [UInt64.lt_iff_toNat_lt] at hc
    rw [UInt64.toNat_sub_of_le _ _ (by rw [UInt64.le_iff_toNat_le]; omega)]
    omega

theorem neg_toNat (a : Fp) (ha : a.Canon) : (neg a).v.toNat = (gP - a.v.toNat) % gP := by
  unfold Canon at ha
  rw [gP_val] at ha ⊢
  unfold neg
  split_ifs with h
  · rw [h]; rfl
  · have h0 : a.v.toNat ≠ 0 := fun h0 => h (UInt64.toNat_inj.mp (by simpa using h0))
    show (P64 - a.v).toNat = _
    rw [UInt64.toNat_sub_of_le _ _ (by rw [UInt64.le_iff_toNat_le, P64_toNat]; omega), P64_toNat]
    omega

/-- `reduce128`'s first step: its value is `x_lo − x_hi_hi`, plus `p` on a borrow. -/
theorem t0_spec (xlo xhi : UInt64) :
    (r128t0 xlo xhi).toNat + xhi.toNat / 2 ^ 32
      = xlo.toNat + (if xlo.toNat < xhi.toNat / 2 ^ 32 then gP else 0) := by
  have := xlo.toNat_lt
  have hhi := xhi.toNat_lt
  have hhh : (xhi >>> 32).toNat = xhi.toNat / 2 ^ 32 := by
    rw [UInt64.toNat_shiftRight, show (32 : UInt64).toNat % 64 = 32 from rfl, Nat.shiftRight_eq_div_pow]
  unfold r128t0
  rw [gP_val]
  by_cases h1 : xlo.toNat < xhi.toNat / 2 ^ 32
  · have h1' : xlo < xhi >>> 32 := UInt64.lt_iff_toNat_lt.mpr (by rw [hhh]; exact h1)
    simp only [h1, h1', ↓reduceIte]
    rw [UInt64.toNat_sub, UInt64.toNat_sub, EPS_toNat, hhh]
    omega
  · have h1' : ¬ xlo < xhi >>> 32 := fun h => h1 (by rw [← hhh]; exact UInt64.lt_iff_toNat_lt.mp h)
    simp only [h1, h1', ↓reduceIte]
    rw [UInt64.toNat_sub_of_le _ _ (UInt64.le_iff_toNat_le.mpr (by rw [hhh]; omega)), hhh]
    omega

theorem t1_spec (xhi : UInt64) : (r128t1 xhi).toNat = xhi.toNat % 2 ^ 32 * 4294967295 := by
  unfold r128t1
  rw [UInt64.toNat_mul, UInt64.toNat_and, EPS_toNat, show (4294967295 : ℕ) = 2 ^ 32 - 1 from rfl,
    Nat.and_two_pow_sub_one_eq_mod]
  exact Nat.mod_eq_of_lt (by omega)

/-- `reduce128`'s second step: its value is `t0 + t1`, minus `p` on a carry (`t1 ≤ (2^32 − 1)²`, so the correction
never wraps). -/
theorem res_spec (t0 t1 : UInt64) (h1 : t1.toNat ≤ 18446744065119617025) :
    (r128res t0 t1).toNat + (if 2 ^ 64 ≤ t0.toNat + t1.toNat then gP else 0) = t0.toNat + t1.toNat := by
  have := t0.toNat_lt
  have h01 : (t0 + t1).toNat = (t0.toNat + t1.toNat) % 2 ^ 64 := UInt64.toNat_add _ _
  unfold r128res
  rw [gP_val]
  by_cases hc : 2 ^ 64 ≤ t0.toNat + t1.toNat
  · have hlt : t0 + t1 < t0 := by rw [UInt64.lt_iff_toNat_lt, h01]; omega
    simp only [hlt, hc, ↓reduceIte]
    rw [UInt64.toNat_add, h01, EPS_toNat]
    omega
  · have hlt : ¬ t0 + t1 < t0 := by rw [UInt64.lt_iff_toNat_lt, h01]; omega
    simp only [hlt, hc, ↓reduceIte]
    rw [h01]
    omega

/-- `reduce128`'s arithmetic: with `x = 2^96·a + 2^64·b + l` (`a = x_hi_hi`, `b = x_hi_lo`, `l = x_lo`), the two steps'
values (`t0_spec`, `res_spec`) are `≡ x (mod p)`, because `2^64 ≡ 2^32 − 1` and `2^96 + 1 = p·(2^32 + 1)`. -/
theorem reduce128_arith (a b l t0 r : ℕ)
    (hA : t0 + a = l + (if l < a then 18446744069414584321 else 0))
    (hB : r + (if 2 ^ 64 ≤ t0 + b * 4294967295 then 18446744069414584321 else 0) = t0 + b * 4294967295) :
    r % 18446744069414584321 = (2 ^ 64 * (2 ^ 32 * a + b) + l) % 18446744069414584321 := by
  by_cases hb : l < a <;> by_cases hc : 2 ^ 64 ≤ t0 + b * 4294967295 <;>
    simp only [hb, hc, ↓reduceIte] at hA hB
  · have e : 2 ^ 64 * (2 ^ 32 * a + b) + l = r + 18446744069414584321 * (b + 4294967297 * a) := by omega
    rw [e, Nat.add_mul_mod_self_left]
  · have e : 2 ^ 64 * (2 ^ 32 * a + b) + l = r + 18446744069414584321 * (b + 4294967297 * a - 1) := by omega
    rw [e, Nat.add_mul_mod_self_left]
  · have e : 2 ^ 64 * (2 ^ 32 * a + b) + l = r + 18446744069414584321 * (b + 1 + 4294967297 * a) := by omega
    rw [e, Nat.add_mul_mod_self_left]
  · have e : 2 ^ 64 * (2 ^ 32 * a + b) + l = r + 18446744069414584321 * (b + 4294967297 * a) := by omega
    rw [e, Nat.add_mul_mod_self_left]

/-- **The code's Goldilocks reduction is correct on its whole domain**: for every `x < 2^128`. -/
theorem reduce128_toNat (x : ℕ) (hx : x < 2 ^ 128) : (reduce128 x).v.toNat = x % gP := by
  have hlo : (lo64 x).toNat = x % 2 ^ 64 := UInt64.toNat_ofNat'
  have hhi : (hi64 x).toNat = x / 2 ^ 64 := by
    unfold hi64
    rw [UInt64.toNat_ofNat', Nat.shiftRight_eq_div_pow]
    exact Nat.mod_eq_of_lt (by omega)
  have hA := t0_spec (lo64 x) (hi64 x)
  have h1 := t1_spec (hi64 x)
  have hB := res_spec (r128t0 (lo64 x) (hi64 x)) (r128t1 (hi64 x)) (by rw [h1]; omega)
  rw [hlo, hhi] at hA
  rw [h1, hhi] at hB
  rw [reduce128, new_toNat, gP_val]
  rw [gP_val] at hA hB
  have hx' : x = 2 ^ 64 * (2 ^ 32 * (x / 2 ^ 64 / 2 ^ 32) + x / 2 ^ 64 % 2 ^ 32) + x % 2 ^ 64 := by
    have hd1 := Nat.div_add_mod x (2 ^ 64)
    have hd2 := Nat.div_add_mod (x / 2 ^ 64) (2 ^ 32)
    omega
  conv_rhs => rw [hx']
  exact reduce128_arith _ _ _ _ _ hA hB

theorem reduce128_canon (x : ℕ) : (reduce128 x).Canon := new_canon _

theorem mul_toNat (a b : Fp) : (mul a b).v.toNat = a.v.toNat * b.v.toNat % gP :=
  reduce128_toNat _ (by
    have := a.v.toNat_lt
    have := b.v.toNat_lt
    calc a.v.toNat * b.v.toNat < 2 ^ 64 * 2 ^ 64 := Nat.mul_lt_mul'' ‹_› ‹_›
      _ = 2 ^ 128 := by norm_num)

theorem mul_canon (a b : Fp) : (mul a b).Canon := reduce128_canon _

theorem add_canon (a b : Fp) : (add a b).Canon := new_canon _

theorem sub_canon (a b : Fp) (ha : a.Canon) (hb : b.Canon) : (sub a b).Canon := by
  unfold Canon
  rw [sub_toNat a b ha hb]
  exact Nat.mod_lt _ (by rw [gP_val]; omega)

theorem neg_canon (a : Fp) (ha : a.Canon) : (neg a).Canon := by
  unfold Canon
  rw [neg_toNat a ha]
  exact Nat.mod_lt _ (by rw [gP_val]; omega)

theorem toGF_eq_of_toNat {a : Fp} {n : ℕ} (h : a.v.toNat = n % gP) : a.toGF = (n : GF) := by
  rw [toGF, h, ZMod.natCast_mod]

theorem toGF_add (a b : Fp) (ha : a.Canon) (hb : b.Canon) : (add a b).toGF = a.toGF + b.toGF := by
  rw [toGF_eq_of_toNat (add_toNat a b ha hb), Nat.cast_add]; rfl

theorem toGF_sub (a b : Fp) (ha : a.Canon) (hb : b.Canon) : (sub a b).toGF = a.toGF - b.toGF := by
  rw [toGF_eq_of_toNat (sub_toNat a b ha hb), Nat.cast_sub (by unfold Canon at hb; omega), Nat.cast_add,
    ZMod.natCast_self]
  simp [toGF]

theorem toGF_neg (a : Fp) (ha : a.Canon) : (neg a).toGF = -a.toGF := by
  rw [toGF_eq_of_toNat (neg_toNat a ha), Nat.cast_sub (by unfold Canon at ha; omega), ZMod.natCast_self]
  simp [toGF]

theorem toGF_mul (a b : Fp) : (mul a b).toGF = a.toGF * b.toGF := by
  rw [toGF_eq_of_toNat (mul_toNat a b), Nat.cast_mul]; rfl

theorem toGF_reduce128 (x : ℕ) (hx : x < 2 ^ 128) : (reduce128 x).toGF = (x : GF) :=
  toGF_eq_of_toNat (reduce128_toNat x hx)

theorem toGF_new (x : UInt64) : (new x).toGF = (x.toNat : GF) := toGF_eq_of_toNat (new_toNat x)

theorem one_toGF : one.toGF = 1 := by simp [one, toGF]

theorem toGF_powAux (base acc : Fp) (e : UInt64) :
    (powAux base acc e).toGF = acc.toGF * base.toGF ^ e.toNat := by
  suffices ∀ n : ℕ, ∀ (e : UInt64), e.toNat = n → ∀ (base acc : Fp),
      (powAux base acc e).toGF = acc.toGF * base.toGF ^ e.toNat from this _ e rfl base acc
  intro n
  induction n using Nat.strong_induction_on with
  | _ n ih => ?_
  intro e hn base acc
  rw [powAux]
  split_ifs with h0 h1
  · subst h0; simp
  · rw [ih _ (hn ▸ shr1_lt e h0) _ rfl, toGF_mul, toGF_mul, shr1_toNat]
    have hodd : e.toNat % 2 = 1 := (and1_eq_one_iff e).mp h1
    conv_rhs => rw [← Nat.div_add_mod e.toNat 2, hodd]
    ring
  · rw [ih _ (hn ▸ shr1_lt e h0) _ rfl, toGF_mul, shr1_toNat]
    have heven : e.toNat % 2 = 0 := by
      have := mt (and1_eq_one_iff e).mpr h1
      omega
    conv_rhs => rw [← Nat.div_add_mod e.toNat 2, heven]
    ring

theorem toGF_pow (a : Fp) (e : UInt64) : (pow a e).toGF = a.toGF ^ e.toNat := by
  rw [pow, toGF_powAux, one_toGF, one_mul]

theorem powAux_canon (base acc : Fp) (e : UInt64) (hacc : acc.Canon) : (powAux base acc e).Canon := by
  suffices ∀ n : ℕ, ∀ (e : UInt64), e.toNat = n → ∀ (base acc : Fp), acc.Canon → (powAux base acc e).Canon from
    this _ e rfl base acc hacc
  intro n
  induction n using Nat.strong_induction_on with
  | _ n ih => ?_
  intro e hn base acc hacc
  rw [powAux]
  split_ifs with h0 h1
  · exact hacc
  · exact ih _ (hn ▸ shr1_lt e h0) _ rfl _ _ (mul_canon _ _)
  · exact ih _ (hn ▸ shr1_lt e h0) _ rfl _ _ hacc

theorem pow_canon (a : Fp) (e : UInt64) : (pow a e).Canon := powAux_canon _ _ _ (by decide)

/-- **`Fp::inv` is the field inverse** on a canonical nonzero value (Fermat, `ZMod.pow_card_sub_one_eq_one`). -/
theorem toGF_inv (a : Fp) (ha0 : a.toGF ≠ 0) : (inv a).toGF = a.toGF⁻¹ := by
  rw [inv, toGF_pow]
  have h2 : (P64 - 2).toNat = gP - 2 := rfl
  rw [h2]
  have h1 : a.toGF ^ (gP - 1) = 1 := ZMod.pow_card_sub_one_eq_one ha0
  refine (inv_eq_of_mul_eq_one_right ?_).symm
  rw [← pow_succ', show gP - 2 + 1 = gP - 1 by rw [gP_val]]
  exact h1

theorem inv_canon (a : Fp) : (inv a).Canon := pow_canon _ _

theorem toGF_zero_iff (a : Fp) (ha : a.Canon) : a.toGF = 0 ↔ a.v = 0 := by
  unfold Canon at ha
  constructor
  · intro h
    rw [toGF, ZMod.natCast_eq_zero_iff] at h
    rcases h with ⟨k, hk⟩
    have : k = 0 := by
      rcases k with _ | k
      · rfl
      · rw [hk] at ha; nlinarith
    rw [this, mul_zero] at hk
    exact UInt64.toNat_inj.mp (by simpa using hk)
  · intro h; simp [toGF, h]

theorem toGF_ofGF (x : GF) : (ofGF x).toGF = x := by
  have hx : x.val < 2 ^ 64 := lt_of_lt_of_le (ZMod.val_lt x) (by rw [gP_val]; norm_num)
  rw [ofGF, toGF, UInt64.toNat_ofNat', Nat.mod_eq_of_lt hx, ZMod.natCast_zmod_val]

theorem ofGF_canon (x : GF) : (ofGF x).Canon := by
  have hx : x.val < 2 ^ 64 := lt_of_lt_of_le (ZMod.val_lt x) (by rw [gP_val]; norm_num)
  unfold Canon ofGF
  rw [UInt64.toNat_ofNat', Nat.mod_eq_of_lt hx]
  exact ZMod.val_lt x

theorem toGF_injective {a b : Fp} (ha : a.Canon) (hb : b.Canon) (h : a.toGF = b.toGF) : a = b := by
  unfold Canon at ha hb
  have := (ZMod.natCast_eq_natCast_iff' a.v.toNat b.v.toNat gP).mp h
  rw [Nat.mod_eq_of_lt ha, Nat.mod_eq_of_lt hb] at this
  cases a; cases b
  simp only [Fp.mk.injEq]
  exact UInt64.toNat_inj.mp this

theorem ofGF_toGF (a : Fp) (ha : a.Canon) : ofGF a.toGF = a :=
  toGF_injective (ofGF_canon _) ha (toGF_ofGF _)

end Fp

/-! ## `7` is not a square -/

/-- `7` is a non-residue mod the Goldilocks prime (Euler's criterion; `7^((p−1)/2) ≠ 1` is `Goldilocks.lean`'s
`pow7_2`), so `u² − 7` is irreducible and `Fp2` is a field. -/
theorem seven_not_square : ∀ s : GF, s * s ≠ 7 := by
  intro s hs
  have h7 : (7 : GF) ≠ 0 := by
    intro h
    have : ((7 : ℕ) : GF) = 0 := by exact_mod_cast h
    rw [ZMod.natCast_eq_zero_iff] at this
    exact absurd (Nat.le_of_dvd (by norm_num) this) (by rw [Fp.gP_val]; norm_num)
  have hsq : IsSquare (7 : GF) := ⟨s, hs.symm⟩
  rw [ZMod.euler_criterion gP h7] at hsq
  exact pow7_2 (by rw [show (9223372034707292160 : ℕ) = gP / 2 by rw [Fp.gP_val]]; exact hsq)

/-! ## The extension field -/

/-- `field.rs` `NONRESIDUE = 7`, as a word. -/
def seven : Fp := ⟨7⟩

theorem seven_toGF : seven.toGF = 7 := by simp [seven, Fp.toGF]

/-- `Fp2 { c0, c1 }`, the value `c0 + c1·u` with `u² = 7`. -/
structure Fp2 where
  c0 : Fp
  c1 : Fp
  deriving DecidableEq, Repr, Inhabited

namespace Fp2

def zero : Fp2 := ⟨Fp.zero, Fp.zero⟩
def one : Fp2 := ⟨Fp.one, Fp.zero⟩
def fromBase (a : Fp) : Fp2 := ⟨a, Fp.zero⟩
def add (a b : Fp2) : Fp2 := ⟨a.c0.add b.c0, a.c1.add b.c1⟩
def sub (a b : Fp2) : Fp2 := ⟨a.c0.sub b.c0, a.c1.sub b.c1⟩
def neg (a : Fp2) : Fp2 := ⟨a.c0.neg, a.c1.neg⟩

/-- `Fp2::mul`: `ac + bd·7`, `ad + bc`, in the code's order of operations. -/
def mul (a b : Fp2) : Fp2 :=
  let ac := a.c0.mul b.c0
  let bd := a.c1.mul b.c1
  let ad := a.c0.mul b.c1
  let bc := a.c1.mul b.c0
  ⟨ac.add (bd.mul seven), ad.add bc⟩

def mulBase (a : Fp2) (r : Fp) : Fp2 := ⟨a.c0.mul r, a.c1.mul r⟩
def addBase (a : Fp2) (r : Fp) : Fp2 := ⟨a.c0.add r, a.c1⟩
def subBase (a : Fp2) (r : Fp) : Fp2 := ⟨a.c0.sub r, a.c1⟩

/-- The norm `a² − 7 b²` as `Fp2::inv` computes it. -/
def norm (a : Fp2) : Fp := a.c0.square.sub (a.c1.square.mul seven)

/-- `Fp2::inv`: `(a − b u) / (a² − 7 b²)` (the norm's inverse refused at zero by `Fp::inv`'s assertion). -/
def inv (a : Fp2) : Fp2 :=
  let ninv := a.norm.inv
  ⟨a.c0.mul ninv, a.c1.neg.mul ninv⟩

def isZero (a : Fp2) : Bool := a.c0.v == 0 && a.c1.v == 0

/-- `Fp2::to_bytes`: `c0` then `c1`, 16 bytes. -/
def toBytes (a : Fp2) : List UInt8 := a.c0.toBytes ++ a.c1.toBytes

/-- `Fp2::from_bytes`: `Fp::new` of each little-endian word. -/
def fromBytes (b : List UInt8) : Fp2 := ⟨Fp.new (ofLE64 (b.take 8)), Fp.new (ofLE64 ((b.drop 8).take 8))⟩

def Canon (a : Fp2) : Prop := a.c0.Canon ∧ a.c1.Canon

instance (a : Fp2) : Decidable a.Canon := inferInstanceAs (Decidable (_ ∧ _))

theorem fromBytes_toBytes (a : Fp2) (ha : a.Canon) : fromBytes a.toBytes = a := by
  have hn : ∀ x : Fp, x.Canon → Fp.new x.v = x := by
    intro x hx
    unfold Fp.Canon at hx
    have hlt : ¬ x.v ≥ P64 := by
      intro h
      have := UInt64.le_iff_toNat_le.mp h
      rw [P64_toNat] at this
      rw [Fp.gP_val] at hx
      omega
    unfold Fp.new
    simp [hlt]
  unfold fromBytes toBytes Fp.toBytes
  rw [List.take_left' (le64_length _), List.drop_left' (le64_length _), List.take_of_length_le (by
    rw [le64_length]), ofLE64_le64, ofLE64_le64, hn _ ha.1, hn _ ha.2]

section Field

variable {K : Type} [Field K] [Algebra GF K]

/-- The value of a code pair in a field `K ⊇ GF` with `U² = 7` (`HidingMOpening.lean`'s `fp2`). -/
def toK (U : K) (a : Fp2) : K := ZK60.Hiding.fp2 U (a.c0.toGF, a.c1.toGF)

theorem toK_add (U : K) (a b : Fp2) (ha : a.Canon) (hb : b.Canon) : (add a b).toK U = a.toK U + b.toK U := by
  simp only [toK, add, ZK60.Hiding.fp2, Fp.toGF_add _ _ ha.1 hb.1, Fp.toGF_add _ _ ha.2 hb.2, map_add]
  ring

theorem toK_sub (U : K) (a b : Fp2) (ha : a.Canon) (hb : b.Canon) : (sub a b).toK U = a.toK U - b.toK U := by
  simp only [toK, sub, ZK60.Hiding.fp2, Fp.toGF_sub _ _ ha.1 hb.1, Fp.toGF_sub _ _ ha.2 hb.2, map_sub]
  ring

theorem toK_neg (U : K) (a : Fp2) (ha : a.Canon) : (neg a).toK U = -a.toK U := by
  simp only [toK, neg, ZK60.Hiding.fp2, Fp.toGF_neg _ ha.1, Fp.toGF_neg _ ha.2, map_neg]
  ring

/-- **`Fp2::mul` is the field product** (for every input: `Fp::mul` is exact on any word). -/
theorem toK_mul (U : K) (hU : U ^ 2 = algebraMap GF K 7) (a b : Fp2) : (mul a b).toK U = a.toK U * b.toK U := by
  simp only [toK]
  rw [ZK60.Hiding.fp2_mul U 7 hU]
  simp only [mul, Fp.toGF_add _ _ (Fp.mul_canon _ _) (Fp.mul_canon _ _), Fp.toGF_mul, seven_toGF]
  congr 1
  ring_nf

theorem toK_mulBase (U : K) (a : Fp2) (r : Fp) : (mulBase a r).toK U = a.toK U * algebraMap GF K r.toGF := by
  simp only [toK]
  rw [ZK60.Hiding.fp2_mul_base]
  simp [mulBase, Fp.toGF_mul]

theorem canon_mul (a b : Fp2) : (mul a b).Canon := ⟨Fp.add_canon _ _, Fp.add_canon _ _⟩

theorem toK_one (U : K) : one.toK U = 1 := by
  simp [toK, one, ZK60.Hiding.fp2, Fp.one, Fp.zero, Fp.toGF]

theorem norm_toGF (a : Fp2) : a.norm.toGF = a.c0.toGF * a.c0.toGF - 7 * (a.c1.toGF * a.c1.toGF) := by
  rw [norm, Fp.square, Fp.square, Fp.toGF_sub _ _ (Fp.mul_canon _ _) (Fp.mul_canon _ _), Fp.toGF_mul, Fp.toGF_mul,
    Fp.toGF_mul, seven_toGF]
  ring

/-- **A canonical nonzero value has a nonzero norm** (`7` is not a square), so `Fp2::inv` never meets `Fp::inv`'s
assertion except at zero. -/
theorem norm_ne_zero (a : Fp2) (ha : a.Canon) (h0 : a ≠ zero) : a.norm.toGF ≠ 0 := by
  rw [norm_toGF]
  intro hn
  by_cases h1 : a.c1.toGF = 0
  · have h0' : a.c0.toGF * a.c0.toGF = 0 := by rw [h1] at hn; simpa using hn
    have hc0 : a.c0.toGF = 0 := mul_self_eq_zero.mp h0'
    apply h0
    have e0 := (Fp.toGF_zero_iff _ ha.1).mp hc0
    have e1 := (Fp.toGF_zero_iff _ ha.2).mp h1
    cases a with
    | mk c0 c1 => cases c0; cases c1; simp_all [zero, Fp.zero]
  · apply seven_not_square (a.c0.toGF / a.c1.toGF)
    field_simp
    linear_combination hn

/-- **`Fp2::inv` is the field inverse** on a canonical nonzero value. -/
theorem toK_inv (U : K) (hU : U ^ 2 = algebraMap GF K 7) (a : Fp2) (ha : a.Canon) (h0 : a ≠ zero) :
    (inv a).toK U * a.toK U = 1 := by
  have hn := norm_ne_zero a ha h0
  simp only [toK]
  rw [ZK60.Hiding.fp2_mul U 7 hU]
  have hpair : ((inv a).c0.toGF * a.c0.toGF + 7 * ((inv a).c1.toGF * a.c1.toGF),
      (inv a).c0.toGF * a.c1.toGF + (inv a).c1.toGF * a.c0.toGF) = ((1 : GF), (0 : GF)) := by
    refine Prod.ext ?_ ?_
    · show _ = (1 : GF)
      have e : (inv a).c0.toGF * a.c0.toGF + 7 * ((inv a).c1.toGF * a.c1.toGF) = a.norm.toGF * a.norm.toGF⁻¹ := by
        simp only [inv, Fp.toGF_mul, Fp.toGF_neg _ ha.2, Fp.toGF_inv _ hn]
        rw [norm_toGF]
        ring
      rw [e, mul_inv_cancel₀ hn]
    · show _ = (0 : GF)
      simp only [inv, Fp.toGF_mul, Fp.toGF_neg _ ha.2]
      ring
  rw [hpair]
  simp [ZK60.Hiding.fp2]

end Field

open Polynomial in
/-- **For `K = GF[u]/(u² − 7)`, the reading of canonical code pairs is a bijection onto the field.** -/
theorem toK_bijective :
    haveI : Fact (Irreducible (X ^ 2 - C 7 : GF[X])) :=
      ⟨X_pow_sub_C_irreducible_of_prime Nat.prime_two (fun b hb => seven_not_square b (by rw [← hb]; ring))⟩
    Function.Bijective (fun a : {a : Fp2 // a.Canon} => a.1.toK (AdjoinRoot.root (X ^ 2 - C 7 : GF[X]))) := by
  have : Fact (Irreducible (X ^ 2 - C 7 : GF[X])) :=
    ⟨X_pow_sub_C_irreducible_of_prime Nat.prime_two (fun b hb => seven_not_square b (by rw [← hb]; ring))⟩
  obtain ⟨hfin, hroot⟩ := ZK60.Hiding.adjoinRoot_finrank (F := GF) (κ := 7) seven_not_square
  have hb := ZK60.Hiding.fp2_bijective hfin hroot seven_not_square
  constructor
  · rintro ⟨a, ha⟩ ⟨b, hb'⟩ h
    have := hb.1 h
    simp only [Prod.mk.injEq] at this
    have e0 := Fp.toGF_injective ha.1 hb'.1 this.1
    have e1 := Fp.toGF_injective ha.2 hb'.2 this.2
    cases a; cases b
    simp_all
  · intro z
    obtain ⟨⟨x, y⟩, hxy⟩ := hb.2 z
    refine ⟨⟨⟨Fp.ofGF x, Fp.ofGF y⟩, Fp.ofGF_canon _, Fp.ofGF_canon _⟩, ?_⟩
    simp only [toK, Fp.toGF_ofGF]
    exact hxy

end Fp2

end ZK60.Exec
