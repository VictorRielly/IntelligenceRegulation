/-
D63 Lean lane L32 (2026-11-09), part 1: **`M`'s honest opening prover, and the completeness of lane L10's executable
`M` test** (`maskVerify`, the mirror of `hashline/src/zk.rs` `mask_verify_tagged`) on its output.

The code (`hashline/src/zk.rs` `mask_commit_tagged` :499-536, `combined_weights` :551-574, `mask_open` :618-656, read
2026-11-09; nothing there is changed). `M` commits `2S + 4` base rows: per mask its re and im rows (the interpolants on
`G_512` of `coefficients ‖ pads ‖ 0`, degree `< 512`), then `b_re, b_im` (1024 coefficients with `b_512 = −b_0`) and
`u_re, u_im` (1024 coefficients), each evaluated on the coset `7·G_4096`. The opening: `θ`; `q' = b + Σ_s a_s·p_{W_s}`
(1024 coefficients); `absorb_fp2("mask-q")`; the `2S + 2` row coefficients `r`; the proximity vector `u + Σ_row
r_row·row`; `absorb_fp2("mask-prox")`; the indices; the opened columns with their salts and paths.

What is here:
* `MTable`: `M`'s honest data (the base rows as polynomials over the base field, the leaf salts); `mCol`: the committed
  column at a point; `MHonest`: the rows' degrees and `b`'s zero sum over `G_512`;
