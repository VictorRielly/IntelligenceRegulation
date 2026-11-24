/-
D63 lane L68c, shared honest M-table & claim/slot bridges (`HonestShieldMTable.lean`):
reusable zero-`sorry` infrastructure shared by Stage IN-C (`HonestShieldStageInArith.lean`),
Stage OUT-C (`HonestShieldStageOutArith.lean`), and 26-layer blocks (`HonestShieldBlock.lean`).

What this file proves (only at most `propext`, `Classical.choice`, `Quot.sound`):
1. **Kernel-safe row builder & `ClaimTrue ↔ Link.claimSem` bridge:**
   `chalVec_canon`, `stgPrivVals_length`, `stgPrivVals_canon`, `mkRows`, `mkRows_length`,
   `mkRows_getD_lt`, `mkRows_data_getD`, `mkRows_pad_getD`, `tabMat`, `tabMat_mkRows`,
   `claimTrue_iff_claimSem`.
2. **Reusable generic `mkMTable` for ANY mask count `S : ℕ`:**
   `natDegree_coefPoly_lt`, `bAdj`, `mkMTable`, `mkMTable_honest` (`MHonest`),
   `mkMTable_mA_eval`, `mRowKOf`, `mTrue_singleton_mdot`, `mTrue_sumWeights_eq`,
   `mTrue_evalWeights_eq`.
3. **Unified unmasked slot polynomial & claim-truth preservation:**
   `slotPolyK`, `slotPolyK_vecK_eq`, `slotClaims_claimTrue`.
-/
import ZK60Formal.HonestShieldCore
import ZK60Formal.RunStgShieldToK
import ZK60Formal.SlotPolyInstMask
import ZK60Formal.SlotW16Ir

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open Polynomial
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Sound
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestRun
open ZK60.ProtocolClassify
open ZK60.Circuit (gP GF)
open ZK60.Exec.Block (BlockParams SlotDef Acc Claims4 Cm Tab)

/-! ## 1. Transcript, `stgPrivVals`, kernel-safe `mkRows`, and `ClaimTrue ↔ claimSem` -/

section CoreBridges

/-- Every challenge produced by `Tr.challengeFp2Vec` is canonical. -/
theorem chalVec_canon (H : HIn → Dig) :
    ∀ (n : ℕ) (t : Tr), ∀ a ∈ (t.challengeFp2Vec H n).1, a.Canon
  | 0, _, _, ha => by cases ha
  | n + 1, t, a, ha => by
    change a ∈ (t.challengeFp2 H).1 :: ((t.challengeFp2 H).2.challengeFp2Vec H n).1 at ha
    rcases List.mem_cons.mp ha with rfl | hmem
    · exact canon_challengeFp2Of _
    · exact chalVec_canon H n (t.challengeFp2 H).2 a hmem

/-- `stgPrivVals` has length equal to the number of `.priv` tables in `tabs`. -/
theorem stgPrivVals_length {K : Type} [Field K] [Algebra GF K] (U : K)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (P : BlockParams) (cs : Cm → Block.ZClaim → K) (rho es : List Fp2) :
    ∀ (tabs : List Tab),
      (stgPrivVals U hbij P cs rho es tabs).length = (tabs.filter Tab.isPriv).length
  | [] => rfl
  | .priv _ :: ts => by
    simp only [stgPrivVals, List.length_cons, List.filter_cons, Tab.isPriv, ↓reduceIte,
      stgPrivVals_length U hbij P cs rho es ts]
  | .eq _ _ :: ts => by
    simp only [stgPrivVals, List.filter_cons, Tab.isPriv, Bool.false_eq_true, ↓reduceIte,
      stgPrivVals_length U hbij P cs rho es ts]
  | .pub _ :: ts => by
    simp only [stgPrivVals, List.filter_cons, Tab.isPriv, Bool.false_eq_true, ↓reduceIte,
      stgPrivVals_length U hbij P cs rho es ts]

/-- Every entry of `stgPrivVals` is canonical. -/
theorem stgPrivVals_canon {K : Type} [Field K] [Algebra GF K] (U : K)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (P : BlockParams) (cs : Cm → Block.ZClaim → K) (rho es : List Fp2) :
    ∀ (tabs : List Tab), ∀ w ∈ stgPrivVals U hbij P cs rho es tabs, w.Canon
  | [], _, hw => by cases hw
  | .priv _ :: ts, w, hw => by
    rcases List.mem_cons.mp hw with rfl | hmem
    · exact ofK_canon U hbij _
    · exact stgPrivVals_canon U hbij P cs rho es ts w hmem
  | .eq _ _ :: ts, w, hw => stgPrivVals_canon U hbij P cs rho es ts w hw
  | .pub _ :: ts, w, hw => stgPrivVals_canon U hbij P cs rho es ts w hw

