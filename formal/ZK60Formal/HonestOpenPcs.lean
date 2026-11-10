/-
D63 Lean lane L32 (2026-11-09), part 1: **the hiding PCS opening's honest prover, and the completeness of lane L10's
executable opening verifier** (`pcsVerify`, the mirror of `zkp-core/src/pcs.rs` `verify_zk_tagged`) on its output.

The code (`zkp-core/src/pcs.rs` `open_zk` :1040-1069, `fold_rows_multi_zk` :976-1000, `encode_row_zk` :674-693, read
2026-11-09; nothing there is changed). The prover makes the verifier's transcript calls in the verifier's order:
`group_zclaims`, `zk_rhos` (the members' `λ`s per group, then the `rows` proximity weights), one clear vector per
group and the proximity vector (each `Σ_i ρ_i·(row_i ‖ pad_i)`, `fold_rows_multi_zk`), `absorb_fp2("pcs-vec")` per
group, `absorb_fp2("pcs-prox")`, `challenge_indices`, then per sampled index the committed column, its salt and its
Merkle path.

What is here:
* `combAt`, `combVec`: the row combination on the words (`Σ_i ρ_i·row_i[k]`, the base-field rows under `Fp2` weights);
  `toK_combAt`, `encK_combVec`: it is the field's combination, and lane L10's encoder `encK` is linear in it;
* `Table`: one commitment's honest data (the rows `message ‖ pad`, the encoded columns, the salts); `ColsHonest`: the
  committed columns ARE the encoder's values at the column points; `rootOf`, `pathOf`: the honest Merkle root and
  paths (`CompleteSub.lean`'s `treeRoot`, `treePath`), `verifyPath_honest`;
* `tabVal`, `ClaimTrue`: a claim is TRUE of the table (its value is its own weights' functional of the rows:
  `zpart_weights` on the rows, `zkey_weights` on the columns); `groupZclaims_true`: then every member of every group
  `group_zclaims` forms is true of its group's column weights;
* **`pcsProve`**: the honest opening prover (`open_zk`), returning the opening and the transcript after it;
* **`pcsVerify_of_prove`**: for every hash function and every transcript, L10's executable verifier ACCEPTS the honest
  opening of true claims on an honest table, and lands on the prover's transcript. No challenge can make it fail: the
  opening's completeness error is `0`. (The prover's own refusals, `check_opening`'s, are sites: `HonestOpenSites.lean`.)

Every premise is an explicit hypothesis. The code's prover also ASSERTS that every opening site is masked
(`assert_mask_sites`, pcs.rs:1006); that assertion is not modelled here (finding L32-2: it follows from
`check_opening`'s acceptance, which the callers run first).
-/
import ZK60Formal.LinkW16Pcs
import ZK60Formal.CompleteSub

set_option autoImplicit false

namespace ZK60.HonestOpen

open Polynomial
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## Lists -/

section Lists

/-- A list of `G + 1` entries is its first `G` entries and its last. -/
theorem take_getD_eq {α : Type} (d : α) : ∀ (l : List α) (G : ℕ), l.length = G + 1 → l.take G ++ [l.getD G d] = l
  | [], _, h => by rw [List.length_nil] at h; omega
  | [_], 0, _ => rfl
  | _ :: _ :: _, 0, h => by rw [List.length_cons, List.length_cons] at h; omega
  | a :: l, G + 1, h => by
    have ih := take_getD_eq d l G (by rw [List.length_cons] at h; omega)
    rw [List.take_succ_cons, List.getD_cons_succ, List.cons_append, ih]

theorem isPow2_two_pow (d : ℕ) : isPow2 (2 ^ d) = true := by
  have h1 : (2 ^ d &&& (2 ^ d - 1)) = 0 := by rw [Nat.and_two_pow_sub_one_eq_mod, Nat.mod_self]
  simp [isPow2, h1]

/-- **`challenge_indices` of a power-of-two bound returns indices below the bound** (lane L22's `idxOf_lt`). -/
theorem challengeIndices_some (H : HIn → Dig) (n bound : ℕ) (t : Tr) (hb : isPow2 bound = true) (hn : 0 < n)
    (hpos : 0 < bound) :
    ∃ idx t', t.challengeIndices H n bound = some (idx, t') ∧ idx.length = n ∧ ∀ x ∈ idx, x < bound :=
  ⟨_, _, challengeIndices_sqDs H n bound t hb hn, by rw [idxOf_length, sqDs_length]; omega,
    idxOf_lt bound n hpos _⟩

end Lists

/-! ## The row combination on the words -/

section Comb

/-- **`Σ_i ρ_i·row_i[k]`** on the words (`fold_rows_host`: the base-field rows under `Fp2` weights, left to right). -/
def combAt (rho : List Fp2) (rs : List (List Fp)) (k : ℕ) : Fp2 :=
  dotB rho (rs.map (fun r => r.getD k Fp.zero))

/-- **The combined clear vector** of `w` entries (`fold_rows_multi_zk`: the message fold, then the pad fold). -/
def combVec (w : ℕ) (rho : List Fp2) (rs : List (List Fp)) : List Fp2 :=
  (List.range w).map (combAt rho rs)

theorem combVec_length (w : ℕ) (rho : List Fp2) (rs : List (List Fp)) : (combVec w rho rs).length = w := by
  rw [combVec, List.length_map, List.length_range]

theorem combVec_getD (w : ℕ) (rho : List Fp2) (rs : List (List Fp)) (k : ℕ) (hk : k < w) :
    (combVec w rho rs).getD k Fp2.zero = combAt rho rs k := by
  unfold combVec
  rw [getD_map_lt' (combAt rho rs) (List.range w) k (by rw [List.length_range]; exact hk) 0 Fp2.zero,
    List.getD_eq_getElem?_getD, List.getElem?_range hk, Option.getD_some]

/-- A base-field row as a clear vector (`Fp2` words with zero second coordinate). -/
def liftRow (r : List Fp) : List Fp2 := r.map Fp2.fromBase

theorem liftRow_getD (r : List Fp) (k : ℕ) : (liftRow r).getD k Fp2.zero = Fp2.fromBase (r.getD k Fp.zero) := by
  unfold liftRow
  by_cases h : k < r.length
  · exact getD_map_lt' Fp2.fromBase r k h Fp.zero Fp2.zero
  · rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD,
      List.getElem?_eq_none (by rw [List.length_map]; omega), List.getElem?_eq_none (by omega)]
    rfl

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem toK_liftRow (r : List Fp) (k : ℕ) :
    ((liftRow r).getD k Fp2.zero).toK U = algebraMap GF K (r.getD k Fp.zero).toGF := by
  rw [liftRow_getD, Fp2.toK_fromBase]

/-- **The word combination is the field's**: `Σ_i ρ_i·row_i[k]` over the `rows` rows. -/
theorem toK_combAt (rho : List Fp2) (rs : List (List Fp)) (hr : rho.length = rs.length) (k : ℕ) :
    (combAt rho rs k).toK U
      = ∑ i ∈ Finset.range rs.length, (rho.getD i Fp2.zero).toK U
          * algebraMap GF K ((rs.getD i []).getD k Fp.zero).toGF := by
  unfold combAt
  rw [toK_dotB U rho _ rs.length hr (by rw [List.length_map]),
    Finset.sum_range (fun i => (rho.getD i Fp2.zero).toK U * algebraMap GF K ((rs.getD i []).getD k Fp.zero).toGF)]
  refine Finset.sum_congr rfl (fun i _ => ?_)
  rw [getD_map_lt' (fun r : List Fp => r.getD k Fp.zero) rs i i.isLt [] Fp.zero]

theorem toK_combVec (w : ℕ) (rho : List Fp2) (rs : List (List Fp)) (hr : rho.length = rs.length) (k : ℕ)
    (hk : k < w) :
    ((combVec w rho rs).getD k Fp2.zero).toK U
      = ∑ i ∈ Finset.range rs.length, (rho.getD i Fp2.zero).toK U
          * ((liftRow (rs.getD i [])).getD k Fp2.zero).toK U := by
  rw [combVec_getD w rho rs k hk, toK_combAt U rho rs hr k]
  refine Finset.sum_congr rfl (fun i _ => ?_)
  rw [toK_liftRow]

/-- **The encoder is linear in the row combination**: the encoded value of the combined clear vector at a point is
the combination of the rows' encoded values (`encPoly` is linear in the message and in the pad). -/
theorem encK_combVec {n : ℕ} (R : RowForm K n) (Q : ℕ) (rho : List Fp2) (rs : List (List Fp))
    (hr : rho.length = rs.length) (x : K) :
    encK U R Q (combVec (n + Q) rho rs) x
      = ∑ i ∈ Finset.range rs.length, (rho.getD i Fp2.zero).toK U * encK U R Q (liftRow (rs.getD i [])) x := by
  have hv : vecK U n (combVec (n + Q) rho rs)
      = ∑ i ∈ Finset.range rs.length, (rho.getD i Fp2.zero).toK U • vecK U n (liftRow (rs.getD i [])) := by
    funext t
    rw [Finset.sum_apply]
    simp only [Pi.smul_apply, smul_eq_mul]
    exact toK_combVec U (n + Q) rho rs hr t (by have := t.isLt; omega)
  have hp : padK U n Q (combVec (n + Q) rho rs)
      = ∑ i ∈ Finset.range rs.length, (rho.getD i Fp2.zero).toK U • padK U n Q (liftRow (rs.getD i [])) := by
    funext k
    rw [Finset.sum_apply]
    simp only [Pi.smul_apply, smul_eq_mul]
    exact toK_combVec U (n + Q) rho rs hr (n + k) (by have := k.isLt; omega)
  unfold encK encPoly
  rw [hv, hp, map_sum, map_sum, eval_add, eval_mul, eval_finsetSum, eval_finsetSum, Finset.mul_sum,
    ← Finset.sum_add_distrib]
  refine Finset.sum_congr rfl (fun i _ => ?_)
  simp only [map_smul, eval_smul, smul_eq_mul, eval_add, eval_mul]
  ring

end Comb

/-! ## One commitment's honest data -/

section TableDefs

/-- **One commitment's honest data**: the rows (each `n` message words, then `Q` pad words; the mask rows are rows
like the others), the encoded column at every position, and the leaf salts. -/
structure Table where
  rows : List (List Fp)
  cols : ℕ → List Fp
  salts : ℕ → Dig

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **The committed columns are the encoder's values** (`encode_row_zk` row by row): column `j` holds, for every row,
the value at the column's point `pt j` of the row's encoded polynomial (L10's `encK` of the row as a clear vector). -/
def ColsHonest {n : ℕ} (R : RowForm K n) (Q : ℕ) (pt : ℕ → Fp) (N : ℕ) (T : Table) : Prop :=
  ∀ j, j < N → (T.cols j).length = T.rows.length
    ∧ ∀ i, i < T.rows.length → algebraMap GF K ((T.cols j).getD i Fp.zero).toGF
        = encK U R Q (liftRow (T.rows.getD i [])) (algebraMap GF K (pt j).toGF)

variable (H : HIn → Dig) (tag : MTag)

/-- The salted leaf of column `j` (`salt_leaf_keyed` of `hash_column_keyed`). -/
def leafAt (T : Table) (j : ℕ) : Dig := saltLeaf H tag (colDigest H tag (T.cols j)) (T.salts j)

/-- **The honest root** (`MerkleTree::build_keyed` over the `2^depth` salted leaves). -/
def rootOf (depth : ℕ) (T : Table) : Dig := ZK60.Complete.treeRoot (merkleEnc tag) H depth (leafAt H tag T)

/-- **The honest path** of column `j` (`MerkleTree::path`). -/
def pathOf (depth : ℕ) (T : Table) (j : ℕ) : List Dig :=
  ZK60.Complete.treePath (merkleEnc tag) H depth (leafAt H tag T) j

theorem pathOf_length (depth : ℕ) (T : Table) (j : ℕ) : (pathOf H tag depth T j).length = depth :=
  ZK60.Complete.treePath_length (merkleEnc tag) H depth _ j

/-- **The honest path verifies** against the honest root, from the column's salted leaf (`verify_path_keyed`). -/
theorem verifyPath_honest (depth : ℕ) (T : Table) (j : ℕ) (hj : j < 2 ^ depth) :
    verifyPath H tag (rootOf H tag depth T) j (saltLeaf H tag (colDigest H tag (T.cols j)) (T.salts j))
      (pathOf H tag depth T j) = true := by
  unfold verifyPath
  rw [decide_eq_true_eq, foldPath_eq_climb]
  exact ZK60.Complete.climb_treePath (merkleEnc tag) H depth (leafAt H tag T) j hj

end TableDefs

/-! ## True claims -/

section Truth

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **The value a pair of weights takes on the rows**: `Σ_i rw_i·Σ_t row_i[t]·cw_t` (row weights `rw`, column weights
`cw` over the `n` message positions). -/
def tabVal (n : ℕ) (rs : List (List Fp)) (rw cw : List Fp2) : K :=
  ∑ i ∈ Finset.range rs.length, (rw.getD i Fp2.zero).toK U
    * ∑ t ∈ Finset.range n, algebraMap GF K ((rs.getD i []).getD t Fp.zero).toGF * (cw.getD t Fp2.zero).toK U

/-- A group member `(row weights, value)` is true of the rows under the group's column weights. -/
def MemTrue (n : ℕ) (rs : List (List Fp)) (cw : List Fp2) (m : List Fp2 × Fp2) : Prop :=
  m.2.toK U = tabVal U n rs m.1 cw

/-- **A claim is true of the committed rows**: its value is the functional its own weights define (`zpart_weights`
over the rows, `zkey_weights` over the columns: `Σ parts coef·MLE(slice)(point)` as the PCS reads it). -/
def ClaimTrue (n logCols : ℕ) (rs : List (List Fp)) (c : ZClaim) : Prop :=
  MemTrue U n rs (zkeyWeights (claimWeights c rs.length logCols).2 logCols) ((claimWeights c rs.length logCols).1, c.value)

/-- The fold's invariant: one key per group, each group's column weights its key's, every member true of its group's
column weights. -/
def TInv (n logCols : ℕ) (rs : List (List Fp)) (st : List ZKey × List (List Fp2 × List (List Fp2 × Fp2))) : Prop :=
  st.1.length = st.2.length
    ∧ (∀ g, g < st.2.length → (st.2.getD g ([], [])).1 = zkeyWeights (st.1.getD g ⟨[], 0, 0⟩) logCols)
    ∧ ∀ g, g < st.2.length → ∀ m ∈ (st.2.getD g ([], [])).2, MemTrue U n rs (st.2.getD g ([], [])).1 m

theorem tInv_step (n logCols : ℕ) (rs : List (List Fp)) (st : List ZKey × List (List Fp2 × List (List Fp2 × Fp2)))
    (c : ZClaim) (hc : ClaimTrue U n logCols rs c) (h : TInv U n logCols rs st) :
    TInv U n logCols rs (groupStep rs.length logCols st c) := by
  obtain ⟨hl, hcw, hmem⟩ := h
  rcases hk : keyIdx st.1 (claimWeights c rs.length logCols).2 with _ | gi
  · have e : groupStep rs.length logCols st c = (st.1 ++ [(claimWeights c rs.length logCols).2],
        st.2 ++ [(zkeyWeights (claimWeights c rs.length logCols).2 logCols,
          [((claimWeights c rs.length logCols).1, c.value)])]) := by
      simp only [groupStep, hk]
    rw [e]
    refine ⟨by simp [hl], ?_, ?_⟩
    · intro g hg
      simp only [List.length_append, List.length_singleton] at hg
      by_cases hg' : g < st.2.length
      · rw [getD_append' _ _ _ _ hg', getD_append' _ _ _ _ (by omega)]
        exact hcw g hg'
      · have hge : g = st.2.length := by omega
        subst hge
        rw [getD_append_right' st.2 _ _ st.2.length le_rfl, getD_append_right' st.1 _ _ st.2.length (by omega),
          Nat.sub_self, ← hl, Nat.sub_self]
        rfl
    · intro g hg m hm
      simp only [List.length_append, List.length_singleton] at hg
      by_cases hg' : g < st.2.length
      · have e1 : (st.2 ++ [(zkeyWeights (claimWeights c rs.length logCols).2 logCols,
            [((claimWeights c rs.length logCols).1, c.value)])]).getD g ([], []) = st.2.getD g ([], []) :=
          getD_append' _ _ _ _ hg'
        rw [e1] at hm ⊢
        exact hmem g hg' m hm
      · have hge : g = st.2.length := by omega
        subst hge
        have e1 : (st.2 ++ [(zkeyWeights (claimWeights c rs.length logCols).2 logCols,
            [((claimWeights c rs.length logCols).1, c.value)])]).getD st.2.length ([], [])
            = (zkeyWeights (claimWeights c rs.length logCols).2 logCols,
              [((claimWeights c rs.length logCols).1, c.value)]) := by
          rw [getD_append_right' st.2 _ _ st.2.length le_rfl, Nat.sub_self]
          rfl
        rw [e1] at hm ⊢
        rw [List.mem_singleton] at hm
        subst hm
        exact hc
  · have e : groupStep rs.length logCols st c
        = (st.1, pushAt st.2 gi ((claimWeights c rs.length logCols).1, c.value)) := by
      simp only [groupStep, hk]
    obtain ⟨hgi, hkey⟩ := keyIdx_spec hk
    rw [e]
    refine ⟨by simp only [pushAt_length]; exact hl, ?_, ?_⟩
    · intro g hg
      simp only [pushAt_length] at hg
      simp only [pushAt_getD]
      split_ifs
      · exact hcw g hg
      · exact hcw g hg
    · intro g hg m hm
      simp only [pushAt_length] at hg
      by_cases hgg : g = gi ∧ gi < st.2.length
      · have e1 : (pushAt st.2 gi ((claimWeights c rs.length logCols).1, c.value)).getD g ([], [])
            = ((st.2.getD g ([], [])).1,
              (st.2.getD g ([], [])).2 ++ [((claimWeights c rs.length logCols).1, c.value)]) := by
          rw [pushAt_getD, ite_eq_left hgg]
        rw [e1] at hm ⊢
        rcases List.mem_append.mp hm with hm | hm
        · exact hmem g hg m hm
        · rw [List.mem_singleton] at hm
          subst hm
          show MemTrue U n rs (st.2.getD g ([], [])).1 ((claimWeights c rs.length logCols).1, c.value)
          rw [hcw g hg, hgg.1, hkey]
          exact hc
      · have e1 : (pushAt st.2 gi ((claimWeights c rs.length logCols).1, c.value)).getD g ([], [])
            = st.2.getD g ([], []) := by
          rw [pushAt_getD, ite_eq_right hgg]
        rw [e1] at hm ⊢
        exact hmem g hg m hm

theorem tInv_foldl (n logCols : ℕ) (rs : List (List Fp)) : ∀ (cl : List ZClaim)
    (st : List ZKey × List (List Fp2 × List (List Fp2 × Fp2))), (∀ c ∈ cl, ClaimTrue U n logCols rs c) →
    TInv U n logCols rs st → TInv U n logCols rs (cl.foldl (groupStep rs.length logCols) st)
  | [], _, _, h => h
  | c :: cl, st, hc, h => by
    rw [List.foldl_cons]
    exact tInv_foldl n logCols rs cl _ (fun c' hc' => hc c' (List.mem_cons_of_mem _ hc'))
      (tInv_step U n logCols rs st c (hc c List.mem_cons_self) h)

/-- **True claims make true groups**: every member of every group `group_zclaims` forms is true of the rows under
its group's column weights. -/
theorem groupZclaims_true (n logCols : ℕ) (rs : List (List Fp)) (cl : List ZClaim)
    (hc : ∀ c ∈ cl, ClaimTrue U n logCols rs c) (g : ℕ) (hg : g < (groupZclaims cl rs.length logCols).length) :
    ∀ m ∈ ((groupZclaims cl rs.length logCols).getD g ([], [])).2,
      MemTrue U n rs ((groupZclaims cl rs.length logCols).getD g ([], [])).1 m := by
  obtain ⟨-, -, h⟩ := tInv_foldl U n logCols rs cl ([], []) hc
    ⟨rfl, fun g hg => absurd hg (by simp), fun g hg => absurd hg (by simp)⟩
  exact h g hg

end Truth

/-! ## The wanted values are canonical -/

section Want

theorem foldl_comb_canon : ∀ (l : List ((List Fp2 × Fp2) × Fp2)) (acc : List Fp2 × Fp2), acc.2.Canon →
    (l.foldl (fun acc p => (rhoAdd p.2 acc.1 p.1.1, acc.2.add (p.2.mul p.1.2))) acc).2.Canon
  | [], _, h => h
  | _ :: l, _, _ => by
    rw [List.foldl_cons]
    exact foldl_comb_canon l _ (Fp2.canon_add _ _)

theorem groupComb_canon (rows : ℕ) (members : List (List Fp2 × Fp2)) (lams : List Fp2) :
    (groupComb rows members lams).2.Canon := by
  unfold groupComb
  exact foldl_comb_canon _ _ Fp2.canon_zero

/-- Every wanted value of `zk_rhos` is canonical. -/
theorem zkRhosAux_want_canon (H : HIn → Dig) (rows : ℕ) :
    ∀ (gs : List (List Fp2 × List (List Fp2 × Fp2))) (t : Tr) (g : ℕ),
      ((zkRhosAux H rows gs t).2.1.getD g Fp2.zero).Canon
  | [], t, g => by
    have e : (zkRhosAux H rows [] t).2.1 = [] := rfl
    rw [e, List.getD_eq_getElem?_getD, List.getElem?_nil, Option.getD_none]
    exact Fp2.canon_zero
  | x :: xs, t, 0 => by
    have e : (zkRhosAux H rows (x :: xs) t).2.1 = (groupComb rows x.2 (t.challengeFp2Vec H x.2.length).1).2
        :: (zkRhosAux H rows xs (t.challengeFp2Vec H x.2.length).2).2.1 := rfl
    rw [e, List.getD_cons_zero]
    exact groupComb_canon _ _ _
  | x :: xs, t, g + 1 => by
    have e : (zkRhosAux H rows (x :: xs) t).2.1 = (groupComb rows x.2 (t.challengeFp2Vec H x.2.length).1).2
        :: (zkRhosAux H rows xs (t.challengeFp2Vec H x.2.length).2).2.1 := rfl
    rw [e, List.getD_cons_succ]
    exact zkRhosAux_want_canon H rows xs _ g

theorem canon_dotF (v c : List Fp2) : (dotF v c).Canon :=
  canon_foldl_add (fun p : Fp2 × Fp2 => p.1.mul p.2) _ _ Fp2.canon_zero

/-- Three nested sums, reordered: `Σ_t (Σ_i (Σ_j λ_j·w_{j,i})·a_{i,t})·c_t = Σ_j λ_j·Σ_i w_{j,i}·Σ_t a_{i,t}·c_t`. -/
theorem triple_swap {K : Type} [CommSemiring K] (n rows M : ℕ) (lam : ℕ → K) (w : ℕ → ℕ → K) (a : ℕ → ℕ → K)
    (c : ℕ → K) :
    ∑ t ∈ Finset.range n, (∑ i ∈ Finset.range rows, (∑ j ∈ Finset.range M, lam j * w j i) * a i t) * c t
      = ∑ j ∈ Finset.range M, lam j * ∑ i ∈ Finset.range rows, w j i * ∑ t ∈ Finset.range n, a i t * c t := by
  calc ∑ t ∈ Finset.range n, (∑ i ∈ Finset.range rows, (∑ j ∈ Finset.range M, lam j * w j i) * a i t) * c t
      = ∑ t ∈ Finset.range n, ∑ i ∈ Finset.range rows, ∑ j ∈ Finset.range M, lam j * w j i * a i t * c t := by
        simp only [Finset.sum_mul]
    _ = ∑ i ∈ Finset.range rows, ∑ t ∈ Finset.range n, ∑ j ∈ Finset.range M, lam j * w j i * a i t * c t :=
        Finset.sum_comm
    _ = ∑ i ∈ Finset.range rows, ∑ j ∈ Finset.range M, ∑ t ∈ Finset.range n, lam j * w j i * a i t * c t :=
        Finset.sum_congr rfl (fun _ _ => Finset.sum_comm)
    _ = ∑ j ∈ Finset.range M, ∑ i ∈ Finset.range rows, ∑ t ∈ Finset.range n, lam j * w j i * a i t * c t :=
        Finset.sum_comm
    _ = ∑ j ∈ Finset.range M, lam j * ∑ i ∈ Finset.range rows, w j i * ∑ t ∈ Finset.range n, a i t * c t := by
        refine Finset.sum_congr rfl (fun j _ => ?_)
        rw [Finset.mul_sum]
        refine Finset.sum_congr rfl (fun i _ => ?_)
        rw [Finset.mul_sum, Finset.mul_sum]
        refine Finset.sum_congr rfl (fun t _ => ?_)
        ring

end Want

/-! ## The honest opening prover -/

section Prove

variable (H : HIn → Dig) (tag : MTag)

/-- The claims' groups (`group_zclaims`). -/
def pGroups (prm : PcsPrm) (T : Table) (claims : List ZClaim) : List (List Fp2 × List (List Fp2 × Fp2)) :=
  groupZclaims claims T.rows.length prm.logCols

/-- `zk_rhos`: the groups' row combinations then the proximity weights, the wanted values, the transcript. -/
def pRhos (prm : PcsPrm) (T : Table) (claims : List ZClaim) (t : Tr) : List (List Fp2) × List Fp2 × Tr :=
  zkRhosAux H T.rows.length (pGroups prm T claims) t

/-- Every clear vector (`fold_rows_multi_zk`): the groups', then the proximity vector. -/
def pAll (prm : PcsPrm) (T : Table) (claims : List ZClaim) (t : Tr) : List (List Fp2) :=
  (pRhos H prm T claims t).1.map (fun rho => combVec (prm.n + prm.qPad) rho T.rows)

def pVecs (prm : PcsPrm) (T : Table) (claims : List ZClaim) (t : Tr) : List (List Fp2) :=
  (pAll H prm T claims t).take (pGroups prm T claims).length

def pProx (prm : PcsPrm) (T : Table) (claims : List ZClaim) (t : Tr) : List Fp2 :=
  (pAll H prm T claims t).getD (pGroups prm T claims).length []

/-- The transcript after the group vectors' and the proximity vector's absorbs. -/
def pT2 (prm : PcsPrm) (T : Table) (claims : List ZClaim) (t : Tr) : Tr :=
  (absorbVecs H (pVecs H prm T claims t) (pRhos H prm T claims t).2.2).absorbFp2 H pcsProxLabel (pProx H prm T claims t)

/-- The sampled column indices and the transcript after them. -/
def pIdx (prm : PcsPrm) (T : Table) (claims : List ZClaim) (t : Tr) : List ℕ × Tr :=
  ((pT2 H prm T claims t).challengeIndices H prm.nQ prm.nn).getD ([], pT2 H prm T claims t)

/-- **The honest opening prover** (`pcs::open_zk`): the opening and the transcript after it. -/
def pcsProve (prm : PcsPrm) (depth : ℕ) (T : Table) (claims : List ZClaim) (t : Tr) : OpeningZk × Tr :=
  (⟨pVecs H prm T claims t, pProx H prm T claims t,
    (pIdx H prm T claims t).1.map (fun j => (j, T.cols j, T.salts j, pathOf H tag depth T j))⟩,
    (pIdx H prm T claims t).2)

theorem pAll_length (prm : PcsPrm) (T : Table) (claims : List ZClaim) (t : Tr) :
    (pAll H prm T claims t).length = (pGroups prm T claims).length + 1 := by
  rw [pAll, List.length_map]
  exact (zkRhosAux_length H T.rows.length (pGroups prm T claims) t).1

theorem pAll_split (prm : PcsPrm) (T : Table) (claims : List ZClaim) (t : Tr) :
    pVecs H prm T claims t ++ [pProx H prm T claims t] = pAll H prm T claims t :=
  take_getD_eq [] _ _ (pAll_length H prm T claims t)

theorem pAll_getD (prm : PcsPrm) (T : Table) (claims : List ZClaim) (t : Tr) (g : ℕ)
    (hg : g < (pGroups prm T claims).length + 1) :
    (pAll H prm T claims t).getD g []
      = combVec (prm.n + prm.qPad) ((pRhos H prm T claims t).1.getD g []) T.rows := by
  unfold pAll
  exact getD_map_lt' _ _ g
    (lt_of_lt_of_eq hg (zkRhosAux_length H T.rows.length (pGroups prm T claims) t).1.symm) [] []

theorem pAll_mem_length (prm : PcsPrm) (T : Table) (claims : List ZClaim) (t : Tr) :
    ∀ v ∈ pAll H prm T claims t, v.length = prm.n + prm.qPad := by
  intro v hv
  unfold pAll at hv
  obtain ⟨rho, -, rfl⟩ := List.mem_map.mp hv
  exact combVec_length _ _ _

theorem pVecs_length (prm : PcsPrm) (T : Table) (claims : List ZClaim) (t : Tr) :
    (pVecs H prm T claims t).length = (pGroups prm T claims).length := by
  rw [pVecs, List.length_take, pAll_length]
  omega

theorem pVecs_getD (prm : PcsPrm) (T : Table) (claims : List ZClaim) (t : Tr) (g : ℕ)
    (hg : g < (pGroups prm T claims).length) :
    (pVecs H prm T claims t).getD g []
      = combVec (prm.n + prm.qPad) ((pRhos H prm T claims t).1.getD g []) T.rows := by
  rw [pVecs, getD_take_lt _ _ _ hg, pAll_getD H prm T claims t g (by omega)]

theorem pProx_length (prm : PcsPrm) (T : Table) (claims : List ZClaim) (t : Tr) :
    (pProx H prm T claims t).length = prm.n + prm.qPad := by
  rw [pProx, pAll_getD H prm T claims t _ (by omega)]
  exact combVec_length _ _ _

/-- **What the honest prover returns**: the sampled indices exist (`nn = 2^depth` is a power of two), there are `Q` of
them, each below `nn`, and the opening is the clear vectors and the columns at those indices. -/
theorem pcsProve_eq (prm : PcsPrm) (depth : ℕ) (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ) (T : Table)
    (claims : List ZClaim) (t : Tr) :
    ∃ idx t3, (pT2 H prm T claims t).challengeIndices H prm.nQ prm.nn = some (idx, t3) ∧ idx.length = prm.nQ
      ∧ (∀ x ∈ idx, x < prm.nn)
      ∧ pcsProve H tag prm depth T claims t
        = (⟨pVecs H prm T claims t, pProx H prm T claims t,
            idx.map (fun j => (j, T.cols j, T.salts j, pathOf H tag depth T j))⟩, t3) := by
  have hpow : isPow2 prm.nn = true := by rw [hnn]; exact isPow2_two_pow depth
  obtain ⟨idx, t3, hidx, hlen, hlt⟩ := challengeIndices_some H prm.nQ prm.nn (pT2 H prm T claims t) hpow hnQ
    (by rw [hnn]; exact Nat.two_pow_pos depth)
  have hpi : pIdx H prm T claims t = (idx, t3) := by
    unfold pIdx
    rw [hidx]
    rfl
  refine ⟨idx, t3, hidx, hlen, hlt, ?_⟩
  unfold pcsProve
  rw [hpi]

/-- **The honest opening's shape**: the clear vectors' count and lengths, the `Q` opened columns, each at an index
below `nn` with the committed column and a path of the tree's depth. -/
theorem pcsProve_shape (prm : PcsPrm) (depth : ℕ) (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ) (T : Table)
    (claims : List ZClaim) (t : Tr) :
    (pcsProve H tag prm depth T claims t).1.groupVecs.length = (groupZclaims claims T.rows.length prm.logCols).length
      ∧ (∀ v ∈ (pcsProve H tag prm depth T claims t).1.groupVecs, v.length = prm.n + prm.qPad)
      ∧ (pcsProve H tag prm depth T claims t).1.proxVec.length = prm.n + prm.qPad
      ∧ (pcsProve H tag prm depth T claims t).1.columns.length = prm.nQ
      ∧ ∀ c ∈ (pcsProve H tag prm depth T claims t).1.columns,
          c.1 < prm.nn ∧ c.2.1 = T.cols c.1 ∧ c.2.2.2.length = depth := by
  obtain ⟨idx, t3, -, hlen, hlt, hop⟩ := pcsProve_eq H tag prm depth hnn hnQ T claims t
  rw [hop]
  refine ⟨pVecs_length H prm T claims t, fun v hv => ?_, pProx_length H prm T claims t, ?_, fun c hc => ?_⟩
  · exact pAll_mem_length H prm T claims t v (List.mem_of_mem_take hv)
  · show (idx.map (fun j => ((j, T.cols j, T.salts j, pathOf H tag depth T j) : OCol))).length = prm.nQ
    rw [List.length_map, hlen]
  · obtain ⟨j, hj, rfl⟩ := List.mem_map.mp hc
    exact ⟨hlt j hj, rfl, pathOf_length H tag depth T j⟩

/-- **The honest opening's words are canonical** when the committed columns' are (the clear vectors are outputs of
the field's `add`). -/
theorem pcsProve_canon (prm : PcsPrm) (depth : ℕ) (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ) (T : Table)
    (hcan : ∀ j, ∀ x ∈ T.cols j, x.Canon) (claims : List ZClaim) (t : Tr) :
    (∀ v ∈ (pcsProve H tag prm depth T claims t).1.groupVecs, ∀ x ∈ v, x.Canon)
      ∧ (∀ x ∈ (pcsProve H tag prm depth T claims t).1.proxVec, x.Canon)
      ∧ ∀ c ∈ (pcsProve H tag prm depth T claims t).1.columns, ∀ x ∈ c.2.1, x.Canon := by
  have hall : ∀ v ∈ pAll H prm T claims t, ∀ x ∈ v, x.Canon := by
    intro v hv x hx
    unfold pAll at hv
    obtain ⟨rho, -, rfl⟩ := List.mem_map.mp hv
    unfold combVec at hx
    obtain ⟨k, -, rfl⟩ := List.mem_map.mp hx
    exact canon_dotB _ _
  obtain ⟨idx, t3, -, -, -, hop⟩ := pcsProve_eq H tag prm depth hnn hnQ T claims t
  rw [hop]
  refine ⟨fun v hv => hall v (List.mem_of_mem_take hv), fun x hx => ?_, fun c hc => ?_⟩
  · have hmem : pProx H prm T claims t ∈ pAll H prm T claims t := by
      rw [← pAll_split H prm T claims t]
      exact List.mem_append_right _ (List.mem_singleton_self _)
    exact hall _ hmem x hx
  · obtain ⟨j, -, rfl⟩ := List.mem_map.mp hc
    exact hcan j

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

/-- The members' row weights have `rows` entries (lane L22's `groupZclaims_lens`). -/
theorem pGroups_mem_length (prm : PcsPrm) (T : Table) (claims : List ZClaim) (g : ℕ)
    (hg : g < (pGroups prm T claims).length) :
    ∀ m ∈ ((pGroups prm T claims).getD g ([], [])).2, m.1.length = T.rows.length :=
  (groupZclaims_lens claims T.rows.length prm.logCols g hg).2

include hU in
/-- Every row combination of `zk_rhos` (the groups' and the proximity weights) has `rows` entries. -/
theorem pRhos_length (prm : PcsPrm) (T : Table) (claims : List ZClaim) (t : Tr) (g : ℕ)
    (hg : g < (pGroups prm T claims).length + 1) : ((pRhos H prm T claims t).1.getD g []).length = T.rows.length := by
  obtain ⟨h1, -, h3⟩ := zkRhosAux_K U hU H T.rows.length (pGroups prm T claims) t
    (fun g hg => pGroups_mem_length prm T claims g hg)
  by_cases hg' : g < (pGroups prm T claims).length
  · exact (h1 g hg').1
  · have e : g = (pGroups prm T claims).length := by omega
    subst e
    unfold pRhos
    rw [h3, List.length_map, List.length_drop, sqDs_length]
    omega

include hU in
/-- **The claim check passes**: the honest group vector's product with the group's column weights is the group's
wanted value, for true claims. -/
theorem claim_check (prm : PcsPrm) (T : Table) (claims : List ZClaim)
    (htrue : ∀ c ∈ claims, ClaimTrue U prm.n prm.logCols T.rows c) (t : Tr) (g : ℕ)
    (hg : g < (pGroups prm T claims).length) :
    dotF ((combVec (prm.n + prm.qPad) ((pRhos H prm T claims t).1.getD g []) T.rows).take prm.n)
        (((pGroups prm T claims).map (·.1)).getD g [])
      = (pRhos H prm T claims t).2.1.getD g Fp2.zero := by
  obtain ⟨h1, h2, -⟩ := zkRhosAux_K U hU H T.rows.length (pGroups prm T claims) t
    (fun g hg => pGroups_mem_length prm T claims g hg)
  have hρlen : ((pRhos H prm T claims t).1.getD g []).length = T.rows.length := (h1 g hg).1
  have hρK : ∀ i, i < T.rows.length → (((pRhos H prm T claims t).1.getD g []).getD i Fp2.zero).toK U
      = ∑ j ∈ Finset.range ((pGroups prm T claims).getD g ([], [])).2.length,
          (challengeFp2Of ((sqDs H t (nMem (pGroups prm T claims) + T.rows.length)).getD
            (offOf (pGroups prm T claims) g + j) zeroDig)).toK U
            * ((((pGroups prm T claims).getD g ([], [])).2.getD j ([], Fp2.zero)).1.getD i Fp2.zero).toK U :=
    (h1 g hg).2
  have hwK : ((pRhos H prm T claims t).2.1.getD g Fp2.zero).toK U
      = ∑ j ∈ Finset.range ((pGroups prm T claims).getD g ([], [])).2.length,
          (challengeFp2Of ((sqDs H t (nMem (pGroups prm T claims) + T.rows.length)).getD
            (offOf (pGroups prm T claims) g + j) zeroDig)).toK U
            * (((pGroups prm T claims).getD g ([], [])).2.getD j ([], Fp2.zero)).2.toK U := h2 g hg
  have hcw : ((pGroups prm T claims).map (·.1)).getD g [] = ((pGroups prm T claims).getD g ([], [])).1 :=
    getD_map_lt' (·.1) (pGroups prm T claims) g hg ([], []) []
  have hcwl : (((pGroups prm T claims).getD g ([], [])).1).length = prm.n :=
    (groupZclaims_lens claims T.rows.length prm.logCols g hg).1
  have hgt := groupZclaims_true U prm.n prm.logCols T.rows claims htrue g hg
  rw [hcw]
  refine Fp2.toK_injective U hU (canon_dotF _ _) (zkRhosAux_want_canon H _ _ _ _) ?_
  have hlen1 : ((combVec (prm.n + prm.qPad) ((pRhos H prm T claims t).1.getD g []) T.rows).take prm.n).length
      = prm.n := by
    rw [List.length_take, combVec_length]
    omega
  rw [toK_dotF U hU _ _ prm.n hlen1 hcwl]
  refine Eq.trans ?_ (Eq.trans (triple_swap prm.n T.rows.length ((pGroups prm T claims).getD g ([], [])).2.length
    (fun j => (challengeFp2Of ((sqDs H t (nMem (pGroups prm T claims) + T.rows.length)).getD
      (offOf (pGroups prm T claims) g + j) zeroDig)).toK U)
    (fun j i => ((((pGroups prm T claims).getD g ([], [])).2.getD j ([], Fp2.zero)).1.getD i Fp2.zero).toK U)
    (fun i k => algebraMap GF K ((T.rows.getD i []).getD k Fp.zero).toGF)
    (fun k => (((pGroups prm T claims).getD g ([], [])).1.getD k Fp2.zero).toK U)) ?_)
  · refine Finset.sum_congr rfl (fun k hk => ?_)
    have hk' : k < prm.n := Finset.mem_range.mp hk
    rw [getD_take_lt _ _ _ hk', combVec_getD _ _ _ k (by omega), toK_combAt U _ _ hρlen k]
    congr 1
    refine Finset.sum_congr rfl (fun i hi => ?_)
    rw [hρK i (Finset.mem_range.mp hi)]
  · refine Eq.trans ?_ hwK.symm
    refine Finset.sum_congr rfl (fun j hj => ?_)
    have hm := hgt _ (mem_of_getD_lt ((pGroups prm T claims).getD g ([], [])).2 j (Finset.mem_range.mp hj)
      ([], Fp2.zero))
    rw [show ((((pGroups prm T claims).getD g ([], [])).2.getD j ([], Fp2.zero)).2).toK U
      = tabVal U prm.n T.rows (((pGroups prm T claims).getD g ([], [])).2.getD j ([], Fp2.zero)).1
        ((pGroups prm T claims).getD g ([], [])).1 from hm]
    rfl

include hU in
/-- **One honestly opened column passes every check** (`ColOk`): its index, its length, its Merkle path, and every
combination's word equality with the encoded clear vectors. -/
theorem colOk_honest (prm : PcsPrm) (pt : ℕ → Fp) (ev : Fp → List (List Fp2) → List Fp2) (R : RowForm K prm.n)
    (hspec : ColEncSpec U R prm.qPad pt ev) (depth : ℕ) (hnn : prm.nn = 2 ^ depth) (T : Table)
    (hcols : ColsHonest U R prm.qPad pt prm.nn T) (claims : List ZClaim) (t : Tr) (j : ℕ) (hj : j < prm.nn) :
    ColOk H tag (rootOf H tag depth T) T.rows.length (pRhos H prm T claims t).1
      (fun j => ev (pt j) (pVecs H prm T claims t ++ [pProx H prm T claims t]))
      (j, T.cols j, T.salts j, pathOf H tag depth T j) j := by
  refine ⟨rfl, (hcols j hj).1, verifyPath_honest H tag depth T j (by rw [← hnn]; exact hj), ?_⟩
  intro g hg
  have hg' : g < (pGroups prm T claims).length + 1 := by
    rw [← (zkRhosAux_length H T.rows.length (pGroups prm T claims) t).1]
    exact hg
  show dotB ((pRhos H prm T claims t).1.getD g []) (T.cols j)
    = (ev (pt j) (pVecs H prm T claims t ++ [pProx H prm T claims t])).getD g Fp2.zero
  rw [pAll_split]
  obtain ⟨-, hge⟩ := hspec j (pAll H prm T claims t) (pAll_mem_length H prm T claims t)
  obtain ⟨hcan, hval⟩ := hge g (by rw [pAll_length]; exact hg')
  have hρ := pRhos_length H U hU prm T claims t g hg'
  refine (colEq_iff_K U hU T.rows.length _ _ _ hcan hρ (hcols j hj).1).mpr ?_
  rw [hval, pAll_getD H prm T claims t g hg', encK_combVec U R prm.qPad _ _ hρ,
    ← Finset.sum_range (fun i => (((pRhos H prm T claims t).1.getD g []).getD i Fp2.zero).toK U
      * algebraMap GF K ((T.cols j).getD i Fp.zero).toGF)]
  refine Finset.sum_congr rfl (fun i hi => ?_)
  rw [(hcols j hj).2 i (Finset.mem_range.mp hi)]

include hU in
/-- **The executable opening verifier accepts the honest opening** (completeness of L10's `pcsVerify`, generic in the
parameters, the points and the column evaluator): for an honest table (`ColsHonest`), true claims, a tree of
`2^depth = nn` leaves and at least one sampled column, at EVERY hash function and from EVERY transcript, `pcsVerify`
returns the prover's transcript. -/
theorem pcsVerify_of_prove (prm : PcsPrm) (pt : ℕ → Fp) (ev : Fp → List (List Fp2) → List Fp2)
    (hev : ∀ x vs, (ev x vs).length = vs.length) (R : RowForm K prm.n) (hspec : ColEncSpec U R prm.qPad pt ev)
    (depth : ℕ) (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ) (hq : prm.nQ ≤ prm.qPad) (T : Table)
    (hcols : ColsHonest U R prm.qPad pt prm.nn T) (claims : List ZClaim)
    (htrue : ∀ c ∈ claims, ClaimTrue U prm.n prm.logCols T.rows c) (t : Tr) :
    pcsVerify H tag prm pt ev (rootOf H tag depth T) T.rows.length prm.logCols claims
        (pcsProve H tag prm depth T claims t).1 t
      = .ok (pcsProve H tag prm depth T claims t).2 := by
  rw [pcsVerify_ok_iff H tag prm pt ev hev]
  obtain ⟨idx, t3, hidx, -, hlt, hop⟩ := pcsProve_eq H tag prm depth hnn hnQ T claims t
  rw [hop]
  unfold PcsOk
  refine ⟨rfl, hq, ?_, pVecs_length H prm T claims t, ?_, pProx_length H prm T claims t, idx, hidx, ?_, ?_⟩
  · intro c hc
    obtain ⟨j, -, rfl⟩ := List.mem_map.mp hc
    show (pathOf H tag depth T j).length = Nat.log2 prm.nn
    rw [hnn, Nat.log2_two_pow]
    exact pathOf_length H tag depth T j
  · intro g hg
    have hgG : g < (pGroups prm T claims).length := lt_of_lt_of_eq hg (pVecs_length H prm T claims t)
    show ((pVecs H prm T claims t).getD g []).length = prm.n + prm.qPad
      ∧ dotF (((pVecs H prm T claims t).getD g []).take prm.n) (((pGroups prm T claims).map (·.1)).getD g [])
        = (pRhos H prm T claims t).2.1.getD g Fp2.zero
    rw [pVecs_getD H prm T claims t g hgG]
    exact ⟨combVec_length _ _ _, claim_check H U hU prm T claims htrue t g hgG⟩
  · show (idx.map (fun j => (j, T.cols j, T.salts j, pathOf H tag depth T j))).length = idx.length
    rw [List.length_map]
  · intro k hk
    have hk' : k < idx.length := by
      have : k < (idx.map (fun j => (j, T.cols j, T.salts j, pathOf H tag depth T j))).length := hk
      rwa [List.length_map] at this
    have hcol : (idx.map (fun j => ((j, T.cols j, T.salts j, pathOf H tag depth T j) : OCol))).getD k
        (0, [], zeroDig, []) = (idx.getD k 0, T.cols (idx.getD k 0), T.salts (idx.getD k 0),
          pathOf H tag depth T (idx.getD k 0)) :=
      getD_map_lt' _ idx k hk' 0 _
    show ColOk H tag (rootOf H tag depth T) T.rows.length (pRhos H prm T claims t).1
      (fun j => ev (pt j) (pVecs H prm T claims t ++ [pProx H prm T claims t]))
      ((idx.map (fun j => ((j, T.cols j, T.salts j, pathOf H tag depth T j) : OCol))).getD k (0, [], zeroDig, []))
      (idx.getD k 0)
    rw [hcol]
    exact colOk_honest H tag U hU prm pt ev R hspec depth hnn T hcols claims t (idx.getD k 0)
      (hlt _ (mem_of_getD_lt idx k hk' 0))

end Prove

end ZK60.HonestOpen