* `qPoly`, `pPoly`: the product polynomial (`SoundMProduct.lean`'s `mProduct` at offset `1`: D65(1)) and the proximity
  polynomial; `qPoly_sum`: the product polynomial's sum over `G_512` is the combined value when every functional is
  TRUE of the masks;
* **`maskProve`**: the honest `M` opening prover (`zk::mask_open`); its words are the canonical words of the true
  coefficients (the code computes them by NTT products: as for lane L25's round words, finding L25-7);
* **`maskVerify_of_prove`**: for every hash function and every transcript, L10's executable `M` test ACCEPTS the honest
  opening of true functionals on honest rows, and lands on the prover's transcript. Its completeness error is `0`.

Every premise is an explicit hypothesis.
-/
import ZK60Formal.HonestOpenPcs
import ZK60Formal.HonestClassifySum

set_option autoImplicit false

namespace ZK60.HonestOpen

open Polynomial
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.HonestClassify
open ZK60.Circuit (gP GF)

/-! ## Lists and polynomials -/

section Aux

theorem ofFn_getD {α : Type} {n : ℕ} (f : Fin n → α) (k : ℕ) (hk : k < n) (d : α) :
    (List.ofFn f).getD k d = f ⟨k, hk⟩ := by
  rw [List.getD_eq_getElem?_getD, List.getElem?_ofFn]
  split
  · rfl
  · rename_i hn
    exact absurd hk hn

/-- `challenge_fp2_vec(n)` returns `n` challenges. -/
theorem chalVec_length (H : HIn → Dig) : ∀ (n : ℕ) (t : Tr), (t.challengeFp2Vec H n).1.length = n
  | 0, _ => rfl
  | n + 1, t => by
    show ((t.challengeFp2 H).1 :: ((t.challengeFp2 H).2.challengeFp2Vec H n).1).length = n + 1
    rw [List.length_cons, chalVec_length H n]

variable {F : Type} [Field F]

/-- A polynomial of degree `< k` is the polynomial of its first `k` coefficients. -/
theorem coefPoly_coeffs {k : ℕ} (p : F[X]) (hp : p.natDegree < k) : coefPoly (fun i : Fin k => p.coeff i) = p := by
  ext t
  rw [coefPoly_coeff]
  split_ifs with h
  · rfl
  · exact (coeff_eq_zero_of_natDegree_lt (by omega)).symm

end Aux

/-! ## `M`'s honest data -/

section MData

/-- **`M`'s honest data**: the `2S + 4` base rows as polynomials over the base field (row `2s` and `2s + 1` the re and
im parts of mask `s`; rows `2S, 2S + 1` of `b`; rows `2S + 2, 2S + 3` of `u`), and the leaf salts. -/
structure MTable where
  row : ℕ → GF[X]
  salts : ℕ → Dig

/-- **The committed column** at the point `pt j`: every base row's value there (`encode_coeffs_coset`). -/
noncomputable def mCol (S : ℕ) (pt : ℕ → Fp) (M : MTable) (j : ℕ) : List Fp :=
  (List.range (2 * S + 4)).map (fun i => Fp.ofGF ((M.row i).eval (pt j).toGF))

theorem mCol_length (S : ℕ) (pt : ℕ → Fp) (M : MTable) (j : ℕ) : (mCol S pt M j).length = 2 * S + 4 := by
  rw [mCol, List.length_map, List.length_range]

theorem mCol_canon (S : ℕ) (pt : ℕ → Fp) (M : MTable) (j : ℕ) : ∀ x ∈ mCol S pt M j, x.Canon := by
  intro x hx
  unfold mCol at hx
  obtain ⟨i, -, rfl⟩ := List.mem_map.mp hx
  exact Fp.ofGF_canon _

theorem mCol_getD (S : ℕ) (pt : ℕ → Fp) (M : MTable) (j i : ℕ) (hi : i < 2 * S + 4) :
    (mCol S pt M j).getD i Fp.zero = Fp.ofGF ((M.row i).eval (pt j).toGF) := by
  unfold mCol
  rw [getD_map_lt' (fun i => Fp.ofGF ((M.row i).eval (pt j).toGF)) (List.range (2 * S + 4)) i
      (by rw [List.length_range]; exact hi) 0 Fp.zero,
    List.getD_eq_getElem?_getD, List.getElem?_range hi, Option.getD_some]

/-- `M`'s columns and salts as a `Table` (for the Merkle root and paths of `HonestOpenPcs.lean`). -/
noncomputable def mTab (S : ℕ) (pt : ℕ → Fp) (M : MTable) : Table := ⟨[], mCol S pt M, M.salts⟩

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- `re + U·im` of two base rows, in `K[X]`. -/
noncomputable def pairK (M : MTable) (a b : ℕ) : K[X] :=
  (M.row a).map (algebraMap GF K) + C U * (M.row b).map (algebraMap GF K)

theorem pairK_natDegree_lt (M : MTable) (a b d : ℕ) (ha : (M.row a).natDegree < d) (hb : (M.row b).natDegree < d) :
    (pairK U M a b).natDegree < d := by
  unfold pairK
  refine lt_of_le_of_lt (natDegree_add_le _ _) (max_lt (lt_of_le_of_lt natDegree_map_le ha) ?_)
  exact lt_of_le_of_lt ((natDegree_C_mul_le _ _).trans natDegree_map_le) hb

theorem eval_map_alg (p : GF[X]) (x : GF) :
    (p.map (algebraMap GF K)).eval (algebraMap GF K x) = algebraMap GF K (p.eval x) := by
  rw [eval_map, eval₂_at_apply]

/-- A pair of entries of the committed column is the pair's polynomial at the column's point. -/
theorem toK_fp2Of_mCol (S : ℕ) (pt : ℕ → Fp) (M : MTable) (j a b : ℕ) (ha : a < 2 * S + 4) (hb : b < 2 * S + 4) :
    (fp2Of (mCol S pt M j) a b).toK U = (pairK U M a b).eval (algebraMap GF K (pt j).toGF) := by
  rw [toK_fp2Of, mCol_getD S pt M j a ha, mCol_getD S pt M j b hb, Fp.toGF_ofGF, Fp.toGF_ofGF]
  unfold pairK
  rw [eval_add, eval_mul, eval_C, eval_map_alg, eval_map_alg]

/-- Mask `s`'s polynomial `a_s = a_re + U·a_im`. -/
noncomputable def mA (M : MTable) (S : ℕ) (s : Fin S) : K[X] := pairK U M (2 * s) (2 * s + 1)

/-- The blinding polynomial `b`. -/
noncomputable def mB (M : MTable) (S : ℕ) : K[X] := pairK U M (2 * S) (2 * S + 1)

/-- The proximity mask `u`. -/
noncomputable def mUp (M : MTable) (S : ℕ) : K[X] := pairK U M (2 * S + 2) (2 * S + 3)

/-- The functionals' weights, read in `K` (lane L10's `fwt`). -/
def wtOf (fs : List MaskFunctional) (S : ℕ) : Fin fs.length → Fin S → Fin mMsg → K :=
  fun i s j => fwt U (fs.get i) s j