/-- Kernel-safe row builder (`R` rows, each `n` data words followed by `q` pad words). -/
noncomputable def mkRows (R n q : ℕ) (data : Fin R → Fin n → Fp) (pads : Fin R → Fin q → Fp) : List (List Fp) :=
  List.ofFn fun i : Fin R => List.ofFn (data i) ++ List.ofFn (pads i)

theorem mkRows_length (R n q : ℕ) (data : Fin R → Fin n → Fp) (pads : Fin R → Fin q → Fp) :
    (mkRows R n q data pads).length = R :=
  List.length_ofFn

theorem mkRows_getD_lt (R n q : ℕ) (data : Fin R → Fin n → Fp) (pads : Fin R → Fin q → Fp)
    (i : ℕ) (hi : i < R) :
    (mkRows R n q data pads).getD i [] = List.ofFn (data ⟨i, hi⟩) ++ List.ofFn (pads ⟨i, hi⟩) :=
  ofFn_getD _ i hi []

theorem mkRows_data_getD (R n q : ℕ) (data : Fin R → Fin n → Fp) (pads : Fin R → Fin q → Fp)
    (i : Fin R) (t : Fin n) :
    ((mkRows R n q data pads).getD i.val []).getD t.val Fp.zero = data i t := by
  rw [mkRows_getD_lt R n q data pads i.val i.isLt, List.getD_eq_getElem?_getD,
    List.getElem?_append_left (by rw [List.length_ofFn]; exact t.isLt),
    List.getElem?_ofFn, dite_eq_left t.isLt, Option.getD_some]

theorem mkRows_pad_getD (R n q : ℕ) (data : Fin R → Fin n → Fp) (pads : Fin R → Fin q → Fp)
    (i : Fin R) (k : Fin q) :
    ((mkRows R n q data pads).getD i.val []).getD (n + k.val) Fp.zero = pads i k := by
  rw [mkRows_getD_lt R n q data pads i.val i.isLt, List.getD_eq_getElem?_getD,
    List.getElem?_append_right (by rw [List.length_ofFn]; exact Nat.le_add_right _ _),
    List.length_ofFn, Nat.add_sub_cancel_left,
    List.getElem?_ofFn, dite_eq_left k.isLt, Option.getD_some]

/-- Matrix reading of a `Table.rows` list in `K` (width `2^lc + 0`, matching `Link.claimSem ... Q=0`). -/
noncomputable def tabMat {K : Type} [Field K] [Algebra GF K] (R lc : ℕ) (rows : List (List Fp)) :
    Fin R → Fin (2 ^ lc + 0) → K :=
  fun i t => algebraMap GF K ((rows.getD i.val []).getD t.val Fp.zero).toGF

theorem tabMat_mkRows {K : Type} [Field K] [Algebra GF K] (R lc q : ℕ)
    (data : Fin R → Fin (2 ^ lc) → Fp) (pads : Fin R → Fin q → Fp)
    (i : Fin R) (t : Fin (2 ^ lc + 0)) :
    tabMat (K := K) R lc (mkRows R (2 ^ lc) q data pads) i t =
      algebraMap GF K (data i ⟨t.val, by omega⟩).toGF := by
  unfold tabMat
  rw [mkRows_data_getD R (2 ^ lc) q data pads i ⟨t.val, by omega⟩]

/-- **Exact bridge between `HonestOpen.ClaimTrue` and `Link.claimSem`** (at `Q = 0`). -/
theorem claimTrue_iff_claimSem {K : Type} [Field K] [Algebra GF K] (U : K)
    (R lc : ℕ) (rows : List (List Fp)) (hR : rows.length = R) (z : Block.ZClaim) :
    ClaimTrue U (2 ^ lc) lc rows (toZClaim z) ↔
      z.value.toK U = Link.claimSem U R lc 0 (tabMat (K := K) R lc rows) z := by
  subst hR
  unfold ClaimTrue MemTrue tabVal Link.claimSem Link.claimRw Link.claimCw Link.cwK tabMat
  have hrhs :
      (∑ i ∈ Finset.range rows.length,
        (((claimWeights (toZClaim z) rows.length lc).1).getD i Fp2.zero).toK U
          * ∑ t ∈ Finset.range (2 ^ lc),
              algebraMap GF K ((rows.getD i []).getD t Fp.zero).toGF
                * ((zkeyWeights (claimWeights (toZClaim z) rows.length lc).2 lc).getD t Fp2.zero).toK U)
      = ∑ i : Fin rows.length,
          (((claimWeights (toZClaim z) rows.length lc).1).getD i Fp2.zero).toK U
            * ∑ t : Fin (2 ^ lc + 0),
                algebraMap GF K ((rows.getD i.val []).getD t.val Fp.zero).toGF
                  * (if (t : ℕ) < 2 ^ lc then
                      ((zkeyWeights (claimWeights (toZClaim z) rows.length lc).2 lc).getD t Fp2.zero).toK U
                     else 0) := by
    rw [Finset.sum_range]
    refine Finset.sum_congr rfl (fun i _ => ?_)
    congr 1
    rw [Finset.sum_range]
    refine Finset.sum_congr rfl (fun t _ => ?_)
    have ht : (t : ℕ) < 2 ^ lc := t.isLt
    rw [ite_eq_left ht]
  rw [hrhs]
  rfl

