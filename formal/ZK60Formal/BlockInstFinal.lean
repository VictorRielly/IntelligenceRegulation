/-
D63 lane L31 (2026-11-09), part 8: **the block's statement at the three profiles, with every premise this lane
discharges gone**: L28's bookkeeping premises (the profile, the fields, `hcnt`, `hRd`, the reading definitions; as
`BlockInstRung.lean`), the corrected evaluation interface (`SlotEvalN`, finding L31-1), and the mask half of the slot
polynomials (`F` is `maskedF` of a table side `Poly`, `SlotPolyInstEval.lean`).

* `maskedFX`: the masked slot polynomial over the mask table extracted for the statement's `M` root;
* `w16r2_rung_mask_facts`, `r13_rung_mask_facts`, `r13_shield_mask_facts`: every slot has a degree in `[1, 5]`, at
  least one variable, and its `(n + e)·d + 2` mask coefficients fit a mask row of 512;
* **`block_knowledge_final_w16r2`**, **`block_knowledge_final_r13`**, **`block_knowledge_final_r13_shield`**: for EVERY
  `q`, `Pr[BlockAcc ∧ sqN header = hdrSq ∧ ¬BlockSat] ≤ εsTarget q + εend`, at the W16R2 rung, the R13 rung and the
  Shieldstral T128 R13 block (the media app's classifier block).

**The premises that are left**, by name:
* the profile's definition: `hP : Link.IsRungW16 / IsRungR13 / IsShieldR13 P tag rowsOf` (the schedule, the group
  counts, the functional count, the opening fields);
* `define`'s commitment schedule `hdc : Link.DefCm P aC hC`, for any per-slot split `aC`, `hC` with the profile's totals
  `hsA`, `hsH` (`Link.aCntW16Rung` … with `Link.cnt_sums` are the splits the layouts give); and `hpolyC` (its
  polynomials return canonical words; `hpolyC_of_ir` for an IR-defined `define`);