/-- **The product polynomial** `q' = b + Σ_s a_s·p_{W_s(θ)}` (`mProduct` at offset `1`: the powers from `θ^1`). -/
noncomputable def qPoly (ω : K) (M : MTable) (S : ℕ) (fs : List MaskFunctional) (θ : K) : K[X] :=
  mProduct ω 1 (wtOf U fs S) (mA U M S) (mB U M S) θ

/-- **The proximity polynomial** `u + Σ_row r_row·row` over the `2S + 2` rows of the masks and of `b`. -/
noncomputable def pPoly (M : MTable) (S : ℕ) (rs : List Fp2) : K[X] :=
  mUp U M S + ∑ i : Fin (2 * S + 2), C ((rs.getD i Fp2.zero).toK U) * (M.row i).map (algebraMap GF K)

/-- **`M`'s rows are honest**: the masks' rows have degree `< 512`, the rows of `b` and `u` degree `< 1024`, and `b`
sums to zero over `G_512` (`b_512 = −b_0`, `mOff_eq`). -/
structure MHonest (ω : K) (M : MTable) (S : ℕ) : Prop where
  degA : ∀ i, i < 2 * S → (M.row i).natDegree < mMsg
  degB : ∀ i, 2 * S ≤ i → i < 2 * S + 4 → (M.row i).natDegree < 2 * mMsg
  off : mOff mMsg ω (mB U M S) = 0

variable {U}

theorem qPoly_natDegree_lt {ω : K} (hω : IsPrimitiveRoot ω mMsg) {M : MTable} {S : ℕ} (hM : MHonest U ω M S)
    (fs : List MaskFunctional) (θ : K) : (qPoly U ω M S fs θ).natDegree < 2 * mMsg := by
  unfold qPoly mProduct
  refine lt_of_le_of_lt (natDegree_add_le _ _)
    (max_lt ?_ (lt_of_le_of_lt ?_ (show 2 * mMsg - 2 < 2 * mMsg by norm_num [mMsg])))
  · exact pairK_natDegree_lt U M _ _ _ (hM.degB _ (by omega) (by omega)) (hM.degB _ (by omega) (by omega))
  · refine natDegree_sum_le_of_forall_le _ _ fun s _ => (natDegree_mul_le).trans ?_
    have h1 : (mA U M S s).natDegree < mMsg :=
      pairK_natDegree_lt U M _ _ _ (hM.degA _ (by have := s.isLt; omega)) (hM.degA _ (by have := s.isLt; omega))
    have h2 := mInterp_natDegree_lt (by norm_num [mMsg]) hω (mW 1 (wtOf U fs S) θ s)
    omega

theorem pPoly_natDegree_lt {ω : K} {M : MTable} {S : ℕ} (hM : MHonest U ω M S) (rs : List Fp2) :
    (pPoly U M S rs).natDegree < 2 * mMsg := by
  unfold pPoly
  refine lt_of_le_of_lt (natDegree_add_le _ _)
    (max_lt ?_ (lt_of_le_of_lt ?_ (show 2 * mMsg - 1 < 2 * mMsg by norm_num [mMsg])))
  · exact pairK_natDegree_lt U M _ _ _ (hM.degB _ (by omega) (by omega)) (hM.degB _ (by omega) (by omega))
  · refine natDegree_sum_le_of_forall_le _ _ fun i _ =>
      ((natDegree_C_mul_le _ _).trans natDegree_map_le).trans ?_
    have hi := i.isLt
    by_cases h : (i : ℕ) < 2 * S
    · have := hM.degA i h
      omega
    · have := hM.degB i (by omega) (by omega)
      omega

