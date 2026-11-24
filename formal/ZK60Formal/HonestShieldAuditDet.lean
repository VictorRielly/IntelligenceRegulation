/-
D63 lane L68c, deterministic audit & refusal-cover bridges (`HonestShieldAuditDet.lean`):
self-contained, complete proofs (standard Lean foundations only) with no edits to upstream files.

1. **Finding L32-4 closure (`auditClaims` & `checkTokenEp` deterministic non-refusal on surviving runs):**
   - `fp2_det_mulU_ne_zero`, `fp2_det_mulOne_mulU_ne_zero`: canonical `cm ≠ 0 → (Block.det cm (cm.mul Block.fp2U)).v ≠ 0`
     (via `Fp2.norm_ne_zero` / `seven_not_square`).
   - `oneMinusProd_ne_zero_of_noDeg`, `maskCoef_ne_zero_of_noDeg`: non-degenerate canonical `es` yields canonical
     nonzero `oneMinusProd es` and `maskCoef es r` for every `r < es.length`.
   - `zpartRowWeight_*`, `claimWeight_of_unique_part`, **`auditClaims_ok_of_surviving`**: whenever every audited
     claim carries canonical `(cm, cm.mul Block.fp2U)` weights with `cm ≠ 0` (covering both `maskCoef` non-sum
     claims and `(1, fp2U)` `logupSumClaim`), `ExecOpeningBlock.auditClaims` returns `.ok ()`.
   - **`checkTokenEp_header_ok_of_surviving`**, `checkTokenEp_header_ok_of_ext1`: for a surviving singleton
     `INC-00` claim (`ext = 1`, `e₀ ≠ 0`, `e₀ ≠ 1`, or general `es`), all non-`openingChallenges` checks in
     `StageVerifyExec.checkTokenEp` pass deterministically.
2. **Exact `ext`-round `slotProve` refusal cover (fixing `HonestOracleSlots.lean:526` Trap 3 without upstream edits):**
   - **`slotProve_refuses_ext`**, **`fam_refuse_cover_ext`**: preserve `main ≤ m < main + ext` and return
     `j : Fin (Block.slotShape P s).2.1` (bounding Kind 3 to `ext` sites per slot: `4 + 650 + 8 = 662 ≤ 4096`).
3. **`openingGroupsAt` accidental `ZKey` collision `startSite` cover (`k = 1`, `δ = 0`, Kind 1):**
   - `openingGroupsAt_ok_of_uniform`, `openingGroupsAt_lt_implies_collision`, `openingGroupsAt_ne_implies_collision`,
     **`zkeyCollisionStartSite`**, **`openingGroupsAt_collision_startCover`**: covers accidental `ZKey` collisions
     by `k = 1`, `δ = 0` `startSite`s at the chronologically later final challenge coordinate of each colliding pair.
-/
import ZK60Formal.HonestShieldProgBase
import ZK60Formal.HonestRunCover

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open ZK60 ZK60.Exec ZK60.Exec.StageV ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestOracle
  ZK60.HonestRun ZK60.ProtocolClassify
open ZK60.Circuit (gP GF)

/-! ## 1. `Fp2` determinant non-vanishing & non-degenerate `maskCoef` / `oneMinusProd` -/

section Fp2Det

private theorem fp2_eq_of_parts {a b : Fp2} (h0 : a.c0 = b.c0) (h1 : a.c1 = b.c1) : a = b := by
  rcases a with ⟨a0, a1⟩; rcases b with ⟨b0, b1⟩; dsimp only at h0 h1; rw [h0, h1]

private theorem fp_zero_toGF : Fp.zero.toGF = 0 := by simp [Fp.zero, Fp.toGF]

theorem fp2_isZero_iff (a : Fp2) : a.isZero = true ↔ a = Fp2.zero := by
  rcases a with ⟨⟨v0⟩, ⟨v1⟩⟩; simp [Fp2.isZero, Fp2.zero, Fp.zero]

theorem fp2_isZero_false_iff (a : Fp2) : a.isZero = false ↔ a ≠ Fp2.zero := by
  rw [ne_eq, ← fp2_isZero_iff]; cases a.isZero <;> simp

theorem canon_fp2U : Block.fp2U.Canon := ⟨Fp2.canon_zero.1, Fp2.canon_one.1⟩
theorem fp2_one_ne_zero : Fp2.one ≠ Fp2.zero := by decide
theorem fp2U_ne_zero : Block.fp2U ≠ Fp2.zero := by decide

theorem fp2_mul_one (a : Fp2) (ha : a.Canon) : a.mul Fp2.one = a := by
  have hc : (a.mul Fp2.one).Canon := Fp2.canon_mul a Fp2.one
  refine fp2_eq_of_parts (Fp.toGF_injective hc.1 ha.1 ?_) (Fp.toGF_injective hc.2 ha.2 ?_)
  · unfold Fp2.mul Fp2.one; dsimp only
    rw [Fp.toGF_add _ _ (Fp.mul_canon _ _) (Fp.mul_canon _ _),
      Fp.toGF_mul, Fp.toGF_mul, Fp.toGF_mul, Fp.one_toGF, fp_zero_toGF, seven_toGF]; ring
  · unfold Fp2.mul Fp2.one; dsimp only
    rw [Fp.toGF_add _ _ (Fp.mul_canon _ _) (Fp.mul_canon _ _),
      Fp.toGF_mul, Fp.toGF_mul, Fp.one_toGF, fp_zero_toGF]; ring

theorem fp2_zero_add (a : Fp2) (ha : a.Canon) : Fp2.zero.add a = a := by
  have hc : (Fp2.zero.add a).Canon := Fp2.canon_add Fp2.zero a
  refine fp2_eq_of_parts (Fp.toGF_injective hc.1 ha.1 ?_) (Fp.toGF_injective hc.2 ha.2 ?_)
  · change (Fp.zero.add a.c0).toGF = a.c0.toGF
    rw [Fp.toGF_add Fp.zero a.c0 Fp2.canon_zero.1 ha.1, fp_zero_toGF, zero_add]
  · change (Fp.zero.add a.c1).toGF = a.c1.toGF
    rw [Fp.toGF_add Fp.zero a.c1 Fp2.canon_zero.2 ha.2, fp_zero_toGF, zero_add]

theorem fp2_add_zero (a : Fp2) (ha : a.Canon) : a.add Fp2.zero = a := by
  have hc : (a.add Fp2.zero).Canon := Fp2.canon_add a Fp2.zero
  refine fp2_eq_of_parts (Fp.toGF_injective hc.1 ha.1 ?_) (Fp.toGF_injective hc.2 ha.2 ?_)
  · change (a.c0.add Fp.zero).toGF = a.c0.toGF
    rw [Fp.toGF_add a.c0 Fp.zero ha.1 Fp2.canon_zero.1, fp_zero_toGF, add_zero]
  · change (a.c1.add Fp.zero).toGF = a.c1.toGF
    rw [Fp.toGF_add a.c1 Fp.zero ha.2 Fp2.canon_zero.2, fp_zero_toGF, add_zero]

theorem fp2_norm_mul (a b : Fp2) : (a.mul b).norm.toGF = a.norm.toGF * b.norm.toGF := by
  rw [Fp2.norm_toGF, Fp2.norm_toGF, Fp2.norm_toGF]
  have hc0 : (a.mul b).c0.toGF = a.c0.toGF * b.c0.toGF + a.c1.toGF * b.c1.toGF * 7 := by
    change ((a.c0.mul b.c0).add ((a.c1.mul b.c1).mul seven)).toGF = _
    rw [Fp.toGF_add _ _ (Fp.mul_canon _ _) (Fp.mul_canon _ _), Fp.toGF_mul, Fp.toGF_mul, Fp.toGF_mul, seven_toGF]
  have hc1 : (a.mul b).c1.toGF = a.c0.toGF * b.c1.toGF + a.c1.toGF * b.c0.toGF := by
    change ((a.c0.mul b.c1).add (a.c1.mul b.c0)).toGF = _
    rw [Fp.toGF_add _ _ (Fp.mul_canon _ _) (Fp.mul_canon _ _), Fp.toGF_mul, Fp.toGF_mul]
  rw [hc0, hc1]; ring

theorem fp2_mul_ne_zero (a b : Fp2) (ha : a.Canon) (hb : b.Canon) (ha0 : a ≠ Fp2.zero) (hb0 : b ≠ Fp2.zero) :
    a.mul b ≠ Fp2.zero := by
  intro h
  have hmul : (a.mul b).norm.toGF = 0 := by
    rw [h, Fp2.norm_toGF]
    change Fp.zero.toGF * Fp.zero.toGF - 7 * (Fp.zero.toGF * Fp.zero.toGF) = 0
    rw [fp_zero_toGF]; ring
  rw [fp2_norm_mul] at hmul
  exact mul_ne_zero (Fp2.norm_ne_zero a ha ha0) (Fp2.norm_ne_zero b hb hb0) hmul

