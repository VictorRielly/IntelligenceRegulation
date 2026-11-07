/-
D63 lane L22 (2026-11-07), part 3: **`M`'s executable check read in `K` is `MFinal` of the data it checks** (L20-3
(b) for `M`).

L10's `maskVerify_ok_iff` says the executable `M` check accepts exactly when `MaskOk` holds (the sum check, the wire
lengths, the indices, and per opened column the index, the length, the Merkle path, the product and the proximity
tests). L10's `mcol_iff_K`, `sum_iff_K`, `toK_combinedWeights` read those checks in `K`. Here they are assembled into
`SoundMProduct.lean`'s `MFinal` for the data `M`'s sub-protocol states (`maskCSubX`):

* `mEtaE`: `M`'s evaluation points `η_j = 7·ω_4096^j` in `K`, an embedding of `Fin 4096`;
* `mDataOf`: the `MData` of a functional list and a table of columns: the functionals' weights and values, the base
  rows (`2S + 2` per column), the proximity mask `u`, the fixed combinations `La` (`a_s = row 2s + U·row (2s + 1)`) and
  `Lb` (`b = row 2S + U·row (2S + 1)`);
* `comb_La`, `comb_Lb`, `mV_cw`, `mW_cw`: the combinations and `combined_weights` in `K`;
* **`maskOk_mFinal`**: if `MaskOk` holds and the table's column at every sampled index is the opened column there, then
  `MFinal` holds of `mDataOf` at `θ`, `q'`, `r`, `prox` and the indices the transcript gave.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.LinkW16Trace
import ZK60Formal.ExecOpeningBlock

set_option autoImplicit false

namespace ZK60.Exec.Link

open ZK60.Sound
open ZK60.Exec
open ZK60.Circuit (gP GF)
open scoped ENNReal
open Polynomial

section MField

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem cosetPt_toGF (ω : Fp) (j : ℕ) (hj : j < 2 ^ 64) : (cosetPt ω j).toGF = 7 * ω.toGF ^ j := by
  rw [cosetPt, Fp.toGF_mul, Fp.toGF_pow, seven_toGF, u64_ofNat_toNat hj]

omit [Field K] [Algebra GF K] in
theorem cosetPt12_inj : Function.Injective (fun j : Fin (2 ^ 12) => (cosetPt (rootFp 12) j).toGF) := by
  intro i j hij
  have hi : (i : ℕ) < 2 ^ 64 := lt_of_lt_of_le i.isLt (by norm_num)
  have hj : (j : ℕ) < 2 ^ 64 := lt_of_lt_of_le j.isLt (by norm_num)
  simp only at hij
  rw [cosetPt_toGF _ _ hi, cosetPt_toGF _ _ hj] at hij
  have hω : IsPrimitiveRoot (rootFp 12).toGF (2 ^ 12) := rootFp_isPrimitiveRoot (by norm_num)
  exact cosetPts_injective (N := 2 ^ 12) seven_ne_zero_GF hω hij

/-- **`M`'s evaluation points** `η_j = 7·ω_4096^j`, in `K`. -/
noncomputable def mEtaE : Fin (2 ^ 12) ↪ K :=
  ⟨fun j => algebraMap GF K (cosetPt (rootFp 12) j).toGF,
    fun _ _ hij => cosetPt12_inj ((algebraMap GF K).injective hij)⟩

theorem mEtaE_apply (j : Fin (2 ^ 12)) : mEtaE (K := K) j = algebraMap GF K (cosetPt (rootFp 12) j).toGF := rfl

/-- `M`'s message root `ω_512`, in `K`. -/
noncomputable def mOmega : K := algebraMap GF K (rootFp 9).toGF

/-- The empty functional. -/
def mf0 : Block.MaskFunctional := ⟨[], Fp2.zero⟩

