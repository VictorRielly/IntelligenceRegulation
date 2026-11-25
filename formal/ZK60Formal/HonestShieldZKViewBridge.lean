/-
D63 lane L69, Milestone B Part 1 (`HonestShieldZKViewBridge.lean`):
generic, reusable view-factorization bridges linking the concrete fixed-schedule Shieldstral prover
(`shdP_runFixedProg`) to the abstract hiding views in `HonestShieldZKView.lean`:
1. **Sampled-column deduplication & coset evaluation matrix (`nodupCols`, `pcsEvalMat`)**:
   - Deduplicates any raw `nQ ≤ 256` sampled column index list into an injective map `Fin kOpen → Fin (2^(logN+lr))`
     with `kOpen ≤ 256`, discharging `hE` (`shdP_coset_padSurj`) for all 84 PCS tables at once.
   - Proves `ColsHonest` tables' opened columns equal `Fp.ofGF` of `pcsEvalMat` times row vectors.
2. **Audit-to-Weights extraction & PCS opening reconstruction (`stdPcsData_of_audit`, `hPcsData_of_audit`,
   `tePcsData_of_checkTokenEp`)**:
   - Proves `((claimWeights (toZClaim c) rows logN).1.getD r Fp2.zero).toK shdP_U = (claimWeight logN c r).toK shdP_U`.
   - Inverts `auditClaims` + `openingChallenges` (`checkOpeningExec = .ok ()`) to extract exact `Hiding.Weights`
     / `Hiding.WeightsH` with `hab`, `hp`, `hsH` discharged via `shdP_proxPair_linInd_of_fp2Det`, and reconstructs
     BOTH `ofOZ (pcsProve ...)` (`groupVecs`, `proxVec`, `columns`) AND every individual `ClaimTrue` claim value
     purely from `PcsStdView` / `PcsAHView` + `(v, tree)`.
3. **Level-2 slot & `M`-opening view bridges (`slotProof_of_slotView`, `segMOpen_of_mOpenView`)**:
   - Bridges `honestW` (`polySlotData`) on `f + c * Link.maskPoly` directly to `ZKW16.slotView` (recovering exact
     `SlotProof.scalar` for `.standalone`, `.priv`, and `.host` and exact `SlotProof.rounds` for all slots).
   - Bridges `mkMTable` + `zkBMaskFixedProg` directly to `Hiding.mOpenView 7 P _ (w a) mCoins` + `mSalts` + `v`.

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.HonestShieldZKCountInst

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open Polynomial Finset
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Sound ZK60.Hiding ZK60.ZKW16 ZK60.ZKLinks ZK60.ZKHonest
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestRun ZK60.ProtocolClassify
open ZK60.Circuit (gP GF)
open ZK60.Exec.Slot.W16R2 (Kind)

/-! ## 1. Sampled-Column Deduplication & Coset Evaluation Matrix (`nodupCols`, `pcsEvalMat`) -/

section DedupAndEvalMat

/-- Self-contained order-preserving deduplication of a list of column indices. -/
def nodupCols : List ℕ → List ℕ
  | [] => []
  | x :: xs =>
    let rest := nodupCols xs
    if x ∈ rest then rest else x :: rest

theorem nodupCols_length_le : ∀ l : List ℕ, (nodupCols l).length ≤ l.length
  | [] => le_rfl
  | x :: xs => by
    unfold nodupCols; dsimp only
    have ih := nodupCols_length_le xs
    split_ifs <;> simp only [List.length_cons] <;> omega

theorem mem_nodupCols_iff (y : ℕ) : ∀ l : List ℕ, y ∈ nodupCols l ↔ y ∈ l
  | [] => Iff.rfl
  | x :: xs => by
    unfold nodupCols; dsimp only
    have ih := mem_nodupCols_iff y xs
    split_ifs with hx
    · constructor
      · intro hy; exact List.mem_cons_of_mem x (ih.mp hy)
      · intro hy
        rcases List.mem_cons.mp hy with rfl | hxs
        · exact hx
        · exact ih.mpr hxs
    · simp only [List.mem_cons, ih]

theorem nodupCols_nodup : ∀ l : List ℕ, (nodupCols l).Nodup
  | [] => List.nodup_nil
  | x :: xs => by
    unfold nodupCols; dsimp only
    have ih := nodupCols_nodup xs
    split_ifs with hx
    · exact ih
    · exact List.nodup_cons.mpr ⟨hx, ih⟩

/-- Injective map `Fin (nodupCols idxs).length → Fin (2 ^ depth)` of distinct opened column indices. -/
def dedupIdx {depth : ℕ} (idxs : List ℕ) (hlt : ∀ j ∈ idxs, j < 2 ^ depth) :
    Fin (nodupCols idxs).length → Fin (2 ^ depth) :=
  fun t => ⟨(nodupCols idxs)[t.val], hlt _ ((mem_nodupCols_iff _ idxs).mp (List.getElem_mem t.isLt))⟩

theorem dedupIdx_injective {depth : ℕ} (idxs : List ℕ) (hlt : ∀ j ∈ idxs, j < 2 ^ depth) :
    Function.Injective (dedupIdx idxs hlt) := by
  intro a b hab
  have hval : (nodupCols idxs)[a.val] = (nodupCols idxs)[b.val] := congrArg Fin.val hab
  exact Fin.ext (((List.Nodup.getElem_inj_iff (nodupCols_nodup idxs)).mp hval))

/-- Lookup index `t : Fin (nodupCols idxs).length` for any `j ∈ idxs`. -/
noncomputable def dedupFind (idxs : List ℕ) (j : ℕ) (hj : j ∈ idxs) : Fin (nodupCols idxs).length :=
  have hmem : j ∈ nodupCols idxs := (mem_nodupCols_iff j idxs).mpr hj
  have hex : ∃ t : Fin (nodupCols idxs).length, (nodupCols idxs)[t.val] = j := by
    obtain ⟨k, hk, hget⟩ := List.mem_iff_getElem.mp hmem
    exact ⟨⟨k, hk⟩, hget⟩
  Classical.choose hex

theorem dedupIdx_dedupFind {depth : ℕ} (idxs : List ℕ) (hlt : ∀ j ∈ idxs, j < 2 ^ depth)
    (j : ℕ) (hj : j ∈ idxs) :
    (dedupIdx idxs hlt (dedupFind idxs j hj)).val = j := by
  have hmem : j ∈ nodupCols idxs := (mem_nodupCols_iff j idxs).mpr hj
  have hex : ∃ t : Fin (nodupCols idxs).length, (nodupCols idxs)[t.val] = j := by
    obtain ⟨k, hk, hget⟩ := List.mem_iff_getElem.mp hmem
    exact ⟨⟨k, hk⟩, hget⟩
  exact Classical.choose_spec hex