/-- **The sum check, honest**: with `b` summing to zero over `G_512` and every functional TRUE of the masks
(`value_i = Σ_s Σ_j wt_{i,s,j}·a_s(ω^j)`), `512·(q'_0 + q'_512)` is the combined value `Σ_i θ^(i+1)·value_i`. -/
theorem qPoly_sum {ω : K} (hω : IsPrimitiveRoot ω mMsg) {M : MTable} {S : ℕ} (hM : MHonest U ω M S)
    (fs : List MaskFunctional) (θ : K)
    (htrue : ∀ i : Fin fs.length, (fs.get i).value.toK U = mTrue ω (wtOf U fs S) (mA U M S) i) :
    (mMsg : K) * ((qPoly U ω M S fs θ).coeff 0 + (qPoly U ω M S fs θ).coeff mMsg)
      = mV 1 (fun i : Fin fs.length => (fs.get i).value.toK U) θ := by
  rw [← sum_mPts_eval (by norm_num [mMsg]) hω _ (qPoly_natDegree_lt hω hM fs θ)]
  unfold qPoly
  rw [sum_mProduct hω, hM.off, zero_add]
  show ∑ i : Fin fs.length, θ ^ ((i : ℕ) + 1) * mTrue ω (wtOf U fs S) (mA U M S) i
    = ∑ i : Fin fs.length, θ ^ ((i : ℕ) + 1) * (fs.get i).value.toK U
  exact Finset.sum_congr rfl (fun i _ => by rw [htrue i])

end MData

/-! ## The words of a polynomial -/

section Words

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- The canonical words of a polynomial's first `1024` coefficients. -/
noncomputable def polyWords (p : K[X]) : List Fp2 :=
  List.ofFn (fun k : Fin (2 * mMsg) => ofK U hbij (p.coeff k))

theorem polyWords_length (p : K[X]) : (polyWords U hbij p).length = 2 * mMsg := by
  rw [polyWords, List.length_ofFn]

theorem polyWords_canon (p : K[X]) : ∀ a ∈ polyWords U hbij p, a.Canon := by
  intro a ha
  have ha' : a ∈ List.ofFn (fun k : Fin (2 * mMsg) => ofK U hbij (p.coeff k)) := ha
  obtain ⟨i, rfl⟩ := List.mem_ofFn.mp ha'
  exact ofK_canon U hbij _

theorem polyWords_toK (p : K[X]) (k : ℕ) (hk : k < 2 * mMsg) :
    ((polyWords U hbij p).getD k Fp2.zero).toK U = p.coeff k := by
  unfold polyWords
  rw [ofFn_getD _ k hk, toK_ofK]

/-- The words read back are the polynomial, for degree `< 1024`. -/
theorem coefPoly_polyWords (p : K[X]) (hp : p.natDegree < 2 * mMsg) :
    coefPoly (vecK U (2 * mMsg) (polyWords U hbij p)) = p := by
  have e : vecK U (2 * mMsg) (polyWords U hbij p) = fun k : Fin (2 * mMsg) => p.coeff k := by
    funext k
    exact polyWords_toK U hbij p k k.isLt
  rw [e]
  exact coefPoly_coeffs p hp

end Words

/-! ## The honest `M` opening prover -/

section Prove

variable (H : HIn → Dig) (tag : MTag) {K : Type} [Field K] [Algebra GF K] (U : K)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (ω512 ω4096 : Fp)

/-- `θ`. -/
def mTheta (t : Tr) : Fp2 := (t.challengeFp2 H).1

/-- `q'`'s words. -/
noncomputable def mQw (M : MTable) (S : ℕ) (fs : List MaskFunctional) (t : Tr) : List Fp2 :=
  polyWords U hbij (qPoly U (algebraMap GF K ω512.toGF) M S fs ((mTheta H t).toK U))

/-- The transcript after `absorb_fp2("mask-q", q')`. -/
noncomputable def mT1 (M : MTable) (S : ℕ) (fs : List MaskFunctional) (t : Tr) : Tr :=
  (t.challengeFp2 H).2.absorbFp2 H maskQLabel (mQw H U hbij ω512 M S fs t)

