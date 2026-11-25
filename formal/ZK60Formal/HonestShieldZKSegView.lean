/-
D63 lane L69, Milestone B Part 2a (`HonestShieldZKSegView.lean`):
generic PCS / Level-2 honest-view builders and exact receipt-field reconstruction bridges
for the concrete Shieldstral T128 R13 honest prover (`shdP_runFixedProg`):

1. **Generic `groupZclaims` / `groupRhosAux` / `claimSem` Reconstruction**:
   - `claimWeights_eq_of_parts`, `claimWeight_eq_of_parts`, `groupZclaims_mem_rw_eq`,
     `groupZclaims_rw_eq_of_parts`, `groupRhosAux_eq_of_parts`: every grouped row-combination
     depends ONLY on `cl.map ZClaim.parts` and `lams`, never on `ZClaim.value`.
   - `claimSem_of_vec`: recovers `Link.claimSem shdP_U R lc 0 (tabMat R lc rows) z` directly
     from the individual claim row-vector `vec : Hiding.Row shdP_K (2^lc) 256` and `z.parts`.
   - `groupRhosAux_combVec_of_claimVecs`: recovers all grouped PCS vectors (`OpeningZk.vecs`)
     as a pure function of individual claim vectors `claimVec : Fin cl.length → Row` and `v`.

2. **Input Endpoint `TE` (`shdP_teSpec`, 6 rows, `logN = 8, lr = 3`)**:
   - `teRowOf`, `shdP_epTable_rows_eq`, `teClaim_combAt_eq_view`, `teProx_combAt_eq_view`,
     `teCol_eq_view`, `tePcsData_of_audit`, `teClaimSem_of_view`, `teOpenRecon`, `teOpen_of_view`.

3. **Standard PCS Tables (`B_0..26`, `A_0..27`)**:
   - `stdCol_eq_view`, `stdPcsData_of_audit`, `stdClaimSem_of_view`, `stdOpenRecon`, `stdOpen_of_view`.

4. **`H` PCS Tables (`H_0..27`) & `PcsAHData`**:
   - `hdH_of_logupSumClaim_true`, `hCol_eq_view`, `pcsAHData_of_audit`,
     `hClaimSem_of_view`, `hOpenRecon`, `hOpen_of_view`.

5. **Level-2 Segment Builders (`MOpenPub`, `MaskOpening`, `SlotProof`, `codeFuns`)**:
   - `maskPoly_packSegMA_eq_cfsEval`, `cubeSum_maskPoly_packSegMA_eq_cfsTotal`.
   - `segMOpenPub`, `segMOpenPub_facts`, `segMOpenPub_hW_hlay`, `segMOpenRecon`, `segMOpen_of_mOpenView`.
   - `slotProofRecon`, `slotProof_of_slotView`.

Uses only standard Lean/Mathlib foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.HonestShieldZKViewBridge

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open Finset Polynomial
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Hiding ZK60.ZKW16 ZK60.ZKLinks ZK60.ZKHonest
open ZK60.HonestClassify ZK60.HonestOpen ZK60.ProtocolClassify ZK60.TokenRun
open ZK60.Circuit (gP GF)
open ZK60.Exec.Slot.W16R2 (Kind)
open ZK60.RunShape.Shield (shieldS0)

/-! ## 1. Generic `claimWeights`, `claimSem`, and `groupZclaims` / `groupRhosAux` Reconstruction -/

section GenericGroupAndClaimRecon

theorem claimWeights_eq_of_parts (R lc : ℕ) {z₁ z₂ : Block.ZClaim} (h : z₁.parts = z₂.parts) :
    claimWeights (toZClaim z₁) R lc = claimWeights (toZClaim z₂) R lc := by
  unfold claimWeights toZClaim
  simp only [h]

theorem claimWeight_eq_of_parts (lc : ℕ) {z₁ z₂ : Block.ZClaim} (h : z₁.parts = z₂.parts) (r : ℕ) :
    claimWeight lc z₁ r = claimWeight lc z₂ r := by
  unfold claimWeight
  simp only [h]

/-- Pure `parts`-only claim evaluation from an individual claim row vector `vec`. -/
noncomputable def claimValFromVec (R lc : ℕ) (zRef : Block.ZClaim)
    (vec : Hiding.Row shdP_K (2 ^ lc) 256) : shdP_K :=
  ∑ t : Fin (2 ^ lc), vec (Sum.inl t) *
    ((zkeyWeights (claimWeights (toZClaim zRef) R lc).2 lc).getD t.val Fp2.zero).toK shdP_U

/-- **`Link.claimSem` recovery directly from an individual claim vector `vec`**, without needing `ClaimTrue`:
for any `z` whose `parts` match `zRef`, `claimSem` equals `claimValFromVec R lc zRef vec`. -/
theorem claimSem_of_vec {R lc : ℕ} (rows : List (List Fp)) (hR : rows.length = R)
    (z zRef : Block.ZClaim) (hparts : z.parts = zRef.parts)
    (vec : Hiding.Row shdP_K (2 ^ lc) 256)
    (hvec : ∀ t : Fin (2 ^ lc),
      (combAt (claimWeights (toZClaim zRef) R lc).1 rows t.val).toK shdP_U = vec (Sum.inl t)) :
    Link.claimSem shdP_U R lc 0 (tabMat R lc rows) z = claimValFromVec R lc zRef vec := by
  let vK := Link.claimSem shdP_U R lc 0 (tabMat R lc rows) z
  let z' : Block.ZClaim := ⟨z.parts, ofK shdP_U shdP_hbij vK⟩
  have hsemEq : Link.claimSem shdP_U R lc 0 (tabMat R lc rows) z' = vK :=
    claimSem_value_indep shdP_U R lc 0 (tabMat R lc rows) z.parts _ z.value
  have htrue : ClaimTrue shdP_U (2 ^ lc) lc rows (toZClaim z') := by
    rw [claimTrue_iff_claimSem shdP_U R lc rows hR z', hsemEq]
    exact toK_ofK shdP_U shdP_hbij vK
  have hval := claimTrue_toK_of_vec rows z' htrue vec (fun t => by
    have hcw : claimWeights (toZClaim z') rows.length lc = claimWeights (toZClaim zRef) R lc := by
      rw [hR]; exact claimWeights_eq_of_parts R lc hparts
    rw [hcw]; exact hvec t)
  have hcw2 : claimWeights (toZClaim z') rows.length lc = claimWeights (toZClaim zRef) R lc := by
    rw [hR]; exact claimWeights_eq_of_parts R lc hparts
  rw [hcw2] at hval
  have hval' : z'.value.toK shdP_U = vK := toK_ofK shdP_U shdP_hbij vK
  exact hval'.symm.trans hval

/-- Every member `(rw, val)` of every group in `groupZclaims (cl.map toZClaim) rows lc` has
`rw = (claimWeights (toZClaim cl[i]) rows lc).1` for some `i : Fin cl.length`. -/
theorem groupZclaims_mem_rw_eq (rows lc : ℕ) (cl : List Block.ZClaim) :
    ∀ grp ∈ groupZclaims (cl.map toZClaim) rows lc,
      ∀ m ∈ grp.2, ∃ i : Fin cl.length, m.1 = (claimWeights (toZClaim cl[i.val]) rows lc).1 := by
  have hfold : ∀ (l : List Block.ZClaim) (ks : List ZKey) (gs : List (List Fp2 × List (List Fp2 × Fp2))),
      (∀ grp ∈ gs, ∀ m ∈ grp.2, ∃ i : Fin cl.length, m.1 = (claimWeights (toZClaim cl[i.val]) rows lc).1) →
      (∀ c ∈ l, ∃ i : Fin cl.length, c = cl[i.val]) →
      ∀ grp ∈ ((l.map toZClaim).foldl (groupStep rows lc) (ks, gs)).2,
        ∀ m ∈ grp.2, ∃ i : Fin cl.length, m.1 = (claimWeights (toZClaim cl[i.val]) rows lc).1 := by
    intro l
    induction l with
    | nil => intro _ _ hgs _ grp hgrp m hm; exact hgs grp hgrp m hm
    | cons c cs ih =>
      intro ks gs hgs hmem
      simp only [List.map_cons, List.foldl_cons]
      refine ih _ _ ?_ (fun c' hc' => hmem c' (List.mem_cons_of_mem _ hc'))
      obtain ⟨ic, hic⟩ := hmem c List.mem_cons_self
      dsimp only
      have hmemPush : ∀ (xs : List (List Fp2 × List (List Fp2 × Fp2))) (gi : ℕ) (m0 : List Fp2 × Fp2),
          ∀ grp ∈ pushAt xs gi m0, ∀ m ∈ grp.2,
            (∃ grp0 ∈ xs, m ∈ grp0.2) ∨ m = m0 := by
        intro xs gi m0
        induction xs generalizing gi with
        | nil => intro _ h; cases h
        | cons a as iha =>
          cases gi with
          | zero =>
            intro grp hgrp m hm
            rcases List.mem_cons.mp hgrp with rfl | htail
            · rcases List.mem_append.mp hm with hm1 | hm2
              · exact Or.inl ⟨a, List.mem_cons_self, hm1⟩
              · exact Or.inr (List.mem_singleton.mp hm2)
            · exact Or.inl ⟨grp, List.mem_cons_of_mem _ htail, hm⟩
          | succ gi' =>
            intro grp hgrp m hm
            rcases List.mem_cons.mp hgrp with rfl | htail
            · exact Or.inl ⟨grp, List.mem_cons_self, hm⟩
            · rcases iha gi' grp htail m hm with ⟨grp0, hg0, hm0⟩ | rfl
              · exact Or.inl ⟨grp0, List.mem_cons_of_mem _ hg0, hm0⟩
              · exact Or.inr rfl
      cases keyIdx ks (claimWeights (toZClaim c) rows lc).2 with
      | some gi =>
        intro grp hgrp m hm
        rcases hmemPush gs gi _ grp hgrp m hm with ⟨grp0, hg0, hm0⟩ | rfl
        · exact hgs grp0 hg0 m hm0
        · rw [hic]; exact ⟨ic, rfl⟩
      | none =>
        intro grp hgrp m hm
        rcases List.mem_append.mp hgrp with h1 | h2
        · exact hgs grp h1 m hm
        · rw [List.mem_singleton.mp h2] at hm
          rw [List.mem_singleton.mp hm, hic]
          exact ⟨ic, rfl⟩
  unfold groupZclaims
  exact hfold cl [] [] (fun _ h => by cases h) (fun c hc => by
    obtain ⟨i, hi, rfl⟩ := List.getElem_of_mem hc
    exact ⟨⟨i, hi⟩, rfl⟩)

/-- `groupZclaims`'s `(keys, group-member rw lists)` depend ONLY on `cl.map Block.ZClaim.parts`. -/
theorem groupZclaims_rw_eq_of_parts (rows lc : ℕ) {cl₁ cl₂ : List Block.ZClaim}
    (h : cl₁.map Block.ZClaim.parts = cl₂.map Block.ZClaim.parts) :
    (groupZclaims (cl₁.map toZClaim) rows lc).map (fun g => (g.1, g.2.map Prod.fst))
      = (groupZclaims (cl₂.map toZClaim) rows lc).map (fun g => (g.1, g.2.map Prod.fst)) := by
  have hfold : ∀ (l₁ l₂ : List Block.ZClaim), l₁.map Block.ZClaim.parts = l₂.map Block.ZClaim.parts →
      ∀ (ks : List ZKey) (gs₁ gs₂ : List (List Fp2 × List (List Fp2 × Fp2))),
        gs₁.map (fun g => (g.1, g.2.map Prod.fst)) = gs₂.map (fun g => (g.1, g.2.map Prod.fst)) →
        let r₁ := (l₁.map toZClaim).foldl (groupStep rows lc) (ks, gs₁)
        let r₂ := (l₂.map toZClaim).foldl (groupStep rows lc) (ks, gs₂)
        r₁.1 = r₂.1 ∧ r₁.2.map (fun g => (g.1, g.2.map Prod.fst)) = r₂.2.map (fun g => (g.1, g.2.map Prod.fst)) := by
    intro l₁
    induction l₁ with
    | nil =>
      intro l₂ hl ks gs₁ gs₂ hgs
      cases l₂ with
      | nil => exact ⟨rfl, hgs⟩
      | cons _ _ => simp at hl
    | cons c₁ cs₁ ih =>
      intro l₂ hl ks gs₁ gs₂ hgs
      cases l₂ with
      | nil => simp at hl
      | cons c₂ cs₂ =>
        simp only [List.map_cons, List.cons.injEq] at hl
        obtain ⟨hp, hps⟩ := hl
        have hcw : claimWeights (toZClaim c₁) rows lc = claimWeights (toZClaim c₂) rows lc :=
          claimWeights_eq_of_parts rows lc hp
        simp only [List.map_cons, List.foldl_cons]
        have hstep : (groupStep rows lc (ks, gs₁) (toZClaim c₁)).1 = (groupStep rows lc (ks, gs₂) (toZClaim c₂)).1
            ∧ (groupStep rows lc (ks, gs₁) (toZClaim c₁)).2.map (fun g => (g.1, g.2.map Prod.fst))
              = (groupStep rows lc (ks, gs₂) (toZClaim c₂)).2.map (fun g => (g.1, g.2.map Prod.fst)) := by
          unfold groupStep
          rw [hcw]
          dsimp only
          have hmapPush : ∀ (xs : List (List Fp2 × List (List Fp2 × Fp2))) (gi : ℕ) (m0 : List Fp2 × Fp2),
              (pushAt xs gi m0).map (fun g => (g.1, g.2.map Prod.fst))
                = pushAt (xs.map (fun g => (g.1, g.2.map Prod.fst))) gi m0.1 := by
            intro xs gi m0
            induction xs generalizing gi with
            | nil => rfl
            | cons a as iha =>
              cases gi with
              | zero => simp [pushAt]
              | succ gi' => simp only [pushAt, List.map_cons, iha gi']
          cases keyIdx ks (claimWeights (toZClaim c₂) rows lc).2 with
          | some gi =>
            refine ⟨rfl, ?_⟩
            rw [hmapPush, hmapPush, hgs]
          | none =>
            exact ⟨rfl, by simp [hgs]⟩
        cases h1 : groupStep rows lc (ks, gs₁) (toZClaim c₁) with
        | mk ks₁' gs₁' =>
          cases h2 : groupStep rows lc (ks, gs₂) (toZClaim c₂) with
          | mk ks₂' gs₂' =>
            rw [h1, h2] at hstep
            obtain ⟨rfl, hgs'⟩ := hstep
            exact ih cs₂ hps ks₁' gs₁' gs₂' hgs'
  exact (hfold cl₁ cl₂ h [] [] [] rfl).2

theorem groupComb_fst_eq_of_rws (rows : ℕ) {m₁ m₂ : List (List Fp2 × Fp2)} (hm : m₁.map Prod.fst = m₂.map Prod.fst)
    (lams : List Fp2) :
    (groupComb rows m₁ lams).1 = (groupComb rows m₂ lams).1 := by
  have hfold : ∀ (a₁ a₂ : List (List Fp2 × Fp2)) (ls : List Fp2),
      a₁.map Prod.fst = a₂.map Prod.fst →
      ∀ (acc : List Fp2) (v₁ v₂ : Fp2),
        ((a₁.zip ls).foldl (fun a p => (rhoAdd p.2 a.1 p.1.1, a.2.add (p.2.mul p.1.2))) (acc, v₁)).1
          = ((a₂.zip ls).foldl (fun a p => (rhoAdd p.2 a.1 p.1.1, a.2.add (p.2.mul p.1.2))) (acc, v₂)).1 := by
    intro a₁
    induction a₁ with
    | nil =>
      intro a₂ ls h acc v₁ v₂
      cases a₂ with
      | nil => rfl
      | cons _ _ => simp at h
    | cons x₁ xs₁ ih =>
      intro a₂ ls h acc v₁ v₂
      cases a₂ with
      | nil => simp at h
      | cons x₂ xs₂ =>
        simp only [List.map_cons, List.cons.injEq] at h
        cases ls with
        | nil => rfl
        | cons l ls' =>
          simp only [List.zip_cons_cons, List.foldl_cons, h.1]
          exact ih xs₂ ls' h.2 _ _ _
  exact hfold m₁ m₂ lams hm (List.replicate rows Fp2.zero) Fp2.zero Fp2.zero

/-- `groupRhosAux` depends ONLY on `cl.map Block.ZClaim.parts` (never on claim values). -/
theorem groupRhosAux_eq_of_parts (rows lc : ℕ) {cl₁ cl₂ : List Block.ZClaim}
    (h : cl₁.map Block.ZClaim.parts = cl₂.map Block.ZClaim.parts) (lams : List Fp2) :
    groupRhosAux rows (groupZclaims (cl₁.map toZClaim) rows lc) lams
      = groupRhosAux rows (groupZclaims (cl₂.map toZClaim) rows lc) lams := by
  have haux : ∀ (gs₁ gs₂ : List (List Fp2 × List (List Fp2 × Fp2))),
      gs₁.map (fun g => (g.1, g.2.map Prod.fst)) = gs₂.map (fun g => (g.1, g.2.map Prod.fst)) →
      ∀ rem : List Fp2, groupRhosAux rows gs₁ rem = groupRhosAux rows gs₂ rem := by
    intro gs₁
    induction gs₁ with
    | nil =>
      intro gs₂ hgs rem
      cases gs₂ with
      | nil => rfl
      | cons _ _ => simp at hgs
    | cons g₁ rest₁ ih =>
      intro gs₂ hgs rem
      cases gs₂ with
      | nil => simp at hgs
      | cons g₂ rest₂ =>
        simp only [List.map_cons, List.cons.injEq, Prod.mk.injEq] at hgs
        obtain ⟨⟨_, hm⟩, hrest⟩ := hgs
        have hlen : g₁.2.length = g₂.2.length := by
          have := congrArg List.length hm; simpa using this
        unfold groupRhosAux
        dsimp only
        rw [hlen, groupComb_fst_eq_of_rws rows hm, ih rest₂ hrest]
  exact haux _ _ (groupZclaims_rw_eq_of_parts rows lc h) lams

open Classical in
/-- Helper recursion for `groupVecsRecon`. -/
noncomputable def groupVecsReconGo (logN : ℕ) (rwVec : List Fp2 → Hiding.Row shdP_K (2 ^ logN) 256) :
    List (List Fp2 × List (List Fp2 × Fp2)) → List Fp2 → List (List Fp2)
  | [], _ => []
  | grp :: rest, rem =>
    let k := grp.2.length
    let ls := rem.take k
    let vec := (List.range (2 ^ logN + 256)).map fun j =>
      ofK shdP_U shdP_hbij ((grp.2.zip ls).map fun p => p.2.toK shdP_U * rowAt (rwVec p.1.1) j).sum
    vec :: groupVecsReconGo logN rwVec rest (rem.drop k)

open Classical in
/-- Reconstruct all grouped PCS vectors (`OpeningZk.vecs`) as a pure function of individual claim
row vectors `claimVec : Fin clRef.length → Row shdP_K (2^logN) 256` and `v`-only data `(clRef, rows, logN, lams)`. -/
noncomputable def groupVecsRecon (rows logN : ℕ) (clRef : List Block.ZClaim) (lams : List Fp2)
    (claimVec : Fin clRef.length → Hiding.Row shdP_K (2 ^ logN) 256) : List (List Fp2) :=
  let rwVec (rw : List Fp2) : Hiding.Row shdP_K (2 ^ logN) 256 :=
    if h : ∃ i : Fin clRef.length, rw = (claimWeights (toZClaim clRef[i.val]) rows logN).1 then
      claimVec h.choose
    else fun _ => 0
  groupVecsReconGo logN rwVec (groupZclaims (clRef.map toZClaim) rows logN) lams

/-- **Exact `OpeningZk.vecs` reconstruction** from individual claim vectors `claimVec`:
matches `(groupRhosAux rows (groupZclaims (cl.map toZClaim) rows logN) lams).map (combVec (2^logN + 256) · T.rows)`
whenever `cl.map ZClaim.parts = clRef.map ZClaim.parts` and every claim `i`'s `combAt` agrees with `claimVec i`. -/
theorem groupRhosAux_combVec_of_claimVecs (rows logN : ℕ) (cl clRef : List Block.ZClaim)
    (hparts : cl.map Block.ZClaim.parts = clRef.map Block.ZClaim.parts)
    (Trows : List (List Fp)) (hTrows : Trows.length = rows)
    (lams : List Fp2)
    (hLamsLen : ((groupZclaims (clRef.map toZClaim) rows logN).map (fun x => x.2.length)).sum = lams.length)
    (claimVec : Fin clRef.length → Hiding.Row shdP_K (2 ^ logN) 256)
    (hClaimVec : ∀ (i : Fin clRef.length) (k : ℕ), k < 2 ^ logN + 256 →
      (combAt (claimWeights (toZClaim clRef[i.val]) rows logN).1 Trows k).toK shdP_U = rowAt (claimVec i) k) :
    (groupRhosAux rows (groupZclaims (cl.map toZClaim) rows logN) lams).map
        (fun rho => combVec (2 ^ logN + 256) rho Trows)
      = groupVecsRecon rows logN clRef lams claimVec := by
  classical
  rw [groupRhosAux_eq_of_parts rows logN hparts lams]
  have hmemAll := groupZclaims_mem_rw_eq rows logN clRef
  let rwVec (rw : List Fp2) : Hiding.Row shdP_K (2 ^ logN) 256 :=
    if h : ∃ i : Fin clRef.length, rw = (claimWeights (toZClaim clRef[i.val]) rows logN).1 then
      claimVec h.choose
    else fun _ => 0
  have hrwVec : ∀ (rw : List Fp2), (∃ i : Fin clRef.length, rw = (claimWeights (toZClaim clRef[i.val]) rows logN).1) →
      ∀ k < 2 ^ logN + 256, (combAt rw Trows k).toK shdP_U = rowAt (rwVec rw) k := by
    intro rw hex k hk
    dsimp only [rwVec]
    rw [dite_eq_left hex]
    exact (congrArg (fun x => (combAt x Trows k).toK shdP_U) hex.choose_spec).trans (hClaimVec hex.choose k hk)
  have hrwLen : ∀ (rw : List Fp2), (∃ i : Fin clRef.length, rw = (claimWeights (toZClaim clRef[i.val]) rows logN).1) →
      rw.length = Trows.length := by
    rintro rw ⟨i, rfl⟩
    rw [claimWeights_length, hTrows]
  have hgo : ∀ (gs : List (List Fp2 × List (List Fp2 × Fp2))) (rem : List Fp2),
      (∀ grp ∈ gs, ∀ m ∈ grp.2, ∃ i : Fin clRef.length, m.1 = (claimWeights (toZClaim clRef[i.val]) rows logN).1) →
      (gs.map (fun x => x.2.length)).sum = rem.length →
      (groupRhosAux rows gs rem).map (fun rho => combVec (2 ^ logN + 256) rho Trows)
        = groupVecsReconGo logN rwVec gs rem := by
    intro gs
    induction gs with
    | nil => intro _ _ _; rfl
    | cons grp rest ih =>
      intro rem hmem hsum
      simp only [List.map_cons, List.sum_cons] at hsum
      unfold groupRhosAux groupVecsReconGo
      simp only [List.map_cons, List.cons.injEq]
      refine ⟨?_, ih (rem.drop grp.2.length) (fun g hg => hmem g (List.mem_cons_of_mem _ hg)) (by simp [List.length_drop]; omega)⟩
      have htakeLen : (rem.take grp.2.length).length = grp.2.length := by
        rw [List.length_take]; omega
      refine List.ext_getElem (by rw [combVec_length, List.length_map, List.length_range]) fun k hk1 hk2 => ?_
      rw [combVec_length] at hk1
      have hget1 : (combVec (2 ^ logN + 256) (groupComb rows grp.2 (rem.take grp.2.length)).1 Trows)[k]'(by rw [combVec_length]; exact hk1)
          = combAt (groupComb rows grp.2 (rem.take grp.2.length)).1 Trows k := by
        have h := combVec_getD (2 ^ logN + 256) (groupComb rows grp.2 (rem.take grp.2.length)).1 Trows k hk1
        rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem (by rw [combVec_length]; exact hk1), Option.getD_some] at h
        exact h
      rw [hget1]
      simp only [List.getElem_map, List.getElem_range]
      have hcan : (combAt (groupComb rows grp.2 (rem.take grp.2.length)).1 Trows k).Canon := by
        have hc := (combVec_canon_len (2 ^ logN + 256) (groupComb rows grp.2 (rem.take grp.2.length)).1 Trows).2
        exact hc _ (by
          rw [← hget1]
          exact List.getElem_mem _)
      refine fp2_eq_ofK hcan ?_
      have hgc := groupComb_combAt_toK Trows k grp.2 (rem.take grp.2.length)
        (fun m hm => hrwLen m.1 (hmem grp List.mem_cons_self m hm)) htakeLen
      rw [hTrows] at hgc
      rw [hgc]
      congr 1
      refine List.map_congr_left fun p hp => ?_
      have hm : p.1 ∈ grp.2 := (List.of_mem_zip hp).1
      rw [hrwVec p.1.1 (hmem grp List.mem_cons_self p.1 hm) k hk1]
  exact hgo (groupZclaims (clRef.map toZClaim) rows logN) lams hmemAll hLamsLen