end CoreBridges

/-! ## 2. Reusable generic `mkMTable` (`MHonest`, `mA` evaluation, `mTrue` bridges) -/

section GenericMTable

/-- `coefPoly f` on `k > 0` coefficients has `natDegree < k`. -/
theorem natDegree_coefPoly_lt {F : Type} [Field F] {k : ℕ} (hk : 0 < k) (f : Fin k → F) :
    (coefPoly f).natDegree < k := by
  by_cases h0 : coefPoly f = 0
  · rw [h0, natDegree_zero]; exact hk
  · by_contra hge
    have hle : k ≤ (coefPoly f).natDegree := by omega
    have hcoeff : (coefPoly f).coeff (coefPoly f).natDegree = 0 := by
      rw [coefPoly_coeff, dite_eq_right (by omega)]
    exact Polynomial.leadingCoeff_ne_zero.mpr h0 hcoeff

/-- Blinding polynomial adjustment setting `b_512 = -b_0` so `mOff 512 ω (mB M S) = 0`. -/
def bAdj (f : Fin 1024 → GF) : Fin 1024 → GF :=
  fun i => if i.val = 512 then -(f ⟨0, by norm_num⟩) else f i

/-- **Reusable honest `MTable` builder for any mask count `S : ℕ`**:
- rows `2s, 2s+1` (`s < S`): base-field Lagrange interpolants on `G_512` of `(aCoeffs s).c0 / c1` (degree `< 512`),
- rows `2S, 2S+1`: blinding polynomials `b_re, b_im` adjusted by `bAdj` (`b_512 = -b_0`, degree `< 1024`),
- rows `2S+2, 2S+3`: proximity polynomials `u_re, u_im` (degree `< 1024`). -/
noncomputable def mkMTable (S : ℕ) (aCoeffs : Fin S → Fin 512 → Fp2)
    (bRe bIm uRe uIm : Fin 1024 → GF) (salts : ℕ → Dig) : MTable where
  row i :=
    if h : i < 2 * S then
      let s : Fin S := ⟨i / 2, by omega⟩
      if i % 2 = 0 then
        mInterp (rootFp 9).toGF (fun j : Fin 512 => (aCoeffs s j).c0.toGF)
      else
        mInterp (rootFp 9).toGF (fun j : Fin 512 => (aCoeffs s j).c1.toGF)
    else if i = 2 * S then coefPoly (bAdj bRe)
    else if i = 2 * S + 1 then coefPoly (bAdj bIm)
    else if i = 2 * S + 2 then coefPoly uRe
    else if i = 2 * S + 3 then coefPoly uIm
    else 0
  salts := salts

private theorem bAdj_coeff_sum (f : Fin 1024 → GF) :
    (coefPoly (bAdj f)).coeff 0 + (coefPoly (bAdj f)).coeff 512 = 0 := by
  rw [coefPoly_coeff, coefPoly_coeff, dite_eq_left (by norm_num : 0 < 1024),
    dite_eq_left (by norm_num : 512 < 1024)]
  unfold bAdj
  norm_num

