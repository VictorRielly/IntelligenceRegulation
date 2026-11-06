/-
D63 step L6 (the executable verifier): the multilinear helpers and the interpolation of the generic sumcheck,
executable, as `zkp-core/src/mle.rs` runs them, and proved to be the models `SoundSumcheck.lean` (`interpEval`,
`roundPoly`) and `SoundZeroCheck.lean` / `SoundMultilinear.lean` (`eqPoly`, `mleAt`) use.

What is mirrored (`ops/zkp-mvp/gpu-metal/zkp-core/src/mle.rs` and `field.rs`, read 2026-11-06; nothing there is changed),
on `ExecField.lean`'s `Fp` / `Fp2`:
* `Fp::from_i64` (`fromI64`, on the value of an `i64` as an integer) and `Fp2::from_u64`;
* `interpolate_eval(vals, x)`: for each node `i < d = vals.len()`, the inner loop over `j ≠ i` multiplies
  `num ← num·(x − j)` (`x.sub_base(Fp::new(j as u64))`) and `den ← den·from_i64(i as i64 − j as i64)`; the term is
  `vals[i]·num` scaled by `den.inv()` (`mul_base`), summed from `ZERO`. The casts `i as i64`, `j as u64` are exact for
  `i, j < 2^63` (the code's degree is at most 6; `toK_interpolateEval` assumes `d < p`, so `d < 2^64`);
* `eq_point(r, s)` (after its length assertion): `Π (a·b + (1 − a)(1 − b))` from `ONE`;
* `eq_table(r)`: the buffer `vec![ONE; 2^n]` and, for each `r_i` in order, the doubling step on the first `2·len`
  entries (`lo = buf[..len]`, `hi = buf[len..2len]`: `hi ← lo·r_i`, `lo ← lo·(1 − r_i)`), `len ← 2·len` (both the
  sequential and the rayon branch of a step write the same values); `eq_table_msb(r) = eq_table(reverse r)`;
* `eval_mle_ext(v, r)` / `eval_mle_base(v, r)` (after the assertion `v.len() == 1 << r.len()`): the sum of
  `eq[idx]·v[idx]` (`mul`, resp. `mul_base`) over `eq = eq_table_msb(r)`. The code sums with rayon's `reduce`, in a
  tree; the Lean mirror sums left to right. Both add canonical words (`add`'s output is always canonical) whose values
  in the field are the same terms, so by associativity and `Fp2.toK_injective` they are the same word.

What is proved (only `propext`, `Classical.choice`, `Quot.sound`), under `toK U` (`ExecField.lean`) into ANY field
`K ⊇ GF` with `U² = 7`:
* `Fp.toGF_fromI64`: `from_i64` is the residue of every value in `(−2^64, 2^64)`; `Fp.toGF_inv'`: `Fp::inv` is the
  field inverse for EVERY word (also at zero: `0^(p−2) = 0 = 0⁻¹`); `Fp2.toK_injective`: canonical words are
  determined by their value (the code's word equality is the field's equality);
* **`toK_interpolateEval`**: on `d + 1` values (`d < p`; no canonical premise on them) and a canonical point,
  `interpolate_eval` is `SoundSumcheck.lean`'s `interpEval` (`interpolateEval_roundPoly`: the evaluation of `roundPoly`; with
  `ringChar_eq_gP`, `roundPoly` has degree `≤ d` and takes the sent values at the nodes, `SoundSumcheck.lean`);
* **`toK_eqPointBody`**: `eq_point` is `eqPoly`;
* `toK_eqTable`, **`toK_eqTableMsb`**: entry `idx` of `eq_table(r)` is `Π_i (r_i if bit i of idx else 1 − r_i)` (bit 0
  the LEAST significant: variable `i` is bit `i`), and of `eq_table_msb(r)` it is `eqPoly(r, b)` with variable `j` the
  bit `n − 1 − j` of `idx` (the MOST significant first, `sumcheck.rs`'s convention);
* **`toK_mleSumExt`**, **`toK_mleSumBase`**: `eval_mle_ext` / `eval_mle_base` are `mleAt` of the cube values
  `b ↦ v[msbIndex b]`, `msbIndex` the code's index of the cube point `b` (`msbBits_msbIndex`, `msbIndex_msbBits`: a
  bijection between `{0,1}^n` and `[0, 2^n)`).
-/
import ZK60Formal.ExecField
import ZK60Formal.SoundMultilinear

namespace ZK60.Exec

open ZK60.Circuit (gP GF)
open ZK60.Sound
open Finset

/-! ## Field helpers -/

namespace Fp

/-- `Fp::from_i64`, on the value `v` of an `i64`: `Fp::new(v as u64)` for `v ≥ 0`, otherwise
`Fp::new(P − ((−v) as u64 % P))`. -/
def fromI64 (v : ℤ) : Fp :=
  if 0 ≤ v then new (UInt64.ofNat v.toNat) else new (P64 - UInt64.ofNat (-v).toNat % P64)

/-- **`from_i64` is the residue** of every value in `(−2^64, 2^64)` (an `i64` is in `[−2^63, 2^63)`). -/
theorem toGF_fromI64 (v : ℤ) (h1 : -2 ^ 64 < v) (h2 : v < 2 ^ 64) : (fromI64 v).toGF = (v : GF) := by
  unfold fromI64
  split_ifs with h
  · have hv : ((v.toNat : ℕ) : ℤ) = v := Int.toNat_of_nonneg h
    have hlt : v.toNat < 2 ^ 64 := by omega
    rw [toGF_new, UInt64.toNat_ofNat', Nat.mod_eq_of_lt hlt, ← Int.cast_natCast, hv]
  · have hw : (((-v).toNat : ℕ) : ℤ) = -v := Int.toNat_of_nonneg (by omega)
    have hwlt : (-v).toNat < 2 ^ 64 := by omega
    have hm : (UInt64.ofNat (-v).toNat % P64).toNat = (-v).toNat % gP := by
      rw [UInt64.toNat_mod, UInt64.toNat_ofNat', Nat.mod_eq_of_lt hwlt, P64_toNat, gP_val]
    have hmlt : (-v).toNat % gP < gP := Nat.mod_lt _ (by rw [gP_val]; norm_num)
    have hle : UInt64.ofNat (-v).toNat % P64 ≤ P64 := by
      rw [UInt64.le_iff_toNat_le, hm, P64_toNat, ← gP_val]
      exact hmlt.le
    rw [toGF_new, UInt64.toNat_sub_of_le _ _ hle, hm, P64_toNat, ← gP_val, Nat.cast_sub hmlt.le, ZMod.natCast_self,
      ZMod.natCast_mod, zero_sub, ← Int.cast_natCast, hw, Int.cast_neg, neg_neg]

/-- **`Fp::inv` is the field inverse of EVERY word** (`pow(p − 2)`; at zero `0^(p−2) = 0 = 0⁻¹`). The code asserts a
nonzero input; the value it would compute is the same. -/
theorem toGF_inv' (a : Fp) : (inv a).toGF = a.toGF⁻¹ := by
  by_cases h : a.toGF = 0
  · rw [h, inv_zero, inv, toGF_pow, h]
    exact zero_pow (by rw [show (P64 - 2).toNat = gP - 2 from rfl, gP_val]; norm_num)
  · exact toGF_inv a h

theorem new_toGF_ofNat (j : ℕ) (hj : j < 2 ^ 64) : (new (UInt64.ofNat j)).toGF = (j : GF) := by
  rw [toGF_new, UInt64.toNat_ofNat', Nat.mod_eq_of_lt hj]

end Fp

namespace Fp2

theorem canon_add (a b : Fp2) : (add a b).Canon := ⟨Fp.add_canon _ _, Fp.add_canon _ _⟩

theorem canon_sub (a b : Fp2) (ha : a.Canon) (hb : b.Canon) : (sub a b).Canon :=
  ⟨Fp.sub_canon _ _ ha.1 hb.1, Fp.sub_canon _ _ ha.2 hb.2⟩

theorem canon_mulBase (a : Fp2) (r : Fp) : (mulBase a r).Canon := ⟨Fp.mul_canon _ _, Fp.mul_canon _ _⟩

theorem canon_subBase (a : Fp2) (r : Fp) (ha : a.Canon) (hr : r.Canon) : (subBase a r).Canon :=
  ⟨Fp.sub_canon _ _ ha.1 hr, ha.2⟩

theorem canon_zero : zero.Canon := by decide

theorem canon_one : one.Canon := by decide

theorem canon_fromBase (a : Fp) (ha : a.Canon) : (fromBase a).Canon := ⟨ha, show Fp.zero.Canon by decide⟩

/-- `Fp2::from_u64`. -/
def fromU64 (v : UInt64) : Fp2 := fromBase (Fp.new v)

theorem canon_fromU64 (v : UInt64) : (fromU64 v).Canon := canon_fromBase _ (Fp.new_canon v)

theorem canon_getD {l : List Fp2} (hl : ∀ a ∈ l, a.Canon) (i : ℕ) : (l.getD i zero).Canon := by
  rw [List.getD_eq_getElem?_getD]
  cases h : l[i]? with
  | none => exact canon_zero
  | some a =>
    obtain ⟨hi, rfl⟩ := List.getElem?_eq_some_iff.mp h
    exact hl _ (List.getElem_mem hi)

section K

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem toK_zero : zero.toK U = 0 := by
  simp [toK, zero, ZK60.Hiding.fp2, Fp.zero, Fp.toGF]

theorem toK_fromBase (a : Fp) : (fromBase a).toK U = algebraMap GF K a.toGF := by
  simp [toK, fromBase, ZK60.Hiding.fp2, Fp.zero, Fp.toGF]

theorem toK_fromU64 (v : UInt64) : (fromU64 v).toK U = (v.toNat : K) := by
  rw [fromU64, toK_fromBase, Fp.toGF_new, map_natCast]

theorem toK_fromU64_ofNat (x : ℕ) (hx : x < 2 ^ 64) : (fromU64 (UInt64.ofNat x)).toK U = (x : K) := by
  rw [toK_fromU64, UInt64.toNat_ofNat', Nat.mod_eq_of_lt hx]

theorem toK_subBase (a : Fp2) (r : Fp) (ha : a.Canon) (hr : r.Canon) :
    (subBase a r).toK U = a.toK U - algebraMap GF K r.toGF := by
  simp only [toK, subBase, ZK60.Hiding.fp2, Fp.toGF_sub _ _ ha.1 hr, map_sub]
  ring

/-- **Canonical words are determined by their value**: the code's word equality on canonical values is the field's
equality (`1, U` are independent over `GF`, `7` not being a square). -/
theorem toK_injective (hU : U ^ 2 = algebraMap GF K 7) {a b : Fp2} (ha : a.Canon) (hb : b.Canon)
    (h : a.toK U = b.toK U) : a = b := by
  have hp := ZK60.Hiding.fp2_injective (ZK60.Hiding.not_mem_range_of_sq hU seven_not_square) h
  simp only [Prod.mk.injEq] at hp
  have e0 := Fp.toGF_injective ha.1 hb.1 hp.1
  have e1 := Fp.toGF_injective ha.2 hb.2 hp.2
  cases a
  cases b
  simp_all

theorem eq_iff_toK (hU : U ^ 2 = algebraMap GF K 7) {a b : Fp2} (ha : a.Canon) (hb : b.Canon) :
    a = b ↔ a.toK U = b.toK U :=
  ⟨fun h => h ▸ rfl, toK_injective U hU ha hb⟩

end K

end Fp2

/-! ## Folds and sums -/

section Folds

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem toK_foldl_mul (hU : U ^ 2 = algebraMap GF K 7) {α : Type} (g : α → Fp2) :
    ∀ (l : List α) (init : Fp2),
      (l.foldl (fun acc a => acc.mul (g a)) init).toK U = init.toK U * (l.map (fun a => (g a).toK U)).prod
  | [], init => by simp
  | a :: l, init => by
    simp only [List.foldl_cons]
    rw [toK_foldl_mul hU g l, Fp2.toK_mul U hU, List.map_cons, List.prod_cons, mul_assoc]

theorem canon_foldl_add {α : Type} (g : α → Fp2) :
    ∀ (l : List α) (init : Fp2), init.Canon → (l.foldl (fun acc a => acc.add (g a)) init).Canon
  | [], _, h => h
  | a :: l, init, _ => by
    simp only [List.foldl_cons]
    exact canon_foldl_add g l _ (Fp2.canon_add _ _)

theorem toK_foldl_add {α : Type} (g : α → Fp2) :
    ∀ (l : List α) (init : Fp2), init.Canon → (∀ a ∈ l, (g a).Canon) →
      (l.foldl (fun acc a => acc.add (g a)) init).toK U = init.toK U + (l.map (fun a => (g a).toK U)).sum
  | [], init, _, _ => by simp
  | a :: l, init, hi, hg => by
    simp only [List.foldl_cons]
    rw [toK_foldl_add g l _ (Fp2.canon_add _ _) (fun b hb => hg b (List.mem_cons_of_mem a hb)),
      Fp2.toK_add U _ _ hi (hg a List.mem_cons_self), List.map_cons, List.sum_cons, add_assoc]

theorem toGF_foldl_mul_skip (i : ℕ) (g : ℕ → Fp) :
    ∀ (l : List ℕ) (init : Fp),
      (l.foldl (fun a j => if i = j then a else a.mul (g j)) init).toGF
        = init.toGF * (l.map (fun j => if i = j then (1 : GF) else (g j).toGF)).prod
  | [], init => by simp
  | j :: l, init => by
    simp only [List.foldl_cons]
    rw [toGF_foldl_mul_skip i g l, List.map_cons, List.prod_cons]
    split_ifs
    · ring
    · rw [Fp.toGF_mul]
      ring

theorem toK_foldl_mul_skip (hU : U ^ 2 = algebraMap GF K 7) (i : ℕ) (g : ℕ → Fp2) :
    ∀ (l : List ℕ) (init : Fp2),
      (l.foldl (fun a j => if i = j then a else a.mul (g j)) init).toK U
        = init.toK U * (l.map (fun j => if i = j then (1 : K) else (g j).toK U)).prod
  | [], init => by simp
  | j :: l, init => by
    simp only [List.foldl_cons]
    rw [toK_foldl_mul_skip hU i g l, List.map_cons, List.prod_cons]
    split_ifs
    · ring
    · rw [Fp2.toK_mul U hU]
      ring

end Folds

theorem list_prod_range {M : Type} [CommMonoid M] (f : ℕ → M) :
    ∀ n, ((List.range n).map f).prod = ∏ i ∈ range n, f i
  | 0 => by simp
  | n + 1 => by
    rw [List.range_succ, List.map_append, List.prod_append, list_prod_range f n, Finset.prod_range_succ]
    simp

theorem list_sum_range {M : Type} [AddCommMonoid M] (f : ℕ → M) :
    ∀ n, ((List.range n).map f).sum = ∑ i ∈ range n, f i
  | 0 => by simp
  | n + 1 => by
    rw [List.range_succ, List.map_append, List.sum_append, list_sum_range f n, Finset.sum_range_succ]
    simp

/-- The product over the nodes other than `i`, as the code skips `j = i`. -/
theorem list_prod_range_skip {M : Type} [CommMonoid M] (n : ℕ) (i : Fin n) (g : ℕ → M) :
    ((List.range n).map (fun j => if (i : ℕ) = j then 1 else g j)).prod = ∏ j ∈ univ.erase i, g j := by
  rw [list_prod_range, ← Fin.prod_univ_eq_prod_range (fun j => if (i : ℕ) = j then 1 else g j) n,
    ← Finset.mul_prod_erase univ (fun j : Fin n => if (i : ℕ) = (j : ℕ) then 1 else g j) (mem_univ i)]
  rw [ite_eq_left rfl, one_mul]
  refine Finset.prod_congr rfl (fun j hj => ?_)
  have hne : j ≠ i := Finset.ne_of_mem_erase hj
  have : ¬ ((i : ℕ) = (j : ℕ)) := fun h => hne (Fin.ext h).symm
  simp [this]

/-- A sum over two lists of the same length, by index. -/
theorem list_sum_zip_map {α β M : Type} [AddCommMonoid M] (G : α → β → M) (da : α) (db : β) :
    ∀ (l1 : List α) (l2 : List β), l1.length = l2.length →
      ((l1.zip l2).map (fun p => G p.1 p.2)).sum = ∑ i ∈ range l1.length, G (l1.getD i da) (l2.getD i db)
  | [], _, _ => by simp
  | _ :: _, [], h => by simp at h
  | a :: l1, b :: l2, h => by
    simp only [List.length_cons, add_left_inj] at h
    rw [List.zip_cons_cons, List.map_cons, List.sum_cons, list_sum_zip_map G da db l1 l2 h, List.length_cons,
      Finset.sum_range_succ']
    simp only [List.getD_cons_zero, List.getD_cons_succ]
    rw [add_comm]

/-- A product over two lists of the same length, by index. -/
theorem list_prod_zip_map {α β M : Type} [CommMonoid M] (G : α → β → M) (da : α) (db : β) :
    ∀ (l1 : List α) (l2 : List β), l1.length = l2.length →
      ((l1.zip l2).map (fun p => G p.1 p.2)).prod = ∏ i ∈ range l1.length, G (l1.getD i da) (l2.getD i db)
  | [], _, _ => by simp
  | _ :: _, [], h => by simp at h
  | a :: l1, b :: l2, h => by
    simp only [List.length_cons, add_left_inj] at h
    rw [List.zip_cons_cons, List.map_cons, List.prod_cons, list_prod_zip_map G da db l1 l2 h, List.length_cons,
      Finset.prod_range_succ']
    simp only [List.getD_cons_zero, List.getD_cons_succ]
    rw [mul_comm]

/-! ## `interpolate_eval` -/

/-- `interpolate_eval`'s inner loop for the node `i`, one `j`: `num ← num·(x − j)`, `den ← den·from_i64(i − j)`, and
nothing for `j = i`. -/
def ieStep (x : Fp2) (i : ℕ) (nd : Fp2 × Fp) (j : ℕ) : Fp2 × Fp :=
  if i = j then nd else (nd.1.mul (x.subBase (Fp.new (UInt64.ofNat j))), nd.2.mul (Fp.fromI64 ((i : ℤ) - (j : ℤ))))

/-- The term of the node `i`: `vals[i].mul(num).mul_base(den.inv())`. -/
def ieTerm (vals : List Fp2) (x : Fp2) (i : ℕ) : Fp2 :=
  let nd := (List.range vals.length).foldl (ieStep x i) (Fp2.one, Fp.one)
  ((vals.getD i Fp2.zero).mul nd.1).mulBase nd.2.inv

/-- **`mle::interpolate_eval`**: the value at `x` of the polynomial through `(i, vals[i])`, `i = 0, …, d − 1`. -/
def interpolateEval (vals : List Fp2) (x : Fp2) : Fp2 :=
  (List.range vals.length).foldl (fun acc i => acc.add (ieTerm vals x i)) Fp2.zero

theorem ieStep_fold (x : Fp2) (i : ℕ) :
    ∀ (l : List ℕ) (a : Fp2) (b : Fp),
      (l.foldl (ieStep x i) (a, b)).1
          = l.foldl (fun a j => if i = j then a else a.mul (x.subBase (Fp.new (UInt64.ofNat j)))) a
        ∧ (l.foldl (ieStep x i) (a, b)).2
          = l.foldl (fun a j => if i = j then a else a.mul (Fp.fromI64 ((i : ℤ) - (j : ℤ)))) b
  | [], _, _ => ⟨rfl, rfl⟩
  | j :: l, a, b => by
    simp only [List.foldl_cons]
    by_cases h : i = j
    · simp only [ieStep, ite_eq_left h]
      exact ieStep_fold x i l a b
    · simp only [ieStep, ite_eq_right h]
      exact ieStep_fold x i l _ _

theorem canon_interpolateEval (vals : List Fp2) (x : Fp2) : (interpolateEval vals x).Canon :=
  canon_foldl_add _ _ _ Fp2.canon_zero

section Interp

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem toK_ieNum (hU : U ^ 2 = algebraMap GF K 7) (x : Fp2) (hx : x.Canon) (i : ℕ) :
    ∀ (l : List ℕ) (init : Fp2), (∀ j ∈ l, j < 2 ^ 64) →
      (l.foldl (fun a j => if i = j then a else a.mul (x.subBase (Fp.new (UInt64.ofNat j)))) init).toK U
        = init.toK U * (l.map (fun j => if i = j then (1 : K) else x.toK U - (j : K))).prod
  | [], init, _ => by simp
  | j :: l, init, hl => by
    simp only [List.foldl_cons]
    rw [toK_ieNum hU x hx i l _ (fun j' hj' => hl j' (List.mem_cons_of_mem j hj')), List.map_cons, List.prod_cons]
    split_ifs
    · ring
    · rw [Fp2.toK_mul U hU, Fp2.toK_subBase U _ _ hx (Fp.new_canon _), Fp.new_toGF_ofNat j (hl j List.mem_cons_self),
        map_natCast]
      ring

theorem toGF_ieDen (i : ℕ) (hi : i < 2 ^ 64) :
    ∀ (l : List ℕ) (init : Fp), (∀ j ∈ l, j < 2 ^ 64) →
      algebraMap GF K (l.foldl (fun a j => if i = j then a else a.mul (Fp.fromI64 ((i : ℤ) - (j : ℤ)))) init).toGF
        = algebraMap GF K init.toGF * (l.map (fun j => if i = j then (1 : K) else (i : K) - (j : K))).prod
  | [], init, _ => by simp
  | j :: l, init, hl => by
    simp only [List.foldl_cons]
    have hj := hl j List.mem_cons_self
    rw [toGF_ieDen i hi l _ (fun j' hj' => hl j' (List.mem_cons_of_mem j hj')), List.map_cons, List.prod_cons]
    split_ifs
    · ring
    · rw [Fp.toGF_mul, Fp.toGF_fromI64 ((i : ℤ) - (j : ℤ)) (by omega) (by omega), map_mul, Int.cast_sub,
        Int.cast_natCast, Int.cast_natCast, map_sub, map_natCast, map_natCast]
      ring

theorem toK_ieTerm (hU : U ^ 2 = algebraMap GF K 7) (vals : List Fp2) (hlen : vals.length < 2 ^ 64) (x : Fp2)
    (hx : x.Canon) (i : ℕ) (hi : i < vals.length) :
    (ieTerm vals x i).toK U = (vals.getD i Fp2.zero).toK U
      * ((List.range vals.length).map (fun j => if i = j then (1 : K) else x.toK U - (j : K))).prod
      * ((List.range vals.length).map (fun j => if i = j then (1 : K) else ((i : K) - (j : K)))).prod⁻¹ := by
  have h64 : ∀ j ∈ List.range vals.length, j < 2 ^ 64 := fun j hj => by
    have := List.mem_range.mp hj
    omega
  unfold ieTerm
  simp only
  rw [Fp2.toK_mulBase, Fp2.toK_mul U hU, (ieStep_fold x i _ Fp2.one Fp.one).1, (ieStep_fold x i _ Fp2.one Fp.one).2,
    toK_ieNum U hU x hx i _ _ h64, Fp.toGF_inv', map_inv₀, toGF_ieDen i (by omega) _ _ h64, Fp2.toK_one, one_mul,
    Fp.one_toGF, map_one, one_mul]

/-- **`interpolate_eval` is `SoundSumcheck.lean`'s `interpEval`** on `d + 1` values (`d < p`) and a canonical point,
under `toK`: `Σ_i s_i·Π_{j ≠ i}(x − j)·(Π_{j ≠ i}(i − j))⁻¹`. -/
theorem toK_interpolateEval (hU : U ^ 2 = algebraMap GF K 7) (d : ℕ) (hd : d < gP) (vals : List Fp2)
    (hl : vals.length = d + 1) (x : Fp2) (hx : x.Canon) :
    (interpolateEval vals x).toK U = interpEval (fun i : Fin (d + 1) => (vals.getD i Fp2.zero).toK U) (x.toK U) := by
  have hd64 : vals.length < 2 ^ 64 := by rw [Fp.gP_val] at hd; omega
  unfold interpolateEval
  rw [toK_foldl_add U (ieTerm vals x) _ _ Fp2.canon_zero (fun i _ => Fp2.canon_mulBase _ _), Fp2.toK_zero,
    zero_add, List.map_congr_left (fun i hi => toK_ieTerm U hU vals hd64 x hx i (List.mem_range.mp hi)),
    list_sum_range, hl, ← Fin.sum_univ_eq_sum_range]
  unfold interpEval
  refine Finset.sum_congr rfl (fun i _ => ?_)
  dsimp only
  simp only [node]
  rw [list_prod_range_skip (d + 1) i (fun j => x.toK U - (j : K)),
    list_prod_range_skip (d + 1) i (fun j => ((i : ℕ) : K) - (j : K))]

/-- So the code computes the round polynomial's evaluation (`interpEval_eq`). -/
theorem interpolateEval_roundPoly (hU : U ^ 2 = algebraMap GF K 7) (d : ℕ) (hd : d < gP) (vals : List Fp2)
    (hl : vals.length = d + 1) (x : Fp2) (hx : x.Canon) :
    (interpolateEval vals x).toK U
      = (roundPoly (fun i : Fin (d + 1) => (vals.getD i Fp2.zero).toK U)).eval (x.toK U) := by
  rw [toK_interpolateEval U hU d hd vals hl x hx, interpEval_eq]

/-- Every field `K ⊇ GF` has characteristic `p`: the degree premise `d < ringChar K` of `SoundSumcheck.lean` is
`d < p`. -/
theorem ringChar_eq_gP : ringChar K = gP := by
  have : CharP K gP := charP_of_injective_algebraMap (algebraMap GF K).injective gP
  exact ringChar.eq K gP

/-- With `d < p` the round polynomial of the sent values has degree `≤ d` and takes them at the nodes. -/
theorem interpolateEval_degree (d : ℕ) (hd : d < gP) (s : Fin (d + 1) → K) :
    (roundPoly s).natDegree ≤ d ∧ ∀ i, (roundPoly s).eval (node d i) = s i := by
  have h : d < ringChar K := by rw [ringChar_eq_gP]; exact hd
  exact ⟨roundPoly_natDegree_le h s, roundPoly_eval_node h s⟩

end Interp

/-! ## `eq_point`, `eq_table`, `eq_table_msb` -/

/-- One factor of `eq_point`: `a·b + (1 − a)(1 − b)`. -/
def eqFactor (a b : Fp2) : Fp2 := (a.mul b).add ((Fp2.one.sub a).mul (Fp2.one.sub b))

/-- `mle::eq_point`'s loop. -/
def eqPointBody (r s : List Fp2) : Fp2 := (r.zip s).foldl (fun acc p => acc.mul (eqFactor p.1 p.2)) Fp2.one

/-- **`mle::eq_point`**, its length assertion as a refusal. -/
def eqPoint (r s : List Fp2) : Option Fp2 := if r.length = s.length then some (eqPointBody r s) else none

/-- One doubling step of `eq_table` on the first `2·len` entries: `lo·(1 − r_i)`, then `lo·r_i`, then the rest. -/
def eqStep (len : ℕ) (ri : Fp2) (buf : List Fp2) : List Fp2 :=
  let om := Fp2.one.sub ri
  (buf.take len).map (fun e => e.mul om) ++ ((buf.take len).map (fun e => e.mul ri) ++ buf.drop (2 * len))

/-- `eq_table`'s loop over `r`, `len` doubling. -/
def eqTableAux : List Fp2 → ℕ → List Fp2 → List Fp2
  | [], _, buf => buf
  | ri :: rs, len, buf => eqTableAux rs (len * 2) (eqStep len ri buf)

/-- **`mle::eq_table`**: the buffer of `2^n` ones, then the doubling steps in the order of `r`. -/
def eqTable (r : List Fp2) : List Fp2 := eqTableAux r 1 (List.replicate (2 ^ r.length) Fp2.one)

/-- **`mle::eq_table_msb`**: `eq_table` of the reversed point. -/
def eqTableMsb (r : List Fp2) : List Fp2 := eqTable r.reverse

/-- A point of `n` words, read in `K`. -/
def vecK {K : Type} [Field K] [Algebra GF K] (U : K) (n : ℕ) (l : List Fp2) : Fin n → K :=
  fun i => (l.getD i Fp2.zero).toK U

/-- The bit of the code's index `idx` that `eq_table_msb` assigns to variable `j`: bit `n − 1 − j`. -/
def msbBits (n idx : ℕ) (j : Fin n) : Bool := decide (idx / 2 ^ (n - 1 - (j : ℕ)) % 2 = 1)

/-- The factor of one variable at the bit `b`: `x` or `1 − x`. -/
def eqSel {K : Type} [Field K] (x : K) (b : Bool) : K := if b then x else 1 - x

theorem bit_lt (idx k : ℕ) (h : idx < 2 ^ k) : idx / 2 ^ k % 2 = 0 := by
  rw [Nat.div_eq_of_lt h]

theorem bit_high (m k : ℕ) (h : m < 2 ^ k) : (2 ^ k + m) / 2 ^ k % 2 = 1 := by
  rw [Nat.add_div_left m (Nat.two_pow_pos k), Nat.div_eq_of_lt h]

theorem bit_low (m k i : ℕ) (hi : i < k) : (2 ^ k + m) / 2 ^ i % 2 = m / 2 ^ i % 2 := by
  have e : 2 ^ k = 2 ^ i * (2 * 2 ^ (k - i - 1)) := by
    rw [← pow_succ', ← pow_add]
    congr 1
    omega
  rw [e, Nat.mul_add_div (by positivity), Nat.mul_add_mod]

theorem getD_eq_get {α : Type} (l : List α) (i : ℕ) (d : α) (h : i < l.length) : l.getD i d = l[i] := by
  rw [List.getD_eq_getElem?_getD, List.getElem?_eq_some_iff.mpr ⟨h, rfl⟩, Option.getD_some]

theorem getD_append_lt {α : Type} (l l' : List α) (d : α) (n : ℕ) (h : n < l.length) :
    (l ++ l').getD n d = l.getD n d := by
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_append_left h]

theorem getD_append_ge {α : Type} (l l' : List α) (d : α) (n : ℕ) (h : l.length ≤ n) :
    (l ++ l').getD n d = l'.getD (n - l.length) d := by
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_append_right h]

theorem getD_map_lt {α β : Type} (l : List α) (f : α → β) (d : α) (d' : β) (n : ℕ) (h : n < l.length) :
    (l.map f).getD n d' = f (l.getD n d) := by
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_map,
    List.getElem?_eq_some_iff.mpr ⟨h, rfl⟩, Option.map_some, Option.getD_some, Option.getD_some]

theorem getD_reverse (r : List Fp2) (i : ℕ) (hi : i < r.length) :
    r.reverse.getD i Fp2.zero = r.getD (r.length - 1 - i) Fp2.zero := by
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_reverse hi]

theorem eqStep_spec (k : ℕ) (ri : Fp2) (P R : List Fp2) (hP : P.length = 2 ^ k) :
    eqStep (2 ^ k) ri (P ++ R)
      = (P.map (fun e => e.mul (Fp2.one.sub ri)) ++ P.map (fun e => e.mul ri)) ++ R.drop (2 ^ k) := by
  unfold eqStep
  simp only
  rw [List.take_left' hP, List.drop_append,
    List.drop_eq_nil_of_le (as := P) (i := 2 * 2 ^ k) (by rw [hP]; omega), List.nil_append,
    List.append_assoc, hP, show 2 * 2 ^ k - 2 ^ k = 2 ^ k by omega]

/-- `eqPoly`'s factor at a bit. -/
theorem eqPoly_factor_bit {K : Type} [Field K] (x : K) (b : Bool) : x * bit b + (1 - x) * (1 - bit b) = eqSel x b := by
  cases b <;> simp [bit, eqSel]

section Eq

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem toK_eqFactor (hU : U ^ 2 = algebraMap GF K 7) (a b : Fp2) (ha : a.Canon) (hb : b.Canon) :
    (eqFactor a b).toK U = a.toK U * b.toK U + (1 - a.toK U) * (1 - b.toK U) := by
  unfold eqFactor
  rw [Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _), Fp2.toK_mul U hU, Fp2.toK_mul U hU,
    Fp2.toK_sub U _ _ Fp2.canon_one ha, Fp2.toK_sub U _ _ Fp2.canon_one hb, Fp2.toK_one]

/-- **`eq_point` is `eqPoly`** on canonical points of the same length. -/
theorem toK_eqPointBody (hU : U ^ 2 = algebraMap GF K 7) (r s : List Fp2) (hr : ∀ a ∈ r, a.Canon)
    (hs : ∀ a ∈ s, a.Canon) (hl : r.length = s.length) :
    (eqPointBody r s).toK U = eqPoly (vecK U r.length r) (vecK U r.length s) := by
  unfold eqPointBody
  rw [toK_foldl_mul U hU, Fp2.toK_one, one_mul,
    list_prod_zip_map (fun a b => (eqFactor a b).toK U) Fp2.zero Fp2.zero r s hl]
  unfold eqPoly
  rw [← Fin.prod_univ_eq_prod_range (fun i => (eqFactor (r.getD i Fp2.zero) (s.getD i Fp2.zero)).toK U) r.length]
  refine Finset.prod_congr rfl (fun i _ => ?_)
  exact toK_eqFactor U hU _ _ (Fp2.canon_getD hr _) (Fp2.canon_getD hs _)

/-- **The doubling loop's invariant.** After the first `k` steps the buffer is `P` followed by ones, entry `idx` of
`P` being `Π_{i<k}` of `r_i` or `1 − r_i` by bit `i` of `idx`. -/
theorem eqTableAux_spec (hU : U ^ 2 = algebraMap GF K 7) (r : List Fp2) (hr : ∀ a ∈ r, a.Canon) :
    ∀ (rs : List Fp2) (k : ℕ) (P : List Fp2), r.drop k = rs → k + rs.length = r.length → P.length = 2 ^ k →
      (∀ idx < P.length,
        (P.getD idx Fp2.zero).toK U = ∏ i ∈ range k, eqSel ((r.getD i Fp2.zero).toK U) (decide (idx / 2 ^ i % 2 = 1))) →
      (eqTableAux rs (2 ^ k) (P ++ List.replicate (2 ^ r.length - 2 ^ k) Fp2.one)).length = 2 ^ r.length
        ∧ ∀ idx < 2 ^ r.length,
          ((eqTableAux rs (2 ^ k) (P ++ List.replicate (2 ^ r.length - 2 ^ k) Fp2.one)).getD idx Fp2.zero).toK U
            = ∏ i ∈ range r.length, eqSel ((r.getD i Fp2.zero).toK U) (decide (idx / 2 ^ i % 2 = 1))
  | [], k, P, _, hk, hP, hent => by
    simp only [List.length_nil, add_zero] at hk
    subst hk
    simp only [Nat.sub_self, List.replicate_zero, List.append_nil, eqTableAux]
    exact ⟨hP, fun idx hidx => hent idx (by rw [hP]; exact hidx)⟩
  | ri :: rs, k, P, hd, hk, hP, hent => by
    simp only [List.length_cons] at hk
    have hget : r.getD k Fp2.zero = ri := by
      have h0 : (r.drop k)[0]? = some ri := by rw [hd]; rfl
      rw [List.getElem?_drop, Nat.add_zero] at h0
      rw [List.getD_eq_getElem?_getD, h0]
      rfl
    have hri : ri.Canon := by
      have := Fp2.canon_getD hr k
      rwa [hget] at this
    simp only [eqTableAux]
    rw [eqStep_spec k ri P _ hP, List.drop_replicate, show 2 ^ k * 2 = 2 ^ (k + 1) from (pow_succ 2 k).symm,
      show 2 ^ r.length - 2 ^ k - 2 ^ k = 2 ^ r.length - 2 ^ (k + 1) by rw [pow_succ]; omega]
    refine eqTableAux_spec hU r hr rs (k + 1) _ ?_ (by omega) ?_ ?_
    · have := congrArg (List.drop 1) hd
      simpa [List.drop_drop] using this
    · simp [hP, pow_succ, mul_two]
    · intro idx h
      have hlm : (P.map (fun e => e.mul (Fp2.one.sub ri))).length = 2 ^ k := by rw [List.length_map, hP]
      rw [Finset.prod_range_succ]
      by_cases h1 : idx < 2 ^ k
      · rw [getD_append_lt _ _ _ _ (by rw [hlm]; exact h1), getD_map_lt _ _ Fp2.zero _ _ (by rw [hP]; exact h1),
          Fp2.toK_mul U hU, Fp2.toK_sub U _ _ Fp2.canon_one hri, Fp2.toK_one, hent idx (by rw [hP]; exact h1),
          bit_lt idx k h1, hget]
        simp [eqSel]
      · have hge : 2 ^ k ≤ idx := by omega
        have hlt2 : idx < 2 ^ k + 2 ^ k := by simpa [hP] using h
        obtain ⟨m, rfl⟩ : ∃ m, idx = 2 ^ k + m := ⟨idx - 2 ^ k, by omega⟩
        have hm : m < 2 ^ k := by omega
        rw [getD_append_ge _ _ _ _ (by rw [hlm]; exact hge), hlm, Nat.add_sub_cancel_left,
          getD_map_lt _ _ Fp2.zero _ _ (by rw [hP]; exact hm), Fp2.toK_mul U hU, hent m (by rw [hP]; exact hm),
          bit_high m k hm, hget]
        congr 1
        refine Finset.prod_congr rfl (fun i hi => ?_)
        rw [bit_low m k i (Finset.mem_range.mp hi)]

/-- **`eq_table`**: entry `idx` is `Π_i (r_i if bit i of idx else 1 − r_i)`, bit 0 the least significant. -/
theorem toK_eqTable (hU : U ^ 2 = algebraMap GF K 7) (r : List Fp2) (hr : ∀ a ∈ r, a.Canon) :
    (eqTable r).length = 2 ^ r.length ∧ ∀ idx < 2 ^ r.length,
      ((eqTable r).getD idx Fp2.zero).toK U
        = ∏ i ∈ range r.length, eqSel ((r.getD i Fp2.zero).toK U) (decide (idx / 2 ^ i % 2 = 1)) := by
  have hsp := eqTableAux_spec U hU r hr r 0 [Fp2.one] List.drop_zero (by simp) rfl (by
    intro idx h
    have : idx = 0 := by simpa using h
    subst this
    simp [Fp2.toK_one])
  have h1 : [Fp2.one] ++ List.replicate (2 ^ r.length - 2 ^ 0) Fp2.one = List.replicate (2 ^ r.length) Fp2.one := by
    rw [pow_zero, List.singleton_append, ← List.replicate_succ]
    congr 1
    have := Nat.two_pow_pos r.length
    omega
  rw [h1, pow_zero] at hsp
  exact hsp

/-- **`eq_table_msb`**: entry `idx` is `eqPoly(r, b)` with variable `j` the bit `n − 1 − j` of `idx` (the MOST
significant first). -/
theorem toK_eqTableMsb (hU : U ^ 2 = algebraMap GF K 7) (r : List Fp2) (hr : ∀ a ∈ r, a.Canon) :
    (eqTableMsb r).length = 2 ^ r.length ∧ ∀ idx < 2 ^ r.length,
      ((eqTableMsb r).getD idx Fp2.zero).toK U = eqPoly (vecK U r.length r) (fun j => bit (msbBits r.length idx j)) := by
  have hrr : ∀ a ∈ r.reverse, a.Canon := fun a ha => hr a (List.mem_reverse.mp ha)
  obtain ⟨hl, he⟩ := toK_eqTable U hU r.reverse hrr
  simp only [List.length_reverse] at hl he
  refine ⟨hl, fun idx hidx => (he idx hidx).trans ?_⟩
  have hR : eqPoly (vecK U r.length r) (fun j => bit (msbBits r.length idx j))
      = ∏ j ∈ range r.length, eqSel ((r.getD j Fp2.zero).toK U) (decide (idx / 2 ^ (r.length - 1 - j) % 2 = 1)) := by
    rw [← Fin.prod_univ_eq_prod_range (fun j => eqSel ((r.getD j Fp2.zero).toK U)
      (decide (idx / 2 ^ (r.length - 1 - j) % 2 = 1))) r.length]
    simp only [eqPoly, eqPoly_factor_bit]
    rfl
  rw [hR, ← Finset.prod_range_reflect (fun j => eqSel ((r.getD j Fp2.zero).toK U)
      (decide (idx / 2 ^ (r.length - 1 - j) % 2 = 1))) r.length]
  refine Finset.prod_congr rfl (fun i hi => ?_)
  have hi' := Finset.mem_range.mp hi
  rw [getD_reverse r i hi', show r.length - 1 - (r.length - 1 - i) = i by omega]

end Eq

/-! ## The code's index of a cube point, and the multilinear evaluations -/

/-- **The code's index of the cube point `b`** in `eq_table_msb`'s order (variable `j` is bit `n − 1 − j`), through
`finFunctionFinEquiv` (bit `i` of an index is its digit `i`). -/
def msbIndex (n : ℕ) (b : Fin n → Bool) : ℕ :=
  (finFunctionFinEquiv (m := 2) (fun i : Fin n => if b (Fin.rev i) then (1 : Fin 2) else 0) : ℕ)

theorem ffe_symm_val (n k : ℕ) (hk : k < 2 ^ n) (i : Fin n) :
    ((finFunctionFinEquiv (m := 2) (n := n)).symm ⟨k, hk⟩ i : ℕ) = k / 2 ^ (i : ℕ) % 2 := rfl

theorem msbIndex_lt (n : ℕ) (b : Fin n → Bool) : msbIndex n b < 2 ^ n := Fin.isLt _

theorem msbBits_msbIndex (n : ℕ) (b : Fin n → Bool) : msbBits n (msbIndex n b) = b := by
  funext j
  have hk := msbIndex_lt n b
  have h1 : (finFunctionFinEquiv (m := 2) (n := n)).symm ⟨msbIndex n b, hk⟩
      = (fun i : Fin n => if b (Fin.rev i) then (1 : Fin 2) else 0) := by
    have : (⟨msbIndex n b, hk⟩ : Fin (2 ^ n))
        = finFunctionFinEquiv (m := 2) (fun i : Fin n => if b (Fin.rev i) then (1 : Fin 2) else 0) := Fin.ext rfl
    rw [this, Equiv.symm_apply_apply]
  have hj := j.isLt
  have h2 : msbIndex n b / 2 ^ (n - 1 - (j : ℕ)) % 2 = ((if b j then (1 : Fin 2) else 0 : Fin 2) : ℕ) := by
    have e := congrArg (fun g : Fin n → Fin 2 => ((g (Fin.rev j) : Fin 2) : ℕ)) h1
    rw [show n - 1 - (j : ℕ) = ((Fin.rev j : Fin n) : ℕ) by rw [Fin.val_rev]; omega, ← ffe_symm_val n _ hk]
    simpa only [Fin.rev_rev] using e
  unfold msbBits
  rw [h2]
  cases b j <;> rfl

theorem msbIndex_msbBits (n idx : ℕ) (h : idx < 2 ^ n) : msbIndex n (msbBits n idx) = idx := by
  have e : (fun i : Fin n => if msbBits n idx (Fin.rev i) then (1 : Fin 2) else 0)
      = (finFunctionFinEquiv (m := 2) (n := n)).symm ⟨idx, h⟩ := by
    funext i
    apply Fin.ext
    rw [ffe_symm_val]
    have hi := i.isLt
    unfold msbBits
    rw [Fin.val_rev, show n - 1 - (n - ((i : ℕ) + 1)) = (i : ℕ) by omega]
    rcases Nat.mod_two_eq_zero_or_one (idx / 2 ^ (i : ℕ)) with h0 | h0 <;> simp [h0]
  unfold msbIndex
  rw [e, Equiv.apply_symm_apply]

/-- **Summing over the code's indices is summing over the cube.** -/
theorem sum_range_msb {M : Type} [AddCommMonoid M] (n : ℕ) (G : (Fin n → Bool) → ℕ → M) :
    ∑ idx ∈ range (2 ^ n), G (msbBits n idx) idx = ∑ b : Fin n → Bool, G b (msbIndex n b) := by
  refine Finset.sum_nbij' (msbBits n) (msbIndex n) (fun _ _ => mem_univ _)
    (fun b _ => Finset.mem_range.mpr (msbIndex_lt n b))
    (fun idx hi => msbIndex_msbBits n idx (Finset.mem_range.mp hi))
    (fun b _ => msbBits_msbIndex n b) (fun idx hi => ?_)
  rw [msbIndex_msbBits n idx (Finset.mem_range.mp hi)]

/-- `eval_mle_ext`'s sum (rayon's `reduce` in the code, left to right here: the same word, see the header). -/
def mleSumExt (v eq : List Fp2) : Fp2 := (v.zip eq).foldl (fun acc p => acc.add (p.2.mul p.1)) Fp2.zero

/-- **`mle::eval_mle_ext`**, its length assertion as a refusal. -/
def evalMleExt (v r : List Fp2) : Option Fp2 :=
  if v.length = 2 ^ r.length then some (mleSumExt v (eqTableMsb r)) else none

/-- `eval_mle_base`'s sum (`e.mul_base(a)`). -/
def mleSumBase (v : List Fp) (eq : List Fp2) : Fp2 := (v.zip eq).foldl (fun acc p => acc.add (p.2.mulBase p.1)) Fp2.zero

/-- **`mle::eval_mle_base`**, its length assertion as a refusal. -/
def evalMleBase (v : List Fp) (r : List Fp2) : Option Fp2 :=
  if v.length = 2 ^ r.length then some (mleSumBase v (eqTableMsb r)) else none

section Mle

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **`eval_mle_ext` is `mleAt`**: the multilinear extension, at the point `r`, of the cube values
`b ↦ v[msbIndex b]`. -/
theorem toK_mleSumExt (hU : U ^ 2 = algebraMap GF K 7) (v r : List Fp2) (hr : ∀ a ∈ r, a.Canon)
    (hv : v.length = 2 ^ r.length) :
    (mleSumExt v (eqTableMsb r)).toK U
      = mleAt (fun b => (v.getD (msbIndex r.length b) Fp2.zero).toK U) (vecK U r.length r) := by
  obtain ⟨hl, he⟩ := toK_eqTableMsb U hU r hr
  unfold mleSumExt
  rw [toK_foldl_add U (fun p : Fp2 × Fp2 => p.2.mul p.1) _ _ Fp2.canon_zero (fun p _ => Fp2.canon_mul _ _),
    Fp2.toK_zero, zero_add,
    list_sum_zip_map (fun a e => (Fp2.mul e a).toK U) Fp2.zero Fp2.zero v (eqTableMsb r) (by rw [hv, hl]), hv]
  unfold mleAt
  refine Eq.trans ?_ (sum_range_msb r.length
    (fun b idx => eqPoly (vecK U r.length r) (fun i => bit (b i)) * (v.getD idx Fp2.zero).toK U))
  refine Finset.sum_congr rfl (fun idx hi => ?_)
  rw [Fp2.toK_mul U hU, he idx (Finset.mem_range.mp hi)]

/-- **`eval_mle_base` is `mleAt`** of the base-field cube values. -/
theorem toK_mleSumBase (hU : U ^ 2 = algebraMap GF K 7) (v : List Fp) (r : List Fp2) (hr : ∀ a ∈ r, a.Canon)
    (hv : v.length = 2 ^ r.length) :
    (mleSumBase v (eqTableMsb r)).toK U
      = mleAt (fun b => algebraMap GF K (v.getD (msbIndex r.length b) Fp.zero).toGF) (vecK U r.length r) := by
  obtain ⟨hl, he⟩ := toK_eqTableMsb U hU r hr
  unfold mleSumBase
  rw [toK_foldl_add U (fun p : Fp × Fp2 => p.2.mulBase p.1) _ _ Fp2.canon_zero (fun p _ => Fp2.canon_mulBase _ _),
    Fp2.toK_zero, zero_add,
    list_sum_zip_map (fun a e => (Fp2.mulBase e a).toK U) Fp.zero Fp2.zero v (eqTableMsb r) (by rw [hv, hl]), hv]
  unfold mleAt
  refine Eq.trans ?_ (sum_range_msb r.length
    (fun b idx => eqPoly (vecK U r.length r) (fun i => bit (b i)) * algebraMap GF K (v.getD idx Fp.zero).toGF))
  refine Finset.sum_congr rfl (fun idx hi => ?_)
  rw [Fp2.toK_mulBase, he idx (Finset.mem_range.mp hi)]

end Mle

end ZK60.Exec