theorem fp2_one_sub_ne_zero (e : Fp2) (he : e.Canon) (hne : e ≠ Fp2.one) : Fp2.one.sub e ≠ Fp2.zero := by
  intro h
  have h0 : (Fp.one.sub e.c0).toGF = Fp.zero.toGF := congrArg (fun x : Fp2 => x.c0.toGF) h
  have h1 : (Fp.zero.sub e.c1).toGF = Fp.zero.toGF := congrArg (fun x : Fp2 => x.c1.toGF) h
  rw [Fp.toGF_sub Fp.one e.c0 Fp2.canon_one.1 he.1, fp_zero_toGF, sub_eq_zero] at h0
  rw [Fp.toGF_sub Fp.zero e.c1 Fp2.canon_one.2 he.2, fp_zero_toGF, zero_sub, neg_eq_zero] at h1
  exact hne (fp2_eq_of_parts (Fp.toGF_injective he.1 Fp2.canon_one.1 h0.symm)
    (Fp.toGF_injective he.2 Fp2.canon_one.2 (h1.trans fp_zero_toGF.symm)))

/-- `det(cm, cm * u)` equals the `Fp2` norm `cm.c0² - 7 · cm.c1²` in `GF`. -/
theorem fp2_det_mulU_toGF (cm : Fp2) : (Block.det cm (cm.mul Block.fp2U)).toGF = cm.norm.toGF := by
  have hc0 : (cm.mul Block.fp2U).c0.toGF = 7 * cm.c1.toGF := by
    unfold Fp2.mul Block.fp2U; dsimp only
    rw [Fp.toGF_add _ _ (Fp.mul_canon _ _) (Fp.mul_canon _ _),
      Fp.toGF_mul, Fp.toGF_mul, Fp.toGF_mul, fp_zero_toGF, Fp.one_toGF, seven_toGF]; ring
  have hc1 : (cm.mul Block.fp2U).c1.toGF = cm.c0.toGF := by
    unfold Fp2.mul Block.fp2U; dsimp only
    rw [Fp.toGF_add _ _ (Fp.mul_canon _ _) (Fp.mul_canon _ _),
      Fp.toGF_mul, Fp.toGF_mul, Fp.one_toGF, fp_zero_toGF]; ring
  unfold Block.det
  rw [Fp.toGF_sub _ _ (Fp.mul_canon _ _) (Fp.mul_canon _ _), Fp.toGF_mul, Fp.toGF_mul, hc0, hc1, Fp2.norm_toGF]
  ring

/-- **Base-field independence of `(cm, cm * u)`** (`seven_not_square` via `Fp2.norm_ne_zero`). -/
theorem fp2_det_mulU_ne_zero (cm : Fp2) (hcm : cm.Canon) (hne : cm ≠ Fp2.zero) :
    (Block.det cm (cm.mul Block.fp2U)).v ≠ 0 := by
  intro hv
  have hcan : (Block.det cm (cm.mul Block.fp2U)).Canon :=
    Fp.sub_canon _ _ (Fp.mul_canon _ _) (Fp.mul_canon _ _)
  have h0 : (Block.det cm (cm.mul Block.fp2U)).toGF = 0 := (Fp.toGF_zero_iff _ hcan).mpr hv
  rw [fp2_det_mulU_toGF] at h0
  exact Fp2.norm_ne_zero cm hcm hne h0

theorem fp2_det_mulOne_mulU_ne_zero (cm : Fp2) (hcm : cm.Canon) (hne : cm ≠ Fp2.zero) :
    (Block.det (cm.mul Fp2.one) (cm.mul Block.fp2U)).v ≠ 0 := by
  rw [fp2_mul_one cm hcm]; exact fp2_det_mulU_ne_zero cm hcm hne

theorem noDeg_of_any_false (es : List Fp2) (h : es.any (fun x => x.isZero || decide (x = Fp2.one)) = false) :
    ∀ e ∈ es, e ≠ Fp2.zero ∧ e ≠ Fp2.one := by
  intro e he
  have hne : (e.isZero || decide (e = Fp2.one)) ≠ true := by
    intro ht
    have htrue : es.any (fun x => x.isZero || decide (x = Fp2.one)) = true := List.any_eq_true.mpr ⟨e, he, ht⟩
    rw [h] at htrue; cases htrue
  rw [ne_eq] at hne
  simp only [Bool.or_eq_true, fp2_isZero_iff, decide_eq_true_eq, not_or] at hne
  exact hne

theorem fp2_foldl_oneMinus_canon_ne_zero (es : List Fp2) (init : Fp2)
    (hinitC : init.Canon) (hinit0 : init ≠ Fp2.zero) (hcan : ∀ e ∈ es, e.Canon) (hno1 : ∀ e ∈ es, e ≠ Fp2.one) :
    let res := es.foldl (fun a e => a.mul (Fp2.one.sub e)) init
    res.Canon ∧ res ≠ Fp2.zero := by
  induction es generalizing init with
  | nil => exact ⟨hinitC, hinit0⟩
  | cons e rest ih =>
    have heC := hcan e List.mem_cons_self
    exact ih (init.mul (Fp2.one.sub e)) (Fp2.canon_mul _ _)
      (fp2_mul_ne_zero _ _ hinitC (Fp2.canon_sub Fp2.one e Fp2.canon_one heC) hinit0
        (fp2_one_sub_ne_zero e heC (hno1 e List.mem_cons_self)))
      (fun x hx => hcan x (List.mem_cons_of_mem _ hx)) (fun x hx => hno1 x (List.mem_cons_of_mem _ hx))

/-- **`oneMinusProd` is canonical and nonzero** on non-degenerate canonical extension challenges. -/
theorem oneMinusProd_ne_zero_of_noDeg (es : List Fp2) (hcan : ∀ e ∈ es, e.Canon) (hno1 : ∀ e ∈ es, e ≠ Fp2.one) :
    (Block.oneMinusProd es).Canon ∧ Block.oneMinusProd es ≠ Fp2.zero :=
  fp2_foldl_oneMinus_canon_ne_zero es Fp2.one Fp2.canon_one fp2_one_ne_zero hcan hno1

/-- **`maskCoef` is canonical and nonzero** for every `r < es.length` on non-degenerate canonical `es`. -/
theorem maskCoef_ne_zero_of_noDeg (es : List Fp2) (r : ℕ) (hr : r < es.length)
    (hcan : ∀ e ∈ es, e.Canon) (hnoDeg : ∀ e ∈ es, e ≠ Fp2.zero ∧ e ≠ Fp2.one) :
    (Block.maskCoef es r).Canon ∧ Block.maskCoef es r ≠ Fp2.zero := by
  unfold Block.maskCoef
  have hget : es.getD r Fp2.zero = es[r] := by rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hr]; rfl
  have hmem : es.getD r Fp2.zero ∈ es := by rw [hget]; exact List.getElem_mem hr
  exact fp2_foldl_oneMinus_canon_ne_zero (es.drop (r + 1)) (es.getD r Fp2.zero) (hcan _ hmem) (hnoDeg _ hmem).1
    (fun e he => hcan e (List.mem_of_mem_drop he)) (fun e he => (hnoDeg e (List.mem_of_mem_drop he)).2)

end Fp2Det

/-! ## 2. Deterministic `auditClaims` & `checkTokenEp` non-refusal on surviving runs (Finding L32-4) -/

section AuditDet

private theorem ceil_two_pow_div_of_le (m k : ℕ) (h : m ≤ k) : (2 ^ m + 2 ^ k - 1) / 2 ^ k = 1 := by
  have h1 : 1 ≤ 2 ^ m := Nat.one_le_two_pow
  have h2 : 2 ^ m ≤ 2 ^ k := Nat.pow_le_pow_right (by norm_num) h
  have hpos : 0 < 2 ^ k := Nat.two_pow_pos k
  rw [show 2 ^ m + 2 ^ k - 1 = (2 ^ m - 1) + 1 * 2 ^ k by omega,
    Nat.add_mul_div_right _ _ hpos, Nat.div_eq_of_lt (by omega), Nat.zero_add]