/-- **`mkMTable` satisfies `MHonest` for any `S : ℕ`** (`degA < 512`, `degB < 1024`, `mOff = 0`). -/
theorem mkMTable_honest (S : ℕ) (aCoeffs : Fin S → Fin 512 → Fp2)
    (bRe bIm uRe uIm : Fin 1024 → GF) (salts : ℕ → Dig) :
    MHonest shdP_U (algebraMap GF shdP_K (rootFp 9).toGF)
      (mkMTable S aCoeffs bRe bIm uRe uIm salts) S := by
  have hωGF : IsPrimitiveRoot (rootFp 9).toGF 512 := rootFp_isPrimitiveRoot (k := 9) (by norm_num)
  have hωK : IsPrimitiveRoot (algebraMap GF shdP_K (rootFp 9).toGF) 512 :=
    hωGF.map_of_injective (algebraMap GF shdP_K).injective
  have hdegB : ∀ i, 2 * S ≤ i → i < 2 * S + 4 →
      ((mkMTable S aCoeffs bRe bIm uRe uIm salts).row i).natDegree < 2 * mMsg := by
    intro i hlo hhi
    have hnot : ¬ (i < 2 * S) := by omega
    dsimp only [mkMTable]
    rw [dite_eq_right hnot]
    by_cases h0 : i = 2 * S
    · rw [ite_eq_left h0]; exact natDegree_coefPoly_lt (by norm_num) _
    · rw [ite_eq_right h0]
      by_cases h1 : i = 2 * S + 1
      · rw [ite_eq_left h1]; exact natDegree_coefPoly_lt (by norm_num) _
      · rw [ite_eq_right h1]
        by_cases h2 : i = 2 * S + 2
        · rw [ite_eq_left h2]; exact natDegree_coefPoly_lt (by norm_num) _
        · rw [ite_eq_right h2]
          have h3 : i = 2 * S + 3 := by omega
          rw [ite_eq_left h3]; exact natDegree_coefPoly_lt (by norm_num) _
  refine ⟨?_, hdegB, ?_⟩
  · intro i hi
    dsimp only [mkMTable]
    rw [dite_eq_left hi]
    split_ifs
    · exact mInterp_natDegree_lt (by norm_num) hωGF _
    · exact mInterp_natDegree_lt (by norm_num) hωGF _
  · have hBdeg : (mB shdP_U (mkMTable S aCoeffs bRe bIm uRe uIm salts) S).natDegree < 2 * 512 :=
      pairK_natDegree_lt shdP_U _ _ _ _ (hdegB (2 * S) le_rfl (by omega))
        (hdegB (2 * S + 1) (by omega) (by omega))
    change mOff 512 (algebraMap GF shdP_K (rootFp 9).toGF) (mB shdP_U (mkMTable S aCoeffs bRe bIm uRe uIm salts) S) = 0
    rw [mOff_eq (by norm_num) hωK _ hBdeg]
    have hrow0 : (mkMTable S aCoeffs bRe bIm uRe uIm salts).row (2 * S) = coefPoly (bAdj bRe) := by
      dsimp only [mkMTable]
      rw [dite_eq_right (by omega), ite_eq_left rfl]
    have hrow1 : (mkMTable S aCoeffs bRe bIm uRe uIm salts).row (2 * S + 1) = coefPoly (bAdj bIm) := by
      dsimp only [mkMTable]
      rw [dite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left rfl]
    have hsum0 : (mB shdP_U (mkMTable S aCoeffs bRe bIm uRe uIm salts) S).coeff 0
        + (mB shdP_U (mkMTable S aCoeffs bRe bIm uRe uIm salts) S).coeff 512 = 0 := by
      unfold mB pairK
      rw [hrow0, hrow1]
      simp only [coeff_add, coeff_C_mul, coeff_map]
      have hre : algebraMap GF shdP_K ((coefPoly (bAdj bRe)).coeff 0)
          + algebraMap GF shdP_K ((coefPoly (bAdj bRe)).coeff 512) = 0 := by
        rw [← map_add, bAdj_coeff_sum, map_zero]
      have him : algebraMap GF shdP_K ((coefPoly (bAdj bIm)).coeff 0)
          + algebraMap GF shdP_K ((coefPoly (bAdj bIm)).coeff 512) = 0 := by
        rw [← map_add, bAdj_coeff_sum, map_zero]
      calc (algebraMap GF shdP_K ((coefPoly (bAdj bRe)).coeff 0)
              + shdP_U * algebraMap GF shdP_K ((coefPoly (bAdj bIm)).coeff 0))
            + (algebraMap GF shdP_K ((coefPoly (bAdj bRe)).coeff 512)
              + shdP_U * algebraMap GF shdP_K ((coefPoly (bAdj bIm)).coeff 512))
          = (algebraMap GF shdP_K ((coefPoly (bAdj bRe)).coeff 0)
              + algebraMap GF shdP_K ((coefPoly (bAdj bRe)).coeff 512))
            + shdP_U * (algebraMap GF shdP_K ((coefPoly (bAdj bIm)).coeff 0)
              + algebraMap GF shdP_K ((coefPoly (bAdj bIm)).coeff 512)) := by ring
        _ = 0 + shdP_U * 0 := by rw [hre, him]
        _ = 0 := by ring
    rw [hsum0, mul_zero]

