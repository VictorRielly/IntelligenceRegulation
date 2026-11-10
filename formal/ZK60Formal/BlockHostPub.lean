/-
D63 lane L44 (2026-11-10), part 2: **the verifier's public tables at the W16R2 rung, from the block's public data**
(deliverable 2, finding L35-2): a concrete `pubsW16 B rest`, every table the hosts read built from `B` in the code's
arithmetic, and **`pubW16_of`**: it meets every field of `PubW16`.

* `wordGF`: a base value as the code's word (`Fp2::from_base`); `toK_wordGF`;
* `cubeTab n g`: the table of a function on the cube, in the code's index order (`msbIndex`, `eq_table_msb`'s);
  **`cubeTab_getD`**;
* `drSeg dr off n`: the draws `off … off + n − 1` (a zero word past the end);
* `foldTab m n W r`: **the fold of a weight by `eq(r, ·)`** in the code's arithmetic (`eq_table_msb`, `Fp2::mul`,
  `Fp2::add`); **`foldTab_getD`**: entry `c` read in the field is `Σ_y eq(r, y)·W(c, y)` (canonical `r`);
* **`pubsW16 B rest`**: the support gates, the norms' `γ`, RoPE's `cos` / `sin`, the causal mask, the activation's group
  column and the seven matmuls' folded weights from `B`; the tables of the lookup side (`SC_LZC`'s support, `SC_TAB`'s
  value columns, `SC_ZS`) from `rest` (deliverable 3);
* **`pubW16_of`**: `PubW16 U (pubsW16 B rest) Pb Lay B`, for every `rest`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockHostBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-! ## Words and tables -/

/-- **A base value as the code's word** (`Fp2::from_base` of the canonical word). -/
def wordGF (x : GF) : Fp2 := Fp2.fromBase (Fp.ofGF x)

theorem wordGF_canon (x : GF) : (wordGF x).Canon := Fp2.canon_fromBase _ (Fp.ofGF_canon x)

theorem toK_wordGF {K : Type} [Field K] [Algebra GF K] (U : K) (x : GF) : (wordGF x).toK U = algebraMap GF K x := by
  unfold wordGF
  rw [Fp2.toK_fromBase, Fp.toGF_ofGF]

/-- **The table of a function on the cube**, in the code's index order. -/
def cubeTab (n : ℕ) (g : (Fin n → Bool) → GF) : List Fp2 :=
  (List.range (2 ^ n)).map fun idx => wordGF (g (msbBits n idx))

theorem cubeTab_getD (n : ℕ) (g : (Fin n → Bool) → GF) (b : Fin n → Bool) :
    (cubeTab n g).getD (msbIndex n b) Fp2.zero = wordGF (g b) := by
  unfold cubeTab
  rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range (msbIndex_lt n b)]
  simp only [Option.map_some, Option.getD_some, msbBits_msbIndex]

/-- The draws `off … off + n − 1`, a zero word past the end. -/
def drSeg (dr : List Fp2) (off n : ℕ) : List Fp2 := List.ofFn fun a : Fin n => dr.getD (off + a) Fp2.zero

theorem drSeg_length (dr : List Fp2) (off n : ℕ) : (drSeg dr off n).length = n := List.length_ofFn

theorem drSeg_getD (dr : List Fp2) (off n : ℕ) (a : Fin n) : (drSeg dr off n).getD a Fp2.zero = dr.getD (off + a) Fp2.zero := by
  unfold drSeg
  rw [List.getD_eq_getElem?_getD, List.getElem?_ofFn]
  simp

theorem drSeg_canon (dr : List Fp2) (hdr : ∀ x ∈ dr, x.Canon) (off n : ℕ) : ∀ x ∈ drSeg dr off n, x.Canon := by
  intro x hx
  unfold drSeg at hx
  obtain ⟨a, rfl⟩ := List.mem_ofFn.mp hx
  rw [List.getD_eq_getElem?_getD]
  cases h : dr[off + (a : ℕ)]? with
  | none => exact Fp2.canon_zero
  | some y => exact hdr y (List.mem_of_getElem? h)

/-- A sum of words in the code's arithmetic (`Fp2::add`, from zero). -/
def wsumF (l : List Fp2) : Fp2 := l.foldl Fp2.add Fp2.zero

section Sum

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem toK_foldl_add : ∀ (l : List Fp2) (a : Fp2), a.Canon → (∀ x ∈ l, x.Canon) →
    (l.foldl Fp2.add a).toK U = a.toK U + (l.map (Fp2.toK U)).sum
  | [], a, _, _ => by simp
  | x :: l, a, ha, hl => by
    rw [List.foldl_cons, toK_foldl_add l (a.add x) (Fp2.canon_add a x) (fun y hy => hl y (by simp [hy])),
      Fp2.toK_add U a x ha (hl x (by simp)), List.map_cons, List.sum_cons]
    ring

theorem toK_wsumF (l : List Fp2) (hl : ∀ x ∈ l, x.Canon) : (wsumF l).toK U = (l.map (Fp2.toK U)).sum := by
  unfold wsumF
  rw [toK_foldl_add U l Fp2.zero Fp2.canon_zero hl, Fp2.toK_zero, zero_add]