* the table side `Poly` of the slot polynomials: `hPoly` (`SlotEvalN` with the zero `M` semantics: at an accepting
  slot whose claims are true, `Poly(ρ) = poly(vals)`) and `hdegP` (its individual degree is the slot's);
* the run level: the header's numbers `hh`, `hq`, the endpoint commitments' semantics `csE` and `hEnd`;
* public data: `Pb`, `Lay`, `B` (with `fams`, `hF`, `hW` at W16R2; `hW13` at R13), `h24`;
* L23's per-outcome algebra over the extracted planes `xtE`: the certified slot polynomials `spR`, `spH` with `hdgR`,
  `hdgH`; `hvR`, `hgdR`, `hvH`, `hgdH`; the lookup list `Alk`, `T`, `mlk` with `hN`, `he`, `hbr`, `hhr`.

The statements are generated from L28's (results/zk60_lean_l31_20261109/l31_mk_chain.py). Only `propext`,
`Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockInstChainN
import ZK60Formal.BlockInstRung

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-- **The masked slot polynomial over the mask table extracted for the statement's `M` root** (23 mask specs): `F` of
the block statements, from a table side `Poly`. -/
noncomputable abbrev maskedFX {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) {L : ℕ} (hL20 : 2 ^ 20 ≤ L)
    (P : BlockParams)
    (Poly : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) :
    Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K :=
  fun cu rt => maskedF U (Link.mRowX U 23 (Link.colsC tag L (Link.le64_of_le20 hL20) cu.2.1 rt.2.1)) P (Poly cu rt)

/-- The W16R2 rung's slots: degree at least `1`, at least one variable, the mask coefficients within a row of 512. -/
theorem w16r2_rung_mask_facts : ∀ k, k < 23 → 1 ≤ (W16R2.rungSlots.getD k (0, 0, 0)).2.2
    ∧ 0 < (W16R2.rungSlots.getD k (0, 0, 0)).1 + (W16R2.rungSlots.getD k (0, 0, 0)).2.1
    ∧ ((W16R2.rungSlots.getD k (0, 0, 0)).1 + (W16R2.rungSlots.getD k (0, 0, 0)).2.1)
        * (W16R2.rungSlots.getD k (0, 0, 0)).2.2 + 2 ≤ 512 := by
  decide

/-- The R13 rung's slots, likewise. -/
theorem r13_rung_mask_facts : ∀ k, k < 23 → 1 ≤ (R13.rungSlots.getD k (0, 0, 0)).2.2
    ∧ 0 < (R13.rungSlots.getD k (0, 0, 0)).1 + (R13.rungSlots.getD k (0, 0, 0)).2.1
    ∧ ((R13.rungSlots.getD k (0, 0, 0)).1 + (R13.rungSlots.getD k (0, 0, 0)).2.1)
        * (R13.rungSlots.getD k (0, 0, 0)).2.2 + 2 ≤ 512 := by
  decide

/-- The Shieldstral T128 R13 block's slots, likewise (at most `22·5 + 2 = 112` coefficients). -/
theorem r13_shield_mask_facts : ∀ k, k < 23 → 1 ≤ (R13.shieldSlots.getD k (0, 0, 0)).2.2
    ∧ 0 < (R13.shieldSlots.getD k (0, 0, 0)).1 + (R13.shieldSlots.getD k (0, 0, 0)).2.1
    ∧ ((R13.shieldSlots.getD k (0, 0, 0)).1 + (R13.shieldSlots.getD k (0, 0, 0)).2.1)
        * (R13.shieldSlots.getD k (0, 0, 0)).2.2 + 2 ≤ 512 := by
  decide

section Final

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

/-- **One W16R2 rung block's knowledge statement, with this lane's premises discharged** (D63 lane L31): L28's
bookkeeping premises, the corrected evaluation interface and the mask half of the slot polynomials. The premises left
are listed in this file's header. -/
theorem block_knowledge_final_w16r2 [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsRungW16 P tag rowsOf)
    (aC hC : List ℕ) (hdc : Link.DefCm P aC hC)
    (hsA : sumFrom (fun k => aC.getD k 0) 0 23 = 114) (hsH : sumFrom (fun k => hC.getD k 0) 0 23 + 1 = 47)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (Poly : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hPoly : ∀ cu rt, SlotEvalN U P (Link.csRungW16 U tag hL20 csE cu rt) (fun _ => 0) (Poly cu rt))
    (hdegP : ∀ cu rt k sn, IndDegLE (slotShape P k).2.2 (Poly cu rt k sn))
    (Pb : ZK60.Block.BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf) (B : ZK60.Layout.W16Pub S Pb Lay)
    (fams : List (ℕ × ℕ)) (hF : ZK60.Circuit.FamsOK fams) (hW : ZK60.Layout.W16Widths S fams) (h24 : S.h24 = true)
    (xtE : Cuts3 L → RootsO → ZK60.Layout.W16Data Ct Cw Cg Cj Cd Cf)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csRungW16 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    -- the four relation layers (certified slot polynomials) and their per-outcome algebra
    (spR : ℕ → Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgR : ∀ i, i < 4 → ∀ cu rt k h, k ∈ w16r2RelKs i → (spR i cu rt k h).dg ≤ 80)
    (hvR : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungW16 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc → ∀ i, i < 4 →
      (∀ j, j < i → SchedGd (w16r2DR P spR j) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      SchedVan U P (w16r2DR P spR i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs)
    (hgdR : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungW16 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      (∀ i, i < 4 → SchedGd (w16r2DR P spR i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)))
    -- the helper layer and LogUp
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hvH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungW16 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      SchedVan U P (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs)
    (hgdH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungW16 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      SchedGd (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 35153256)
    (hbr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungW16 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      ¬ ZK60.Layout.W16Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) fams →
      ∃ l, ∀ j, T j ≠ Alk (cutsOf key domain hs hL A G).1 l)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungW16 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X (Lay.dPos p))
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))))
      ≤ εsTarget q + εend := by
  have hbij := ZK60.Hiding.fp2_bijective hK2 hU seven_not_square
  have hlen23 : P.geom.slots.length = 23 := by rw [hP.hsl]; rfl
  have hfacts : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2
      ∧ 0 < (slotShape P k).1 + (slotShape P k).2.1
      ∧ ((slotShape P k).1 + (slotShape P k).2.1) * (slotShape P k).2.2 + 2 ≤ 512 := by
    intro k hk
    rw [hlen23] at hk
    have h1 := w16r2_rung_mask_facts k hk
    simp only [slotShape, hP.hsl]
    exact h1
  have hd1 : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 := fun k hk => (hfacts k hk).1
  exact block_knowledge_open_w16r2N U hU hK2 key domain hs hL hL64 hL20 P hP.hdr hP.hsl hP.htm
    (Link.profW16Rung P hP.hdr hP.hsl hP.hag hP.hhg tag hdrLen hdrSq hh hq) hh (maskedFX U tag hL20 P Poly)
    (Link.csRungW16 U tag hL20 csE) (Link.msRung U tag hL20) hpolyC
    (fun cu rt => maskedF_slotEvalN U hU hbij P _ _ _ 512 (Link.msXof_mlin U tag L (Link.le64_of_le20 hL20) 23 cu rt)
      (fun k hk => (hfacts k hk).2) (Poly cu rt) (hPoly cu rt))
    (fun cu rt k sn => maskedF_indDeg_all U _ P (Poly cu rt) hd1 (hdegP cu rt) k sn)
    Pb Lay B fams hF hW h24 xtE q A hA rfl rowsOf hP.hPm hP.hPp hP.hrA hP.hrH
    ⟨by show 8 * 320 ≤ L; omega, by show 8 * 202 ≤ L; omega, by show 8 * (2 * 23 + 4) ≤ L; omega⟩
    (by rw [hP.hnf]; norm_num) (by rw [hP.hnf]; norm_num)
    (fun G bga rs acc hacc => Link.hcnt_of_defCm P hdrLen key domain aC hC 114 47 23 hlen23 hsA hsH hdc G (A.run G)
      bga rs acc hacc.1)
    (tAccRd P hdrLen)
    (fun G bga rs acc hacc _ => by
      rw [accRd_slotTrace P hdrLen key domain hd1 G (A.run G) bga rs acc hacc.1]
      exact ⟨rfl, rfl, rfl⟩)
    (fun _ _ _ => rfl) (fun _ _ _ => rfl) (fun _ _ _ => rfl) εend hEnd spR hdgR hvR hgdR HGd spH hdgH hvH hgdH Alk T
    mlk hN he hbr hhr

/-- **One R13 rung block's knowledge statement, with this lane's premises discharged** (as
`block_knowledge_final_w16r2`, at R13). -/
theorem block_knowledge_final_r13 [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsRungR13 P tag rowsOf)
    (aC hC : List ℕ) (hdc : Link.DefCm P aC hC)
    (hsA : sumFrom (fun k => aC.getD k 0) 0 23 = 148) (hsH : sumFrom (fun k => hC.getD k 0) 0 23 + 1 = 55)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (Poly : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hPoly : ∀ cu rt, SlotEvalN U P (Link.csRungR13 U tag hL20 csE cu rt) (fun _ => 0) (Poly cu rt))
    (hdegP : ∀ cu rt k sn, IndDegLE (slotShape P k).2.2 (Poly cu rt k sn))
    (Pb : ZK60.Block.BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf) (B : ZK60.Layout.W16Pub S Pb Lay)
    {ls : ℕ} (hW13 : ZK60.Layout.R13.R13Windows S ls) (h24 : S.h24 = true)
    (xtE : Cuts3 L → RootsO → ZK60.Layout.R13.R13Data Ct Cw Cg Cj Cd Cf ls)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csRungR13 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    -- the four relation layers (certified slot polynomials) and their per-outcome algebra
    (spR : ℕ → Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgR : ∀ i, i < 4 → ∀ cu rt k h, k ∈ w16r2RelKs i → (spR i cu rt k h).dg ≤ 80)
    (hvR : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungR13 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc → ∀ i, i < 4 →
      (∀ j, j < i → SchedGd (w16r2DR P spR j) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      SchedVan U P (w16r2DR P spR i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs)
    (hgdR : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungR13 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      (∀ i, i < 4 → SchedGd (w16r2DR P spR i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      ZK60.Layout.R13.R13Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)))
    -- the helper layer and LogUp
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hvH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungR13 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      SchedVan U P (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs)
    (hgdH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungR13 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      SchedGd (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 35153256)
    (hbr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungR13 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      ZK60.Layout.R13.R13Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) →
      ¬ ZK60.Layout.R13.R13Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) →
      ∃ l, ∀ j, T j ≠ Alk (cutsOf key domain hs hL A G).1 l)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungR13 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X (Lay.dPos p))
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay ((xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).toW16 S)))
      ≤ εsTarget q + εend := by
  have hbij := ZK60.Hiding.fp2_bijective hK2 hU seven_not_square
  have hlen23 : P.geom.slots.length = 23 := by rw [hP.hsl]; rfl
  have hfacts : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2
      ∧ 0 < (slotShape P k).1 + (slotShape P k).2.1
      ∧ ((slotShape P k).1 + (slotShape P k).2.1) * (slotShape P k).2.2 + 2 ≤ 512 := by
    intro k hk
    rw [hlen23] at hk
    have h1 := r13_rung_mask_facts k hk
    simp only [slotShape, hP.hsl]
    exact h1
  have hd1 : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 := fun k hk => (hfacts k hk).1
  exact block_knowledge_open_r13N U hU hK2 key domain hs hL hL64 hL20 P hP.hdr hP.hsl hP.htm
    (Link.profR13Rung P hP.hdr hP.hsl hP.hag hP.hhg tag hdrLen hdrSq hh hq) hh (maskedFX U tag hL20 P Poly)
    (Link.csRungR13 U tag hL20 csE) (Link.msRung U tag hL20) hpolyC
    (fun cu rt => maskedF_slotEvalN U hU hbij P _ _ _ 512 (Link.msXof_mlin U tag L (Link.le64_of_le20 hL20) 23 cu rt)
      (fun k hk => (hfacts k hk).2) (Poly cu rt) (hPoly cu rt))
    (fun cu rt k sn => maskedF_indDeg_all U _ P (Poly cu rt) hd1 (hdegP cu rt) k sn)
    Pb Lay B hW13 h24 xtE q A hA rfl rowsOf hP.hPm hP.hPp hP.hrA hP.hrH
    ⟨by show 8 * 437 ≤ L; omega, by show 8 * 248 ≤ L; omega, by show 8 * (2 * 23 + 4) ≤ L; omega⟩
    (by rw [hP.hnf]; norm_num) (by rw [hP.hnf]; norm_num)
    (fun G bga rs acc hacc => Link.hcnt_of_defCm P hdrLen key domain aC hC 148 55 23 hlen23 hsA hsH hdc G (A.run G)
      bga rs acc hacc.1)
    (tAccRd P hdrLen)
    (fun G bga rs acc hacc _ => by
      rw [accRd_slotTrace P hdrLen key domain hd1 G (A.run G) bga rs acc hacc.1]
      exact ⟨rfl, rfl, rfl⟩)
    (fun _ _ _ => rfl) (fun _ _ _ => rfl) (fun _ _ _ => rfl) εend hEnd spR hdgR hvR hgdR HGd spH hdgH hvH hgdH Alk T
    mlk hN he hbr hhr

/-- **One Shieldstral T128 R13 block's knowledge statement, with this lane's premises discharged** (the media app's
classifier block; as `block_knowledge_final_r13`, at the Shieldstral schedule). -/
theorem block_knowledge_final_r13_shield [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsShieldR13 P tag rowsOf)
    (aC hC : List ℕ) (hdc : Link.DefCm P aC hC)
    (hsA : sumFrom (fun k => aC.getD k 0) 0 23 = 146) (hsH : sumFrom (fun k => hC.getD k 0) 0 23 + 1 = 54)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (Poly : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hPoly : ∀ cu rt, SlotEvalN U P (Link.csShieldR13 U tag hL20 csE cu rt) (fun _ => 0) (Poly cu rt))
    (hdegP : ∀ cu rt k sn, IndDegLE (slotShape P k).2.2 (Poly cu rt k sn))
    (Pb : ZK60.Block.BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf) (B : ZK60.Layout.W16Pub S Pb Lay)
    {ls : ℕ} (hW13 : ZK60.Layout.R13.R13Windows S ls) (h24 : S.h24 = true)
    (xtE : Cuts3 L → RootsO → ZK60.Layout.R13.R13Data Ct Cw Cg Cj Cd Cf ls)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csShieldR13 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    -- the four relation layers (certified slot polynomials) and their per-outcome algebra
    (spR : ℕ → Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgR : ∀ i, i < 4 → ∀ cu rt k h, k ∈ w16r2RelKs i → (spR i cu rt k h).dg ≤ 80)
    (hvR : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldR13 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc → ∀ i, i < 4 →
      (∀ j, j < i → SchedGd (w16r2DR P spR j) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      SchedVan U P (w16r2DR P spR i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs)
    (hgdR : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldR13 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      (∀ i, i < 4 → SchedGd (w16r2DR P spR i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      ZK60.Layout.R13.R13Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)))
    -- the helper layer and LogUp
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hvH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldR13 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      SchedVan U P (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs)
    (hgdH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldR13 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      SchedGd (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 35153256)
    (hbr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldR13 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      ZK60.Layout.R13.R13Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) →
      ¬ ZK60.Layout.R13.R13Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) →
      ∃ l, ∀ j, T j ≠ Alk (cutsOf key domain hs hL A G).1 l)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldR13 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X (Lay.dPos p))
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay ((xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).toW16 S)))
      ≤ εsTarget q + εend := by
  have hbij := ZK60.Hiding.fp2_bijective hK2 hU seven_not_square
  have hlen23 : P.geom.slots.length = 23 := by rw [hP.hsl]; rfl
  have hfacts : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2
      ∧ 0 < (slotShape P k).1 + (slotShape P k).2.1
      ∧ ((slotShape P k).1 + (slotShape P k).2.1) * (slotShape P k).2.2 + 2 ≤ 512 := by
    intro k hk
    rw [hlen23] at hk
    have h1 := r13_shield_mask_facts k hk
    simp only [slotShape, hP.hsl]
    exact h1
  have hd1 : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 := fun k hk => (hfacts k hk).1
  exact block_knowledge_open_r13_shieldN U hU hK2 key domain hs hL hL64 hL20 P hP.hdr hP.hsl hP.htm
    (Link.profR13Shield P hP.hdr hP.hsl hP.hag hP.hhg tag hdrLen hdrSq hh hq) hh (maskedFX U tag hL20 P Poly)
    (Link.csShieldR13 U tag hL20 csE) (Link.msRung U tag hL20) hpolyC
    (fun cu rt => maskedF_slotEvalN U hU hbij P _ _ _ 512 (Link.msXof_mlin U tag L (Link.le64_of_le20 hL20) 23 cu rt)
      (fun k hk => (hfacts k hk).2) (Poly cu rt) (hPoly cu rt))
    (fun cu rt k sn => maskedF_indDeg_all U _ P (Poly cu rt) hd1 (hdegP cu rt) k sn)
    Pb Lay B hW13 h24 xtE q A hA rfl rowsOf hP.hPm hP.hPp hP.hrA hP.hrH
    ⟨by show 8 * 4577 ≤ L; omega, by show 8 * 4390 ≤ L; omega, by show 8 * (2 * 23 + 4) ≤ L; omega⟩
    (by rw [hP.hnf]; norm_num) (by rw [hP.hnf]; norm_num)
    (fun G bga rs acc hacc => Link.hcnt_of_defCm P hdrLen key domain aC hC 146 54 23 hlen23 hsA hsH hdc G (A.run G)
      bga rs acc hacc.1)
    (tAccRd P hdrLen)
    (fun G bga rs acc hacc _ => by
      rw [accRd_slotTrace P hdrLen key domain hd1 G (A.run G) bga rs acc hacc.1]
      exact ⟨rfl, rfl, rfl⟩)
    (fun _ _ _ => rfl) (fun _ _ _ => rfl) (fun _ _ _ => rfl) εend hEnd spR hdgR hvR hgdR HGd spH hdgH hvH hgdH Alk T
    mlk hN he hbr hhr

end Final

end ZK60.Exec.Block
