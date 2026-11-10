/-
D63 lane L47 (2026-11-10), part 4 (fork C): **a pairless sum claim read in the field** (for `hhr`'s sum, finding
L44-K3), generic in the claim.

* `inRows`, `rowS`: a part's rows (`off / 2^lc … + 2^(ls − lc)`), a row's sum over the data columns;
* `zpartWeights_empty`, `zpartRow_toK`, `cwFold`, **`claimRw_empty`**, **`claimCw_empty`**,
  **`claimSem_empty`**: a claim whose parts have empty points and slices at least a row wide (`protocol::logup_sum_claim`
  in the code) is `Σ_parts coef·Σ_{rows of the part} rowS`;
* **`core_rowKey`**: at a Boolean point, a slice's row weight times its column weight, summed over the cube, is the
  indicator of the row;
* **`sum_planeZ2`**: an `H` plane's sum over its cube (`re + u·im`) is `Σ_rows (1 + u·[im]) rowS` on the same matrix.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockLookRelBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.Look

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Circuit (gP GF)

section Weights

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **A part's row indicator**: the rows `off / 2^lc … off / 2^lc + 2^(ls − lc) − 1`. -/
noncomputable def inRows (lc off ls i : ℕ) : K :=
  if off / 2 ^ lc ≤ i ∧ i < off / 2 ^ lc + 2 ^ (ls - lc) then 1 else 0

/-- **A row's sum over the data columns** (the pad columns weigh nothing). -/
noncomputable def rowS (lc R Q : ℕ) (X : Fin R → Fin (2 ^ lc + Q) → K) (i : Fin R) : K :=
  ∑ t : Fin (2 ^ lc + Q), X i t * (if (t : ℕ) < 2 ^ lc then 1 else 0)

/-- `zpart_weights` of a part with an empty point and a slice at least a row wide. -/
theorem zpartWeights_empty (q : ZK60.Exec.ZPart) (rows lc : ℕ) (hp : q.point = []) (hl : lc ≤ q.logSize) :
    zpartWeights q rows lc
      = ((List.range (2 ^ (q.logSize - lc))).foldl (fun rw j => addAt rw (q.offset / 2 ^ lc + j) q.coef)
          (List.replicate rows Fp2.zero), ⟨[], 0, 2 ^ lc⟩) := by
  unfold zpartWeights
  simp only [hp, List.isEmpty_nil, ↓reduceIte, hl]

theorem zpartW_length (q : ZK60.Exec.ZPart) (rows lc : ℕ) (hp : q.point = []) (hl : lc ≤ q.logSize) :
    (zpartWeights q rows lc).1.length = rows := by
  rw [zpartWeights_empty q rows lc hp hl]
  rw [(foldAdd_getD (fun _ => q.coef) (q.offset / 2 ^ lc) (List.replicate rows Fp2.zero) (2 ^ (q.logSize - lc)) 0).1,
    List.length_replicate]