/-- A list sum over `range N` as a `Finset` sum. -/
theorem list_sum_range {M : Type} [AddCommMonoid M] (N : ℕ) (f : ℕ → M) :
    ((List.range N).map f).sum = ∑ i ∈ Finset.range N, f i := by
  induction N with
  | zero => simp
  | succ N ih => rw [List.range_succ, List.map_append, List.sum_append, ih, Finset.sum_range_succ]; simp

/-- The code's index order is a bijection onto the cube. -/
def eMsb (n : ℕ) : Fin (2 ^ n) ≃ (Fin n → Bool) :=
  ⟨fun i => msbBits n i, fun b => ⟨msbIndex n b, msbIndex_lt n b⟩,
    fun i => Fin.ext (msbIndex_msbBits n i i.isLt), fun b => msbBits_msbIndex n b⟩

/-- **A sum over the code's indices is a sum over the cube.** -/
theorem sum_range_msb {M : Type} [AddCommMonoid M] (n : ℕ) (F : (Fin n → Bool) → M) :
    ∑ i ∈ Finset.range (2 ^ n), F (msbBits n i) = ∑ y, F y := by
  rw [← Fin.sum_univ_eq_sum_range (fun i => F (msbBits n i))]
  exact Fintype.sum_equiv (eMsb n) _ _ (fun _ => rfl)

end Sum

/-- **The fold of a weight by `eq(r, ·)`** in the code's arithmetic: entry `idx` is `Σ_j eq_table_msb(r)[j]·W(idx, j)`. -/
def foldTab (m n : ℕ) (W : (Fin m → Bool) → (Fin n → Bool) → GF) (r : List Fp2) : List Fp2 :=
  (List.range (2 ^ m)).map fun idx =>
    wsumF ((List.range (2 ^ n)).map fun j =>
      ((eqTableMsb r).getD j Fp2.zero).mul (wordGF (W (msbBits m idx) (msbBits n j))))

section Fold

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **A folded table's entry, read in the field**: `Σ_y eq(r, y)·W(c, y)` (for `n` canonical words `r`). -/
theorem foldTab_getD (m n : ℕ) (W : (Fin m → Bool) → (Fin n → Bool) → GF) (r : List Fp2) (hrl : r.length = n)
    (hr : ∀ a ∈ r, a.Canon) (c : Fin m → Bool) :
    ((foldTab m n W r).getD (msbIndex m c) Fp2.zero).toK U
      = ∑ y : Fin n → Bool, eqPoly (vecK U n r) (fun i => bit (y i)) * algebraMap GF K (W c y) := by
  unfold foldTab
  rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range (msbIndex_lt m c)]
  simp only [Option.map_some, Option.getD_some, msbBits_msbIndex]
  rw [toK_wsumF U _ (fun x hx => by
      obtain ⟨j, -, rfl⟩ := List.mem_map.mp hx
      exact Fp2.canon_mul _ _),
    List.map_map, list_sum_range]
  obtain ⟨-, heq⟩ := toK_eqTableMsb U hU r hr
  rw [hrl] at heq
  rw [← sum_range_msb n (fun y => eqPoly (vecK U n r) (fun i => bit (y i)) * algebraMap GF K (W c y))]
  refine Finset.sum_congr rfl (fun j hj => ?_)
  show (((eqTableMsb r).getD j Fp2.zero).mul (wordGF (W c (msbBits n j)))).toK U = _
  rw [Fp2.toK_mul U hU, heq j (Finset.mem_range.mp hj), toK_wordGF]

end Fold

/-! ## The public tables -/

section Pubs

variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

/-- **The verifier's public tables at the W16R2 rung, from the public data `B`**: table `i` of slot `s` at the history
and the slot's draws; the lookup side's tables (`SC_LZC`, `SC_TAB`, `SC_ZS`, slots `3`, `19`, `20`) from `rest`. -/
def pubsW16 (rest : PubTabs) : PubTabs := fun s hist dr i =>
  if s = 0 ∨ s = 1 then (if i = 0 then cubeTab 14 (fun b => B.gD (splitD b)) else [])
  else if s = 4 then (if i = 0 then cubeTab 14 (fun b => B.mask (splitS b)) else [])
  else if s = 5 then (if i = 0 then foldTab 9 10 (fun c y => B.Wq c (splitHQ y)) (drSeg dr 5 10) else [])
  else if s = 6 then (if i = 0 then foldTab 9 9 (fun c y => B.Wk c (splitGD y)) (drSeg dr 0 9) else [])
  else if s = 7 then (if i = 0 then foldTab 9 9 (fun c y => B.Wv c (splitGD y)) (drSeg dr 0 9) else [])
  else if s = 10 then (if i = 0 then foldTab 10 9 (fun c y => B.Wo (splitHQ c) y) (drSeg dr 5 9) else [])
  else if s = 11 then (if i = 0 then foldTab 9 10 (fun c y => B.Wg c y) (drSeg dr 5 10) else [])
  else if s = 12 then (if i = 0 then foldTab 9 10 (fun c y => B.Wu c y) (drSeg dr 0 10) else [])
  else if s = 13 then (if i = 0 then foldTab 10 9 (fun c y => B.Wd c y) (drSeg dr 5 9) else [])
  else if s = 14 then
    (if i = 0 then cubeTab 14 (fun b => B.gamA (splitD b))
      else if i = 1 then cubeTab 14 (fun b => B.gamM (splitD b))
      else if i = 2 then cubeTab 14 (fun b => B.gD (splitD b)) else [])
  else if s = 15 then
    (if i = 0 then cubeTab 15 (fun b => B.cosT (splitQ b))
      else if i = 1 then cubeTab 15 (fun b => B.sinT (splitQ b)) else [])
  else if s = 16 then
    (if i = 0 then cubeTab 14 (fun b => B.cosK (splitK b))
      else if i = 1 then cubeTab 14 (fun b => B.sinK (splitK b)) else [])
  else if s = 17 then (if i = 0 then cubeTab 14 (fun b => B.mask (splitS b)) else [])
  else if s = 18 then
    (if i = 0 then cubeTab 15 (fun b => B.grpCol (splitF b))
      else if i = 1 then cubeTab 15 (fun b => B.gF (splitF b)) else [])
  else rest s hist dr i

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