/-- `cosetPt (rootFp k) j` read in `GF` equals `7 * (rootFp k).toGF ^ j` for `j < 2 ^ 64`. -/
theorem cosetPt_rootFp_toGF (k j : ℕ) (hj : j < 2 ^ 64) :
    (cosetPt (rootFp k) j).toGF = (7 : GF) * (rootFp k).toGF ^ j := by
  unfold cosetPt
  rw [Fp.toGF_mul, Fp.toGF_pow, Exec.seven_toGF]
  simp only [UInt64.toNat_ofNat', Nat.mod_eq_of_lt hj]

/-- Basis row with a single `1` at `c : Fin n`. -/
private def stdBasisGF (n : ℕ) (c : Fin n) : Fin n → GF :=
  fun i => if i = c then 1 else 0

/-- Base-field evaluation matrix `E : Matrix (Fin kOpen) (Fin (2^logN) ⊕ Fin 256) GF` for the
Shieldstral Lagrange+pad PCS encoder at distinct coset points `idx : Fin kOpen → Fin (2^(logN+lr))`. -/
noncomputable def pcsEvalMat (logN lr : ℕ) (hkl : logN + lr ≤ 31) {kOpen : ℕ}
    (idx : Fin kOpen → Fin (2 ^ (logN + lr))) :
    Matrix (Fin kOpen) (Fin (2 ^ logN) ⊕ Fin 256) GF :=
  fun j col =>
    let x := (7 : GF) * (rootFp (logN + lr)).toGF ^ (idx j : ℕ)
    match col with
    | Sum.inl c => ((lagGF logN (by omega)).poly (stdBasisGF (2 ^ logN) c)).eval x
    | Sum.inr l => (x ^ (2 ^ logN) - 1) * x ^ (l : ℕ)

/-- **`pcsEvalMat` satisfies `hE` (`Function.Surjective` of the pad block)** for any `kOpen ≤ 256`
distinct coset points (`logN + lr ≤ 31`). -/
theorem pcsEvalMat_padSurj (logN lr : ℕ) (hkl : logN + lr ≤ 31) {kOpen : ℕ} (hkQ : kOpen ≤ 256)
    (idx : Fin kOpen → Fin (2 ^ (logN + lr))) (hidx : Function.Injective idx) :
    Function.Surjective (fun p : Fin 256 → GF => fun j => ∑ l, pcsEvalMat logN lr hkl idx j (Sum.inr l) * p l) :=
  shdP_coset_padSurj hkl hkQ idx hidx (pcsEvalMat logN lr hkl idx) (fun _ _ => rfl)

/-- Linearity of `lagGF.poly` decomposes `encPoly` into the exact matrix-vector product with `pcsEvalMat`. -/
theorem pcsEvalMat_mul_row (logN lr : ℕ) (hkl : logN + lr ≤ 31) {kOpen : ℕ}
    (idx : Fin kOpen → Fin (2 ^ (logN + lr))) (r : Hiding.Row GF (2 ^ logN) 256) (j : Fin kOpen) :
    ∑ col : Fin (2 ^ logN) ⊕ Fin 256, pcsEvalMat logN lr hkl idx j col * r col
      = (encPoly (lagGF logN (by omega)) (fun t => r (Sum.inl t)) (fun l => r (Sum.inr l))).eval
          ((7 : GF) * (rootFp (logN + lr)).toGF ^ (idx j : ℕ)) := by
  set x := (7 : GF) * (rootFp (logN + lr)).toGF ^ (idx j : ℕ)
  rw [Fintype.sum_sum_type]
  unfold encPoly
  rw [eval_add, eval_mul, eval_sub, eval_pow, eval_X, eval_one]
  refine congrArg₂ (· + ·) ?_ ?_
  · have hlin : (fun t : Fin (2 ^ logN) => r (Sum.inl t))
        = ∑ c : Fin (2 ^ logN), r (Sum.inl c) • stdBasisGF (2 ^ logN) c := by
      funext t
      rw [Finset.sum_apply]
      rw [Finset.sum_eq_single t]
      · simp [stdBasisGF]
      · intro c _ hne; simp [stdBasisGF, hne.symm]
      · intro h; exact absurd (Finset.mem_univ t) h
    conv_rhs => rw [hlin, map_sum, eval_finsetSum]
    refine Finset.sum_congr rfl fun c _ => ?_
    rw [map_smul, eval_smul, smul_eq_mul, mul_comm]; rfl
  · rw [coefPoly_apply, eval_finsetSum, Finset.mul_sum]
    refine Finset.sum_congr rfl fun l _ => ?_
    rw [Polynomial.eval_monomial]
    dsimp only [pcsEvalMat, x]
    ring

/-- **Column evaluation bridge for ANY `ColsHonest` table**: at every opened index `j < 2^(logN+lr)`,
row `i`'s canonical `Fp` word in `T.cols (idx t)` equals `Fp.ofGF (∑ col, pcsEvalMat ... t col * rowGF col)`. -/
theorem colsHonest_col_eq_evalMat (logN lr : ℕ) (hkl : logN + lr ≤ 31)
    {kOpen : ℕ} (idx : Fin kOpen → Fin (2 ^ (logN + lr)))
    (T : Table) (hcols : ColsHonest shdP_U (lagK logN (by omega)) 256 (cosetPt (rootFp (logN + lr))) (2 ^ logN * 2 ^ lr) T)
    (hcan : ∀ j, ∀ x ∈ T.cols j, x.Canon)
    (i : ℕ) (hi : i < T.rows.length) (t : Fin kOpen) :
    (T.cols (idx t).val).getD i Fp.zero =
      Fp.ofGF (∑ col : Fin (2 ^ logN) ⊕ Fin 256, pcsEvalMat logN lr hkl idx t col *
        Sum.elim (fun c : Fin (2 ^ logN) => ((T.rows.getD i []).getD c.val Fp.zero).toGF)
          (fun l : Fin 256 => ((T.rows.getD i []).getD (2 ^ logN + l.val) Fp.zero).toGF) col) := by
  have hltN : (idx t).val < 2 ^ logN * 2 ^ lr := by rw [← pow_add]; exact (idx t).isLt
  have hlt64 : (idx t).val < 2 ^ 64 := lt_of_lt_of_le (idx t).isLt (Nat.pow_le_pow_right (by norm_num) (by omega))
  obtain ⟨hlen, hspec⟩ := hcols (idx t).val hltN
  have hcolCan : ((T.cols (idx t).val).getD i Fp.zero).Canon :=
    hcan (idx t).val _ (mem_of_getD_lt _ i (by rw [hlen]; exact hi) Fp.zero)
  have hGF : ((T.cols (idx t).val).getD i Fp.zero).toGF =
      ∑ col : Fin (2 ^ logN) ⊕ Fin 256, pcsEvalMat logN lr hkl idx t col *
        Sum.elim (fun c : Fin (2 ^ logN) => ((T.rows.getD i []).getD c.val Fp.zero).toGF)
          (fun l : Fin 256 => ((T.rows.getD i []).getD (2 ^ logN + l.val) Fp.zero).toGF) col := by
    apply (algebraMap GF shdP_K).injective
    rw [hspec i hi, pcsEvalMat_mul_row logN lr hkl idx _ t]
    have hext : RowFormExt (lagGF logN (by omega)) (lagK (K := shdP_K) logN (by omega)) :=
      lagForm_ext (Nat.two_pow_pos logN) (rootFp_isPrimitiveRoot (by omega))
    have hmp := encPoly_map_base (lagGF logN (by omega)) (lagK (K := shdP_K) logN (by omega)) hext
      (fun c : Fin (2 ^ logN) => ((T.rows.getD i []).getD c.val Fp.zero).toGF)
      (fun l : Fin 256 => ((T.rows.getD i []).getD (2 ^ logN + l.val) Fp.zero).toGF)
    have hv : vecK shdP_U (2 ^ logN) (liftRow (T.rows.getD i [])) =
        fun c : Fin (2 ^ logN) => algebraMap GF shdP_K ((T.rows.getD i []).getD c.val Fp.zero).toGF := by
      funext c; exact toK_liftRow shdP_U (T.rows.getD i []) c.val
    have hp : padK shdP_U (2 ^ logN) 256 (liftRow (T.rows.getD i [])) =
        fun l : Fin 256 => algebraMap GF shdP_K ((T.rows.getD i []).getD (2 ^ logN + l.val) Fp.zero).toGF := by
      funext l; exact toK_liftRow shdP_U (T.rows.getD i []) (2 ^ logN + l.val)
    unfold encK
    rw [hv, hp, hmp, cosetPt_rootFp_toGF (logN + lr) (idx t).val hlt64, Polynomial.eval_map_apply]
    rfl
  rw [← hGF, Fp.ofGF_toGF _ hcolCan]

end DedupAndEvalMat

/-! ## 2. Exact `claimWeights` / `claimWeight` Bridge & `auditClaims` Inversion -/

section AuditInversion

/-- Canonical equality `Fp2` from equality in `shdP_K`. -/
theorem fp2_eq_ofK {a : Fp2} (ha : a.Canon) {z : shdP_K} (h : a.toK shdP_U = z) :
    a = ofK shdP_U shdP_hbij z :=
  Fp2.toK_injective shdP_U shdP_hU ha (ofK_canon shdP_U shdP_hbij z) (h.trans (toK_ofK shdP_U shdP_hbij z).symm)

private theorem fp_add_toGF_of_canon_left (a b : Fp) (ha : a.Canon) :
    (a.add b).toGF = a.toGF + b.toGF := by
  have htoNat : (a.add b).v.toNat = (a.v.toNat + b.v.toNat) % gP := by
    unfold Fp.Canon at ha
    have hb : b.v.toNat < 2 ^ 64 := b.v.toNat_lt
    rw [Fp.gP_val] at ha ⊢
    unfold Fp.add
    simp only
    rw [Fp.new_toNat, Fp.gP_val]
    have h1 : (a.v + b.v).toNat = (a.v.toNat + b.v.toNat) % 2 ^ 64 := UInt64.toNat_add _ _
    split_ifs with hc
    · rw [UInt64.lt_iff_toNat_lt, h1] at hc
      rw [UInt64.toNat_add, h1, EPS_toNat]
      have hge : 2 ^ 64 ≤ a.v.toNat + b.v.toNat := by omega
      have hsub : ((a.v.toNat + b.v.toNat) % 2 ^ 64 + 4294967295) % 2 ^ 64 =
          a.v.toNat + b.v.toNat - 18446744069414584321 := by omega
      rw [hsub]
      conv_rhs => rw [show a.v.toNat + b.v.toNat = (a.v.toNat + b.v.toNat - 18446744069414584321) + 18446744069414584321 by omega]
      rw [Nat.add_mod_right]
    · rw [UInt64.lt_iff_toNat_lt, h1] at hc
      have hlt : a.v.toNat + b.v.toNat < 2 ^ 64 := by omega
      rw [h1, Nat.mod_eq_of_lt hlt]
  rw [Fp.toGF_eq_of_toNat htoNat, Nat.cast_add]; rfl

private theorem fp_add_toGF_of_canon_right (a b : Fp) (hb : b.Canon) :
    (a.add b).toGF = a.toGF + b.toGF := by
  have htoNat : (a.add b).v.toNat = (a.v.toNat + b.v.toNat) % gP := by
    unfold Fp.Canon at hb
    have ha : a.v.toNat < 2 ^ 64 := a.v.toNat_lt
    rw [Fp.gP_val] at hb ⊢
    unfold Fp.add
    simp only
    rw [Fp.new_toNat, Fp.gP_val]
    have h1 : (a.v + b.v).toNat = (a.v.toNat + b.v.toNat) % 2 ^ 64 := UInt64.toNat_add _ _
    split_ifs with hc
    · rw [UInt64.lt_iff_toNat_lt, h1] at hc
      rw [UInt64.toNat_add, h1, EPS_toNat]
      have hge : 2 ^ 64 ≤ a.v.toNat + b.v.toNat := by omega
      have hsub : ((a.v.toNat + b.v.toNat) % 2 ^ 64 + 4294967295) % 2 ^ 64 =
          a.v.toNat + b.v.toNat - 18446744069414584321 := by omega
      rw [hsub]
      conv_rhs => rw [show a.v.toNat + b.v.toNat = (a.v.toNat + b.v.toNat - 18446744069414584321) + 18446744069414584321 by omega]
      rw [Nat.add_mod_right]
    · rw [UInt64.lt_iff_toNat_lt, h1] at hc
      have hlt : a.v.toNat + b.v.toNat < 2 ^ 64 := by omega
      rw [h1, Nat.mod_eq_of_lt hlt]
  rw [Fp.toGF_eq_of_toNat htoNat, Nat.cast_add]; rfl

private theorem fp2_toK_add_of_canon_left (a b : Fp2) (ha : a.Canon) :
    (a.add b).toK shdP_U = a.toK shdP_U + b.toK shdP_U := by
  simp only [Fp2.toK, Fp2.add, ZK60.Hiding.fp2,
    fp_add_toGF_of_canon_left _ _ ha.1, fp_add_toGF_of_canon_left _ _ ha.2, map_add]
  ring

private theorem fp2_toK_add_of_canon_right (a b : Fp2) (hb : b.Canon) :
    (a.add b).toK shdP_U = a.toK shdP_U + b.toK shdP_U := by
  simp only [Fp2.toK, Fp2.add, ZK60.Hiding.fp2,
    fp_add_toGF_of_canon_right _ _ hb.1, fp_add_toGF_of_canon_right _ _ hb.2, map_add]
  ring

private theorem addAt_canon_vb (l : List Fp2) (i : ℕ) (a : Fp2) (hl : ∀ x ∈ l, x.Canon) :
    ∀ x ∈ addAt l i a, x.Canon := by
  induction l generalizing i with
  | nil => intro _ h; cases h
  | cons x xs ih =>
    cases i with
    | zero =>
      intro y hy
      rcases List.mem_cons.mp hy with rfl | hy'
      · exact Fp2.canon_add _ _
      · exact hl y (List.mem_cons_of_mem _ hy')
    | succ i' =>
      intro y hy
      rcases List.mem_cons.mp hy with rfl | hy'
      · exact hl y List.mem_cons_self
      · exact ih i' (fun z hz => hl z (List.mem_cons_of_mem _ hz)) y hy'

private theorem foldl_addAt_canon_vb (idx : ℕ → ℕ) (f : ℕ → Fp2) :
    ∀ (m : ℕ) (l : List Fp2), (∀ x ∈ l, x.Canon) →
      ∀ x ∈ (List.range m).foldl (fun rw i => addAt rw (idx i) (f i)) l, x.Canon
  | 0, _, hl => hl
  | m + 1, l, hl => by
    rw [List.range_succ, List.foldl_append, List.foldl_cons, List.foldl_nil]
    exact addAt_canon_vb _ _ _ (foldl_addAt_canon_vb idx f m l hl)

private theorem zpartWeights_canon_vb (q : ZPart) (rows logN : ℕ) :
    ∀ b ∈ (zpartWeights q rows logN).1, b.Canon := by
  have h0 : ∀ b ∈ List.replicate rows Fp2.zero, b.Canon := fun b hb => by
    rw [List.eq_of_mem_replicate hb]; exact Fp2.canon_zero
  unfold zpartWeights
  dsimp only
  split_ifs
  · exact foldl_addAt_canon_vb (fun i => q.offset / 2 ^ logN + i) (fun _ => q.coef) _ _ h0
  · exact addAt_canon_vb _ _ _ h0
  · exact foldl_addAt_canon_vb (fun i => q.offset / 2 ^ logN + i)
      (fun i => q.coef.mul ((eqTableMsb (q.point.take (q.logSize - logN))).getD i Fp2.zero)) _ _ h0
  · exact addAt_canon_vb _ _ _ h0

private theorem zipWith_add_canon_vb : ∀ (a b : List Fp2), ∀ x ∈ List.zipWith Fp2.add a b, x.Canon
  | [], _, _, h => by cases h
  | _ :: _, [], _, h => by cases h
  | a :: as, b :: bs, x, h => by
    rcases List.mem_cons.mp h with rfl | h'
    · exact Fp2.canon_add a b
    · exact zipWith_add_canon_vb as bs x h'

private theorem addAt_getD_toK (l : List Fp2) (hl : ∀ x ∈ l, x.Canon) (i r : ℕ) (a : Fp2) (hr : r < l.length) :
    ((addAt l i a).getD r Fp2.zero).toK shdP_U =
      (l.getD r Fp2.zero).toK shdP_U + if r = i then a.toK shdP_U else 0 := by
  induction l generalizing i r with
  | nil => cases hr
  | cons x xs ih =>
    cases i with
    | zero =>
      cases r with
      | zero =>
        simp only [addAt, List.getD_cons_zero, ↓reduceIte]
        exact fp2_toK_add_of_canon_left x a (hl x List.mem_cons_self)
      | succ r' => simp [addAt]
    | succ i' =>
      cases r with
      | zero => simp [addAt]
      | succ r' =>
        simp only [addAt, List.getD_cons_succ, Nat.succ.injEq]
        exact ih (fun z hz => hl z (List.mem_cons_of_mem _ hz)) i' r' (Nat.lt_of_succ_lt_succ hr)

private theorem foldl_addAt_getD_toK (f : ℕ → Fp2) (r0 : ℕ) :
    ∀ (m : ℕ) (l : List Fp2), (∀ x ∈ l, x.Canon) → ∀ (r : ℕ), r < l.length →
      (((List.range m).foldl (fun rw i => addAt rw (r0 + i) (f i)) l).getD r Fp2.zero).toK shdP_U =
        (l.getD r Fp2.zero).toK shdP_U + if r0 ≤ r ∧ r < r0 + m then (f (r - r0)).toK shdP_U else 0
  | 0, l, _, r, _ => by simp
  | m + 1, l, hl, r, hr => by
    rw [List.range_succ, List.foldl_append, List.foldl_cons, List.foldl_nil]
    have hlen : ((List.range m).foldl (fun rw i => addAt rw (r0 + i) (f i)) l).length = l.length := by
      clear hr hl; induction m generalizing l with
      | zero => rfl
      | succ k ihk =>
        rw [List.range_succ, List.foldl_append, List.foldl_cons, List.foldl_nil, addAt_length, ihk]
    have hcan : ∀ x ∈ (List.range m).foldl (fun rw i => addAt rw (r0 + i) (f i)) l, x.Canon :=
      foldl_addAt_canon_vb (fun i => r0 + i) f m l hl
    rw [addAt_getD_toK _ hcan (r0 + m) r (f m) (by rw [hlen]; exact hr),
      foldl_addAt_getD_toK f r0 m l hl r hr]
    by_cases h1 : r0 ≤ r ∧ r < r0 + m
    · have hne : r ≠ r0 + m := by omega
      have h2 : r0 ≤ r ∧ r < r0 + (m + 1) := by omega
      rw [ite_eq_left h1, ite_eq_right hne, ite_eq_left h2, add_zero]
    · by_cases h2 : r = r0 + m
      · subst h2
        have h3 : r0 ≤ r0 + m ∧ r0 + m < r0 + (m + 1) := by omega
        rw [ite_eq_right h1, ite_eq_left rfl, ite_eq_left h3, add_zero, Nat.add_sub_cancel_left]
      · have h3 : ¬ (r0 ≤ r ∧ r < r0 + (m + 1)) := by omega
        rw [ite_eq_right h1, ite_eq_right h2, ite_eq_right h3, add_zero]

private theorem replicate_zero_getD_toK (rows r : ℕ) :
    ((List.replicate rows Fp2.zero).getD r Fp2.zero).toK shdP_U = 0 := by
  by_cases h : r < rows
  · rw [List.getD_eq_getElem?_getD, List.getElem?_replicate, ite_eq_left h]; exact Fp2.toK_zero shdP_U
  · rw [List.getD_eq_getElem?_getD, List.getElem?_replicate, ite_eq_right h]; exact Fp2.toK_zero shdP_U

private theorem eqStep_length (len : ℕ) (ri : Fp2) (buf : List Fp2) (h : 2 * len ≤ buf.length) :
    (eqStep len ri buf).length = buf.length := by
  unfold eqStep
  simp only [List.length_append, List.length_map, List.length_take, List.length_drop]
  omega

private theorem eqTableAux_length : ∀ (rs : List Fp2) (len : ℕ) (buf : List Fp2),
    len * 2 ^ rs.length ≤ buf.length → (eqTableAux rs len buf).length = buf.length
  | [], _, _, _ => rfl
  | ri :: rs, len, buf, h => by
    simp only [List.length_cons, pow_succ] at h
    unfold eqTableAux
    have h1 : 2 * len ≤ buf.length := by
      have hp : 1 ≤ 2 ^ rs.length := Nat.one_le_pow _ _ (by norm_num)
      nlinarith
    rw [eqTableAux_length rs (len * 2) (eqStep len ri buf) (by rw [eqStep_length len ri buf h1]; linarith),
      eqStep_length len ri buf h1]

theorem eqTableMsb_length (r : List Fp2) : (eqTableMsb r).length = 2 ^ r.length := by
  unfold eqTableMsb eqTable
  rw [eqTableAux_length r.reverse 1 _ (by rw [List.length_replicate, one_mul]),
    List.length_replicate, List.length_reverse]

/-- **Exact pointwise equality in `shdP_K` between `zpartWeights` (`ExecOpening`) and `zpartRowWeight`
(`ExecOpeningBlock`)** for every `r < rows`. -/
theorem zpartWeights_getD_toK (p : Block.ZPart) (rows logN r : ℕ) (hr : r < rows) :
    ((zpartWeights (toZPart p) rows logN).1.getD r Fp2.zero).toK shdP_U =
      (zpartRowWeight p logN r).toK shdP_U := by
  unfold zpartWeights zpartRowWeight toZPart
  dsimp only
  have hlen : (List.replicate rows Fp2.zero).length = rows := List.length_replicate
  have hrepCan : ∀ x ∈ List.replicate rows Fp2.zero, x.Canon := fun x hx => by
    rw [List.eq_of_mem_replicate hx]; exact Fp2.canon_zero
  by_cases hlt : p.logSize < logN
  · have hnot : ¬ (logN ≤ p.logSize) := by omega
    rw [ite_eq_left hlt]
    by_cases hemp : p.point.isEmpty = true
    · rw [ite_eq_left hemp, ite_eq_right hnot, addAt_getD_toK _ hrepCan _ _ _ (by rw [hlen]; exact hr),
        replicate_zero_getD_toK, zero_add]
      split_ifs <;> simp [Fp2.toK_zero]
    · rw [ite_eq_right hemp, ite_eq_right hnot, addAt_getD_toK _ hrepCan _ _ _ (by rw [hlen]; exact hr),
        replicate_zero_getD_toK, zero_add]
      split_ifs <;> simp [Fp2.toK_zero]
  · have hge : logN ≤ p.logSize := by omega
    rw [ite_eq_right hlt]
    by_cases hemp : p.point.isEmpty = true
    · rw [ite_eq_left hemp, ite_eq_left hge,
        foldl_addAt_getD_toK _ _ _ _ hrepCan r (by rw [hlen]; exact hr),
        replicate_zero_getD_toK, zero_add]
      by_cases hout : r < p.offset / 2 ^ logN ∨ p.offset / 2 ^ logN + 2 ^ (p.logSize - logN) ≤ r
      · rw [ite_eq_left hout, ite_eq_right (by omega)]; exact (Fp2.toK_zero shdP_U).symm
      · rw [ite_eq_right hout, ite_eq_left hemp, ite_eq_left (by omega)]
    · rw [ite_eq_right hemp, ite_eq_left hge,
        foldl_addAt_getD_toK _ _ _ _ hrepCan r (by rw [hlen]; exact hr),
        replicate_zero_getD_toK, zero_add]
      set eqR := eqTableMsb (p.point.take (p.logSize - logN))
      have heqLen : eqR.length ≤ 2 ^ (p.logSize - logN) := by
        rw [eqTableMsb_length]
        exact Nat.pow_le_pow_right (by norm_num) (List.length_take_le _ _)
      by_cases hout : r < p.offset / 2 ^ logN ∨ p.offset / 2 ^ logN + 2 ^ (p.logSize - logN) ≤ r
      · rw [ite_eq_left hout, ite_eq_right (by omega)]; exact (Fp2.toK_zero shdP_U).symm
      · rw [ite_eq_right hout, ite_eq_right hemp]
        by_cases hin : r < p.offset / 2 ^ logN + eqR.length
        · rw [ite_eq_left (by omega)]
        · rw [ite_eq_right (by omega)]
          have hget0 : eqR.getD (r - p.offset / 2 ^ logN) Fp2.zero = Fp2.zero := by
            rw [List.getD_eq_getElem?_getD, List.getElem?_eq_none (by omega)]; rfl
          rw [hget0, Fp2.toK_mul shdP_U shdP_hU, Fp2.toK_zero, mul_zero]

private theorem zipWith_add_getD_toK (a b : List Fp2) (hla : ∀ x ∈ a, x.Canon)
    (r : ℕ) (ha : r < a.length) (hb : r < b.length) :
    ((List.zipWith Fp2.add a b).getD r Fp2.zero).toK shdP_U =
      (a.getD r Fp2.zero).toK shdP_U + (b.getD r Fp2.zero).toK shdP_U := by
  induction a generalizing b r with
  | nil => cases ha
  | cons x xs ih =>
    cases b with
    | nil => cases hb
    | cons y ys =>
      cases r with
      | zero =>
        simp only [List.zipWith_cons_cons, List.getD_cons_zero]
        exact fp2_toK_add_of_canon_left x y (hla x List.mem_cons_self)
      | succ r' =>
        simp only [List.zipWith_cons_cons, List.getD_cons_succ]
        exact ih ys (fun z hz => hla z (List.mem_cons_of_mem _ hz)) r'
          (Nat.lt_of_succ_lt_succ ha) (Nat.lt_of_succ_lt_succ hb)

private theorem foldl_zipWith_zpartWeights_toK (rows logN r : ℕ) (hr : r < rows) :
    ∀ (ps : List Block.ZPart) (acc : List Fp2) (hacc : acc.length = rows) (haccCan : ∀ x ∈ acc, x.Canon)
      (acc0 : Fp2) (hacc0Can : acc0.Canon),
      (acc.getD r Fp2.zero).toK shdP_U = acc0.toK shdP_U →
      (((ps.map toZPart).foldl (fun rw q => List.zipWith Fp2.add rw (zpartWeights q rows logN).1) acc).getD r Fp2.zero).toK shdP_U
        = (ps.foldl (fun a p => a.add (zpartRowWeight p logN r)) acc0).toK shdP_U
  | [], acc, _, _, acc0, _, hEq => hEq
  | p :: ps, acc, hacc, haccCan, acc0, hacc0Can, hEq => by
    simp only [List.map_cons, List.foldl_cons]
    have hlen1 : (List.zipWith Fp2.add acc (zpartWeights (toZPart p) rows logN).1).length = rows := by
      rw [List.length_zipWith, hacc, zpartWeights_length, min_self]
    refine foldl_zipWith_zpartWeights_toK rows logN r hr ps _ hlen1 (zipWith_add_canon_vb _ _) _ (Fp2.canon_add _ _) ?_
    rw [zipWith_add_getD_toK _ _ haccCan r (by rw [hacc]; exact hr) (by rw [zpartWeights_length]; exact hr),
      hEq, zpartWeights_getD_toK p rows logN r hr, fp2_toK_add_of_canon_left _ _ hacc0Can]

/-- **Exact pointwise equality in `shdP_K` between `claimWeights` (`ExecOpening`) and `claimWeight`
(`ExecOpeningBlock`)** for every `r < rows`. -/
theorem claimWeights_getD_toK (c : Block.ZClaim) (rows logN r : ℕ) (hr : r < rows) :
    ((claimWeights (toZClaim c) rows logN).1.getD r Fp2.zero).toK shdP_U =
      (claimWeight logN c r).toK shdP_U := by
  unfold claimWeights claimWeight toZClaim
  cases hc : c.parts with
  | nil =>
    simp only [List.map_nil, List.foldl_nil]
    rw [replicate_zero_getD_toK, Fp2.toK_zero]
  | cons p ps =>
    simp only [List.map_cons, List.foldl_cons]
    refine foldl_zipWith_zpartWeights_toK rows logN r hr ps _ (zpartWeights_length _ rows logN)
      (zpartWeights_canon_vb _ rows logN) _ (Fp2.canon_add _ _) ?_
    rw [zpartWeights_getD_toK p rows logN r hr, fp2_toK_add_of_canon_left _ _ Fp2.canon_zero,
      Fp2.toK_zero, zero_add]

/-- **Inversion of `claimTouched`**: if `claimTouched n prox siteRows c = .ok ts`, then:
1. every `p ∈ c.parts` has `partHi p n ≤ prox`,
2. `ts = c.parts.flatMap (partSiteRows n siteRows)`. -/
theorem claimTouched_inv (n prox : ℕ) (siteRows : List ℕ) (c : Block.ZClaim) (ts : List ℕ)
    (h : claimTouched n prox siteRows c = .ok ts) :
    (∀ p ∈ c.parts, partHi p n ≤ prox) ∧ ts = c.parts.flatMap (partSiteRows n siteRows) := by
  have aux : ∀ (ps : List Block.ZPart) (acc out : List ℕ),
      ps.foldlM (m := Except String) (fun acc p => do
        if partHi p n > prox then
          throw "private block: mask schedule audit: a claim reaches the proximity pair or leaves the commitment"
        let rs := (List.range' (partLo p n) (partHi p n - partLo p n)).filter (fun r => decide (r ∈ siteRows))
        if !rs.isEmpty && p.coef.isZero then
          throw "private block: mask schedule audit: zero terminal mask coefficient; discard attempt"
        pure (acc ++ rs)) acc = Except.ok out →
      (∀ p ∈ ps, partHi p n ≤ prox) ∧ out = acc ++ ps.flatMap (partSiteRows n siteRows) := by
    intro ps
    induction ps with
    | nil =>
      intro acc out hout
      simp only [List.foldlM_nil, pure, Except.pure, Except.ok.injEq, List.flatMap_nil, List.append_nil] at hout ⊢
      exact ⟨fun _ hm => (by cases hm), hout.symm⟩
    | cons p ps ih =>
      intro acc out hout
      rw [List.foldlM_cons] at hout
      simp only [Bind.bind, Except.bind, pure, Except.pure] at hout
      by_cases hgt : partHi p n > prox
      · rw [ite_eq_left hgt] at hout; cases hout
      · rw [ite_eq_right hgt] at hout
        set rs := (List.range' (partLo p n) (partHi p n - partLo p n)).filter (fun r => decide (r ∈ siteRows))
        by_cases hbad : (!rs.isEmpty && p.coef.isZero) = true
        · rw [ite_eq_left hbad] at hout; cases hout
        · rw [ite_eq_right hbad] at hout
          obtain ⟨hrest, houtEq⟩ := ih (acc ++ rs) out hout
          refine ⟨fun q hq => ?_, ?_⟩
          · rcases List.mem_cons.mp hq with rfl | hq'
            · omega
            · exact hrest q hq'
          · rw [houtEq, List.flatMap_cons, List.append_assoc]; rfl
  have ⟨h1, h2⟩ := aux c.parts [] ts h
  exact ⟨h1, by simpa using h2⟩

/-- If `r ∈ siteRows` is not in `c.parts.flatMap (partSiteRows (2^logN) siteRows)`, then `claimWeight logN c r = 0`. -/
theorem claimWeight_zero_of_not_mem_touched (logN : ℕ) (siteRows : List ℕ) (c : Block.ZClaim) (r : ℕ)
    (hsite : r ∈ siteRows) (hnot : r ∉ c.parts.flatMap (partSiteRows (2 ^ logN) siteRows)) :
    (claimWeight logN c r).toK shdP_U = 0 := by
  have hall : ∀ p ∈ c.parts, zpartRowWeight p logN r = Fp2.zero := by
    intro p hp
    apply zpartRowWeight_outside
    by_contra h
    have hlo : partLo p (2 ^ logN) ≤ r := by omega
    have hhi : r < partHi p (2 ^ logN) := by omega
    have hmem : r ∈ partSiteRows (2 ^ logN) siteRows p := by
      unfold partSiteRows
      rw [List.mem_filter, List.mem_range']
      exact ⟨⟨r - partLo p (2 ^ logN), by omega, by omega⟩, decide_eq_true hsite⟩
    exact hnot (List.mem_flatMap.mpr ⟨p, hp, hmem⟩)
  unfold claimWeight
  have hfold : ∀ (ps : List Block.ZPart) (acc : Fp2), acc.Canon → acc.toK shdP_U = 0 →
      (∀ p ∈ ps, zpartRowWeight p logN r = Fp2.zero) →
      (ps.foldl (fun a p => a.add (zpartRowWeight p logN r)) acc).toK shdP_U = 0 := by
    intro ps
    induction ps with
    | nil => intro acc _ h _; exact h
    | cons p ps ih =>
      intro acc hcan h hall'
      rw [List.foldl_cons]
      refine ih _ (Fp2.canon_add _ _) ?_ (fun q hq => hall' q (List.mem_cons_of_mem _ hq))
      rw [hall' p List.mem_cons_self, Fp2.toK_add shdP_U _ _ hcan Fp2.canon_zero, h, Fp2.toK_zero, add_zero]
  exact hfold c.parts Fp2.zero Fp2.canon_zero (Fp2.toK_zero shdP_U) hall

/-- If every `p ∈ c.parts` has `partHi p (2^logN) ≤ prox` and `prox ≤ r`, then `(claimWeight logN c r).toK = 0`. -/
theorem claimWeight_zero_of_ge_prox (logN prox : ℕ) (c : Block.ZClaim) (r : ℕ)
    (hhi : ∀ p ∈ c.parts, partHi p (2 ^ logN) ≤ prox) (hr : prox ≤ r) :
    (claimWeight logN c r).toK shdP_U = 0 := by
  have hall : ∀ p ∈ c.parts, zpartRowWeight p logN r = Fp2.zero := fun p hp =>
    zpartRowWeight_outside p logN r (Or.inr (le_trans (hhi p hp) hr))
  unfold claimWeight
  have hfold : ∀ (ps : List Block.ZPart) (acc : Fp2), acc.Canon → acc.toK shdP_U = 0 →
      (∀ p ∈ ps, zpartRowWeight p logN r = Fp2.zero) →
      (ps.foldl (fun a p => a.add (zpartRowWeight p logN r)) acc).toK shdP_U = 0 := by
    intro ps
    induction ps with
    | nil => intro acc _ h _; exact h
    | cons p ps ih =>
      intro acc hcan h hall'
      rw [List.foldl_cons]
      refine ih _ (Fp2.canon_add _ _) ?_ (fun q hq => hall' q (List.mem_cons_of_mem _ hq))
      rw [hall' p List.mem_cons_self, Fp2.toK_add shdP_U _ _ hcan Fp2.canon_zero, h, Fp2.toK_zero, add_zero]
  exact hfold c.parts Fp2.zero Fp2.canon_zero (Fp2.toK_zero shdP_U) hall

/-- **Per-claim inversion of `auditOne`**: extracts exact touched rows, `partHi ≤ prox`, and `LinearIndependent`
pair weights directly from `auditOne = .ok uses'`. -/
theorem auditOne_inv (logN rows prox : ℕ) (siteRows : List ℕ) (sumRows : Option (ℕ × ℕ))
    (nClaims ci : ℕ) (c : Block.ZClaim) (uses uses' : List ℕ)
    (h : auditOne (2 ^ logN) rows prox siteRows sumRows nClaims ci c uses = .ok uses') :
    let ts := c.parts.flatMap (partSiteRows (2 ^ logN) siteRows)
    (∀ p ∈ c.parts, partHi p (2 ^ logN) ≤ prox)
      ∧ uses' = ts.foldl incAt uses
      ∧ (if c.parts.all (fun p => p.point.isEmpty) then
            ∃ u0 u1, sumRows = some (u0, u1) ∧ ci + 1 = nClaims ∧ ts = []
              ∧ LinearIndependent GF ![(claimWeight logN c u0).toK shdP_U, (claimWeight logN c u1).toK shdP_U]
          else
            ∃ t0, ts = [t0, t0 + 1] ∧ (t0 - siteRows.getD 0 0) % 2 = 0
              ∧ LinearIndependent GF ![(claimWeight logN c t0).toK shdP_U, (claimWeight logN c (t0 + 1)).toK shdP_U]) := by
  unfold auditOne at h
  simp only [Bind.bind, Except.bind, pure, Except.pure, Nat.log2_two_pow] at h
  cases hct : claimTouched (2 ^ logN) prox siteRows c with
  | error e => rw [hct] at h; cases h
  | ok ts =>
    rw [hct] at h
    obtain ⟨hhi, rfl⟩ := claimTouched_inv (2 ^ logN) prox siteRows c ts hct
    dsimp only at h ⊢
    cases his : c.parts.all (fun p => p.point.isEmpty) with
    | false =>
      rw [his] at h; dsimp only at h
      by_cases hbad1 : (c.parts.flatMap (partSiteRows (2 ^ logN) siteRows)).length ≠ 2
          ∨ (c.parts.flatMap (partSiteRows (2 ^ logN) siteRows)).getD 1 0
              ≠ (c.parts.flatMap (partSiteRows (2 ^ logN) siteRows)).getD 0 0 + 1
          ∨ ((c.parts.flatMap (partSiteRows (2 ^ logN) siteRows)).getD 0 0 - siteRows.getD 0 0) % 2 ≠ 0
      · rw [ite_eq_left hbad1] at h; cases h
      · rw [ite_eq_right hbad1] at h
        set ts' := c.parts.flatMap (partSiteRows (2 ^ logN) siteRows)
        set t0 := ts'.getD 0 0
        set t1 := ts'.getD 1 0
        by_cases hdet : (Exec.Block.det (claimWeight logN c t0) (claimWeight logN c t1)).v = 0
        · rw [ite_eq_left hdet] at h; cases h
        · rw [ite_eq_right hdet] at h
          simp only [Except.ok.injEq] at h
          have hlen2 : ts'.length = 2 := by omega
          have ht1 : t1 = t0 + 1 := by omega
          have heven : (t0 - siteRows.getD 0 0) % 2 = 0 := by omega
          have htsEq : ts' = [t0, t0 + 1] := by
            cases hts : ts' with
            | nil => rw [hts] at hlen2; cases hlen2
            | cons a rest =>
              cases rest with
              | nil => rw [hts] at hlen2; cases hlen2
              | cons b rest2 =>
                cases rest2 with
                | cons _ _ => rw [hts] at hlen2; cases hlen2
                | nil =>
                  have ha : t0 = a := by dsimp only [t0]; rw [hts]; rfl
                  have hb : t1 = b := by dsimp only [t1]; rw [hts]; rfl
                  rw [← ha, ← hb, ht1]
          rw [ht1] at hdet
          exact ⟨hhi, h.symm, ⟨t0, htsEq, heven, shdP_proxPair_linInd_of_fp2Det _ _ hdet⟩⟩
    | true =>
      rw [his] at h
      cases hsum : sumRows with
      | none => rw [hsum] at h; cases h
      | some p =>
        rcases p with ⟨u0, u1⟩
        rw [hsum] at h; dsimp only at h
        by_cases hlast : ci + 1 = nClaims
        · rw [ite_eq_left hlast] at h
          by_cases hcov : (!(c.parts.flatMap (partSiteRows (2 ^ logN) siteRows)).isEmpty
              || !c.parts.any (fun p => decide (partLo p (2 ^ logN) ≤ u0 ∧ u0 < partHi p (2 ^ logN)) && !p.coef.isZero)
              || !c.parts.any (fun p => decide (partLo p (2 ^ logN) ≤ u1 ∧ u1 < partHi p (2 ^ logN)) && !p.coef.isZero)) = true
          · rw [ite_eq_left hcov] at h; cases h
          · rw [ite_eq_right hcov] at h
            by_cases hdet : (Exec.Block.det (claimWeight logN c u0) (claimWeight logN c u1)).v = 0
            · rw [ite_eq_left hdet] at h; cases h
            · rw [ite_eq_right hdet] at h
              simp only [Except.ok.injEq] at h
              have hemp : (c.parts.flatMap (partSiteRows (2 ^ logN) siteRows)).isEmpty = true := by
                cases he : (c.parts.flatMap (partSiteRows (2 ^ logN) siteRows)).isEmpty with
                | true => rfl
                | false => rw [he] at hcov; simp at hcov
              exact ⟨hhi, h.symm, ⟨u0, u1, rfl, hlast, List.isEmpty_iff.mp hemp,
                shdP_proxPair_linInd_of_fp2Det _ _ hdet⟩⟩
        · rw [ite_eq_right hlast] at h; cases h

/-- Inversion of `auditLoop`: tracks accumulated `uses` and per-claim `auditOne_inv` properties. -/
theorem auditLoop_inv (logN rows prox : ℕ) (siteRows : List ℕ) (sumRows : Option (ℕ × ℕ)) (nClaims : ℕ) :
    ∀ (ci : ℕ) (cs : List Block.ZClaim) (uses uses' : List ℕ),
      auditLoop (2 ^ logN) rows prox siteRows sumRows nClaims ci cs uses = .ok uses' →
      uses' = (cs.flatMap (fun c => c.parts.flatMap (partSiteRows (2 ^ logN) siteRows))).foldl incAt uses
        ∧ ∀ (j : ℕ) (hj : j < cs.length),
            let c := cs[j]
            let ts := c.parts.flatMap (partSiteRows (2 ^ logN) siteRows)
            (∀ p ∈ c.parts, partHi p (2 ^ logN) ≤ prox)
              ∧ (if c.parts.all (fun p => p.point.isEmpty) then
                  ∃ u0 u1, sumRows = some (u0, u1) ∧ ci + j + 1 = nClaims ∧ ts = []
                    ∧ LinearIndependent GF ![(claimWeight logN c u0).toK shdP_U, (claimWeight logN c u1).toK shdP_U]
                else
                  ∃ t0, ts = [t0, t0 + 1] ∧ (t0 - siteRows.getD 0 0) % 2 = 0
                    ∧ LinearIndependent GF ![(claimWeight logN c t0).toK shdP_U, (claimWeight logN c (t0 + 1)).toK shdP_U])
  | _, [], uses, uses', h => by
    simp only [auditLoop, Except.ok.injEq] at h
    exact ⟨h.symm, fun j hj => by simp at hj⟩
  | ci, c :: cs, uses, uses', h => by
    unfold auditLoop at h; simp only [Bind.bind, Except.bind] at h
    cases h1 : auditOne (2 ^ logN) rows prox siteRows sumRows nClaims ci c uses with
    | error e => rw [h1] at h; cases h
    | ok u1 =>
      rw [h1] at h
      obtain ⟨hhi1, hu1, hspec1⟩ := auditOne_inv logN rows prox siteRows sumRows nClaims ci c uses u1 h1
      obtain ⟨hu2, hrest⟩ := auditLoop_inv logN rows prox siteRows sumRows nClaims (ci + 1) cs u1 uses' h
      refine ⟨by rw [hu2, hu1, List.flatMap_cons, List.foldl_append], fun j hj => ?_⟩
      cases j with
      | zero => simpa only [Nat.add_zero] using ⟨hhi1, hspec1⟩
      | succ j' =>
        have h' := hrest j' (Nat.lt_of_succ_lt_succ hj)
        simpa only [List.getElem_cons_succ, show ci + 1 + j' = ci + (j' + 1) by omega] using h'

/-- Count-additivity helper for `countNat`. -/
private theorem countNat_append (r : ℕ) (a b : List ℕ) :
    countNat r (a ++ b) = countNat r a + countNat r b := by
  induction a with
  | nil => simp [countNat]
  | cons x xs ih => simp only [List.cons_append, countNat, ih]; omega

private theorem countNat_pos_iff (r : ℕ) : ∀ l : List ℕ, 0 < countNat r l ↔ r ∈ l
  | [] => by simp [countNat]
  | x :: xs => by
    simp only [countNat, List.mem_cons]
    by_cases hx : r = x
    · subst hx; simp
    · simp only [hx, ↓reduceIte, Nat.zero_add, countNat_pos_iff r xs, false_or]

private theorem incAt_length : ∀ (l : List ℕ) (i : ℕ), (incAt l i).length = l.length
  | [], _ => rfl
  | _ :: _, 0 => rfl
  | _ :: l, i + 1 => congrArg Nat.succ (incAt_length l i)

private theorem incAt_getD : ∀ (l : List ℕ) (i r : ℕ), r < l.length →
    (incAt l i).getD r 0 = l.getD r 0 + if r = i then 1 else 0
  | [], _, _, hr => by cases hr
  | _ :: _, 0, 0, _ => by simp [incAt]
  | _ :: _, 0, _ + 1, _ => by simp [incAt]
  | _ :: _, _ + 1, 0, _ => by simp [incAt]
  | _ :: l, i + 1, r + 1, hr => by
    have ih := incAt_getD l i r (Nat.lt_of_succ_lt_succ hr)
    simp only [incAt, List.getD_cons_succ, ih, Nat.succ.injEq]

private theorem foldl_incAt_getD (ts : List ℕ) : ∀ (uses : List ℕ) (r : ℕ), r < uses.length →
    (ts.foldl incAt uses).getD r 0 = uses.getD r 0 + countNat r ts
  | uses, r, hr => by
    induction ts generalizing uses with
    | nil => simp [countNat]
    | cons i rest ih =>
      rw [List.foldl_cons, ih (incAt uses i) (by rw [incAt_length]; exact hr), incAt_getD uses i r hr, countNat]; omega

private theorem getD_replicate_zero_nat : ∀ (rows r : ℕ), (List.replicate rows 0).getD r 0 = 0
  | 0, _ => rfl
  | _ + 1, 0 => rfl
  | rows + 1, r + 1 => getD_replicate_zero_nat rows r

/-- **Standard PCS (`sumRows = none`) audit inversion**:
given `auditClaims claims (2^logN) rows (List.range' siteStart (2*g)) none prox = .ok ()` with
`siteStart + 2 * g ≤ prox`, `prox + 2 = rows`:
1. `claims.length = g`,
2. there is a bijection `pairToClaim : Fin g ≃ Fin claims.length` such that claim `pairToClaim p`
   touches ONLY the site pair `(siteStart + 2*p, siteStart + 2*p + 1)` with `GF`-independent weights
   and zero weight on every other site row and every row `≥ prox`. -/
theorem auditClaims_std_bijection (logN siteStart g prox rows : ℕ)
    (hsp : siteStart + 2 * g ≤ prox) (hpr : prox + 2 = rows) (claims : List Block.ZClaim)
    (haud : auditClaims claims (2 ^ logN) rows (List.range' siteStart (2 * g)) none prox = .ok ()) :
    ∃ (hLen : claims.length = g) (perm : Fin g ≃ Fin claims.length),
      (∀ p : Fin g,
        let c := claims[(perm p).val]
        (∀ q ∈ c.parts, partHi q (2 ^ logN) ≤ prox)
        ∧ c.parts.flatMap (partSiteRows (2 ^ logN) (List.range' siteStart (2 * g)))
            = [siteStart + 2 * p.val, siteStart + 2 * p.val + 1]
        ∧ LinearIndependent GF
            ![(claimWeight logN c (siteStart + 2 * p.val)).toK shdP_U,
              (claimWeight logN c (siteStart + 2 * p.val + 1)).toK shdP_U]) := by
  set siteRows := List.range' siteStart (2 * g)
  unfold auditClaims at haud
  simp only [Bind.bind, Except.bind, pure, Except.pure] at haud
  have hg1 : ¬ (prox + 2 ≠ rows ∨ siteRows.length % 2 ≠ 0) := by
    simp [siteRows, hpr]
  have hg2 : ¬ ((!isPow2 (2 ^ logN)) = true) := by
    rw [HonestOpen.isPow2_two_pow]; exact Bool.false_ne_true
  rw [ite_eq_right hg1, ite_eq_right hg2] at haud
  cases hloop : auditLoop (2 ^ logN) rows prox siteRows none claims.length 0 claims (List.replicate rows 0) with
  | error e => rw [hloop] at haud; cases haud
  | ok uses =>
    rw [hloop] at haud; dsimp only at haud
    by_cases hany : siteRows.any (fun r => decide (uses.getD r 0 ≠ 1)) = true
    · rw [ite_eq_left hany] at haud; cases haud
    · obtain ⟨huses, hclaims⟩ := auditLoop_inv logN rows prox siteRows none claims.length 0 claims _ uses hloop
      set allT := claims.flatMap (fun c => c.parts.flatMap (partSiteRows (2 ^ logN) siteRows))
      have hcnt1 : ∀ r ∈ siteRows, countNat r allT = 1 := by
        intro r hr
        have hfalse : decide (uses.getD r 0 ≠ 1) = false := by
          cases hd : decide (uses.getD r 0 ≠ 1) with
          | false => rfl
          | true => exact absurd (List.any_eq_true.mpr ⟨r, hr, hd⟩) hany
        have hrLt : r < rows := by
          obtain ⟨k, hk, rfl⟩ := List.mem_range'.mp hr; omega
        have hget : uses.getD r 0 = countNat r allT := by
          rw [huses, foldl_incAt_getD _ _ r (by rw [List.length_replicate]; exact hrLt),
            getD_replicate_zero_nat, Nat.zero_add]
        have h1 : uses.getD r 0 = 1 := by
          by_contra hne; exact Bool.false_ne_true (hfalse.symm.trans (decide_eq_true hne))
        omega
      -- Every claim is non-sum (since `sumRows = none`) and touches a unique even pair `p : Fin g`.
      have hclaimPair : ∀ i : Fin claims.length,
          ∃ p : Fin g,
            (∀ q ∈ claims[i.val].parts, partHi q (2 ^ logN) ≤ prox)
            ∧ claims[i.val].parts.flatMap (partSiteRows (2 ^ logN) siteRows)
                = [siteStart + 2 * p.val, siteStart + 2 * p.val + 1]
            ∧ LinearIndependent GF
                ![(claimWeight logN claims[i.val] (siteStart + 2 * p.val)).toK shdP_U,
                  (claimWeight logN claims[i.val] (siteStart + 2 * p.val + 1)).toK shdP_U] := by
        intro i
        obtain ⟨hhi, hspec⟩ := hclaims i.val i.isLt
        cases his : claims[i.val].parts.all (fun p => p.point.isEmpty) with
        | true => rw [his] at hspec; obtain ⟨_, _, hnone, _⟩ := hspec; cases hnone
        | false =>
          rw [his] at hspec
          obtain ⟨t0, hts, heven, hlin⟩ := hspec
          have hmem0 : t0 ∈ siteRows := by
            have hm : t0 ∈ claims[i.val].parts.flatMap (partSiteRows (2 ^ logN) siteRows) := by
              rw [hts]; exact List.mem_cons_self
            obtain ⟨q, _, hqm⟩ := List.mem_flatMap.mp hm
            exact of_decide_eq_true (List.mem_filter.mp hqm).2
          obtain ⟨k, hk, htk⟩ := List.mem_range'.mp hmem0
          have hs0 : siteRows.getD 0 0 = siteStart := by
            dsimp only [siteRows]
            cases g with
            | zero => omega
            | succ g' => rfl
          rw [hs0] at heven
          have hp : k / 2 < g := by omega
          have ht0Eq : t0 = siteStart + 2 * (k / 2) := by omega
          rw [ht0Eq] at hts hlin
          exact ⟨⟨k / 2, hp⟩, hhi, hts, hlin⟩
      choose fPair hfPair using hclaimPair
      -- `fPair` is bijective because `countNat (siteStart + 2*p) allT = 1` for every `p : Fin g`!
      have hallCount : ∀ (p : Fin g),
          countNat (siteStart + 2 * p.val) allT =
            (Finset.univ.filter (fun i : Fin claims.length => fPair i = p)).card := by
        intro p
        have aux : ∀ (l : List (Fin claims.length)),
            countNat (siteStart + 2 * p.val)
              (l.flatMap (fun i => claims[i.val].parts.flatMap (partSiteRows (2 ^ logN) siteRows)))
            = (l.filter (fun i => decide (fPair i = p))).length := by
          intro l
          induction l with
          | nil => rfl
          | cons i ls ih =>
            rw [List.flatMap_cons, countNat_append, ih, (hfPair i).2.1, List.filter_cons]
            by_cases heq : fPair i = p
            · simp only [heq, decide_true, ↓reduceIte, List.length_cons, countNat,
                show siteStart + 2 * p.val ≠ siteStart + 2 * p.val + 1 by omega]; omega
            · have hne1 : siteStart + 2 * p.val ≠ siteStart + 2 * (fPair i).val := fun h => heq (Fin.ext (by omega))
              have hne2 : siteStart + 2 * p.val ≠ siteStart + 2 * (fPair i).val + 1 := by omega
              simp only [decide_eq_false heq, Bool.false_eq_true, ↓reduceIte,
                countNat, ite_eq_right hne1, ite_eq_right hne2]; omega
        have hclaimsEq : (List.finRange claims.length).map (fun i : Fin claims.length => claims[i.val]) = claims := by
          refine List.ext_getElem (by simp) fun i hi1 hi2 => ?_
          simp
        have hallEq : allT = (List.finRange claims.length).flatMap
            (fun i => claims[i.val].parts.flatMap (partSiteRows (2 ^ logN) siteRows)) := by
          dsimp only [allT]
          conv_lhs => rw [← hclaimsEq]
          rw [List.flatMap_map]
        rw [hallEq, aux]
        have hnd : (List.finRange claims.length).Nodup := List.nodup_finRange claims.length
        rw [← List.toFinset_card_of_nodup (hnd.filter _)]
        congr 1; ext i; simp
      have hfBij : Function.Bijective fPair := by
        constructor
        · intro i₁ i₂ hEq
          have hrMem : siteStart + 2 * (fPair i₁).val ∈ siteRows :=
            List.mem_range'.mpr ⟨2 * (fPair i₁).val, by have := (fPair i₁).isLt; omega, by omega⟩
          have hcard1 : (Finset.univ.filter (fun i : Fin claims.length => fPair i = fPair i₁)).card = 1 := by
            rw [← hallCount (fPair i₁), hcnt1 _ hrMem]
          have hm1 : i₁ ∈ Finset.univ.filter (fun i : Fin claims.length => fPair i = fPair i₁) := by simp
          have hm2 : i₂ ∈ Finset.univ.filter (fun i : Fin claims.length => fPair i = fPair i₁) := by simp [hEq]
          exact Finset.card_le_one.mp (le_of_eq hcard1) i₁ hm1 i₂ hm2
        · intro p
          have hrMem : siteStart + 2 * p.val ∈ siteRows :=
            List.mem_range'.mpr ⟨2 * p.val, by have := p.isLt; omega, by omega⟩
          have hcard1 : (Finset.univ.filter (fun i : Fin claims.length => fPair i = p)).card = 1 := by
            rw [← hallCount p, hcnt1 _ hrMem]
          obtain ⟨i, hi⟩ := Finset.card_pos.mp (hcard1.symm ▸ Nat.zero_lt_one)
          exact ⟨i, (Finset.mem_filter.mp hi).2⟩
      have hLen : claims.length = g := by
        have := Fintype.card_of_bijective hfBij
        simpa using this
      let e := Equiv.ofBijective fPair hfBij
      refine ⟨hLen, e.symm, fun p => ?_⟩
      have hpEq : fPair (e.symm p) = p := e.apply_symm_apply p
      have hfp := hfPair (e.symm p)
      rw [hpEq] at hfp
      exact hfp

/-- **`H`-table (`sumRows = some (u0, u1)`) audit inversion**:
given `auditClaims claims (2^logN) rows (List.range' siteStart (2*g)) (some (u0, u1)) prox = .ok ()`
with `u1 < siteStart`, `siteStart + 2 * g ≤ prox`, `prox + 2 = rows`, and `claims.length = g + 1`:
1. The last claim `claims[g]` is the unique sum claim (touches 0 site rows, `partHi ≤ prox`,
   `GF`-independent weights on `(u0, u1)`),
2. The first `g` claims are all non-sum claims, bijecting via `perm : Fin g ≃ Fin g` onto the `g`
   site pairs `(siteStart + 2*p, siteStart + 2*p + 1)` with `GF`-independent weights. -/
theorem auditClaims_h_bijection (logN u0 u1 siteStart g prox rows : ℕ)
    (hsp : siteStart + 2 * g ≤ prox) (hpr : prox + 2 = rows) (claims : List Block.ZClaim)
    (hLen : claims.length = g + 1)
    (haud : auditClaims claims (2 ^ logN) rows (List.range' siteStart (2 * g)) (some (u0, u1)) prox = .ok ()) :
    ∃ (perm : Fin g ≃ Fin g),
      -- Last claim `claims[g]` is the sum claim
      ((∀ q ∈ claims[g].parts, partHi q (2 ^ logN) ≤ prox)
        ∧ claims[g].parts.flatMap (partSiteRows (2 ^ logN) (List.range' siteStart (2 * g))) = []
        ∧ LinearIndependent GF ![(claimWeight logN claims[g] u0).toK shdP_U, (claimWeight logN claims[g] u1).toK shdP_U])
      -- First `g` claims biject onto the `g` site pairs
      ∧ (∀ p : Fin g,
          let c := claims[(perm p).val]
          (∀ q ∈ c.parts, partHi q (2 ^ logN) ≤ prox)
          ∧ c.parts.flatMap (partSiteRows (2 ^ logN) (List.range' siteStart (2 * g)))
              = [siteStart + 2 * p.val, siteStart + 2 * p.val + 1]
          ∧ LinearIndependent GF
              ![(claimWeight logN c (siteStart + 2 * p.val)).toK shdP_U,
                (claimWeight logN c (siteStart + 2 * p.val + 1)).toK shdP_U]) := by
  set siteRows := List.range' siteStart (2 * g)
  unfold auditClaims at haud
  simp only [Bind.bind, Except.bind, pure, Except.pure] at haud
  have hg1 : ¬ (prox + 2 ≠ rows ∨ siteRows.length % 2 ≠ 0) := by simp [siteRows, hpr]
  have hg2 : ¬ ((!isPow2 (2 ^ logN)) = true) := by
    rw [HonestOpen.isPow2_two_pow]; exact Bool.false_ne_true
  rw [ite_eq_right hg1, ite_eq_right hg2] at haud
  cases hloop : auditLoop (2 ^ logN) rows prox siteRows (some (u0, u1)) claims.length 0 claims (List.replicate rows 0) with
  | error e => rw [hloop] at haud; cases haud
  | ok uses =>
    rw [hloop] at haud; dsimp only at haud
    by_cases hany : siteRows.any (fun r => decide (uses.getD r 0 ≠ 1)) = true
    · rw [ite_eq_left hany] at haud; cases haud
    · obtain ⟨huses, hclaims⟩ := auditLoop_inv logN rows prox siteRows (some (u0, u1)) claims.length 0 claims _ uses hloop
      set allT := claims.flatMap (fun c => c.parts.flatMap (partSiteRows (2 ^ logN) siteRows))
      have hcnt1 : ∀ r ∈ siteRows, countNat r allT = 1 := by
        intro r hr
        have hfalse : decide (uses.getD r 0 ≠ 1) = false := by
          cases hd : decide (uses.getD r 0 ≠ 1) with
          | false => rfl
          | true => exact absurd (List.any_eq_true.mpr ⟨r, hr, hd⟩) hany
        have hrLt : r < rows := by obtain ⟨k, hk, rfl⟩ := List.mem_range'.mp hr; omega
        have hget : uses.getD r 0 = countNat r allT := by
          rw [huses, foldl_incAt_getD _ _ r (by rw [List.length_replicate]; exact hrLt),
            getD_replicate_zero_nat, Nat.zero_add]
        have h1 : uses.getD r 0 = 1 := by
          by_contra hne; exact Bool.false_ne_true (hfalse.symm.trans (decide_eq_true hne))
        omega
      -- Every index `i < g` is strictly `< claims.length - 1`, so it MUST be a non-sum claim!
      have hfirstPair : ∀ i : Fin g,
          ∃ p : Fin g,
            (∀ q ∈ claims[i.val].parts, partHi q (2 ^ logN) ≤ prox)
            ∧ claims[i.val].parts.flatMap (partSiteRows (2 ^ logN) siteRows)
                = [siteStart + 2 * p.val, siteStart + 2 * p.val + 1]
            ∧ LinearIndependent GF
                ![(claimWeight logN claims[i.val] (siteStart + 2 * p.val)).toK shdP_U,
                  (claimWeight logN claims[i.val] (siteStart + 2 * p.val + 1)).toK shdP_U] := by
        intro i
        obtain ⟨hhi, hspec⟩ := hclaims i.val (by omega)
        cases his : claims[i.val].parts.all (fun p => p.point.isEmpty) with
        | true =>
          rw [his] at hspec
          obtain ⟨_, _, _, hlast, _⟩ := hspec
          omega
        | false =>
          rw [his] at hspec
          obtain ⟨t0, hts, heven, hlin⟩ := hspec
          have hmem0 : t0 ∈ siteRows := by
            have hm : t0 ∈ claims[i.val].parts.flatMap (partSiteRows (2 ^ logN) siteRows) := by
              rw [hts]; exact List.mem_cons_self
            obtain ⟨q, _, hqm⟩ := List.mem_flatMap.mp hm
            exact of_decide_eq_true (List.mem_filter.mp hqm).2
          obtain ⟨k, hk, htk⟩ := List.mem_range'.mp hmem0
          have hs0 : siteRows.getD 0 0 = siteStart := by
            dsimp only [siteRows]; cases g with | zero => omega | succ _ => rfl
          rw [hs0] at heven
          have hp : k / 2 < g := by omega
          have ht0Eq : t0 = siteStart + 2 * (k / 2) := by omega
          rw [ht0Eq] at hts hlin
          exact ⟨⟨k / 2, hp⟩, hhi, hts, hlin⟩
      choose fPair hfPair using hfirstPair
      -- Show `claims[g]` MUST be the sum claim (otherwise `allT.length = 2*(g+1) > 2*g`, impossible!)
      have hlastIsSum : claims[g].parts.all (fun p => p.point.isEmpty) = true := by
        by_contra hnot
        have hfalse : claims[g].parts.all (fun p => p.point.isEmpty) = false := Bool.eq_false_iff.mpr hnot
        obtain ⟨_, hspecLast⟩ := hclaims g (by omega)
        rw [hfalse] at hspecLast
        obtain ⟨t0, htsLast, _⟩ := hspecLast
        -- Every element of `allT` lies in `siteRows` (`length = 2*g`), and each `r ∈ siteRows` occurs once,
        -- so `allT.length = ∑ r ∈ siteRows, countNat r allT = 2*g`, contradicting `2*(g+1)`!
        have hallSub : ∀ x ∈ allT, x ∈ siteRows := by
          intro x hx
          obtain ⟨c, _, hx1⟩ := List.mem_flatMap.mp hx
          obtain ⟨q, _, hx2⟩ := List.mem_flatMap.mp hx1
          exact of_decide_eq_true (List.mem_filter.mp hx2).2
        have hlenSum : ∀ (ls : List ℕ), ls.Nodup → (∀ x ∈ allT, x ∈ ls) →
            allT.length = (ls.map (fun r => countNat r allT)).sum := by
          have hsub : ∀ (t ls : List ℕ), ls.Nodup → (∀ x ∈ t, x ∈ ls) →
              t.length = (ls.map (fun r => countNat r t)).sum := by
            intro t
            induction t with
            | nil =>
              intro ls _ _
              simp [countNat]
            | cons a ts iht =>
              intro ls hnd hmem
              have hrest := iht ls hnd (fun x hx => hmem x (List.mem_cons_of_mem _ hx))
              have haMem : a ∈ ls := hmem a List.mem_cons_self
              have hstep : ∀ (ms : List ℕ), ms.Nodup → a ∈ ms →
                  (ms.map (fun r => countNat r (a :: ts))).sum = (ms.map (fun r => countNat r ts)).sum + 1 := by
                intro ms
                induction ms with
                | nil => intro _ hm; cases hm
                | cons m ms' ihm =>
                  intro hnd' hm'
                  obtain ⟨hnm, hnd''⟩ := List.nodup_cons.mp hnd'
                  rcases List.mem_cons.mp hm' with rfl | htail
                  · have h0 : ∀ x ∈ ms', countNat x (a :: ts) = countNat x ts := fun x hx => by
                      have hne : x ≠ a := fun h => hnm (h ▸ hx)
                      simp [countNat, hne]
                    rw [List.map_cons, List.sum_cons, List.map_cons, List.sum_cons,
                      List.map_congr_left h0]
                    simp [countNat]; omega
                  · have hne : m ≠ a := fun h => hnm (h ▸ htail)
                    rw [List.map_cons, List.sum_cons, List.map_cons, List.sum_cons, ihm hnd'' htail]
                    simp [countNat, hne]; omega
              rw [List.length_cons, hrest, hstep ls hnd haMem]
          exact hsub allT
        have hallLen2g : allT.length = 2 * g := by
          rw [hlenSum siteRows (List.nodup_range' 1 (by omega)) hallSub,
            List.map_congr_left (fun r hr => hcnt1 r hr)]
          simp [siteRows]
        have hallLenBig : allT.length = 2 * (g + 1) := by
          have hsplit : claims = (List.finRange g).map (fun i : Fin g => claims[i.val]) ++ [claims[g]] := by
            refine List.ext_getElem (by simp [hLen]) fun i hi1 hi2 => ?_
            by_cases hlt : i < g
            · rw [List.getElem_append_left (by simp; exact hlt)]; simp
            · have hiEq : i = g := by omega
              subst hiEq
              rw [List.getElem_append_right (by simp)]
              simp
          have hallEq : allT = ((List.finRange g).flatMap (fun i : Fin g =>
              claims[i.val].parts.flatMap (partSiteRows (2 ^ logN) siteRows)))
              ++ claims[g].parts.flatMap (partSiteRows (2 ^ logN) siteRows) := by
            dsimp only [allT]
            conv_lhs => rw [hsplit]
            rw [List.flatMap_append, List.flatMap_map, List.flatMap_singleton]
          rw [hallEq, List.length_append, htsLast]
          have hfirstLen : ∀ (l : List (Fin g)),
              (l.flatMap (fun i : Fin g => claims[i.val].parts.flatMap (partSiteRows (2 ^ logN) siteRows))).length
                = 2 * l.length := by
            intro l; induction l with
            | nil => rfl
            | cons i ls ih => rw [List.flatMap_cons, List.length_append, (hfPair i).2.1, ih]; simp; omega
          rw [hfirstLen, List.length_finRange]; simp; omega
        omega
      obtain ⟨hhiLast, hspecLast⟩ := hclaims g (by omega)
      rw [hlastIsSum] at hspecLast
      obtain ⟨u0', u1', hsomeEq, _, htsLastEmpty, hlinLast⟩ := hspecLast
      have huEq : (u0', u1') = (u0, u1) := Option.some.inj hsomeEq.symm
      obtain ⟨rfl, rfl⟩ := Prod.mk.inj huEq
      -- Now `fPair : Fin g → Fin g` is bijective exactly as in the std case!
      have hallCount : ∀ (p : Fin g),
          countNat (siteStart + 2 * p.val) allT =
            (Finset.univ.filter (fun i : Fin g => fPair i = p)).card := by
        intro p
        have hsplit : claims = (List.finRange g).map (fun i : Fin g => claims[i.val]) ++ [claims[g]] := by
          refine List.ext_getElem (by simp [hLen]) fun i hi1 hi2 => ?_
          by_cases hlt : i < g
          · rw [List.getElem_append_left (by simp; exact hlt)]; simp
          · have hiEq : i = g := by omega
            subst hiEq
            rw [List.getElem_append_right (by simp)]; simp
        have hallEq : allT = ((List.finRange g).flatMap (fun i : Fin g =>
            claims[i.val].parts.flatMap (partSiteRows (2 ^ logN) siteRows))) := by
          dsimp only [allT]
          conv_lhs => rw [hsplit]
          rw [List.flatMap_append, List.flatMap_map, List.flatMap_singleton, htsLastEmpty, List.append_nil]
        have aux : ∀ (l : List (Fin g)),
            countNat (siteStart + 2 * p.val)
              (l.flatMap (fun i => claims[i.val].parts.flatMap (partSiteRows (2 ^ logN) siteRows)))
            = (l.filter (fun i => decide (fPair i = p))).length := by
          intro l; induction l with
          | nil => rfl
          | cons i ls ih =>
            rw [List.flatMap_cons, countNat_append, ih, (hfPair i).2.1, List.filter_cons]
            by_cases heq : fPair i = p
            · simp only [heq, decide_true, ↓reduceIte, List.length_cons, countNat,
                show siteStart + 2 * p.val ≠ siteStart + 2 * p.val + 1 by omega]; omega
            · have hne1 : siteStart + 2 * p.val ≠ siteStart + 2 * (fPair i).val := fun h => heq (Fin.ext (by omega))
              have hne2 : siteStart + 2 * p.val ≠ siteStart + 2 * (fPair i).val + 1 := by omega
              simp only [decide_eq_false heq, Bool.false_eq_true, ↓reduceIte,
                countNat, ite_eq_right hne1, ite_eq_right hne2]; omega
        rw [hallEq, aux]
        have hnd : (List.finRange g).Nodup := List.nodup_finRange g
        rw [← List.toFinset_card_of_nodup (hnd.filter _)]
        congr 1; ext i; simp
      have hfBij : Function.Bijective fPair := by
        constructor
        · intro i₁ i₂ hEq
          have hrMem : siteStart + 2 * (fPair i₁).val ∈ siteRows :=
            List.mem_range'.mpr ⟨2 * (fPair i₁).val, by have := (fPair i₁).isLt; omega, by omega⟩
          have hcard1 : (Finset.univ.filter (fun i : Fin g => fPair i = fPair i₁)).card = 1 := by
            rw [← hallCount (fPair i₁), hcnt1 _ hrMem]
          have hm1 : i₁ ∈ Finset.univ.filter (fun i : Fin g => fPair i = fPair i₁) := by simp
          have hm2 : i₂ ∈ Finset.univ.filter (fun i : Fin g => fPair i = fPair i₁) := by simp [hEq]
          exact Finset.card_le_one.mp (le_of_eq hcard1) i₁ hm1 i₂ hm2
        · intro p
          have hrMem : siteStart + 2 * p.val ∈ siteRows :=
            List.mem_range'.mpr ⟨2 * p.val, by have := p.isLt; omega, by omega⟩
          have hcard1 : (Finset.univ.filter (fun i : Fin g => fPair i = p)).card = 1 := by
            rw [← hallCount p, hcnt1 _ hrMem]
          obtain ⟨i, hi⟩ := Finset.card_pos.mp (hcard1.symm ▸ Nat.zero_lt_one)
          exact ⟨i, (Finset.mem_filter.mp hi).2⟩
      let e := Equiv.ofBijective fPair hfBij
      refine ⟨e.symm, ⟨hhiLast, htsLastEmpty, hlinLast⟩, fun p => ?_⟩
      have hpEq : fPair (e.symm p) = p := e.apply_symm_apply p
      have hfp := hfPair (e.symm p)
      rw [hpEq] at hfp
      exact hfp

end AuditInversion

/-! ## 3. Generic Standard & `H` PCS Opening Reconstruction from `PcsStdView` / `PcsAHView` -/

section PcsOpeningRecon

/-- Extract the exact `k`-th entry (`k < 2^logN + 256`) of `Row K (2^logN) 256`. -/
def rowAt {K : Type} [Zero K] {n Q : ℕ} (r : Hiding.Row K n Q) (k : ℕ) : K :=
  if h1 : k < n then r (Sum.inl ⟨k, h1⟩)
  else if h2 : k - n < Q then r (Sum.inr ⟨k - n, h2⟩)
  else 0

private theorem fin_sum_split_std (d g : ℕ) (f : Fin (d + 2 * g + 2) → shdP_K) :
    ∑ r : Fin (d + 2 * g + 2), f r =
      (∑ i : Fin d, f ⟨i.val, by omega⟩)
      + (∑ q : Fin g, (f ⟨d + 2 * q.val, by omega⟩ + f ⟨d + 2 * q.val + 1, by omega⟩))
      + (f ⟨d + 2 * g, by omega⟩ + f ⟨d + 2 * g + 1, by omega⟩) := by
  rw [Fin.sum_univ_castSucc, Fin.sum_univ_castSucc]
  have h1 : ∀ (m : ℕ) (h : Fin (d + 2 * m) → shdP_K),
      ∑ r : Fin (d + 2 * m), h r =
        (∑ i : Fin d, h ⟨i.val, by omega⟩) +
        ∑ q : Fin m, (h ⟨d + 2 * q.val, by omega⟩ + h ⟨d + 2 * q.val + 1, by omega⟩) := by
    intro m; induction m with
    | zero => intro h; simp
    | succ m' ihm =>
      intro h
      have hstep : ∑ r : Fin (d + 2 * (m' + 1)), h r =
          (∑ r : Fin (d + 2 * m'), h ⟨r.val, by omega⟩) +
          h ⟨d + 2 * m', by omega⟩ + h ⟨d + 2 * m' + 1, by omega⟩ := by
        rw [show ∑ r : Fin (d + 2 * (m' + 1)), h r =
              ∑ r : Fin (d + 2 * m' + 1 + 1), h ⟨r.val, by omega⟩ by
            refine Fintype.sum_equiv (finCongr (by omega)) _ _ fun r => by simp [finCongr]]
        rw [Fin.sum_univ_castSucc, Fin.sum_univ_castSucc]
        rfl
      rw [hstep, ihm (fun r => h ⟨r.val, by omega⟩), Fin.sum_univ_castSucc]
      simp only [Fin.val_castSucc, Fin.val_last]
      ring
  have hm := h1 g (fun r => f ⟨r.val, by omega⟩)
  have hcast : ∑ r : Fin (d + 2 * g), f r.castSucc.castSucc = ∑ r : Fin (d + 2 * g), f ⟨r.val, by omega⟩ := rfl
  have hl1 : (Fin.last (d + 2 * g)).castSucc = (⟨d + 2 * g, by omega⟩ : Fin (d + 2 * g + 2)) := rfl
  have hl2 : Fin.last (d + 2 * g + 1) = (⟨d + 2 * g + 1, by omega⟩ : Fin (d + 2 * g + 2)) := rfl
  rw [hcast, hm, hl1, hl2]; ring

/-- For a standard PCS table with `d` data rows (`0..d-1`), `g` site pairs (`d..d+2g-1`), and
`2` prox rows (`d+2g..d+2g+1`), pack `(d, site, prox)` row vectors into `Fin (d + 2*g + 2) → Row GF n 256`. -/
def stdRowOf {n d g : ℕ} (dat : Fin d → Fin n → GF) (c : Hiding.Coins GF n 256 (Fin d) (Fin g))
    (r : Fin (d + 2 * g + 2)) : Hiding.Row GF n 256 :=
  if h1 : r.val < d then Sum.elim (dat ⟨r.val, h1⟩) (c.1 ⟨r.val, h1⟩)
  else if h2 : r.val < d + 2 * g then
    c.2.1 (⟨(r.val - d) / 2, by omega⟩, decide ((r.val - d) % 2 = 0))
  else
    c.2.2 (decide (r.val = d + 2 * g))

/-- Standard PCS table's `combAt` on an audited claim `c` (touching only site pair `p` and rows `< d`)
equals `openingView.1 p` at every `k < n + 256`! -/
theorem stdClaim_combAt_eq_view {n d g kOpen : ℕ} {E : Matrix (Fin kOpen) (Fin n ⊕ Fin 256) GF}
    (ω : Hiding.Weights shdP_K (Fin d) (Fin g))
    (dat : Fin d → Fin n → GF) (c : Hiding.Coins GF n 256 (Fin d) (Fin g))
    (rows : List (List Fp)) (hrowsLen : rows.length = d + 2 * g + 2)
    (hrowsEq : ∀ (r : Fin (d + 2 * g + 2)) (k : ℕ) (hk : k < n + 256),
      ((rows.getD r.val []).getD k Fp.zero).toGF = rowAt (stdRowOf dat c r) k)
    (rw : List Fp2) (hrwLen : rw.length = d + 2 * g + 2) (p : Fin g)
    (hwD : ∀ i : Fin d, (rw.getD i.val Fp2.zero).toK shdP_U = ω.wD p i)
    (hwSite : ∀ q : Fin g, ∀ b : Bool,
      (rw.getD (d + 2 * q.val + if b then 0 else 1) Fp2.zero).toK shdP_U =
        if q = p then (if b then ω.a p else ω.b p) else 0)
    (hwProx : (rw.getD (d + 2 * g) Fp2.zero).toK shdP_U = 0
      ∧ (rw.getD (d + 2 * g + 1) Fp2.zero).toK shdP_U = 0)
    (k : ℕ) (hk : k < n + 256) :
    (combAt rw rows k).toK shdP_U = rowAt ((Hiding.openingView E ω dat c).1 p) k := by
  rw [toK_combAt shdP_U rw rows (by rw [hrwLen, hrowsLen]) k, hrowsLen, Finset.sum_range, fin_sum_split_std]
  -- Simplify each of the 3 parts: data rows, site pairs, prox pair
  have hprox0 :
      (rw.getD (d + 2 * g) Fp2.zero).toK shdP_U * algebraMap GF shdP_K ((rows.getD (d + 2 * g) []).getD k Fp.zero).toGF
      + (rw.getD (d + 2 * g + 1) Fp2.zero).toK shdP_U * algebraMap GF shdP_K ((rows.getD (d + 2 * g + 1) []).getD k Fp.zero).toGF
      = 0 := by rw [hwProx.1, hwProx.2, zero_mul, zero_mul, add_zero]
  rw [hprox0, add_zero]
  have hsite :
      ∑ q : Fin g,
        ((rw.getD (d + 2 * q.val) Fp2.zero).toK shdP_U * algebraMap GF shdP_K ((rows.getD (d + 2 * q.val) []).getD k Fp.zero).toGF
        + (rw.getD (d + 2 * q.val + 1) Fp2.zero).toK shdP_U * algebraMap GF shdP_K ((rows.getD (d + 2 * q.val + 1) []).getD k Fp.zero).toGF)
      = ω.a p * algebraMap GF shdP_K (rowAt (c.2.1 (p, true)) k)
        + ω.b p * algebraMap GF shdP_K (rowAt (c.2.1 (p, false)) k) := by
    rw [Finset.sum_eq_single p]
    · have ha := hwSite p true; simp only [↓reduceIte, Nat.add_zero] at ha
      have hb := hwSite p false; simp only [↓reduceIte, Bool.false_eq_true] at hb
      rw [ha, hb, hrowsEq ⟨d + 2 * p.val, by omega⟩ k hk, hrowsEq ⟨d + 2 * p.val + 1, by omega⟩ k hk]
      have hs1 : stdRowOf dat c ⟨d + 2 * p.val, by omega⟩ = c.2.1 (p, true) := by
        unfold stdRowOf; dsimp only
        rw [dite_eq_right (by omega), dite_eq_left (by omega)]
        exact congrArg c.2.1 (Prod.ext (Fin.ext (by dsimp only; omega)) (decide_eq_true (by omega)))
      have hs2 : stdRowOf dat c ⟨d + 2 * p.val + 1, by omega⟩ = c.2.1 (p, false) := by
        unfold stdRowOf; dsimp only
        rw [dite_eq_right (by omega), dite_eq_left (by omega)]
        exact congrArg c.2.1 (Prod.ext (Fin.ext (by dsimp only; omega)) (decide_eq_false (by omega)))
      rw [hs1, hs2]
    · intro q _ hne
      have ha := hwSite q true; simp only [↓reduceIte, Nat.add_zero, ite_eq_right hne] at ha
      have hb := hwSite q false; simp only [Bool.false_eq_true, ↓reduceIte, ite_eq_right hne] at hb
      rw [ha, hb, zero_mul, zero_mul, add_zero]
    · intro h; exact absurd (Finset.mem_univ p) h
  rw [hsite]
  have hdat :
      ∑ i : Fin d, (rw.getD i.val Fp2.zero).toK shdP_U * algebraMap GF shdP_K ((rows.getD i.val []).getD k Fp.zero).toGF
      = ∑ i : Fin d, ω.wD p i * algebraMap GF shdP_K (rowAt (Sum.elim (dat i) (c.1 i)) k) := by
    refine Finset.sum_congr rfl fun i _ => ?_
    rw [hwD i, hrowsEq ⟨i.val, by omega⟩ k hk]
    have hs : stdRowOf dat c ⟨i.val, by omega⟩ = Sum.elim (dat i) (c.1 i) := by
      unfold stdRowOf; dsimp only; rw [dite_eq_left i.isLt]
    rw [hs]
  rw [hdat]
  unfold Hiding.openingView rowAt; dsimp only
  by_cases h1 : k < n
  · simp only [dite_eq_left h1]; ring
  · have h2 : k - n < 256 := by omega
    simp only [dite_eq_right h1, dite_eq_left h2]; ring

/-- Standard PCS table's proximity vector `combAt proxRho rows k` equals `openingView.2.1` at every `k < n + 256`. -/
theorem stdProx_combAt_eq_view {n d g kOpen : ℕ} {E : Matrix (Fin kOpen) (Fin n ⊕ Fin 256) GF}
    (ω : Hiding.Weights shdP_K (Fin d) (Fin g))
    (dat : Fin d → Fin n → GF) (c : Hiding.Coins GF n 256 (Fin d) (Fin g))
    (rows : List (List Fp)) (hrowsLen : rows.length = d + 2 * g + 2)
    (hrowsEq : ∀ (r : Fin (d + 2 * g + 2)) (k : ℕ) (hk : k < n + 256),
      ((rows.getD r.val []).getD k Fp.zero).toGF = rowAt (stdRowOf dat c r) k)
    (proxRho : List Fp2) (hproxLen : proxRho.length = d + 2 * g + 2)
    (hpD : ∀ i : Fin d, (proxRho.getD i.val Fp2.zero).toK shdP_U = ω.pD i)
    (hpG : ∀ q : Fin g, ∀ b : Bool,
      (proxRho.getD (d + 2 * q.val + if b then 0 else 1) Fp2.zero).toK shdP_U = ω.pG (q, b))
    (hpa : (proxRho.getD (d + 2 * g) Fp2.zero).toK shdP_U = ω.pa)
    (hpb : (proxRho.getD (d + 2 * g + 1) Fp2.zero).toK shdP_U = ω.pb)
    (k : ℕ) (hk : k < n + 256) :
    (combAt proxRho rows k).toK shdP_U = rowAt ((Hiding.openingView E ω dat c).2.1) k := by
  rw [toK_combAt shdP_U proxRho rows (by rw [hproxLen, hrowsLen]) k, hrowsLen, Finset.sum_range, fin_sum_split_std]
  have hdat :
      ∑ i : Fin d, (proxRho.getD i.val Fp2.zero).toK shdP_U * algebraMap GF shdP_K ((rows.getD i.val []).getD k Fp.zero).toGF
      = ∑ i : Fin d, ω.pD i * algebraMap GF shdP_K (rowAt (Sum.elim (dat i) (c.1 i)) k) := by
    refine Finset.sum_congr rfl fun i _ => ?_
    rw [hpD i, hrowsEq ⟨i.val, by omega⟩ k hk]
    have hs : stdRowOf dat c ⟨i.val, by omega⟩ = Sum.elim (dat i) (c.1 i) := by
      unfold stdRowOf; dsimp only; rw [dite_eq_left i.isLt]
    rw [hs]
  have hsite :
      ∑ q : Fin g,
        ((proxRho.getD (d + 2 * q.val) Fp2.zero).toK shdP_U * algebraMap GF shdP_K ((rows.getD (d + 2 * q.val) []).getD k Fp.zero).toGF
        + (proxRho.getD (d + 2 * q.val + 1) Fp2.zero).toK shdP_U * algebraMap GF shdP_K ((rows.getD (d + 2 * q.val + 1) []).getD k Fp.zero).toGF)
      = ∑ gs : Fin g × Bool, ω.pG gs * algebraMap GF shdP_K (rowAt (c.2.1 gs) k) := by
    rw [Fintype.sum_prod_type]
    refine Finset.sum_congr rfl fun q _ => ?_
    rw [Fintype.sum_bool]
    have ha := hpG q true; simp only [↓reduceIte, Nat.add_zero] at ha
    have hb := hpG q false; simp only [Bool.false_eq_true, ↓reduceIte] at hb
    rw [ha, hb, hrowsEq ⟨d + 2 * q.val, by omega⟩ k hk, hrowsEq ⟨d + 2 * q.val + 1, by omega⟩ k hk]
    have hs1 : stdRowOf dat c ⟨d + 2 * q.val, by omega⟩ = c.2.1 (q, true) := by
      unfold stdRowOf; dsimp only; rw [dite_eq_right (by omega), dite_eq_left (by omega)]
      exact congrArg c.2.1 (Prod.ext (Fin.ext (by dsimp only; omega)) (decide_eq_true (by omega)))
    have hs2 : stdRowOf dat c ⟨d + 2 * q.val + 1, by omega⟩ = c.2.1 (q, false) := by
      unfold stdRowOf; dsimp only; rw [dite_eq_right (by omega), dite_eq_left (by omega)]
      exact congrArg c.2.1 (Prod.ext (Fin.ext (by dsimp only; omega)) (decide_eq_false (by omega)))
    rw [hs1, hs2]
  have hprx :
      (proxRho.getD (d + 2 * g) Fp2.zero).toK shdP_U * algebraMap GF shdP_K ((rows.getD (d + 2 * g) []).getD k Fp.zero).toGF
      + (proxRho.getD (d + 2 * g + 1) Fp2.zero).toK shdP_U * algebraMap GF shdP_K ((rows.getD (d + 2 * g + 1) []).getD k Fp.zero).toGF
      = ω.pa * algebraMap GF shdP_K (rowAt (c.2.2 true) k) + ω.pb * algebraMap GF shdP_K (rowAt (c.2.2 false) k) := by
    rw [hpa, hpb, hrowsEq ⟨d + 2 * g, by omega⟩ k hk, hrowsEq ⟨d + 2 * g + 1, by omega⟩ k hk]
    have hs1 : stdRowOf dat c ⟨d + 2 * g, by omega⟩ = c.2.2 true := by
      unfold stdRowOf; dsimp only; rw [dite_eq_right (by omega), dite_eq_right (by omega)]; simp
    have hs2 : stdRowOf dat c ⟨d + 2 * g + 1, by omega⟩ = c.2.2 false := by
      unfold stdRowOf; dsimp only; rw [dite_eq_right (by omega), dite_eq_right (by omega)]
      simp [show d + 2 * g + 1 ≠ d + 2 * g by omega]
    rw [hs1, hs2]
  rw [hdat, hsite, hprx]
  unfold Hiding.openingView rowAt; dsimp only
  by_cases h1 : k < n
  · simp only [dite_eq_left h1]; ring
  · have h2 : k - n < 256 := by omega
    simp only [dite_eq_right h1, dite_eq_left h2]; ring

/-- Pack `(d, H_U, site, prox)` row vectors of an `H` PCS table into `Fin (d + 2 + 2*g + 2) → Row GF n 256`. -/
def hRowOf {n d g : ℕ} (dat : Fin d → Fin n → GF) (c : Hiding.CoinsH GF n 256 (Fin d) (Fin g))
    (r : Fin (d + 2 + 2 * g + 2)) : Hiding.Row GF n 256 :=
  if h1 : r.val < d then Sum.elim (dat ⟨r.val, h1⟩) (c.1 ⟨r.val, h1⟩)
  else if h2 : r.val < d + 2 then
    Hiding.zsRow shdP_zsGen (c.2.1 (decide (r.val = d)))
  else if h3 : r.val < d + 2 + 2 * g then
    c.2.2.1 (⟨(r.val - (d + 2)) / 2, by omega⟩, decide ((r.val - (d + 2)) % 2 = 0))
  else
    c.2.2.2 (decide (r.val = d + 2 + 2 * g))

/-- **`H`-table sum-claim vector** equals `openingViewH.1` at every `k < n + 256`. -/
theorem hSumClaim_combAt_eq_view {n d g kOpen : ℕ} {E : Matrix (Fin kOpen) (Fin n ⊕ Fin 256) GF}
    (ω : Hiding.WeightsH shdP_K (Fin d) (Fin g))
    (dat : Fin d → Fin n → GF) (c : Hiding.CoinsH GF n 256 (Fin d) (Fin g))
    (rows : List (List Fp)) (hrowsLen : rows.length = d + 2 + 2 * g + 2)
    (hrowsEq : ∀ (r : Fin (d + 2 + 2 * g + 2)) (k : ℕ) (hk : k < n + 256),
      ((rows.getD r.val []).getD k Fp.zero).toGF = rowAt (hRowOf dat c r) k)
    (rw : List Fp2) (hrwLen : rw.length = d + 2 + 2 * g + 2)
    (hsD : ∀ i : Fin d, (rw.getD i.val Fp2.zero).toK shdP_U = ω.sD i)
    (hsa : (rw.getD d Fp2.zero).toK shdP_U = ω.sa)
    (hsb : (rw.getD (d + 1) Fp2.zero).toK shdP_U = ω.sb)
    (hrest0 : ∀ r : ℕ, d + 2 ≤ r → r < d + 2 + 2 * g + 2 → (rw.getD r Fp2.zero).toK shdP_U = 0)
    (k : ℕ) (hk : k < n + 256) :
    (combAt rw rows k).toK shdP_U = rowAt ((Hiding.openingViewH E shdP_zsGen ω dat c).1) k := by
  rw [toK_combAt shdP_U rw rows (by rw [hrwLen, hrowsLen]) k, hrowsLen,
    show d + 2 + 2 * g + 2 = (d + 2) + (2 * g + 2) by omega, Finset.sum_range_add]
  have htail0 : ∑ j ∈ Finset.range (2 * g + 2),
      (rw.getD (d + 2 + j) Fp2.zero).toK shdP_U *
        algebraMap GF shdP_K ((rows.getD (d + 2 + j) []).getD k Fp.zero).toGF = 0 :=
    Finset.sum_eq_zero fun j hj => by
      rw [hrest0 (d + 2 + j) (by omega) (by have := Finset.mem_range.mp hj; omega), zero_mul]
  rw [htail0, add_zero, Finset.sum_range_succ, Finset.sum_range_succ, Finset.sum_range]
  have hdat :
      ∑ i : Fin d, (rw.getD i.val Fp2.zero).toK shdP_U * algebraMap GF shdP_K ((rows.getD i.val []).getD k Fp.zero).toGF
      = ∑ i : Fin d, ω.sD i * algebraMap GF shdP_K (rowAt (Sum.elim (dat i) (c.1 i)) k) := by
    refine Finset.sum_congr rfl fun i _ => ?_
    rw [hsD i, hrowsEq ⟨i.val, by omega⟩ k hk]
    have hs : hRowOf dat c ⟨i.val, by omega⟩ = Sum.elim (dat i) (c.1 i) := by
      unfold hRowOf; dsimp only; rw [dite_eq_left i.isLt]
    rw [hs]
  have hu0 : hRowOf dat c ⟨d, by omega⟩ = Hiding.zsRow shdP_zsGen (c.2.1 true) := by
    unfold hRowOf; dsimp only; rw [dite_eq_right (by omega), dite_eq_left (by omega)]; simp
  have hu1 : hRowOf dat c ⟨d + 1, by omega⟩ = Hiding.zsRow shdP_zsGen (c.2.1 false) := by
    unfold hRowOf; dsimp only; rw [dite_eq_right (by omega), dite_eq_left (by omega)]
    simp [show d + 1 ≠ d by omega]
  rw [hdat, hsa, hsb, hrowsEq ⟨d, by omega⟩ k hk, hrowsEq ⟨d + 1, by omega⟩ k hk, hu0, hu1]
  unfold Hiding.openingViewH rowAt; dsimp only
  by_cases h1 : k < n
  · simp only [dite_eq_left h1]
  · have h2 : k - n < 256 := by omega
    simp only [dite_eq_right h1, dite_eq_left h2]

/-- **`H`-table evaluation-claim vector** equals `openingViewH.2.1 p` at every `k < n + 256`. -/
theorem hEvalClaim_combAt_eq_view {n d g kOpen : ℕ} {E : Matrix (Fin kOpen) (Fin n ⊕ Fin 256) GF}
    (ω : Hiding.WeightsH shdP_K (Fin d) (Fin g))
    (dat : Fin d → Fin n → GF) (c : Hiding.CoinsH GF n 256 (Fin d) (Fin g))
    (rows : List (List Fp)) (hrowsLen : rows.length = d + 2 + 2 * g + 2)
    (hrowsEq : ∀ (r : Fin (d + 2 + 2 * g + 2)) (k : ℕ) (hk : k < n + 256),
      ((rows.getD r.val []).getD k Fp.zero).toGF = rowAt (hRowOf dat c r) k)
    (rw : List Fp2) (hrwLen : rw.length = d + 2 + 2 * g + 2) (p : Fin g)
    (hwD : ∀ i : Fin d, (rw.getD i.val Fp2.zero).toK shdP_U = ω.wD p i)
    (hwU : (rw.getD d Fp2.zero).toK shdP_U = ω.wU p true ∧ (rw.getD (d + 1) Fp2.zero).toK shdP_U = ω.wU p false)
    (hwSite : ∀ q : Fin g, ∀ b : Bool,
      (rw.getD (d + 2 + 2 * q.val + if b then 0 else 1) Fp2.zero).toK shdP_U =
        if q = p then (if b then ω.a p else ω.b p) else 0)
    (hwProx : (rw.getD (d + 2 + 2 * g) Fp2.zero).toK shdP_U = 0
      ∧ (rw.getD (d + 2 + 2 * g + 1) Fp2.zero).toK shdP_U = 0)
    (k : ℕ) (hk : k < n + 256) :
    (combAt rw rows k).toK shdP_U = rowAt ((Hiding.openingViewH E shdP_zsGen ω dat c).2.1 p) k := by
  have hsum2 : ∀ f : ℕ → shdP_K, ∑ x ∈ Finset.range 2, f x = f 0 + f 1 := fun f => by
    rw [Finset.sum_range_succ, Finset.sum_range_one]
  rw [toK_combAt shdP_U rw rows (by rw [hrwLen, hrowsLen]) k, hrowsLen]
  rw [show d + 2 + 2 * g + 2 = ((d + 2) + 2 * g) + 2 by omega,
    Finset.sum_range_add, Finset.sum_range_add, hsum2]
  have hprox0 :
      (rw.getD (d + 2 + 2 * g + 0) Fp2.zero).toK shdP_U * algebraMap GF shdP_K ((rows.getD (d + 2 + 2 * g + 0) []).getD k Fp.zero).toGF
      + (rw.getD (d + 2 + 2 * g + 1) Fp2.zero).toK shdP_U * algebraMap GF shdP_K ((rows.getD (d + 2 + 2 * g + 1) []).getD k Fp.zero).toGF
      = 0 := by simp only [Nat.add_zero, hwProx.1, hwProx.2, zero_mul, add_zero]
  rw [hprox0, add_zero, Finset.sum_range_succ, Finset.sum_range_succ, Finset.sum_range]
  have hdat :
      ∑ i : Fin d, (rw.getD i.val Fp2.zero).toK shdP_U * algebraMap GF shdP_K ((rows.getD i.val []).getD k Fp.zero).toGF
      = ∑ i : Fin d, ω.wD p i * algebraMap GF shdP_K (rowAt (Sum.elim (dat i) (c.1 i)) k) := by
    refine Finset.sum_congr rfl fun i _ => ?_
    rw [hwD i, hrowsEq ⟨i.val, by omega⟩ k hk]
    have hs : hRowOf dat c ⟨i.val, by omega⟩ = Sum.elim (dat i) (c.1 i) := by
      unfold hRowOf; dsimp only; rw [dite_eq_left i.isLt]
    rw [hs]
  have hu0 : hRowOf dat c ⟨d, by omega⟩ = Hiding.zsRow shdP_zsGen (c.2.1 true) := by
    unfold hRowOf; dsimp only; rw [dite_eq_right (by omega), dite_eq_left (by omega)]; simp
  have hu1 : hRowOf dat c ⟨d + 1, by omega⟩ = Hiding.zsRow shdP_zsGen (c.2.1 false) := by
    unfold hRowOf; dsimp only; rw [dite_eq_right (by omega), dite_eq_left (by omega)]
    simp [show d + 1 ≠ d by omega]
  have hsite :
      ∑ j ∈ Finset.range (2 * g),
        (rw.getD (d + 2 + j) Fp2.zero).toK shdP_U * algebraMap GF shdP_K ((rows.getD (d + 2 + j) []).getD k Fp.zero).toGF
      = ω.a p * algebraMap GF shdP_K (rowAt (c.2.2.1 (p, true)) k)
        + ω.b p * algebraMap GF shdP_K (rowAt (c.2.2.1 (p, false)) k) := by
    have hpairSum : ∀ (m : ℕ) (f : ℕ → shdP_K),
        ∑ j ∈ Finset.range (2 * m), f j = ∑ q : Fin m, (f (2 * q.val) + f (2 * q.val + 1)) := by
      intro m f; induction m with
      | zero => simp
      | succ m' ihm =>
        rw [show 2 * (m' + 1) = 2 * m' + 2 by omega, Finset.sum_range_add, Finset.sum_range_succ,
          Finset.sum_range_one, ihm, Fin.sum_univ_castSucc]
        simp only [Fin.val_castSucc, Fin.val_last, Nat.add_zero]
    rw [hpairSum, Finset.sum_eq_single p]
    · have ha := hwSite p true; simp only [↓reduceIte, Nat.add_zero] at ha
      have hb := hwSite p false; simp only [↓reduceIte, Bool.false_eq_true] at hb
      rw [show d + 2 + (2 * p.val + 1) = d + 2 + 2 * p.val + 1 by omega,
        ha, hb, hrowsEq ⟨d + 2 + 2 * p.val, by omega⟩ k hk, hrowsEq ⟨d + 2 + 2 * p.val + 1, by omega⟩ k hk]
      have hs1 : hRowOf dat c ⟨d + 2 + 2 * p.val, by omega⟩ = c.2.2.1 (p, true) := by
        unfold hRowOf; dsimp only; rw [dite_eq_right (by omega), dite_eq_right (by omega), dite_eq_left (by omega)]
        exact congrArg c.2.2.1 (Prod.ext (Fin.ext (by dsimp only; omega)) (decide_eq_true (by omega)))
      have hs2 : hRowOf dat c ⟨d + 2 + 2 * p.val + 1, by omega⟩ = c.2.2.1 (p, false) := by
        unfold hRowOf; dsimp only; rw [dite_eq_right (by omega), dite_eq_right (by omega), dite_eq_left (by omega)]
        exact congrArg c.2.2.1 (Prod.ext (Fin.ext (by dsimp only; omega)) (decide_eq_false (by omega)))
      rw [hs1, hs2]
    · intro q _ hne
      have ha := hwSite q true; simp only [↓reduceIte, Nat.add_zero, ite_eq_right hne] at ha
      have hb := hwSite q false; simp only [Bool.false_eq_true, ↓reduceIte, ite_eq_right hne] at hb
      rw [show d + 2 + (2 * q.val + 1) = d + 2 + 2 * q.val + 1 by omega, ha, hb, zero_mul, zero_mul, add_zero]
    · intro h; exact absurd (Finset.mem_univ p) h
  rw [hdat, hwU.1, hwU.2, hrowsEq ⟨d, by omega⟩ k hk, hrowsEq ⟨d + 1, by omega⟩ k hk, hu0, hu1, hsite]
  unfold Hiding.openingViewH rowAt; dsimp only
  by_cases h1 : k < n
  · simp only [dite_eq_left h1, Fintype.sum_bool]; ring
  · have h2 : k - n < 256 := by omega
    simp only [dite_eq_right h1, dite_eq_left h2, Fintype.sum_bool]; ring

/-- **`H`-table proximity vector** equals `openingViewH.2.2.1` at every `k < n + 256`. -/
theorem hProx_combAt_eq_view {n d g kOpen : ℕ} {E : Matrix (Fin kOpen) (Fin n ⊕ Fin 256) GF}
    (ω : Hiding.WeightsH shdP_K (Fin d) (Fin g))
    (dat : Fin d → Fin n → GF) (c : Hiding.CoinsH GF n 256 (Fin d) (Fin g))
    (rows : List (List Fp)) (hrowsLen : rows.length = d + 2 + 2 * g + 2)
    (hrowsEq : ∀ (r : Fin (d + 2 + 2 * g + 2)) (k : ℕ) (hk : k < n + 256),
      ((rows.getD r.val []).getD k Fp.zero).toGF = rowAt (hRowOf dat c r) k)
    (proxRho : List Fp2) (hproxLen : proxRho.length = d + 2 + 2 * g + 2)
    (hpD : ∀ i : Fin d, (proxRho.getD i.val Fp2.zero).toK shdP_U = ω.pD i)
    (hpU : (proxRho.getD d Fp2.zero).toK shdP_U = ω.pU true ∧ (proxRho.getD (d + 1) Fp2.zero).toK shdP_U = ω.pU false)
    (hpG : ∀ q : Fin g, ∀ b : Bool,
      (proxRho.getD (d + 2 + 2 * q.val + if b then 0 else 1) Fp2.zero).toK shdP_U = ω.pG (q, b))
    (hpa : (proxRho.getD (d + 2 + 2 * g) Fp2.zero).toK shdP_U = ω.pa)
    (hpb : (proxRho.getD (d + 2 + 2 * g + 1) Fp2.zero).toK shdP_U = ω.pb)
    (k : ℕ) (hk : k < n + 256) :
    (combAt proxRho rows k).toK shdP_U = rowAt ((Hiding.openingViewH E shdP_zsGen ω dat c).2.2.1) k := by
  have hsum2 : ∀ f : ℕ → shdP_K, ∑ x ∈ Finset.range 2, f x = f 0 + f 1 := fun f => by
    rw [Finset.sum_range_succ, Finset.sum_range_one]
  rw [toK_combAt shdP_U proxRho rows (by rw [hproxLen, hrowsLen]) k, hrowsLen,
    show d + 2 + 2 * g + 2 = ((d + 2) + 2 * g) + 2 by omega,
    Finset.sum_range_add, Finset.sum_range_add, hsum2,
    Finset.sum_range_succ, Finset.sum_range_succ, Finset.sum_range]
  have hdat :
      ∑ i : Fin d, (proxRho.getD i.val Fp2.zero).toK shdP_U * algebraMap GF shdP_K ((rows.getD i.val []).getD k Fp.zero).toGF
      = ∑ i : Fin d, ω.pD i * algebraMap GF shdP_K (rowAt (Sum.elim (dat i) (c.1 i)) k) := by
    refine Finset.sum_congr rfl fun i _ => ?_
    rw [hpD i, hrowsEq ⟨i.val, by omega⟩ k hk]
    have hs : hRowOf dat c ⟨i.val, by omega⟩ = Sum.elim (dat i) (c.1 i) := by
      unfold hRowOf; dsimp only; rw [dite_eq_left i.isLt]
    rw [hs]
  have hu0 : hRowOf dat c ⟨d, by omega⟩ = Hiding.zsRow shdP_zsGen (c.2.1 true) := by
    unfold hRowOf; dsimp only; rw [dite_eq_right (by omega), dite_eq_left (by omega)]; simp
  have hu1 : hRowOf dat c ⟨d + 1, by omega⟩ = Hiding.zsRow shdP_zsGen (c.2.1 false) := by
    unfold hRowOf; dsimp only; rw [dite_eq_right (by omega), dite_eq_left (by omega)]
    simp [show d + 1 ≠ d by omega]
  have hsite :
      ∑ j ∈ Finset.range (2 * g),
        (proxRho.getD (d + 2 + j) Fp2.zero).toK shdP_U * algebraMap GF shdP_K ((rows.getD (d + 2 + j) []).getD k Fp.zero).toGF
      = ∑ gs : Fin g × Bool, ω.pG gs * algebraMap GF shdP_K (rowAt (c.2.2.1 gs) k) := by
    have hpairSum : ∀ (m : ℕ) (f : ℕ → shdP_K),
        ∑ j ∈ Finset.range (2 * m), f j = ∑ q : Fin m, (f (2 * q.val) + f (2 * q.val + 1)) := by
      intro m f; induction m with
      | zero => simp
      | succ m' ihm =>
        rw [show 2 * (m' + 1) = 2 * m' + 2 by omega, Finset.sum_range_add, Finset.sum_range_succ,
          Finset.sum_range_one, ihm, Fin.sum_univ_castSucc]
        simp only [Fin.val_castSucc, Fin.val_last, Nat.add_zero]
    rw [hpairSum, Fintype.sum_prod_type]
    refine Finset.sum_congr rfl fun q _ => ?_
    rw [Fintype.sum_bool]
    have ha := hpG q true; simp only [↓reduceIte, Nat.add_zero] at ha
    have hb := hpG q false; simp only [Bool.false_eq_true, ↓reduceIte] at hb
    rw [show d + 2 + (2 * q.val + 1) = d + 2 + 2 * q.val + 1 by omega,
      ha, hb, hrowsEq ⟨d + 2 + 2 * q.val, by omega⟩ k hk, hrowsEq ⟨d + 2 + 2 * q.val + 1, by omega⟩ k hk]
    have hs1 : hRowOf dat c ⟨d + 2 + 2 * q.val, by omega⟩ = c.2.2.1 (q, true) := by
      unfold hRowOf; dsimp only; rw [dite_eq_right (by omega), dite_eq_right (by omega), dite_eq_left (by omega)]
      exact congrArg c.2.2.1 (Prod.ext (Fin.ext (by dsimp only; omega)) (decide_eq_true (by omega)))
    have hs2 : hRowOf dat c ⟨d + 2 + 2 * q.val + 1, by omega⟩ = c.2.2.1 (q, false) := by
      unfold hRowOf; dsimp only; rw [dite_eq_right (by omega), dite_eq_right (by omega), dite_eq_left (by omega)]
      exact congrArg c.2.2.1 (Prod.ext (Fin.ext (by dsimp only; omega)) (decide_eq_false (by omega)))
    rw [hs1, hs2]
  have hp0 : hRowOf dat c ⟨d + 2 + 2 * g, by omega⟩ = c.2.2.2 true := by
    unfold hRowOf; dsimp only
    rw [dite_eq_right (by omega), dite_eq_right (by omega), dite_eq_right (by omega)]; simp
  have hp1 : hRowOf dat c ⟨d + 2 + 2 * g + 1, by omega⟩ = c.2.2.2 false := by
    unfold hRowOf; dsimp only
    rw [dite_eq_right (by omega), dite_eq_right (by omega), dite_eq_right (by omega)]
    simp [show d + 2 + 2 * g + 1 ≠ d + 2 + 2 * g by omega]
  simp only [Nat.add_zero]
  rw [hdat, hpU.1, hpU.2, hpa, hpb,
    hrowsEq ⟨d, by omega⟩ k hk, hrowsEq ⟨d + 1, by omega⟩ k hk,
    hrowsEq ⟨d + 2 + 2 * g, by omega⟩ k hk, hrowsEq ⟨d + 2 + 2 * g + 1, by omega⟩ k hk,
    hu0, hu1, hp0, hp1, hsite]
  unfold Hiding.openingViewH rowAt; dsimp only
  by_cases h1 : k < n
  · simp only [dite_eq_left h1, Fintype.sum_bool]; ring
  · have h2 : k - n < 256 := by omega
    simp only [dite_eq_right h1, dite_eq_left h2, Fintype.sum_bool]; ring

/-- **`ClaimTrue` value recovery from a single claim vector `v_g`**:
given `ClaimTrue` on `z` and `combAt (claimWeights z).1 rows t = v_g (Sum.inl t)` for all `t < 2^lc`,
`z.value.toK shdP_U` equals `∑ t : Fin (2^lc), v_g (Sum.inl t) * (zkeyWeights key lc)[t].toK`! -/
theorem claimTrue_toK_of_vec {lc : ℕ} (rows : List (List Fp)) (z : Block.ZClaim)
    (htrue : ClaimTrue shdP_U (2 ^ lc) lc rows (toZClaim z))
    (vec : Hiding.Row shdP_K (2 ^ lc) 256)
    (hvec : ∀ t : Fin (2 ^ lc), (combAt (claimWeights (toZClaim z) rows.length lc).1 rows t.val).toK shdP_U = vec (Sum.inl t)) :
    z.value.toK shdP_U =
      ∑ t : Fin (2 ^ lc), vec (Sum.inl t) *
        ((zkeyWeights (claimWeights (toZClaim z) rows.length lc).2 lc).getD t.val Fp2.zero).toK shdP_U := by
  unfold ClaimTrue MemTrue tabVal at htrue
  dsimp only [toZClaim] at htrue
  rw [htrue]
  have hcw : ∀ t : Fin (2 ^ lc),
      vec (Sum.inl t) * ((zkeyWeights (claimWeights (toZClaim z) rows.length lc).2 lc).getD t.val Fp2.zero).toK shdP_U =
      ∑ i ∈ Finset.range rows.length,
        (((claimWeights (toZClaim z) rows.length lc).1).getD i Fp2.zero).toK shdP_U *
          (algebraMap GF shdP_K ((rows.getD i []).getD t.val Fp.zero).toGF *
            ((zkeyWeights (claimWeights (toZClaim z) rows.length lc).2 lc).getD t.val Fp2.zero).toK shdP_U) := by
    intro t
    rw [← hvec t, toK_combAt shdP_U _ rows (claimWeights_length _ _ _) t.val, Finset.sum_mul]
    refine Finset.sum_congr rfl fun i _ => by ring
  simp_rw [hcw]
  rw [Finset.sum_comm]
  refine Finset.sum_congr rfl fun i _ => ?_
  rw [← Finset.mul_sum, Finset.sum_range]
  rfl

/-- **Group vector recovery from individual claim vectors (`pGroups` / `groupRhosAux`)**:
for any group `grp` whose member `j` has row-weights `rw_j` with `combAt rw_j rows k = memVec j`,
`combAt (groupComb rows grp.2 lams).1 rows k` equals `∑ j, lams[j] * memVec j`! -/
theorem rhoAdd_combAt_toK (lam : Fp2) (rho rw : List Fp2) (rows : List (List Fp))
    (hrho : rho.length = rows.length) (hrw : rw.length = rows.length) (k : ℕ) :
    (combAt (rhoAdd lam rho rw) rows k).toK shdP_U =
      (combAt rho rows k).toK shdP_U + lam.toK shdP_U * (combAt rw rows k).toK shdP_U := by
  have hlen : (rhoAdd lam rho rw).length = rows.length := by
    unfold rhoAdd; rw [List.length_zipWith, hrho, hrw, min_self]
  rw [toK_combAt shdP_U _ rows hlen k, toK_combAt shdP_U _ rows hrho k,
    toK_combAt shdP_U _ rows hrw k, Finset.mul_sum, ← Finset.sum_add_distrib]
  refine Finset.sum_congr rfl fun i hi => ?_
  have hiLt : i < rows.length := Finset.mem_range.mp hi
  have hget : ((rhoAdd lam rho rw).getD i Fp2.zero).toK shdP_U =
      (rho.getD i Fp2.zero).toK shdP_U + lam.toK shdP_U * (rw.getD i Fp2.zero).toK shdP_U := by
    have hzip : ∀ (a b : List Fp2) (idx : ℕ), idx < a.length → idx < b.length →
        ((List.zipWith (fun r w => if w.isZero then r else r.add (lam.mul w)) a b).getD idx Fp2.zero).toK shdP_U =
        (a.getD idx Fp2.zero).toK shdP_U + lam.toK shdP_U * (b.getD idx Fp2.zero).toK shdP_U := by
      intro a; induction a with
      | nil => intro _ _ h; cases h
      | cons x xs ih =>
        intro b idx hx hb
        cases b with
        | nil => cases hb
        | cons y ys =>
          cases idx with
          | zero =>
            simp only [List.zipWith_cons_cons, List.getD_cons_zero]
            by_cases hz : y.isZero = true
            · rw [ite_eq_left hz, (fp2_isZero_iff y).mp hz, Fp2.toK_zero, mul_zero, add_zero]
            · rw [ite_eq_right hz, fp2_toK_add_of_canon_right _ _ (Fp2.canon_mul _ _), Fp2.toK_mul shdP_U shdP_hU]
          | succ idx' =>
            simp only [List.zipWith_cons_cons, List.getD_cons_succ]
            exact ih ys idx' (Nat.lt_of_succ_lt_succ hx) (Nat.lt_of_succ_lt_succ hb)
    exact hzip rho rw i (by omega) (by omega)
  rw [hget]; ring

theorem groupComb_combAt_toK (rows : List (List Fp)) (k : ℕ) :
    ∀ (mems : List (List Fp2 × Fp2)) (lams : List Fp2),
      (∀ m ∈ mems, m.1.length = rows.length) →
      lams.length = mems.length →
      (combAt (groupComb rows.length mems lams).1 rows k).toK shdP_U =
        ((mems.zip lams).map (fun p => p.2.toK shdP_U * (combAt p.1.1 rows k).toK shdP_U)).sum := by
  intro mems lams hmems hlams
  have aux : ∀ (ps : List ((List Fp2 × Fp2) × Fp2)) (acc : List Fp2) (val : Fp2),
      acc.length = rows.length →
      (∀ p ∈ ps, p.1.1.length = rows.length) →
      (combAt (ps.foldl (fun a p => (rhoAdd p.2 a.1 p.1.1, a.2.add (p.2.mul p.1.2))) (acc, val)).1 rows k).toK shdP_U =
        (combAt acc rows k).toK shdP_U + (ps.map (fun p => p.2.toK shdP_U * (combAt p.1.1 rows k).toK shdP_U)).sum := by
    intro ps; induction ps with
    | nil => intro _ _ _ _; simp
    | cons p ps ih =>
      intro acc val hacc hps
      simp only [List.foldl_cons, List.map_cons, List.sum_cons]
      have hlen1 : (rhoAdd p.2 acc p.1.1).length = rows.length := by
        unfold rhoAdd; rw [List.length_zipWith, hacc, hps p List.mem_cons_self, min_self]
      rw [ih _ _ hlen1 (fun q hq => hps q (List.mem_cons_of_mem _ hq)),
        rhoAdd_combAt_toK p.2 acc p.1.1 rows hacc (hps p List.mem_cons_self) k]
      ring
  unfold groupComb
  rw [aux _ _ _ (List.length_replicate) (fun p hp => hmems p.1 (List.of_mem_zip hp).1)]
  have h0 : (combAt (List.replicate rows.length Fp2.zero) rows k).toK shdP_U = 0 := by
    rw [toK_combAt shdP_U _ rows (List.length_replicate) k]
    exact Finset.sum_eq_zero fun i _ => by rw [replicate_zero_getD_toK, zero_mul]
  rw [h0, zero_add]

/-- Zero-sum helper equivalence: `shdP_incHUVal` / `blkHUVal` / `shdP_outcHUVal` equals `shdP_zsGen`. -/
theorem huVal_eq_zsGen {n : ℕ} (hn : 0 < n) (raw : Fin n → GF × GF) (col : Fin n) :
    (if col.val = 0 then
        (- ∑ j : Fin (n - 1), (raw ⟨j.val + 1, by omega⟩).1,
         - ∑ j : Fin (n - 1), (raw ⟨j.val + 1, by omega⟩).2)
      else raw col)
    = (shdP_zsGen (fun j => (raw j).1) col, shdP_zsGen (fun j => (raw j).2) col) := by
  by_cases h0 : col.val = 0
  · rw [ite_eq_left h0]
    unfold shdP_zsGen
    rw [ite_eq_left h0, ite_eq_left h0]
    have hsum : ∀ (f : Fin n → GF),
        (∑ j : Fin (n - 1), f ⟨j.val + 1, by omega⟩) = ∑ j : Fin n, if j.val = 0 then (0 : GF) else f j := by
      intro f
      obtain ⟨m, rfl⟩ : ∃ m, n = m + 1 := ⟨n - 1, by omega⟩
      rw [Fin.sum_univ_succ]
      simp only [Fin.val_zero, ↓reduceIte, zero_add, Fin.val_succ, Nat.add_eq_zero_iff, one_ne_zero, and_false]
      rfl
    exact Prod.ext (congrArg Neg.neg (hsum (fun j => (raw j).1)))
      (congrArg Neg.neg (hsum (fun j => (raw j).2)))
  · rw [ite_eq_right h0]
    unfold shdP_zsGen
    rw [ite_eq_right h0, ite_eq_right h0]

end PcsOpeningRecon

/-! ## 4. Level-2 Slot & `M`-Opening Bridges (`slotProof_of_slotView`, `segMOpen_of_mOpenView`) -/

section Level2Bridges

private theorem cfsEval_indDeg {k d : ℕ} (hd1 : 1 ≤ d) (cf : Hiding.CfsCoeffs shdP_K k d) :
    IndDegLE d (Hiding.cfsEval cf) := by
  have h := Link.maskPoly_indDeg (K := shdP_K) (fun _ idx => cfsCoefAt hd1 cf idx) 0 (k + 1) d hd1
  have heq : Link.maskPoly (fun _ idx => cfsCoefAt hd1 cf idx) 0 (k + 1) d = Hiding.cfsEval cf := by
    funext x; unfold Link.maskPoly Hiding.cfsEval cfsCoefAt
    simp only [↓reduceIte, show (1 : ℕ) ≠ 0 by omega]
    congr 1
    refine Finset.sum_congr rfl fun i _ => Finset.sum_congr rfl fun e _ => ?_
    have hlt : 2 + i.val * d + e.val - 2 < (k + 1) * d := by
      have := i.isLt; have := e.isLt
      calc 2 + i.val * d + e.val - 2 = i.val * d + e.val := by omega
        _ < i.val * d + d := Nat.add_lt_add_left e.isLt _
        _ = (i.val + 1) * d := by ring
        _ ≤ (k + 1) * d := Nat.mul_le_mul_right d (by omega)
    simp only [show 2 + i.val * d + e.val ≠ 0 by omega, show 2 + i.val * d + e.val ≠ 1 by omega,
      ↓reduceIte, dite_eq_left hlt]
    have hdiv : (2 + i.val * d + e.val - 2) / d = i.val := by
      rw [show 2 + i.val * d + e.val - 2 = e.val + i.val * d by omega,
        Nat.add_mul_div_right _ _ (by omega), Nat.div_eq_of_lt e.isLt, Nat.zero_add]
    have hmod : (2 + i.val * d + e.val - 2) % d = e.val := by
      rw [show 2 + i.val * d + e.val - 2 = e.val + i.val * d by omega,
        Nat.add_mul_mod_self_right, Nat.mod_eq_of_lt e.isLt]
    refine congrArg₂ (· * ·) ?_ rfl
    exact congrArg₂ cf.2.2 (Fin.ext hdiv) (Fin.ext hmod)
  rwa [heq] at h

/-- **Mask-round equivalence**: for any `a : CfsCoeffs shdP_K n d` (`1 ≤ d < ringChar shdP_K`),
`honestCo d n (cfsEval a) r j` equals `cfsMaskRound a r j` (both have degree `≤ d` and evaluate
identically to `cubeSum (fun x => cfsEval a (r₀, ..., r_{j-1}, t, x))`)! -/
theorem peval_honestCo_cfsEval {n d : ℕ} (hd1 : 1 ≤ d) (hdc : d < ringChar shdP_K)
    (a : Hiding.CfsCoeffs shdP_K n d) :
    ∀ (r : Fin (n + 1) → shdP_K) (j : Fin (n + 1)) (t : shdP_K),
      Hiding.peval (honestCo d n (Hiding.cfsEval a) r j) t = Hiding.peval (Hiding.cfsMaskRound a r j) t := by
  induction n with
  | zero =>
    intro r j t
    have hj : j = 0 := Fin.ext (Nat.lt_one_iff.mp j.isLt)
    subst hj
    have hdeg : IndDegLE d (Hiding.cfsEval a) := cfsEval_indDeg hd1 a
    rw [honestCo, peval_roundCo hdc hdeg t, cubeSum_zero, Hiding.peval_cfsMaskRound hd1]
    unfold Hiding.cfsEval Hiding.cfsScale Hiding.cfsBase Hiding.cfsPrefix Hiding.cfsU
    have hgt : Finset.univ.filter (fun i : Fin 1 => (0 : Fin 1) < i) = ∅ := by
      ext i; simp
    simp only [Fin.val_zero, Nat.sub_self, pow_zero, one_mul, Hiding.filter_lt_zero, Finset.prod_empty,
      Finset.sum_empty, hgt, mul_zero, add_zero, Fin.sum_univ_succ, Fin.sum_univ_zero,
      Fin.prod_univ_succ, Fin.prod_univ_zero, Fin.cons_zero]
    ring
  | succ m ih =>
    intro r j t
    refine Fin.cases ?_ (fun k => ?_) j
    · -- `j = 0`
      rw [honestCo, Fin.cons_zero, peval_roundCo hdc (cfsEval_indDeg hd1 a) t, Hiding.peval_cfsMaskRound hd1]
      -- Compute `cubeSum (fun x => cfsEval a (Fin.cons t x))` explicitly!
      have hfix : ∀ x : Fin (m + 1) → shdP_K,
          Hiding.cfsEval a (Fin.cons t x) =
            (a.1 + Hiding.cfsU (a.2.2 0) t) + (a.2.1 * t) * (∏ i, x i)
            + ∑ i : Fin (m + 1), ∑ e : Fin d, a.2.2 i.succ e * x i ^ (e.val + 1) := by
        intro x
        unfold Hiding.cfsEval Hiding.cfsU
        rw [Fin.prod_univ_succ, Fin.sum_univ_succ, Fin.cons_zero]
        simp only [Fin.cons_succ]; ring
      let a' : Hiding.CfsCoeffs shdP_K m d :=
        (a.1 + Hiding.cfsU (a.2.2 0) t, a.2.1 * t, fun i => a.2.2 i.succ)
      have hcf : (fun x : Fin (m + 1) → shdP_K => Hiding.cfsEval a (Fin.cons t x)) = Hiding.cfsEval a' :=
        funext hfix
      rw [hcf, cubeSum_cfsEval]
      unfold Hiding.cfsTotal a' Hiding.cfsScale Hiding.cfsBase Hiding.cfsPrefix
      simp only [Fin.val_zero, Nat.sub_zero, Hiding.filter_lt_zero, Finset.prod_empty, Finset.sum_empty,
        add_zero, mul_one]
      have hgt : ∑ i ∈ Finset.univ.filter (fun i : Fin (m + 2) => (0 : Fin (m + 2)) < i),
          Hiding.cfsU (a.2.2 i) 1 = ∑ i : Fin (m + 1), ∑ e : Fin d, a.2.2 i.succ e := by
        rw [Finset.sum_filter, Fin.sum_univ_succ]
        simp only [lt_irrefl, ↓reduceIte, zero_add, Fin.succ_pos]
        refine Finset.sum_congr rfl fun i _ => ?_
        unfold Hiding.cfsU; simp
      have h2ne : (2 : shdP_K) ≠ 0 := by
        rw [← map_ofNat (algebraMap GF shdP_K) 2]
        exact (_root_.map_ne_zero _).mpr (by decide)
      have h2inv : (2 : shdP_K) * (2 : shdP_K)⁻¹ = 1 := mul_inv_cancel₀ h2ne
      rw [hgt, pow_succ (2 : shdP_K) m]
      calc (2 : shdP_K) ^ m * 2 * (a.1 + Hiding.cfsU (a.2.2 0) t) + a.2.1 * t
            + 2 ^ m * ∑ i : Fin (m + 1), ∑ e : Fin d, a.2.2 i.succ e
          = (2 : shdP_K) ^ m * 2 * (a.1 + Hiding.cfsU (a.2.2 0) t) + a.2.1 * t
            + 2 ^ m * ((2 * 2⁻¹) * ∑ i : Fin (m + 1), ∑ e : Fin d, a.2.2 i.succ e) := by rw [h2inv, one_mul]
        _ = (2 : shdP_K) ^ m * 2 * (a.1 + 2⁻¹ * ∑ i : Fin (m + 1), ∑ e : Fin d, a.2.2 i.succ e
              + Hiding.cfsU (a.2.2 0) t) + a.2.1 * t := by ring
    · -- `j = k.succ`: restrict `a` by fixing variable `0` to `r 0`!
      rw [honestCo, Fin.cons_succ]
      let a' : Hiding.CfsCoeffs shdP_K m d :=
        (a.1 + Hiding.cfsU (a.2.2 0) (r 0), a.2.1 * r 0, fun i => a.2.2 i.succ)
      have hcf : (fun x : Fin (m + 1) → shdP_K => Hiding.cfsEval a (Fin.cons (r 0) x)) = Hiding.cfsEval a' := by
        funext x; unfold Hiding.cfsEval a' Hiding.cfsU
        rw [Fin.prod_univ_succ, Fin.sum_univ_succ, Fin.cons_zero]
        simp only [Fin.cons_succ]; ring
      rw [hcf, ih a' (Fin.tail r) k t, Hiding.peval_cfsMaskRound hd1, Hiding.peval_cfsMaskRound hd1]
      -- Match `cfsScale`, `cfsBase`, `cfsPrefix`, `a'.2.1`!
      have hsc : Hiding.cfsScale (K := shdP_K) m k = Hiding.cfsScale (K := shdP_K) (m + 1) k.succ := by
        unfold Hiding.cfsScale; simp [Fin.val_succ]
      have hpr : a'.2.1 * Hiding.cfsPrefix (Fin.tail r) k = a.2.1 * Hiding.cfsPrefix r k.succ := by
        unfold a' Hiding.cfsPrefix
        rw [mul_assoc]; congr 1
        simp only [Finset.prod_filter, Fin.prod_univ_succ, Fin.succ_pos, ↓reduceIte, Fin.succ_lt_succ_iff]
        rfl
      have hbs : Hiding.cfsBase a' (Fin.tail r) k = Hiding.cfsBase a r k.succ := by
        unfold a' Hiding.cfsBase
        have hlt : ∑ i ∈ Finset.univ.filter (fun i : Fin (m + 2) => i < k.succ), Hiding.cfsU (a.2.2 i) (r i) =
            Hiding.cfsU (a.2.2 0) (r 0) +
            ∑ i ∈ Finset.univ.filter (fun i : Fin (m + 1) => i < k), Hiding.cfsU (a.2.2 i.succ) (Fin.tail r i) := by
          simp only [Finset.sum_filter, Fin.sum_univ_succ, Fin.succ_pos, ↓reduceIte, Fin.succ_lt_succ_iff]; rfl
        have hgt : ∑ i ∈ Finset.univ.filter (fun i : Fin (m + 2) => k.succ < i), Hiding.cfsU (a.2.2 i) 1 =
            ∑ i ∈ Finset.univ.filter (fun i : Fin (m + 1) => k < i), Hiding.cfsU (a.2.2 i.succ) 1 := by
          simp only [Finset.sum_filter, Fin.sum_univ_succ, Fin.not_lt_zero, ↓reduceIte, zero_add,
            Fin.succ_lt_succ_iff]
        rw [hlt, hgt]; ring
      rw [hsc, hpr, hbs]

/-- **Exact sumcheck round-word recovery from `slotView`**:
running `scProveFixedProg` on `honestW shdP_U shdP_hbij d (n + 1) (f + c * cfsEval a)` produces
EXACTLY the `n + 1` round lists evaluating `(slotView masked (honestCo d n f ρ) c ρ a).2.1` at
`0, 1, ..., d` via `ofK`! -/
theorem scProve_honestW_eq_of_slotView {n d : ℕ} (hd1 : 1 ≤ d) (hdc : d < ringChar shdP_K)
    (masked : Bool) (f : (Fin (n + 1) → shdP_K) → shdP_K) (hf : IndDegLE d f)
    (c : shdP_K) (a : Hiding.CfsCoeffs shdP_K n d)
    (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (H : QB Lq → Dig) (v : ℕ → Dig) (t : Tr) (base : ℕ) :
    let ρ : Fin (n + 1) → shdP_K := fun j => (challengeFp2Of (v (base + 2 * j.val + 1))).toK shdP_U
    let sv := slotView masked (honestCo d n f ρ) c ρ a
    ((scProveFixedProg Lq hL20 key (n + 1) true
      (honestW shdP_U shdP_hbij d (n + 1) (fun x => f x + c * Hiding.cfsEval a x)) t).res H v base).1
    = List.ofFn fun j : Fin (n + 1) =>
        List.ofFn fun u : Fin (d + 1) => ofK shdP_U shdP_hbij (Hiding.peval (sv.2.1 j) (u.val : shdP_K)) := by
  -- Prove by induction on `n` that `scProveFixedProg.res.1` evaluates `honestCo d n g ρ` at `0..d`!
  have hgen : ∀ (m : ℕ) (g : (Fin (m + 1) → shdP_K) → shdP_K) (hg : IndDegLE d g)
      (t0 : Tr) (b0 : ℕ),
      let ρ0 : Fin (m + 1) → shdP_K := fun j => (challengeFp2Of (v (b0 + 2 * j.val + 1))).toK shdP_U
      ((scProveFixedProg Lq hL20 key (m + 1) true (honestW shdP_U shdP_hbij d (m + 1) g) t0).res H v b0).1
      = List.ofFn fun j : Fin (m + 1) =>
          List.ofFn fun u : Fin (d + 1) => ofK shdP_U shdP_hbij (Hiding.peval (honestCo d m g ρ0 j) (u.val : shdP_K)) := by
    intro m; induction m with
    | zero =>
      intro g hg t0 b0
      dsimp only
      unfold scProveFixedProg honestW
      rw [PProg.res_andThen H v _ _ 1 b0 (trAbsorbFp2Keyed_ptLen Lq hL20 key t0 scLabel (by decide) _),
        trAbsorbFp2Keyed_res,
        PProg.res_andThen H v _ _ 1 (b0 + 1) (trChallengeFp2Keyed_ptLen Lq (by omega) key _),
        trChallengeFp2Keyed_res,
        PProg.res_andThen H v _ _ 0 (b0 + 1 + 1) (scProveFixedProg_ptLen Lq hL20 key 0 true _ _)]
      rw [List.ofFn_succ (f := fun j : Fin 1 => _), List.ofFn_zero]
      simp only [scProveFixedProg, PProg.res, ↓reduceIte, List.cons.injEq, and_true]
      unfold honestWords
      refine List.ext_getElem (by simp) fun u hu1 hu2 => ?_
      simp only [List.getElem_ofFn]
      congr 1
      dsimp only [honestCo]
      rw [peval_roundCo hdc hg]
      rfl
    | succ m' ihm =>
      intro g hg t0 b0
      dsimp only
      unfold scProveFixedProg honestW
      rw [PProg.res_andThen H v _ _ 1 b0 (trAbsorbFp2Keyed_ptLen Lq hL20 key t0 scLabel (by decide) _),
        trAbsorbFp2Keyed_res,
        PProg.res_andThen H v _ _ 1 (b0 + 1) (trChallengeFp2Keyed_ptLen Lq (by omega) key _),
        trChallengeFp2Keyed_res,
        PProg.res_andThen H v _ _ (2 * (m' + 1)) (b0 + 1 + 1) (scProveFixedProg_ptLen Lq hL20 key (m' + 1) true _ _)]
      rw [List.ofFn_succ (f := fun j : Fin (m' + 2) => _)]
      simp only [PProg.res, ↓reduceIte, List.cons.injEq]
      refine ⟨?_, ?_⟩
      · unfold honestWords
        refine List.ext_getElem (by simp) fun u hu1 hu2 => ?_
        simp only [List.getElem_ofFn]
        apply congrArg (ofK shdP_U shdP_hbij)
        dsimp only [honestCo]
        rw [Fin.cons_zero, peval_roundCo hdc hg]; rfl
      · set r0 := challengeFp2Of (v (b0 + 1))
        have ih := ihm (fun x => g (Fin.cons (r0.toK shdP_U) x)) (hg.cons (r0.toK shdP_U))
          { state := v (b0 + 1), counter := t0.counter + 1, key := key } (b0 + 1 + 1)
        dsimp only at ih
        rw [ih]
        refine List.ext_getElem (by simp) fun j hj1 hj2 => ?_
        simp only [List.getElem_ofFn]
        refine List.ext_getElem (by simp) fun u hu1 hu2 => ?_
        simp only [List.getElem_ofFn]
        apply congrArg (ofK shdP_U shdP_hbij)
        refine congrArg (fun p => Hiding.peval p _) ?_
        have htail : (fun k : Fin (m' + 1) => (challengeFp2Of (v (b0 + 1 + 1 + 2 * k.val + 1))).toK shdP_U)
            = Fin.tail (fun k : Fin (m' + 2) => (challengeFp2Of (v (b0 + 2 * k.val + 1))).toK shdP_U) := by
          funext k; simp only [Fin.tail, Fin.val_succ]
          congr 2; congr 1; omega
        have hr0 : r0 = challengeFp2Of (v (b0 + 2 * (0 : Fin (m' + 2)).val + 1)) := by
          simp [r0]
        dsimp only [honestCo]
        rw [Fin.cons_succ, ← hr0, ← htail]
  have hdegA : IndDegLE d (Hiding.cfsEval a) := cfsEval_indDeg hd1 a
  have hdegSum : IndDegLE d (fun x => f x + c * Hiding.cfsEval a x) :=
    ZK60.StageX.IndDegLE.add hf (ZK60.StageX.IndDegLE.cmul c hdegA)
  dsimp only
  rw [hgen n (fun x => f x + c * Hiding.cfsEval a x) hdegSum t base]
  refine List.ext_getElem (by simp) fun j hj1 hj2 => ?_
  simp only [List.getElem_ofFn]
  refine List.ext_getElem (by simp) fun u hu1 hu2 => ?_
  simp only [List.getElem_ofFn]
  apply congrArg (ofK shdP_U shdP_hbij)
  -- Show `peval (honestCo d n (f + c * cfsEval a) ρ j) u = peval ((slotView ...).2.1 j) u`!
  have hlin : ∀ (m : ℕ) (g₁ g₂ : (Fin (m + 1) → shdP_K) → shdP_K) (h1 : IndDegLE d g₁) (h2 : IndDegLE d g₂)
      (r : Fin (m + 1) → shdP_K) (k : Fin (m + 1)) (z : shdP_K),
      Hiding.peval (honestCo d m (fun x => g₁ x + c * g₂ x) r k) z
        = Hiding.peval (honestCo d m g₁ r k) z + c * Hiding.peval (honestCo d m g₂ r k) z := by
    intro m; induction m with
    | zero =>
      intro g₁ g₂ h1 h2 r k z
      have hk : k = 0 := Fin.ext (Nat.lt_one_iff.mp k.isLt); subst hk
      rw [honestCo, honestCo, honestCo,
        peval_roundCo hdc (ZK60.StageX.IndDegLE.add h1 (ZK60.StageX.IndDegLE.cmul c h2)),
        peval_roundCo hdc h1, peval_roundCo hdc h2, cubeSum_zero, cubeSum_zero, cubeSum_zero]
    | succ m' ihm =>
      intro g₁ g₂ h1 h2 r k z
      refine Fin.cases ?_ (fun k' => ?_) k
      · rw [honestCo, honestCo, honestCo, Fin.cons_zero, Fin.cons_zero, Fin.cons_zero,
          peval_roundCo hdc (ZK60.StageX.IndDegLE.add h1 (ZK60.StageX.IndDegLE.cmul c h2)),
          peval_roundCo hdc h1, peval_roundCo hdc h2]
        exact cubeSum_add_smul _ _ c
      · rw [honestCo, honestCo, honestCo, Fin.cons_succ, Fin.cons_succ, Fin.cons_succ]
        exact ihm _ _ (h1.cons _) (h2.cons _) (Fin.tail r) k' z
  rw [hlin n f (Hiding.cfsEval a) hf hdegA _ ⟨j, by simpa using hj1⟩ (u : shdP_K),
    peval_honestCo_cfsEval hd1 hdc a _ ⟨j, by simpa using hj1⟩ (u : shdP_K)]
  have hsv21 : (slotView masked (honestCo d n f (fun j => (challengeFp2Of (v (base + 2 * j.val + 1))).toK shdP_U))
      c (fun j => (challengeFp2Of (v (base + 2 * j.val + 1))).toK shdP_U) a).2.1 ⟨j, by simpa using hj1⟩ =
      fun e => honestCo d n f (fun j => (challengeFp2Of (v (base + 2 * j.val + 1))).toK shdP_U) ⟨j, by simpa using hj1⟩ e
        + c * Hiding.cfsMaskRound a (fun j => (challengeFp2Of (v (base + 2 * j.val + 1))).toK shdP_U) ⟨j, by simpa using hj1⟩ e := by
    cases masked <;> rfl
  rw [hsv21]
  unfold Hiding.peval
  rw [Finset.mul_sum, ← Finset.sum_add_distrib]
  refine Finset.sum_congr rfl fun e _ => by ring

/-- Exact mask-coefficient message layout `w a : Fin (shdSegNS s) → Bool → Fin 512 → GF` matching `packSegMA`. -/
noncomputable def segMaskW (s : Fin 28)
    (a : (t : Fin (shdSegNS s)) → Hiding.CfsCoeffs shdP_K ((shdP_L2Spec s).n t) ((shdP_L2Spec s).d t))
    (t : Fin (shdSegNS s)) (k : Bool) (j : Fin 512) : GF :=
  if j.val < shdP_slotMaskLen s t then
    let fp := ofK shdP_U shdP_hbij (cfsCoefAt (shdP_L2_slot_bounds s t).1 (a t) j.val)
    if k then fp.c0.toGF else fp.c1.toGF
  else 0

/-- `packSegMA` row coordinates match `segMaskW + placePads (mPadPos ...) pads` pointwise on `Fin 512`! -/
theorem packSegMA_eq_w_add_pads (s : Fin 28) (c2 : SegL2Coins GF shdP_K (shdP_L2Spec s))
    (t : Fin (shdSegNS s)) (k : Bool) (j : Fin 512) :
    (if k then (packSegMA s c2 t j).c0.toGF else (packSegMA s c2 t j).c1.toGF) =
      segMaskW s c2.1.1 t k j +
        Hiding.placePads (Hiding.mPadPos (shdP_L2_slot_bounds s t).2.2.2) (c2.1.2.1 t k) j := by
  unfold packSegMA segMaskW Hiding.placePads Hiding.mPadPos
  dsimp only
  set L := shdP_slotMaskLen s t
  by_cases h1 : j.val < L
  · rw [dite_eq_left h1, ite_eq_left h1]
    have hsum0 : (∑ l : Fin 256, if (⟨L + l.val, by have := (shdP_L2_slot_bounds s t).2.2.2; have := l.isLt; omega⟩ : Fin 512) = j
        then c2.1.2.1 t k l else 0) = 0 :=
      Finset.sum_eq_zero fun l _ => ite_eq_right (fun h => by have := congrArg Fin.val h; dsimp only at this; omega)
    rw [hsum0, add_zero]
  · rw [dite_eq_right h1, ite_eq_right h1, zero_add]
    by_cases h2 : j.val < L + 256
    · rw [dite_eq_left h2]
      let l0 : Fin 256 := ⟨j.val - L, by omega⟩
      rw [Finset.sum_eq_single l0]
      · have heq : (⟨L + l0.val, by have := (shdP_L2_slot_bounds s t).2.2.2; omega⟩ : Fin 512) = j :=
          Fin.ext (by dsimp only [l0]; omega)
        rw [ite_eq_left heq]
        dsimp only [l0, L]
        cases k <;> (simp only [Fp.toGF_ofGF]; rfl)
      · intro l _ hne
        exact ite_eq_right fun h => hne (Fin.ext (by have := congrArg Fin.val h; dsimp only [l0] at this ⊢; omega))
      · intro h; exact absurd (Finset.mem_univ l0) h
    · rw [dite_eq_right h2]
      have hsum0 : (∑ l : Fin 256, if (⟨L + l.val, by have := (shdP_L2_slot_bounds s t).2.2.2; have := l.isLt; omega⟩ : Fin 512) = j
          then c2.1.2.1 t k l else 0) = 0 :=
        Finset.sum_eq_zero fun l _ => ite_eq_right (fun h => by
          have := congrArg Fin.val h; dsimp only at this; have := l.isLt; omega)
      rw [hsum0]
      cases k <;> rfl

private theorem coefPoly_eq_cpoly {k : ℕ} (v : Fin k → GF) : coefPoly v = Hiding.cpoly v := by
  rw [coefPoly_apply]; unfold Hiding.cpoly
  exact Finset.sum_congr rfl fun i _ => by rw [Polynomial.C_mul_X_pow_eq_monomial]

/-- `mkMTable` rows match `Hiding.mA`, `Hiding.mB`, and `Hiding.mU` verbatim for any segment `s : Fin 28`! -/
theorem mkMTable_row_eq_mOpen (s : Fin 28) (c2 : SegL2Coins GF shdP_K (shdP_L2Spec s))
    {qOpen : ℕ} (P : Hiding.MOpenPub GF 512 (shdSegNS s) 256 qOpen)
    (hy : P.y = fun i : Fin 512 => (rootFp 9).toGF ^ i.val)
    (hπ : ∀ t, P.π t = Hiding.mPadPos (shdP_L2_slot_bounds s t).2.2.2) :
    let M := mkMTable (shdSegNS s) (packSegMA s c2) (c2.1.2.2.1 true) (c2.1.2.2.1 false)
      (c2.1.2.2.2 true) (c2.1.2.2.2 false) (extSalt c2.2)
    (∀ (t : Fin (shdSegNS s)) (k : Bool),
      M.row (2 * t.val + if k then 0 else 1) = Hiding.mA P (segMaskW s c2.1.1) c2.1.2.1 t k)
    ∧ (∀ k : Bool, M.row (2 * shdSegNS s + if k then 0 else 1) = Hiding.mB (m := 512) (by norm_num) c2.1.2.2.1 k)
    ∧ (∀ k : Bool, M.row (2 * shdSegNS s + 2 + if k then 0 else 1) = Hiding.mU (m := 512) c2.1.2.2.2 k) := by
  intro M
  refine ⟨?_, ?_, ?_⟩
  · intro t k
    have hlt : 2 * t.val + (if k then 0 else 1) < 2 * shdSegNS s := by
      cases k <;> (have := t.isLt; simp only [↓reduceIte, Bool.false_eq_true]; omega)
    dsimp only [M, mkMTable]
    rw [dite_eq_left hlt]
    cases k with
    | true =>
      simp only [↓reduceIte, Nat.add_zero, Nat.mul_mod_right]
      have htEq : (⟨(2 * t.val) / 2, by have := t.isLt; omega⟩ : Fin (shdSegNS s)) = t := Fin.ext (by dsimp only; omega)
      rw [htEq]
      unfold mInterp Hiding.mA
      rw [hy, hπ t]
      apply congrArg (Lagrange.interpolate Finset.univ _)
      funext j
      simpa using packSegMA_eq_w_add_pads s c2 t true j
    | false =>
      have hmod : (2 * t.val + 1) % 2 ≠ 0 := by omega
      simp only [Bool.false_eq_true, ↓reduceIte, ite_eq_right hmod]
      have htEq : (⟨(2 * t.val + 1) / 2, by have := t.isLt; omega⟩ : Fin (shdSegNS s)) = t := Fin.ext (by dsimp only; omega)
      rw [htEq]
      unfold mInterp Hiding.mA
      rw [hy, hπ t]
      apply congrArg (Lagrange.interpolate Finset.univ _)
      funext j
      simpa using packSegMA_eq_w_add_pads s c2 t false j
  · intro k
    dsimp only [M, mkMTable]
    cases k with
    | true =>
      simp only [↓reduceIte, Nat.add_zero, dite_eq_right (by omega : ¬ (2 * shdSegNS s < 2 * shdSegNS s))]
      exact coefPoly_eq_cpoly _
    | false =>
      simp only [Bool.false_eq_true, ↓reduceIte,
        dite_eq_right (by omega : ¬ (2 * shdSegNS s + 1 < 2 * shdSegNS s)),
        ite_eq_right (by omega : 2 * shdSegNS s + 1 ≠ 2 * shdSegNS s)]
      exact coefPoly_eq_cpoly _
  · intro k
    dsimp only [M, mkMTable]
    cases k with
    | true =>
      simp only [↓reduceIte, Nat.add_zero,
        dite_eq_right (by omega : ¬ (2 * shdSegNS s + 2 < 2 * shdSegNS s)),
        ite_eq_right (by omega : 2 * shdSegNS s + 2 ≠ 2 * shdSegNS s),
        ite_eq_right (by omega : 2 * shdSegNS s + 2 ≠ 2 * shdSegNS s + 1)]
      exact coefPoly_eq_cpoly _
    | false =>
      simp only [Bool.false_eq_true, ↓reduceIte,
        dite_eq_right (by omega : ¬ (2 * shdSegNS s + 2 + 1 < 2 * shdSegNS s)),
        ite_eq_right (by omega : 2 * shdSegNS s + 2 + 1 ≠ 2 * shdSegNS s),
        ite_eq_right (by omega : 2 * shdSegNS s + 2 + 1 ≠ 2 * shdSegNS s + 1),
        ite_eq_right (by omega : 2 * shdSegNS s + 2 + 1 ≠ 2 * shdSegNS s + 2)]
      exact coefPoly_eq_cpoly _

/-- **`qPoly` and `pPoly` polynomial coefficients equal `Hiding.mOpenView`'s `q` and `prox`**
under `shdP_U` (`U^2 = 7`), so `zkBMaskFixedProg`'s output `(q, prox, columns)` is a pure function
of `(Hiding.mOpenView 7 P _ (segMaskW s c2.1.1) c2.1.2, c2.2)` + `v`! -/
theorem qPoly_pPoly_eq_mOpenView (s : Fin 28) (c2 : SegL2Coins GF shdP_K (shdP_L2Spec s))
    {qOpen : ℕ} (P : Hiding.MOpenPub GF 512 (shdSegNS s) 256 qOpen)
    (hy : P.y = fun i : Fin 512 => (rootFp 9).toGF ^ i.val)
    (hπ : ∀ t, P.π t = Hiding.mPadPos (shdP_L2_slot_bounds s t).2.2.2)
    (fs : List Exec.Block.MaskFunctional) (θ : Fp2) (rs : List Fp2)
    (hW : ∀ (t : Fin (shdSegNS s)) (j : Fin 512),
      Hiding.fp2 shdP_U (P.Wre t j, P.Wim t j) = mW 1 (wtOf shdP_U (fs.map toMF) (shdSegNS s)) (θ.toK shdP_U) t j)
    (hρa : ∀ (t : Fin (shdSegNS s)) (k : Bool),
      Hiding.fp2 shdP_U (P.ρa t k) = (rs.getD (2 * t.val + if k then 0 else 1) Fp2.zero).toK shdP_U)
    (hρb : ∀ k : Bool,
      Hiding.fp2 shdP_U (P.ρb k) = (rs.getD (2 * shdSegNS s + if k then 0 else 1) Fp2.zero).toK shdP_U) :
    let M := mkMTable (shdSegNS s) (packSegMA s c2) (c2.1.2.2.1 true) (c2.1.2.2.1 false)
      (c2.1.2.2.2 true) (c2.1.2.2.2 false) (extSalt c2.2)
    let mv := Hiding.mOpenView (7 : GF) P (by norm_num) (segMaskW s c2.1.1) c2.1.2
    (∀ i : Fin 1024,
      (qPoly shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) M (shdSegNS s) (fs.map toMF) (θ.toK shdP_U)).coeff i.val
        = Hiding.fp2 shdP_U (mv.1 i))
    ∧ (∀ i : Fin 1024,
        (pPoly shdP_U M (shdSegNS s) rs).coeff i.val = Hiding.fp2 shdP_U (mv.2.1 i)) := by
  intro M mv
  obtain ⟨hMA, hMB, hMU⟩ := mkMTable_row_eq_mOpen s c2 P hy hπ
  have hMB0 : M.row (2 * shdSegNS s) = Hiding.mB (m := 512) (by norm_num) c2.1.2.2.1 true := by
    simpa using hMB true
  have hMB1 : M.row (2 * shdSegNS s + 1) = Hiding.mB (m := 512) (by norm_num) c2.1.2.2.1 false := by
    simpa using hMB false
  have hMU0 : M.row (2 * shdSegNS s + 2) = Hiding.mU (m := 512) c2.1.2.2.2 true := by
    simpa using hMU true
  have hMU1 : M.row (2 * shdSegNS s + 3) = Hiding.mU (m := 512) c2.1.2.2.2 false := by
    simpa [show 2 * shdSegNS s + 2 + 1 = 2 * shdSegNS s + 3 by omega] using hMU false
  -- Show `qPoly = map (mQre) + C U * map (mQim)` and `pPoly = map (mPre) + C U * map (mPim)`!
  have hfp2_poly : ∀ (p q : GF[X]) (i : ℕ),
      (p.map (algebraMap GF shdP_K) + C shdP_U * q.map (algebraMap GF shdP_K)).coeff i
        = Hiding.fp2 shdP_U (p.coeff i, q.coeff i) := by
    intro p q i
    simp only [coeff_add, coeff_C_mul, coeff_map, Hiding.fp2]
  have hQpolyEq : qPoly shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) M (shdSegNS s) (fs.map toMF) (θ.toK shdP_U)
      = (Hiding.mQre (7 : GF) P (by norm_num) (segMaskW s c2.1.1) c2.1.2).map (algebraMap GF shdP_K)
        + C shdP_U * (Hiding.mQim P (by norm_num) (segMaskW s c2.1.1) c2.1.2).map (algebraMap GF shdP_K) := by
    unfold qPoly mProduct Hiding.mQre Hiding.mQim
    simp only [Polynomial.map_add, Polynomial.map_sum, Polynomial.map_mul, Polynomial.map_C]
    have hB : HonestOpen.mB shdP_U M (shdSegNS s) =
        (Hiding.mB (m := 512) (by norm_num) c2.1.2.2.1 true).map (algebraMap GF shdP_K)
        + C shdP_U * (Hiding.mB (m := 512) (by norm_num) c2.1.2.2.1 false).map (algebraMap GF shdP_K) := by
      unfold HonestOpen.mB pairK; rw [hMB0, hMB1]
    have hTerm : ∀ t : Fin (shdSegNS s),
        HonestOpen.mA shdP_U M (shdSegNS s) t * mInterp (algebraMap GF shdP_K (rootFp 9).toGF)
            (mW 1 (wtOf shdP_U (fs.map toMF) (shdSegNS s)) (θ.toK shdP_U) t)
        = ((Hiding.mA P (segMaskW s c2.1.1) c2.1.2.1 t true).map (algebraMap GF shdP_K) * (Hiding.mWre P t).map (algebraMap GF shdP_K)
            + C (algebraMap GF shdP_K (7 : GF)) * ((Hiding.mA P (segMaskW s c2.1.1) c2.1.2.1 t false).map (algebraMap GF shdP_K)
                * (Hiding.mWim P t).map (algebraMap GF shdP_K)))
          + C shdP_U * ((Hiding.mA P (segMaskW s c2.1.1) c2.1.2.1 t true).map (algebraMap GF shdP_K) * (Hiding.mWim P t).map (algebraMap GF shdP_K)
            + (Hiding.mA P (segMaskW s c2.1.1) c2.1.2.1 t false).map (algebraMap GF shdP_K) * (Hiding.mWre P t).map (algebraMap GF shdP_K)) := by
      intro t
      have hA : HonestOpen.mA shdP_U M (shdSegNS s) t =
          (Hiding.mA P (segMaskW s c2.1.1) c2.1.2.1 t true).map (algebraMap GF shdP_K)
          + C shdP_U * (Hiding.mA P (segMaskW s c2.1.1) c2.1.2.1 t false).map (algebraMap GF shdP_K) := by
        unfold HonestOpen.mA pairK
        have h1 : M.row (2 * t.val) = Hiding.mA P (segMaskW s c2.1.1) c2.1.2.1 t true := by simpa using hMA t true
        have h2 : M.row (2 * t.val + 1) = Hiding.mA P (segMaskW s c2.1.1) c2.1.2.1 t false := by simpa using hMA t false
        rw [h1, h2]
      have hWpoly : mInterp (algebraMap GF shdP_K (rootFp 9).toGF)
            (mW 1 (wtOf shdP_U (fs.map toMF) (shdSegNS s)) (θ.toK shdP_U) t)
          = (Hiding.mWre P t).map (algebraMap GF shdP_K)
            + C shdP_U * (Hiding.mWim P t).map (algebraMap GF shdP_K) := by
        have hωGF : IsPrimitiveRoot (rootFp 9).toGF 512 := rootFp_isPrimitiveRoot (k := 9) (by norm_num)
        have hωK : IsPrimitiveRoot (algebraMap GF shdP_K (rootFp 9).toGF) 512 :=
          hωGF.map_of_injective (algebraMap GF shdP_K).injective
        have hext := lagForm_ext (K := shdP_K) (by norm_num : 0 < 512) hωGF
        have h1 : (Hiding.mWre P t).map (algebraMap GF shdP_K) =
            mInterp (algebraMap GF shdP_K (rootFp 9).toGF) (fun j => algebraMap GF shdP_K (P.Wre t j)) := by
          unfold Hiding.mWre; rw [hy]; exact (hext (P.Wre t)).symm
        have h2 : (Hiding.mWim P t).map (algebraMap GF shdP_K) =
            mInterp (algebraMap GF shdP_K (rootFp 9).toGF) (fun j => algebraMap GF shdP_K (P.Wim t j)) := by
          unfold Hiding.mWim; rw [hy]; exact (hext (P.Wim t)).symm
        rw [h1, h2]
        have hfun : mW 1 (wtOf shdP_U (fs.map toMF) (shdSegNS s)) (θ.toK shdP_U) t =
            (fun j => algebraMap GF shdP_K (P.Wre t j)) + shdP_U • (fun j => algebraMap GF shdP_K (P.Wim t j)) := by
          funext j; rw [← hW t j]; rfl
        rw [hfun]
        have hlin := (lagForm (by norm_num : 0 < 512) hωK).poly.map_add
          (fun j => algebraMap GF shdP_K (P.Wre t j)) (shdP_U • fun j => algebraMap GF shdP_K (P.Wim t j))
        have hsmul := (lagForm (by norm_num : 0 < 512) hωK).poly.map_smul shdP_U (fun j => algebraMap GF shdP_K (P.Wim t j))
        rw [lagForm_poly, lagForm_poly, lagForm_poly] at hlin
        rw [lagForm_poly, lagForm_poly, Polynomial.smul_eq_C_mul] at hsmul
        exact hlin.trans (congrArg _ hsmul)
      rw [hA, hWpoly]
      have hU2 : C shdP_U * C shdP_U = C (algebraMap GF shdP_K (7 : GF)) := by
        rw [← C_mul, ← pow_two, shdP_hU]
      calc ((Hiding.mA P (segMaskW s c2.1.1) c2.1.2.1 t true).map (algebraMap GF shdP_K)
              + C shdP_U * (Hiding.mA P (segMaskW s c2.1.1) c2.1.2.1 t false).map (algebraMap GF shdP_K))
            * ((Hiding.mWre P t).map (algebraMap GF shdP_K)
              + C shdP_U * (Hiding.mWim P t).map (algebraMap GF shdP_K))
          = (Hiding.mA P (segMaskW s c2.1.1) c2.1.2.1 t true).map (algebraMap GF shdP_K) * (Hiding.mWre P t).map (algebraMap GF shdP_K)
            + (C shdP_U * C shdP_U) * ((Hiding.mA P (segMaskW s c2.1.1) c2.1.2.1 t false).map (algebraMap GF shdP_K) * (Hiding.mWim P t).map (algebraMap GF shdP_K))
            + C shdP_U * ((Hiding.mA P (segMaskW s c2.1.1) c2.1.2.1 t true).map (algebraMap GF shdP_K) * (Hiding.mWim P t).map (algebraMap GF shdP_K)
              + (Hiding.mA P (segMaskW s c2.1.1) c2.1.2.1 t false).map (algebraMap GF shdP_K) * (Hiding.mWre P t).map (algebraMap GF shdP_K)) := by ring
        _ = _ := by rw [hU2]
    rw [hB]
    simp_rw [hTerm]
    rw [Finset.sum_add_distrib, ← Finset.mul_sum, mul_add]
    abel
  have hPpolyEq : pPoly shdP_U M (shdSegNS s) rs
      = (Hiding.mPre P (by norm_num) (segMaskW s c2.1.1) c2.1.2).map (algebraMap GF shdP_K)
        + C shdP_U * (Hiding.mPim P (by norm_num) (segMaskW s c2.1.1) c2.1.2).map (algebraMap GF shdP_K) := by
    unfold pPoly Hiding.mPre Hiding.mPim
    simp only [Polynomial.map_add, Polynomial.map_sum, Polynomial.map_mul, Polynomial.map_C]
    have hU : mUp shdP_U M (shdSegNS s) =
        (Hiding.mU (m := 512) c2.1.2.2.2 true).map (algebraMap GF shdP_K)
        + C shdP_U * (Hiding.mU (m := 512) c2.1.2.2.2 false).map (algebraMap GF shdP_K) := by
      unfold mUp pairK; rw [hMU0, hMU1]
    rw [hU, Fin.sum_univ_castSucc, Fin.sum_univ_castSucc]
    simp only [Fin.val_castSucc, Fin.val_last]
    have hB0 : (M.row (2 * shdSegNS s)).map (algebraMap GF shdP_K) = (Hiding.mB (m := 512) (by norm_num) c2.1.2.2.1 true).map (algebraMap GF shdP_K) :=
      congrArg (Polynomial.map (algebraMap GF shdP_K)) hMB0
    have hB1 : (M.row (2 * shdSegNS s + 1)).map (algebraMap GF shdP_K) = (Hiding.mB (m := 512) (by norm_num) c2.1.2.2.1 false).map (algebraMap GF shdP_K) :=
      congrArg (Polynomial.map (algebraMap GF shdP_K)) hMB1
    have hrb0 : (rs.getD (2 * shdSegNS s) Fp2.zero).toK shdP_U = Hiding.fp2 shdP_U (P.ρb true) := by
      simpa using (hρb true).symm
    have hrb1 : (rs.getD (2 * shdSegNS s + 1) Fp2.zero).toK shdP_U = Hiding.fp2 shdP_U (P.ρb false) := by
      simpa using (hρb false).symm
    have hAsum : ∑ i : Fin (2 * shdSegNS s), C ((rs.getD i.val Fp2.zero).toK shdP_U) * (M.row i.val).map (algebraMap GF shdP_K) =
        (∑ t : Fin (shdSegNS s), ∑ k : Bool, C (algebraMap GF shdP_K (P.ρa t k).1) * (Hiding.mA P (segMaskW s c2.1.1) c2.1.2.1 t k).map (algebraMap GF shdP_K))
        + C shdP_U * (∑ t : Fin (shdSegNS s), ∑ k : Bool, C (algebraMap GF shdP_K (P.ρa t k).2) * (Hiding.mA P (segMaskW s c2.1.1) c2.1.2.1 t k).map (algebraMap GF shdP_K)) := by
      have hpair : ∀ (m : ℕ) (f : ℕ → shdP_K[X]),
          ∑ i : Fin (2 * m), f i.val = ∑ t : Fin m, (f (2 * t.val) + f (2 * t.val + 1)) := by
        intro m f; rw [← Finset.sum_range]
        induction m with
        | zero => simp
        | succ m' ihm =>
          rw [show 2 * (m' + 1) = 2 * m' + 2 by omega, Finset.sum_range_add, Finset.sum_range_succ,
            Finset.sum_range_one, ihm, Fin.sum_univ_castSucc]
          simp only [Fin.val_castSucc, Fin.val_last, Nat.add_zero]
      rw [hpair (shdSegNS s) (fun j => C ((rs.getD j Fp2.zero).toK shdP_U) * (M.row j).map (algebraMap GF shdP_K)),
        Finset.mul_sum, ← Finset.sum_add_distrib]
      refine Finset.sum_congr rfl fun t _ => ?_
      rw [Fintype.sum_bool, Fintype.sum_bool]
      have h1 := hρa t true; simp only [↓reduceIte, Nat.add_zero] at h1
      have h2 := hρa t false; simp only [Bool.false_eq_true, ↓reduceIte] at h2
      have ha1 : M.row (2 * t.val) = Hiding.mA P (segMaskW s c2.1.1) c2.1.2.1 t true := by simpa using hMA t true
      have ha2 : M.row (2 * t.val + 1) = Hiding.mA P (segMaskW s c2.1.1) c2.1.2.1 t false := by simpa using hMA t false
      rw [← h1, ← h2, ha1, ha2]
      simp only [Hiding.fp2, C_add, C_mul]
      ring
    rw [hB0, hB1, hrb0, hrb1, hAsum, Fintype.sum_bool, Fintype.sum_bool]
    simp only [Hiding.fp2, C_add, C_mul]
    ring
  refine ⟨fun i => ?_, fun i => ?_⟩
  · rw [hQpolyEq, hfp2_poly]; dsimp only [mv, Hiding.mOpenView]
  · rw [hPpolyEq, hfp2_poly]; dsimp only [mv, Hiding.mOpenView]

end Level2Bridges

end ZK60.HonestShield