end GenericGroupAndClaimRecon

/-- Entrywise lookup on `mkRows R n q data pads` for `i < R` and `k < n + q`. -/
theorem mkRows_getD_eq (R n q : ℕ) (data : Fin R → Fin n → Fp) (pads : Fin R → Fin q → Fp)
    (i k : ℕ) (hi : i < R) (hk : k < n + q) :
    ((mkRows R n q data pads).getD i []).getD k Fp.zero =
      if hk1 : k < n then data ⟨i, hi⟩ ⟨k, hk1⟩ else pads ⟨i, hi⟩ ⟨k - n, by omega⟩ := by
  by_cases hk1 : k < n
  · rw [dite_eq_left hk1]
    exact mkRows_data_getD R n q data pads ⟨i, hi⟩ ⟨k, hk1⟩
  · rw [dite_eq_right hk1]
    have hk2 : k - n < q := by omega
    have h := mkRows_pad_getD R n q data pads ⟨i, hi⟩ ⟨k - n, hk2⟩
    rwa [Nat.add_sub_cancel' (Nat.not_lt.mp hk1)] at h

/-! ## 2. Input Endpoint `TE` (`shdP_teSpec`: 6 rows, `logN = 8, lr = 3`) -/

section TePcsView

/-- Pack `TE` data rows (`Fin 2`, where row 0 is token data and row 1 is unused 0), 1 site pair
(rows `1, 2`), and 1 prox pair (rows `3, 4`) into `Fin 6 → Row GF 256 256` matching `shdEpBase`. -/
def teRowOf (dat : Fin 2 → Fin 256 → GF) (c : Hiding.Coins GF 256 256 (Fin 2) (Fin 1))
    (r : Fin 6) : Hiding.Row GF 256 256 :=
  if r.val = 0 then Sum.elim (dat ⟨0, by decide⟩) (c.1 ⟨0, by decide⟩)
  else if r.val = 1 then c.2.1 (⟨0, by decide⟩, true)
  else if r.val = 2 then c.2.1 (⟨0, by decide⟩, false)
  else if r.val = 3 then c.2.2 true
  else if r.val = 4 then c.2.2 false
  else Sum.elim (dat ⟨1, by decide⟩) (c.1 ⟨1, by decide⟩)

/-- Data entries of `TE`: row 0 is `posPlane shdP_epPos x 0`, row 1 is `0`. -/
noncomputable def teDatOf (x : shieldS0.Tok → ℕ) (i : Fin 2) (col : Fin 256) : GF :=
  if i.val = 0 then posPlane shdP_epPos x ⟨0, by decide⟩ col else 0

/-- Exact row-by-row agreement between `shdP_epTable tag x (shdEpBase c)` and `teRowOf`. -/
theorem shdP_epTable_rows_eq {Hdr : Type} (tag : MTag) (x : shieldS0.Tok → ℕ) (c : ShdCoins)
    (r : Fin 6) (k : ℕ) (hk : k < 256 + 256) :
    (((shdP_epTable (Hdr := Hdr) tag x (shdEpBase c)).rows.getD r.val []).getD k Fp.zero).toGF
      = rowAt (teRowOf (teDatOf x) c.1.1.1 r) k := by
  have hrows : (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c)).rows
      = mkRows 6 256 256
          (fun i t => Fp.ofGF (epxMsg 6 1 shdP_epPlace shdP_epPos x (shdEpBase c) i t))
          (fun i p => Fp.ofGF ((shdEpBase c).pads i p)) := rfl
  rw [hrows, mkRows_getD_eq 6 256 256 _ _ r.val k r.isLt hk]
  by_cases hk1 : k < 256
  · rw [dite_eq_left hk1, Fp.toGF_ofGF]
    unfold rowAt
    rw [dite_eq_left hk1]
    rcases r with ⟨r, hr⟩
    interval_cases r
    · have h0 : epxMsg 6 1 shdP_epPlace shdP_epPos x (shdEpBase c) (shdP_epPlace ⟨0, by decide⟩) ⟨k, hk1⟩
          = posPlane shdP_epPos x ⟨0, by decide⟩ ⟨k, hk1⟩ :=
        congrFun (epxMsg_place 6 1 shdP_epPlace shdP_epPos shdP_epPlace_injective x (shdEpBase c) ⟨0, by decide⟩) ⟨k, hk1⟩
      simpa [teRowOf, teDatOf, shdP_epPlace] using h0
    · simp [epxMsg, shdP_epPlace, shdEpBase, teRowOf, rowMsg]; rfl
    · simp [epxMsg, shdP_epPlace, shdEpBase, teRowOf, rowMsg]; rfl
    · simp [epxMsg, shdP_epPlace, shdEpBase, teRowOf, rowMsg]; rfl
    · simp [epxMsg, shdP_epPlace, shdEpBase, teRowOf, rowMsg]; rfl
    · simp [epxMsg, shdP_epPlace, shdEpBase, teRowOf, teDatOf]
  · have hk2 : k - 256 < 256 := by omega
    rw [dite_eq_right hk1, Fp.toGF_ofGF]
    unfold rowAt
    rw [dite_eq_right hk1, dite_eq_left hk2]
    rcases r with ⟨r, hr⟩
    interval_cases r <;> (simp [shdEpBase, teRowOf]; try rfl)

theorem teClaim_combAt_eq_view {kOpen : ℕ} {E : Matrix (Fin kOpen) (Fin 256 ⊕ Fin 256) GF}
    (ω : Hiding.Weights shdP_K (Fin 2) (Fin 1))
    (dat : Fin 2 → Fin 256 → GF) (c : Hiding.Coins GF 256 256 (Fin 2) (Fin 1))
    (rows : List (List Fp)) (hrowsLen : rows.length = 6)
    (hrowsEq : ∀ (r : Fin 6) (k : ℕ), k < 256 + 256 →
      ((rows.getD r.val []).getD k Fp.zero).toGF = rowAt (teRowOf dat c r) k)
    (rw : List Fp2) (hrwLen : rw.length = 6)
    (hw0 : (rw.getD 0 Fp2.zero).toK shdP_U = ω.wD 0 0)
    (hw1 : (rw.getD 1 Fp2.zero).toK shdP_U = ω.a 0)
    (hw2 : (rw.getD 2 Fp2.zero).toK shdP_U = ω.b 0)
    (hw3 : (rw.getD 3 Fp2.zero).toK shdP_U = 0)
    (hw4 : (rw.getD 4 Fp2.zero).toK shdP_U = 0)
    (hw5 : (rw.getD 5 Fp2.zero).toK shdP_U = ω.wD 0 1)
    (k : ℕ) (hk : k < 256 + 256) :
    (combAt rw rows k).toK shdP_U = rowAt ((Hiding.openingView E ω dat c).1 0) k := by
  rw [toK_combAt shdP_U rw rows (by rw [hrwLen, hrowsLen]) k, hrowsLen, Finset.sum_range]
  rw [Fin.sum_univ_six, hrowsEq 0 k hk, hrowsEq 1 k hk, hrowsEq 2 k hk, hrowsEq 5 k hk]
  simp only [Fin.val_zero, Fin.val_one, Fin.val_two, Fin.isValue,
    show (3 : Fin 6).val = 3 from rfl, show (4 : Fin 6).val = 4 from rfl, show (5 : Fin 6).val = 5 from rfl]
  rw [hw0, hw1, hw2, hw3, hw4, hw5, zero_mul, zero_mul, add_zero, add_zero]
  unfold Hiding.openingView teRowOf rowAt
  dsimp only
  by_cases h1 : k < 256
  · simp only [h1, ↓reduceDIte, ↓reduceIte, Fin.sum_univ_two, Fin.val_zero, Fin.val_one, Fin.val_two, Fin.isValue,
      show (5 : Fin 6).val = 5 from rfl,
      show (1 : ℕ) ≠ 0 by decide, show (2 : ℕ) ≠ 0 by decide, show (2 : ℕ) ≠ 1 by decide,
      show (5 : ℕ) ≠ 0 by omega, show (5 : ℕ) ≠ 1 by omega, show (5 : ℕ) ≠ 2 by omega,
      show (5 : ℕ) ≠ 3 by omega, show (5 : ℕ) ≠ 4 by omega,
      show (⟨0, by decide⟩ : Fin 2) = 0 from rfl, show (⟨1, by decide⟩ : Fin 2) = 1 from rfl,
      show (⟨0, by decide⟩ : Fin 1) = 0 from rfl]
    ring
  · have h2 : k - 256 < 256 := by omega
    simp only [h1, h2, ↓reduceDIte, ↓reduceIte, Fin.sum_univ_two, Fin.val_zero, Fin.val_one, Fin.val_two, Fin.isValue,
      show (5 : Fin 6).val = 5 from rfl,
      show (1 : ℕ) ≠ 0 by decide, show (2 : ℕ) ≠ 0 by decide, show (2 : ℕ) ≠ 1 by decide,
      show (5 : ℕ) ≠ 0 by omega, show (5 : ℕ) ≠ 1 by omega, show (5 : ℕ) ≠ 2 by omega,
      show (5 : ℕ) ≠ 3 by omega, show (5 : ℕ) ≠ 4 by omega,
      show (⟨0, by decide⟩ : Fin 2) = 0 from rfl, show (⟨1, by decide⟩ : Fin 2) = 1 from rfl,
      show (⟨0, by decide⟩ : Fin 1) = 0 from rfl]
    ring

theorem teProx_combAt_eq_view {kOpen : ℕ} {E : Matrix (Fin kOpen) (Fin 256 ⊕ Fin 256) GF}
    (ω : Hiding.Weights shdP_K (Fin 2) (Fin 1))
    (dat : Fin 2 → Fin 256 → GF) (c : Hiding.Coins GF 256 256 (Fin 2) (Fin 1))
    (rows : List (List Fp)) (hrowsLen : rows.length = 6)
    (hrowsEq : ∀ (r : Fin 6) (k : ℕ), k < 256 + 256 →
      ((rows.getD r.val []).getD k Fp.zero).toGF = rowAt (teRowOf dat c r) k)
    (proxRho : List Fp2) (hproxLen : proxRho.length = 6)
    (hp0 : (proxRho.getD 0 Fp2.zero).toK shdP_U = ω.pD 0)
    (hp1 : (proxRho.getD 1 Fp2.zero).toK shdP_U = ω.pG (0, true))
    (hp2 : (proxRho.getD 2 Fp2.zero).toK shdP_U = ω.pG (0, false))
    (hp3 : (proxRho.getD 3 Fp2.zero).toK shdP_U = ω.pa)
    (hp4 : (proxRho.getD 4 Fp2.zero).toK shdP_U = ω.pb)
    (hp5 : (proxRho.getD 5 Fp2.zero).toK shdP_U = ω.pD 1)
    (k : ℕ) (hk : k < 256 + 256) :
    (combAt proxRho rows k).toK shdP_U = rowAt ((Hiding.openingView E ω dat c).2.1) k := by
  rw [toK_combAt shdP_U proxRho rows (by rw [hproxLen, hrowsLen]) k, hrowsLen, Finset.sum_range]
  rw [Fin.sum_univ_six,
    hrowsEq 0 k hk, hrowsEq 1 k hk, hrowsEq 2 k hk, hrowsEq 3 k hk, hrowsEq 4 k hk, hrowsEq 5 k hk]
  simp only [Fin.val_zero, Fin.val_one, Fin.val_two, Fin.isValue,
    show (3 : Fin 6).val = 3 from rfl, show (4 : Fin 6).val = 4 from rfl, show (5 : Fin 6).val = 5 from rfl]
  rw [hp0, hp1, hp2, hp3, hp4, hp5]
  unfold Hiding.openingView teRowOf rowAt
  dsimp only
  by_cases h1 : k < 256
  · simp only [h1, ↓reduceDIte, ↓reduceIte, Fin.sum_univ_two, Fintype.sum_prod_type, Fin.sum_univ_one, Fintype.sum_bool,
      Fin.val_zero, Fin.val_one, Fin.val_two, Fin.isValue,
      show (3 : Fin 6).val = 3 from rfl, show (4 : Fin 6).val = 4 from rfl, show (5 : Fin 6).val = 5 from rfl,
      show (1 : ℕ) ≠ 0 by decide, show (2 : ℕ) ≠ 0 by decide, show (2 : ℕ) ≠ 1 by decide,
      show (3 : ℕ) ≠ 0 by omega, show (3 : ℕ) ≠ 1 by omega, show (3 : ℕ) ≠ 2 by omega,
      show (4 : ℕ) ≠ 0 by omega, show (4 : ℕ) ≠ 1 by omega, show (4 : ℕ) ≠ 2 by omega, show (4 : ℕ) ≠ 3 by omega,
      show (5 : ℕ) ≠ 0 by omega, show (5 : ℕ) ≠ 1 by omega, show (5 : ℕ) ≠ 2 by omega, show (5 : ℕ) ≠ 3 by omega, show (5 : ℕ) ≠ 4 by omega,
      show (⟨0, by decide⟩ : Fin 2) = 0 from rfl, show (⟨1, by decide⟩ : Fin 2) = 1 from rfl,
      show (⟨0, by decide⟩ : Fin 1) = 0 from rfl]
    ring
  · have h2 : k - 256 < 256 := by omega
    simp only [h1, h2, ↓reduceDIte, ↓reduceIte, Fin.sum_univ_two, Fintype.sum_prod_type, Fin.sum_univ_one, Fintype.sum_bool,
      Fin.val_zero, Fin.val_one, Fin.val_two, Fin.isValue,
      show (3 : Fin 6).val = 3 from rfl, show (4 : Fin 6).val = 4 from rfl, show (5 : Fin 6).val = 5 from rfl,
      show (1 : ℕ) ≠ 0 by decide, show (2 : ℕ) ≠ 0 by decide, show (2 : ℕ) ≠ 1 by decide,
      show (3 : ℕ) ≠ 0 by omega, show (3 : ℕ) ≠ 1 by omega, show (3 : ℕ) ≠ 2 by omega,
      show (4 : ℕ) ≠ 0 by omega, show (4 : ℕ) ≠ 1 by omega, show (4 : ℕ) ≠ 2 by omega, show (4 : ℕ) ≠ 3 by omega,
      show (5 : ℕ) ≠ 0 by omega, show (5 : ℕ) ≠ 1 by omega, show (5 : ℕ) ≠ 2 by omega, show (5 : ℕ) ≠ 3 by omega, show (5 : ℕ) ≠ 4 by omega,
      show (⟨0, by decide⟩ : Fin 2) = 0 from rfl, show (⟨1, by decide⟩ : Fin 2) = 1 from rfl,
      show (⟨0, by decide⟩ : Fin 1) = 0 from rfl]
    ring