/-- The `2S + 2` row coefficients `r`. -/
noncomputable def mRs (M : MTable) (S : ℕ) (fs : List MaskFunctional) (t : Tr) : List Fp2 :=
  ((mT1 H U hbij ω512 M S fs t).challengeFp2Vec H (2 * S + 2)).1

/-- The proximity vector's words. -/
noncomputable def mPw (M : MTable) (S : ℕ) (fs : List MaskFunctional) (t : Tr) : List Fp2 :=
  polyWords U hbij (pPoly U M S (mRs H U hbij ω512 M S fs t))

/-- The transcript after `absorb_fp2("mask-prox", prox)`. -/
noncomputable def mT2 (M : MTable) (S : ℕ) (fs : List MaskFunctional) (t : Tr) : Tr :=
  ((mT1 H U hbij ω512 M S fs t).challengeFp2Vec H (2 * S + 2)).2.absorbFp2 H maskProxLabel
    (mPw H U hbij ω512 M S fs t)

/-- The sampled column indices and the transcript after them. -/
noncomputable def mIdx (M : MTable) (S : ℕ) (fs : List MaskFunctional) (t : Tr) : List ℕ × Tr :=
  ((mT2 H U hbij ω512 M S fs t).challengeIndices H mQ mDom).getD ([], mT2 H U hbij ω512 M S fs t)

/-- **The honest `M` opening prover** (`zk::mask_open`): the opening and the transcript after it. -/
noncomputable def maskProve (M : MTable) (S : ℕ) (fs : List MaskFunctional) (t : Tr) : MaskOpening × Tr :=
  (⟨mQw H U hbij ω512 M S fs t, mPw H U hbij ω512 M S fs t,
    (mIdx H U hbij ω512 M S fs t).1.map (fun j => (j, mCol S (cosetPt ω4096) M j, M.salts j,
      pathOf H tag 12 (mTab S (cosetPt ω4096) M) j))⟩,
    (mIdx H U hbij ω512 M S fs t).2)

/-- **What the honest `M` prover returns**: the `256` sampled indices, each below `4096`, and the opening: `q'`, the
proximity vector and the columns at those indices. -/
theorem maskProve_eq (M : MTable) (S : ℕ) (fs : List MaskFunctional) (t : Tr) :
    ∃ idx t3, (mT2 H U hbij ω512 M S fs t).challengeIndices H mQ mDom = some (idx, t3) ∧ idx.length = mQ
      ∧ (∀ x ∈ idx, x < mDom)
      ∧ maskProve H tag U hbij ω512 ω4096 M S fs t
        = (⟨mQw H U hbij ω512 M S fs t, mPw H U hbij ω512 M S fs t,
            idx.map (fun j => (j, mCol S (cosetPt ω4096) M j, M.salts j,
              pathOf H tag 12 (mTab S (cosetPt ω4096) M) j))⟩, t3) := by
  have hpow : isPow2 mDom = true := isPow2_two_pow 12
  obtain ⟨idx, t3, hidx, hlen, hlt⟩ := challengeIndices_some H mQ mDom (mT2 H U hbij ω512 M S fs t) hpow
    (by norm_num [mQ]) (by norm_num [mDom])
  have hpi : mIdx H U hbij ω512 M S fs t = (idx, t3) := by
    unfold mIdx
    rw [hidx]
    rfl
  refine ⟨idx, t3, hidx, hlen, hlt, ?_⟩
  unfold maskProve
  rw [hpi]

