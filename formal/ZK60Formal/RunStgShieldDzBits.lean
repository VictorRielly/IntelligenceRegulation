/-
D63 lane L63 (2026-11-17), part 32: **INC-00's input-endpoint claim at a Boolean point is the matrix entry of its
word** (`hdzW`, first half).

INC-00's endpoint table is `⟨.inp, [(0, 1)], lw, rhoC 0 lw, mr, 0⟩` (`incDefIO_ok`, RunStgShieldDg.lean:294): one slice
from offset `0`, `lw` variables, read at the endpoint's row width `lc`. At the cube point whose main bits are word
`x0`'s (msb first, as `msbIndex`) and whose extension bit is `0`, its claim's functional on a matrix `X` is
`X (x0 / 2^lc) (x0 mod 2^lc)` (row-major words of `2^lc` columns, the code's `input_plane` layout):

* `mb`: bit `a` of `x0` among `n` (msb first; `msbBits` on `ℕ`); `mb_hi`, `mb_lo`: the high bits are `x0 / 2^lc`'s,
  the low ones `x0 mod 2^lc`'s;
* `eqPoly_mb`: `eq` of a point carrying an index's bits against another index's bits is the indicator;
* `dataRowK_mb`, `dataKeyColK_mb`: the row and column weights of the slice at that point are indicators;
* **`ssh_endClaim_bool`**: the claim's functional is the entry.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIODec

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Exec.StageV (IncV OutcV)
open ZK60.Circuit (gP GF)

section Bits

/-- Bit `a` of `x0` among `n` bits, most significant first (`msbBits` on `ℕ`). -/
def mb (n x0 a : ℕ) : Bool := decide (x0 / 2 ^ (n - 1 - a) % 2 = 1)

theorem mb_eq_msbBits (n x0 : ℕ) (a : Fin n) : mb n x0 a = msbBits n x0 a := rfl

theorem mb_hi (n lc x0 a : ℕ) (hle : lc ≤ n) (ha : a < n - lc) : mb n x0 a = mb (n - lc) (x0 / 2 ^ lc) a := by
  unfold mb
  have e : n - 1 - a = (n - lc - 1 - a) + lc := by omega
  rw [e, pow_add, mul_comm, ← Nat.div_div_eq_div_mul]

theorem mb_lo (n lc x0 a : ℕ) (hle : lc ≤ n) (ha : a < lc) : mb n x0 (n - lc + a) = mb lc (x0 % 2 ^ lc) a := by
  unfold mb
  have e : n - 1 - (n - lc + a) = lc - 1 - a := by omega
  rw [e]
  have h2 : 2 ^ lc = 2 ^ (lc - 1 - a) * 2 ^ (lc - (lc - 1 - a)) := by
    rw [← pow_add]; congr 1; omega
  rw [h2, Nat.mod_mul_right_div_self, Nat.mod_mod_of_dvd _ (dvd_pow_self 2 (by omega : lc - (lc - 1 - a) ≠ 0))]

end Bits

section Eval

variable {K : Type} [Field K] [Algebra GF K]

omit [Algebra GF K] in
/-- **`eq` of a point carrying index `r0`'s bits against index `row`'s bits is the indicator.** -/
theorem eqPoly_mb (m r0 row : ℕ) (pt : ℕ → K) (hpt : ∀ a, a < m → pt a = bit (mb m r0 a)) (hr0 : r0 < 2 ^ m)
    (hrow : row < 2 ^ m) :
    eqPoly (fun a : Fin m => pt a) (Block.bitsK m row) = if row = r0 then 1 else 0 := by
  have e1 : (fun a : Fin m => pt a) = fun a => bit (msbBits m r0 a) := by
    funext a
    rw [hpt a a.isLt]
    rfl
  have e2 : (Block.bitsK m row : Fin m → K) = fun a => bit (msbBits m row a) := rfl
  rw [e1, e2, eqPoly_bit]
  by_cases h : row = r0
  · subst h
    simp
  · rw [ite_eq_right (fun hb => h ?_), ite_eq_right h]
    have := congrArg (msbIndex m) hb
    rw [msbIndex_msbBits m r0 hr0, msbIndex_msbBits m row hrow] at this
    exact this.symm

omit [Algebra GF K] in
/-- `eqPoly_mb` at a width given up to an equation. -/
theorem eqPoly_mbK (mK m r0 row : ℕ) (hmK : mK = m) (pt : ℕ → K) (hpt : ∀ a, a < m → pt a = bit (mb m r0 a))
    (hr0 : r0 < 2 ^ m) (hrow : row < 2 ^ m) :
    eqPoly (fun a : Fin mK => pt a) (Block.bitsK mK row) = if row = r0 then 1 else 0 := by
  subst hmK
  exact eqPoly_mb mK r0 row pt hpt hr0 hrow

omit [Algebra GF K] in
/-- **The slice's row weight at the word's bits is the indicator of the word's row.** -/
theorem dataRowK_mb (lw lc x0 : ℕ) (hle : lc ≤ lw) (hlw : 0 < lw) (hx0 : x0 < 2 ^ lw) (pt : ℕ → K)
    (hpt : ∀ a, a < lw → pt a = bit (mb lw x0 a)) (row : ℕ) :
    dataRowK 0 lw lc lw pt row = if row = x0 / 2 ^ lc then 1 else 0 := by
  have hm : min (lw - lc) lw = lw - lc := Nat.min_eq_left (Nat.sub_le _ _)
  have hr0 : x0 / 2 ^ lc < 2 ^ (lw - lc) := by
    rw [Nat.div_lt_iff_lt_mul (Nat.two_pow_pos lc), ← pow_add, Nat.sub_add_cancel hle]
    exact hx0
  unfold dataRowK
  rw [ite_eq_right (by omega), ite_eq_left hle, Nat.zero_div, zero_add]
  by_cases hr : row < 2 ^ (min (lw - lc) lw)
  · rw [ite_eq_left ⟨Nat.zero_le _, hr⟩, Nat.sub_zero]
    rw [hm] at hr ⊢
    exact eqPoly_mb (lw - lc) (x0 / 2 ^ lc) row pt (fun a ha => by
      rw [hpt a (by omega), mb_hi lw lc x0 a hle ha]) hr0 hr
  · rw [ite_eq_right (fun h => hr h.2)]
    rw [hm] at hr
    rw [ite_eq_right (by omega)]

omit [Algebra GF K] in
/-- **The slice's column weight at the word's bits is the indicator of the word's column.** -/
theorem dataKeyColK_mb (lw lc x0 : ℕ) (hle : lc ≤ lw) (pt : ℕ → K)
    (hpt : ∀ a, a < lw → pt a = bit (mb lw x0 a)) (t : ℕ) (ht : t < 2 ^ lc) :
    dataKeyColK 0 lw lc lw pt t = if t = x0 % 2 ^ lc then 1 else 0 := by
  have hk : lw - (lw - lc) = lc := by omega
  have hc0 : x0 % 2 ^ lc < 2 ^ lc := Nat.mod_lt _ (Nat.two_pow_pos lc)
  unfold dataKeyColK
  simp only [hle, ↓reduceIte, Nat.zero_le, true_and, zero_add, Nat.sub_zero]
  rw [ite_eq_left ht, hk]
  by_cases hl0 : lc = 0
  · subst hl0
    simp only [pow_zero, Nat.lt_one_iff] at ht hc0
    simp [ht, hc0]
  · rw [ite_eq_right hl0, ite_eq_left ht]
    exact eqPoly_mbK _ lc (x0 % 2 ^ lc) t (by rw [ite_eq_left hle]; omega) (fun a => pt (lw - lc + a)) (fun a ha => by
      rw [hpt (lw - lc + a) (by omega), mb_lo lw lc x0 a hle ha]) hc0 ht

end Eval

section Claim

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- **INC-00'S INPUT-ENDPOINT CLAIM AT THE WORD'S CUBE POINT IS THE MATRIX ENTRY OF THE WORD** (the endpoint read at row
width `lc`, word `x0` at row `x0 / 2^lc`, column `x0 mod 2^lc`), at a point `x` whose main bits are `x0`'s and whose
extension coordinate selects the data (`selK = 1`, `cmK = 0`). -/
theorem ssh_endClaim_bool (hU : U ^ 2 = algebraMap GF K 7) (P : Block.BlockParams) (lc : ℕ)
    (hep : P.endpointLogN = lc) (R Q : ℕ) (X : Fin R → Fin (2 ^ lc + Q) → K) {N : ℕ} (n e : ℕ) (hN : N = n + e)
    (x : Fin N → K) (lw mr x0 : ℕ) (hn : n = lw) (hle : lc ≤ lw) (hlw : 0 < lw) (hx0 : x0 < 2 ^ lw)
    (hR : x0 / 2 ^ lc < R)
    (hxr : ∀ a, a < n → Block.xrK n x a = bit (mb lw x0 a))
    (hsel : Block.selK n e x = 1) (hcm : Block.cmK n e x 0 = 0) :
    claimSem U R lc Q X (Block.buildClaim P ⟨.inp, [(0, Fp2.one)], lw, StageV.rhoC 0 lw, mr, 0⟩
        (Block.claimPoint ⟨.inp, [(0, Fp2.one)], lw, StageV.rhoC 0 lw, mr, 0⟩ ((stgWords U hbij x).take n))
        (Block.oneMinusProd ((stgWords U hbij x).drop n))
        (Block.maskCoef ((stgWords U hbij x).drop n) 0) Fp2.zero)
      = X ⟨x0 / 2 ^ lc, hR⟩ ⟨x0 % 2 ^ lc, by
          have := Nat.mod_lt x0 (Nat.two_pow_pos lc); omega⟩ := by
  have hrho : ((stgWords U hbij x).take n).length = n := by
    rw [List.length_take, stgWords_length]; omega
  have hes : ((stgWords U hbij x).drop n).length = e := by
    rw [List.length_drop, stgWords_length]; omega
  have hleN : ((stgWords U hbij x).take n ++ (stgWords U hbij x).drop n).length ≤ N := by
    rw [List.take_append_drop, stgWords_length]
  have hrc : ∀ a ∈ (stgWords U hbij x).take n, a.Canon :=
    fun a ha => stgWords_canon U hbij x a (List.mem_of_mem_take ha)
  have hec : ∀ a ∈ (stgWords U hbij x).drop n, a.Canon :=
    fun a ha => stgWords_canon U hbij x a (List.mem_of_mem_drop ha)
  have hmin : min lw (Block.rowLog P .inp) ≤ lc := by
    show min lw P.endpointLogN ≤ lc
    rw [hep]; exact Nat.min_le_right _ _
  have hcan : ∀ c ∈ StageV.rhoC 0 lw, ∀ w, c = Block.Coord.fixed w → w.Canon := by
    intro c hc w hw
    obtain ⟨a, -, rfl⟩ := List.mem_map.mp hc
    cases hw
  rw [claimSem_priv_words U hU P R lc Q X n e _ _ hrho hes hleN hrc hec
    (⟨.inp, [(0, Fp2.one)], lw, StageV.rhoC 0 lw, mr, 0⟩ : Block.Priv) (0, Fp2.one) [] rfl hmin hcan]
  dsimp only
  rw [xOf_take_drop_stgWords U hbij n x]
  have hlen : (StageV.rhoC 0 lw).length = lw := by simp [StageV.rhoC]
  have hpt : ∀ a, a < lw → Block.ptK U (Block.xrK n x) (StageV.rhoC 0 lw) a = bit (mb lw x0 a) := by
    intro a ha
    have hg : (StageV.rhoC 0 lw)[a]? = some (Block.Coord.rho a) := by
      simp [StageV.rhoC, ha]
    unfold Block.ptK
    rw [hg]
    show Block.xrK n x a = _
    exact hxr a (by omega)
  rw [hlen, hsel, hcm]
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero, zero_mul, Fp2.toK_one, one_mul,
    mul_one]
  rw [Finset.sum_eq_single ⟨x0 / 2 ^ lc, hR⟩]
  · rw [dataRowK_mb lw lc x0 hle hlw hx0 _ hpt, ite_eq_left rfl, one_mul]
    rw [Finset.sum_eq_single ⟨x0 % 2 ^ lc, by have := Nat.mod_lt x0 (Nat.two_pow_pos lc); omega⟩]
    · have hc : x0 % 2 ^ lc < 2 ^ lc := Nat.mod_lt _ (Nat.two_pow_pos lc)
      rw [ite_eq_left hc, dataKeyColK_mb lw lc x0 hle _ hpt _ hc, ite_eq_left rfl, mul_one]
    · intro t _ htne
      by_cases ht : (t : ℕ) < 2 ^ lc
      · rw [ite_eq_left ht, dataKeyColK_mb lw lc x0 hle _ hpt _ ht, ite_eq_right (fun h => htne (Fin.ext h)), mul_zero]
      · rw [ite_eq_right ht, mul_zero]
    · intro h; exact absurd (Finset.mem_univ _) h
  · intro row _ hne
    rw [dataRowK_mb lw lc x0 hle hlw hx0 _ hpt, ite_eq_right (fun h => hne (Fin.ext h)), zero_mul]
  · intro h; exact absurd (Finset.mem_univ _) h

end Claim

end ZK60.ProtocolClassify
