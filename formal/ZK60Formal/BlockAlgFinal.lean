/-
D63 lane L36 (2026-11-09), part 5: **the block's knowledge statement at the three profiles with the relation layers'
algebra discharged** (L31's `block_knowledge_final_*` with `spR`, `hdgR`, `hvR`, `hgdR` gone, and `hvH` reduced to the
helper slots' named identities).

* `card_K_gt`: a field over Goldilocks has more than `78` elements (the certified host polynomials' side condition);
* `w16r2_rung_slot64`, `r13_rung_slot64`, `r13_shield_slot64`: every slot has fewer than `64` variables;
* **`alg_hvR`**: `hvR` for the certified polynomials `algSp`: layer 0 from the hosts' named identities (`FormAt`,
  through `accT_unmask`), layers 1 to 3 outright;
* **`alg_hvH`**: `hvH` for any helper polynomials that meet their named identities;
* **`block_knowledge_alg_w16r2`**: one W16R2 rung block. Against L31's final statement the premises `spR`, `hdgR`,
  `hvR`, `hgdR`, `hvH` are replaced by: the shape facts and tables (`AlgShape`, `AlgData`), the six hosts' named
  identities (`hform`), the helper slots' named identities (`hformH`), and the tables being `W16Rels`'s relation
  tables through onto encodings (`W16Spec`), at a layout whose token and head-dimension axes do not pad;
* **`block_knowledge_alg_r13`**, **`block_knowledge_alg_r13_shield`**: the R13 rung block and the Shieldstral T128 R13
  block (the media app's classifier block), likewise; the reindexing to `R13Rels` is the named premise `hrels`
  (`AlgGood` of the tables gives `R13Rels` of the extracted planes).

The premises left are listed in docs/zkmatrix-poc/ZK60_LEAN_L36_BLOCK_ALGEBRA_20261109.md §4. Only `propext`,
`Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockAlgRels

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-- A field over Goldilocks has more than `78` elements. -/
theorem card_K_gt (K : Type) [Field K] [Algebra GF K] [Fintype K] : 78 < Fintype.card K := by
  have h1 : Fintype.card GF ≤ Fintype.card K :=
    Fintype.card_le_of_injective _ (algebraMap GF K).injective
  have h2 : Fintype.card GF = gP := ZMod.card gP
  have h3 : 78 < gP := by norm_num
  omega

/-- The W16R2 rung's slots have fewer than `64` variables. -/
theorem w16r2_rung_slot64 : ∀ k, k < 23 →
    (W16R2.rungSlots.getD k (0, 0, 0)).1 + (W16R2.rungSlots.getD k (0, 0, 0)).2.1 < 64 := by
  decide

/-- The R13 rung's slots, likewise. -/
theorem r13_rung_slot64 : ∀ k, k < 23 →
    (R13.rungSlots.getD k (0, 0, 0)).1 + (R13.rungSlots.getD k (0, 0, 0)).2.1 < 64 := by
  decide

/-- The Shieldstral T128 R13 block's slots, likewise. -/
theorem r13_shield_slot64 : ∀ k, k < 23 →
    (R13.shieldSlots.getD k (0, 0, 0)).1 + (R13.shieldSlots.getD k (0, 0, 0)).2.1 < 64 := by
  decide

section HV

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ} {P : BlockParams}

/-- **`hvR` for the certified polynomials `algSp`** (generic in the profile). On an accepting outcome: layer 0 (the
hosts) vanishes at the drawn challenges by the unmasking and the hosts' named identities; layers 1, 2, 3 vanish once
the layers below hold their start claims, with no further premise. -/
theorem alg_hvR [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hdrLen : ℕ)
    (R : Cuts3 L → RootsO → ℕ → ℕ → K) (Wd : ℕ)
    (Poly : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hlin : ∀ cu rt, MLin U (msX cu rt) (R cu rt) Wd)
    (hN : ∀ k, k < P.geom.slots.length → 0 < (slotShape P k).1 + (slotShape P k).2.1
      ∧ (slotShape P k).1 + (slotShape P k).2.1 < 64
      ∧ ((slotShape P k).1 + (slotShape P k).2.1) * (slotShape P k).2.2 + 2 ≤ Wd)
    (A : OC (QB L) Dig (List Op × Core)) (sh : AlgShape P) (dt : AlgData K L sh) (hcard : 78 < Fintype.card K)
    (G : QB L → Dig) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc)
    (hT : AccT U key domain hs hL P hdrLen (fun cu rt => maskedF U (R cu rt) P (Poly cu rt)) csX msX A G bga rs acc)
    (hform : ∀ k ∈ algHosts, FormAt U P (Poly (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      (fun k h => (algSp U sh dt hcard 0 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ) bga rs k) :
    ∀ i, i < 4 →
      (∀ j, j < i → SchedGd (w16r2DR P (algSp U sh dt hcard) j) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2) bga rs) →
      SchedVan U P (w16r2DR P (algSp U sh dt hcard) i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga
        rs := by
  intro i hi hprev
  have hi' : i = 0 ∨ i = 1 ∨ i = 2 ∨ i = 3 := by omega
  rcases hi' with rfl | rfl | rfl | rfl
  · have hv := schedVan_of_form U hU hbij key domain hs hL P hdrLen R Wd Poly csX msX hlin hN A G bga rs acc hT
      (schedOf P algHosts (algSp U sh dt hcard 0) (fun _ => 80)) hform
    intro k hk r hr
    have hk' : k ∈ w16r2RelKs 0 := hk
    simp only [w16r2RelKs, List.mem_cons, List.not_mem_nil, or_false] at hk'
    rcases hk' with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
    · exact hv 2 (show 2 ∈ algHosts by decide) r hr
    · rfl
    · exact hv 14 (show 14 ∈ algHosts by decide) r hr
    · exact hv 15 (show 15 ∈ algHosts by decide) r hr
    · exact hv 16 (show 16 ∈ algHosts by decide) r hr
    · exact hv 17 (show 17 ∈ algHosts by decide) r hr
    · exact hv 18 (show 18 ∈ algHosts by decide) r hr
    · rfl
    · rfl
  · exact algSp_van1 U sh dt hcard _ _ bga rs (hprev 0 (by norm_num))
  · exact algSp_van2 U sh dt hcard _ _ bga rs (hprev 1 (by norm_num))
  · exact algSp_van3 U sh dt hcard _ _ bga rs (hprev 1 (by norm_num))

/-- **`hvH` for helper polynomials that meet their named identities** (generic in the profile). -/
theorem alg_hvH (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hdrLen : ℕ)
    (R : Cuts3 L → RootsO → ℕ → ℕ → K) (Wd : ℕ)
    (Poly : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hlin : ∀ cu rt, MLin U (msX cu rt) (R cu rt) Wd)
    (hN : ∀ k, k < P.geom.slots.length → 0 < (slotShape P k).1 + (slotShape P k).2.1
      ∧ (slotShape P k).1 + (slotShape P k).2.1 < 64
      ∧ ((slotShape P k).1 + (slotShape P k).2.1) * (slotShape P k).2.2 + 2 ≤ Wd)
    (A : OC (QB L) Dig (List Op × Core))
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (G : QB L → Dig) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc)
    (hT : AccT U key domain hs hL P hdrLen (fun cu rt => maskedF U (R cu rt) P (Poly cu rt)) csX msX A G bga rs acc)
    (hformH : ∀ k ∈ w16r2RelKs 0, FormAt U P (Poly (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      (fun k h => (spH (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ) bga rs k) :
    SchedVan U P (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs :=
  schedVan_of_form U hU hbij key domain hs hL P hdrLen R Wd Poly csX msX hlin hN A G bga rs acc hT
    (w16r2DH P spH 0) hformH

end HV

section Final

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

/-- **One W16R2 rung block's knowledge statement with the relation layers' algebra discharged** (D63 lane L36).
L31's `block_knowledge_final_w16r2` with the certified slot polynomials built (`algSp`), their degrees, their
vanishing on acceptance and the reindexing to `W16Rels` proved. The premises of this lane's part that remain: the
shape facts and tables (`sh`, `dt`), the six hosts' named identities (`hform`), the helper slots' named identities
(`hformH`), `W16Spec` with the two axes that do not pad. The lookup side (`HGd`, `hgdH`, `Alk`, `T`, `mlk`, `hN`,
`he`, `hbr`, `hhr`) and L31's other premises are unchanged. -/
theorem block_knowledge_alg_w16r2 [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
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
    -- the block's algebra: the shape facts, the tables, the hosts' named identities, the reindexing
    (sh : AlgShape P) (dt : AlgData K L sh)
    (hform : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungW16 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ algHosts, FormAt U P (Poly (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (algSp U sh dt (card_K_gt K) 0 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ)
        bga rs k)
    (enc : (k : ℕ) → (Fin (ZK60.Exec.Slot.W16R2.segLn (sh.dl k) .tau) → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (encHt : (Fin sh.nHt → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (hspec : W16Spec sh dt Pb Lay B xtE enc encHt)
    (hTok : Function.Surjective Lay.tok.emb) (hHd : Function.Surjective Lay.hd.emb)
    -- the helper layer and LogUp
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hformH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungW16 U tag
      hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ w16r2RelKs 0, FormAt U P (Poly (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (spH (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ) bga rs k)
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
  have hNs : ∀ k, k < P.geom.slots.length → 0 < (slotShape P k).1 + (slotShape P k).2.1
      ∧ (slotShape P k).1 + (slotShape P k).2.1 < 64
      ∧ ((slotShape P k).1 + (slotShape P k).2.1) * (slotShape P k).2.2 + 2 ≤ 512 := by
    intro k hk
    rw [hlen23] at hk
    have h1 := w16r2_rung_mask_facts k hk
    have h2 := w16r2_rung_slot64 k hk
    simp only [slotShape, hP.hsl]
    exact ⟨h1.2.1, h2, h1.2.2⟩
  have hlin := fun (cu : Cuts3 L) (rt : RootsO) => Link.msXof_mlin U tag L (Link.le64_of_le20 hL20) 23 cu rt
  exact block_knowledge_final_w16r2 U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP aC hC hdc hsA hsH hdrLen
    hdrSq hh hq Poly csE hpolyC hPoly hdegP Pb Lay B fams hF hW h24 xtE q A hA εend hEnd
    (algSp U sh dt (card_K_gt K)) (algSp_dg U sh dt (card_K_gt K))
    (fun G bga rs acc hT => alg_hvR U hU hbij key domain hs hL hdrLen _ 512 Poly _ _ hlin hNs A sh dt
      (card_K_gt K) G bga rs acc hT (hform G bga rs acc hT))
    (fun G bga rs acc _ hall => w16Rels_of_algGood sh dt Pb Lay B xtE enc encHt hspec hTok hHd _ _ bga
      (algGood_of_gd U sh dt (card_K_gt K) _ _ bga rs hall))
    HGd spH hdgH
    (fun G bga rs acc hT => alg_hvH U hU hbij key domain hs hL hdrLen _ 512 Poly _ _ hlin hNs A spH G bga rs acc hT
      (hformH G bga rs acc hT))
    hgdH Alk T mlk hN he hbr hhr

/-- **One R13 rung block's knowledge statement with the relation layers' algebra discharged** (as
`block_knowledge_alg_w16r2`, at R13; the reindexing to `R13Rels` is the named premise `hrels`). -/
theorem block_knowledge_alg_r13 [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
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
    -- the block's algebra: the shape facts, the tables, the hosts' named identities, the reindexing
    (sh : AlgShape P) (dt : AlgData K L sh)
    (hform : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungR13 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ algHosts, FormAt U P (Poly (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (algSp U sh dt (card_K_gt K) 0 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ)
        bga rs k)
    (hrels : ∀ cu rt bga, AlgGood sh dt cu rt bga → ZK60.Layout.R13.R13Rels S Pb Lay B (xtE cu rt))
    -- the helper layer and LogUp
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hformH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csRungR13 U tag
      hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ w16r2RelKs 0, FormAt U P (Poly (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (spH (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ) bga rs k)
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
  have hNs : ∀ k, k < P.geom.slots.length → 0 < (slotShape P k).1 + (slotShape P k).2.1
      ∧ (slotShape P k).1 + (slotShape P k).2.1 < 64
      ∧ ((slotShape P k).1 + (slotShape P k).2.1) * (slotShape P k).2.2 + 2 ≤ 512 := by
    intro k hk
    rw [hlen23] at hk
    have h1 := r13_rung_mask_facts k hk
    have h2 := r13_rung_slot64 k hk
    simp only [slotShape, hP.hsl]
    exact ⟨h1.2.1, h2, h1.2.2⟩
  have hlin := fun (cu : Cuts3 L) (rt : RootsO) => Link.msXof_mlin U tag L (Link.le64_of_le20 hL20) 23 cu rt
  exact block_knowledge_final_r13 U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP aC hC hdc hsA hsH hdrLen
    hdrSq hh hq Poly csE hpolyC hPoly hdegP Pb Lay B hW13 h24 xtE q A hA εend hEnd
    (algSp U sh dt (card_K_gt K)) (algSp_dg U sh dt (card_K_gt K))
    (fun G bga rs acc hT => alg_hvR U hU hbij key domain hs hL hdrLen _ 512 Poly _ _ hlin hNs A sh dt
      (card_K_gt K) G bga rs acc hT (hform G bga rs acc hT))
    (fun G bga rs acc _ hall => hrels _ _ bga (algGood_of_gd U sh dt (card_K_gt K) _ _ bga rs hall))
    HGd spH hdgH
    (fun G bga rs acc hT => alg_hvH U hU hbij key domain hs hL hdrLen _ 512 Poly _ _ hlin hNs A spH G bga rs acc hT
      (hformH G bga rs acc hT))
    hgdH Alk T mlk hN he hbr hhr

/-- **One Shieldstral T128 R13 block's knowledge statement with the relation layers' algebra discharged** (the media
app's classifier block; as `block_knowledge_alg_r13`, at the Shieldstral schedule). The premise `he` is L31's: see
finding L36-1 before using it at this block. -/
theorem block_knowledge_alg_r13_shield [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
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
    -- the block's algebra: the shape facts, the tables, the hosts' named identities, the reindexing
    (sh : AlgShape P) (dt : AlgData K L sh)
    (hform : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldR13 U tag
      hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ algHosts, FormAt U P (Poly (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (algSp U sh dt (card_K_gt K) 0 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ)
        bga rs k)
    (hrels : ∀ cu rt bga, AlgGood sh dt cu rt bga → ZK60.Layout.R13.R13Rels S Pb Lay B (xtE cu rt))
    -- the helper layer and LogUp
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hformH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldR13 U tag
      hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ w16r2RelKs 0, FormAt U P (Poly (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (spH (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ) bga rs k)
    (hgdH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldR13 U tag
      hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      SchedGd (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 35153256)
    (hbr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldR13 U tag
      hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ZK60.Layout.R13.R13Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) →
      ¬ ZK60.Layout.R13.R13Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) →
      ∃ l, ∀ j, T j ≠ Alk (cutsOf key domain hs hL A G).1 l)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldR13 U tag
      hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
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
  have hNs : ∀ k, k < P.geom.slots.length → 0 < (slotShape P k).1 + (slotShape P k).2.1
      ∧ (slotShape P k).1 + (slotShape P k).2.1 < 64
      ∧ ((slotShape P k).1 + (slotShape P k).2.1) * (slotShape P k).2.2 + 2 ≤ 512 := by
    intro k hk
    rw [hlen23] at hk
    have h1 := r13_shield_mask_facts k hk
    have h2 := r13_shield_slot64 k hk
    simp only [slotShape, hP.hsl]
    exact ⟨h1.2.1, h2, h1.2.2⟩
  have hlin := fun (cu : Cuts3 L) (rt : RootsO) => Link.msXof_mlin U tag L (Link.le64_of_le20 hL20) 23 cu rt
  exact block_knowledge_final_r13_shield U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP aC hC hdc hsA hsH
    hdrLen hdrSq hh hq Poly csE hpolyC hPoly hdegP Pb Lay B hW13 h24 xtE q A hA εend hEnd
    (algSp U sh dt (card_K_gt K)) (algSp_dg U sh dt (card_K_gt K))
    (fun G bga rs acc hT => alg_hvR U hU hbij key domain hs hL hdrLen _ 512 Poly _ _ hlin hNs A sh dt
      (card_K_gt K) G bga rs acc hT (hform G bga rs acc hT))
    (fun G bga rs acc _ hall => hrels _ _ bga (algGood_of_gd U sh dt (card_K_gt K) _ _ bga rs hall))
    HGd spH hdgH
    (fun G bga rs acc hT => alg_hvH U hU hbij key domain hs hL hdrLen _ 512 Poly _ _ hlin hNs A spH G bga rs acc hT
      (hformH G bga rs acc hT))
    hgdH Alk T mlk hN he hbr hhr

end Final

end ZK60.Exec.Block