/-- **Evaluation of `mA` on `G_512`**: `mA` of `mkMTable` at `ω^j` recovers `(aCoeffs s j).toK shdP_U`. -/
theorem mkMTable_mA_eval (S : ℕ) (aCoeffs : Fin S → Fin 512 → Fp2)
    (bRe bIm uRe uIm : Fin 1024 → GF) (salts : ℕ → Dig) (s : Fin S) (j : Fin 512) :
    (mA shdP_U (mkMTable S aCoeffs bRe bIm uRe uIm salts) S s).eval
        (mPts (algebraMap GF shdP_K (rootFp 9).toGF) j)
      = (aCoeffs s j).toK shdP_U := by
  have hωGF : IsPrimitiveRoot (rootFp 9).toGF 512 := rootFp_isPrimitiveRoot (k := 9) (by norm_num)
  have hsLt : s.val < S := s.isLt
  have hrow0 : (mkMTable S aCoeffs bRe bIm uRe uIm salts).row (2 * s.val)
      = mInterp (rootFp 9).toGF (fun k : Fin 512 => (aCoeffs s k).c0.toGF) := by
    dsimp only [mkMTable]
    rw [dite_eq_left (by omega)]
    have hdiv : (⟨2 * s.val / 2, by omega⟩ : Fin S) = s := Fin.ext (show 2 * s.val / 2 = s.val by omega)
    have hmod : 2 * s.val % 2 = 0 := by omega
    rw [ite_eq_left hmod, hdiv]
  have hrow1 : (mkMTable S aCoeffs bRe bIm uRe uIm salts).row (2 * s.val + 1)
      = mInterp (rootFp 9).toGF (fun k : Fin 512 => (aCoeffs s k).c1.toGF) := by
    dsimp only [mkMTable]
    rw [dite_eq_left (by omega)]
    have hdiv : (⟨(2 * s.val + 1) / 2, by omega⟩ : Fin S) = s := Fin.ext (show (2 * s.val + 1) / 2 = s.val by omega)
    have hmod : ¬ ((2 * s.val + 1) % 2 = 0) := by omega
    rw [ite_eq_right hmod, hdiv]
  have hpt : mPts (algebraMap GF shdP_K (rootFp 9).toGF) j
      = algebraMap GF shdP_K (mPts (rootFp 9).toGF j) := by
    unfold mPts
    rw [map_pow]
  unfold mA pairK
  rw [hrow0, hrow1, hpt, eval_add, eval_mul, eval_C, eval_map_alg, eval_map_alg,
    mInterp_eval hωGF, mInterp_eval hωGF]
  rfl

/-- Row-table view `ℕ → ℕ → shdP_K` of `aCoeffs : Fin S → Fin 512 → Fp2` for `Link.maskPoly` and `Block.mdot`. -/
noncomputable def mRowKOf (S : ℕ) (aCoeffs : Fin S → Fin 512 → Fp2) (s j : ℕ) : shdP_K :=
  if h : s < S ∧ j < 512 then (aCoeffs ⟨s, h.1⟩ ⟨j, h.2⟩).toK shdP_U else 0