/-- A folded table of the public tables, read in the field. -/
theorem fold_eqDr (hU : U ^ 2 = algebraMap GF K 7) (m n : ℕ) (W : (Fin m → Bool) → (Fin n → Bool) → GF)
    (dr : List Fp2) (hdr : ∀ x ∈ dr, x.Canon) (off : ℕ) (c : Fin m → Bool) :
    ((foldTab m n W (drSeg dr off n)).getD (msbIndex m c) Fp2.zero).toK U
      = ∑ y : Fin n → Bool, eqDr U dr off n y * algebraMap GF K (W c y) := by
  rw [foldTab_getD U hU m n W _ (drSeg_length dr off n) (drSeg_canon dr hdr off n) c]
  refine Finset.sum_congr rfl (fun y _ => ?_)
  unfold eqDr
  congr 2
  funext a
  show ((drSeg dr off n).getD a Fp2.zero).toK U = _
  rw [drSeg_getD]

include hU in
/-- **Deliverable 2: the concrete public tables meet `PubW16`.** -/
theorem pubW16_of (rest : PubTabs) : PubW16 U (pubsW16 Pb Lay B rest) Pb Lay B where
  ssGate s hs hist dr t c := by
    have h : pubsW16 Pb Lay B rest s hist dr 0 = cubeTab 14 (fun b => B.gD (splitD b)) := by
      unfold pubsW16; rw [ite_eq_left hs, ite_eq_left rfl]
    rw [h, cubeTab_getD, toK_wordGF, show splitD (Fin.append t c) = (t, c) from splitD_append (t, c)]
  rsMask hist dr b := by
    show ((cubeTab 14 (fun b => B.mask (splitS b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  wq hist dr hdr c := fold_eqDr U hU 9 10 (fun c y => B.Wq c (splitHQ y)) dr hdr 5 c
  wk hist dr hdr c := fold_eqDr U hU 9 9 (fun c y => B.Wk c (splitGD y)) dr hdr 0 c
  wv hist dr hdr c := fold_eqDr U hU 9 9 (fun c y => B.Wv c (splitGD y)) dr hdr 0 c
  wo hist dr hdr c := fold_eqDr U hU 10 9 (fun c y => B.Wo (splitHQ c) y) dr hdr 5 c
  wg hist dr hdr c := fold_eqDr U hU 9 10 (fun c y => B.Wg c y) dr hdr 5 c
  wu hist dr hdr c := fold_eqDr U hU 9 10 (fun c y => B.Wu c y) dr hdr 0 c
  wd hist dr hdr c := fold_eqDr U hU 10 9 (fun c y => B.Wd c y) dr hdr 5 c
  dzcGamA hist dr b := by
    show ((cubeTab 14 (fun b => B.gamA (splitD b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  dzcGamM hist dr b := by
    show ((cubeTab 14 (fun b => B.gamM (splitD b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  dzcGate hist dr b := by
    show ((cubeTab 14 (fun b => B.gD (splitD b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  qzcCos hist dr b := by
    show ((cubeTab 15 (fun b => B.cosT (splitQ b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  qzcSin hist dr b := by
    show ((cubeTab 15 (fun b => B.sinT (splitQ b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  kvCos hist dr b := by
    show ((cubeTab 14 (fun b => B.cosK (splitK b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  kvSin hist dr b := by
    show ((cubeTab 14 (fun b => B.sinK (splitK b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  szcMask hist dr b := by
    show ((cubeTab 14 (fun b => B.mask (splitS b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  fzcGrp hist dr b := by
    show ((cubeTab 15 (fun b => B.grpCol (splitF b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  fzcGate hist dr b := by
    show ((cubeTab 15 (fun b => B.gF (splitF b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]

end Pubs

end ZK60.Exec.Block.Join.W16