private theorem ceil_two_pow_div_of_ge (m k : ℕ) (h : k ≤ m) : (2 ^ m + 2 ^ k - 1) / 2 ^ k = 2 ^ (m - k) := by
  have hpos : 0 < 2 ^ k := Nat.two_pow_pos k
  have hpow : 2 ^ m = 2 ^ (m - k) * 2 ^ k := by rw [← pow_add, Nat.sub_add_cancel h]
  rw [show 2 ^ m + 2 ^ k - 1 = (2 ^ k - 1) + 2 ^ (m - k) * 2 ^ k by rw [hpow]; omega,
    Nat.add_mul_div_right _ _ hpos, Nat.div_eq_of_lt (by omega), Nat.zero_add]

theorem zpartRowWeight_outside (p : Block.ZPart) (logN r : ℕ)
    (h : r < partLo p (2 ^ logN) ∨ partHi p (2 ^ logN) ≤ r) : zpartRowWeight p logN r = Fp2.zero := by
  unfold zpartRowWeight
  by_cases hlt : p.logSize < logN
  · rw [ite_eq_left hlt]
    have hhi : partHi p (2 ^ logN) = partLo p (2 ^ logN) + 1 := by
      unfold partHi partLo; rw [ceil_two_pow_div_of_le p.logSize logN (by omega)]
    exact ite_eq_right (by unfold partLo at h hhi; omega)
  · rw [ite_eq_right hlt]
    have hhi : partHi p (2 ^ logN) = partLo p (2 ^ logN) + 2 ^ (p.logSize - logN) := by
      unfold partHi partLo; rw [ceil_two_pow_div_of_ge p.logSize logN (by omega)]
    exact ite_eq_left (by unfold partLo at h hhi; omega)

theorem zpartRowWeight_singleRow (p : Block.ZPart) (logN r : ℕ)
    (hls : p.logSize ≤ logN) (hr : r = p.offset / 2 ^ logN) (hcan : p.coef.Canon) :
    zpartRowWeight p logN r = p.coef := by
  unfold zpartRowWeight
  by_cases hlt : p.logSize < logN
  · rw [ite_eq_left hlt, ite_eq_left hr]
  · rw [ite_eq_right hlt]
    have hsub : p.logSize - logN = 0 := by omega
    have hin : ¬ (r < p.offset / 2 ^ logN ∨ p.offset / 2 ^ logN + 2 ^ (p.logSize - logN) ≤ r) := by
      rw [hsub, hr]; omega
    rw [ite_eq_right hin]
    by_cases hemp : p.point.isEmpty = true
    · rw [ite_eq_left hemp]
    · rw [ite_eq_right hemp, hsub, List.take_zero]
      have heq : (eqTableMsb []).getD (r - p.offset / 2 ^ logN) Fp2.zero = Fp2.one := by rw [hr, Nat.sub_self]; rfl
      rw [heq, fp2_mul_one p.coef hcan]