/-- **The data `M` checks**: the functionals `fs` (their weights and values), and a table of columns (`cols j` the
column at index `j`: `2S + 2` base rows, then the proximity mask `u`'s two words). -/
noncomputable def mDataOf (S nF : ℕ) (fs : List Block.MaskFunctional) (cols : Fin (2 ^ 12) → List Fp) :
    MData K (Fin (2 ^ 12)) (Fin S) (Fin (2 * S + 2)) nF 512 where
  wt i s j := fwt U (toMF (fs.getD i mf0)) s j
  val i := (fs.getD i mf0).value.toK U
  Ub i j := algebraMap GF K ((cols j).getD i Fp.zero).toGF
  u j := (fp2Of (cols j) (2 * S + 2) (2 * S + 3)).toK U
  La s i := (if (i : ℕ) = 2 * (s : ℕ) then 1 else 0) + U * (if (i : ℕ) = 2 * (s : ℕ) + 1 then 1 else 0)
  Lb i := (if (i : ℕ) = 2 * S then 1 else 0) + U * (if (i : ℕ) = 2 * S + 1 then 1 else 0)

omit [Algebra GF K] in
theorem sum_ite_val {n : ℕ} (a : ℕ) (ha : a < n) (f : Fin n → K) :
    ∑ i : Fin n, (if (i : ℕ) = a then f i else 0) = f ⟨a, ha⟩ := by
  rw [Finset.sum_eq_single ⟨a, ha⟩]
  · simp
  · intro i _ hi
    rw [ite_eq_right (fun h => hi (Fin.ext h))]
  · intro h
    exact absurd (Finset.mem_univ _) h

omit [Algebra GF K] in
theorem sum_ind2 {n : ℕ} (a b : ℕ) (ha : a < n) (hb : b < n) (x : Fin n → K) :
    ∑ i : Fin n, ((if (i : ℕ) = a then 1 else 0) + U * (if (i : ℕ) = b then 1 else 0)) * x i
      = x ⟨a, ha⟩ + U * x ⟨b, hb⟩ := by
  have e : ∀ i : Fin n, ((if (i : ℕ) = a then (1 : K) else 0) + U * (if (i : ℕ) = b then 1 else 0)) * x i
      = (if (i : ℕ) = a then x i else 0) + U * (if (i : ℕ) = b then x i else 0) := by
    intro i
    split_ifs <;> ring
  simp only [e, Finset.sum_add_distrib, ← Finset.mul_sum]
  rw [sum_ite_val a ha, sum_ite_val b hb]

/-- `a_s` at a column: `row 2s + U·row (2s + 1)`. -/
theorem comb_La (S nF : ℕ) (fs : List Block.MaskFunctional) (cols : Fin (2 ^ 12) → List Fp) (s : Fin S)
    (j : Fin (2 ^ 12)) :
    comb (mDataOf U S nF fs cols).Ub ((mDataOf U S nF fs cols).La s) j
      = (fp2Of (cols j) (2 * s) (2 * s + 1)).toK U := by
  rw [comb_apply, toK_fp2Of]
  exact sum_ind2 U (2 * (s : ℕ)) (2 * (s : ℕ) + 1) (by omega) (by omega)
    (fun i => algebraMap GF K ((cols j).getD i Fp.zero).toGF)

/-- `b` at a column: `row 2S + U·row (2S + 1)`. -/
theorem comb_Lb (S nF : ℕ) (fs : List Block.MaskFunctional) (cols : Fin (2 ^ 12) → List Fp) (j : Fin (2 ^ 12)) :
    comb (mDataOf U S nF fs cols).Ub (mDataOf U S nF fs cols).Lb j = (fp2Of (cols j) (2 * S) (2 * S + 1)).toK U := by
  rw [comb_apply, toK_fp2Of]
  exact sum_ind2 U (2 * S) (2 * S + 1) (by omega) (by omega)
    (fun i => algebraMap GF K ((cols j).getD i Fp.zero).toGF)

theorem getD_map' {α β : Type} (f : α → β) (l : List α) (i : ℕ) (d : α) :
    (l.map f).getD i (f d) = f (l.getD i d) := by
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_map]
  cases l[i]? <;> rfl

theorem getD_append' {α : Type} (l l' : List α) (d : α) (n : ℕ) (h : n < l.length) :
    (l ++ l').getD n d = l.getD n d := by
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_append_left h]

theorem getD_append_right' {α : Type} (l l' : List α) (d : α) (n : ℕ) (h : l.length ≤ n) :
    (l ++ l').getD n d = l'.getD (n - l.length) d := by
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_append_right h]