/-- Singleton-term mask functional evaluated on `mkMTable` equals `Block.mdot` on `mRowKOf`. -/
theorem mTrue_singleton_mdot (S : ℕ) (aCoeffs : Fin S → Fin 512 → Fp2)
    (bRe bIm uRe uIm : Fin 1024 → GF) (salts : ℕ → Dig)
    (s : ℕ) (hs : s < S) (w : List Fp2) (v : Fp2) :
    ∑ s' : Fin S, ∑ j : Fin 512,
        fwt shdP_U (toMF ⟨[(s, w)], v⟩) s' j
          * (mA shdP_U (mkMTable S aCoeffs bRe bIm uRe uIm salts) S s').eval
              (mPts (algebraMap GF shdP_K (rootFp 9).toGF) j)
      = Block.mdot shdP_U (mRowKOf S aCoeffs) 512 (s, w) := by
  unfold Block.mdot
  rw [list_range_sum, Finset.sum_range]
  rw [Finset.sum_eq_single_of_mem (⟨s, hs⟩ : Fin S) (Finset.mem_univ _)]
  · refine Finset.sum_congr rfl (fun j _ => ?_)
    rw [mkMTable_mA_eval]
    have hfwt : fwt shdP_U (toMF ⟨[(s, w)], v⟩) s j = (w.getD j.val Fp2.zero).toK shdP_U := by
      simp [fwt, toMF]
    have hmr : mRowKOf S aCoeffs s j.val = (aCoeffs ⟨s, hs⟩ j).toK shdP_U := by
      unfold mRowKOf
      exact dite_eq_left ⟨hs, j.isLt⟩
    rw [hfwt, hmr]
  · intro s' _ hne
    refine Finset.sum_eq_zero (fun j _ => ?_)
    have hne' : ¬ (s = s'.val) := fun h => hne (Fin.ext h.symm)
    have hfwt : fwt shdP_U (toMF ⟨[(s, w)], v⟩) s' j = 0 := by
      simp [fwt, toMF, hne']
    rw [hfwt, zero_mul]

/-- Multi-term mask functional evaluated on `mkMTable` equals the sum of `Block.mdot` over all terms
(handles 1-term `acc.fs`, 2-term `.host` `acc.hostFs` in Stage OUT-C, and multi-term host functionals in Blocks). -/
theorem mTrue_terms_mdot (S : ℕ) (aCoeffs : Fin S → Fin 512 → Fp2)
    (bRe bIm uRe uIm : Fin 1024 → GF) (salts : ℕ → Dig) :
    ∀ (ts : List (ℕ × List Fp2)) (v : Fp2),
      (∀ t ∈ ts, t.1 < S) →
      ∑ s' : Fin S, ∑ j : Fin 512,
          fwt shdP_U (toMF ⟨ts, v⟩) s' j
            * (mA shdP_U (mkMTable S aCoeffs bRe bIm uRe uIm salts) S s').eval
                (mPts (algebraMap GF shdP_K (rootFp 9).toGF) j)
        = (ts.map (Block.mdot shdP_U (mRowKOf S aCoeffs) 512)).sum
  | [], v, _ => by
    simp [fwt, toMF]
  | t :: ts, v, hlt => by
    have ih := mTrue_terms_mdot S aCoeffs bRe bIm uRe uIm salts ts v
      (fun t' ht' => hlt t' (List.mem_cons_of_mem _ ht'))
    have h0 := mTrue_singleton_mdot S aCoeffs bRe bIm uRe uIm salts t.1 (hlt t List.mem_cons_self) t.2 v
    rw [List.map_cons, List.sum_cons, ← h0, ← ih, ← Finset.sum_add_distrib]
    refine Finset.sum_congr rfl (fun s' _ => ?_)
    rw [← Finset.sum_add_distrib]
    refine Finset.sum_congr rfl (fun j _ => ?_)
    rw [← add_mul]
    congr 1
    simp only [fwt, toMF, List.map_cons, List.sum_cons, List.map_nil, List.sum_nil, add_zero]

/-- Scaled `sumWeights` dot with `mRowKOf` equals `c · cubeSum (maskPoly ...)`. -/
theorem mTrue_sumWeights_eq (S : ℕ) (aCoeffs : Fin S → Fin 512 → Fp2)
    (s N d : ℕ) (hN : 0 < N) (hN64 : N < 64) (hW : N * d + 2 ≤ 512) (c : Fp2) :
    Block.mdot shdP_U (mRowKOf S aCoeffs) 512 (s, (Cfs.sumWeights N d).map (fun w => w.mul c))
      = c.toK shdP_U * cubeSum (Link.maskPoly (mRowKOf S aCoeffs) s N d) := by
  have hscale : Block.mdot shdP_U (mRowKOf S aCoeffs) 512 (s, (Cfs.sumWeights N d).map (fun w => w.mul c))
      = c.toK shdP_U * Block.mdot shdP_U (mRowKOf S aCoeffs) 512 (s, Cfs.sumWeights N d) := by
    unfold Block.mdot
    rw [list_range_sum, list_range_sum, Finset.mul_sum]
    refine Finset.sum_congr rfl (fun i hi => ?_)
    have hget : (((Cfs.sumWeights N d).map (fun w => w.mul c)).getD i Fp2.zero).toK shdP_U
        = c.toK shdP_U * ((Cfs.sumWeights N d).getD i Fp2.zero).toK shdP_U := by
      by_cases hlt : i < (Cfs.sumWeights N d).length
      · rw [getD_map_lt' (fun w : Fp2 => w.mul c) (Cfs.sumWeights N d) i hlt Fp2.zero Fp2.zero,
          Fp2.toK_mul shdP_U shdP_hU, mul_comm]
      · rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD,
          List.getElem?_eq_none (by rw [List.length_map]; omega),
          List.getElem?_eq_none (by omega), Option.getD_none,
          Fp2.toK_zero, mul_zero]
    rw [hget, mul_assoc]
  rw [hscale, Link.maskPoly_cubeSum shdP_U shdP_hU shdP_hbij (mRowKOf S aCoeffs) 512 s N d hN hN64 hW]

/-- `evalWeights` dot with `mRowKOf` equals `maskPoly` at `vecK rho`. -/
theorem mTrue_evalWeights_eq (S : ℕ) (aCoeffs : Fin S → Fin 512 → Fp2)
    (s N d : ℕ) (hN : 0 < N) (rho : List Fp2) (hrho : rho.length = N) (hW : N * d + 2 ≤ 512) :
    Block.mdot shdP_U (mRowKOf S aCoeffs) 512 (s, Cfs.evalWeights rho d)
      = Link.maskPoly (mRowKOf S aCoeffs) s N d (vecK shdP_U N rho) :=
  Link.maskPoly_point shdP_U shdP_hU shdP_hbij (mRowKOf S aCoeffs) 512 s N d hN rho hrho hW

end GenericMTable

/-! ## 3. Unified `slotPolyK` & `slotClaims_claimTrue` -/

section SlotCommon

/-- Unmasked extended slot polynomial in `shdP_K`, defined uniformly from `df.poly` + `stgPrivVals`. -/
noncomputable def slotPolyK (P : BlockParams) (elog : ℕ → ℕ) (cs : Cm → Block.ZClaim → shdP_K)
    (s : ℕ) (df : SlotDef) (x : Fin (slotN P s) → shdP_K) : shdP_K :=
  let Ps := atLog P (elog s)
  let n := (Exec.Block.slotShape P s).1
  let rho := (stgWords shdP_U shdP_hbij x).take n
  let es := (stgWords shdP_U shdP_hbij x).drop n
  match Block.tabVals (Block.oneMinusProd es) rho (stgPrivVals shdP_U shdP_hbij Ps cs rho es df.tabs) df.tabs 0 with
  | .ok vals => (df.poly vals).toK shdP_U
  | .error _ => 0

/-- At canonical `rhoFull` of length `slotN P s`, `slotPolyK` at `vecK rhoFull` agrees with `(df.poly vals).toK`. -/
theorem slotPolyK_vecK_eq (P : BlockParams) (elog : ℕ → ℕ) (cs : Cm → Block.ZClaim → shdP_K)
    (s : ℕ) (df : SlotDef) (rhoFull : List Fp2) (vals : List Fp2)
    (hlen : rhoFull.length = slotN P s) (hcan : ∀ a ∈ rhoFull, a.Canon)
    (htab : Block.tabVals (Block.oneMinusProd (rhoFull.drop (Exec.Block.slotShape P s).1))
      (rhoFull.take (Exec.Block.slotShape P s).1)
      (stgPrivVals shdP_U shdP_hbij (atLog P (elog s)) cs
        (rhoFull.take (Exec.Block.slotShape P s).1) (rhoFull.drop (Exec.Block.slotShape P s).1) df.tabs)
      df.tabs 0 = .ok vals) :
    slotPolyK P elog cs s df (vecK shdP_U (slotN P s) rhoFull) = (df.poly vals).toK shdP_U := by
  unfold slotPolyK
  have hw : stgWords shdP_U shdP_hbij (vecK shdP_U (slotN P s) rhoFull) = rhoFull :=
    stgWords_toK shdP_U shdP_hbij shdP_hU rhoFull hcan (slotN P s) hlen
  dsimp only
  rw [hw, htab]

/-- `Link.claimSem` ignores `z.value`: changing `z.value` does not change `claimSem`. -/
theorem claimSem_value_indep {K : Type} [Field K] [Algebra GF K] (U : K)
    (R lc Q : ℕ) (X : Fin R → Fin (2 ^ lc + Q) → K) (ps : List Block.ZPart) (v₁ v₂ : Fp2) :
    Link.claimSem U R lc Q X ⟨ps, v₁⟩ = Link.claimSem U R lc Q X ⟨ps, v₂⟩ := rfl

private theorem slotClaims_claimTrue_aux (P : BlockParams) (cs : Cm → Block.ZClaim → shdP_K)
    (rho es : List Fp2) (terms : List Fp2)
    (Q : Cm → Block.ZClaim → Prop)
    (hQ : ∀ (cm : Cm) (ps : List Block.ZPart) (v : Fp2),
      v.toK shdP_U = cs cm ⟨ps, Fp2.zero⟩ → Q cm ⟨ps, v⟩) :
    ∀ (tabs : List Tab) (k : ℕ) (cl : Claims4),
      (∀ j, terms.getD (k + j) Fp2.zero = (stgPrivVals shdP_U shdP_hbij P cs rho es tabs).getD j Fp2.zero) →
      (∀ c ∈ cl.a, Q .a c) ∧ (∀ c ∈ cl.h, Q .h c) ∧ (∀ c ∈ cl.inp, Q .inp c) ∧ (∀ c ∈ cl.out, Q .out c) →
      let cl' := Block.slotClaims P rho es terms tabs k cl
      (∀ c ∈ cl'.a, Q .a c) ∧ (∀ c ∈ cl'.h, Q .h c) ∧ (∀ c ∈ cl'.inp, Q .inp c) ∧ (∀ c ∈ cl'.out, Q .out c)
  | [], _, _, _, hcl => hcl
  | .eq _ _ :: ts, k, cl, ht, hcl => slotClaims_claimTrue_aux P cs rho es terms Q hQ ts k cl ht hcl
  | .pub _ :: ts, k, cl, ht, hcl => slotClaims_claimTrue_aux P cs rho es terms Q hQ ts k cl ht hcl
  | .priv p :: ts, k, cl, ht, hcl => by
    have ht0 : terms.getD k Fp2.zero = ofK shdP_U shdP_hbij
        (cs p.cm (Block.buildClaim P p (Block.claimPoint p rho)
          (Block.oneMinusProd es) (Block.maskCoef es p.extRound) Fp2.zero)) := by
      have e := ht 0
      rw [Nat.add_zero] at e
      exact e
    have ht' : ∀ j, terms.getD (k + 1 + j) Fp2.zero = (stgPrivVals shdP_U shdP_hbij P cs rho es ts).getD j Fp2.zero := by
      intro j
      have e := ht (j + 1)
      rw [show k + (j + 1) = k + 1 + j by omega] at e
      exact e
    have hnew : Q p.cm (Block.buildClaim P p (Block.claimPoint p rho)
        (Block.oneMinusProd es) (Block.maskCoef es p.extRound) (terms.getD k Fp2.zero)) := by
      unfold Block.buildClaim
      apply hQ
      rw [ht0, toK_ofK shdP_U shdP_hbij]
      rfl
    have hcl1 :
        (∀ c ∈ (cl.push p.cm (Block.buildClaim P p (Block.claimPoint p rho)
            (Block.oneMinusProd es) (Block.maskCoef es p.extRound) (terms.getD k Fp2.zero))).a, Q .a c)
        ∧ (∀ c ∈ (cl.push p.cm (Block.buildClaim P p (Block.claimPoint p rho)
            (Block.oneMinusProd es) (Block.maskCoef es p.extRound) (terms.getD k Fp2.zero))).h, Q .h c)
        ∧ (∀ c ∈ (cl.push p.cm (Block.buildClaim P p (Block.claimPoint p rho)
            (Block.oneMinusProd es) (Block.maskCoef es p.extRound) (terms.getD k Fp2.zero))).inp, Q .inp c)
        ∧ (∀ c ∈ (cl.push p.cm (Block.buildClaim P p (Block.claimPoint p rho)
            (Block.oneMinusProd es) (Block.maskCoef es p.extRound) (terms.getD k Fp2.zero))).out, Q .out c) := by
      cases hcm : p.cm with
      | a =>
        rw [hcm] at hnew
        refine ⟨fun c hc => ?_, hcl.2.1, hcl.2.2.1, hcl.2.2.2⟩
        simp only [Claims4.push, List.mem_append, List.mem_singleton] at hc
        rcases hc with h1 | rfl
        · exact hcl.1 c h1
        · exact hnew
      | h =>
        rw [hcm] at hnew
        refine ⟨hcl.1, fun c hc => ?_, hcl.2.2.1, hcl.2.2.2⟩
        simp only [Claims4.push, List.mem_append, List.mem_singleton] at hc
        rcases hc with h1 | rfl
        · exact hcl.2.1 c h1
        · exact hnew
      | inp =>
        rw [hcm] at hnew
        refine ⟨hcl.1, hcl.2.1, fun c hc => ?_, hcl.2.2.2⟩
        simp only [Claims4.push, List.mem_append, List.mem_singleton] at hc
        rcases hc with h1 | rfl
        · exact hcl.2.2.1 c h1
        · exact hnew
      | out =>
        rw [hcm] at hnew
        refine ⟨hcl.1, hcl.2.1, hcl.2.2.1, fun c hc => ?_⟩
        simp only [Claims4.push, List.mem_append, List.mem_singleton] at hc
        rcases hc with h1 | rfl
        · exact hcl.2.2.2 c h1
        · exact hnew
    exact slotClaims_claimTrue_aux P cs rho es terms Q hQ ts (k + 1) _ ht' hcl1

/-- **Universal claim-truth preservation for `Block.slotClaims`** when `terms = stgPrivVals P cs rho es tabs`. -/
theorem slotClaims_claimTrue (P : BlockParams) (cs : Cm → Block.ZClaim → shdP_K)
    (rho es : List Fp2) (tabs : List Tab) (cl : Claims4)
    (Q : Cm → Block.ZClaim → Prop)
    (hQ : ∀ (cm : Cm) (ps : List Block.ZPart) (v : Fp2),
      v.toK shdP_U = cs cm ⟨ps, Fp2.zero⟩ → Q cm ⟨ps, v⟩)
    (hcl : (∀ c ∈ cl.a, Q .a c) ∧ (∀ c ∈ cl.h, Q .h c)
      ∧ (∀ c ∈ cl.inp, Q .inp c) ∧ (∀ c ∈ cl.out, Q .out c)) :
    let cl' := Block.slotClaims P rho es (stgPrivVals shdP_U shdP_hbij P cs rho es tabs) tabs 0 cl
    (∀ c ∈ cl'.a, Q .a c) ∧ (∀ c ∈ cl'.h, Q .h c)
      ∧ (∀ c ∈ cl'.inp, Q .inp c) ∧ (∀ c ∈ cl'.out, Q .out c) :=
  slotClaims_claimTrue_aux P cs rho es (stgPrivVals shdP_U shdP_hbij P cs rho es tabs) Q hQ tabs 0 cl
    (fun j => by rw [Nat.zero_add]) hcl

end SlotCommon

end ZK60.HonestShield

theorem ZK60.Exec.Block.toK_fp2U {K : Type} [Field K] [Algebra ZK60.Circuit.GF K] (U : K) :
    ZK60.Exec.Block.fp2U.toK U = U := by
  simp [ZK60.Exec.Block.fp2U, ZK60.Exec.Fp2.toK, ZK60.Hiding.fp2, ZK60.Exec.Fp.toGF,
    ZK60.Exec.Fp.zero, ZK60.Exec.Fp.one]