/-- **The honest `M` opening's shape and words**: `1024` canonical words each for `q'` and the proximity vector, `256`
opened columns, each at an index below `4096`, of `2S + 4` canonical words, with a path of `12` digests. -/
theorem maskProve_shape (M : MTable) (S : ℕ) (fs : List MaskFunctional) (t : Tr) :
    (maskProve H tag U hbij ω512 ω4096 M S fs t).1.q.length = 2 * mMsg
      ∧ (∀ x ∈ (maskProve H tag U hbij ω512 ω4096 M S fs t).1.q, x.Canon)
      ∧ (maskProve H tag U hbij ω512 ω4096 M S fs t).1.prox.length = 2 * mMsg
      ∧ (∀ x ∈ (maskProve H tag U hbij ω512 ω4096 M S fs t).1.prox, x.Canon)
      ∧ (maskProve H tag U hbij ω512 ω4096 M S fs t).1.columns.length = mQ
      ∧ ∀ c ∈ (maskProve H tag U hbij ω512 ω4096 M S fs t).1.columns,
          c.1 < mDom ∧ c.2.1.length = 2 * S + 4 ∧ (∀ x ∈ c.2.1, x.Canon) ∧ c.2.2.2.length = 12 := by
  obtain ⟨idx, t3, -, hlen, hlt, hop⟩ := maskProve_eq H tag U hbij ω512 ω4096 M S fs t
  rw [hop]
  refine ⟨polyWords_length U hbij _, polyWords_canon U hbij _, polyWords_length U hbij _, polyWords_canon U hbij _,
    ?_, fun c hc => ?_⟩
  · show (idx.map (fun j => ((j, mCol S (cosetPt ω4096) M j, M.salts j,
      pathOf H tag 12 (mTab S (cosetPt ω4096) M) j) : OCol))).length = mQ
    rw [List.length_map, hlen]
  · obtain ⟨j, hj, rfl⟩ := List.mem_map.mp hc
    exact ⟨hlt j hj, mCol_length S _ M j, mCol_canon S _ M j, pathOf_length H tag 12 _ j⟩

variable (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **One honestly opened column of `M` passes every check** (`MColOk`): its index, its length, its path's depth and
climb, the product check and the proximity check. -/
theorem mColOk_honest (h512 : IsPrimitiveRoot ω512.toGF 512) (h4096 : IsPrimitiveRoot ω4096.toGF 4096)
    (M : MTable) (S : ℕ) (hM : MHonest U (algebraMap GF K ω512.toGF) M S) (fs : List MaskFunctional) (t : Tr)
    (j : ℕ) (hj : j < mDom) :
    MColOk H tag ω512 ω4096 (rootOf H tag 12 (mTab S (cosetPt ω4096) M)) S (combinedWeights S fs (mTheta H t)).1
      (mQw H U hbij ω512 M S fs t) (mPw H U hbij ω512 M S fs t) (mRs H U hbij ω512 M S fs t)
      (j, mCol S (cosetPt ω4096) M j, M.salts j, pathOf H tag 12 (mTab S (cosetPt ω4096) M) j) j := by
  have hω : IsPrimitiveRoot (algebraMap GF K ω512.toGF) mMsg := h512.map_of_injective (algebraMap GF K).injective
  obtain ⟨hsh, -, -, -, -⟩ := cw_fold_spec U hU (mTheta H t) fs _ Fp2.zero (mTheta H t) (zeros_shape S mMsg)
    Fp2.canon_zero
  have hsh' : WShape S mMsg (combinedWeights S fs (mTheta H t)).1 := hsh
  obtain ⟨hp1, hp2⟩ := mcol_iff_K U hU ω512 ω4096 h512 h4096 S (combinedWeights S fs (mTheta H t)).1 hsh'.1
    (fun w hw => (hsh'.2 w hw).1) (mQw H U hbij ω512 M S fs t) (mPw H U hbij ω512 M S fs t)
    (mRs H U hbij ω512 M S fs t) (polyWords_length U hbij _) (polyWords_length U hbij _) (chalVec_length H _ _)
    (mCol S (cosetPt ω4096) M j) (mCol_canon S _ M j) (mCol_length S _ M j) j
  refine ⟨rfl, mCol_length S _ M j, pathOf_length H tag 12 _ j,
    verifyPath_honest H tag 12 (mTab S (cosetPt ω4096) M) j (show j < 2 ^ 12 from hj), hp1.mpr ?_, hp2.mpr ?_⟩
  · have hq : coefPoly (vecK U (2 * mMsg) (mQw H U hbij ω512 M S fs t))
        = qPoly U (algebraMap GF K ω512.toGF) M S fs ((mTheta H t).toK U) :=
      coefPoly_polyWords U hbij _ (qPoly_natDegree_lt hω hM fs _)
    have hw : ∀ s : Fin S, vecK U mMsg ((combinedWeights S fs (mTheta H t)).1.getD s [])
        = mW 1 (wtOf U fs S) ((mTheta H t).toK U) s := by
      intro s
      funext i
      exact (toK_combinedWeights U hU S fs (mTheta H t)).2 s i s.isLt i.isLt
    have hs : ∑ s : Fin S, (fp2Of (mCol S (cosetPt ω4096) M j) (2 * s) (2 * s + 1)).toK U
          * (mInterp (algebraMap GF K ω512.toGF)
              (vecK U mMsg ((combinedWeights S fs (mTheta H t)).1.getD s []))).eval
            (algebraMap GF K (cosetPt ω4096 j).toGF)
        = ∑ s : Fin S, (mA U M S s).eval (algebraMap GF K (cosetPt ω4096 j).toGF)
          * (mInterp (algebraMap GF K ω512.toGF) (mW 1 (wtOf U fs S) ((mTheta H t).toK U) s)).eval
            (algebraMap GF K (cosetPt ω4096 j).toGF) :=
      Finset.sum_congr rfl (fun s _ => by
        rw [hw s, toK_fp2Of_mCol U S _ M j (2 * s) (2 * s + 1) (by have := s.isLt; omega)
          (by have := s.isLt; omega)]
        rfl)
    rw [hq, hs, toK_fp2Of_mCol U S _ M j (2 * S) (2 * S + 1) (by omega) (by omega),
      show qPoly U (algebraMap GF K ω512.toGF) M S fs ((mTheta H t).toK U)
        = mB U M S + ∑ s, mA U M S s * mInterp (algebraMap GF K ω512.toGF)
            (mW 1 (wtOf U fs S) ((mTheta H t).toK U) s) from rfl,
      eval_add, eval_finsetSum]
    exact congrArg₂ (· + ·) rfl (Finset.sum_congr rfl (fun s _ => (eval_mul).symm))
  · have hp : coefPoly (vecK U (2 * mMsg) (mPw H U hbij ω512 M S fs t))
        = pPoly U M S (mRs H U hbij ω512 M S fs t) :=
      coefPoly_polyWords U hbij _ (pPoly_natDegree_lt hM _)
    rw [hp, toK_fp2Of_mCol U S _ M j (2 * S + 2) (2 * S + 3) (by omega) (by omega),
      show pPoly U M S (mRs H U hbij ω512 M S fs t)
        = mUp U M S + ∑ i : Fin (2 * S + 2), C (((mRs H U hbij ω512 M S fs t).getD i Fp2.zero).toK U)
            * (M.row i).map (algebraMap GF K) from rfl,
      eval_add, eval_finsetSum]
    refine congrArg₂ (· + ·) rfl (Finset.sum_congr rfl (fun i _ => ?_))
    rw [eval_mul, eval_C, eval_map_alg, mCol_getD S _ M j i (by have := i.isLt; omega), Fp.toGF_ofGF]

include hU in
/-- **The executable `M` test accepts the honest opening** (completeness of L10's `maskVerify`): for honest rows
(`MHonest`) and functionals TRUE of the masks, at EVERY hash function and from EVERY transcript, `maskVerify` returns
the prover's transcript. -/
theorem maskVerify_of_prove (h512 : IsPrimitiveRoot ω512.toGF 512) (h4096 : IsPrimitiveRoot ω4096.toGF 4096)
    (M : MTable) (S : ℕ) (hM : MHonest U (algebraMap GF K ω512.toGF) M S) (fs : List MaskFunctional)
    (htrue : ∀ i : Fin fs.length, (fs.get i).value.toK U
      = mTrue (algebraMap GF K ω512.toGF) (wtOf U fs S) (mA U M S) i) (t : Tr) :
    maskVerify H tag ω512 ω4096 (rootOf H tag 12 (mTab S (cosetPt ω4096) M)) S fs
        (maskProve H tag U hbij ω512 ω4096 M S fs t).1 t
      = .ok (maskProve H tag U hbij ω512 ω4096 M S fs t).2 := by
  rw [maskVerify_ok_iff]
  have hω : IsPrimitiveRoot (algebraMap GF K ω512.toGF) mMsg := h512.map_of_injective (algebraMap GF K).injective
  obtain ⟨idx, t3, hidx, -, hlt, hop⟩ := maskProve_eq H tag U hbij ω512 ω4096 M S fs t
  rw [hop]
  obtain ⟨-, hvc, -, -, -⟩ := cw_fold_spec U hU (mTheta H t) fs _ Fp2.zero (mTheta H t) (zeros_shape S mMsg)
    Fp2.canon_zero
  have hvc' : (combinedWeights S fs (mTheta H t)).2.Canon := hvc
  refine ⟨polyWords_length U hbij _, ?_, polyWords_length U hbij _, idx, hidx, ?_, ?_⟩
  · refine (sum_iff_K U hU (mQw H U hbij ω512 M S fs t) (polyWords_canon U hbij _)
      (combinedWeights S fs (mTheta H t)).2 hvc').mpr ?_
    have h0 : ((mQw H U hbij ω512 M S fs t).getD 0 Fp2.zero).toK U
        = (qPoly U (algebraMap GF K ω512.toGF) M S fs ((mTheta H t).toK U)).coeff 0 :=
      polyWords_toK U hbij _ 0 (by norm_num [mMsg])
    have h1 : ((mQw H U hbij ω512 M S fs t).getD mMsg Fp2.zero).toK U
        = (qPoly U (algebraMap GF K ω512.toGF) M S fs ((mTheta H t).toK U)).coeff mMsg :=
      polyWords_toK U hbij _ mMsg (by norm_num [mMsg])
    rw [h0, h1, (toK_combinedWeights U hU S fs (mTheta H t)).1]
    exact qPoly_sum hω hM fs _ htrue
  · show (idx.map (fun j => ((j, mCol S (cosetPt ω4096) M j, M.salts j,
      pathOf H tag 12 (mTab S (cosetPt ω4096) M) j) : OCol))).length = idx.length
    rw [List.length_map]
  · intro k hk
    have hk' : k < idx.length := by
      have : k < (idx.map (fun j => ((j, mCol S (cosetPt ω4096) M j, M.salts j,
        pathOf H tag 12 (mTab S (cosetPt ω4096) M) j) : OCol))).length := hk
      rwa [List.length_map] at this
    have hcol : (idx.map (fun j => ((j, mCol S (cosetPt ω4096) M j, M.salts j,
          pathOf H tag 12 (mTab S (cosetPt ω4096) M) j) : OCol))).getD k (0, [], zeroDig, [])
        = (idx.getD k 0, mCol S (cosetPt ω4096) M (idx.getD k 0), M.salts (idx.getD k 0),
          pathOf H tag 12 (mTab S (cosetPt ω4096) M) (idx.getD k 0)) :=
      getD_map_lt' _ idx k hk' 0 _
    show MColOk H tag ω512 ω4096 (rootOf H tag 12 (mTab S (cosetPt ω4096) M)) S
      (combinedWeights S fs (mTheta H t)).1 (mQw H U hbij ω512 M S fs t) (mPw H U hbij ω512 M S fs t)
      (mRs H U hbij ω512 M S fs t)
      ((idx.map (fun j => ((j, mCol S (cosetPt ω4096) M j, M.salts j,
        pathOf H tag 12 (mTab S (cosetPt ω4096) M) j) : OCol))).getD k (0, [], zeroDig, [])) (idx.getD k 0)
    rw [hcol]
    exact mColOk_honest H tag U hbij ω512 ω4096 hU h512 h4096 M S hM fs t (idx.getD k 0)
      (hlt _ (mem_of_getD_lt idx k hk' 0))

end Prove

end ZK60.HonestOpen