/-- Reconstruct a 6-row `TE` column at deduplicated opened index `q` from `Hiding.View`. -/
def teColFromView {kOpen : ℕ} (vw : Hiding.View GF shdP_K 256 256 kOpen (Fin 2) (Fin 1))
    (q : Fin kOpen) : List Fp :=
  [Fp.ofGF (vw.2.2.1 0 q), Fp.ofGF (vw.2.2.2.1 (0, true) q), Fp.ofGF (vw.2.2.2.1 (0, false) q),
   Fp.ofGF (vw.2.2.2.2 true q), Fp.ofGF (vw.2.2.2.2 false q), Fp.ofGF (vw.2.2.1 1 q)]

theorem teCol_eq_view {kOpen : ℕ} (idx : Fin kOpen → Fin (2 ^ 11))
    (ω : Hiding.Weights shdP_K (Fin 2) (Fin 1))
    (dat : Fin 2 → Fin 256 → GF) (c : Hiding.Coins GF 256 256 (Fin 2) (Fin 1))
    (T : Table) (hrowsLen : T.rows.length = 6)
    (hrowsEq : ∀ (r : Fin 6) (k : ℕ), k < 256 + 256 →
      ((T.rows.getD r.val []).getD k Fp.zero).toGF = rowAt (teRowOf dat c r) k)
    (hcols : ColsHonest shdP_U (lagK 8 (by norm_num)) 256 (cosetPt (rootFp 11)) (2 ^ 8 * 2 ^ 3) T)
    (hcan : ∀ j, ∀ x ∈ T.cols j, x.Canon) (q : Fin kOpen) :
    T.cols (idx q).val = teColFromView (Hiding.openingView (pcsEvalMat 8 3 (by norm_num) idx) ω dat c) q := by
  have hltN : (idx q).val < 2 ^ 8 * 2 ^ 3 := (idx q).isLt
  have hclen : (T.cols (idx q).val).length = 6 := by rw [(hcols (idx q).val hltN).1, hrowsLen]
  refine List.ext_getElem (by rw [hclen]; rfl) fun i hi1 hi2 => ?_
  rw [hclen] at hi1
  have hget : (T.cols (idx q).val)[i]'(by rw [hclen]; exact hi1) = (T.cols (idx q).val).getD i Fp.zero := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem (by rw [hclen]; exact hi1), Option.getD_some]
  rw [hget, colsHonest_col_eq_evalMat 8 3 (by norm_num) idx T hcols hcan i (by omega) q]
  have hrowElim : ∀ (r : Fin 6) (u : Fin (2 ^ 8) ⊕ Fin 256),
      Sum.elim (fun col : Fin (2 ^ 8) => ((T.rows.getD r.val []).getD col.val Fp.zero).toGF)
        (fun l : Fin 256 => ((T.rows.getD r.val []).getD (2 ^ 8 + l.val) Fp.zero).toGF) u
        = teRowOf dat c r u := by
    intro r u
    cases u with
    | inl col =>
      have h := hrowsEq r col.val (by have := col.isLt; omega)
      unfold rowAt at h; rw [dite_eq_left (by have := col.isLt; omega)] at h; exact h
    | inr l =>
      have h := hrowsEq r (256 + l.val) (by have := l.isLt; omega)
      unfold rowAt at h
      rw [dite_eq_right (by omega), dite_eq_left (by omega)] at h
      simpa using h
  have he := hrowElim ⟨i, hi1⟩
  have hfin : i = 0 ∨ i = 1 ∨ i = 2 ∨ i = 3 ∨ i = 4 ∨ i = 5 := by omega
  rcases hfin with rfl | rfl | rfl | rfl | rfl | rfl <;> (
    simp only [teColFromView, List.getElem_cons_zero, List.getElem_cons_succ, Hiding.openingView]
    apply congrArg Fp.ofGF
    refine Finset.sum_congr rfl fun u _ => ?_
    rw [he u]; rfl)

/-- Build `PcsStdData` for `TE` (`shdP_teSpec`) from `v`-only audited claim `c0` and `proxR`. -/
noncomputable def tePcsData_of_audit {Dt : Type} (idxs : List ℕ) (hIdxsLen : idxs.length = 256)
    (hIdxsLt : ∀ j ∈ idxs, j < 2 ^ 11) (c0 : Block.ZClaim)
    (hab : LinearIndependent GF ![(claimWeight 8 c0 1).toK shdP_U, (claimWeight 8 c0 2).toK shdP_U])
    (proxR : List Fp2) (hDet : (Exec.Block.det (proxR.getD 3 Fp2.zero) (proxR.getD 4 Fp2.zero)).v ≠ 0)
    (dat : Dt → Fin 2 → Fin 256 → GF) :
    PcsStdData GF shdP_K Dt shdP_teSpec (nodupCols idxs).length where
  E := pcsEvalMat 8 3 (by norm_num) (dedupIdx idxs hIdxsLt)
  ω :=
    { wD := fun _ i => if i.val = 0 then (claimWeight 8 c0 0).toK shdP_U else (claimWeight 8 c0 5).toK shdP_U
      a := fun _ => (claimWeight 8 c0 1).toK shdP_U
      b := fun _ => (claimWeight 8 c0 2).toK shdP_U
      pD := fun i => if i.val = 0 then (proxR.getD 0 Fp2.zero).toK shdP_U else (proxR.getD 5 Fp2.zero).toK shdP_U
      pG := fun gs => (proxR.getD (if gs.2 then 1 else 2) Fp2.zero).toK shdP_U
      pa := (proxR.getD 3 Fp2.zero).toK shdP_U
      pb := (proxR.getD 4 Fp2.zero).toK shdP_U }
  d := dat
  hab := fun _ => hab
  hp := shdP_proxPair_linInd_of_fp2Det (proxR.getD 3 Fp2.zero) (proxR.getD 4 Fp2.zero) hDet
  hE := pcsEvalMat_padSurj 8 3 (by norm_num) (by rw [← hIdxsLen]; exact nodupCols_length_le idxs)
    (dedupIdx idxs hIdxsLt) (dedupIdx_injective idxs hIdxsLt)

/-- `TE` claim vector matches `Hiding.openingView.1 0` under `tokenEpHdrOk [c0] 1 256 = true`. -/
theorem teClaim_combAt_eq_of_hdr {Dt : Type} (idxs : List ℕ) (hIdxsLen : idxs.length = 256)
    (hIdxsLt : ∀ j ∈ idxs, j < 2 ^ 11) (c0 : Block.ZClaim)
    (hhdr : tokenEpHdrOk [c0] 1 256 = true)
    (hab : LinearIndependent GF ![(claimWeight 8 c0 1).toK shdP_U, (claimWeight 8 c0 2).toK shdP_U])
    (proxR : List Fp2) (hDet : (Exec.Block.det (proxR.getD 3 Fp2.zero) (proxR.getD 4 Fp2.zero)).v ≠ 0)
    (dat : Dt → Fin 2 → Fin 256 → GF) (y : Dt) (c : PcsStdCoins GF shdP_teSpec)
    (Trows : List (List Fp)) (hTrows : Trows.length = 6)
    (hrowsEq : ∀ (r : Fin 6) (k : ℕ), k < 256 + 256 →
      ((Trows.getD r.val []).getD k Fp.zero).toGF = rowAt (teRowOf (dat y) c.1 r) k)
    (k : ℕ) (hk : k < 256 + 256) :
    (combAt (claimWeights (toZClaim c0) 6 8).1 Trows k).toK shdP_U =
      rowAt (((tePcsData_of_audit idxs hIdxsLen hIdxsLt c0 hab proxR hDet dat).view y c).1.1 (0 : Fin 1)) k := by
  have hcw : ∀ r < 6, ((claimWeights (toZClaim c0) 6 8).1.getD r Fp2.zero).toK shdP_U = (claimWeight 8 c0 r).toK shdP_U :=
    fun r hr => claimWeights_getD_toK c0 6 8 r hr
  have h034 : (claimWeight 8 c0 3).toK shdP_U = 0 ∧ (claimWeight 8 c0 4).toK shdP_U = 0 := by
    unfold tokenEpHdrOk at hhdr
    dsimp only at hhdr
    cases hp : c0.parts with
    | nil => rw [hp] at hhdr; cases hhdr
    | cons p0 r0 =>
      cases r0 with
      | nil => rw [hp] at hhdr; cases hhdr
      | cons p1 r1 =>
        cases r1 with
        | nil => rw [hp] at hhdr; cases hhdr
        | cons p2 r2 =>
          cases r2 with
          | cons _ _ => rw [hp] at hhdr; cases hhdr
          | nil =>
            rw [hp] at hhdr
            have hdec := of_decide_eq_true hhdr
            obtain ⟨hp0, hp1, hp2, _⟩ := hdec
            have hhi : ∀ q ∈ c0.parts, partHi q (2 ^ 8) ≤ 3 := by
              intro q hq
              rw [hp] at hq
              have hpartHi : ∀ p : Block.ZPart, partHi p 256 = (Exec.StageV.partRows p 256).2 := fun _ => rfl
              rcases List.mem_cons.mp hq with rfl | hq
              · rw [show (2 ^ 8 : ℕ) = 256 by norm_num, hpartHi, hp0]; norm_num
              · rcases List.mem_cons.mp hq with rfl | hq
                · rw [show (2 ^ 8 : ℕ) = 256 by norm_num, hpartHi, hp1]; norm_num
                · rcases List.mem_cons.mp hq with rfl | hq
                  · rw [show (2 ^ 8 : ℕ) = 256 by norm_num, hpartHi, hp2]
                  · cases hq
            exact ⟨claimWeight_zero_of_ge_prox 8 3 c0 3 hhi (by omega),
                   claimWeight_zero_of_ge_prox 8 3 c0 4 hhi (by omega)⟩
  exact teClaim_combAt_eq_view _ (dat y) c.1 Trows hTrows hrowsEq
    (claimWeights (toZClaim c0) 6 8).1 (claimWeights_length _ 6 8)
    (hcw 0 (by omega)) (hcw 1 (by omega)) (hcw 2 (by omega))
    ((hcw 3 (by omega)).trans h034.1) ((hcw 4 (by omega)).trans h034.2) (hcw 5 (by omega)) k hk

/-- Pure view-and-`v` reconstruction of `TE`'s `Exec.Block.OpeningZk`. -/
noncomputable def teOpenRecon (idxs : List ℕ) (hIdxsLt : ∀ j ∈ idxs, j < 2 ^ 11)
    (c0 : Block.ZClaim) (lams : List Fp2) (tree : MerkleLevels 11)
    (vw : PcsStdView GF shdP_K shdP_teSpec (nodupCols idxs).length) : Exec.Block.OpeningZk :=
  let vecs := groupVecsRecon 6 8 [c0] lams (fun _ => vw.1.1 (0 : Fin 1))
  let prox := (List.range (256 + 256)).map fun k => ofK shdP_U shdP_hbij (rowAt vw.1.2.1 k)
  let cols := idxs.attach.map fun ⟨j, hj⟩ =>
    ofOCol (j, teColFromView vw.1 (dedupFind idxs j hj), vw.2 ⟨j, hIdxsLt j hj⟩, tree.pathD j)
  ⟨vecs, prox, cols⟩

/-- Exact `openingAuditFixedProg` reconstruction for `TE` from `PcsStdView` + `v`. -/
theorem teOpen_of_view {Dt : Type} (idxs : List ℕ) (hIdxsLen : idxs.length = 256)
    (hIdxsLt : ∀ j ∈ idxs, j < 2 ^ 11) (cl : List Block.ZClaim) (c0 : Block.ZClaim)
    (hparts : cl.map Block.ZClaim.parts = [c0].map Block.ZClaim.parts)
    (hhdr : tokenEpHdrOk [c0] 1 256 = true)
    (hab : LinearIndependent GF ![(claimWeight 8 c0 1).toK shdP_U, (claimWeight 8 c0 2).toK shdP_U])
    (lams proxR : List Fp2) (hLamsLen : lams.length = 1) (hProxLen : proxR.length = 6)
    (hDet : (Exec.Block.det (proxR.getD 3 Fp2.zero) (proxR.getD 4 Fp2.zero)).v ≠ 0)
    (dat : Dt → Fin 2 → Fin 256 → GF) (y : Dt) (c : PcsStdCoins GF shdP_teSpec)
    (T : Table) (hTrows : T.rows.length = 6)
    (hrowsEq : ∀ (r : Fin 6) (k : ℕ), k < 256 + 256 →
      ((T.rows.getD r.val []).getD k Fp.zero).toGF = rowAt (teRowOf (dat y) c.1 r) k)
    (hcols : ColsHonest shdP_U (lagK 8 (by norm_num)) 256 (cosetPt (rootFp 11)) (2 ^ 8 * 2 ^ 3) T)
    (hcan : ∀ j, ∀ x ∈ T.cols j, x.Canon)
    (hsalts : ∀ j (hj : j < 2 ^ 11), T.salts j = c.2 ⟨j, hj⟩)
    (tree : MerkleLevels 11) :
    let D := tePcsData_of_audit idxs hIdxsLen hIdxsLt c0 hab proxR hDet dat
    let vecs := (groupRhosAux 6 (pGroups shdP_epPrm T (cl.map toZClaim)) lams).map
      (fun rho => combVec (shdP_epPrm.n + shdP_epPrm.qPad) rho T.rows)
    let prox := combVec (shdP_epPrm.n + shdP_epPrm.qPad) proxR T.rows
    let cols := idxs.map (fun j => ofOCol (j, T.cols j, T.salts j, tree.pathD j))
    (⟨vecs, prox, cols⟩ : Exec.Block.OpeningZk) = teOpenRecon idxs hIdxsLt c0 lams tree (D.view y c) := by
  intro D vecs prox cols
  have hgsSum : ((groupZclaims ([c0].map toZClaim) 6 8).map (fun x => x.2.length)).sum = lams.length := by
    rw [hLamsLen]; rfl
  have hV : vecs = groupVecsRecon 6 8 [c0] lams (fun _ => (D.view y c).1.1 (0 : Fin 1)) := by
    dsimp only [vecs, pGroups]
    rw [hTrows]
    exact groupRhosAux_combVec_of_claimVecs 6 8 cl [c0] hparts T.rows hTrows lams hgsSum
      (fun _ => (D.view y c).1.1 (0 : Fin 1))
      (fun i k hk => by
        have hi : i.val = 0 := Nat.lt_one_iff.mp i.isLt
        simp only [hi, List.getElem_cons_zero]
        exact teClaim_combAt_eq_of_hdr idxs hIdxsLen hIdxsLt c0 hhdr hab proxR hDet dat y c T.rows hTrows hrowsEq k hk)
  have hP : prox = (List.range (256 + 256)).map fun k => ofK shdP_U shdP_hbij (rowAt (D.view y c).1.2.1 k) := by
    refine List.ext_getElem (by rw [combVec_length, List.length_map, List.length_range]; rfl) fun k hk1 hk2 => ?_
    rw [combVec_length] at hk1
    have hget : (combVec (shdP_epPrm.n + shdP_epPrm.qPad) proxR T.rows)[k]'(by rw [combVec_length]; exact hk1)
        = combAt proxR T.rows k := by
      have h := combVec_getD (shdP_epPrm.n + shdP_epPrm.qPad) proxR T.rows k hk1
      rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem (by rw [combVec_length]; exact hk1), Option.getD_some] at h
      exact h
    dsimp only [prox]
    rw [hget]
    simp only [List.getElem_map, List.getElem_range]
    have hcanK : (combAt proxR T.rows k).Canon :=
      (combVec_canon_len (shdP_epPrm.n + shdP_epPrm.qPad) proxR T.rows).2 _ (by rw [← hget]; exact List.getElem_mem _)
    refine fp2_eq_ofK hcanK ?_
    exact teProx_combAt_eq_view D.ω (dat y) c.1 T.rows hTrows hrowsEq proxR hProxLen
      rfl rfl rfl rfl rfl rfl k hk1
  have hC : cols = idxs.attach.map fun ⟨j, hj⟩ =>
      ofOCol (j, teColFromView (D.view y c).1 (dedupFind idxs j hj), (D.view y c).2 ⟨j, hIdxsLt j hj⟩, tree.pathD j) := by
    dsimp only [cols]
    rw [← List.attach_map_val]
    refine List.map_congr_left fun ⟨j, hj⟩ _ => ?_
    have hjEq := dedupIdx_dedupFind idxs hIdxsLt j hj
    have hcol := teCol_eq_view (dedupIdx idxs hIdxsLt) D.ω (dat y) c.1 T hTrows hrowsEq hcols hcan (dedupFind idxs j hj)
    rw [hjEq] at hcol
    rw [hcol, hsalts j (hIdxsLt j hj)]
    rfl
  unfold teOpenRecon
  rw [hV, hP, hC]

end TePcsView

/-! ## 3. Standard PCS Tables (`B_0..26`, `A_0..27`) -/

section StdPcsView

