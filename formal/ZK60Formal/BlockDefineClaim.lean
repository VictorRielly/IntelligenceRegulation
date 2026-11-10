/-
D63 lane L35 (2026-11-09), part 2: **a claim's value on a committed matrix, unfolded through L10's `zpart_weights` and
`zkey_weights`** (L31 §6 item 2: "for a private table this needs `claimSem` of `build_claim` unfolded").

L22's `claimSem` reads a claim through the code's own weight lists: `Σ_i rw_i·⟨X_i, cw⟩`, with `rw` the parts' row
weights added up (`claim_weights`) and `cw` the column weights of the FIRST part's key (`zkey_weights`). Here both
lists are read in the field, entry by entry:

* word-level entries: `addAt_getD`, `foldAdd_getD`, `zipAdd_getD`, `zpartWeights_nonempty`, **`zpartWeights_getD`**,
  **`zkeyWeights_getD`**, and that every row weight is a canonical word (`zpartWeights_canon`);
* `bitsK`, `eqMsb_toK`: an entry of `eq_table_msb(r)` is `eq(r, bits)` (L6's `toK_eqTableMsb`, at a stated length);
* `partRowK`, **`zpart_row_toK`**: a part's weight on row `i` is `coef·eq(point[..lr], bits(i − r0))` on its rows
  (`coef` on its one row when the slice is narrower than a row);
* `keyColK`, **`zkey_col_toK`**: the key's weight on column `t` is `eq(tail, bits(t − c0))` on its column range;
* `PartK`, `claimK`, `partK`, `PartOK`, **`claimSem_parts`**: for a claim whose parts have nonempty canonical points
  of their slices' lengths and canonical coefficients, `claimSem` IS `claimK` of the parts read in the field:
  `Σ_i (Σ_parts coef·rowK_i)·Σ_t X_{i,t}·colK_t`.

Generic in the commitment's geometry `(rows, log_cols, Q)`; nothing here names a profile. Only `propext`,
`Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.SlotPolyInstEval

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Exec
open ZK60.Circuit (gP GF)

/-! ## The weight lists, entry by entry (words) -/

section Words

theorem getD_replicate_zero : ∀ (n i : ℕ), (List.replicate n Fp2.zero).getD i Fp2.zero = Fp2.zero
  | 0, _ => by simp
  | n + 1, 0 => by simp [List.replicate_succ]
  | n + 1, i + 1 => by
    rw [List.replicate_succ, List.getD_cons_succ]
    exact getD_replicate_zero n i

theorem isEmpty_false_of_length {α : Type} (l : List α) (h : 0 < l.length) : l.isEmpty = false := by
  cases l with
  | nil => simp at h
  | cons a l => rfl

/-- `addAt`'s entries. -/
theorem addAt_getD : ∀ (l : List Fp2) (j : ℕ) (a : Fp2) (i : ℕ),
    (addAt l j a).getD i Fp2.zero
      = if i = j ∧ j < l.length then (l.getD i Fp2.zero).add a else l.getD i Fp2.zero
  | [], j, a, i => by simp [addAt]
  | x :: l, 0, a, 0 => by simp [addAt]
  | x :: l, 0, a, i + 1 => by simp [addAt]
  | x :: l, j + 1, a, 0 => by simp [addAt]
  | x :: l, j + 1, a, i + 1 => by
    simp only [addAt, List.getD_cons_succ, List.length_cons]
    rw [addAt_getD l j a i]
    by_cases h : i = j ∧ j < l.length
    · have h' : i + 1 = j + 1 ∧ j + 1 < l.length + 1 := And.intro (by omega) (by omega)
      exact (ite_eq_left h).trans (ite_eq_left h').symm
    · have h' : ¬ (i + 1 = j + 1 ∧ j + 1 < l.length + 1) := fun h2 => h (And.intro (by omega) (by omega))
      exact (ite_eq_right h).trans (ite_eq_right h').symm

theorem addAt_canon : ∀ (l : List Fp2) (j : ℕ) (a : Fp2), (∀ b ∈ l, b.Canon) → ∀ b ∈ addAt l j a, b.Canon
  | [], _, _, _, b, hb => by simp [addAt] at hb
  | x :: l, 0, a, h, b, hb => by
    simp only [addAt, List.mem_cons] at hb
    rcases hb with hb | hb
    · rw [hb]
      exact Fp2.canon_add _ _
    · exact h b (List.mem_cons_of_mem x hb)
  | x :: l, j + 1, a, h, b, hb => by
    simp only [addAt, List.mem_cons] at hb
    rcases hb with hb | hb
    · rw [hb]
      exact h x List.mem_cons_self
    · exact addAt_canon l j a (fun c hc => h c (List.mem_cons_of_mem x hc)) b hb

theorem foldAddAt_canon (f : ℕ → ℕ) (g : ℕ → Fp2) : ∀ (js : List ℕ) (rw0 : List Fp2), (∀ b ∈ rw0, b.Canon) →
    ∀ b ∈ js.foldl (fun rw j => addAt rw (f j) (g j)) rw0, b.Canon
  | [], _, h => h
  | j :: js, rw0, h => by
    rw [List.foldl_cons]
    exact foldAddAt_canon f g js _ (addAt_canon rw0 (f j) (g j) h)

/-- **`zpart_weights`' fold**: after `m` steps, row `r0 + j` (`j < m`, inside the list) has gained `g j`. -/
theorem foldAdd_getD (g : ℕ → Fp2) (r0 : ℕ) (rw0 : List Fp2) : ∀ (m i : ℕ),
    ((List.range m).foldl (fun rw j => addAt rw (r0 + j) (g j)) rw0).length = rw0.length ∧
    ((List.range m).foldl (fun rw j => addAt rw (r0 + j) (g j)) rw0).getD i Fp2.zero
      = if r0 ≤ i ∧ i < r0 + m ∧ i < rw0.length then (rw0.getD i Fp2.zero).add (g (i - r0))
        else rw0.getD i Fp2.zero
  | 0, i => by
    have hn : ¬ (r0 ≤ i ∧ i < r0 + 0 ∧ i < rw0.length) := fun h => by omega
    rw [List.range_zero, List.foldl_nil]
    exact And.intro rfl (ite_eq_right hn).symm
  | m + 1, i => by
    obtain ⟨hl, hg⟩ := foldAdd_getD g r0 rw0 m i
    rw [List.range_succ, List.foldl_append, List.foldl_cons, List.foldl_nil]
    refine And.intro (by rw [Link.addAt_length, hl]) ?_
    rw [addAt_getD, hl, hg]
    by_cases h1 : i = r0 + m ∧ r0 + m < rw0.length
    · have hn : ¬ (r0 ≤ i ∧ i < r0 + m ∧ i < rw0.length) := fun h => by omega
      have hp : r0 ≤ i ∧ i < r0 + (m + 1) ∧ i < rw0.length := And.intro (by omega) (And.intro (by omega) (by omega))
      have e : i - r0 = m := by omega
      rw [ite_eq_left h1, ite_eq_right hn, ite_eq_left hp, e]
    · rw [ite_eq_right h1]
      by_cases h2 : r0 ≤ i ∧ i < r0 + m ∧ i < rw0.length
      · have hp : r0 ≤ i ∧ i < r0 + (m + 1) ∧ i < rw0.length :=
          And.intro h2.1 (And.intro (by omega) h2.2.2)
        exact (ite_eq_left h2).trans (ite_eq_left hp).symm
      · have hn : ¬ (r0 ≤ i ∧ i < r0 + (m + 1) ∧ i < rw0.length) := fun h => by
          have h3 : i = r0 + m := by omega
          exact h1 (And.intro h3 (by omega))
        exact (ite_eq_right h2).trans (ite_eq_right hn).symm

theorem zipAdd_getD : ∀ (l l' : List Fp2) (i : ℕ), i < l.length → i < l'.length →
    (List.zipWith Fp2.add l l').getD i Fp2.zero = (l.getD i Fp2.zero).add (l'.getD i Fp2.zero)
  | [], _, _, h, _ => absurd h (by simp)
  | _ :: _, [], _, _, h => absurd h (by simp)
  | a :: l, b :: l', 0, _, _ => by simp
  | a :: l, b :: l', i + 1, h, h' => by
    simp only [List.zipWith_cons_cons, List.getD_cons_succ]
    exact zipAdd_getD l l' i (by simpa using h) (by simpa using h')

/-- Every row weight of a part is a canonical word. -/
theorem zpartWeights_canon (q : ZK60.Exec.ZPart) (rows logN : ℕ) : ∀ b ∈ (zpartWeights q rows logN).1, b.Canon := by
  have h0 : ∀ b ∈ List.replicate rows Fp2.zero, b.Canon := fun b hb => by
    rw [List.eq_of_mem_replicate hb]
    exact Fp2.canon_zero
  unfold zpartWeights
  simp only
  split_ifs
  · exact foldAddAt_canon (fun i => q.offset / 2 ^ logN + i) (fun _ => q.coef) _ _ h0
  · exact addAt_canon _ _ _ h0
  · exact foldAddAt_canon (fun i => q.offset / 2 ^ logN + i)
      (fun i => q.coef.mul ((eqTableMsb (q.point.take (q.logSize - logN))).getD i Fp2.zero)) _ _ h0
  · exact addAt_canon _ _ _ h0

/-- `zpart_weights` of a part with a point (the `MLE` branch). -/
theorem zpartWeights_nonempty (q : ZK60.Exec.ZPart) (rows logN : ℕ) (hq : q.point.isEmpty = false) :
    zpartWeights q rows logN
      = if logN ≤ q.logSize then
          ((List.range (eqTableMsb (q.point.take (q.logSize - logN))).length).foldl
            (fun rw j => addAt rw (q.offset / 2 ^ logN + j)
              (q.coef.mul ((eqTableMsb (q.point.take (q.logSize - logN))).getD j Fp2.zero)))
            (List.replicate rows Fp2.zero), ⟨q.point.drop (q.logSize - logN), 0, 2 ^ logN⟩)
        else (addAt (List.replicate rows Fp2.zero) (q.offset / 2 ^ logN) q.coef,
          ⟨q.point, q.offset % 2 ^ logN, 2 ^ q.logSize⟩) := by
  unfold zpartWeights
  simp only [hq, Bool.false_eq_true, ite_false]

/-- **A part's weight on row `i`** (words). -/
theorem zpartWeights_getD (q : ZK60.Exec.ZPart) (rows logN : ℕ) (hq : q.point.isEmpty = false) (i : ℕ)
    (hi : i < rows) :
    (zpartWeights q rows logN).1.getD i Fp2.zero
      = if logN ≤ q.logSize then
          (if q.offset / 2 ^ logN ≤ i
              ∧ i < q.offset / 2 ^ logN + (eqTableMsb (q.point.take (q.logSize - logN))).length then
            Fp2.zero.add (q.coef.mul ((eqTableMsb (q.point.take (q.logSize - logN))).getD (i - q.offset / 2 ^ logN)
              Fp2.zero))
          else Fp2.zero)
        else (if i = q.offset / 2 ^ logN then Fp2.zero.add q.coef else Fp2.zero) := by
  rw [zpartWeights_nonempty q rows logN hq]
  by_cases h : logN ≤ q.logSize
  · rw [ite_eq_left h, ite_eq_left h]
    show ((List.range (eqTableMsb (q.point.take (q.logSize - logN))).length).foldl
        (fun rw j => addAt rw (q.offset / 2 ^ logN + j)
          (q.coef.mul ((eqTableMsb (q.point.take (q.logSize - logN))).getD j Fp2.zero)))
        (List.replicate rows Fp2.zero)).getD i Fp2.zero = _
    rw [(foldAdd_getD (fun j => q.coef.mul ((eqTableMsb (q.point.take (q.logSize - logN))).getD j Fp2.zero))
      (q.offset / 2 ^ logN) (List.replicate rows Fp2.zero)
      (eqTableMsb (q.point.take (q.logSize - logN))).length i).2, List.length_replicate, getD_replicate_zero]
    by_cases h2 : q.offset / 2 ^ logN ≤ i
        ∧ i < q.offset / 2 ^ logN + (eqTableMsb (q.point.take (q.logSize - logN))).length
    · exact (ite_eq_left (And.intro h2.1 (And.intro h2.2 hi))).trans (ite_eq_left h2).symm
    · exact (ite_eq_right (fun h3 => h2 (And.intro h3.1 h3.2.1))).trans (ite_eq_right h2).symm
  · rw [ite_eq_right h, ite_eq_right h]
    show (addAt (List.replicate rows Fp2.zero) (q.offset / 2 ^ logN) q.coef).getD i Fp2.zero = _
    rw [addAt_getD, List.length_replicate, getD_replicate_zero]
    by_cases h2 : i = q.offset / 2 ^ logN
    · have h3 : q.offset / 2 ^ logN < rows := by
        rw [← h2]
        exact hi
      exact (ite_eq_left (And.intro h2 h3)).trans (ite_eq_left h2).symm
    · exact (ite_eq_right (fun h3 => h2 h3.1)).trans (ite_eq_right h2).symm

/-- **A key's weight on column `t`** (words). -/
theorem zkeyWeights_getD (k : ZKey) (logN t : ℕ) (ht : t < 2 ^ logN) :
    (zkeyWeights k logN).getD t Fp2.zero
      = if k.c0 ≤ t ∧ t < k.c0 + k.len then
          (if k.tail.isEmpty then Fp2.one else (eqTableMsb k.tail).getD (t - k.c0) Fp2.zero)
        else Fp2.zero := by
  show ((List.range (2 ^ logN)).map (fun c =>
      if k.c0 ≤ c ∧ c < k.c0 + k.len then
        (if k.tail.isEmpty then Fp2.one else (eqTableMsb k.tail).getD (c - k.c0) Fp2.zero)
      else Fp2.zero)).getD t Fp2.zero = _
  rw [getD_map_lt (List.range (2 ^ logN)) _ 0 Fp2.zero t (by rw [List.length_range]; exact ht), range_getD t _ ht]

/-- The row weights of a parts list, added up: entry `i` in the field. -/
theorem foldZip_toK {K : Type} [Field K] [Algebra GF K] (U : K) (rows logN i : ℕ) (hi : i < rows) :
    ∀ (qs : List ZK60.Exec.ZPart) (w0 : List Fp2), w0.length = rows → (w0.getD i Fp2.zero).Canon →
    ((qs.foldl (fun rw q => List.zipWith Fp2.add rw (zpartWeights q rows logN).1) w0).getD i Fp2.zero).toK U
      = (w0.getD i Fp2.zero).toK U
        + (qs.map fun q => ((zpartWeights q rows logN).1.getD i Fp2.zero).toK U).sum
  | [], w0, _, _ => by simp
  | q :: qs, w0, hl, hc => by
    have hW := Link.zpartWeights_length q rows logN
    have hz := zipAdd_getD w0 (zpartWeights q rows logN).1 i (by rw [hl]; exact hi) (by rw [hW]; exact hi)
    have hl' : (List.zipWith Fp2.add w0 (zpartWeights q rows logN).1).length = rows := by
      simp [List.length_zipWith, hl, hW]
    have hc' : ((List.zipWith Fp2.add w0 (zpartWeights q rows logN).1).getD i Fp2.zero).Canon := by
      rw [hz]
      exact Fp2.canon_add _ _
    rw [List.foldl_cons, foldZip_toK U rows logN i hi qs _ hl' hc', hz,
      Fp2.toK_add U _ _ hc (Fp2.canon_getD (zpartWeights_canon q rows logN) i), List.map_cons, List.sum_cons,
      add_assoc]

end Words

/-! ## The entries in the field -/

section K

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- The bits of an index, most significant first, as field elements (`eq_table_msb`'s order). -/
def bitsK (m idx : ℕ) : Fin m → K := fun j => bit (msbBits m idx j)

/-- **An entry of `eq_table_msb(r)`** for a canonical `r` of length `m`: `eq(r, bits(idx))`. -/
theorem eqMsb_toK (hU : U ^ 2 = algebraMap GF K 7) (r : List Fp2) (m : ℕ) (hm : r.length = m)
    (hr : ∀ a ∈ r, a.Canon) :
    (eqTableMsb r).length = 2 ^ m ∧ ∀ idx, idx < 2 ^ m →
      ((eqTableMsb r).getD idx Fp2.zero).toK U
        = eqPoly (fun a : Fin m => (r.getD a Fp2.zero).toK U) (bitsK m idx) := by
  subst hm
  exact toK_eqTableMsb U hU r hr

/-- **A part's weight on row `i`, per unit coefficient**: `eq(point[..lr], bits(i − r0))` on its `2^lr` rows from
`r0 = off / 2^logN` when the slice is at least a row wide (`lr = ls − logN`), else `1` on its one row. -/
def partRowK (logN off ls : ℕ) (pt : ℕ → K) (i : ℕ) : K :=
  if logN ≤ ls then
    (if off / 2 ^ logN ≤ i ∧ i < off / 2 ^ logN + 2 ^ (ls - logN) then
      eqPoly (fun a : Fin (ls - logN) => pt a) (bitsK (ls - logN) (i - off / 2 ^ logN))
    else 0)
  else (if i = off / 2 ^ logN then 1 else 0)

/-- **A key's weight on column `t`**: `eq(point[lr..], bits(t))` on a full row when the slice is at least a row
wide, else `eq(point, bits(t − c0))` on the columns `[c0, c0 + 2^ls)`, `c0 = off mod 2^logN`. -/
def keyColK (logN off ls : ℕ) (pt : ℕ → K) (t : ℕ) : K :=
  if logN ≤ ls then eqPoly (fun a : Fin logN => pt (ls - logN + a)) (bitsK logN t)
  else if off % 2 ^ logN ≤ t ∧ t < off % 2 ^ logN + 2 ^ ls then
    eqPoly (fun a : Fin ls => pt a) (bitsK ls (t - off % 2 ^ logN))
  else 0

/-- **A part's row weight, in the field.** -/
theorem zpart_row_toK (hU : U ^ 2 = algebraMap GF K 7) (q : ZK60.Exec.ZPart) (rows logN : ℕ)
    (hq : q.point.isEmpty = false) (hlen : q.logSize - logN ≤ q.point.length) (hpc : ∀ a ∈ q.point, a.Canon)
    (hcc : q.coef.Canon) (i : ℕ) (hi : i < rows) :
    ((zpartWeights q rows logN).1.getD i Fp2.zero).toK U
      = q.coef.toK U * partRowK logN q.offset q.logSize (fun a => (q.point.getD a Fp2.zero).toK U) i := by
  have htk : ∀ a ∈ q.point.take (q.logSize - logN), a.Canon := fun a ha => hpc a (List.mem_of_mem_take ha)
  have hlt : (q.point.take (q.logSize - logN)).length = q.logSize - logN := by
    rw [List.length_take]
    exact Nat.min_eq_left hlen
  obtain ⟨hlenE, hE⟩ := eqMsb_toK U hU (q.point.take (q.logSize - logN)) (q.logSize - logN) hlt htk
  have e : (fun a : Fin (q.logSize - logN) => ((q.point.take (q.logSize - logN)).getD a Fp2.zero).toK U)
      = fun a : Fin (q.logSize - logN) => (q.point.getD a Fp2.zero).toK U := by
    funext a
    rw [getD_take_lt q.point (q.logSize - logN) a a.isLt Fp2.zero]
  rw [zpartWeights_getD q rows logN hq i hi]
  unfold partRowK
  by_cases h : logN ≤ q.logSize
  · rw [ite_eq_left h, ite_eq_left h, hlenE]
    by_cases h2 : q.offset / 2 ^ logN ≤ i ∧ i < q.offset / 2 ^ logN + 2 ^ (q.logSize - logN)
    · have h3 : i - q.offset / 2 ^ logN < 2 ^ (q.logSize - logN) := by omega
      rw [ite_eq_left h2, ite_eq_left h2, Fp2.toK_add U _ _ Fp2.canon_zero (Fp2.canon_mul _ _), Fp2.toK_zero, zero_add,
        Fp2.toK_mul U hU, hE (i - q.offset / 2 ^ logN) h3, e]
    · rw [ite_eq_right h2, ite_eq_right h2, Fp2.toK_zero, mul_zero]
  · rw [ite_eq_right h, ite_eq_right h]
    by_cases h2 : i = q.offset / 2 ^ logN
    · rw [ite_eq_left h2, ite_eq_left h2, Fp2.toK_add U _ _ Fp2.canon_zero hcc, Fp2.toK_zero, zero_add, mul_one]
    · rw [ite_eq_right h2, ite_eq_right h2, Fp2.toK_zero, mul_zero]

/-- **The first part's key, column `t`, in the field.** -/
theorem zkey_col_toK (hU : U ^ 2 = algebraMap GF K 7) (q : ZK60.Exec.ZPart) (rows logN : ℕ) (hq : q.point.isEmpty = false)
    (hN : 0 < logN) (hlen : q.point.length = q.logSize) (hpc : ∀ a ∈ q.point, a.Canon) (t : ℕ)
    (ht : t < 2 ^ logN) :
    ((zkeyWeights (zpartWeights q rows logN).2 logN).getD t Fp2.zero).toK U
      = keyColK logN q.offset q.logSize (fun a => (q.point.getD a Fp2.zero).toK U) t := by
  rw [zkeyWeights_getD _ logN t ht, zpartWeights_nonempty q rows logN hq]
  unfold keyColK
  by_cases h : logN ≤ q.logSize
  · rw [ite_eq_left h, ite_eq_left h]
    show (if (0 : ℕ) ≤ t ∧ t < 0 + 2 ^ logN then
        (if (q.point.drop (q.logSize - logN)).isEmpty then Fp2.one
          else (eqTableMsb (q.point.drop (q.logSize - logN))).getD (t - 0) Fp2.zero)
      else Fp2.zero).toK U = _
    have hdl : (q.point.drop (q.logSize - logN)).length = logN := by
      rw [List.length_drop, hlen]
      omega
    have hne : ¬ ((q.point.drop (q.logSize - logN)).isEmpty = true) := by
      rw [isEmpty_false_of_length (q.point.drop (q.logSize - logN)) (by rw [hdl]; exact hN)]
      exact Bool.false_ne_true
    obtain ⟨-, hE⟩ := eqMsb_toK U hU (q.point.drop (q.logSize - logN)) logN hdl
      (fun a ha => hpc a (List.mem_of_mem_drop ha))
    have e : (fun a : Fin logN => ((q.point.drop (q.logSize - logN)).getD a Fp2.zero).toK U)
        = fun a : Fin logN => (q.point.getD (q.logSize - logN + a) Fp2.zero).toK U := by
      funext a
      rw [getD_drop]
    have hc : (0 : ℕ) ≤ t ∧ t < 0 + 2 ^ logN := And.intro (Nat.zero_le t) (by omega)
    rw [ite_eq_left hc, ite_eq_right hne, Nat.sub_zero, hE t ht, e]
  · rw [ite_eq_right h, ite_eq_right h]
    show (if q.offset % 2 ^ logN ≤ t ∧ t < q.offset % 2 ^ logN + 2 ^ q.logSize then
        (if q.point.isEmpty then Fp2.one else (eqTableMsb q.point).getD (t - q.offset % 2 ^ logN) Fp2.zero)
      else Fp2.zero).toK U = _
    obtain ⟨-, hE⟩ := eqMsb_toK U hU q.point q.logSize hlen hpc
    have hne : ¬ (q.point.isEmpty = true) := by
      rw [hq]
      exact Bool.false_ne_true
    by_cases h2 : q.offset % 2 ^ logN ≤ t ∧ t < q.offset % 2 ^ logN + 2 ^ q.logSize
    · have h3 : t - q.offset % 2 ^ logN < 2 ^ q.logSize := by omega
      rw [ite_eq_left h2, ite_eq_left h2, ite_eq_right hne, hE (t - q.offset % 2 ^ logN) h3]
    · rw [ite_eq_right h2, ite_eq_right h2, Fp2.toK_zero]

/-! ## A claim in the field -/

/-- A claim part read in the field: its slice's offset and log size, its coefficient, its point by position. -/
structure PartK (K : Type) where
  off : ℕ
  ls : ℕ
  coef : K
  pt : ℕ → K

/-- **A claim's value on a matrix `X`** (`rows × (2^logN + Q)`, the pads weighing nothing), from its parts read in
the field: `Σ_i (Σ_parts coef·rowK_i)·Σ_t X_{i,t}·colK_t`, the columns' weights the FIRST part's key's (the code
asserts the parts share it). -/
def claimK (logN R Q : ℕ) (X : Fin R → Fin (2 ^ logN + Q) → K) : List (PartK K) → K
  | [] => 0
  | b0 :: bs =>
    ∑ i : Fin R, ((b0 :: bs).map fun b => b.coef * partRowK logN b.off b.ls b.pt i).sum
      * ∑ t : Fin (2 ^ logN + Q), X i t * (if (t : ℕ) < 2 ^ logN then keyColK logN b0.off b0.ls b0.pt t else 0)

/-- A code part read in the field. -/
def partK (b : ZPart) : PartK K := ⟨b.offset, b.logSize, b.coef.toK U, fun a => (b.point.getD a Fp2.zero).toK U⟩

/-- What the unfolding needs of a part: a nonempty canonical point of its slice's length, a canonical coefficient. -/
def PartOK (b : ZPart) : Prop :=
  0 < b.logSize ∧ b.point.length = b.logSize ∧ (∀ a ∈ b.point, a.Canon) ∧ b.coef.Canon

/-- **`claimSem`, unfolded**: the claim's value on `X` is `claimK` of its parts read in the field. -/
theorem claimSem_parts (hU : U ^ 2 = algebraMap GF K 7) (R logN Q : ℕ) (X : Fin R → Fin (2 ^ logN + Q) → K)
    (hN : 0 < logN) (z : ZClaim) (b0 : ZPart) (bs : List ZPart) (hz : z.parts = b0 :: bs)
    (hok : ∀ b ∈ z.parts, PartOK b) :
    Link.claimSem U R logN Q X z = claimK logN R Q X (z.parts.map (partK U)) := by
  have hok0 : PartOK b0 := hok b0 (by rw [hz]; exact List.mem_cons_self)
  have hoks : ∀ b ∈ bs, PartOK b := fun b hb => hok b (by rw [hz]; exact List.mem_cons_of_mem b0 hb)
  have hne : ∀ b : ZPart, PartOK b → (toZPart b).point.isEmpty = false := fun b hb =>
    isEmpty_false_of_length b.point (by rw [hb.2.1]; exact hb.1)
  have hcw : claimWeights (toZClaim z) R logN
      = ((bs.map toZPart).foldl (fun rw q => List.zipWith Fp2.add rw (zpartWeights q R logN).1)
          (zpartWeights (toZPart b0) R logN).1, (zpartWeights (toZPart b0) R logN).2) := by
    unfold toZClaim
    rw [hz]
    rfl
  have hrow : ∀ (b : ZPart), PartOK b → ∀ i, i < R →
      ((zpartWeights (toZPart b) R logN).1.getD i Fp2.zero).toK U
        = (partK U b).coef * partRowK logN (partK U b).off (partK U b).ls (partK U b).pt i := fun b hb i hi =>
    zpart_row_toK U hU (toZPart b) R logN (hne b hb)
      (by
        show b.logSize - logN ≤ b.point.length
        rw [hb.2.1]
        exact Nat.sub_le _ _) hb.2.2.1 hb.2.2.2 i hi
  unfold Link.claimSem
  rw [hz]
  show _ = ∑ i : Fin R, ((partK U b0 :: bs.map (partK U)).map
      fun b => b.coef * partRowK logN b.off b.ls b.pt i).sum
    * ∑ t : Fin (2 ^ logN + Q), X i t
      * (if (t : ℕ) < 2 ^ logN then keyColK logN (partK U b0).off (partK U b0).ls (partK U b0).pt t else 0)
  refine Finset.sum_congr rfl (fun i _ => ?_)
  have hrw : Link.claimRw U R logN z i
      = ((partK U b0 :: bs.map (partK U)).map fun b => b.coef * partRowK logN b.off b.ls b.pt i).sum := by
    unfold Link.claimRw
    rw [hcw]
    show ((((bs.map toZPart).foldl (fun rw q => List.zipWith Fp2.add rw (zpartWeights q R logN).1)
      (zpartWeights (toZPart b0) R logN).1).getD i Fp2.zero).toK U) = _
    rw [foldZip_toK U R logN i i.isLt (bs.map toZPart) _ (Link.zpartWeights_length _ R logN)
      (Fp2.canon_getD (zpartWeights_canon (toZPart b0) R logN) i), hrow b0 hok0 i i.isLt, List.map_cons,
      List.sum_cons, List.map_map, List.map_map]
    exact congrArg (fun s => (partK U b0).coef * partRowK logN (partK U b0).off (partK U b0).ls (partK U b0).pt i + s)
      (congrArg List.sum (List.map_congr_left (fun b hb => hrow b (hoks b hb) i i.isLt)))
  have hcol : ∀ t : Fin (2 ^ logN + Q), Link.claimCw U R logN Q z t
      = if (t : ℕ) < 2 ^ logN then keyColK logN (partK U b0).off (partK U b0).ls (partK U b0).pt t else 0 := by
    intro t
    unfold Link.claimCw Link.cwK
    rw [hcw]
    by_cases ht : (t : ℕ) < 2 ^ logN
    · rw [ite_eq_left ht, ite_eq_left ht]
      exact zkey_col_toK U hU (toZPart b0) R logN (hne b0 hok0) hN hok0.2.1 hok0.2.2.1 t ht
    · rw [ite_eq_right ht, ite_eq_right ht]
  rw [hrw]
  exact congrArg (fun s => ((partK U b0 :: bs.map (partK U)).map
      fun b => b.coef * partRowK logN b.off b.ls b.pt i).sum * s)
    (Finset.sum_congr rfl (fun t _ => by rw [hcol t]))

end K

end ZK60.Exec.Block