/-- **A part's row weight in the field**: its coefficient on its rows. -/
theorem zpartRow_toK (q : ZK60.Exec.ZPart) (rows lc i : ℕ) (hp : q.point = []) (hl : lc ≤ q.logSize)
    (hc : q.coef.Canon) (hi : i < rows) :
    ((zpartWeights q rows lc).1.getD i Fp2.zero).toK U = q.coef.toK U * inRows lc q.offset q.logSize i := by
  rw [zpartWeights_empty q rows lc hp hl]
  show (((List.range (2 ^ (q.logSize - lc))).foldl (fun rw j => addAt rw (q.offset / 2 ^ lc + j) q.coef)
      (List.replicate rows Fp2.zero)).getD i Fp2.zero).toK U = _
  rw [(foldAdd_getD (fun _ => q.coef) (q.offset / 2 ^ lc) (List.replicate rows Fp2.zero) (2 ^ (q.logSize - lc)) i).2,
    List.length_replicate, getD_replicate_zero]
  unfold inRows
  by_cases h : q.offset / 2 ^ lc ≤ i ∧ i < q.offset / 2 ^ lc + 2 ^ (q.logSize - lc)
  · rw [ite_eq_left (And.intro h.1 (And.intro h.2 hi)), ite_eq_left h, Fp2.toK_add U _ _ Fp2.canon_zero hc,
      Fp2.toK_zero]
    ring
  · rw [ite_eq_right (fun h' => h (And.intro h'.1 h'.2.1)), ite_eq_right h, Fp2.toK_zero]
    ring

/-- **`claim_weights`' fold of the other parts**: lengths, canonicity and the row weights in the field. -/
theorem cwFold (rows lc : ℕ) : ∀ (ps : List ZK60.Exec.ZPart) (acc : List Fp2), acc.length = rows →
    (∀ i, (acc.getD i Fp2.zero).Canon) → (∀ q ∈ ps, q.point = [] ∧ lc ≤ q.logSize ∧ q.coef.Canon) →
      (ps.foldl (fun rw q => List.zipWith Fp2.add rw (zpartWeights q rows lc).1) acc).length = rows
      ∧ (∀ i, ((ps.foldl (fun rw q => List.zipWith Fp2.add rw (zpartWeights q rows lc).1) acc).getD i
          Fp2.zero).Canon)
      ∧ ∀ i, i < rows →
        ((ps.foldl (fun rw q => List.zipWith Fp2.add rw (zpartWeights q rows lc).1) acc).getD i Fp2.zero).toK U
          = (acc.getD i Fp2.zero).toK U + (ps.map fun q => q.coef.toK U * inRows lc q.offset q.logSize i).sum
  | [], acc, hl, hc, _ => ⟨hl, hc, fun _ _ => by simp⟩
  | q :: ps, acc, hl, hc, hq => by
    obtain ⟨hqp, hql, hqc⟩ := hq q (by simp)
    have hzl := zpartW_length q rows lc hqp hql
    have hl' : (List.zipWith Fp2.add acc (zpartWeights q rows lc).1).length = rows := by
      rw [List.length_zipWith, hl, hzl, Nat.min_self]
    have hget : ∀ i, i < rows → (List.zipWith Fp2.add acc (zpartWeights q rows lc).1).getD i Fp2.zero
        = (acc.getD i Fp2.zero).add ((zpartWeights q rows lc).1.getD i Fp2.zero) := fun i hi =>
      zipAdd_getD acc _ i (by rw [hl]; exact hi) (by rw [hzl]; exact hi)
    have hc' : ∀ i, ((List.zipWith Fp2.add acc (zpartWeights q rows lc).1).getD i Fp2.zero).Canon := by
      intro i
      by_cases hi : i < rows
      · rw [hget i hi]
        exact Fp2.canon_add _ _
      · rw [List.getD_eq_getElem?_getD, List.getElem?_eq_none (by rw [hl']; omega)]
        exact Fp2.canon_zero
    obtain ⟨h1, h2, h3⟩ := cwFold rows lc ps _ hl' hc' (fun q' hq' => hq q' (List.mem_cons_of_mem _ hq'))
    refine And.intro h1 (And.intro h2 (fun i hi => ?_))
    rw [List.foldl_cons, h3 i hi, hget i hi,
      Fp2.toK_add U _ _ (hc i) (Fp2.canon_getD (zpartWeights_canon q rows lc) i),
      zpartRow_toK U q rows lc i hqp hql hqc hi, List.map_cons, List.sum_cons]
    ring

/-- The empty-point premise on a claim's parts. -/
def EmptyParts (lc : ℕ) (z : ZClaim) : Prop := ∀ q ∈ z.parts, q.point = [] ∧ lc ≤ q.logSize ∧ q.coef.Canon

/-- **A pairless claim's row weights in the field.** -/
theorem claimRw_empty (rows lc : ℕ) (z : ZClaim) (q0 : ZPart) (qs : List ZPart) (hz : z.parts = q0 :: qs)
    (he : EmptyParts lc z) (i : Fin rows) :
    Link.claimRw U rows lc z i = (z.parts.map fun q => q.coef.toK U * inRows lc q.offset q.logSize i).sum := by
  have he0 := he q0 (by rw [hz]; simp)
  have hq0 : (toZPart q0).point = [] ∧ lc ≤ (toZPart q0).logSize ∧ (toZPart q0).coef.Canon := he0
  have hacc := zpartW_length (toZPart q0) rows lc hq0.1 hq0.2.1
  obtain ⟨-, -, h3⟩ := cwFold U rows lc (qs.map toZPart) _ hacc
    (fun i => Fp2.canon_getD (zpartWeights_canon (toZPart q0) rows lc) i)
    (fun q hq => by
      obtain ⟨q', hq', rfl⟩ := List.mem_map.mp hq
      exact he q' (by rw [hz]; exact List.mem_cons_of_mem _ hq'))
  unfold Link.claimRw
  have hcw : claimWeights (toZClaim z) rows lc
      = ((qs.map toZPart).foldl (fun rw q => List.zipWith Fp2.add rw (zpartWeights q rows lc).1)
          (zpartWeights (toZPart q0) rows lc).1, (zpartWeights (toZPart q0) rows lc).2) := by
    unfold claimWeights toZClaim
    rw [hz]
    rfl
  rw [hcw]
  show ((((qs.map toZPart).foldl (fun rw q => List.zipWith Fp2.add rw (zpartWeights q rows lc).1)
      (zpartWeights (toZPart q0) rows lc).1).getD i Fp2.zero).toK U) = _
  rw [h3 i i.isLt, zpartRow_toK U (toZPart q0) rows lc i hq0.1 hq0.2.1 hq0.2.2 i.isLt, hz, List.map_cons,
    List.sum_cons, List.map_map]
  rfl

/-- **A pairless claim's column weights in the field**: `1` on the data columns. -/
theorem claimCw_empty (rows lc Q : ℕ) (z : ZClaim) (q0 : ZPart) (qs : List ZPart) (hz : z.parts = q0 :: qs)
    (he : EmptyParts lc z) (t : Fin (2 ^ lc + Q)) :
    Link.claimCw U rows lc Q z t = if (t : ℕ) < 2 ^ lc then 1 else 0 := by
  have he0 := he q0 (by rw [hz]; simp)
  have hq0 : (toZPart q0).point = [] ∧ lc ≤ (toZPart q0).logSize ∧ (toZPart q0).coef.Canon := he0
  have hkey : (claimWeights (toZClaim z) rows lc).2 = ⟨[], 0, 2 ^ lc⟩ := by
    have e : (claimWeights (toZClaim z) rows lc).2 = (zpartWeights (toZPart q0) rows lc).2 := by
      unfold claimWeights toZClaim
      rw [hz]
      rfl
    rw [e, zpartWeights_empty (toZPart q0) rows lc hq0.1 hq0.2.1]
  unfold Link.claimCw Link.cwK
  rw [hkey]
  by_cases ht : (t : ℕ) < 2 ^ lc
  · rw [ite_eq_left ht, ite_eq_left ht, zkeyWeights_getD _ lc t ht]
    simp only [Nat.zero_le, true_and, Nat.zero_add, ht, ↓reduceIte, List.isEmpty_nil]
    exact Fp2.toK_one U
  · rw [ite_eq_right ht, ite_eq_right ht]

omit [Algebra GF K] in
/-- A list-indexed sum swapped with a row sum. -/
theorem list_rows_swap {R : ℕ} {α : Type} (a : α → K) (f : α → Fin R → K) (s : Fin R → K) :
    ∀ L : List α, ∑ i : Fin R, (L.map fun q => a q * f q i).sum * s i
      = (L.map fun q => a q * ∑ i : Fin R, f q i * s i).sum
  | [] => by simp
  | q :: L => by
    simp only [List.map_cons, List.sum_cons]
    rw [← list_rows_swap a f s L, Finset.mul_sum, ← Finset.sum_add_distrib]
    refine Finset.sum_congr rfl (fun i _ => ?_)
    ring

/-- **A pairless claim's value**: `Σ_parts coef·Σ_{rows of the part} rowS`. -/
theorem claimSem_empty (R lc Q : ℕ) (X : Fin R → Fin (2 ^ lc + Q) → K) (z : ZClaim) (q0 : ZPart) (qs : List ZPart)
    (hz : z.parts = q0 :: qs) (he : EmptyParts lc z) :
    Link.claimSem U R lc Q X z
      = (z.parts.map fun q => q.coef.toK U * ∑ i : Fin R, inRows lc q.offset q.logSize i * rowS lc R Q X i).sum := by
  unfold Link.claimSem
  have e : ∀ i : Fin R, Link.claimRw U R lc z i * ∑ t, X i t * Link.claimCw U R lc Q z t
      = (z.parts.map fun q => q.coef.toK U * inRows lc q.offset q.logSize i).sum * rowS lc R Q X i := by
    intro i
    rw [claimRw_empty U R lc z q0 qs hz he i]
    unfold rowS
    congr 1
    refine Finset.sum_congr rfl (fun t _ => ?_)
    rw [claimCw_empty U R lc Q z q0 qs hz he t]
  rw [Finset.sum_congr rfl (fun i _ => e i)]
  exact list_rows_swap (fun q => q.coef.toK U) (fun q i => inRows lc q.offset q.logSize i) (rowS lc R Q X) z.parts

end Weights

/-! ## An `H` plane's sum over its cube -/

section Plane

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- A Boolean point as `planeZ` reads it. -/
noncomputable def zcB {n : ℕ} (c : Fin n → Bool) : ℕ → K := fun a => if h : a < n then bit (c ⟨a, h⟩) else 0

omit [Algebra GF K] in
theorem zcB_left (m : ℕ) (x : Fin m → Bool) (y : Fin 14 → Bool) (a : Fin m) :
    zcB (K := K) (Fin.append x y) (a : ℕ) = bit (x a) := by
  unfold zcB
  have h : (a : ℕ) < m + 14 := by omega
  simp only [h, ↓reduceDIte]
  exact congrArg bit (Fin.append_left x y a)

omit [Algebra GF K] in
theorem zcB_right (m : ℕ) (x : Fin m → Bool) (y : Fin 14 → Bool) (a : Fin 14) :
    zcB (K := K) (Fin.append x y) (m + (a : ℕ)) = bit (y a) := by
  unfold zcB
  have h : m + (a : ℕ) < m + 14 := by omega
  simp only [h, ↓reduceDIte]
  exact congrArg bit (Fin.append_right x y a)

/-- **At the Boolean points a slice's row weight times its column weight, summed over the cube, is the row's
indicator** (a slice of `2^(m + 14)` entries on rows of `2^14`). -/
omit [Algebra GF K] in
theorem core_rowKey (m off off' i t : ℕ) :
    ∑ c : Fin (m + 14) → Bool,
        partRowK 14 off (m + 14) (fun a => if h : a < m + 14 then (bit (c ⟨a, h⟩) : K) else 0) i
          * keyColK 14 off' (m + 14) (fun a => if h : a < m + 14 then (bit (c ⟨a, h⟩) : K) else 0) t
      = inRows 14 off (m + 14) i := by
  show ∑ c : Fin (m + 14) → Bool, partRowK 14 off (m + 14) (zcB (K := K) c) i * keyColK 14 off' (m + 14) (zcB c) t
    = inRows 14 off (m + 14) i
  have e : m + 14 - 14 = m := by omega
  unfold partRowK keyColK inRows
  rw [e]
  simp only [show 14 ≤ m + 14 by omega, ↓reduceIte]
  rw [sum_append (a := m) (b := 14)]
  have hrow : ∀ (x : Fin m → Bool) (y : Fin 14 → Bool) (u : ℕ),
      eqPoly (fun a : Fin m => zcB (K := K) (Fin.append x y) (a : ℕ)) (bitsK m u)
        = if x = msbBits m u then 1 else 0 := by
    intro x y u
    have hz : (fun a : Fin m => zcB (K := K) (Fin.append x y) (a : ℕ)) = fun a => bit (x a) :=
      funext fun a => zcB_left m x y a
    rw [hz]
    exact eqPoly_bit x (msbBits m u)
  have hcol : ∀ (x : Fin m → Bool) (y : Fin 14 → Bool),
      eqPoly (fun a : Fin 14 => zcB (K := K) (Fin.append x y) (m + (a : ℕ))) (bitsK 14 t)
        = if y = msbBits 14 t then 1 else 0 := by
    intro x y
    have hz : (fun a : Fin 14 => zcB (K := K) (Fin.append x y) (m + (a : ℕ))) = fun a => bit (y a) :=
      funext fun a => zcB_right m x y a
    rw [hz]
    exact eqPoly_bit y (msbBits 14 t)
  by_cases hc : off / 2 ^ 14 ≤ i ∧ i < off / 2 ^ 14 + 2 ^ m
  · simp only [hc, and_self, ↓reduceIte, hrow, hcol]
    rw [Finset.sum_eq_single (msbBits m (i - off / 2 ^ 14))
      (fun x _ hx => by simp only [hx, ↓reduceIte, zero_mul, Finset.sum_const_zero])
      (fun h => absurd (Finset.mem_univ _) h)]
    simp
  · simp only [hc, ↓reduceIte, zero_mul, Finset.sum_const_zero]

omit [Algebra GF K] in
/-- A linear rearrangement of a cube sum. -/
theorem sum_lin2 {ι : Type} [Fintype ι] (p q k : ι → K) (a x : K) :
    ∑ c, (p c + a * q c) * (x * k c) = x * ((∑ c, p c * k c) + a * ∑ c, q c * k c) := by
  calc ∑ c, (p c + a * q c) * (x * k c) = ∑ c, (x * (p c * k c) + x * (a * (q c * k c))) :=
        Finset.sum_congr rfl (fun c _ => by ring)
    _ = x * ((∑ c, p c * k c) + a * ∑ c, q c * k c) := by
        rw [Finset.sum_add_distrib, ← Finset.mul_sum, ← Finset.mul_sum, ← Finset.mul_sum]
        ring

/-- **An `H` plane's sum over its cube** (`re + u·im`, slices at least a row wide on rows of `2^14`). -/
theorem sum_planeZ2 (logN R Q : ℕ) (hln : logN = 14) (X : Fin R → Fin (2 ^ logN + Q) → K) (cm : Cm)
    (re im log : ℕ) (hlog : 14 ≤ log) (coords : List Coord) (mr er : ℕ) :
    ∑ c : Fin log → Bool, planeZ U logN R Q X ⟨cm, [(re, Fp2.one), (im, fp2U)], log, coords, mr, er⟩ c
      = ∑ i : Fin R, (inRows logN re log i + fp2U.toK U * inRows logN im log i) * rowS logN R Q X i := by
  subst hln
  obtain ⟨m, rfl⟩ : ∃ m, log = m + 14 := ⟨log - 14, by omega⟩
  unfold planeZ privZ
  simp only [List.map_cons, List.map_nil, claimK, List.sum_cons, List.sum_nil, add_zero, Fp2.toK_one, one_mul]
  rw [Finset.sum_comm]
  refine Finset.sum_congr rfl (fun i _ => ?_)
  unfold rowS
  rw [Finset.mul_sum]
  simp only [Finset.mul_sum]
  rw [Finset.sum_comm]
  refine Finset.sum_congr rfl (fun t _ => ?_)
  by_cases ht : (t : ℕ) < 2 ^ 14
  · simp only [ht, ↓reduceIte, mul_one]
    rw [sum_lin2, core_rowKey m re re i t, core_rowKey m im re i t]
    ring
  · simp only [ht, ↓reduceIte, mul_zero, Finset.sum_const_zero]

end Plane

end ZK60.Exec.Block.Join.W16.Look
