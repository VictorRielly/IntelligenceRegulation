/-
D63 lane L28 (2026-11-07), part 1: **the regular opening's field link** (L22 §5 item 1: the `A` / `H` analogue of
`maskOk_mFinal`).

L10's executable opening verifier accepts exactly when `PcsOk` holds (`pcsVerify_ok_iff`). L20's chain theorem for an
opening reads the opening's checks as `SoundGroups.lean`'s `GroupsAccept` of the `OClaims` the sub-protocols state
(L22's `oclOf`, indexed by DRAW position, L22-3), at the `(λ, ρ)` and the indices the run's digests give. Here:

* `toK_of_isZero`, `toK_dotF`, `sum_zip_range'`: the code's arithmetic in `K`;
* `addAt_length`, `zpartWeights_length`, **`claimWeights_length`**, `groupZclaims_rw_length`, `groupZclaims_cw_length`:
  every row-weight list has `rows` entries, every column-weight list `2^logCols`;
* `memsFrom_grp`, **`sum_memsFrom`**: a sum over the draw positions with a group's indicator is the sum over the group's
  members (`group_zclaims`' first-occurrence groups, drawn group by group);
* `rhoAdd_getD`, `foldl_groupComb`, **`groupComb_K`**: one group's combination `Σ_j λ_j·rw_j` and want `Σ_j λ_j·v_j`;
* **`zkRhosAux_K`**: `zk_rhos`' combinations and wants in `K` are the sums of the run's `λ`s against the members, the
  proximity weights the run's last `rows` digests;
* **`groupWeights_oclOf`**, **`groupWant_oclOf`**: the same as `SoundGroups.lean`'s `groupWeights` / `groupWant` of
  `oclOf` at `λ_p = challenge_fp2(ds_p)`;
* **`pcsOk_groupsAccept`**: `PcsOk` (any parameters, any column evaluator meeting `ColEncSpec`), with the matrix
  agreeing with the opened columns at the sampled indices, is `GroupsAccept` of `oclOf` for the encoder `encLin` at
  the run's `(λ, ρ)` and indices;
* `lrCode_sqDs`: the `(λ, ρ)` vector is `FSOpening.lean`'s `lrCode` of the run's digests (`lrCode_prob_le` gives its
  bias).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.LinkW16Sem
import ZK60Formal.LinkW16MaskChain

set_option autoImplicit false

namespace ZK60.Exec.Link

open ZK60.Sound
open ZK60.Exec
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## The code's arithmetic in `K` -/

section Arith

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem toK_of_isZero (a : Fp2) (h : a.isZero = true) : a.toK U = 0 := by
  simp only [Fp2.isZero, Bool.and_eq_true, beq_iff_eq] at h
  simp [Fp2.toK, ZK60.Hiding.fp2, Fp.toGF, h.1, h.2]

omit [Algebra GF K] in
theorem sum_zip_range' {α β : Type} (a0 : α) (b0 : β) (f : α → β → K) : ∀ (v : List α) (w : List β),
    w.length = v.length →
    ((v.zip w).map (fun p => f p.1 p.2)).sum = ∑ i ∈ Finset.range v.length, f (v.getD i a0) (w.getD i b0)
  | [], _, _ => by simp
  | a :: v, [], h => by simp at h
  | a :: v, b :: w, h => by
    rw [List.zip_cons_cons, List.map_cons, List.sum_cons, sum_zip_range' a0 b0 f v w (by simpa using h),
      List.length_cons, Finset.sum_range_succ']
    simp only [List.getD_cons_succ, List.getD_cons_zero]
    ring

variable (hU : U ^ 2 = algebraMap GF K 7)

include hU in
theorem foldl_dotF (l : List (Fp2 × Fp2)) : ∀ acc : Fp2, acc.Canon →
    (l.foldl (fun a p => a.add (p.1.mul p.2)) acc).toK U = acc.toK U + (l.map (fun p => p.1.toK U * p.2.toK U)).sum := by
  induction l with
  | nil => intro acc _; simp
  | cons p l ih =>
    intro acc hacc
    rw [List.foldl_cons, ih _ (Fp2.canon_add _ _), Fp2.toK_add U _ _ hacc (Fp2.canon_mul _ _), Fp2.toK_mul U hU,
      List.map_cons, List.sum_cons]
    ring

include hU in
/-- **The claim check's dot product is the field's**: `Σ_{t < m} v_t·c_t`. -/
theorem toK_dotF (v c : List Fp2) (m : ℕ) (hv : v.length = m) (hc : c.length = m) :
    (dotF v c).toK U = ∑ t ∈ Finset.range m, (v.getD t Fp2.zero).toK U * (c.getD t Fp2.zero).toK U := by
  subst hv
  unfold dotF
  rw [foldl_dotF U hU _ _ Fp2.canon_zero, Fp2.toK_zero, zero_add,
    sum_zip_range' Fp2.zero Fp2.zero (fun a b => a.toK U * b.toK U) v c hc]

end Arith

/-! ## The weights' lengths -/

section Lengths

theorem addAt_length : ∀ (l : List Fp2) (i : ℕ) (a : Fp2), (addAt l i a).length = l.length
  | [], _, _ => rfl
  | x :: l, 0, a => rfl
  | x :: l, i + 1, a => by simp [addAt, addAt_length l i a]

theorem foldl_addAt_length (f : ℕ → ℕ) (g : ℕ → Fp2) : ∀ (is : List ℕ) (l : List Fp2),
    (is.foldl (fun rw i => addAt rw (f i) (g i)) l).length = l.length
  | [], _ => rfl
  | i :: is, l => by rw [List.foldl_cons, foldl_addAt_length f g is, addAt_length]

theorem zpartWeights_length (p : ZPart) (rows logCols : ℕ) : (zpartWeights p rows logCols).1.length = rows := by
  unfold zpartWeights
  simp only
  split_ifs
  · rw [foldl_addAt_length (fun i => p.offset / 2 ^ logCols + i) (fun _ => p.coef), List.length_replicate]
  · rw [addAt_length, List.length_replicate]
  · rw [foldl_addAt_length (fun i => p.offset / 2 ^ logCols + i)
      (fun i => p.coef.mul ((eqTableMsb (p.point.take (p.logSize - logCols))).getD i Fp2.zero)), List.length_replicate]
  · rw [addAt_length, List.length_replicate]

theorem foldl_zipWith_length (rows logCols : ℕ) : ∀ (ps : List ZPart) (l : List Fp2), l.length = rows →
    (ps.foldl (fun rw q => List.zipWith Fp2.add rw (zpartWeights q rows logCols).1) l).length = rows
  | [], _, h => h
  | q :: ps, l, h => by
    rw [List.foldl_cons]
    refine foldl_zipWith_length rows logCols ps _ ?_
    rw [List.length_zipWith, h, zpartWeights_length, min_self]

/-- **A claim's row weights have `rows` entries.** -/
theorem claimWeights_length (c : ZClaim) (rows logCols : ℕ) : (claimWeights c rows logCols).1.length = rows := by
  unfold claimWeights
  split
  · exact List.length_replicate
  · exact foldl_zipWith_length rows logCols _ _ (zpartWeights_length _ rows logCols)

theorem zkeyWeights_length (k : ZKey) (logCols : ℕ) : (zkeyWeights k logCols).length = 2 ^ logCols := by
  simp [zkeyWeights]

/-- The fold's invariant for the lengths: every member's row weights `rows` long, every group's column weights
`2^logCols` long. -/
def LInv (rows logCols : ℕ) (st : List ZKey × List (List Fp2 × List (List Fp2 × Fp2))) : Prop :=
  ∀ g, g < st.2.length → ((st.2.getD g ([], [])).1.length = 2 ^ logCols
    ∧ ∀ m ∈ (st.2.getD g ([], [])).2, m.1.length = rows)

theorem lInv_step (rows logCols : ℕ) (st : List ZKey × List (List Fp2 × List (List Fp2 × Fp2))) (c : ZClaim)
    (h : LInv rows logCols st) : LInv rows logCols (groupStep rows logCols st c) := by
  rcases hk : keyIdx st.1 (claimWeights c rows logCols).2 with _ | gi
  · have e : groupStep rows logCols st c = (st.1 ++ [(claimWeights c rows logCols).2],
        st.2 ++ [(zkeyWeights (claimWeights c rows logCols).2 logCols,
          [((claimWeights c rows logCols).1, c.value)])]) := by
      simp only [groupStep, hk]
    rw [e]
    intro g hg
    dsimp only at hg ⊢
    simp only [List.length_append, List.length_singleton] at hg
    by_cases hg' : g < st.2.length
    · rw [getD_append' _ _ _ _ hg']
      exact h g hg'
    · rw [getD_append_right' _ _ _ _ (by omega), show g - st.2.length = 0 by omega]
      refine ⟨zkeyWeights_length _ _, fun m hm => ?_⟩
      simp only [List.getD_cons_zero, List.mem_singleton] at hm
      subst hm
      exact claimWeights_length c rows logCols
  · have e : groupStep rows logCols st c = (st.1, pushAt st.2 gi ((claimWeights c rows logCols).1, c.value)) := by
      simp only [groupStep, hk]
    rw [e]
    intro g hg
    dsimp only at hg ⊢
    simp only [pushAt_length] at hg
    simp only [pushAt_getD]
    split_ifs
    · refine ⟨(h g hg).1, fun m hm => ?_⟩
      rcases List.mem_append.mp hm with hm | hm
      · exact (h g hg).2 m hm
      · rw [List.mem_singleton] at hm
        subst hm
        exact claimWeights_length c rows logCols
    · exact h g hg

theorem lInv_foldl (rows logCols : ℕ) : ∀ (cl : List ZClaim) (st : List ZKey × List (List Fp2 × List (List Fp2 × Fp2))),
    LInv rows logCols st → LInv rows logCols (cl.foldl (groupStep rows logCols) st)
  | [], _, h => h
  | c :: cl, st, h => by
    rw [List.foldl_cons]
    exact lInv_foldl rows logCols cl _ (lInv_step rows logCols st c h)

/-- **`group_zclaims`' groups**: column weights `2^logCols` long, every member's row weights `rows` long. -/
theorem groupZclaims_lens (cl : List ZClaim) (rows logCols : ℕ) (g : ℕ) (hg : g < (groupZclaims cl rows logCols).length) :
    ((groupZclaims cl rows logCols).getD g ([], [])).1.length = 2 ^ logCols
      ∧ ∀ m ∈ ((groupZclaims cl rows logCols).getD g ([], [])).2, m.1.length = rows :=
  lInv_foldl rows logCols cl ([], []) (fun g hg => absurd hg (by simp)) g hg

end Lengths

/-! ## Sums over the draw positions -/

section Mems

variable {K : Type} [Field K]

/-- The default member. -/
abbrev mem0 : ℕ × (List Fp2 × Fp2) := (0, ([], Fp2.zero))

theorem memsFrom_grp : ∀ (g0 : ℕ) (gs : List (List Fp2 × List (List Fp2 × Fp2))),
    ∀ e ∈ memsFrom g0 gs, g0 ≤ e.1 ∧ e.1 < g0 + gs.length
  | _, [], e, he => by simp [memsFrom] at he
  | g0, x :: xs, e, he => by
    rw [memsFrom, List.mem_append] at he
    rcases he with he | he
    · obtain ⟨m, -, rfl⟩ := List.mem_map.mp he
      simp
    · have := memsFrom_grp (g0 + 1) xs e he
      simp only [List.length_cons]
      omega

theorem memsFrom_getD_grp (g0 : ℕ) (gs : List (List Fp2 × List (List Fp2 × Fp2))) (p : ℕ)
    (hp : p < (memsFrom g0 gs).length) :
    g0 ≤ ((memsFrom g0 gs).getD p mem0).1 ∧ ((memsFrom g0 gs).getD p mem0).1 < g0 + gs.length := by
  rw [getD_eq_get _ _ _ hp]
  exact memsFrom_grp g0 gs _ (List.getElem_mem hp)

/-- A group's offset among the draw positions. -/
def offOf (gs : List (List Fp2 × List (List Fp2 × Fp2))) (g : ℕ) : ℕ := ((gs.take g).map (·.2.length)).sum

theorem getD_map_pair {α β : Type} (b : α) (l : List β) (p : ℕ) (hp : p < l.length) (d : α × β) (d' : β) :
    (l.map (fun m => (b, m))).getD p d = (b, l.getD p d') := by
  rw [getD_eq_get _ _ _ (by simpa using hp), getD_eq_get _ _ _ hp, List.getElem_map]

/-- **A sum over the draw positions with group `g`'s indicator is the sum over group `g`'s members** (at their draw
positions `offOf g + j`). -/
theorem sum_memsFrom : ∀ (f : ℕ → (List Fp2 × Fp2) → K) (g0 : ℕ) (gs : List (List Fp2 × List (List Fp2 × Fp2)))
    (g : ℕ), g < gs.length →
    ∑ p ∈ Finset.range (memsFrom g0 gs).length,
        (if ((memsFrom g0 gs).getD p mem0).1 = g0 + g then f p ((memsFrom g0 gs).getD p mem0).2 else 0)
      = ∑ j ∈ Finset.range (gs.getD g ([], [])).2.length,
          f (offOf gs g + j) ((gs.getD g ([], [])).2.getD j ([], Fp2.zero))
  | _, _, [], g, hg => absurd hg (by simp)
  | f, g0, x :: xs, g, hg => by
    have hlen : (memsFrom g0 (x :: xs)).length = x.2.length + (memsFrom (g0 + 1) xs).length := by
      rw [memsFrom, List.length_append, List.length_map]
    have hA : ∀ p, p < x.2.length → (memsFrom g0 (x :: xs)).getD p mem0 = (g0, x.2.getD p ([], Fp2.zero)) := by
      intro p hp
      rw [memsFrom, getD_append' _ _ _ _ (by simpa using hp)]
      exact getD_map_pair g0 x.2 p hp mem0 ([], Fp2.zero)
    have hB : ∀ p, (memsFrom g0 (x :: xs)).getD (x.2.length + p) mem0 = (memsFrom (g0 + 1) xs).getD p mem0 := by
      intro p
      rw [memsFrom, getD_append_right' _ _ _ _ (by simp), List.length_map, Nat.add_sub_cancel_left]
    rw [hlen, Finset.sum_range_add]
    rcases g with _ | g
    · have h1 : ∑ p ∈ Finset.range x.2.length,
            (if ((memsFrom g0 (x :: xs)).getD p mem0).1 = g0 + 0 then f p ((memsFrom g0 (x :: xs)).getD p mem0).2
              else 0)
          = ∑ j ∈ Finset.range x.2.length, f j (x.2.getD j ([], Fp2.zero)) := by
        refine Finset.sum_congr rfl (fun p hp => ?_)
        rw [hA p (Finset.mem_range.mp hp)]
        simp
      have h2 : ∑ p ∈ Finset.range (memsFrom (g0 + 1) xs).length,
            (if ((memsFrom g0 (x :: xs)).getD (x.2.length + p) mem0).1 = g0 + 0 then
              f (x.2.length + p) ((memsFrom g0 (x :: xs)).getD (x.2.length + p) mem0).2 else 0) = 0 := by
        refine Finset.sum_eq_zero (fun p hp => ?_)
        rw [hB p]
        have := (memsFrom_getD_grp (g0 + 1) xs p (Finset.mem_range.mp hp)).1
        rw [ite_eq_right (by omega)]
      rw [h1, h2, add_zero]
      simp [offOf]
    · have h1 : ∑ p ∈ Finset.range x.2.length,
            (if ((memsFrom g0 (x :: xs)).getD p mem0).1 = g0 + (g + 1) then
              f p ((memsFrom g0 (x :: xs)).getD p mem0).2 else 0) = 0 := by
        refine Finset.sum_eq_zero (fun p hp => ?_)
        rw [hA p (Finset.mem_range.mp hp)]
        rw [ite_eq_right (by simp)]
      have ih := sum_memsFrom (fun p m => f (x.2.length + p) m) (g0 + 1) xs g (by simpa using hg)
      beta_reduce at ih
      have h2 : ∑ p ∈ Finset.range (memsFrom (g0 + 1) xs).length,
            (if ((memsFrom g0 (x :: xs)).getD (x.2.length + p) mem0).1 = g0 + (g + 1) then
              f (x.2.length + p) ((memsFrom g0 (x :: xs)).getD (x.2.length + p) mem0).2 else 0)
          = ∑ p ∈ Finset.range (memsFrom (g0 + 1) xs).length,
            (if ((memsFrom (g0 + 1) xs).getD p mem0).1 = g0 + 1 + g then
              f (x.2.length + p) ((memsFrom (g0 + 1) xs).getD p mem0).2 else 0) := by
        refine Finset.sum_congr rfl (fun p _ => ?_)
        rw [hB p, show g0 + (g + 1) = g0 + 1 + g by omega]
      rw [h1, h2, ih, zero_add]
      simp only [List.getD_cons_succ, offOf, List.take_succ_cons, List.map_cons, List.sum_cons, Nat.add_assoc]

/-- The draw positions' sum for `memsOf`. -/
theorem sum_memsOf (f : ℕ → (List Fp2 × Fp2) → K) (gs : List (List Fp2 × List (List Fp2 × Fp2))) (g : ℕ)
    (hg : g < gs.length) :
    ∑ p ∈ Finset.range (memsOf gs).length,
        (if ((memsOf gs).getD p mem0).1 = g then f p ((memsOf gs).getD p mem0).2 else 0)
      = ∑ j ∈ Finset.range (gs.getD g ([], [])).2.length,
          f (offOf gs g + j) ((gs.getD g ([], [])).2.getD j ([], Fp2.zero)) := by
  have := sum_memsFrom f 0 gs g hg
  simp only [Nat.zero_add] at this
  exact this

end Mems

/-! ## One group's combination, and `zk_rhos`, in `K` -/

section Comb

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

theorem getD_replicate_zero (n i : ℕ) : (List.replicate n Fp2.zero).getD i Fp2.zero = Fp2.zero := by
  rw [List.getD_eq_getElem?_getD, List.getElem?_replicate]
  split_ifs <;> rfl

theorem rhoAdd_getD (lam : Fp2) (rho rw : List Fp2) (i : ℕ) (hi1 : i < rho.length) (hi2 : i < rw.length) :
    (rhoAdd lam rho rw).getD i Fp2.zero
      = if (rw.getD i Fp2.zero).isZero then rho.getD i Fp2.zero else (rho.getD i Fp2.zero).add (lam.mul (rw.getD i Fp2.zero)) := by
  unfold rhoAdd
  rw [getD_eq_get _ _ _ (by rw [List.length_zipWith]; omega), List.getElem_zipWith, getD_eq_get _ _ _ hi1,
    getD_eq_get _ _ _ hi2]

theorem rhoAdd_length (lam : Fp2) (rho rw : List Fp2) : (rhoAdd lam rho rw).length = min rho.length rw.length := by
  unfold rhoAdd
  rw [List.length_zipWith]

/-- The combination's state: `rows` canonical entries and a canonical want. -/
def CombOk (rows : ℕ) (acc : List Fp2 × Fp2) : Prop :=
  acc.1.length = rows ∧ (∀ i, i < rows → (acc.1.getD i Fp2.zero).Canon) ∧ acc.2.Canon

include hU in
theorem foldl_groupComb (rows : ℕ) : ∀ (l : List ((List Fp2 × Fp2) × Fp2)) (acc : List Fp2 × Fp2),
    (∀ p ∈ l, p.1.1.length = rows) → CombOk rows acc →
    CombOk rows (l.foldl (fun acc p => (rhoAdd p.2 acc.1 p.1.1, acc.2.add (p.2.mul p.1.2))) acc)
      ∧ (∀ i, i < rows → ((l.foldl (fun acc p => (rhoAdd p.2 acc.1 p.1.1, acc.2.add (p.2.mul p.1.2))) acc).1.getD i
          Fp2.zero).toK U = (acc.1.getD i Fp2.zero).toK U
            + (l.map (fun p => p.2.toK U * (p.1.1.getD i Fp2.zero).toK U)).sum)
      ∧ (l.foldl (fun acc p => (rhoAdd p.2 acc.1 p.1.1, acc.2.add (p.2.mul p.1.2))) acc).2.toK U
          = acc.2.toK U + (l.map (fun p => p.2.toK U * p.1.2.toK U)).sum
  | [], acc, _, hok => ⟨hok, fun i _ => by simp, by simp⟩
  | p :: l, acc, hl, hok => by
    obtain ⟨h1, h2, h3⟩ := hok
    have hpl : p.1.1.length = rows := hl p List.mem_cons_self
    set acc' : List Fp2 × Fp2 := (rhoAdd p.2 acc.1 p.1.1, acc.2.add (p.2.mul p.1.2)) with hacc'
    have hent : ∀ i, i < rows → (acc'.1.getD i Fp2.zero).Canon
        ∧ (acc'.1.getD i Fp2.zero).toK U = (acc.1.getD i Fp2.zero).toK U + p.2.toK U * (p.1.1.getD i Fp2.zero).toK U := by
      intro i hi
      show ((rhoAdd p.2 acc.1 p.1.1).getD i Fp2.zero).Canon ∧ _
      rw [rhoAdd_getD p.2 acc.1 p.1.1 i (by omega) (by omega)]
      split_ifs with hz
      · refine ⟨h2 i hi, ?_⟩
        rw [toK_of_isZero U _ hz, mul_zero, add_zero]
      · refine ⟨Fp2.canon_add _ _, ?_⟩
        rw [Fp2.toK_add U _ _ (h2 i hi) (Fp2.canon_mul _ _), Fp2.toK_mul U hU]
    have hok' : CombOk rows acc' :=
      ⟨by show (rhoAdd p.2 acc.1 p.1.1).length = rows; rw [rhoAdd_length, h1, hpl, min_self],
        fun i hi => (hent i hi).1, Fp2.canon_add _ _⟩
    obtain ⟨r1, r2, r3⟩ := foldl_groupComb rows l acc' (fun q hq => hl q (List.mem_cons_of_mem _ hq)) hok'
    simp only [List.foldl_cons]
    refine ⟨r1, fun i hi => ?_, ?_⟩
    · rw [r2 i hi, (hent i hi).2, List.map_cons, List.sum_cons]
      ring
    · rw [r3, List.map_cons, List.sum_cons]
      show (acc.2.add (p.2.mul p.1.2)).toK U + _ = _
      rw [Fp2.toK_add U _ _ h3 (Fp2.canon_mul _ _), Fp2.toK_mul U hU]
      ring

include hU in
/-- **One group's combination in `K`**: `ρ_g = Σ_j λ_j·rw_j` (`rows` entries) and `want_g = Σ_j λ_j·v_j`. -/
theorem groupComb_K (rows : ℕ) (members : List (List Fp2 × Fp2)) (lams : List Fp2)
    (hlam : lams.length = members.length) (hm : ∀ m ∈ members, m.1.length = rows) :
    (groupComb rows members lams).1.length = rows
      ∧ (∀ i, i < rows → ((groupComb rows members lams).1.getD i Fp2.zero).toK U
          = ∑ j ∈ Finset.range members.length,
              (lams.getD j Fp2.zero).toK U * ((members.getD j ([], Fp2.zero)).1.getD i Fp2.zero).toK U)
      ∧ (groupComb rows members lams).2.toK U
          = ∑ j ∈ Finset.range members.length,
              (lams.getD j Fp2.zero).toK U * (members.getD j ([], Fp2.zero)).2.toK U := by
  have hok0 : CombOk rows (List.replicate rows Fp2.zero, Fp2.zero) :=
    ⟨List.length_replicate, fun i _ => by rw [getD_replicate_zero]; exact Fp2.canon_zero, Fp2.canon_zero⟩
  have hl : ∀ p ∈ members.zip lams, p.1.1.length = rows := fun p hp => hm p.1 (List.of_mem_zip hp).1
  obtain ⟨r1, r2, r3⟩ := foldl_groupComb U hU rows (members.zip lams) _ hl hok0
  refine ⟨r1.1, fun i hi => ?_, ?_⟩
  · unfold groupComb
    rw [r2 i hi, getD_replicate_zero, Fp2.toK_zero, zero_add,
      sum_zip_range' ([], Fp2.zero) Fp2.zero (fun a b => b.toK U * (a.1.getD i Fp2.zero).toK U) members lams hlam]
  · unfold groupComb
    rw [r3, Fp2.toK_zero, zero_add,
      sum_zip_range' ([], Fp2.zero) Fp2.zero (fun a b => b.toK U * a.2.toK U) members lams hlam]

variable (H : HIn → Dig)

theorem drop_append_len {α : Type} : ∀ (l1 l2 : List α) (a n : ℕ), l1.length = a → (l1 ++ l2).drop (a + n) = l2.drop n
  | [], _, _, _, h => by subst h; simp
  | b :: l1, l2, _, n, h => by
    subst h
    rw [List.cons_append, List.length_cons, Nat.add_right_comm, List.drop_succ_cons]
    exact drop_append_len l1 l2 _ n rfl

/-- The members' count. -/
def nMem (gs : List (List Fp2 × List (List Fp2 × Fp2))) : ℕ := (gs.map (·.2.length)).sum

include hU in
/-- **`zk_rhos` in `K`**: with `ds` the run's `Σ members + rows` digests, group `g`'s combination is
`Σ_j challenge(ds_{off_g + j})·rw_{g,j}` (`rows` entries), its want `Σ_j challenge(ds_{off_g + j})·v_{g,j}`, and the
proximity weights are the challenges of the last `rows` digests. -/
theorem zkRhosAux_K (rows : ℕ) : ∀ (gs : List (List Fp2 × List (List Fp2 × Fp2))) (t : Tr),
    (∀ g, g < gs.length → ∀ m ∈ (gs.getD g ([], [])).2, m.1.length = rows) →
    (∀ g, g < gs.length → ((zkRhosAux H rows gs t).1.getD g []).length = rows
        ∧ ∀ i, i < rows → (((zkRhosAux H rows gs t).1.getD g []).getD i Fp2.zero).toK U
          = ∑ j ∈ Finset.range (gs.getD g ([], [])).2.length,
              (challengeFp2Of ((sqDs H t (nMem gs + rows)).getD (offOf gs g + j) zeroDig)).toK U
                * (((gs.getD g ([], [])).2.getD j ([], Fp2.zero)).1.getD i Fp2.zero).toK U)
      ∧ (∀ g, g < gs.length → ((zkRhosAux H rows gs t).2.1.getD g Fp2.zero).toK U
          = ∑ j ∈ Finset.range (gs.getD g ([], [])).2.length,
              (challengeFp2Of ((sqDs H t (nMem gs + rows)).getD (offOf gs g + j) zeroDig)).toK U
                * ((gs.getD g ([], [])).2.getD j ([], Fp2.zero)).2.toK U)
      ∧ (zkRhosAux H rows gs t).1.getD gs.length [] = ((sqDs H t (nMem gs + rows)).drop (nMem gs)).map challengeFp2Of
  | [], t, _ => by
    refine ⟨fun g hg => absurd hg (by simp), fun g hg => absurd hg (by simp), ?_⟩
    simp only [zkRhosAux, List.length_nil, List.getD_cons_zero, nMem, List.map_nil, List.sum_nil, Nat.zero_add,
      List.drop_zero, challengeFp2Vec_sqDs]
  | x :: xs, t, hm => by
    set t1 := (t.challengeFp2Vec H x.2.length).2 with ht1
    have ht1' : t1 = runOps H t (List.replicate x.2.length Op.squeeze) := by
      rw [ht1, challengeFp2Vec_sqDs]
    have ih := zkRhosAux_K rows xs t1 (fun g hg m hmm => hm (g + 1) (by simp; omega) m (by simpa using hmm))
    have hds : sqDs H t (nMem (x :: xs) + rows) = sqDs H t x.2.length ++ sqDs H t1 (nMem xs + rows) := by
      rw [ht1', ← sqDs_add]
      simp only [nMem, List.map_cons, List.sum_cons, Nat.add_assoc]
    have hz : zkRhosAux H rows (x :: xs) t = ((groupComb rows x.2 (t.challengeFp2Vec H x.2.length).1).1
        :: (zkRhosAux H rows xs t1).1, (groupComb rows x.2 (t.challengeFp2Vec H x.2.length).1).2
          :: (zkRhosAux H rows xs t1).2.1, (zkRhosAux H rows xs t1).2.2) := rfl
    have hlam : (t.challengeFp2Vec H x.2.length).1 = (sqDs H t x.2.length).map challengeFp2Of := by
      rw [challengeFp2Vec_sqDs]
    have hlamL : ((sqDs H t x.2.length).map challengeFp2Of).length = x.2.length := by
      rw [List.length_map, sqDs_length]
    have hgc := groupComb_K U hU rows x.2 ((sqDs H t x.2.length).map challengeFp2Of) hlamL
      (fun m hmm => hm 0 (by simp) m (by simpa using hmm))
    have hl0 : ∀ j, j ∈ Finset.range x.2.length →
        (((sqDs H t x.2.length).map challengeFp2Of).getD j Fp2.zero)
          = challengeFp2Of ((sqDs H t (nMem (x :: xs) + rows)).getD (offOf (x :: xs) 0 + j) zeroDig) := by
      intro j hj
      have hj' : j < (sqDs H t x.2.length).length := by rw [sqDs_length]; exact Finset.mem_range.mp hj
      rw [getD_map_lt' _ _ _ hj' zeroDig, hds, show offOf (x :: xs) 0 = 0 from rfl, Nat.zero_add,
        getD_append' _ _ _ _ hj']
    have hsh : ∀ g j, (sqDs H t (nMem (x :: xs) + rows)).getD (offOf (x :: xs) (g + 1) + j) zeroDig
        = (sqDs H t1 (nMem xs + rows)).getD (offOf xs g + j) zeroDig := by
      intro g j
      rw [hds, getD_append_right' _ _ _ _ (by
        simp only [sqDs_length, offOf, List.take_succ_cons, List.map_cons, List.sum_cons]; omega)]
      congr 1
      simp only [sqDs_length, offOf, List.take_succ_cons, List.map_cons, List.sum_cons]
      omega
    rw [hz]
    refine ⟨fun g hg => ?_, fun g hg => ?_, ?_⟩
    · rcases g with _ | g
      · simp only [List.getD_cons_zero]
        rw [hlam]
        refine ⟨hgc.1, fun i hi => ?_⟩
        rw [hgc.2.1 i hi]
        exact Finset.sum_congr rfl (fun j hj => by rw [hl0 j hj])
      · simp only [List.getD_cons_succ]
        have hg' : g < xs.length := by simpa using hg
        refine ⟨(ih.1 g hg').1, fun i hi => ?_⟩
        rw [(ih.1 g hg').2 i hi]
        exact Finset.sum_congr rfl (fun j _ => by rw [hsh g j])
    · rcases g with _ | g
      · simp only [List.getD_cons_zero]
        rw [hlam, hgc.2.2]
        exact Finset.sum_congr rfl (fun j hj => by rw [hl0 j hj])
      · simp only [List.getD_cons_succ]
        rw [ih.2.1 g (by simpa using hg)]
        exact Finset.sum_congr rfl (fun j _ => by rw [hsh g j])
    · simp only [List.length_cons, List.getD_cons_succ]
      have hn : nMem (x :: xs) = x.2.length + nMem xs := by simp only [nMem, List.map_cons, List.sum_cons]
      rw [ih.2.2, hds, hn, drop_append_len _ _ _ _ (sqDs_length H t x.2.length)]

end Comb

/-! ## `SoundGroups.lean`'s combinations of `oclOf` are the code's -/

section Oclof

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7) (H : HIn → Dig)

/-- The draw-position challenge `challenge_fp2(ds_p)`, in `K`. -/
noncomputable def chK (ds : List Dig) (p : ℕ) : K := (challengeFp2Of (ds.getD p zeroDig)).toK U

theorem memsOf_length' (gs : List (List Fp2 × List (List Fp2 × Fp2))) : (memsOf gs).length = nMem gs :=
  memsOf_length gs

include hU in
/-- **`groupWeights` of `oclOf` at the run's `λ`s is `zk_rhos`' combination** (row `i`). -/
theorem groupWeights_oclOf (rows lc Q : ℕ) (gs : List (List Fp2 × List (List Fp2 × Fp2))) (t : Tr)
    (hm : ∀ g, g < gs.length → ∀ m ∈ (gs.getD g ([], [])).2, m.1.length = rows) (g : ℕ) (hg : g < gs.length)
    (i : Fin rows) :
    groupWeights (oclOf U rows lc Q (nMem gs) gs).rw (oclOf U rows lc Q (nMem gs) gs).grp
        (fun p : Fin (nMem gs) => chK U (sqDs H t (nMem gs + rows)) p) g i
      = (((zkRhosAux H rows gs t).1.getD g []).getD i Fp2.zero).toK U := by
  have hs := sum_memsOf (fun p m => chK U (sqDs H t (nMem gs + rows)) p * (m.1.getD i Fp2.zero).toK U) gs g hg
  beta_reduce at hs
  simp only [mem0] at hs
  rw [memsOf_length', Finset.sum_range] at hs
  rw [((zkRhosAux_K U hU H rows gs t hm).1 g hg).2 i i.isLt]
  refine Eq.trans ?_ hs
  unfold groupWeights
  rw [Finset.sum_apply]
  refine Finset.sum_congr rfl (fun p _ => ?_)
  show (if ((memsOf gs).getD p (0, ([], Fp2.zero))).1 = g then chK U (sqDs H t (nMem gs + rows)) p else 0)
      * ((((memsOf gs).getD p (0, ([], Fp2.zero))).2.1).getD i Fp2.zero).toK U = _
  by_cases h : ((memsOf gs).getD p (0, ([], Fp2.zero))).1 = g
  · simp only [ite_eq_left h]
  · simp only [ite_eq_right h, zero_mul]

include hU in
/-- **`groupWant` of `oclOf` at the run's `λ`s is `zk_rhos`' want.** -/
theorem groupWant_oclOf (rows lc Q : ℕ) (gs : List (List Fp2 × List (List Fp2 × Fp2))) (t : Tr)
    (hm : ∀ g, g < gs.length → ∀ m ∈ (gs.getD g ([], [])).2, m.1.length = rows) (g : ℕ) (hg : g < gs.length) :
    groupWant (oclOf U rows lc Q (nMem gs) gs).val (oclOf U rows lc Q (nMem gs) gs).grp
        (fun p : Fin (nMem gs) => chK U (sqDs H t (nMem gs + rows)) p) g
      = ((zkRhosAux H rows gs t).2.1.getD g Fp2.zero).toK U := by
  have hs := sum_memsOf (fun p m => chK U (sqDs H t (nMem gs + rows)) p * m.2.toK U) gs g hg
  beta_reduce at hs
  simp only [mem0] at hs
  rw [memsOf_length', Finset.sum_range] at hs
  rw [(zkRhosAux_K U hU H rows gs t hm).2.1 g hg]
  refine Eq.trans ?_ hs
  unfold groupWant
  refine Finset.sum_congr rfl (fun p _ => ?_)
  show (if ((memsOf gs).getD p (0, ([], Fp2.zero))).1 = g then chK U (sqDs H t (nMem gs + rows)) p else 0)
      * (((memsOf gs).getD p (0, ([], Fp2.zero))).2.2).toK U = _
  by_cases h : ((memsOf gs).getD p (0, ([], Fp2.zero))).1 = g
  · simp only [ite_eq_left h]
  · simp only [ite_eq_right h, zero_mul]

/-- Every group of `oclOf`'s draw positions is a group of the list. -/
theorem oclOf_grp_lt (rows lc Q : ℕ) (gs : List (List Fp2 × List (List Fp2 × Fp2))) (p : Fin (nMem gs)) :
    (oclOf U rows lc Q (nMem gs) gs).grp p < gs.length := by
  have hp : (p : ℕ) < (memsFrom 0 gs).length := by
    have := memsOf_length' gs
    unfold memsOf at this
    rw [this]
    exact p.isLt
  have := (memsFrom_getD_grp 0 gs p hp).2
  simpa [oclOf, memsOf, mem0] using this

/-- A clear vector of `2^lc + Q` entries, read on the message coordinates: its column-weight product is the dot
product of its first `2^lc` entries. -/
theorem sum_vecK_cwK (lc Q : ℕ) (v cw : List Fp2) :
    ∑ t : Fin (2 ^ lc + Q), vecK U (2 ^ lc + Q) v t * cwK U lc Q cw t
      = ∑ t ∈ Finset.range (2 ^ lc), (v.getD t Fp2.zero).toK U * (cw.getD t Fp2.zero).toK U := by
  have h := Fin.sum_univ_eq_sum_range
    (fun t : ℕ => (v.getD t Fp2.zero).toK U * (if t < 2 ^ lc then (cw.getD t Fp2.zero).toK U else 0)) (2 ^ lc + Q)
  refine Eq.trans (Finset.sum_congr rfl (fun t _ => rfl)) (h.trans ?_)
  rw [Finset.sum_range_add]
  have hz : ∀ x ∈ Finset.range Q, (v.getD (2 ^ lc + x) Fp2.zero).toK U
      * (if 2 ^ lc + x < 2 ^ lc then (cw.getD (2 ^ lc + x) Fp2.zero).toK U else 0) = 0 :=
    fun x _ => by rw [ite_eq_right (by omega), mul_zero]
  rw [Finset.sum_eq_zero hz, add_zero]
  exact Finset.sum_congr rfl (fun t ht => by rw [ite_eq_left (Finset.mem_range.mp ht)])

/-- The encoder at a clear vector read in `K` is L10's `encK` at the point. -/
theorem encLin_vecK {lc Q N : ℕ} (pts : Fin N → K) (R : RowForm K (2 ^ lc)) (v : List Fp2) (j : Fin N) :
    encLin (Q := Q) pts R (vecK U (2 ^ lc + Q) v) j = encK U R Q v (pts j) := by
  rw [encLin_apply]
  rfl

omit [Algebra GF K] in
theorem comb_apply' {rows N : ℕ} (Ux : Fin rows → Fin N → K) (w : Fin rows → K) (j : Fin N) :
    comb Ux w j = ∑ i, w i * Ux i j := by
  unfold comb
  rw [Finset.sum_apply]
  simp only [Pi.smul_apply, smul_eq_mul]

end Oclof

/-! ## The field link: `PcsOk` is `GroupsAccept` of `oclOf` -/

section Accept

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7) (H : HIn → Dig) (tag : MTag)

theorem idx_length_of (prm : PcsPrm) (hnn : isPow2 prm.nn = true) (hnQ : 0 < prm.nQ) (t t' : Tr) (idx : List ℕ)
    (h : t.challengeIndices H prm.nQ prm.nn = some (idx, t')) :
    idx = idxOf prm.nn prm.nQ (sqDs H t ((prm.nQ + 3) / 4)) ∧ idx.length = prm.nQ := by
  rw [challengeIndices_sqDs H prm.nQ prm.nn t hnn hnQ] at h
  simp only [Option.some.injEq, Prod.mk.injEq] at h
  rw [← h.1, idxOf_length, sqDs_length]
  exact ⟨rfl, by omega⟩

include hU in
/-- **The regular opening's field link** (L22 §5 item 1). If L10's executable opening verifier's checks hold
(`PcsOk`, for any parameters, any column evaluator meeting `ColEncSpec` with the row form `R`), and the matrix `Ux`
agrees with the opened columns at the sampled indices, then `SoundGroups.lean`'s `GroupsAccept` holds for the encoder
`encLin`, the `OClaims` `oclOf` of the claims' groups (indexed by draw position), the clear vectors and proximity
vector read in `K`, the run's `λ`s and proximity weights (`challenge_fp2` of the `(λ, ρ)` run's digests), and the
sampled indices. -/
theorem pcsOk_groupsAccept (prm : PcsPrm) (pt : ℕ → Fp) (ev : Fp → List (List Fp2) → List Fp2) (lc Q N rows : ℕ)
    (hlc : prm.logCols = lc) (hQ : prm.qPad = Q) (hnn : isPow2 prm.nn = true) (hnQ : 0 < prm.nQ)
    (R : RowForm K (2 ^ lc)) (hspec : ColEncSpec U R Q pt ev) (root : Dig) (claims : List ZClaim) (op : OpeningZk)
    (t t' : Tr) (hok : PcsOk H tag prm pt ev root rows lc claims op t t')
    (pts : Fin N → K) (hpts : ∀ j : Fin N, pts j = algebraMap GF K (pt j).toGF)
    (J : Fin prm.nQ → Fin N)
    (hJ : ∀ k : Fin prm.nQ, (J k : ℕ) = (idxOf prm.nn prm.nQ (sqDs H ((absorbVecs H op.groupVecs
      (zkRhosAux H rows (groupZclaims claims rows lc) t).2.2).absorbFp2 H pcsProxLabel op.proxVec)
        ((prm.nQ + 3) / 4))).getD k 0)
    (Ux : Fin rows → Fin N → K)
    (hUx : ∀ (k : Fin prm.nQ) (i : Fin rows),
      Ux i (J k) = algebraMap GF K (((op.columns.getD k (0, [], zeroDig, [])).2.1).getD i Fp.zero).toGF) :
    GroupsAccept (encLin (Q := Q) pts R) Ux
      (oclOf U rows lc Q (nMem (groupZclaims claims rows lc)) (groupZclaims claims rows lc)).rw
      (oclOf U rows lc Q (nMem (groupZclaims claims rows lc)) (groupZclaims claims rows lc)).cw
      (oclOf U rows lc Q (nMem (groupZclaims claims rows lc)) (groupZclaims claims rows lc)).grp
      (oclOf U rows lc Q (nMem (groupZclaims claims rows lc)) (groupZclaims claims rows lc)).val
      (fun g _ _ => vecK U (2 ^ lc + Q) (op.groupVecs.getD g []))
      (fun _ _ => vecK U (2 ^ lc + Q) op.proxVec)
      (fun p => chK U (sqDs H t (nMem (groupZclaims claims rows lc) + rows)) p)
      (fun i => chK U (sqDs H t (nMem (groupZclaims claims rows lc) + rows)) (nMem (groupZclaims claims rows lc) + i))
      J := by
  subst hlc hQ
  obtain ⟨-, -, -, h3, hgrp, h4, idx, hidx, h5, hcols⟩ := hok
  have hidx' := idx_length_of H prm hnn hnQ _ _ idx hidx
  have hm : ∀ g, g < (groupZclaims claims rows prm.logCols).length →
      ∀ m ∈ ((groupZclaims claims rows prm.logCols).getD g ([], [])).2, m.1.length = rows :=
    fun g hg => (groupZclaims_lens claims rows prm.logCols g hg).2
  have hZ := zkRhosAux_K U hU H rows (groupZclaims claims rows prm.logCols) t hm
  have hrl : (zkRhosAux H rows (groupZclaims claims rows prm.logCols) t).1.length
      = (op.groupVecs ++ [op.proxVec]).length := by
    rw [(zkRhosAux_length H rows _ t).1, List.length_append, h3, List.length_singleton]
  have hvs : ∀ v ∈ op.groupVecs ++ [op.proxVec], v.length = 2 ^ prm.logCols + prm.qPad := by
    intro v hv
    rcases List.mem_append.mp hv with hv | hv
    · obtain ⟨g, hg, rfl⟩ := List.getElem_of_mem hv
      have := (hgrp g hg).1
      rw [getD_eq_get _ _ _ hg] at this
      exact this
    · rw [List.mem_singleton] at hv
      subst hv
      exact h4
  have hlast := hZ.2.2
  have hrr : ∀ rho ∈ (zkRhosAux H rows (groupZclaims claims rows prm.logCols) t).1, rho.length = rows := by
    intro rho hrho
    obtain ⟨g, hg, rfl⟩ := List.getElem_of_mem hrho
    have hg' : g < (groupZclaims claims rows prm.logCols).length + 1 := by
      rw [(zkRhosAux_length H rows _ t).1] at hg; exact hg
    rw [← getD_eq_get _ _ [] hg]
    by_cases hgl : g < (groupZclaims claims rows prm.logCols).length
    · exact (hZ.1 g hgl).1
    · have hge : g = (groupZclaims claims rows prm.logCols).length := by omega
      rw [hge, hlast, List.length_map, List.length_drop, sqDs_length]
      omega
  -- one opened column's field equations
  have hcol : ∀ (k : Fin prm.nQ) (g : ℕ), g < (op.groupVecs ++ [op.proxVec]).length →
      ∑ i : Fin rows, (((zkRhosAux H rows (groupZclaims claims rows prm.logCols) t).1.getD g []).getD i
          Fp2.zero).toK U * Ux i (J k)
        = encK U R prm.qPad ((op.groupVecs ++ [op.proxVec]).getD g []) (pts (J k)) := by
    intro k g hg
    have hk : (k : ℕ) < op.columns.length := by rw [h5, hidx'.2]; exact k.isLt
    have hc := hcols k hk
    have he := opening_columns_K U hU R prm.qPad pt ev hspec rows _ (op.groupVecs ++ [op.proxVec]) hvs hrl hrr H tag
      root _ _ hc g hg
    have hj : (op.columns.getD k (0, [], zeroDig, [])).1 = (J k : ℕ) := by
      rw [hc.1, hJ k, ← hidx'.1]
    rw [hj, ← hpts] at he
    rw [← he]
    exact Finset.sum_congr rfl (fun i _ => by rw [hUx k i])
  refine ⟨?_, ?_, ?_⟩
  · -- the groups' claim checks
    rintro g ⟨p, rfl⟩
    have hg := oclOf_grp_lt U rows prm.logCols prm.qPad (groupZclaims claims rows prm.logCols) p
    have hgv : (oclOf U rows prm.logCols prm.qPad (nMem (groupZclaims claims rows prm.logCols))
        (groupZclaims claims rows prm.logCols)).grp p < op.groupVecs.length := by rw [h3]; exact hg
    rw [groupWant_oclOf U hU H rows prm.logCols prm.qPad _ t hm _ hg]
    have hc := (hgrp _ hgv).2
    rw [getD_map_lt' _ _ _ hg ([], []) []] at hc
    rw [← hc]
    have hvl := (hgrp _ hgv).1
    have hcl := (groupZclaims_lens claims rows prm.logCols _ hg).1
    rw [toK_dotF U hU _ _ (2 ^ prm.logCols) (by rw [List.length_take, hvl]; simp [PcsPrm.n]) hcl]
    show ∑ t : Fin (2 ^ prm.logCols + prm.qPad), vecK U (2 ^ prm.logCols + prm.qPad) _ t
        * cwK U prm.logCols prm.qPad _ t = _
    rw [sum_vecK_cwK]
    refine Finset.sum_congr rfl (fun t ht => ?_)
    rw [getD_take_lt _ _ _ (by simpa [PcsPrm.n] using Finset.mem_range.mp ht)]
  · -- the groups' column checks
    rintro g ⟨p, rfl⟩ k
    have hg := oclOf_grp_lt U rows prm.logCols prm.qPad (groupZclaims claims rows prm.logCols) p
    have hgl : (oclOf U rows prm.logCols prm.qPad (nMem (groupZclaims claims rows prm.logCols))
        (groupZclaims claims rows prm.logCols)).grp p < (op.groupVecs ++ [op.proxVec]).length := by
      rw [List.length_append, h3]; omega
    rw [encLin_vecK, comb_apply']
    have hcg := hcol k _ hgl
    rw [getD_append' _ _ _ _ (by rw [h3]; exact hg)] at hcg
    rw [← hcg]
    refine Finset.sum_congr rfl (fun i _ => ?_)
    rw [groupWeights_oclOf U hU H rows prm.logCols prm.qPad _ t hm _ hg i]
  · -- the proximity column check
    intro k
    have hgl : (groupZclaims claims rows prm.logCols).length < (op.groupVecs ++ [op.proxVec]).length := by
      rw [List.length_append, h3]; simp
    rw [encLin_vecK, comb_apply']
    have hcg := hcol k _ hgl
    rw [getD_append_right' _ _ _ _ (le_of_eq h3), h3, Nat.sub_self, hlast] at hcg
    rw [show [op.proxVec].getD 0 [] = op.proxVec from rfl] at hcg
    rw [← hcg]
    refine Finset.sum_congr rfl (fun i _ => ?_)
    congr 1
    rw [getD_map_lt' _ _ _ (by rw [List.length_drop, sqDs_length]; have := i.isLt; omega) zeroDig, getD_drop]
    rfl

/-- **The code's `(λ, ρ)` is `lrCode` of the run's digests**: `FSOpening.lean`'s derivation, in the draw order
`finSumFinEquiv`, read through `fp2Field` (`challengeFp2Of_toK`). -/
theorem lrCode_sqDs (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (nC rows : ℕ) (ds : List Dig)
    (hds : ds.length = nC + rows) :
    lrCode gP (Equiv.ofBijective _ hbij) (finSumFinEquiv.symm : Fin (nC + rows) ≃ Fin nC ⊕ Fin rows)
        (vecOf dg0 (nC + rows) (ds.map halves))
      = ((fun p : Fin nC => chK U ds p), (fun i : Fin rows => chK U ds (nC + i))) := by
  have key : ∀ j : ℕ, j < ds.length → fp2Field gP (2 ^ 128) (Equiv.ofBijective _ hbij) ((ds.map halves).getD j dg0)
      = chK U ds j := by
    intro j hj
    unfold chK
    rw [challengeFp2Of_toK U hbij, getD_map_lt' _ _ _ hj zeroDig]
  refine Prod.ext (funext fun p => ?_) (funext fun i => ?_)
  · show fp2Field gP (2 ^ 128) (Equiv.ofBijective _ hbij) (vecOf dg0 (nC + rows) (ds.map halves)
      (finSumFinEquiv.symm.symm (Sum.inl p))) = _
    rw [Equiv.symm_symm, finSumFinEquiv_apply_left]
    exact key p (by rw [hds]; have := p.isLt; omega)
  · show fp2Field gP (2 ^ 128) (Equiv.ofBijective _ hbij) (vecOf dg0 (nC + rows) (ds.map halves)
      (finSumFinEquiv.symm.symm (Sum.inr i))) = _
    rw [Equiv.symm_symm, finSumFinEquiv_apply_right]
    exact key (nC + i) (by rw [hds]; have := i.isLt; omega)

end Accept

/-! ## `opA`'s and `opB`'s rounds read off the trace, and `opB` alive at the end -/

section Alive

variable (H : HIn → Dig)

theorem stpsOps_pcsStps_split (w0 m : ℕ) (o : Block.OpeningZk) :
    stpsOps (pcsStps w0 m o) = (List.replicate w0 Op.squeeze ++ stpsOps (vecStps o.groupVecs))
      ++ (Op.absorb Block.labPcsProx (o.proxVec.flatMap Fp2.toBytes) :: List.replicate m Op.squeeze) := by
  simp [pcsStps, pcsPre, stpsOps_cons, stpsOps_append, Stp.ops, stpsOps_nil]

theorem stpOK_pcsHead (W : UInt64 → ℕ) (w0 : ℕ) (hw0 : 0 < w0) (o : Block.OpeningZk) (c : UInt64) (hW : W c = w0) :
    StpOK W c (Stp.sq w0 :: vecStps o.groupVecs) := by
  refine ⟨hW, hw0, ?_⟩
  have := stpOK_vecStps W (c + UInt64.ofNat w0) o.groupVecs [] trivial
  rwa [List.append_nil] at this

/-- **`opA`'s round read off the trace**: from `opA`'s window, the `w0` squeezes complete its one round with their
digests, and the group vectors' absorbs leave the frozen reading unchanged. -/
theorem cRd_opA (W : UInt64 → ℕ) (w0 : ℕ) (hw0 : 0 < w0) (vs : List (List Fp2)) (tA : Tr) (hW : W tA.counter = w0) :
    cRd (opARounds w0) W (opTrace H tA (List.replicate w0 Op.squeeze ++ stpsOps (vecStps vs)))
      = some ([([], sqDs H tA w0)], none, []) := by
  unfold cRd
  rw [Block.opTrace_append, List.foldl_append,
    cRd_run_sq H (opARounds w0) W tA w0 [] none (by simp [opARounds]) (by simp [opARounds]) (by simp [opARounds]) hw0 hW]
  exact foldl_cRdStep_frozen (opARounds w0) W (by simp [opARounds]) _

/-- **`opB`'s round read off the trace**: the `"pcs-prox"` absorb is its message, the `m` index squeezes its digests,
and then it is frozen. -/
theorem cRd_opB (W : UInt64 → ℕ) (m : ℕ) (hm : 0 < m) (pb : List UInt8) (t2 : Tr)
    (hW : W (t2.absorb H Block.labPcsProx pb).counter = m) (rest : List (TItem × Dig)) :
    cRd (opBRounds Block.labPcsProx m) W ((TItem.absorb Block.labPcsProx pb, (t2.absorb H Block.labPcsProx pb).state)
        :: (opTrace H (t2.absorb H Block.labPcsProx pb) (List.replicate m Op.squeeze) ++ rest))
      = some ([(pb, sqDs H (t2.absorb H Block.labPcsProx pb) m)], none, []) := by
  unfold cRd
  rw [List.foldl_cons, cRdStep_absorb_msg (opBRounds Block.labPcsProx m) W [] Block.labPcsProx pb _
    (by simp [opBRounds]) (by simp [opBRounds]) (by simp [opBRounds]), List.foldl_append,
    cRd_run_sq H (opBRounds Block.labPcsProx m) W _ m [] (some pb) (by simp [opBRounds]) (by simp [opBRounds])
      (by simp [opBRounds]) hm hW]
  exact foldl_cRdStep_frozen (opBRounds Block.labPcsProx m) W (by simp [opBRounds]) _

variable {F κ μ G Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype μ]
  [Fintype Cl] [DecidableEq Cl] [DecidableEq G] {h : ℕ}

omit [Fintype F] [DecidableEq F] [DecidableEq κ] [DecidableEq Cl] in
/-- **`opB` alive at the end of the chain when the opening's checks hold** (the `A` / `H` analogue of
`mask_subSt_of_ok`, deterministic). The chain is any whole-step prefix `pre` (`opA`'s window at `pre.length`), the
opening's steps on the transcript `tA` (`w0` batching squeezes, the group vectors, `"pcs-prox"`, `m` index
squeezes), then anything. If the widths agree with the runs and `GroupsAccept` holds at `opA`'s claims and matrix at
`pre`, the group vectors `vOf` reads off `opB`'s header, the proximity vector `decB` decodes, the `(λ, ρ)` of the
batching run's digests and the indices of the index run's, then `opB`'s window (after the group vectors) is at a step's
end, in the chain, and `opB` is alive at the end (`subSt W (opBCSub …)`). -/
theorem pcs_subSt_of_acc (W : UInt64 → ℕ) (w0 m : ℕ) (hw0 : 0 < w0) (hm : 0 < m) (o : Block.OpeningZk) (tA : Tr)
    (hW1 : W tA.counter = w0)
    (hW2 : W ((runOps H (runOps H tA (List.replicate w0 Op.squeeze)) (stpsOps (vecStps o.groupVecs))).absorb H
      Block.labPcsProx (o.proxVec.flatMap Fp2.toBytes)).counter = m)
    (pre rest : List (TItem × Dig)) (hpre : tRem W pre = some 0)
    (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ) (clOf : List (TItem × Dig) → OClaims Cl G κ μ F)
    (Ux : List (TItem × Dig) → κ → Fin (2 ^ h) → F) (vOf : List (TItem × Dig) → G → μ → F) (d₀ : Dg)
    (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h)))
    (decB : List UInt8 → Option (μ → F)) (εB : ℝ≥0∞) (wv : μ → F)
    (hdec : decB (o.proxVec.flatMap Fp2.toBytes) = some wv)
    (hacc : GroupsAccept enc (Ux pre) (clOf pre).rw (clOf pre).cw (clOf pre).grp (clOf pre).val
      (fun g _ _ => vOf (pre ++ opTrace H tA (List.replicate w0 Op.squeeze ++ stpsOps (vecStps o.groupVecs))) g)
      (fun _ _ => wv) (chalLR (vecOf d₀ w0 ((sqDs H tA w0).map halves))).1
      (chalLR (vecOf d₀ w0 ((sqDs H tA w0).map halves))).2
      (chalJ (vecOf d₀ m ((sqDs H ((runOps H (runOps H tA (List.replicate w0 Op.squeeze))
        (stpsOps (vecStps o.groupVecs))).absorb H Block.labPcsProx (o.proxVec.flatMap Fp2.toBytes)) m).map halves)))) :
    pre.length + (w0 + o.groupVecs.length) ≤ (pre ++ opTrace H tA (stpsOps (pcsStps w0 m o)) ++ rest).length
      ∧ tRem W ((pre ++ opTrace H tA (stpsOps (pcsStps w0 m o)) ++ rest).take (pre.length + (w0 + o.groupVecs.length)))
        = some 0
      ∧ subSt W (opBCSub W pre.length w0 enc e clOf Ux vOf d₀ chalLR m chalJ Block.labPcsProx decB
          (pre.length + (w0 + o.groupVecs.length)) εB) (pre ++ opTrace H tA (stpsOps (pcsStps w0 m o)) ++ rest) := by
  set A1 := opTrace H tA (List.replicate w0 Op.squeeze ++ stpsOps (vecStps o.groupVecs)) with hA1
  set t2 := runOps H (runOps H tA (List.replicate w0 Op.squeeze)) (stpsOps (vecStps o.groupVecs)) with ht2
  set pb := o.proxVec.flatMap Fp2.toBytes with hpb
  have hA1l : A1.length = w0 + o.groupVecs.length := by
    rw [hA1, Block.opTrace_length, List.length_append, List.length_replicate, stpsOps_vecStps_length]
  have htr : opTrace H tA (stpsOps (pcsStps w0 m o)) = A1 ++ ((TItem.absorb Block.labPcsProx pb,
      (t2.absorb H Block.labPcsProx pb).state) :: opTrace H (t2.absorb H Block.labPcsProx pb) (List.replicate m Op.squeeze)) := by
    rw [stpsOps_pcsStps_split, Block.opTrace_append, runOps_append]
    rfl
  have hchain : pre ++ opTrace H tA (stpsOps (pcsStps w0 m o)) ++ rest = (pre ++ A1) ++ ((TItem.absorb Block.labPcsProx pb,
      (t2.absorb H Block.labPcsProx pb).state) :: (opTrace H (t2.absorb H Block.labPcsProx pb)
        (List.replicate m Op.squeeze) ++ rest)) := by
    rw [htr]
    simp only [List.append_assoc, List.cons_append]
  have hlen : (pre ++ A1).length = pre.length + (w0 + o.groupVecs.length) := by
    rw [List.length_append, hA1l]
  have htake : (pre ++ opTrace H tA (stpsOps (pcsStps w0 m o)) ++ rest).take (pre.length + (w0 + o.groupVecs.length))
      = pre ++ A1 := by
    rw [hchain, ← hlen, List.take_left' rfl]
  have hdrop : (pre ++ opTrace H tA (stpsOps (pcsStps w0 m o)) ++ rest).drop (pre.length + (w0 + o.groupVecs.length))
      = (TItem.absorb Block.labPcsProx pb, (t2.absorb H Block.labPcsProx pb).state)
        :: (opTrace H (t2.absorb H Block.labPcsProx pb) (List.replicate m Op.squeeze) ++ rest) := by
    rw [hchain, ← hlen, List.drop_left' rfl]
  have hrem : tRem W (pre ++ A1) = some 0 := by
    have := tRem_opTrace_stps W H (Stp.sq w0 :: vecStps o.groupVecs) tA pre (stpOK_pcsHead W w0 hw0 o _ hW1) hpre
    rwa [stpsOps_cons] at this
  have hlen2 : pre.length + (w0 + o.groupVecs.length) ≤ (pre ++ opTrace H tA (stpsOps (pcsStps w0 m o)) ++ rest).length := by
    rw [hchain, List.length_append, hlen]
    exact Nat.le_add_right _ _
  refine ⟨hlen2, by rw [htake]; exact hrem, Or.inr (Or.inl ⟨?_, ?_⟩)⟩
  · show tRem W ((pre ++ opTrace H tA (stpsOps (pcsStps w0 m o)) ++ rest).take
      (pre.length + (w0 + o.groupVecs.length))) = some 0
    rw [htake]
    exact hrem
  have hrdA : opARead W pre.length w0 (pre ++ A1) = some (sqDs H tA w0) := by
    unfold opARead
    rw [List.drop_left' rfl, hA1, cRd_opA H W w0 hw0 o.groupVecs tA hW1]
  show liftC ((opBCSub W pre.length w0 enc e clOf Ux vOf d₀ chalLR m chalJ Block.labPcsProx decB
      (pre.length + (w0 + o.groupVecs.length)) εB).St
      ((pre ++ opTrace H tA (stpsOps (pcsStps w0 m o)) ++ rest).take (pre.length + (w0 + o.groupVecs.length))))
    (cRd (opBRounds Block.labPcsProx m) W
      ((pre ++ opTrace H tA (stpsOps (pcsStps w0 m o)) ++ rest).drop (pre.length + (w0 + o.groupVecs.length))))
  rw [hdrop, htake, cRd_opB H W m hm pb t2 hW2 rest]
  have htt : (pre ++ A1).take pre.length = pre := List.take_left' rfl
  show (opARead W pre.length w0 (pre ++ A1)).isSome = true ∧ ∃ wv', decB pb = some wv' ∧ GroupsAccept enc (Ux ((pre ++ A1).take pre.length))
    (clOf ((pre ++ A1).take pre.length)).rw (clOf ((pre ++ A1).take pre.length)).cw
    (clOf ((pre ++ A1).take pre.length)).grp (clOf ((pre ++ A1).take pre.length)).val
    (fun g _ _ => vOf (pre ++ A1) g) (fun _ _ => wv') (opBLR W pre.length w0 d₀ chalLR (pre ++ A1)).1
    (opBLR W pre.length w0 d₀ chalLR (pre ++ A1)).2
    (chalJ (vecOf d₀ m ((sqDs H (t2.absorb H Block.labPcsProx pb) m).map halves)))
  have hlr : opBLR W pre.length w0 d₀ chalLR (pre ++ A1) = chalLR (vecOf d₀ w0 ((sqDs H tA w0).map halves)) := by
    unfold opBLR
    rw [hrdA]
    rfl
  rw [htt, hlr, hrdA]
  exact ⟨rfl, wv, hdec, hacc⟩

end Alive

end ZK60.Exec.Link