/-- Reconstruct a `(d + 2*g + 2)`-row standard PCS column at deduplicated index `q` from `Hiding.View`. -/
def stdColFromView {n d g kOpen : ℕ} (vw : Hiding.View GF shdP_K n 256 kOpen (Fin d) (Fin g))
    (q : Fin kOpen) : List Fp :=
  (List.range (d + 2 * g + 2)).map fun r =>
    if h1 : r < d then Fp.ofGF (vw.2.2.1 ⟨r, h1⟩ q)
    else if h2 : r < d + 2 * g then
      Fp.ofGF (vw.2.2.2.1 (⟨(r - d) / 2, by omega⟩, decide ((r - d) % 2 = 0)) q)
    else Fp.ofGF (vw.2.2.2.2 (decide (r = d + 2 * g)) q)

theorem stdCol_eq_view {logN lr d g kOpen : ℕ} (hkl : logN + lr ≤ 31)
    (idx : Fin kOpen → Fin (2 ^ (logN + lr)))
    (ω : Hiding.Weights shdP_K (Fin d) (Fin g))
    (dat : Fin d → Fin (2 ^ logN) → GF) (c : Hiding.Coins GF (2 ^ logN) 256 (Fin d) (Fin g))
    (T : Table) (hrowsLen : T.rows.length = d + 2 * g + 2)
    (hrowsEq : ∀ (r : Fin (d + 2 * g + 2)) (k : ℕ), k < 2 ^ logN + 256 →
      ((T.rows.getD r.val []).getD k Fp.zero).toGF = rowAt (stdRowOf dat c r) k)
    (hcols : ColsHonest shdP_U (lagK logN (by omega)) 256 (cosetPt (rootFp (logN + lr))) (2 ^ logN * 2 ^ lr) T)
    (hcan : ∀ j, ∀ x ∈ T.cols j, x.Canon) (q : Fin kOpen) :
    T.cols (idx q).val = stdColFromView (Hiding.openingView (pcsEvalMat logN lr hkl idx) ω dat c) q := by
  have hltN : (idx q).val < 2 ^ logN * 2 ^ lr := by rw [← pow_add]; exact (idx q).isLt
  have hclen : (T.cols (idx q).val).length = d + 2 * g + 2 := by rw [(hcols (idx q).val hltN).1, hrowsLen]
  refine List.ext_getElem (by rw [hclen, stdColFromView, List.length_map, List.length_range]) fun i hi1 hi2 => ?_
  rw [hclen] at hi1
  have hget : (T.cols (idx q).val)[i]'(by rw [hclen]; exact hi1) = (T.cols (idx q).val).getD i Fp.zero := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem (by rw [hclen]; exact hi1), Option.getD_some]
  rw [hget, colsHonest_col_eq_evalMat logN lr hkl idx T hcols hcan i (by omega) q]
  simp only [stdColFromView, List.getElem_map, List.getElem_range]
  have hrowElim :
      Sum.elim (fun col : Fin (2 ^ logN) => ((T.rows.getD i []).getD col.val Fp.zero).toGF)
        (fun l : Fin 256 => ((T.rows.getD i []).getD (2 ^ logN + l.val) Fp.zero).toGF)
        = stdRowOf dat c ⟨i, hi1⟩ := by
    funext u
    cases u with
    | inl col =>
      have h := hrowsEq ⟨i, hi1⟩ col.val (by omega)
      unfold rowAt at h; rw [dite_eq_left col.isLt] at h; exact h
    | inr l =>
      have h := hrowsEq ⟨i, hi1⟩ (2 ^ logN + l.val) (by omega)
      unfold rowAt at h
      rw [dite_eq_right (by omega), dite_eq_left (by omega)] at h
      simpa using h
  rw [hrowElim]
  unfold stdRowOf Hiding.openingView
  dsimp only
  split_ifs <;> rfl

/-- Standard `PcsTableSpec` with `n = 2^logN, Q = 256, Dat = Fin d, Γ = Fin g, Salt = Fin (2^(logN+lr)) → Dig`. -/
def mkStdSpec (logN lr d g : ℕ) : PcsTableSpec where
  n := 2 ^ logN
  Q := 256
  Dat := Fin d
  Γ := Fin g
  Salt := Fin (2 ^ (logN + lr)) → Dig