theorem zpartRowWeight_emptyPoint (p : Block.ZPart) (logN r : ℕ)
    (hemp : p.point = []) (hlo : partLo p (2 ^ logN) ≤ r) (hhi : r < partHi p (2 ^ logN)) :
    zpartRowWeight p logN r = p.coef := by
  unfold zpartRowWeight
  by_cases hlt : p.logSize < logN
  · rw [ite_eq_left hlt]
    have hhi' : partHi p (2 ^ logN) = partLo p (2 ^ logN) + 1 := by
      unfold partHi partLo; rw [ceil_two_pow_div_of_le p.logSize logN (by omega)]
    exact ite_eq_left (by unfold partLo at hlo hhi'; omega)
  · rw [ite_eq_right hlt]
    have hhi' : partHi p (2 ^ logN) = partLo p (2 ^ logN) + 2 ^ (p.logSize - logN) := by
      unfold partHi partLo; rw [ceil_two_pow_div_of_ge p.logSize logN (by omega)]
    have hin : ¬ (r < p.offset / 2 ^ logN ∨ p.offset / 2 ^ logN + 2 ^ (p.logSize - logN) ≤ r) := by
      unfold partLo at hlo hhi'; omega
    rw [ite_eq_right hin, hemp]
    exact ite_eq_left (show ([] : List Fp2).isEmpty = true from rfl)

private theorem foldl_add_zero {α : Type} (f : α → Fp2) :
    ∀ (l : List α) (init : Fp2), init.Canon → (∀ x ∈ l, f x = Fp2.zero) →
      l.foldl (fun acc x => acc.add (f x)) init = init
  | [], _, _, _ => rfl
  | x :: xs, init, hinit, h0 => by
    rw [List.foldl_cons, h0 x List.mem_cons_self, fp2_add_zero init hinit]
    exact foldl_add_zero f xs init hinit (fun y hy => h0 y (List.mem_cons_of_mem _ hy))

theorem claimWeight_of_unique_part (logN r : ℕ) (c : Block.ZClaim) (l₁ l₂ : List Block.ZPart) (p : Block.ZPart)
    (hparts : c.parts = l₁ ++ p :: l₂) (h1 : ∀ q ∈ l₁, zpartRowWeight q logN r = Fp2.zero)
    (h2 : ∀ q ∈ l₂, zpartRowWeight q logN r = Fp2.zero) (hpC : (zpartRowWeight p logN r).Canon) :
    claimWeight logN c r = zpartRowWeight p logN r := by
  unfold claimWeight
  rw [hparts, List.foldl_append, List.foldl_cons, foldl_add_zero _ l₁ Fp2.zero Fp2.canon_zero h1,
    fp2_zero_add _ hpC, foldl_add_zero _ l₂ _ hpC h2]

/-- Reserved rows touched by a single `ZPart` at row width `n`. -/
def partSiteRows (n : ℕ) (siteRows : List ℕ) (p : Block.ZPart) : List ℕ :=
  (List.range' (partLo p n) (partHi p n - partLo p n)).filter (fun r => decide (r ∈ siteRows))

private def claimTouchedStep (n prox : ℕ) (siteRows : List ℕ) (acc : List ℕ) (p : Block.ZPart) :
    Except String (List ℕ) := do
  if partHi p n > prox then
    throw "private block: mask schedule audit: a claim reaches the proximity pair or leaves the commitment"
  let rs := (List.range' (partLo p n) (partHi p n - partLo p n)).filter (fun r => decide (r ∈ siteRows))
  if !rs.isEmpty && p.coef.isZero then
    throw "private block: mask schedule audit: zero terminal mask coefficient; discard attempt"
  pure (acc ++ rs)

private theorem claimTouchedStep_ok (n prox : ℕ) (siteRows : List ℕ) (acc : List ℕ) (p : Block.ZPart)
    (hhi : partHi p n ≤ prox) (hnz : (partSiteRows n siteRows p).isEmpty = false → p.coef ≠ Fp2.zero) :
    claimTouchedStep n prox siteRows acc p = .ok (acc ++ partSiteRows n siteRows p) := by
  unfold claimTouchedStep
  simp only [Bind.bind, Except.bind, pure, Except.pure]
  have h1 : ¬ (partHi p n > prox) := by omega
  rw [ite_eq_right h1]
  have h2 : (!(partSiteRows n siteRows p).isEmpty && p.coef.isZero) = false := by
    cases hemp : (partSiteRows n siteRows p).isEmpty with
    | true => rfl
    | false => rw [(fp2_isZero_false_iff _).mpr (hnz hemp)]; rfl
  unfold partSiteRows at h2 ⊢
  rw [h2, ite_eq_right Bool.false_ne_true]

private theorem claimTouched_foldlM (n prox : ℕ) (siteRows : List ℕ) :
    ∀ (ps : List Block.ZPart) (acc : List ℕ),
      (∀ p ∈ ps, partHi p n ≤ prox) →
      (∀ p ∈ ps, (partSiteRows n siteRows p).isEmpty = false → p.coef ≠ Fp2.zero) →
      ps.foldlM (claimTouchedStep n prox siteRows) acc = .ok (acc ++ ps.flatMap (partSiteRows n siteRows))
  | [], acc, _, _ => by simp [List.foldlM_nil, pure, Except.pure]
  | p :: ps, acc, hhi, hnz => by
    rw [List.foldlM_cons, claimTouchedStep_ok n prox siteRows acc p (hhi p List.mem_cons_self)
      (hnz p List.mem_cons_self)]
    have ih := claimTouched_foldlM n prox siteRows ps (acc ++ partSiteRows n siteRows p)
      (fun q hq => hhi q (List.mem_cons_of_mem _ hq)) (fun q hq => hnz q (List.mem_cons_of_mem _ hq))
    change ps.foldlM (claimTouchedStep n prox siteRows) (acc ++ partSiteRows n siteRows p) = _
    rw [ih, List.flatMap_cons, List.append_assoc]

theorem claimTouched_ok (n prox : ℕ) (siteRows : List ℕ) (c : Block.ZClaim)
    (hhi : ∀ p ∈ c.parts, partHi p n ≤ prox)
    (hnz : ∀ p ∈ c.parts, (partSiteRows n siteRows p).isEmpty = false → p.coef ≠ Fp2.zero) :
    claimTouched n prox siteRows c = .ok (c.parts.flatMap (partSiteRows n siteRows)) :=
  claimTouched_foldlM n prox siteRows c.parts [] hhi hnz

/-- Occurrence count of `r` in a `List ℕ`. -/
def countNat (r : ℕ) : List ℕ → ℕ
  | [] => 0
  | x :: xs => (if r = x then 1 else 0) + countNat r xs

private theorem incAt_length : ∀ (l : List ℕ) (i : ℕ), (incAt l i).length = l.length
  | [], _ => rfl
  | _ :: _, 0 => rfl
  | _ :: l, i + 1 => by simp [incAt, incAt_length l i]

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

/-- Surviving-run audit specification for claim `c` at index `ci` of `nClaims`: every part stays
below `prox`, every site-touched part has nonzero coefficient, and the audited pair carries
canonical `(cm, cm.mul Block.fp2U)` weights with `cm ≠ Fp2.zero` (non-sum `maskCoef` pair or final
`logupSumClaim` `(1, fp2U)` zero-sum pair). -/
def SurvivingAuditClaim (logN prox : ℕ) (siteRows : List ℕ) (sumRows : Option (ℕ × ℕ))
    (nClaims ci : ℕ) (c : Block.ZClaim) : Prop :=
  let n := 2 ^ logN
  (∀ p ∈ c.parts, partHi p n ≤ prox) ∧
  (∀ p ∈ c.parts, (partSiteRows n siteRows p).isEmpty = false → p.coef ≠ Fp2.zero) ∧
  if c.parts.all (fun p => p.point.isEmpty) then
    ∃ u0 u1 cm, sumRows = some (u0, u1) ∧ ci + 1 = nClaims ∧ c.parts.flatMap (partSiteRows n siteRows) = [] ∧
      (∃ p ∈ c.parts, partLo p n ≤ u0 ∧ u0 < partHi p n ∧ p.coef ≠ Fp2.zero) ∧
      (∃ p ∈ c.parts, partLo p n ≤ u1 ∧ u1 < partHi p n ∧ p.coef ≠ Fp2.zero) ∧
      cm.Canon ∧ cm ≠ Fp2.zero ∧ claimWeight logN c u0 = cm ∧ claimWeight logN c u1 = cm.mul Block.fp2U
  else
    ∃ t0 cm, c.parts.flatMap (partSiteRows n siteRows) = [t0, t0 + 1] ∧ (t0 - siteRows.getD 0 0) % 2 = 0 ∧
      cm.Canon ∧ cm ≠ Fp2.zero ∧ claimWeight logN c t0 = cm ∧ claimWeight logN c (t0 + 1) = cm.mul Block.fp2U

theorem auditOne_ok_of_surviving (logN rows prox : ℕ) (siteRows : List ℕ)
    (sumRows : Option (ℕ × ℕ)) (nClaims ci : ℕ) (c : Block.ZClaim) (uses : List ℕ)
    (hS : SurvivingAuditClaim logN prox siteRows sumRows nClaims ci c) :
    auditOne (2 ^ logN) rows prox siteRows sumRows nClaims ci c uses =
      .ok ((c.parts.flatMap (partSiteRows (2 ^ logN) siteRows)).foldl incAt uses) := by
  obtain ⟨hhi, hnz, hbody⟩ := hS
  unfold auditOne
  rw [claimTouched_ok (2 ^ logN) prox siteRows c hhi hnz]
  simp only [Bind.bind, Except.bind, pure, Except.pure, Nat.log2_two_pow]
  cases his : c.parts.all (fun p => p.point.isEmpty) with
  | false =>
    rw [his, ite_eq_right Bool.false_ne_true] at hbody
    obtain ⟨t0, cm, hT, heven0, hcmC, hcm0, hw0, hw1⟩ := hbody
    rw [hT]; dsimp only
    have hg1 : ¬ (([t0, t0 + 1] : List ℕ).length ≠ 2
        ∨ ([t0, t0 + 1] : List ℕ).getD 1 0 ≠ ([t0, t0 + 1] : List ℕ).getD 0 0 + 1
        ∨ (([t0, t0 + 1] : List ℕ).getD 0 0 - siteRows.getD 0 0) % 2 ≠ 0) := by
      simp only [List.length_cons, List.length_nil, List.getD_cons_zero, List.getD_cons_succ, heven0]; omega
    have hg2 : (Block.det (claimWeight logN c (([t0, t0 + 1] : List ℕ).getD 0 0))
        (claimWeight logN c (([t0, t0 + 1] : List ℕ).getD 1 0))).v ≠ 0 := by
      simp only [List.getD_cons_zero, List.getD_cons_succ, hw0, hw1]; exact fp2_det_mulU_ne_zero cm hcmC hcm0
    rw [ite_eq_right hg1, ite_eq_right hg2]
  | true =>
    rw [his, ite_eq_left rfl] at hbody
    obtain ⟨u0, u1, cm, hsum, hlast, hT, ⟨p0, hp0M, hp0Lo, hp0Hi, hp0Ne⟩,
      ⟨p1, hp1M, hp1Lo, hp1Hi, hp1Ne⟩, hcmC, hcm0, hw0, hw1⟩ := hbody
    rw [hsum, hT]; dsimp only; rw [ite_eq_left hlast]
    have hc0 : c.parts.any (fun p => decide (partLo p (2 ^ logN) ≤ u0 ∧ u0 < partHi p (2 ^ logN))
        && !p.coef.isZero) = true :=
      List.any_eq_true.mpr ⟨p0, hp0M, by simp [hp0Lo, hp0Hi, (fp2_isZero_false_iff _).mpr hp0Ne]⟩
    have hc1 : c.parts.any (fun p => decide (partLo p (2 ^ logN) ≤ u1 ∧ u1 < partHi p (2 ^ logN))
        && !p.coef.isZero) = true :=
      List.any_eq_true.mpr ⟨p1, hp1M, by simp [hp1Lo, hp1Hi, (fp2_isZero_false_iff _).mpr hp1Ne]⟩
    rw [ite_eq_right (by rw [hc0, hc1]; decide)]
    have hg2 : (Block.det (claimWeight logN c u0) (claimWeight logN c u1)).v ≠ 0 := by
      rw [hw0, hw1]; exact fp2_det_mulU_ne_zero cm hcmC hcm0
    rw [ite_eq_right hg2]

theorem auditLoop_ok_of_surviving (logN rows prox : ℕ) (siteRows : List ℕ)
    (sumRows : Option (ℕ × ℕ)) (nClaims : ℕ) :
    ∀ (ci : ℕ) (cs : List Block.ZClaim) (uses : List ℕ),
      (∀ (j : ℕ) (hj : j < cs.length), SurvivingAuditClaim logN prox siteRows sumRows nClaims (ci + j) cs[j]) →
      auditLoop (2 ^ logN) rows prox siteRows sumRows nClaims ci cs uses =
        .ok ((cs.flatMap (fun c => c.parts.flatMap (partSiteRows (2 ^ logN) siteRows))).foldl incAt uses)
  | _, [], _, _ => rfl
  | ci, c :: cs, uses, h => by
    unfold auditLoop
    have h0 : SurvivingAuditClaim logN prox siteRows sumRows nClaims ci c := by
      have h' := h 0 (Nat.zero_lt_succ _); rwa [Nat.add_zero] at h'
    rw [auditOne_ok_of_surviving logN rows prox siteRows sumRows nClaims ci c uses h0]
    simp only [Bind.bind, Except.bind]
    rw [auditLoop_ok_of_surviving logN rows prox siteRows sumRows nClaims (ci + 1) cs _
      (fun j hj => by have h' := h (j + 1) (Nat.succ_lt_succ hj); rwa [show ci + (j + 1) = (ci + 1) + j by omega] at h'),
      List.flatMap_cons, List.foldl_append]

/-- **Finding L32-4 closure for `ExecOpeningBlock.auditClaims`**: on a surviving run where every claim
satisfies `SurvivingAuditClaim` and every reserved row in `siteRows` is touched exactly once across
`claims`, `auditClaims` succeeds deterministically. -/
theorem auditClaims_ok_of_surviving (claims : List Block.ZClaim) (logN rows : ℕ)
    (siteRows : List ℕ) (sumRows : Option (ℕ × ℕ)) (prox : ℕ)
    (hprox : prox + 2 = rows) (heven : siteRows.length % 2 = 0) (hsiteLt : ∀ r ∈ siteRows, r < rows)
    (hclaims : ∀ (i : ℕ) (hi : i < claims.length),
      SurvivingAuditClaim logN prox siteRows sumRows claims.length i claims[i])
    (hcov : ∀ r ∈ siteRows,
      countNat r (claims.flatMap (fun c => c.parts.flatMap (partSiteRows (2 ^ logN) siteRows))) = 1) :
    auditClaims claims (2 ^ logN) rows siteRows sumRows prox = .ok () := by
  unfold auditClaims
  simp only [Bind.bind, Except.bind, pure, Except.pure]
  have hg1 : ¬ (prox + 2 ≠ rows ∨ siteRows.length % 2 ≠ 0) := by omega
  have hg2 : ¬ ((!isPow2 (2 ^ logN)) = true) := by
    rw [HonestOpen.isPow2_two_pow]; exact Bool.false_ne_true
  rw [ite_eq_right hg1, ite_eq_right hg2]
  rw [auditLoop_ok_of_surviving logN rows prox siteRows sumRows claims.length 0 claims
    (List.replicate rows 0) (fun j hj => by have h' := hclaims j hj; rwa [Nat.zero_add])]
  set uses := (claims.flatMap (fun c => c.parts.flatMap (partSiteRows (2 ^ logN) siteRows))).foldl incAt
    (List.replicate rows 0) with huses
  have hany : siteRows.any (fun r => decide (uses.getD r 0 ≠ 1)) = false := by
    cases hb : siteRows.any (fun r => decide (uses.getD r 0 ≠ 1)) with
    | false => rfl
    | true =>
      obtain ⟨r, hrMem, hrNe⟩ := List.any_eq_true.mp hb
      have hrLt : r < (List.replicate rows 0).length := by rw [List.length_replicate]; exact hsiteLt r hrMem
      have hget : uses.getD r 0 = 1 := by
        rw [huses, foldl_incAt_getD _ _ r hrLt, getD_replicate_zero_nat, Nat.zero_add, hcov r hrMem]
      have hf : False := (of_decide_eq_true hrNe) hget; cases hf
  dsimp only
  rw [hany, ite_eq_right Bool.false_ne_true]

/-- **Finding L32-4 closure for `StageVerifyExec.checkTokenEp`**: on a surviving singleton `INC-00`
claim, every non-`openingChallenges` header and coefficient check passes deterministically. -/
theorem checkTokenEp_header_ok_of_surviving (H : HIn → Dig) (P : Block.BlockParams) (p : Block.Priv)
    (pt es : List Fp2) (val : Fp2) (data : ℕ) (t : Tr)
    (hcm : p.cm = .inp) (hslices : p.slices = [(0, Fp2.one)]) (hmask : p.maskRow = data)
    (hdata : (2 ^ p.log + 2 ^ P.endpointLogN - 1) / 2 ^ P.endpointLogN = data)
    (hcan : ∀ e ∈ es, e.Canon) (hnoDeg : ∀ e ∈ es, e ≠ Fp2.zero ∧ e ≠ Fp2.one) (hr : p.extRound < es.length) :
    checkTokenEp H [Block.buildClaim P p pt (Block.oneMinusProd es) (Block.maskCoef es p.extRound) val]
        data (2 ^ P.endpointLogN) t
      = Block.openingChallenges H [1] (data + epMaskRows) (data + 2) t := by
  rcases p with ⟨cm, slices, log, coords, maskRow, extRound⟩
  dsimp only at hcm hslices hmask hdata hr; subst hcm hslices; rw [hmask]
  have hc0 : (if log < P.endpointLogN then 0 % 2 ^ P.endpointLogN else 0) = 0 := by
    by_cases hlt : log < P.endpointLogN
    · rw [ite_eq_left hlt, Nat.zero_mod]
    · rw [ite_eq_right hlt]
  have ⟨hcdC, hcd0⟩ := oneMinusProd_ne_zero_of_noDeg es hcan (fun e he => (hnoDeg e he).2)
  have ⟨hcmC, hcm0⟩ := maskCoef_ne_zero_of_noDeg es extRound hr hcan hnoDeg
  have hp0 : (Fp2.one.mul (Block.oneMinusProd es)).isZero = false :=
    (fp2_isZero_false_iff _).mpr (fp2_mul_ne_zero _ _ Fp2.canon_one hcdC fp2_one_ne_zero hcd0)
  have hp1 : ((Block.maskCoef es extRound).mul Fp2.one).isZero = false :=
    (fp2_isZero_false_iff _).mpr (fp2_mul_ne_zero _ _ hcmC Fp2.canon_one hcm0 fp2_one_ne_zero)
  have hp2 : ((Block.maskCoef es extRound).mul Block.fp2U).isZero = false :=
    (fp2_isZero_false_iff _).mpr (fp2_mul_ne_zero _ _ hcmC canon_fp2U hcm0 fp2U_ne_zero)
  unfold checkTokenEp Block.buildClaim
  dsimp only [Block.rowLog, List.map_cons, List.map_nil, List.cons_append, List.nil_append, List.headD_cons]
  refine ite_eq_left ⟨?_, ?_, ?_, ?_⟩
  · unfold partRows partLo partHi; simp only [Nat.zero_div, Nat.zero_add, hdata]
  · unfold partRows partLo partHi
    rw [hc0, Nat.add_zero, Nat.mul_div_cancel data (Nat.two_pow_pos P.endpointLogN),
      ceil_two_pow_div_of_le (min log P.endpointLogN) P.endpointLogN (min_le_right _ _)]
  · unfold partRows partLo partHi
    rw [hc0, Nat.add_zero, Nat.mul_div_cancel (data + 1) (Nat.two_pow_pos P.endpointLogN),
      ceil_two_pow_div_of_le (min log P.endpointLogN) P.endpointLogN (min_le_right _ _)]
  · simp [hp0, hp1, hp2]

/-- Specialization of `checkTokenEp_header_ok_of_surviving` to `ext = 1` (`es = [e0]`, `p.extRound = 0`). -/
theorem checkTokenEp_header_ok_of_ext1 (H : HIn → Dig) (P : Block.BlockParams) (p : Block.Priv)
    (pt : List Fp2) (e0 val : Fp2) (data : ℕ) (t : Tr)
    (hcm : p.cm = .inp) (hslices : p.slices = [(0, Fp2.one)]) (hmask : p.maskRow = data)
    (hdata : (2 ^ p.log + 2 ^ P.endpointLogN - 1) / 2 ^ P.endpointLogN = data)
    (hext : p.extRound = 0) (heC : e0.Canon) (he0 : e0 ≠ Fp2.zero) (he1 : e0 ≠ Fp2.one) :
    checkTokenEp H [Block.buildClaim P p pt (Block.oneMinusProd [e0]) (Block.maskCoef [e0] p.extRound) val]
        data (2 ^ P.endpointLogN) t
      = Block.openingChallenges H [1] (data + epMaskRows) (data + 2) t :=
  checkTokenEp_header_ok_of_surviving H P p pt [e0] val data t hcm hslices hmask hdata
    (fun e he => by rw [List.mem_singleton.mp he]; exact heC)
    (fun e he => by rw [List.mem_singleton.mp he]; exact ⟨he0, he1⟩) (by rw [hext]; exact Nat.zero_lt_one)

end AuditDet

/-! ## 3. Exact `ext`-round `slotProve` refusal cover (fixing `HonestOracleSlots.lean:526` Trap 3) -/

section ExtRefusal

/-- **Exact `ext`-round `slotProve` refusal decomposition**: preserves `main ≤ m < main + ext`
from `exists_getD_of_mem_drop`, returning `j : Fin (Block.slotShape P s).2.1`. -/
theorem slotProve_refuses_ext {K : Type} [Field K] [DecidableEq K] [Algebra GF K] (U : K)
    (hU : U ^ 2 = algebraMap GF K 7) (H : HIn → Dig) (P : Block.BlockParams) (D : SlotData P)
    (s : ℕ) (hist : Block.Hist) (acc : Block.Acc) (t : Tr) (h : slotProve H P D s hist acc t = .error ()) :
    (∃ e, P.define s hist (t.challengeFp2Vec H (P.draws s)).1 = .error e)
      ∨ ∃ df, P.define s hist (t.challengeFp2Vec H (P.draws s)).1 = .ok df
        ∧ ((challengeFp2Of (H ⟨(slotT2 H P s t).key,
              squeezeMsg (slotT2 H P s t).state (slotT2 H P s t).counter⟩)).toK U ∈ ({0} : Finset K)
          ∨ (∃ j : Fin (Block.slotShape P s).2.1,
              ((slotRho H P D s hist acc t df).getD ((Block.slotShape P s).1 + j.val) Fp2.zero).toK U
                ∈ ({0, 1} : Finset K))
          ∨ (∃ e, Block.slotDefChecks P s acc df = .error e)
          ∨ (∃ e, Block.hostedSum acc.scalars (slotSP H P D s hist acc t df).scalar df.hosted = .error e)
          ∨ ∃ e, Block.tabVals
              (Block.oneMinusProd ((slotRho H P D s hist acc t df).drop (Block.slotShape P s).1))
              ((slotRho H P D s hist acc t df).take (Block.slotShape P s).1)
              (slotSP H P D s hist acc t df).terms df.tabs 0 = .error e) := by
  rcases slotProve_refuses_sites U hU H P D s hist acc t h with hdef | ⟨df, hdf, hc | ⟨y, hy, hy'⟩ | hrest⟩
  · exact Or.inl hdef
  · exact Or.inr ⟨df, hdf, Or.inl hc⟩
  · obtain ⟨m, ha, hm, e⟩ := exists_getD_of_mem_drop Fp2.zero y _ _ hy
    rw [slotRho_length] at hm
    have hlt : m - (Block.slotShape P s).1 < (Block.slotShape P s).2.1 := by
      change m < (Block.slotShape P s).1 + (Block.slotShape P s).2.1 at hm; omega
    refine Or.inr ⟨df, hdf, Or.inr (Or.inl ⟨⟨m - (Block.slotShape P s).1, hlt⟩, ?_⟩)⟩
    rw [show (Block.slotShape P s).1 + (m - (Block.slotShape P s).1) = m by omega, e]; exact hy'
  · exact Or.inr ⟨df, hdf, Or.inr (Or.inr hrest)⟩

/-- **Exact `ext`-round slot-loop refusal cover**: returns `j : Fin ext` at round `main + j.val`,
bounding Kind 3 to `ext` sites per slot (`4 + 650 + 8 = 662 ≤ 4096`). -/
theorem fam_refuse_cover_ext (Lq : ℕ) (hLq : 47 ≤ Lq) {α : Type} (Pf : α → ℕ → Block.BlockParams)
    (Df : (x : α) → (s : ℕ) → SlotData (Pf x s)) (bga : α → Fp2 × Fp2 × Fp2)
    {Coins : Type} [Fintype Coins] [Nonempty Coins] {K : Type} [Field K] [DecidableEq K] [Algebra GF K]
    (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hd : Coins → TProg α) (t0 : Coins → Tr) (hs : ∀ c, TProg.Sep (t0 c).key (hd c))
    (hnC : ∀ i c, TProg.NoWrap (depCProg Pf (famPre Pf Df bga (hd c) i) i) (t0 c))
    (hnE : ∀ i m c, TProg.NoWrap (depEProg Pf Df bga (famPre Pf Df bga (hd c) i) i m) (t0 c))
    (G : QB Lq → Dig) (c : Coins) (n : ℕ) (x : α) (t3 : Tr) (hF : (hd c).final (liftH G) (t0 c) = (t3, x))
    (h : famProve (liftH G) (Pf x) (Df x) (bga x).1 (bga x).2.1 (bga x).2.2 n [] 0 {} t3 = .error ()) :
    ∃ (i : ℕ) (ti : Tr) (recs : List Block.SlotRec) (acc : Block.Acc), i < n
      ∧ (famPre Pf Df bga (hd c) i).final (liftH G) (t0 c) = (ti, (x, recs, acc))
      ∧ ((∃ e, (Pf x i).define i (Block.histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs)
            (ti.challengeFp2Vec (liftH G) ((Pf x i).draws i)).1 = .error e)
        ∨ (depCSite Lq hLq Pf (fun c => famPre Pf Df bga (hd c) i) i t0
            (fun c => sep_famPre Pf Df bga _ (hd c) (hs c) i) (hnC i) (K := K)).fires U G c
        ∨ (∃ j : Fin (Block.slotShape (Pf x i) i).2.1,
            (depESite Lq hLq Pf Df bga (fun c => famPre Pf Df bga (hd c) i) i
              ((Block.slotShape (Pf x i) i).1 + j.val) t0
              (fun c => sep_famPre Pf Df bga _ (hd c) (hs c) i)
              (hnE i ((Block.slotShape (Pf x i) i).1 + j.val)) (K := K)).fires U G c)
        ∨ ∃ df, (Pf x i).define i (Block.histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs)
              (ti.challengeFp2Vec (liftH G) ((Pf x i).draws i)).1 = .ok df
            ∧ ((∃ e, Block.slotDefChecks (Pf x i) i acc df = .error e)
              ∨ (∃ e, Block.hostedSum acc.scalars
                  (slotSP (liftH G) (Pf x i) (Df x i) i
                    (Block.histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc ti df).scalar
                  df.hosted = .error e)
              ∨ ∃ e, Block.tabVals
                  (Block.oneMinusProd ((slotRho (liftH G) (Pf x i) (Df x i) i
                    (Block.histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc ti df).drop
                    (Block.slotShape (Pf x i) i).1))
                  ((slotRho (liftH G) (Pf x i) (Df x i) i
                    (Block.histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc ti df).take
                    (Block.slotShape (Pf x i) i).1)
                  (slotSP (liftH G) (Pf x i) (Df x i) i
                    (Block.histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc ti df).terms
                  df.tabs 0 = .error e)) := by
  obtain ⟨i, sps, recs, acc, ti, hi, hok, hr⟩ :=
    famProve_refuses_at (liftH G) (Pf x) (Df x) (bga x).1 (bga x).2.1 (bga x).2.2 n [] 0 {} t3 h
  rw [Nat.zero_add] at hr
  have hY : (famPre Pf Df bga (hd c) i).final (liftH G) (t0 c) = (ti, (x, recs, acc)) := by
    have h1 := final_famPre (liftH G) Pf Df bga (hd c) i (t0 c) sps recs acc ti (by rw [hF]; exact hok)
    rw [h1, hF]
  refine ⟨i, ti, recs, acc, hi, hY, ?_⟩
  rcases slotProve_refuses_ext U hU (liftH G) (Pf x i) (Df x i) i _ acc ti hr with
    hdef | ⟨df, hdf, hc | ⟨j, hj'⟩ | hrest⟩
  · exact Or.inl hdef
  · refine Or.inr (Or.inl ?_)
    rw [depCSite_fires Lq hLq Pf U hU, hY]
    exact (slot_c_guard_iff U hU (liftH G) (Pf x i) i ti).mpr hc
  · refine Or.inr (Or.inr (Or.inl ⟨j, ?_⟩))
    have hm : (Block.slotShape (Pf x i) i).1 + j.val < slotN (Pf x i) i := by unfold slotN; have := j.isLt; omega
    rw [depESite_fires Lq hLq Pf Df bga U hU _ i ((Block.slotShape (Pf x i) i).1 + j.val)
      t0 _ _ G c ti x recs acc hY hm df hdf]
    exact (degenerate_guard_iff U hU _ (Fp2.canon_getD (scChal_canon (liftH G) _ _) _)).mpr hj'
  · exact Or.inr (Or.inr (Or.inr ⟨df, hdf, hrest⟩))

end ExtRefusal

/-! ## 4. `openingGroupsAt` accidental `ZKey` collision `startSite` cover (`k = 1`, `δ = 0`, Kind 1) -/

section GroupCollision

/-- Column-weight key of a claim's leading part (`openingGroupsAt`'s grouping key). -/
def claimKey (logN : ℕ) (c : Block.ZClaim) : List Fp2 × ℕ × ℕ :=
  partKeyAt (c.parts.headD ⟨0, 0, Fp2.zero, []⟩) logN

private theorem bumpKey_map_fst (key : List Fp2 × ℕ × ℕ) :
    ∀ (gs : List ((List Fp2 × ℕ × ℕ) × ℕ)),
      (bumpKey key gs).map Prod.fst = if key ∈ gs.map Prod.fst then gs.map Prod.fst else gs.map Prod.fst ++ [key]
  | [] => rfl
  | (k, c) :: rest => by
    by_cases heq : k = key
    · subst heq; simp [bumpKey]
    · have ih := bumpKey_map_fst key rest
      have hne : key ≠ k := fun h => heq h.symm
      simp only [bumpKey, heq, ↓reduceIte, List.map_cons, List.mem_cons, hne, false_or, ih]
      by_cases hmem : key ∈ rest.map Prod.fst
      · rw [ite_eq_left hmem, ite_eq_left hmem]
      · rw [ite_eq_right hmem, ite_eq_right hmem]; rfl

private theorem bumpKey_toFinset_card (key : List Fp2 × ℕ × ℕ) (gs : List ((List Fp2 × ℕ × ℕ) × ℕ))
    (h : gs.length = (gs.map Prod.fst).toFinset.card) :
    (bumpKey key gs).length = ((bumpKey key gs).map Prod.fst).toFinset.card := by
  have hlen : (bumpKey key gs).length = ((bumpKey key gs).map Prod.fst).length := by rw [List.length_map]
  rw [hlen, bumpKey_map_fst]
  by_cases hm : key ∈ gs.map Prod.fst
  · rw [ite_eq_left hm, List.length_map]; exact h
  · rw [ite_eq_right hm, List.length_append, List.length_singleton, List.length_map]
    have hins : (gs.map Prod.fst ++ [key]).toFinset = insert key (gs.map Prod.fst).toFinset := by
      ext x; simp only [List.mem_toFinset, List.mem_append, List.mem_singleton, Finset.mem_insert]; exact or_comm
    have hnm : key ∉ (gs.map Prod.fst).toFinset := by rwa [List.mem_toFinset]
    rw [hins, Finset.card_insert_of_notMem hnm, h]

private theorem openingGroupsAt_foldl_inv_keys (logN : ℕ) :
    ∀ (cs : List Block.ZClaim) (gs groups : List ((List Fp2 × ℕ × ℕ) × ℕ)),
      gs.length = (gs.map Prod.fst).toFinset.card → cs.foldlM (grpStep logN) gs = .ok groups →
      (∀ k, k ∈ groups.map Prod.fst ↔ k ∈ gs.map Prod.fst ∨ k ∈ cs.map (claimKey logN))
        ∧ groups.length = (groups.map Prod.fst).toFinset.card
  | [], gs, groups, hcard, h => by
    have h' : (Except.ok gs : Except String (List ((List Fp2 × ℕ × ℕ) × ℕ))) = .ok groups := h
    cases h'; exact ⟨fun k => by simp, hcard⟩
  | c :: cs, gs, groups, hcard, h => by
    have e1 : (c :: cs).foldlM (grpStep logN) gs = grpStep logN gs c >>= fun gs1 => cs.foldlM (grpStep logN) gs1 := rfl
    have e2 : grpStep logN gs c = if c.parts.any (fun p => decide (partKeyAt p logN ≠ claimKey logN c)) = true
      then .error "private block: claim parts with different column weights" else .ok (bumpKey (claimKey logN c) gs) := rfl
    rw [e1, e2] at h
    by_cases hc : c.parts.any (fun p => decide (partKeyAt p logN ≠ claimKey logN c)) = true
    · rw [ite_eq_left hc] at h; cases h
    · rw [ite_eq_right hc] at h
      have h' : cs.foldlM (grpStep logN) (bumpKey (claimKey logN c) gs) = .ok groups := h
      obtain ⟨hmem, hlen⟩ := openingGroupsAt_foldl_inv_keys logN cs (bumpKey (claimKey logN c) gs) groups
        (bumpKey_toFinset_card (claimKey logN c) gs hcard) h'
      refine ⟨fun k => ?_, hlen⟩
      rw [hmem k, bumpKey_map_fst, List.map_cons, List.mem_cons]
      by_cases hck : claimKey logN c ∈ gs.map Prod.fst
      · rw [ite_eq_left hck]
        constructor
        · rintro (h1 | h2)
          · exact Or.inl h1
          · exact Or.inr (Or.inr h2)
        · rintro (h1 | rfl | h2)
          · exact Or.inl h1
          · exact Or.inl hck
          · exact Or.inr h2
      · rw [ite_eq_right hck, List.mem_append, List.mem_singleton]
        constructor
        · rintro ((h1 | rfl) | h2)
          · exact Or.inl h1
          · exact Or.inr (Or.inl rfl)
          · exact Or.inr (Or.inr h2)
        · rintro (h1 | rfl | h2)
          · exact Or.inl (Or.inl h1)
          · exact Or.inl (Or.inr rfl)
          · exact Or.inr h2

theorem openingGroupsAt_keys_iff (claims : List Block.ZClaim) (logN : ℕ)
    (groups : List ((List Fp2 × ℕ × ℕ) × ℕ)) (h : openingGroupsAt claims logN = .ok groups) :
    ∀ k, k ∈ groups.map Prod.fst ↔ k ∈ claims.map (claimKey logN) := by
  have hinv := (openingGroupsAt_foldl_inv_keys logN claims [] groups (by simp) h).1
  intro k; simpa using hinv k

theorem openingGroupsAt_length_eq_card (claims : List Block.ZClaim) (logN : ℕ)
    (groups : List ((List Fp2 × ℕ × ℕ) × ℕ)) (h : openingGroupsAt claims logN = .ok groups) :
    groups.length = (groups.map Prod.fst).toFinset.card :=
  (openingGroupsAt_foldl_inv_keys logN claims [] groups (by simp) h).2

private theorem grp_fold_ok_of_uniform (logN : ℕ) :
    ∀ (claims : List Block.ZClaim) (gs : List ((List Fp2 × ℕ × ℕ) × ℕ)),
      (∀ c ∈ claims, ∀ p ∈ c.parts, partKeyAt p logN = claimKey logN c) →
      claims.foldlM (grpStep logN) gs = .ok (claims.foldl (fun acc c => bumpKey (claimKey logN c) acc) gs)
  | [], _, _ => rfl
  | c :: cs, gs, hunif => by
    have e1 : (c :: cs).foldlM (grpStep logN) gs = grpStep logN gs c >>= fun gs1 => cs.foldlM (grpStep logN) gs1 := rfl
    have hstep : grpStep logN gs c = .ok (bumpKey (claimKey logN c) gs) := by
      have e2 : grpStep logN gs c = if c.parts.any (fun p => decide (partKeyAt p logN ≠ claimKey logN c)) = true
        then .error "private block: claim parts with different column weights" else .ok (bumpKey (claimKey logN c) gs) := rfl
      rw [e2]
      have hfalse : c.parts.any (fun p => decide (partKeyAt p logN ≠ claimKey logN c)) = false := by
        cases hb : c.parts.any (fun p => decide (partKeyAt p logN ≠ claimKey logN c)) with
        | false => rfl
        | true =>
          obtain ⟨p, hpMem, hpNe⟩ := List.any_eq_true.mp hb
          have hf : False := (of_decide_eq_true hpNe) (hunif c List.mem_cons_self p hpMem); cases hf
      rw [hfalse, ite_eq_right Bool.false_ne_true]
    rw [e1, hstep]
    exact grp_fold_ok_of_uniform logN cs (bumpKey (claimKey logN c) gs)
      (fun c' hc' => hunif c' (List.mem_cons_of_mem _ hc'))

/-- When every claim's parts share the same column-weight key, `openingGroupsAt` never returns `.error`. -/
theorem openingGroupsAt_ok_of_uniform (claims : List Block.ZClaim) (logN : ℕ)
    (hunif : ∀ c ∈ claims, ∀ p ∈ c.parts, partKeyAt p logN = claimKey logN c) :
    openingGroupsAt claims logN = .ok (claims.foldl (fun acc c => bumpKey (claimKey logN c) acc) []) :=
  grp_fold_ok_of_uniform logN claims [] hunif

theorem openingGroupsAt_length_le (claims : List Block.ZClaim) (logN gExp : ℕ)
    (groups : List ((List Fp2 × ℕ × ℕ) × ℕ)) (expKey : Fin gExp → List Fp2 × ℕ × ℕ)
    (hgr : openingGroupsAt claims logN = .ok groups)
    (hsubCl : ∀ cl ∈ claims, ∃ a : Fin gExp, claimKey logN cl = expKey a) :
    groups.length ≤ gExp := by
  have hsub : (groups.map Prod.fst).toFinset ⊆ Finset.univ.image expKey := by
    intro k hk
    rw [List.mem_toFinset, openingGroupsAt_keys_iff claims logN groups hgr] at hk
    obtain ⟨cl, hclMem, hclKey⟩ := List.mem_map.mp hk
    obtain ⟨a, ha⟩ := hsubCl cl hclMem
    exact Finset.mem_image.mpr ⟨a, Finset.mem_univ a, ha.symm.trans hclKey⟩
  calc groups.length = (groups.map Prod.fst).toFinset.card := openingGroupsAt_length_eq_card claims logN groups hgr
    _ ≤ (Finset.univ.image expKey).card := Finset.card_le_card hsub
    _ ≤ (Finset.univ : Finset (Fin gExp)).card := Finset.card_image_le
    _ = gExp := by rw [Finset.card_univ, Fintype.card_fin]

/-- **Pigeonhole for `openingGroupsAt`**: fewer than `gExp` groups implies a colliding pair `a < b`. -/
theorem openingGroupsAt_lt_implies_collision (claims : List Block.ZClaim) (logN gExp : ℕ)
    (groups : List ((List Fp2 × ℕ × ℕ) × ℕ)) (expKey : Fin gExp → List Fp2 × ℕ × ℕ)
    (hgr : openingGroupsAt claims logN = .ok groups)
    (hsurj : ∀ a : Fin gExp, ∃ cl ∈ claims, claimKey logN cl = expKey a) (hlt : groups.length < gExp) :
    ∃ a b : Fin gExp, a < b ∧ expKey a = expKey b := by
  by_contra hno
  have hinj : Function.Injective expKey := by
    intro a b hab; by_contra hne
    rcases lt_or_gt_of_ne hne with hlt' | hlt'
    · exact hno ⟨a, b, hlt', hab⟩
    · exact hno ⟨b, a, hlt', hab.symm⟩
  have hsub : Finset.univ.image expKey ⊆ (groups.map Prod.fst).toFinset := by
    intro k hk
    obtain ⟨a, -, rfl⟩ := Finset.mem_image.mp hk
    rw [List.mem_toFinset, openingGroupsAt_keys_iff claims logN groups hgr]
    obtain ⟨cl, hclMem, hclKey⟩ := hsurj a
    exact List.mem_map.mpr ⟨cl, hclMem, hclKey⟩
  have hle : gExp ≤ groups.length := by
    calc gExp = (Finset.univ : Finset (Fin gExp)).card := by rw [Finset.card_univ, Fintype.card_fin]
      _ = (Finset.univ.image expKey).card := (Finset.card_image_of_injective Finset.univ hinj).symm
      _ ≤ (groups.map Prod.fst).toFinset.card := Finset.card_le_card hsub
      _ = groups.length := (openingGroupsAt_length_eq_card claims logN groups hgr).symm
  omega

theorem openingGroupsAt_ne_implies_collision (claims : List Block.ZClaim) (logN gExp : ℕ)
    (groups : List ((List Fp2 × ℕ × ℕ) × ℕ)) (expKey : Fin gExp → List Fp2 × ℕ × ℕ)
    (hgr : openingGroupsAt claims logN = .ok groups)
    (hsub : ∀ cl ∈ claims, ∃ a : Fin gExp, claimKey logN cl = expKey a)
    (hsurj : ∀ a : Fin gExp, ∃ cl ∈ claims, claimKey logN cl = expKey a) (hne : groups.length ≠ gExp) :
    groups.length < gExp ∧ ∃ a b : Fin gExp, a < b ∧ expKey a = expKey b := by
  have hle := openingGroupsAt_length_le claims logN gExp groups expKey hgr hsub
  have hlt : groups.length < gExp := by omega
  exact ⟨hlt, openingGroupsAt_lt_implies_collision claims logN gExp groups expKey hgr hsurj hlt⟩

/-- Flip-coordinate helper (`Coord.flip`): `1 - x = y` pins canonical `x` to the single value `1 - y`. -/
theorem fp2_one_sub_toK_eq {K : Type} [Field K] [Algebra GF K] (U : K) (x y : Fp2) (hx : x.Canon)
    (h : Fp2.one.sub x = y) : x.toK U = 1 - y.toK U := by
  have h1 : (Fp2.one.sub x).toK U = y.toK U := congrArg (Fp2.toK U) h
  rw [Fp2.toK_sub U Fp2.one x Fp2.canon_one hx, Fp2.toK_one] at h1
  linear_combination -h1

/-- **Single-value `ZKey` collision `startSite`** (`k = 1`, `δ = 0`, Kind 1). -/
noncomputable def zkeyCollisionStartSite {α Coins K : Type} [Fintype Coins] [Nonempty Coins]
    [Field K] [DecidableEq K] [Algebra GF K]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (prog : Coins → TProg α) (target : α → K)
    (hs : ∀ c, TProg.Sep key (prog c)) (hn : ∀ c dg, TProg.NoWrap (prog c) ⟨dg, 0, key⟩) :
    ProtocolClassify.Site (QB Lq) Coins K :=
  startSite Lq hLq key domain hdom prog (fun v => ({target v} : Finset K)) 1 (fun _ => by simp) hs hn

theorem zkeyCollisionStartSite_k_delta {α Coins K : Type} [Fintype Coins] [Nonempty Coins]
    [Field K] [DecidableEq K] [Algebra GF K]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (prog : Coins → TProg α) (target : α → K)
    (hs : ∀ c, TProg.Sep key (prog c)) (hn : ∀ c dg, TProg.NoWrap (prog c) ⟨dg, 0, key⟩) :
    (zkeyCollisionStartSite Lq hLq key domain hdom prog target hs hn).k = 1
      ∧ (zkeyCollisionStartSite Lq hLq key domain hdom prog target hs hn).δ = 0 := ⟨rfl, rfl⟩

theorem zkeyCollisionStartSite_fires {α Coins K : Type} [Fintype Coins] [Nonempty Coins]
    [Field K] [DecidableEq K] [Algebra GF K] (U : K)
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (prog : Coins → TProg α) (target : α → K)
    (hs : ∀ c, TProg.Sep key (prog c)) (hn : ∀ c dg, TProg.NoWrap (prog c) ⟨dg, 0, key⟩)
    (G : QB Lq → Dig) (c : Coins) :
    (zkeyCollisionStartSite Lq hLq key domain hdom prog target hs hn).fires U G c ↔
      let t0 := Tr.newKeyed (liftH G) domain key
      (challengeFp2Of (liftH G ⟨((prog c).final (liftH G) t0).1.key,
        squeezeMsg ((prog c).final (liftH G) t0).1.state ((prog c).final (liftH G) t0).1.counter⟩)).toK U
        = target ((prog c).final (liftH G) t0).2 := by
  unfold zkeyCollisionStartSite; rw [startSite_fires]; dsimp only; exact Finset.mem_singleton

/-- **Accidental `ZKey` collision `startSite` cover (`k = 1`, `δ = 0`, Kind 1)**: whenever
`openingGroupsAt` yields `groups.length ≠ gExp`, some colliding pair `a < b` of expected groups
forces the chronologically later challenge squeeze (`prog i c`) to equal its single already-fixed
value (`target i`), firing `zkeyCollisionStartSite`. -/
theorem openingGroupsAt_collision_startCover {ι Coins K : Type} [Fintype Coins] [Nonempty Coins]
    [Field K] [DecidableEq K] [Algebra GF K] (U : K)
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (α : ι → Type) (prog : (i : ι) → Coins → TProg (α i)) (target : (i : ι) → α i → K)
    (hs : ∀ i c, TProg.Sep key (prog i c)) (hn : ∀ i c dg, TProg.NoWrap (prog i c) ⟨dg, 0, key⟩)
    (G : QB Lq → Dig) (c : Coins) (claims : List Block.ZClaim) (logN gExp : ℕ)
    (groups : List ((List Fp2 × ℕ × ℕ) × ℕ)) (expKey : Fin gExp → List Fp2 × ℕ × ℕ)
    (hgr : openingGroupsAt claims logN = .ok groups)
    (hsub : ∀ cl ∈ claims, ∃ a : Fin gExp, claimKey logN cl = expKey a)
    (hsurj : ∀ a : Fin gExp, ∃ cl ∈ claims, claimKey logN cl = expKey a) (hne : groups.length ≠ gExp)
    (hpair : ∀ a b : Fin gExp, a < b → expKey a = expKey b →
      ∃ i : ι, let t0 := Tr.newKeyed (liftH G) domain key
        (challengeFp2Of (liftH G ⟨((prog i c).final (liftH G) t0).1.key,
          squeezeMsg ((prog i c).final (liftH G) t0).1.state ((prog i c).final (liftH G) t0).1.counter⟩)).toK U
          = target i ((prog i c).final (liftH G) t0).2) :
    ∃ i : ι, (zkeyCollisionStartSite Lq hLq key domain hdom (prog i) (target i) (hs i) (hn i)).fires U G c := by
  obtain ⟨-, a, b, hlt, heq⟩ := openingGroupsAt_ne_implies_collision claims logN gExp groups expKey hgr hsub hsurj hne
  obtain ⟨i, hi⟩ := hpair a b hlt heq
  exact ⟨i, (zkeyCollisionStartSite_fires U Lq hLq key domain hdom (prog i) (target i) (hs i) (hn i) G c).mpr hi⟩

end GroupCollision

end ZK60.HonestShield