theorem getD_map_toMF (fs : List Block.MaskFunctional) (i : ℕ) :
    (fs.map toMF).getD i default = toMF (fs.getD i mf0) := by
  rw [show (default : MaskFunctional) = toMF mf0 from rfl, getD_map']

omit [Algebra GF K] in
theorem sum_fin_cast {n m : ℕ} (h : n = m) (f : ℕ → K) : ∑ i : Fin n, f i = ∑ i : Fin m, f i := by
  subst h
  rfl

theorem get_map_toMF (fs : List Block.MaskFunctional) (i : Fin (fs.map toMF).length) :
    (fs.map toMF).get i = toMF (fs.getD i mf0) := by
  rw [List.get_eq_getElem, ← getD_eq_get _ _ default i.isLt, getD_map_toMF]

variable (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **`combined_weights`' value is `mV 1`** of the data's values. -/
theorem mV_cw (S : ℕ) (fs : List Block.MaskFunctional) (cols : Fin (2 ^ 12) → List Fp) (θ : Fp2) :
    mV 1 (mDataOf U S fs.length fs cols).val (θ.toK U) = (combinedWeights S (fs.map toMF) θ).2.toK U := by
  rw [(toK_combinedWeights U hU S (fs.map toMF) θ).1]
  show ∑ i : Fin fs.length, θ.toK U ^ ((i : ℕ) + 1) * (fs.getD i mf0).value.toK U
    = ∑ i : Fin (fs.map toMF).length, θ.toK U ^ ((i : ℕ) + 1) * ((fs.map toMF).get i).value.toK U
  simp only [get_map_toMF]
  exact sum_fin_cast (List.length_map _).symm (fun i => θ.toK U ^ (i + 1) * (fs.getD i mf0).value.toK U)

include hU in
/-- **`combined_weights`' entries are `mW 1`** of the data's weights. -/
theorem mW_cw (S : ℕ) (fs : List Block.MaskFunctional) (cols : Fin (2 ^ 12) → List Fp) (θ : Fp2) (s : Fin S) :
    mW 1 (mDataOf U S fs.length fs cols).wt (θ.toK U) s
      = vecK U mMsg ((combinedWeights S (fs.map toMF) θ).1.getD s []) := by
  funext j
  simp only [vecK]
  rw [(toK_combinedWeights U hU S (fs.map toMF) θ).2 s j s.isLt j.isLt]
  show ∑ i : Fin fs.length, θ.toK U ^ ((i : ℕ) + 1) * fwt U (toMF (fs.getD i mf0)) s j
    = ∑ i : Fin (fs.map toMF).length, θ.toK U ^ ((i : ℕ) + 1) * fwt U ((fs.map toMF).get i) s j
  simp only [get_map_toMF]
  exact sum_fin_cast (List.length_map _).symm (fun i => θ.toK U ^ (i + 1) * fwt U (toMF (fs.getD i mf0)) s j)

theorem getD_toMO (mo : Block.MaskOpening) (k : ℕ) :
    (toMO mo).columns.getD k (0, [], zeroDig, []) = toOCol (mo.columns.getD k ⟨0, [], zeroDig, []⟩) := by
  show (mo.columns.map toOCol).getD k (toOCol ⟨0, [], zeroDig, []⟩) = _
  rw [getD_map']

theorem flatMap_idxVals_length (b : ℕ) : ∀ ds : List Dig, (ds.flatMap (idxVals b)).length = 4 * ds.length
  | [] => rfl
  | d :: ds => by
    rw [List.flatMap_cons, List.length_append, idxVals_length, flatMap_idxVals_length b ds, List.length_cons]
    ring

theorem idxOf_length (b n : ℕ) (ds : List Dig) : (idxOf b n ds).length = min n (4 * ds.length) := by
  rw [idxOf, List.length_take, flatMap_idxVals_length]

theorem idxOf_lt (b n : ℕ) (hb : 0 < b) (ds : List Dig) : ∀ i ∈ idxOf b n ds, i < b := by
  intro i hi
  obtain ⟨d, -, hd⟩ := List.mem_flatMap.mp (List.mem_of_mem_take hi)
  obtain ⟨c, -, rfl⟩ := List.mem_map.mp hd
  exact lt_of_le_of_lt Nat.and_le_right (by omega)

include hU in
/-- **`M`'s executable check, read in `K`, is `MFinal`** (L20-3 (b) for `M`). If `MaskOk` holds (`maskVerify`
accepted at `t`, L10's `maskVerify_ok_iff`) with the indices `idx`, and the table `cols` has, at every sampled index,
the opened column there (the extraction agreeing with the opening), then `MFinal` holds of `mDataOf` at the
transcript's `θ`, `q'`, `r`, `prox` and indices: the state `M`'s sub-protocol reaches at the end of its three rounds. -/
theorem maskOk_mFinal (H : HIn → Dig) (tag : MTag) (root : Dig) (S : ℕ) (fs : List Block.MaskFunctional)
    (mo : Block.MaskOpening) (hcan : Block.MaskCanon mo) (t t' : Tr)
    (hok : MaskOk H tag (rootFp 9) (rootFp 12) root S (fs.map toMF) (toMO mo) t t') (idx : List ℕ)
    (hidx : ((((t.challengeFp2 H).2.absorbFp2 H maskQLabel mo.q).challengeFp2Vec H (2 * S + 2)).2.absorbFp2 H
      maskProxLabel mo.prox).challengeIndices H mQ mDom = some (idx, t'))
    (hJ : ∀ k : Fin mQ, idx.getD k 0 < 2 ^ 12) (cols : Fin (2 ^ 12) → List Fp)
    (hcols : ∀ k : Fin mQ, cols ⟨idx.getD k 0, hJ k⟩ = (mo.columns.getD k ⟨0, [], zeroDig, []⟩).col) :
    MFinal (mEtaE (K := K)) (mOmega (K := K)) 1023 (mDataOf U S fs.length fs cols) ((t.challengeFp2 H).1.toK U)
      (some (coefPoly (vecK U 1024 mo.q)))
      (fun i => (((((t.challengeFp2 H).2.absorbFp2 H maskQLabel mo.q).challengeFp2Vec H (2 * S + 2)).1).getD i
        Fp2.zero).toK U)
      (some (coefPoly (vecK U 1024 mo.prox))) (fun k : Fin mQ => (⟨idx.getD k 0, hJ k⟩ : Fin (2 ^ 12))) := by
  obtain ⟨hq, hsum, hp, idx', hidx', hlen, hcolok⟩ := hok
  have hii : idx = idx' := by
    have h2 := hidx.symm.trans hidx'
    simp only [Option.some.injEq, Prod.mk.injEq, and_true] at h2
    exact h2
  subst hii
  have hfold := cw_fold_spec U hU (t.challengeFp2 H).1 (fs.map toMF) _ Fp2.zero (t.challengeFp2 H).1
    (zeros_shape S mMsg) Fp2.canon_zero
  have hws : WShape S mMsg (combinedWeights S (fs.map toMF) (t.challengeFp2 H).1).1 := hfold.1
  have hvc : (combinedWeights S (fs.map toMF) (t.challengeFp2 H).1).2.Canon := hfold.2.1
  have hrs : ((((t.challengeFp2 H).2.absorbFp2 H maskQLabel mo.q).challengeFp2Vec H (2 * S + 2)).1).length
      = 2 * S + 2 := by
    rw [challengeFp2Vec_sqDs, List.length_map, sqDs_length]
  have h512 : IsPrimitiveRoot (rootFp 9).toGF 512 := by simpa using rootFp_isPrimitiveRoot (k := 9) (by norm_num)
  have h4096 : IsPrimitiveRoot (rootFp 12).toGF 4096 := by
    simpa using rootFp_isPrimitiveRoot (k := 12) (by norm_num)
  have hlenQ : (toMO mo).columns.length = mQ := by
    rw [hlen]
    have h3 := hidx
    rw [challengeIndices_sqDs H mQ mDom _ (by decide) (by decide)] at h3
    simp only [Option.some.injEq, Prod.mk.injEq] at h3
    rw [← h3.1, idxOf_length, sqDs_length]
    decide
  -- per sampled column, the two checks in `K`
  have hcolK : ∀ k : Fin mQ,
      let c := mo.columns.getD k ⟨0, [], zeroDig, []⟩
      c.j = idx.getD k 0 ∧ c.col.length = 2 * S + 4 ∧
      ((fp2Of c.col (2 * S) (2 * S + 1)).toK U
          + ∑ s : Fin S, (fp2Of c.col (2 * s) (2 * s + 1)).toK U
            * (mInterp (mOmega (K := K)) (vecK U mMsg
                ((combinedWeights S (fs.map toMF) (t.challengeFp2 H).1).1.getD s []))).eval
              (algebraMap GF K (cosetPt (rootFp 12) c.j).toGF)
        = (coefPoly (vecK U (2 * mMsg) mo.q)).eval (algebraMap GF K (cosetPt (rootFp 12) c.j).toGF))
      ∧ ((fp2Of c.col (2 * S + 2) (2 * S + 3)).toK U
          + ∑ i : Fin (2 * S + 2), (((((t.challengeFp2 H).2.absorbFp2 H maskQLabel mo.q).challengeFp2Vec H
              (2 * S + 2)).1).getD i Fp2.zero).toK U * algebraMap GF K (c.col.getD i Fp.zero).toGF
        = (coefPoly (vecK U (2 * mMsg) mo.prox)).eval (algebraMap GF K (cosetPt (rootFp 12) c.j).toGF)) := by
    intro k
    have hk : (k : ℕ) < (toMO mo).columns.length := by rw [hlenQ]; exact k.isLt
    have hok := hcolok k hk
    rw [getD_toMO] at hok
    obtain ⟨hj, hcl, -, -, hprod, hprox⟩ := hok
    have hmem : mo.columns.getD k ⟨0, [], zeroDig, []⟩ ∈ mo.columns :=
      mem_of_getD_lt mo.columns k (by simpa [toMO] using hk) _
    have hcc : ∀ x ∈ (mo.columns.getD k ⟨0, [], zeroDig, []⟩).col, x.Canon := hcan.2.2 _ hmem
    have key := mcol_iff_K U hU (rootFp 9) (rootFp 12) h512 h4096 S
      (combinedWeights S (fs.map toMF) (t.challengeFp2 H).1).1 hws.1 (fun w hw => (hws.2 w hw).1) mo.q mo.prox
      ((((t.challengeFp2 H).2.absorbFp2 H maskQLabel mo.q).challengeFp2Vec H (2 * S + 2)).1) hq hp hrs
      (mo.columns.getD k ⟨0, [], zeroDig, []⟩).col hcc hcl (mo.columns.getD k ⟨0, [], zeroDig, []⟩).j
    exact ⟨hj, hcl, key.1.mp hprod, key.2.mp hprox⟩
  refine ⟨_, _, rfl, rfl, coefPoly_natDegree_lt (by norm_num) _,
    Nat.le_of_lt_succ (coefPoly_natDegree_lt (by norm_num) _), ⟨⟨?_, ?_⟩, ?_⟩⟩
  · -- the sum check
    rw [coefPoly_coeff, coefPoly_coeff, dite_eq_left (by norm_num : 0 < 1024),
      dite_eq_left (by norm_num : 512 < 1024), mV_cw U hU S fs cols]
    exact (sum_iff_K U hU mo.q hcan.1 _ hvc).mp hsum
  · -- the product test at every sampled column
    intro k
    obtain ⟨hj, -, hprod, -⟩ := hcolK k
    rw [comb_Lb, hcols k]
    simp only [comb_La, hcols k, mW_cw U hU S fs cols, mEtaE_apply]
    rw [← hj]
    exact hprod
  · -- the proximity test at every sampled column
    intro k
    obtain ⟨hj, -, -, hprox⟩ := hcolK k
    rw [comb_apply]
    show (fp2Of (cols ⟨idx.getD k 0, hJ k⟩) (2 * S + 2) (2 * S + 3)).toK U
        + ∑ i : Fin (2 * S + 2), (((((t.challengeFp2 H).2.absorbFp2 H maskQLabel mo.q).challengeFp2Vec H
            (2 * S + 2)).1).getD i Fp2.zero).toK U
          * algebraMap GF K (((cols ⟨idx.getD k 0, hJ k⟩)).getD i Fp.zero).toGF
      = (coefPoly (vecK U 1024 mo.prox)).eval (algebraMap GF K (cosetPt (rootFp 12) (idx.getD k 0)).toGF)
    rw [hcols k, ← hj]
    exact hprox

end MField

end ZK60.Exec.Link