/-- Build `PcsStdData` for ANY audited standard PCS table (`B_0..26`, `A_0..27`) from `v`-only
`auditClaims ... none ... = .ok ()` and `openingAuditOk` determinant check! -/
noncomputable def stdPcsData_of_audit {Dt : Type} (logN lr d g : ℕ) (hkl : logN + lr ≤ 31)
    (idxs : List ℕ) (hIdxsLen : idxs.length = 256) (hIdxsLt : ∀ j ∈ idxs, j < 2 ^ (logN + lr))
    (cl : List Block.ZClaim)
    (haud : auditClaims cl (2 ^ logN) (d + 2 * g + 2) (List.range' d (2 * g)) none (d + 2 * g) = .ok ())
    (proxR : List Fp2)
    (hDet : (Exec.Block.det (proxR.getD (d + 2 * g) Fp2.zero) (proxR.getD (d + 2 * g + 1) Fp2.zero)).v ≠ 0)
    (dat : Dt → Fin d → Fin (2 ^ logN) → GF) :
    PcsStdData GF shdP_K Dt (mkStdSpec logN lr d g) (nodupCols idxs).length := by
  classical
  have hbij := auditClaims_std_bijection logN d g (d + 2 * g) (d + 2 * g + 2) le_rfl rfl cl haud
  let perm : Fin g ≃ Fin cl.length := hbij.choose_spec.choose
  exact
    { E := pcsEvalMat logN lr hkl (dedupIdx idxs hIdxsLt)
      ω :=
        { wD := fun p i => (claimWeight logN cl[(perm p).val] i.val).toK shdP_U
          a := fun p => (claimWeight logN cl[(perm p).val] (d + 2 * p.val)).toK shdP_U
          b := fun p => (claimWeight logN cl[(perm p).val] (d + 2 * p.val + 1)).toK shdP_U
          pD := fun i => (proxR.getD i.val Fp2.zero).toK shdP_U
          pG := fun gs => (proxR.getD (d + 2 * gs.1.val + if gs.2 then 0 else 1) Fp2.zero).toK shdP_U
          pa := (proxR.getD (d + 2 * g) Fp2.zero).toK shdP_U
          pb := (proxR.getD (d + 2 * g + 1) Fp2.zero).toK shdP_U }
      d := dat
      hab := fun p => (hbij.choose_spec.choose_spec p).2.2
      hp := shdP_proxPair_linInd_of_fp2Det _ _ hDet
      hE := pcsEvalMat_padSurj logN lr hkl (by rw [← hIdxsLen]; exact nodupCols_length_le idxs)
        (dedupIdx idxs hIdxsLt) (dedupIdx_injective idxs hIdxsLt) }

private theorem list_getElem_eq_of_idx {α : Type*} (l : List α) {i j : ℕ}
    (hi : i < l.length) (hj : j < l.length) (h : i = j) : l[i]'hi = l[j]'hj := by
  subst h; rfl

/-- The `Fin g ≃ Fin cl.length` claim-to-site-pair permutation extracted from `auditClaims_std_bijection`. -/
noncomputable def stdAuditPerm (logN d g : ℕ) (cl : List Block.ZClaim)
    (haud : auditClaims cl (2 ^ logN) (d + 2 * g + 2) (List.range' d (2 * g)) none (d + 2 * g) = .ok ()) :
    Fin g ≃ Fin cl.length :=
  (auditClaims_std_bijection logN d g (d + 2 * g) (d + 2 * g + 2) le_rfl rfl cl haud).choose_spec.choose

/-- Every claim `i : Fin cl.length` of an audited standard PCS table has `combAt` matching
`(stdPcsData_of_audit ...).view.1.1 (perm.symm i)` at every `k < 2^logN + 256`! -/
theorem stdClaim_combAt_eq_of_audit {Dt : Type} (logN lr d g : ℕ) (hkl : logN + lr ≤ 31)
    (idxs : List ℕ) (hIdxsLen : idxs.length = 256) (hIdxsLt : ∀ j ∈ idxs, j < 2 ^ (logN + lr))
    (cl : List Block.ZClaim)
    (haud : auditClaims cl (2 ^ logN) (d + 2 * g + 2) (List.range' d (2 * g)) none (d + 2 * g) = .ok ())
    (proxR : List Fp2)
    (hDet : (Exec.Block.det (proxR.getD (d + 2 * g) Fp2.zero) (proxR.getD (d + 2 * g + 1) Fp2.zero)).v ≠ 0)
    (dat : Dt → Fin d → Fin (2 ^ logN) → GF) (y : Dt) (c : PcsStdCoins GF (mkStdSpec logN lr d g))
    (Trows : List (List Fp)) (hTrows : Trows.length = d + 2 * g + 2)
    (hrowsEq : ∀ (r : Fin (d + 2 * g + 2)) (k : ℕ), k < 2 ^ logN + 256 →
      ((Trows.getD r.val []).getD k Fp.zero).toGF = rowAt (stdRowOf (dat y) c.1 r) k)
    (i : Fin cl.length) (k : ℕ) (hk : k < 2 ^ logN + 256) :
    let D := stdPcsData_of_audit logN lr d g hkl idxs hIdxsLen hIdxsLt cl haud proxR hDet dat
    let perm := stdAuditPerm logN d g cl haud
    (combAt (claimWeights (toZClaim cl[i.val]) (d + 2 * g + 2) logN).1 Trows k).toK shdP_U
      = rowAt ((D.view y c).1.1 (perm.symm i)) k := by
  intro D perm
  set p : Fin g := perm.symm i
  have hpi : perm p = i := perm.apply_symm_apply i
  have hspec := (auditClaims_std_bijection logN d g (d + 2 * g) (d + 2 * g + 2) le_rfl rfl cl haud).choose_spec.choose_spec p
  have hpiVal : (perm p).val = i.val := congrArg Fin.val hpi
  have hclEq : cl[(perm p).val] = cl[i.val] := list_getElem_eq_of_idx cl _ _ hpiVal
  have hcw : ∀ r < d + 2 * g + 2,
      ((claimWeights (toZClaim cl[i.val]) (d + 2 * g + 2) logN).1.getD r Fp2.zero).toK shdP_U
        = (claimWeight logN cl[i.val] r).toK shdP_U :=
    fun r hr => claimWeights_getD_toK cl[i.val] (d + 2 * g + 2) logN r hr
  refine stdClaim_combAt_eq_view D.ω (dat y) c.1 Trows hTrows hrowsEq
    (claimWeights (toZClaim cl[i.val]) (d + 2 * g + 2) logN).1 (claimWeights_length _ _ _) p ?_ ?_ ?_ k hk
  · intro j
    rw [hcw j.val (by omega)]
    show (claimWeight logN cl[i.val] j.val).toK shdP_U = (claimWeight logN cl[(perm p).val] j.val).toK shdP_U
    rw [hclEq]
  · intro q b
    rw [hcw (d + 2 * q.val + if b then 0 else 1) (by have := q.isLt; cases b <;> (simp only [↓reduceIte, Bool.false_eq_true]; omega))]
    by_cases hqp : q = p
    · subst hqp
      rw [ite_eq_left rfl]
      cases b with
      | true =>
        simp only [↓reduceIte, Nat.add_zero]
        show (claimWeight logN cl[i.val] (d + 2 * p.val)).toK shdP_U
          = (claimWeight logN cl[(perm p).val] (d + 2 * p.val)).toK shdP_U
        rw [hclEq]
      | false =>
        simp only [Bool.false_eq_true, ↓reduceIte]
        show (claimWeight logN cl[i.val] (d + 2 * p.val + 1)).toK shdP_U
          = (claimWeight logN cl[(perm p).val] (d + 2 * p.val + 1)).toK shdP_U
        rw [hclEq]
    · rw [ite_eq_right hqp]
      have hmemSite : d + 2 * q.val + (if b then 0 else 1) ∈ List.range' d (2 * g) := by
        refine List.mem_range'.mpr ⟨2 * q.val + (if b then 0 else 1),
          by have := q.isLt; cases b <;> (simp only [↓reduceIte, Bool.false_eq_true]; omega), by omega⟩
      have hnotMem : d + 2 * q.val + (if b then 0 else 1) ∉
          cl[i.val].parts.flatMap (partSiteRows (2 ^ logN) (List.range' d (2 * g))) := by
        rw [← hclEq]
        change _ ∉ cl[((auditClaims_std_bijection logN d g (d + 2 * g) (d + 2 * g + 2) le_rfl rfl cl haud).choose_spec.choose p).val].parts.flatMap _
        rw [hspec.2.1]
        simp only [List.mem_cons, List.not_mem_nil, or_false, not_or]
        have hqne : q.val ≠ p.val := fun h => hqp (Fin.ext h)
        cases b <;> (simp only [↓reduceIte, Bool.false_eq_true]; omega)
      exact claimWeight_zero_of_not_mem_touched logN (List.range' d (2 * g)) cl[i.val] _ hmemSite hnotMem
  · refine ⟨(hcw (d + 2 * g) (by omega)).trans ?_, (hcw (d + 2 * g + 1) (by omega)).trans ?_⟩
    · exact claimWeight_zero_of_ge_prox logN (d + 2 * g) cl[i.val] (d + 2 * g)
        (by rw [← hclEq]; exact hspec.1) le_rfl
    · exact claimWeight_zero_of_ge_prox logN (d + 2 * g) cl[i.val] (d + 2 * g + 1)
        (by rw [← hclEq]; exact hspec.1) (by omega)

/-- Pure view-and-`v` reconstruction of ANY standard PCS table's `Exec.Block.OpeningZk`. -/
noncomputable def stdOpenRecon (logN lr d g : ℕ) (idxs : List ℕ) (hIdxsLt : ∀ j ∈ idxs, j < 2 ^ (logN + lr))
    (clRef : List Block.ZClaim)
    (haud : auditClaims clRef (2 ^ logN) (d + 2 * g + 2) (List.range' d (2 * g)) none (d + 2 * g) = .ok ())
    (lams : List Fp2) (tree : MerkleLevels (logN + lr))
    (vw : PcsStdView GF shdP_K (mkStdSpec logN lr d g) (nodupCols idxs).length) : Exec.Block.OpeningZk :=
  let perm := stdAuditPerm logN d g clRef haud
  let vecs := groupVecsRecon (d + 2 * g + 2) logN clRef lams (fun i => vw.1.1 (perm.symm i))
  let prox := (List.range (2 ^ logN + 256)).map fun k => ofK shdP_U shdP_hbij (rowAt vw.1.2.1 k)
  let cols := idxs.attach.map fun ⟨j, hj⟩ =>
    ofOCol (j, stdColFromView vw.1 (dedupFind idxs j hj), vw.2 ⟨j, hIdxsLt j hj⟩, tree.pathD j)
  ⟨vecs, prox, cols⟩

/-- **Exact `openingAuditFixedProg` reconstruction for ANY standard PCS table (`B_0..26`, `A_0..27`)**
from `(D.view y c)` and `v`-only data! -/
theorem stdOpen_of_view {Dt : Type} (logN lr d g : ℕ) (hkl : logN + lr ≤ 31)
    (prm : PcsPrm) (hPrmN : prm.n = 2 ^ logN) (hPrmQ : prm.qPad = 256) (hPrmLC : prm.logCols = logN)
    (idxs : List ℕ) (hIdxsLen : idxs.length = 256) (hIdxsLt : ∀ j ∈ idxs, j < 2 ^ (logN + lr))
    (cl clRef : List Block.ZClaim) (hparts : cl.map Block.ZClaim.parts = clRef.map Block.ZClaim.parts)
    (haud : auditClaims clRef (2 ^ logN) (d + 2 * g + 2) (List.range' d (2 * g)) none (d + 2 * g) = .ok ())
    (lams proxR : List Fp2)
    (hLamsLen : ((groupZclaims (clRef.map toZClaim) (d + 2 * g + 2) logN).map (fun x => x.2.length)).sum = lams.length)
    (hProxLen : proxR.length = d + 2 * g + 2)
    (hDet : (Exec.Block.det (proxR.getD (d + 2 * g) Fp2.zero) (proxR.getD (d + 2 * g + 1) Fp2.zero)).v ≠ 0)
    (dat : Dt → Fin d → Fin (2 ^ logN) → GF) (y : Dt) (c : PcsStdCoins GF (mkStdSpec logN lr d g))
    (T : Table) (hTrows : T.rows.length = d + 2 * g + 2)
    (hrowsEq : ∀ (r : Fin (d + 2 * g + 2)) (k : ℕ), k < 2 ^ logN + 256 →
      ((T.rows.getD r.val []).getD k Fp.zero).toGF = rowAt (stdRowOf (dat y) c.1 r) k)
    (hcols : ColsHonest shdP_U (lagK logN (by omega)) 256 (cosetPt (rootFp (logN + lr))) (2 ^ logN * 2 ^ lr) T)
    (hcan : ∀ j, ∀ x ∈ T.cols j, x.Canon)
    (hsalts : ∀ j (hj : j < 2 ^ (logN + lr)), T.salts j = c.2 ⟨j, hj⟩)
    (tree : MerkleLevels (logN + lr)) :
    let D := stdPcsData_of_audit logN lr d g hkl idxs hIdxsLen hIdxsLt clRef haud proxR hDet dat
    let vecs := (groupRhosAux (d + 2 * g + 2) (pGroups prm T (cl.map toZClaim)) lams).map
      (fun rho => combVec (prm.n + prm.qPad) rho T.rows)
    let prox := combVec (prm.n + prm.qPad) proxR T.rows
    let cols := idxs.map (fun j => ofOCol (j, T.cols j, T.salts j, tree.pathD j))
    (⟨vecs, prox, cols⟩ : Exec.Block.OpeningZk)
      = stdOpenRecon logN lr d g idxs hIdxsLt clRef haud lams tree (D.view y c) := by
  intro D vecs prox cols
  have hV : vecs = groupVecsRecon (d + 2 * g + 2) logN clRef lams
      (fun i => (D.view y c).1.1 ((stdAuditPerm logN d g clRef haud).symm i)) := by
    dsimp only [vecs, pGroups]
    rw [hTrows, hPrmLC, hPrmN, hPrmQ]
    exact groupRhosAux_combVec_of_claimVecs (d + 2 * g + 2) logN cl clRef hparts T.rows hTrows lams hLamsLen
      (fun i => (D.view y c).1.1 ((stdAuditPerm logN d g clRef haud).symm i))
      (fun i k hk => stdClaim_combAt_eq_of_audit logN lr d g hkl idxs hIdxsLen hIdxsLt clRef haud proxR hDet dat y c T.rows hTrows hrowsEq i k hk)
  have hP : prox = (List.range (2 ^ logN + 256)).map fun k => ofK shdP_U shdP_hbij (rowAt (D.view y c).1.2.1 k) := by
    dsimp only [prox]; rw [hPrmN, hPrmQ]
    refine List.ext_getElem (by rw [combVec_length, List.length_map, List.length_range]) fun k hk1 hk2 => ?_
    rw [combVec_length] at hk1
    have hget : (combVec (2 ^ logN + 256) proxR T.rows)[k]'(by rw [combVec_length]; exact hk1)
        = combAt proxR T.rows k := by
      have h := combVec_getD (2 ^ logN + 256) proxR T.rows k hk1
      rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem (by rw [combVec_length]; exact hk1), Option.getD_some] at h
      exact h
    rw [hget]
    simp only [List.getElem_map, List.getElem_range]
    have hcanK : (combAt proxR T.rows k).Canon :=
      (combVec_canon_len (2 ^ logN + 256) proxR T.rows).2 _ (by rw [← hget]; exact List.getElem_mem _)
    refine fp2_eq_ofK hcanK ?_
    exact stdProx_combAt_eq_view D.ω (dat y) c.1 T.rows hTrows hrowsEq proxR hProxLen
      (fun _ => rfl) (fun _ _ => rfl) rfl rfl k hk1
  have hC : cols = idxs.attach.map fun ⟨j, hj⟩ =>
      ofOCol (j, stdColFromView (D.view y c).1 (dedupFind idxs j hj), (D.view y c).2 ⟨j, hIdxsLt j hj⟩, tree.pathD j) := by
    dsimp only [cols]
    rw [← List.attach_map_val]
    refine List.map_congr_left fun ⟨j, hj⟩ _ => ?_
    have hjEq := dedupIdx_dedupFind idxs hIdxsLt j hj
    have hcol := stdCol_eq_view hkl (dedupIdx idxs hIdxsLt) D.ω (dat y) c.1 T hTrows hrowsEq hcols hcan (dedupFind idxs j hj)
    rw [hjEq] at hcol
    rw [hcol, hsalts j (hIdxsLt j hj)]
    rfl
  unfold stdOpenRecon
  rw [hV, hP, hC]

end StdPcsView

/-! ## 4. `H` PCS Tables (`H_0..27`) & Unified `PcsAHData` -/

section HPcsView

/-- **Generic `hdH` discharge from `ClaimTrue ... (toZClaim logupSumClaim)`**:
for any `H` table matching `hRowOf dat c` whose sum claim `zSum` has `value = 0`, key `⟨[], 0, 2^logN⟩`
(all-ones column weights), and zero weights on rows `≥ d + 2`, the data-row sum vanishes! -/
theorem hdH_of_logupSumClaim_true {logN d g : ℕ}
    (dat : Fin d → Fin (2 ^ logN) → GF) (c : Hiding.CoinsH GF (2 ^ logN) 256 (Fin d) (Fin g))
    (rows : List (List Fp)) (hrowsLen : rows.length = d + 2 + 2 * g + 2)
    (hrowsEq : ∀ (r : Fin (d + 2 + 2 * g + 2)) (k : ℕ), k < 2 ^ logN + 256 →
      ((rows.getD r.val []).getD k Fp.zero).toGF = rowAt (hRowOf dat c r) k)
    (zSum : Block.ZClaim) (hzVal : zSum.value = Fp2.zero)
    (hzKey : (claimWeights (toZClaim zSum) (d + 2 + 2 * g + 2) logN).2 = ⟨[], 0, 2 ^ logN⟩)
    (hzRest : ∀ r, d + 2 ≤ r → r < d + 2 + 2 * g + 2 → (claimWeight logN zSum r).toK shdP_U = 0)
    (htrue : ClaimTrue shdP_U (2 ^ logN) logN rows (toZClaim zSum)) :
    ∑ col : Fin (2 ^ logN), ∑ i : Fin d,
      (claimWeight logN zSum i.val).toK shdP_U * algebraMap GF shdP_K (dat i col) = 0 := by
  unfold ClaimTrue MemTrue tabVal at htrue
  dsimp only at htrue
  have hval0 : (toZClaim zSum).value.toK shdP_U = 0 := by simp [toZClaim, hzVal, Fp2.toK_zero]
  rw [hval0, hrowsLen] at htrue
  have hzw : ∀ t : ℕ, t < 2 ^ logN →
      ((zkeyWeights (claimWeights (toZClaim zSum) (d + 2 + 2 * g + 2) logN).2 logN).getD t Fp2.zero).toK shdP_U = 1 := by
    intro t ht
    rw [hzKey]
    unfold zkeyWeights
    rw [getD_map_lt' _ (List.range (2 ^ logN)) t (by rw [List.length_range]; exact ht) 0 Fp2.zero,
      List.getD_eq_getElem?_getD, List.getElem?_range ht, Option.getD_some]
    simp [ht, Fp2.toK_one]
  have hcw : ∀ r < d + 2 + 2 * g + 2,
      (((claimWeights (toZClaim zSum) (d + 2 + 2 * g + 2) logN).1).getD r Fp2.zero).toK shdP_U
        = (claimWeight logN zSum r).toK shdP_U :=
    fun r hr => claimWeights_getD_toK zSum (d + 2 + 2 * g + 2) logN r hr
  have hsum :
      ∑ i ∈ Finset.range (d + 2 + 2 * g + 2),
        (((claimWeights (toZClaim zSum) (d + 2 + 2 * g + 2) logN).1).getD i Fp2.zero).toK shdP_U *
          ∑ t ∈ Finset.range (2 ^ logN),
            algebraMap GF shdP_K ((rows.getD i []).getD t Fp.zero).toGF *
              ((zkeyWeights (claimWeights (toZClaim zSum) (d + 2 + 2 * g + 2) logN).2 logN).getD t Fp2.zero).toK shdP_U
      = ∑ i : Fin d, (claimWeight logN zSum i.val).toK shdP_U *
          ∑ col : Fin (2 ^ logN), algebraMap GF shdP_K (dat i col) := by
    rw [show Finset.range (d + 2 + 2 * g + 2) = Finset.range ((d + 2) + (2 * g + 2)) from congrArg Finset.range (by omega),
      Finset.sum_range_add]
    have htail : ∑ j ∈ Finset.range (2 * g + 2),
        (((claimWeights (toZClaim zSum) (d + 2 + 2 * g + 2) logN).1).getD (d + 2 + j) Fp2.zero).toK shdP_U *
          ∑ t ∈ Finset.range (2 ^ logN),
            algebraMap GF shdP_K ((rows.getD (d + 2 + j) []).getD t Fp.zero).toGF *
              ((zkeyWeights (claimWeights (toZClaim zSum) (d + 2 + 2 * g + 2) logN).2 logN).getD t Fp2.zero).toK shdP_U = 0 :=
      Finset.sum_eq_zero fun j hj => by
        have hjlt := Finset.mem_range.mp hj
        rw [hcw (d + 2 + j) (by omega), hzRest (d + 2 + j) (by omega) (by omega), zero_mul]
    rw [htail, add_zero, Finset.sum_range_succ, Finset.sum_range_succ]
    have hU0 : ∑ t ∈ Finset.range (2 ^ logN),
        algebraMap GF shdP_K ((rows.getD d []).getD t Fp.zero).toGF *
          ((zkeyWeights (claimWeights (toZClaim zSum) (d + 2 + 2 * g + 2) logN).2 logN).getD t Fp2.zero).toK shdP_U = 0 := by
      rw [Finset.sum_range]
      have h1 : ∀ col : Fin (2 ^ logN),
          algebraMap GF shdP_K ((rows.getD d []).getD col.val Fp.zero).toGF *
            ((zkeyWeights (claimWeights (toZClaim zSum) (d + 2 + 2 * g + 2) logN).2 logN).getD col.val Fp2.zero).toK shdP_U
          = algebraMap GF shdP_K (shdP_zsGen (fun j => c.2.1 true (Sum.inl j)) col) := by
        intro col
        rw [hzw col.val col.isLt, mul_one, hrowsEq ⟨d, by omega⟩ col.val (by omega)]
        unfold hRowOf rowAt Hiding.zsRow
        dsimp only
        rw [dite_eq_left col.isLt, dite_eq_right (by omega), dite_eq_left (by omega)]
        simp
      simp_rw [h1, ← map_sum, shdP_zsGen_sum_zero (Nat.two_pow_pos logN), map_zero]
    have hU1 : ∑ t ∈ Finset.range (2 ^ logN),
        algebraMap GF shdP_K ((rows.getD (d + 1) []).getD t Fp.zero).toGF *
          ((zkeyWeights (claimWeights (toZClaim zSum) (d + 2 + 2 * g + 2) logN).2 logN).getD t Fp2.zero).toK shdP_U = 0 := by
      rw [Finset.sum_range]
      have h1 : ∀ col : Fin (2 ^ logN),
          algebraMap GF shdP_K ((rows.getD (d + 1) []).getD col.val Fp.zero).toGF *
            ((zkeyWeights (claimWeights (toZClaim zSum) (d + 2 + 2 * g + 2) logN).2 logN).getD col.val Fp2.zero).toK shdP_U
          = algebraMap GF shdP_K (shdP_zsGen (fun j => c.2.1 false (Sum.inl j)) col) := by
        intro col
        rw [hzw col.val col.isLt, mul_one, hrowsEq ⟨d + 1, by omega⟩ col.val (by omega)]
        unfold hRowOf rowAt Hiding.zsRow
        dsimp only
        rw [dite_eq_left col.isLt, dite_eq_right (by omega), dite_eq_left (by omega)]
        simp [show d + 1 ≠ d by omega]
      simp_rw [h1, ← map_sum, shdP_zsGen_sum_zero (Nat.two_pow_pos logN), map_zero]
    rw [hU0, hU1, mul_zero, mul_zero, add_zero, add_zero, Finset.sum_range]
    refine Finset.sum_congr rfl fun i _ => ?_
    rw [hcw i.val (by omega), Finset.sum_range]
    congr 1
    refine Finset.sum_congr rfl fun col _ => ?_
    rw [hzw col.val col.isLt, mul_one, hrowsEq ⟨i.val, by omega⟩ col.val (by omega)]
    unfold hRowOf rowAt; dsimp only
    rw [dite_eq_left i.isLt, dite_eq_left col.isLt]; rfl
  rw [hsum] at htrue
  rw [Finset.sum_comm]
  have : ∑ i : Fin d, ∑ col : Fin (2 ^ logN),
      (claimWeight logN zSum i.val).toK shdP_U * algebraMap GF shdP_K (dat i col) = 0 := by
    simp_rw [← Finset.mul_sum]
    exact htrue.symm
  exact this

/-- Reconstruct a `(d + 2 + 2*g + 2)`-row `H` PCS column at deduplicated index `q` from `Hiding.ViewH`. -/
def hColFromView {n d g kOpen : ℕ} (vw : Hiding.ViewH GF shdP_K n 256 kOpen (Fin d) (Fin g))
    (q : Fin kOpen) : List Fp :=
  (List.range (d + 2 + 2 * g + 2)).map fun r =>
    if h1 : r < d then Fp.ofGF (vw.2.2.2.1 ⟨r, h1⟩ q)
    else if h2 : r < d + 2 then Fp.ofGF (vw.2.2.2.2.1 (decide (r = d)) q)
    else if h3 : r < d + 2 + 2 * g then
      Fp.ofGF (vw.2.2.2.2.2.1 (⟨(r - (d + 2)) / 2, by omega⟩, decide ((r - (d + 2)) % 2 = 0)) q)
    else Fp.ofGF (vw.2.2.2.2.2.2 (decide (r = d + 2 + 2 * g)) q)

theorem hCol_eq_view {logN lr d g kOpen : ℕ} (hkl : logN + lr ≤ 31)
    (idx : Fin kOpen → Fin (2 ^ (logN + lr)))
    (ω : Hiding.WeightsH shdP_K (Fin d) (Fin g))
    (dat : Fin d → Fin (2 ^ logN) → GF) (c : Hiding.CoinsH GF (2 ^ logN) 256 (Fin d) (Fin g))
    (T : Table) (hrowsLen : T.rows.length = d + 2 + 2 * g + 2)
    (hrowsEq : ∀ (r : Fin (d + 2 + 2 * g + 2)) (k : ℕ), k < 2 ^ logN + 256 →
      ((T.rows.getD r.val []).getD k Fp.zero).toGF = rowAt (hRowOf dat c r) k)
    (hcols : ColsHonest shdP_U (lagK logN (by omega)) 256 (cosetPt (rootFp (logN + lr))) (2 ^ logN * 2 ^ lr) T)
    (hcan : ∀ j, ∀ x ∈ T.cols j, x.Canon) (q : Fin kOpen) :
    T.cols (idx q).val
      = hColFromView (Hiding.openingViewH (pcsEvalMat logN lr hkl idx) shdP_zsGen ω dat c) q := by
  have hltN : (idx q).val < 2 ^ logN * 2 ^ lr := by rw [← pow_add]; exact (idx q).isLt
  have hclen : (T.cols (idx q).val).length = d + 2 + 2 * g + 2 := by rw [(hcols (idx q).val hltN).1, hrowsLen]
  refine List.ext_getElem (by rw [hclen, hColFromView, List.length_map, List.length_range]) fun i hi1 hi2 => ?_
  rw [hclen] at hi1
  have hget : (T.cols (idx q).val)[i]'(by rw [hclen]; exact hi1) = (T.cols (idx q).val).getD i Fp.zero := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem (by rw [hclen]; exact hi1), Option.getD_some]
  rw [hget, colsHonest_col_eq_evalMat logN lr hkl idx T hcols hcan i (by omega) q]
  simp only [hColFromView, List.getElem_map, List.getElem_range]
  have hrowElim :
      Sum.elim (fun col : Fin (2 ^ logN) => ((T.rows.getD i []).getD col.val Fp.zero).toGF)
        (fun l : Fin 256 => ((T.rows.getD i []).getD (2 ^ logN + l.val) Fp.zero).toGF)
        = hRowOf dat c ⟨i, hi1⟩ := by
    funext u
    cases u with
    | inl col =>
      have h := hrowsEq ⟨i, hi1⟩ col.val (by omega)
      unfold rowAt at h; rw [dite_eq_left col.isLt] at h; exact h
    | inr l =>
      have h := hrowsEq ⟨i, hi1⟩ (2 ^ logN + l.val) (by omega)
      unfold rowAt at h
      rw [dite_eq_right (by omega), dite_eq_left (by omega)] at h
      simpa using h
  rw [hrowElim]
  unfold hRowOf Hiding.openingViewH
  dsimp only
  split_ifs <;> rfl

/-- The `Fin g ≃ Fin g` claim-to-site-pair permutation extracted from `auditClaims_h_bijection`. -/
noncomputable def hAuditPerm (logN d g : ℕ) (cl : List Block.ZClaim) (hLen : cl.length = g + 1)
    (haud : auditClaims cl (2 ^ logN) (d + 2 + 2 * g + 2) (List.range' (d + 2) (2 * g))
      (some (d, d + 1)) (d + 2 + 2 * g) = .ok ()) : Fin g ≃ Fin g :=
  (auditClaims_h_bijection logN d (d + 1) (d + 2) g (d + 2 + 2 * g) (d + 2 + 2 * g + 2)
    le_rfl rfl cl hLen haud).choose

/-- Build `PcsAHData` for one segment's `(A, H)` pair (`⟨mkStdSpec logN lr dA gA, mkStdSpec logN lr dH gH⟩`). -/
noncomputable def pcsAHData_of_audit {Dt : Type} (logN lr dA gA dH gH : ℕ) (hkl : logN + lr ≤ 31)
    (idxsA : List ℕ) (hIdxsALen : idxsA.length = 256) (hIdxsALt : ∀ j ∈ idxsA, j < 2 ^ (logN + lr))
    (clA : List Block.ZClaim)
    (haudA : auditClaims clA (2 ^ logN) (dA + 2 * gA + 2) (List.range' dA (2 * gA)) none (dA + 2 * gA) = .ok ())
    (proxRA : List Fp2)
    (hDetA : (Exec.Block.det (proxRA.getD (dA + 2 * gA) Fp2.zero) (proxRA.getD (dA + 2 * gA + 1) Fp2.zero)).v ≠ 0)
    (datA : Dt → Fin dA → Fin (2 ^ logN) → GF)
    (idxsH : List ℕ) (hIdxsHLen : idxsH.length = 256) (hIdxsHLt : ∀ j ∈ idxsH, j < 2 ^ (logN + lr))
    (clH : List Block.ZClaim) (hLenH : clH.length = gH + 1)
    (haudH : auditClaims clH (2 ^ logN) (dH + 2 + 2 * gH + 2) (List.range' (dH + 2) (2 * gH))
      (some (dH, dH + 1)) (dH + 2 + 2 * gH) = .ok ())
    (proxRH : List Fp2)
    (hDetH : (Exec.Block.det (proxRH.getD (dH + 2 + 2 * gH) Fp2.zero) (proxRH.getD (dH + 2 + 2 * gH + 1) Fp2.zero)).v ≠ 0)
    (datH : Dt → Fin dH → Fin (2 ^ logN) → GF)
    (hdH : ∀ y, ∑ col : Fin (2 ^ logN), ∑ i : Fin dH,
      (claimWeight logN clH[gH] i.val).toK shdP_U * algebraMap GF shdP_K (datH y i col) = 0) :
    PcsAHData GF shdP_K Dt ⟨mkStdSpec logN lr dA gA, mkStdSpec logN lr dH gH⟩
      (nodupCols idxsA).length (nodupCols idxsH).length :=
  let DA := stdPcsData_of_audit logN lr dA gA hkl idxsA hIdxsALen hIdxsALt clA haudA proxRA hDetA datA
  let hbij := auditClaims_h_bijection logN dH (dH + 1) (dH + 2) gH (dH + 2 + 2 * gH) (dH + 2 + 2 * gH + 2)
    le_rfl rfl clH hLenH haudH
  let permH := hbij.choose
  { EA := DA.E
    ωA := DA.ω
    habA := DA.hab
    hpA := DA.hp
    hEA := DA.hE
    EH := pcsEvalMat logN lr hkl (dedupIdx idxsH hIdxsHLt)
    Z := shdP_zsGen
    hZadd := shdP_zsGen_add
    hZ := shdP_zsGen_surj (Nat.two_pow_pos logN)
    ωH :=
      { sD := fun i => (claimWeight logN clH[gH] i.val).toK shdP_U
        sa := (claimWeight logN clH[gH] dH).toK shdP_U
        sb := (claimWeight logN clH[gH] (dH + 1)).toK shdP_U
        wD := fun p i => (claimWeight logN clH[(permH p).val] i.val).toK shdP_U
        wU := fun p b => (claimWeight logN clH[(permH p).val] (if b then dH else dH + 1)).toK shdP_U
        a := fun p => (claimWeight logN clH[(permH p).val] (dH + 2 + 2 * p.val)).toK shdP_U
        b := fun p => (claimWeight logN clH[(permH p).val] (dH + 2 + 2 * p.val + 1)).toK shdP_U
        pD := fun i => (proxRH.getD i.val Fp2.zero).toK shdP_U
        pU := fun b => (proxRH.getD (if b then dH else dH + 1) Fp2.zero).toK shdP_U
        pG := fun gs => (proxRH.getD (dH + 2 + 2 * gs.1.val + if gs.2 then 0 else 1) Fp2.zero).toK shdP_U
        pa := (proxRH.getD (dH + 2 + 2 * gH) Fp2.zero).toK shdP_U
        pb := (proxRH.getD (dH + 2 + 2 * gH + 1) Fp2.zero).toK shdP_U }
    hsH := hbij.choose_spec.1.2.2
    habH := fun p => (hbij.choose_spec.2 p).2.2
    hpH := shdP_proxPair_linInd_of_fp2Det _ _ hDetH
    hEH := pcsEvalMat_padSurj logN lr hkl (by rw [← hIdxsHLen]; exact nodupCols_length_le idxsH)
      (dedupIdx idxsH hIdxsHLt) (dedupIdx_injective idxsH hIdxsHLt)
    dA := datA
    dH := datH
    hdH := hdH }

/-- Map each claim `i : Fin clH.length` (`clH.length = gH + 1`) to its individual claim row vector
inside `Hiding.ViewH`: `i < gH ↦ vwH.2.1 (permH.symm ⟨i, _⟩)` and `i = gH ↦ vwH.1`! -/
def hClaimVecOfView {n dH gH kOpen : ℕ} (clH : List Block.ZClaim) (hLenH : clH.length = gH + 1)
    (permH : Fin gH ≃ Fin gH) (vwH : Hiding.ViewH GF shdP_K n 256 kOpen (Fin dH) (Fin gH))
    (i : Fin clH.length) : Hiding.Row shdP_K n 256 :=
  if h : i.val < gH then vwH.2.1 (permH.symm ⟨i.val, h⟩) else vwH.1

/-- Every claim `i : Fin clH.length` of an audited `H` table matches `hClaimVecOfView` at every `k < 2^logN + 256`. -/
theorem hClaim_combAt_eq_of_audit {logN lr dH gH kOpen : ℕ}
    {E : Matrix (Fin kOpen) (Fin (2 ^ logN) ⊕ Fin 256) GF}
    (clH : List Block.ZClaim) (hLenH : clH.length = gH + 1)
    (haudH : auditClaims clH (2 ^ logN) (dH + 2 + 2 * gH + 2) (List.range' (dH + 2) (2 * gH))
      (some (dH, dH + 1)) (dH + 2 + 2 * gH) = .ok ())
    (proxRH : List Fp2)
    (datH : Fin dH → Fin (2 ^ logN) → GF) (cH : Hiding.CoinsH GF (2 ^ logN) 256 (Fin dH) (Fin gH))
    (Trows : List (List Fp)) (hTrows : Trows.length = dH + 2 + 2 * gH + 2)
    (hrowsEq : ∀ (r : Fin (dH + 2 + 2 * gH + 2)) (k : ℕ), k < 2 ^ logN + 256 →
      ((Trows.getD r.val []).getD k Fp.zero).toGF = rowAt (hRowOf datH cH r) k)
    (i : Fin clH.length) (k : ℕ) (hk : k < 2 ^ logN + 256) :
    let permH := hAuditPerm logN dH gH clH hLenH haudH
    let ωH : Hiding.WeightsH shdP_K (Fin dH) (Fin gH) :=
      { sD := fun j => (claimWeight logN clH[gH] j.val).toK shdP_U
        sa := (claimWeight logN clH[gH] dH).toK shdP_U
        sb := (claimWeight logN clH[gH] (dH + 1)).toK shdP_U
        wD := fun p j => (claimWeight logN clH[(permH p).val] j.val).toK shdP_U
        wU := fun p b => (claimWeight logN clH[(permH p).val] (if b then dH else dH + 1)).toK shdP_U
        a := fun p => (claimWeight logN clH[(permH p).val] (dH + 2 + 2 * p.val)).toK shdP_U
        b := fun p => (claimWeight logN clH[(permH p).val] (dH + 2 + 2 * p.val + 1)).toK shdP_U
        pD := fun j => (proxRH.getD j.val Fp2.zero).toK shdP_U
        pU := fun b => (proxRH.getD (if b then dH else dH + 1) Fp2.zero).toK shdP_U
        pG := fun gs => (proxRH.getD (dH + 2 + 2 * gs.1.val + if gs.2 then 0 else 1) Fp2.zero).toK shdP_U
        pa := (proxRH.getD (dH + 2 + 2 * gH) Fp2.zero).toK shdP_U
        pb := (proxRH.getD (dH + 2 + 2 * gH + 1) Fp2.zero).toK shdP_U }
    (combAt (claimWeights (toZClaim clH[i.val]) (dH + 2 + 2 * gH + 2) logN).1 Trows k).toK shdP_U
      = rowAt (hClaimVecOfView clH hLenH permH (Hiding.openingViewH E shdP_zsGen ωH datH cH) i) k := by
  intro permH ωH
  have hbij := auditClaims_h_bijection logN dH (dH + 1) (dH + 2) gH (dH + 2 + 2 * gH)
    (dH + 2 + 2 * gH + 2) le_rfl rfl clH hLenH haudH
  have hcw : ∀ r < dH + 2 + 2 * gH + 2,
      ((claimWeights (toZClaim clH[i.val]) (dH + 2 + 2 * gH + 2) logN).1.getD r Fp2.zero).toK shdP_U
        = (claimWeight logN clH[i.val] r).toK shdP_U :=
    fun r hr => claimWeights_getD_toK clH[i.val] (dH + 2 + 2 * gH + 2) logN r hr
  unfold hClaimVecOfView
  by_cases hi : i.val < gH
  · rw [dite_eq_left hi]
    set p : Fin gH := permH.symm ⟨i.val, hi⟩
    have hpiVal : (permH p).val = i.val := congrArg Fin.val (permH.apply_symm_apply ⟨i.val, hi⟩)
    have hclEq : clH[(permH p).val]'(by omega) = clH[i.val] := list_getElem_eq_of_idx clH _ _ hpiVal
    have hspec := hbij.choose_spec.2 p
    refine hEvalClaim_combAt_eq_view ωH datH cH Trows hTrows hrowsEq
      (claimWeights (toZClaim clH[i.val]) (dH + 2 + 2 * gH + 2) logN).1 (claimWeights_length _ _ _) p ?_ ?_ ?_ ?_ k hk
    · intro j; rw [hcw j.val (by omega)]; dsimp only [ωH]; rw [hclEq]
    · exact ⟨by rw [hcw dH (by omega)]; dsimp only [ωH]; simp only [↓reduceIte, hclEq],
             by rw [hcw (dH + 1) (by omega)]; dsimp only [ωH]; simp only [Bool.false_eq_true, ↓reduceIte, hclEq]⟩
    · intro q b
      rw [hcw (dH + 2 + 2 * q.val + if b then 0 else 1) (by have := q.isLt; cases b <;> (simp only [↓reduceIte, Bool.false_eq_true]; omega))]
      by_cases hqp : q = p
      · subst hqp
        rw [ite_eq_left rfl]
        cases b <;> (dsimp only [ωH]; simp only [↓reduceIte, Bool.false_eq_true, Nat.add_zero, hclEq])
      · rw [ite_eq_right hqp]
        have hmemSite : dH + 2 + 2 * q.val + (if b then 0 else 1) ∈ List.range' (dH + 2) (2 * gH) :=
          List.mem_range'.mpr ⟨2 * q.val + (if b then 0 else 1),
            by have := q.isLt; cases b <;> (simp only [↓reduceIte, Bool.false_eq_true]; omega), by omega⟩
        have hnotMem : dH + 2 + 2 * q.val + (if b then 0 else 1) ∉
            clH[i.val].parts.flatMap (partSiteRows (2 ^ logN) (List.range' (dH + 2) (2 * gH))) := by
          rw [← hclEq]
          change _ ∉ (clH[(hbij.choose p).val]'(by omega)).parts.flatMap _
          rw [hspec.2.1]
          simp only [List.mem_cons, List.not_mem_nil, or_false, not_or]
          have hqne : q.val ≠ p.val := fun h => hqp (Fin.ext h)
          cases b <;> (simp only [↓reduceIte, Bool.false_eq_true]; omega)
        exact claimWeight_zero_of_not_mem_touched logN (List.range' (dH + 2) (2 * gH)) clH[i.val] _ hmemSite hnotMem
    · refine ⟨(hcw (dH + 2 + 2 * gH) (by omega)).trans ?_, (hcw (dH + 2 + 2 * gH + 1) (by omega)).trans ?_⟩
      · exact claimWeight_zero_of_ge_prox logN (dH + 2 + 2 * gH) clH[i.val] (dH + 2 + 2 * gH)
          (by rw [← hclEq]; exact hspec.1) le_rfl
      · exact claimWeight_zero_of_ge_prox logN (dH + 2 + 2 * gH) clH[i.val] (dH + 2 + 2 * gH + 1)
          (by rw [← hclEq]; exact hspec.1) (by omega)
  · rw [dite_eq_right hi]
    have hig : i.val = gH := by have := i.isLt; omega
    have hclEqG : clH[i.val] = clH[gH]'(by omega) := list_getElem_eq_of_idx clH _ _ hig
    have hsumSpec := hbij.choose_spec.1
    refine hSumClaim_combAt_eq_view ωH datH cH Trows hTrows hrowsEq
      (claimWeights (toZClaim clH[i.val]) (dH + 2 + 2 * gH + 2) logN).1 (claimWeights_length _ _ _) ?_ ?_ ?_ ?_ k hk
    · intro j; rw [hcw j.val (by omega)]; dsimp only [ωH]; rw [hclEqG]
    · rw [hcw dH (by omega)]; dsimp only [ωH]; rw [hclEqG]
    · rw [hcw (dH + 1) (by omega)]; dsimp only [ωH]; rw [hclEqG]
    · intro r hr1 hr2
      rw [hcw r hr2]
      by_cases hltP : r < dH + 2 + 2 * gH
      · have hmemSite : r ∈ List.range' (dH + 2) (2 * gH) :=
          List.mem_range'.mpr ⟨r - (dH + 2), by omega, by omega⟩
        have hnotMem : r ∉ clH[i.val].parts.flatMap (partSiteRows (2 ^ logN) (List.range' (dH + 2) (2 * gH))) := by
          rw [hclEqG, hsumSpec.2.1]; exact List.not_mem_nil
        exact claimWeight_zero_of_not_mem_touched logN (List.range' (dH + 2) (2 * gH)) clH[i.val] r hmemSite hnotMem
      · exact claimWeight_zero_of_ge_prox logN (dH + 2 + 2 * gH) clH[i.val] r
          (by rw [hclEqG]; exact hsumSpec.1) (by omega)

/-- Pure view-and-`v` reconstruction of ANY `H` PCS table's `Exec.Block.OpeningZk`. -/
noncomputable def hOpenRecon (logN lr dH gH : ℕ) (idxsH : List ℕ) (hIdxsHLt : ∀ j ∈ idxsH, j < 2 ^ (logN + lr))
    (clHRef : List Block.ZClaim) (hLenH : clHRef.length = gH + 1)
    (haudH : auditClaims clHRef (2 ^ logN) (dH + 2 + 2 * gH + 2) (List.range' (dH + 2) (2 * gH))
      (some (dH, dH + 1)) (dH + 2 + 2 * gH) = .ok ())
    (lamsH : List Fp2) (treeH : MerkleLevels (logN + lr))
    (vwH : Hiding.ViewH GF shdP_K (2 ^ logN) 256 (nodupCols idxsH).length (Fin dH) (Fin gH))
    (saltH : Fin (2 ^ (logN + lr)) → Dig) : Exec.Block.OpeningZk :=
  let permH := hAuditPerm logN dH gH clHRef hLenH haudH
  let vecs := groupVecsRecon (dH + 2 + 2 * gH + 2) logN clHRef lamsH
    (hClaimVecOfView clHRef hLenH permH vwH)
  let prox := (List.range (2 ^ logN + 256)).map fun k => ofK shdP_U shdP_hbij (rowAt vwH.2.2.1 k)
  let cols := idxsH.attach.map fun ⟨j, hj⟩ =>
    ofOCol (j, hColFromView vwH (dedupFind idxsH j hj), saltH ⟨j, hIdxsHLt j hj⟩, treeH.pathD j)
  ⟨vecs, prox, cols⟩

/-- **Exact `openingAuditFixedProg` reconstruction for ANY `H` PCS table (`H_0..27`)**
from `(vwH, saltH)` and `v`-only data! -/
theorem hOpen_of_view (logN lr dH gH : ℕ) (hkl : logN + lr ≤ 31)
    (prm : PcsPrm) (hPrmN : prm.n = 2 ^ logN) (hPrmQ : prm.qPad = 256) (hPrmLC : prm.logCols = logN)
    (idxsH : List ℕ) (hIdxsHLt : ∀ j ∈ idxsH, j < 2 ^ (logN + lr))
    (clH clHRef : List Block.ZClaim) (hparts : clH.map Block.ZClaim.parts = clHRef.map Block.ZClaim.parts)
    (hLenH : clHRef.length = gH + 1)
    (haudH : auditClaims clHRef (2 ^ logN) (dH + 2 + 2 * gH + 2) (List.range' (dH + 2) (2 * gH))
      (some (dH, dH + 1)) (dH + 2 + 2 * gH) = .ok ())
    (lamsH proxRH : List Fp2)
    (hLamsLen : ((groupZclaims (clHRef.map toZClaim) (dH + 2 + 2 * gH + 2) logN).map (fun x => x.2.length)).sum = lamsH.length)
    (hProxLen : proxRH.length = dH + 2 + 2 * gH + 2)
    (datH : Fin dH → Fin (2 ^ logN) → GF) (cH : Hiding.CoinsH GF (2 ^ logN) 256 (Fin dH) (Fin gH))
    (saltH : Fin (2 ^ (logN + lr)) → Dig)
    (T : Table) (hTrows : T.rows.length = dH + 2 + 2 * gH + 2)
    (hrowsEq : ∀ (r : Fin (dH + 2 + 2 * gH + 2)) (k : ℕ), k < 2 ^ logN + 256 →
      ((T.rows.getD r.val []).getD k Fp.zero).toGF = rowAt (hRowOf datH cH r) k)
    (hcols : ColsHonest shdP_U (lagK logN (by omega)) 256 (cosetPt (rootFp (logN + lr))) (2 ^ logN * 2 ^ lr) T)
    (hcan : ∀ j, ∀ x ∈ T.cols j, x.Canon)
    (hsalts : ∀ j (hj : j < 2 ^ (logN + lr)), T.salts j = saltH ⟨j, hj⟩)
    (treeH : MerkleLevels (logN + lr)) :
    let permH := hAuditPerm logN dH gH clHRef hLenH haudH
    let ωH : Hiding.WeightsH shdP_K (Fin dH) (Fin gH) :=
      { sD := fun j => (claimWeight logN clHRef[gH] j.val).toK shdP_U
        sa := (claimWeight logN clHRef[gH] dH).toK shdP_U
        sb := (claimWeight logN clHRef[gH] (dH + 1)).toK shdP_U
        wD := fun p j => (claimWeight logN clHRef[(permH p).val] j.val).toK shdP_U
        wU := fun p b => (claimWeight logN clHRef[(permH p).val] (if b then dH else dH + 1)).toK shdP_U
        a := fun p => (claimWeight logN clHRef[(permH p).val] (dH + 2 + 2 * p.val)).toK shdP_U
        b := fun p => (claimWeight logN clHRef[(permH p).val] (dH + 2 + 2 * p.val + 1)).toK shdP_U
        pD := fun j => (proxRH.getD j.val Fp2.zero).toK shdP_U
        pU := fun b => (proxRH.getD (if b then dH else dH + 1) Fp2.zero).toK shdP_U
        pG := fun gs => (proxRH.getD (dH + 2 + 2 * gs.1.val + if gs.2 then 0 else 1) Fp2.zero).toK shdP_U
        pa := (proxRH.getD (dH + 2 + 2 * gH) Fp2.zero).toK shdP_U
        pb := (proxRH.getD (dH + 2 + 2 * gH + 1) Fp2.zero).toK shdP_U }
    let vwH := Hiding.openingViewH (pcsEvalMat logN lr hkl (dedupIdx idxsH hIdxsHLt)) shdP_zsGen ωH datH cH
    let vecs := (groupRhosAux (dH + 2 + 2 * gH + 2) (pGroups prm T (clH.map toZClaim)) lamsH).map
      (fun rho => combVec (prm.n + prm.qPad) rho T.rows)
    let prox := combVec (prm.n + prm.qPad) proxRH T.rows
    let cols := idxsH.map (fun j => ofOCol (j, T.cols j, T.salts j, treeH.pathD j))
    (⟨vecs, prox, cols⟩ : Exec.Block.OpeningZk)
      = hOpenRecon logN lr dH gH idxsH hIdxsHLt clHRef hLenH haudH lamsH treeH vwH saltH := by
  intro permH ωH vwH vecs prox cols
  have hV : vecs = groupVecsRecon (dH + 2 + 2 * gH + 2) logN clHRef lamsH
      (hClaimVecOfView clHRef hLenH permH vwH) := by
    dsimp only [vecs, pGroups]
    rw [hTrows, hPrmLC, hPrmN, hPrmQ]
    exact groupRhosAux_combVec_of_claimVecs (dH + 2 + 2 * gH + 2) logN clH clHRef hparts T.rows hTrows lamsH hLamsLen
      (hClaimVecOfView clHRef hLenH permH vwH)
      (fun i k hk => hClaim_combAt_eq_of_audit (lr := lr) clHRef hLenH haudH proxRH datH cH T.rows hTrows hrowsEq i k hk)
  have hP : prox = (List.range (2 ^ logN + 256)).map fun k => ofK shdP_U shdP_hbij (rowAt vwH.2.2.1 k) := by
    dsimp only [prox]; rw [hPrmN, hPrmQ]
    refine List.ext_getElem (by rw [combVec_length, List.length_map, List.length_range]) fun k hk1 hk2 => ?_
    rw [combVec_length] at hk1
    have hget : (combVec (2 ^ logN + 256) proxRH T.rows)[k]'(by rw [combVec_length]; exact hk1)
        = combAt proxRH T.rows k := by
      have h := combVec_getD (2 ^ logN + 256) proxRH T.rows k hk1
      rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem (by rw [combVec_length]; exact hk1), Option.getD_some] at h
      exact h
    rw [hget]
    simp only [List.getElem_map, List.getElem_range]
    have hcanK : (combAt proxRH T.rows k).Canon :=
      (combVec_canon_len (2 ^ logN + 256) proxRH T.rows).2 _ (by rw [← hget]; exact List.getElem_mem _)
    refine fp2_eq_ofK hcanK ?_
    exact hProx_combAt_eq_view ωH datH cH T.rows hTrows hrowsEq proxRH hProxLen
      (fun _ => rfl) ⟨rfl, rfl⟩ (fun _ _ => rfl) rfl rfl k hk1
  have hC : cols = idxsH.attach.map fun ⟨j, hj⟩ =>
      ofOCol (j, hColFromView vwH (dedupFind idxsH j hj), saltH ⟨j, hIdxsHLt j hj⟩, treeH.pathD j) := by
    dsimp only [cols]
    rw [← List.attach_map_val]
    refine List.map_congr_left fun ⟨j, hj⟩ _ => ?_
    have hjEq := dedupIdx_dedupFind idxsH hIdxsHLt j hj
    have hcol := hCol_eq_view hkl (dedupIdx idxsH hIdxsHLt) ωH datH cH T hTrows hrowsEq hcols hcan (dedupFind idxsH j hj)
    rw [hjEq] at hcol
    rw [hcol, hsalts j (hIdxsHLt j hj)]
  unfold hOpenRecon
  rw [hV, hP, hC]

end HPcsView

/-! ## 5. Level-2 Segment Builders (`MOpenPub`, `MaskOpening`, `SlotProof`, `codeFuns`) -/

section Level2ViewBuilders

/-- `Link.maskPoly` on `mRowKOf (shdSegNS s) (packSegMA s c2)` equals `Hiding.cfsEval (c2.1.1 t)` verbatim! -/
theorem maskPoly_packSegMA_eq_cfsEval (s : Fin 28) (c2 : SegL2Coins GF shdP_K (shdP_L2Spec s))
    (t : Fin (shdSegNS s)) :
    Link.maskPoly (mRowKOf (shdSegNS s) (packSegMA s c2)) t.val
        ((shdP_L2Spec s).n t + 1) ((shdP_L2Spec s).d t)
      = Hiding.cfsEval (c2.1.1 t) := by
  have hd1 := (shdP_L2_slot_bounds s t).1
  have hL : shdP_slotMaskLen s t = ((shdP_L2Spec s).n t + 1) * (shdP_L2Spec s).d t + 2 := rfl
  have hL512 : shdP_slotMaskLen s t ≤ 512 := by have := (shdP_L2_slot_bounds s t).2.2.2; omega
  have hmRow : ∀ j < shdP_slotMaskLen s t,
      mRowKOf (shdSegNS s) (packSegMA s c2) t.val j = cfsCoefAt hd1 (c2.1.1 t) j := by
    intro j hj
    unfold mRowKOf
    rw [dite_eq_left ⟨t.isLt, by omega⟩]
    unfold packSegMA
    dsimp only
    rw [dite_eq_left hj, toK_ofK shdP_U shdP_hbij]
  funext x
  unfold Link.maskPoly Hiding.cfsEval
  have h0 := hmRow 0 (by omega)
  have h1 := hmRow 1 (by omega)
  rw [h0, h1]
  simp only [cfsCoefAt, ↓reduceIte, show (1 : ℕ) ≠ 0 by omega]
  congr 1
  refine Finset.sum_congr rfl fun i _ => Finset.sum_congr rfl fun e _ => ?_
  have hidxLt : 2 + i.val * (shdP_L2Spec s).d t + e.val < shdP_slotMaskLen s t := by
    have hi := i.isLt; have he := e.isLt
    calc 2 + i.val * (shdP_L2Spec s).d t + e.val
        < 2 + i.val * (shdP_L2Spec s).d t + (shdP_L2Spec s).d t := Nat.add_lt_add_left he _
      _ = 2 + (i.val + 1) * (shdP_L2Spec s).d t := by ring
      _ ≤ 2 + ((shdP_L2Spec s).n t + 1) * (shdP_L2Spec s).d t := by
          have := Nat.mul_le_mul_right ((shdP_L2Spec s).d t) (show i.val + 1 ≤ (shdP_L2Spec s).n t + 1 by omega)
          omega
      _ = shdP_slotMaskLen s t := by omega
  rw [hmRow _ hidxLt]
  unfold cfsCoefAt
  have hsub : 2 + i.val * (shdP_L2Spec s).d t + e.val - 2 < ((shdP_L2Spec s).n t + 1) * (shdP_L2Spec s).d t := by omega
  simp only [show 2 + i.val * (shdP_L2Spec s).d t + e.val ≠ 0 by omega,
    show 2 + i.val * (shdP_L2Spec s).d t + e.val ≠ 1 by omega, ↓reduceIte, dite_eq_left hsub]
  have hdiv : (2 + i.val * (shdP_L2Spec s).d t + e.val - 2) / (shdP_L2Spec s).d t = i.val := by
    rw [show 2 + i.val * (shdP_L2Spec s).d t + e.val - 2 = e.val + i.val * (shdP_L2Spec s).d t by omega,
      Nat.add_mul_div_right _ _ (by omega), Nat.div_eq_of_lt e.isLt, Nat.zero_add]
  have hmod : (2 + i.val * (shdP_L2Spec s).d t + e.val - 2) % (shdP_L2Spec s).d t = e.val := by
    rw [show 2 + i.val * (shdP_L2Spec s).d t + e.val - 2 = e.val + i.val * (shdP_L2Spec s).d t by omega,
      Nat.add_mul_mod_self_right, Nat.mod_eq_of_lt e.isLt]
  refine congrArg₂ (· * ·) ?_ rfl
  exact congrArg₂ (c2.1.1 t).2.2 (Fin.ext hdiv) (Fin.ext hmod)

theorem cubeSum_maskPoly_packSegMA_eq_cfsTotal (s : Fin 28) (c2 : SegL2Coins GF shdP_K (shdP_L2Spec s))
    (t : Fin (shdSegNS s)) :
    cubeSum (Link.maskPoly (mRowKOf (shdSegNS s) (packSegMA s c2)) t.val
      ((shdP_L2Spec s).n t + 1) ((shdP_L2Spec s).d t)) = Hiding.cfsTotal (c2.1.1 t) := by
  rw [maskPoly_packSegMA_eq_cfsEval s c2 t, cubeSum_cfsEval]

/-- Construct `Hiding.MOpenPub` for segment `s : Fin 28` from `v`-only `(fs, θ, rs, idxs)`. -/
noncomputable def segMOpenPub (s : Fin 28) (fs : List Exec.Block.MaskFunctional)
    (θ : Fp2) (rs : List Fp2) (idxs : List ℕ) (hIdxsLt : ∀ j ∈ idxs, j < 2 ^ 12) :
    Hiding.MOpenPub GF 512 (shdSegNS s) 256 (nodupCols idxs).length :=
  let e := Equiv.ofBijective (Hiding.fp2 shdP_U) shdP_hbij
  { y := fun i => (rootFp 9).toGF ^ i.val
    π := fun t => Hiding.mPadPos (shdP_L2_slot_bounds s t).2.2.2
    Wre := fun t j => (e.symm (mW 1 (wtOf shdP_U (fs.map toMF) (shdSegNS s)) (θ.toK shdP_U) t j)).1
    Wim := fun t j => (e.symm (mW 1 (wtOf shdP_U (fs.map toMF) (shdSegNS s)) (θ.toK shdP_U) t j)).2
    ρa := fun t k => e.symm ((rs.getD (2 * t.val + if k then 0 else 1) Fp2.zero).toK shdP_U)
    ρb := fun k => e.symm ((rs.getD (2 * shdSegNS s + if k then 0 else 1) Fp2.zero).toK shdP_U)
    x := fun q => (7 : GF) * (rootFp 12).toGF ^ (dedupIdx idxs hIdxsLt q).val }

/-- All public domain & pad-reachability obligations (`hm`, `hmF`, `hy`, `hsum`, `hpad`) of `segMOpenPub`,
discharged uniformly from `shdP_M_pub_facts`! -/
theorem segMOpenPub_facts (s : Fin 28) (fs : List Exec.Block.MaskFunctional)
    (θ : Fp2) (rs : List Fp2) (idxs : List ℕ) (hIdxsLen : idxs.length = 256)
    (hIdxsLt : ∀ j ∈ idxs, j < 2 ^ 12) :
    let P := segMOpenPub s fs θ rs idxs hIdxsLt
    (0 < 512)
    ∧ ((512 : GF) ≠ 0)
    ∧ Function.Injective P.y
    ∧ (∀ j < 2 * 512, ∑ i, P.y i ^ j = if j = 0 ∨ j = 512 then (512 : GF) else 0)
    ∧ (∀ t (v : Fin 512 → GF), ∃ g : Fin 256 → GF,
        ∀ q, (Lagrange.interpolate Finset.univ P.y (v - Hiding.placePads (P.π t) g)).eval (P.x q) = 0) := by
  obtain ⟨hm, hmF, hy, hsum, _, _, hpadAll⟩ := shdP_M_pub_facts
  refine ⟨hm, hmF, hy, hsum, fun t v => ?_⟩
  have hkq : (nodupCols idxs).length ≤ 256 := by rw [← hIdxsLen]; exact nodupCols_length_le idxs
  exact hpadAll (shdP_L2_slot_bounds s t).2.2.2 hkq (dedupIdx idxs hIdxsLt) v

/-- `hW` of `ShdSegL2Data`: if every functional term `(t', w)` in `fs` has `w.length ≤ shdP_slotMaskLen s t'`,
then `P.Wre t (P.π t l) = 0 ∧ P.Wim t (P.π t l) = 0` for all `t, l`. -/
theorem segMOpenPub_hW (s : Fin 28) (fs : List Exec.Block.MaskFunctional)
    (hLen : ∀ f ∈ fs, ∀ tm ∈ f.terms, ∀ hlt : tm.1 < shdSegNS s, tm.2.length ≤ shdP_slotMaskLen s ⟨tm.1, hlt⟩)
    (θ : Fp2) (rs : List Fp2) (idxs : List ℕ) (hIdxsLt : ∀ j ∈ idxs, j < 2 ^ 12) :
    let P := segMOpenPub s fs θ rs idxs hIdxsLt
    ∀ (t : Fin (shdSegNS s)) (l : Fin 256), P.Wre t (P.π t l) = 0 ∧ P.Wim t (P.π t l) = 0 := by
  intro P t l
  have hmw0 : mW 1 (wtOf shdP_U (fs.map toMF) (shdSegNS s)) (θ.toK shdP_U) t (P.π t l) = 0 := by
    unfold mW
    refine Finset.sum_eq_zero fun i _ => ?_
    have hf : wtOf shdP_U (fs.map toMF) (shdSegNS s) i t (P.π t l) = 0 := by
      unfold wtOf fwt
      have hfi : (fs.map toMF).get i = toMF (fs[i.val]'(by simpa using i.isLt)) := by
        simp [List.get_eq_getElem]
      rw [hfi]
      simp only [toMF]
      have hts : ∀ ts : List (ℕ × List Fp2),
          (∀ tm ∈ ts, ∀ hlt : tm.1 < shdSegNS s, tm.2.length ≤ shdP_slotMaskLen s ⟨tm.1, hlt⟩) →
          (ts.map fun tm => if tm.1 = t.val then (tm.2.getD (P.π t l).val Fp2.zero).toK shdP_U else 0).sum = 0 := by
        intro ts
        induction ts with
        | nil => intro _; rfl
        | cons tm rest ih =>
          intro htm
          simp only [List.map_cons, List.sum_cons]
          rw [ih (fun x hx => htm x (List.mem_cons_of_mem _ hx)), add_zero]
          by_cases heq : tm.1 = t.val
          · rw [ite_eq_left heq]
            have hle := htm tm List.mem_cons_self (by omega)
            have hpi : (P.π t l).val = shdP_slotMaskLen s t + l.val := rfl
            have hge : tm.2.length ≤ (P.π t l).val := by
              have hteq : (⟨tm.1, by omega⟩ : Fin (shdSegNS s)) = t := Fin.ext heq
              rw [hteq] at hle; omega
            rw [List.getD_eq_getElem?_getD, List.getElem?_eq_none hge, Option.getD_none, Fp2.toK_zero]
          · exact ite_eq_right heq
      exact hts _ (hLen _ (List.getElem_mem (by simpa using i.isLt)))
    rw [hf, mul_zero]
  have hpair : (Equiv.ofBijective (Hiding.fp2 shdP_U) shdP_hbij).symm (0 : shdP_K) = (0, 0) := by
    apply (Equiv.ofBijective (Hiding.fp2 shdP_U) shdP_hbij).injective
    rw [Equiv.apply_symm_apply]
    simp [Equiv.ofBijective, Hiding.fp2]
  dsimp only [P, segMOpenPub] at hmw0 ⊢
  rw [hmw0, hpair]
  exact ⟨rfl, rfl⟩

/-- **`hlay` of `ShdSegL2Data`**: when `fs` has the same length as `codeFuns (shdSegNS s) (shdSegKind s) (shdSegHosts hc s)`
and each functional `fs[i]` evaluates on `mRowKOf` to `mfMask c ρ (codeFunsAt ... i) a`, `segMOpenPub` satisfies `hlay`! -/
theorem segMOpenPub_hlay (s : Fin 28) (hc : ShdHostCoeffs shdP_K)
    (c : Fin (shdSegNS s) → shdP_K) (ρ : (t : Fin (shdSegNS s)) → Fin ((shdP_L2Spec s).n t + 1) → shdP_K)
    (fs : List Exec.Block.MaskFunctional)
    (hLen : fs.length = (codeFuns (shdSegNS s) (shdSegKind s) (shdSegHosts hc s)).length)
    (hTermLt : ∀ f ∈ fs, ∀ tm ∈ f.terms, tm.1 < shdSegNS s)
    (hEach : ∀ (a : (t : Fin (shdSegNS s)) → Hiding.CfsCoeffs shdP_K ((shdP_L2Spec s).n t) ((shdP_L2Spec s).d t))
        (i : Fin (codeFuns (shdSegNS s) (shdSegKind s) (shdSegHosts hc s)).length),
        let f := fs[i.val]'(by omega)
        let aCoeffs := packSegMA s ((a, (fun _ _ _ => 0, fun _ _ => 0, fun _ _ => 0)), fun _ => zeroDig)
        (f.terms.map (Block.mdot shdP_U (mRowKOf (shdSegNS s) aCoeffs) 512)).sum
          = mfMask c ρ (codeFunsAt (shdSegNS s) (shdSegKind s) (shdSegHosts hc s) i) a)
    (θ : Fp2) (rs : List Fp2) (idxs : List ℕ) (hIdxsLt : ∀ j ∈ idxs, j < 2 ^ 12) :
    let P := segMOpenPub s fs θ rs idxs hIdxsLt
    ∀ a, ∑ t : Fin (shdSegNS s), ∑ j : Fin 512,
        Hiding.fp2 shdP_U (segMaskW s a t true j, segMaskW s a t false j)
          * Hiding.fp2 shdP_U (P.Wre t j, P.Wim t j)
      = mfComb (θ.toK shdP_U) (codeFunsAt (shdSegNS s) (shdSegKind s) (shdSegHosts hc s)) c ρ a := by
  intro P a
  let c2zero : SegL2Coins GF shdP_K (shdP_L2Spec s) :=
    ((a, (fun _ _ _ => 0, fun _ _ => 0, fun _ _ => 0)), fun _ => zeroDig)
  let aCoeffs := packSegMA s c2zero
  let Mzero := mkMTable (shdSegNS s) aCoeffs (fun _ => 0) (fun _ => 0) (fun _ => 0) (fun _ => 0) (fun _ => zeroDig)
  have hW : ∀ t j, Hiding.fp2 shdP_U (P.Wre t j, P.Wim t j)
      = mW 1 (wtOf shdP_U (fs.map toMF) (shdSegNS s)) (θ.toK shdP_U) t j := by
    intro t j
    exact (Equiv.ofBijective (Hiding.fp2 shdP_U) shdP_hbij).apply_symm_apply _
  have hMA : ∀ t j, Hiding.fp2 shdP_U (segMaskW s a t true j, segMaskW s a t false j)
      = (mA shdP_U Mzero (shdSegNS s) t).eval (mPts (algebraMap GF shdP_K (rootFp 9).toGF) j) := by
    intro t j
    rw [mkMTable_mA_eval]
    unfold aCoeffs packSegMA segMaskW
    dsimp only [c2zero]
    by_cases h1 : j.val < shdP_slotMaskLen s t
    · rw [ite_eq_left h1, ite_eq_left h1, dite_eq_left h1]
      simp only [↓reduceIte, Bool.false_eq_true, Fp2.toK]
    · rw [ite_eq_right h1, ite_eq_right h1, dite_eq_right h1]
      split_ifs <;> (simp only [Hiding.fp2, Fp2.toK, Fp.toGF_ofGF, Fp2.zero, Fp.zero]; try simp [Fp.toGF])
  simp_rw [hW, hMA]
  unfold mW mfComb
  have hswap' :
      ∑ t : Fin (shdSegNS s), ∑ j : Fin 512,
          (mA shdP_U Mzero (shdSegNS s) t).eval (mPts (algebraMap GF shdP_K (rootFp 9).toGF) j) *
            ∑ i : Fin (fs.map toMF).length,
              (θ.toK shdP_U) ^ (i.val + 1) * wtOf shdP_U (fs.map toMF) (shdSegNS s) i t j
      = ∑ i : Fin (fs.map toMF).length, (θ.toK shdP_U) ^ (i.val + 1) *
          ∑ t : Fin (shdSegNS s), ∑ j : Fin 512,
            wtOf shdP_U (fs.map toMF) (shdSegNS s) i t j *
              (mA shdP_U Mzero (shdSegNS s) t).eval (mPts (algebraMap GF shdP_K (rootFp 9).toGF) j) := by
    calc ∑ t : Fin (shdSegNS s), ∑ j : Fin 512,
            (mA shdP_U Mzero (shdSegNS s) t).eval (mPts (algebraMap GF shdP_K (rootFp 9).toGF) j) *
              ∑ i : Fin (fs.map toMF).length,
                (θ.toK shdP_U) ^ (i.val + 1) * wtOf shdP_U (fs.map toMF) (shdSegNS s) i t j
        = ∑ t : Fin (shdSegNS s), ∑ i : Fin (fs.map toMF).length, ∑ j : Fin 512,
            (θ.toK shdP_U) ^ (i.val + 1) *
              (wtOf shdP_U (fs.map toMF) (shdSegNS s) i t j *
                (mA shdP_U Mzero (shdSegNS s) t).eval (mPts (algebraMap GF shdP_K (rootFp 9).toGF) j)) := by
          refine Finset.sum_congr rfl fun t _ => ?_
          simp_rw [Finset.mul_sum]
          rw [Finset.sum_comm]
          refine Finset.sum_congr rfl fun i _ => Finset.sum_congr rfl fun j _ => by ring
      _ = ∑ i : Fin (fs.map toMF).length, ∑ t : Fin (shdSegNS s), ∑ j : Fin 512,
            (θ.toK shdP_U) ^ (i.val + 1) *
              (wtOf shdP_U (fs.map toMF) (shdSegNS s) i t j *
                (mA shdP_U Mzero (shdSegNS s) t).eval (mPts (algebraMap GF shdP_K (rootFp 9).toGF) j)) :=
          Finset.sum_comm
      _ = _ := by
          refine Finset.sum_congr rfl fun i _ => ?_
          simp_rw [← Finset.mul_sum]
  rw [hswap']
  have hlenMap : (fs.map toMF).length = (codeFuns (shdSegNS s) (shdSegKind s) (shdSegHosts hc s)).length := by
    rw [List.length_map, hLen]
  refine Fintype.sum_equiv (finCongr hlenMap) _ _ fun i => ?_
  have hiLt : i.val < fs.length := by simpa [List.length_map] using i.isLt
  refine congrArg₂ (· * ·) (by simp [finCongr]) ?_
  have hfi : (fs.map toMF).get i = toMF fs[i.val] := by
    rw [List.get_eq_getElem, List.getElem_map]
  have hwt : ∀ t (j : Fin 512), wtOf shdP_U (fs.map toMF) (shdSegNS s) i t j
      = fwt shdP_U (toMF ⟨fs[i.val].terms, fs[i.val].value⟩) t j := fun t j => by
    unfold wtOf; rw [hfi]
  have hmdot :
      ∑ t : Fin (shdSegNS s), ∑ j : Fin 512,
          fwt shdP_U (toMF ⟨fs[i.val].terms, fs[i.val].value⟩) t j
            * (mA shdP_U Mzero (shdSegNS s) t).eval (mPts (algebraMap GF shdP_K (rootFp 9).toGF) j)
        = (fs[i.val].terms.map (Block.mdot shdP_U (mRowKOf (shdSegNS s) aCoeffs) 512)).sum :=
    mTrue_terms_mdot (shdSegNS s) aCoeffs (fun _ => 0) (fun _ => 0) (fun _ => 0) (fun _ => 0) (fun _ => zeroDig)
      fs[i.val].terms fs[i.val].value (hTermLt _ (List.getElem_mem hiLt))
  have hsumEq :
      ∑ t : Fin (shdSegNS s), ∑ j : Fin 512,
          wtOf shdP_U (fs.map toMF) (shdSegNS s) i t j *
            (mA shdP_U Mzero (shdSegNS s) t).eval (mPts (algebraMap GF shdP_K (rootFp 9).toGF) j)
        = (fs[i.val].terms.map (Block.mdot shdP_U (mRowKOf (shdSegNS s) aCoeffs) 512)).sum :=
    (Finset.sum_congr rfl fun t _ => Finset.sum_congr rfl fun j _ =>
      congrArg (· * _) (hwt t j)).trans hmdot
  exact hsumEq.trans (hEach a (finCongr hlenMap i))

/-- Reconstruct a single `(2 * S + 4)`-row `M` column at deduplicated opened index `q` from `Hiding.MView`. -/
def mColFromView {S qOpen : ℕ} (mv : Hiding.MView GF 512 S qOpen) (q : Fin qOpen) : List Fp :=
  (List.range (2 * S + 4)).map fun i =>
    if h1 : i < 2 * S then Fp.ofGF (mv.2.2.1 ⟨i / 2, by omega⟩ (decide (i % 2 = 0)) q)
    else if i = 2 * S then Fp.ofGF (mv.2.2.2.1 true q)
    else if i = 2 * S + 1 then Fp.ofGF (mv.2.2.2.1 false q)
    else if i = 2 * S + 2 then Fp.ofGF (mv.2.2.2.2 true q)
    else Fp.ofGF (mv.2.2.2.2 false q)

/-- Pure view-and-`v` reconstruction of segment `s`'s `Exec.Block.MaskOpening`. -/
noncomputable def segMOpenRecon (s : Fin 28) (idxs : List ℕ) (hIdxsLt : ∀ j ∈ idxs, j < 2 ^ 12)
    (treeM : MerkleLevels 12)
    (mv : Hiding.MView GF 512 (shdSegNS s) (nodupCols idxs).length)
    (saltM : Fin (2 ^ 12) → Dig) : Exec.Block.MaskOpening :=
  let qw := List.ofFn fun k : Fin (2 * 512) => ⟨Fp.ofGF (mv.1 k).1, Fp.ofGF (mv.1 k).2⟩
  let pw := List.ofFn fun k : Fin (2 * 512) => ⟨Fp.ofGF (mv.2.1 k).1, Fp.ofGF (mv.2.1 k).2⟩
  let cols := idxs.attach.map fun ⟨j, hj⟩ =>
    ofOCol (j, mColFromView mv (dedupFind idxs j hj), saltM ⟨j, hIdxsLt j hj⟩, treeM.pathD j)
  ⟨qw, pw, cols⟩

private theorem polyWords_eq_of_coeff (p : shdP_K[X]) (f : Fin (2 * 512) → GF × GF)
    (hf : ∀ i : Fin 1024, p.coeff i.val = Hiding.fp2 shdP_U (f i)) :
    polyWords shdP_U shdP_hbij p = List.ofFn fun k : Fin (2 * 512) => ⟨Fp.ofGF (f k).1, Fp.ofGF (f k).2⟩ := by
  have hm1024 : 2 * mMsg = 2 * 512 := rfl
  have hlen : (polyWords shdP_U shdP_hbij p).length = 2 * 512 := (polyWords_length shdP_U shdP_hbij p).trans hm1024
  refine List.ext_getElem (by rw [hlen, List.length_ofFn]) fun k hk1 hk2 => ?_
  have hk2m : k < 2 * mMsg := (polyWords_length shdP_U shdP_hbij p) ▸ hk1
  have hk512 : k < 2 * 512 := hlen ▸ hk1
  simp only [List.getElem_ofFn]
  have hcan : ((polyWords shdP_U shdP_hbij p)[k]'hk1).Canon :=
    polyWords_canon shdP_U shdP_hbij p _ (List.getElem_mem hk1)
  have hcanR : (⟨Fp.ofGF (f ⟨k, hk512⟩).1, Fp.ofGF (f ⟨k, hk512⟩).2⟩ : Fp2).Canon :=
    ⟨Fp.ofGF_canon _, Fp.ofGF_canon _⟩
  refine Fp2.toK_injective shdP_U shdP_hU hcan hcanR ?_
  have hget : (polyWords shdP_U shdP_hbij p)[k]'hk1 = (polyWords shdP_U shdP_hbij p).getD k Fp2.zero := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hk1, Option.getD_some]
  rw [hget, polyWords_toK shdP_U shdP_hbij p k hk2m, hf ⟨k, hk512⟩]
  simp [Fp2.toK, Hiding.fp2, Fp.toGF_ofGF]

private theorem mCol_eq_mColFromView_of_rows {S qOpen : ℕ}
    (pt : ℕ → Fp) (M : MTable) (mv : Hiding.MView GF 512 S qOpen)
    (j : ℕ) (q : Fin qOpen) (x : GF) (hpt : (pt j).toGF = x)
    (hA : ∀ (t : Fin S) (b : Bool), (M.row (2 * t.val + if b then 0 else 1)).eval x = mv.2.2.1 t b q)
    (hB : ∀ b : Bool, (M.row (2 * S + if b then 0 else 1)).eval x = mv.2.2.2.1 b q)
    (hU : ∀ b : Bool, (M.row (2 * S + 2 + if b then 0 else 1)).eval x = mv.2.2.2.2 b q) :
    mCol S pt M j = mColFromView mv q := by
  unfold mCol mColFromView
  refine List.ext_getElem (by simp) fun i hi1 hi2 => ?_
  simp only [List.length_map, List.length_range] at hi1
  simp only [List.getElem_map, List.getElem_range]
  rw [hpt]
  by_cases h1 : i < 2 * S
  · rw [dite_eq_left h1]
    have heq : 2 * (i / 2) + (if decide (i % 2 = 0) then 0 else 1) = i := by
      by_cases hm : i % 2 = 0 <;> simp [hm] <;> omega
    have hrow := hA ⟨i / 2, by omega⟩ (decide (i % 2 = 0))
    dsimp only at hrow
    rw [heq] at hrow
    rw [hrow]
  · rw [dite_eq_right h1]
    by_cases h2 : i = 2 * S
    · rw [ite_eq_left h2, h2]
      have hrow := hB true; simp only [↓reduceIte, Nat.add_zero] at hrow; rw [hrow]
    · rw [ite_eq_right h2]
      by_cases h3 : i = 2 * S + 1
      · rw [ite_eq_left h3, h3]
        have hrow := hB false; simp only [Bool.false_eq_true, ↓reduceIte] at hrow; rw [hrow]
      · rw [ite_eq_right h3]
        by_cases h4 : i = 2 * S + 2
        · rw [ite_eq_left h4, h4]
          have hrow := hU true; simp only [↓reduceIte, Nat.add_zero] at hrow; rw [hrow]
        · rw [ite_eq_right h4]
          have h5 : i = 2 * S + 2 + 1 := by omega
          rw [h5]
          have hrow := hU false; simp only [Bool.false_eq_true, ↓reduceIte] at hrow; rw [hrow]

private theorem segMOpen_of_mOpenView_aux (s : Fin 28)
    (idxs : List ℕ) (hIdxsLt : ∀ j ∈ idxs, j < 2 ^ 12) (treeM : MerkleLevels 12)
    (M : MTable) (mv : Hiding.MView GF 512 (shdSegNS s) (nodupCols idxs).length)
    (saltM : Fin (2 ^ 12) → Dig) (q p : shdP_K[X])
    (hq : ∀ i : Fin 1024, q.coeff i.val = Hiding.fp2 shdP_U (mv.1 i))
    (hp : ∀ i : Fin 1024, p.coeff i.val = Hiding.fp2 shdP_U (mv.2.1 i))
    (hcol : ∀ j (hj : j ∈ idxs),
      mCol (shdSegNS s) (cosetPt (rootFp 12)) M j = mColFromView mv (dedupFind idxs j hj))
    (hsalt : ∀ j (hj : j ∈ idxs), M.salts j = saltM ⟨j, hIdxsLt j hj⟩) :
    (⟨polyWords shdP_U shdP_hbij q, polyWords shdP_U shdP_hbij p,
      idxs.map (fun j => ofOCol (j, mCol (shdSegNS s) (cosetPt (rootFp 12)) M j, M.salts j, treeM.pathD j))⟩
        : Exec.Block.MaskOpening)
      = segMOpenRecon s idxs hIdxsLt treeM mv saltM := by
  have hQ := polyWords_eq_of_coeff q mv.1 hq
  have hP := polyWords_eq_of_coeff p mv.2.1 hp
  have hC : idxs.map (fun j => ofOCol (j, mCol (shdSegNS s) (cosetPt (rootFp 12)) M j, M.salts j, treeM.pathD j))
      = idxs.attach.map fun ⟨j, hj⟩ =>
          ofOCol (j, mColFromView mv (dedupFind idxs j hj), saltM ⟨j, hIdxsLt j hj⟩, treeM.pathD j) := by
    rw [← List.attach_map_val]
    refine List.map_congr_left fun ⟨j, hj⟩ _ => ?_
    rw [hcol j hj, hsalt j hj]
  unfold segMOpenRecon
  rw [hQ, hP, hC]

/-- **Exact `zkBMaskFixedProg` reconstruction for segment `s : Fin 28`** from `(mv, c2.2)` and `v`-only data! -/
theorem segMOpen_of_mOpenView (s : Fin 28) (c2 : SegL2Coins GF shdP_K (shdP_L2Spec s))
    (fs : List Exec.Block.MaskFunctional) (θ : Fp2) (rs : List Fp2)
    (idxs : List ℕ) (hIdxsLt : ∀ j ∈ idxs, j < 2 ^ 12) (treeM : MerkleLevels 12) :
    let P := segMOpenPub s fs θ rs idxs hIdxsLt
    let M := mkMTable (shdSegNS s) (packSegMA s c2) (c2.1.2.2.1 true) (c2.1.2.2.1 false)
      (c2.1.2.2.2 true) (c2.1.2.2.2 false) (extSalt c2.2)
    let mv := Hiding.mOpenView (7 : GF) P (by norm_num) (segMaskW s c2.1.1) c2.1.2
    let qw := polyWords shdP_U shdP_hbij (qPoly shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) M (shdSegNS s) (fs.map toMF) (θ.toK shdP_U))
    let pw := polyWords shdP_U shdP_hbij (pPoly shdP_U M (shdSegNS s) rs)
    let cols := idxs.map (fun j => ofOCol (j, mCol (shdSegNS s) (cosetPt (rootFp 12)) M j, M.salts j, treeM.pathD j))
    (⟨qw, pw, cols⟩ : Exec.Block.MaskOpening) = segMOpenRecon s idxs hIdxsLt treeM mv c2.2 := by
  dsimp only
  have hqp := qPoly_pPoly_eq_mOpenView s c2 (segMOpenPub s fs θ rs idxs hIdxsLt) rfl (fun _ => rfl) fs θ rs
    (fun t j => (Equiv.ofBijective (Hiding.fp2 shdP_U) shdP_hbij).apply_symm_apply _)
    (fun t k => (Equiv.ofBijective (Hiding.fp2 shdP_U) shdP_hbij).apply_symm_apply _)
    (fun k => (Equiv.ofBijective (Hiding.fp2 shdP_U) shdP_hbij).apply_symm_apply _)
  dsimp only at hqp
  obtain ⟨hMA, hMB, hMU⟩ := mkMTable_row_eq_mOpen s c2 (segMOpenPub s fs θ rs idxs hIdxsLt) rfl (fun _ => rfl)
  refine segMOpen_of_mOpenView_aux s idxs hIdxsLt treeM _ _ c2.2 _ _ hqp.1 hqp.2 ?_
    (fun j hj => extSalt_lt c2.2 (hIdxsLt j hj))
  intro j hj
  have hjLt := hIdxsLt j hj
  have hj64 : j < 2 ^ 64 := lt_of_lt_of_le hjLt (by norm_num)
  have hpt : (cosetPt (rootFp 12) j).toGF = (segMOpenPub s fs θ rs idxs hIdxsLt).x (dedupFind idxs j hj) := by
    rw [cosetPt_rootFp_toGF 12 j hj64]
    dsimp only [segMOpenPub]
    rw [dedupIdx_dedupFind idxs hIdxsLt j hj]
  exact mCol_eq_mColFromView_of_rows (cosetPt (rootFp 12)) _ _ j (dedupFind idxs j hj)
    ((segMOpenPub s fs θ rs idxs hIdxsLt).x (dedupFind idxs j hj)) hpt
    (fun t b => congrArg (fun p : GF[X] => p.eval ((segMOpenPub s fs θ rs idxs hIdxsLt).x (dedupFind idxs j hj))) (hMA t b))
    (fun b => congrArg (fun p : GF[X] => p.eval ((segMOpenPub s fs θ rs idxs hIdxsLt).x (dedupFind idxs j hj))) (hMB b))
    (fun b => congrArg (fun p : GF[X] => p.eval ((segMOpenPub s fs θ rs idxs hIdxsLt).x (dedupFind idxs j hj))) (hMU b))

/-- Pure view-and-`v` reconstruction of one slot's `Exec.Block.SlotProof` (`scalar`, `rounds`, `terms`). -/
noncomputable def slotProofRecon {ns : ℕ} {n d : Fin ns → ℕ}
    (kind : Fin ns → Kind) (hosts : Fin ns → List (Fin ns × shdP_K))
    (c : Fin ns → shdP_K)
    (sv : (t : Fin ns) → shdP_K × (Fin (n t + 1) → Fin (d t + 1) → shdP_K) × shdP_K)
    (t : Fin ns) (tms : List Fp2) : Exec.Block.SlotProof :=
  let scalarK : shdP_K := match kind t with
    | .standalone => c t * (sv t).1
    | .priv => (sv t).1
    | .host => (sv t).1 - ((hosts t).map fun p => p.2 * (sv p.1).1).sum
  let rounds : List (List Fp2) :=
    List.ofFn fun j : Fin (n t + 1) =>
      List.ofFn fun u : Fin (d t + 1) => ofK shdP_U shdP_hbij (Hiding.peval ((sv t).2.1 j) (u.val : shdP_K))
  ⟨ofK shdP_U shdP_hbij scalarK, rounds, tms⟩

/-- **Exact `SlotProof.scalar` recovery from `slotView`** across all 3 slot kinds (`.standalone`, `.priv`, `.host`)! -/
theorem slotScalar_eq_slotProofRecon {ns : ℕ} {n d : Fin ns → ℕ}
    (kind : Fin ns → Kind) (hosts : Fin ns → List (Fin ns × shdP_K))
    (hdc : ∀ t, d t < ringChar shdP_K)
    (hhosted : ∀ t, kind t = .host → ∀ p ∈ hosts t, maskedOfKind (kind p.1) = true)
    (c : Fin ns → shdP_K) (ρ : (t : Fin ns) → Fin (n t + 1) → shdP_K)
    (f : (t : Fin ns) → (Fin (n t + 1) → shdP_K) → shdP_K) (hf : ∀ t, IndDegLE (d t) (f t))
    (hsumH : ∀ t, kind t = .host → cubeSum (f t) = ((hosts t).map fun p => p.2 * cubeSum (f p.1)).sum)
    (a : (t : Fin ns) → Hiding.CfsCoeffs shdP_K (n t) (d t)) (t : Fin ns) :
    let sv := fun u : Fin ns => slotView (maskedOfKind (kind u)) (honestCo (d u) (n u) (f u) (ρ u)) (c u) (ρ u) (a u)
    (match kind t with
      | .standalone => c t * Hiding.cfsTotal (a t)
      | .priv => cubeSum (f t) + c t * Hiding.cfsTotal (a t)
      | .host => c t * Hiding.cfsTotal (a t) - ((hosts t).map fun (p : Fin ns × shdP_K) => p.2 * (c p.1 * Hiding.cfsTotal (a p.1))).sum)
    = (match kind t with
      | .standalone => c t * (sv t).1
      | .priv => (sv t).1
      | .host => (sv t).1 - ((hosts t).map fun (p : Fin ns × shdP_K) => p.2 * (sv p.1).1).sum) := by
  intro sv
  cases hk : kind t with
  | standalone =>
    have hm : maskedOfKind (kind t) = false := by rw [hk]; rfl
    dsimp only [sv]; rw [slotView_false hm]; rfl
  | priv =>
    have hm : maskedOfKind (kind t) = true := by rw [hk]; rfl
    dsimp only [sv]; rw [slotView_true hm]
    show cubeSum (f t) + c t * Hiding.cfsTotal (a t) = roundSum (honestCo (d t) (n t) (f t) (ρ t) 0) + c t * Hiding.cfsTotal (a t)
    rw [honest_roundSum (hdc t) (n t) (f t) (ρ t) (hf t)]
  | host =>
    have hm : maskedOfKind (kind t) = true := by rw [hk]; rfl
    have hsumR : roundSum (honestCo (d t) (n t) (f t) (ρ t) 0) =
        ((hosts t).map fun p => p.2 * roundSum (honestCo (d p.1) (n p.1) (f p.1) (ρ p.1) 0)).sum := by
      rw [honest_roundSum (hdc t) (n t) (f t) (ρ t) (hf t), hsumH t hk]
      congr 1
      refine List.map_congr_left fun p _ => ?_
      rw [honest_roundSum (hdc p.1) (n p.1) (f p.1) (ρ p.1) (hf p.1)]
    exact hostScalar_of_views (fun u => maskedOfKind (kind u)) n d
      (fun u => honestCo (d u) (n u) (f u) (ρ u)) c ρ a t (hosts t) hm (hhosted t hk) hsumR

end Level2ViewBuilders

end ZK60.HonestShield
