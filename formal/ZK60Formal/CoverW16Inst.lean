/-
D63 lane L23 (2026-11-07), part 7: **the W16R2 rung instance of the block's knowledge statement**, with the
schedules, their certificates, the counts and the budget discharged.

`block_knowledge_target_w16r2` is `block_knowledge_target_mtN` (four relation layers, finding L23-2; one helper layer)
at the W16R2 development rung's schedule (`rungDraws`, `rungSlots`, `rungTerms`: L9's, and by L11's formulas
`shRungW16`'s, `SlotPolyW16Draw.lean`) and W16R2's opening geometry (`M ≤ 2^-106`, `opA ≤ 2^-111`, `opB ≤ 2^-113`).
Discharged here, for ANY certified slot polynomials (`SlotPoly`, built by `SlotPolyW16.lean`'s constructors):

* the schedules' slots are W16R2 slots and distinct (`w16r2RelKs_facts`), their escape counts `80`, their degrees and
  `(Φ ≡ 0) → Gd` (`schedOf_facts`, the certificates), `Σ draws·dg ≤ 80·351` (`w16r2_defND_le`);
* the covers `hcoverR`, `hcoverH` and the split `hsplit` (`hcoverR_layers`, `hcoverH_layers`, `hsplit_two`) from
  per-outcome facts;
* the rung's geometry (degrees `≤ 5`, chains within `2^20`, `blockND = 924`) and the budget (`w16r2_budget_mtN`:
  `30,263,665 ≤ 2^26`).

What stays a premise: the openings' and `M`'s bounds and links (L20 / L22's `hsem`, `hexec`), the slot polynomials over
the extracted data (`F`, `csX`, `msX` with `SlotEval`, `hdeg`, `hpolyC`), and the instance's algebra in its
per-outcome form: on an accepting outcome each layer's polynomials vanish at the drawn challenges once the earlier
layers' start claims hold (`hvR`, `hvH`: the unmasking `CoverW16Unmask.unmask_slots` plus the slot polynomials' named
forms), all start claims give `W16Rels` (`hgdR`: the reindexing) and the helpers' claims (`hgdH`), and the lookup-list
bridge (`hbr`, `hhr`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.SlotPolyW16Draw

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Circuit (gP GF)
open scoped ENNReal

section Inst

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

/-- **The W16R2 relation layers from certified slot polynomials** (escape counts `80`). -/
def w16r2DR (P : BlockParams) (spR : ℕ → Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k)) (i : ℕ) :
    DefSched K L P :=
  schedOf P (w16r2RelKs i) (spR i) (fun _ => 80)

/-- **The W16R2 helper layer** (the hosts' and standalone zero-checks' helper clauses: layer 0's slots). -/
def w16r2DH (P : BlockParams) (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k)) (_i : ℕ) :
    DefSched K L P :=
  schedOf P (w16r2RelKs 0) spH (fun _ => 80)

/-- **One W16R2 rung block's knowledge error is at most the approved target, for EVERY `q`** (D63 lane L23). For a block
verifier with the rung's schedule, a header of at most `2^19` operations and hash inputs of at most `L ≥ 2^20` bytes,
and ANY certified slot polynomials `spR` (four relation layers) and `spH` (the helper layer) with degrees `≤ 80`: given
the openings' and `M`'s bounds and links (L20, with `hsem` for `OpenTrue`), the slot polynomials over the extracted data
(`SlotEval`, `hdeg`, `hpolyC`), and the instance's per-outcome algebra (`hvR`, `hgdR`, `hvH`, `hgdH`, `hbr`, `hhr`),
the block verifier accepts while the extracted planes do not satisfy `BlockSat` with probability at most
`εsTarget q = q·2^-100 + 2^-100`. -/
theorem block_knowledge_target_w16r2 [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (hdr : P.draws = W16R2.rungDraws) (hsl : P.geom.slots = W16R2.rungSlots) (htm : P.geom.terms = W16R2.rungTerms)
    (hdrLen : ℕ) (hh : hdrLen ≤ 2 ^ 19)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : ∀ cu rt, SlotEval U P (csX cu rt) (msX cu rt) (F cu rt))
    (hdeg : ∀ cu rt k sn, IndDegLE (slotShape P k).2.2 (F cu rt k sn))
    (Pb : ZK60.Block.BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf) (B : ZK60.Layout.W16Pub S Pb Lay)
    (fams : List (ℕ × ℕ)) (hF : ZK60.Circuit.FamsOK fams) (hW : ZK60.Layout.W16Widths S fams) (h24 : S.h24 = true)
    (xtE : Cuts3 L → RootsO → ZK60.Layout.W16Data Ct Cw Cg Cj Cd Cf)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    -- the openings: their good predicates, chain events and per-position bounds (L20), at W16R2's geometry
    (GA GH GM EvA EvH EvM EvX : (QB L → Dig) → Prop) (ℓo : ℕ) (hℓo : ℓo ≤ 2 ^ 20)
    (maskE εAa εBa εAh εBh : ℝ≥0∞) (hmE : maskE ≤ (2⁻¹ : ℝ≥0∞) ^ 106)
    (hAa : εAa ≤ (2⁻¹ : ℝ≥0∞) ^ 111) (hBa : εBa ≤ (2⁻¹ : ℝ≥0∞) ^ 113)
    (hAh : εAh ≤ (2⁻¹ : ℝ≥0∞) ^ 111) (hBh : εBh ≤ (2⁻¹ : ℝ≥0∞) ^ 113)
    (hM : prH EvM ≤ (q : ℝ≥0∞) * maskE + 3 * maskE + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig)
    (hEA : prH EvA ≤ ((q : ℝ≥0∞) * εAa + εAa + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig)
        + ((q : ℝ≥0∞) * εBa + εBa + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig))
    (hEH : prH EvH ≤ ((q : ℝ≥0∞) * εAh + εAh + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig)
        + ((q : ℝ≥0∞) * εBh + εBh + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig))
    (T' nr : ℕ) (hT' : T' ≤ 2 ^ 22 * (q + 1)) (hnr : nr ≤ 3)
    (hX : prH EvX ≤ collBound T' Dig + ((2 * T' * T' + (1 + nr) * T' : ℕ) : ℝ≥0∞) / Fintype.card Dig)
    (hsem : ∀ G, (∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ ¬ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
          (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc) → ¬ (GA G ∧ GH G ∧ GM G))
    (hexec : ∀ G, (∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc) → ¬ EvX G →
      (GA G ∨ EvA G) ∧ (GH G ∨ EvH G) ∧ (GM G ∨ EvM G))
    -- the four relation layers (certified slot polynomials) and their per-outcome algebra
    (spR : ℕ → Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgR : ∀ i, i < 4 → ∀ cu rt k h, k ∈ w16r2RelKs i → (spR i cu rt k h).dg ≤ 80)
    (hvR : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc → ∀ i, i < 4 →
      (∀ j, j < i → SchedGd (w16r2DR P spR j) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      SchedVan U P (w16r2DR P spR i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs)
    (hgdR : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc →
      (∀ i, i < 4 → SchedGd (w16r2DR P spR i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)))
    -- the helper layer and LogUp
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hvH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc →
      SchedVan U P (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs)
    (hgdH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc →
      SchedGd (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 35153256)
    (hbr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc →
      ¬ ZK60.Layout.W16Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) fams →
      ∃ l, ∀ j, T j ≠ Alk (cutsOf key domain hs hL A G).1 l)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X (Lay.dPos p))
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))))
      ≤ εsTarget q := by
  have hlen : P.geom.slots.length = 23 := by rw [hsl]; rfl
  have hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ 5
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L := by
    intro k hk
    rw [hlen] at hk
    obtain ⟨h1, h2, h3, h4⟩ := W16R2.rung_slot_facts k hk
    simp only [slotShape, slotTerms, hsl, htm]
    exact ⟨h1, h2, by omega, by omega⟩
  have hgt : P.geom.slots.length = P.geom.terms.length := by rw [hsl, htm]; rfl
  have hℓs : blockLen P.draws P.geom.slots hdrLen ≤ 2 ^ 20 := by
    rw [hdr, hsl, W16R2.rung_len]
    omega
  have hℓd : defLen P hdrLen ≤ 2 ^ 20 := by
    rw [rung_defLen P hdr hsl]
    omega
  have hℓk : hdrLen + 10 ≤ 2 ^ 20 := by omega
  have hND : blockND P.geom.slots = 924 := by rw [hsl]; exact rung_blockND
  -- the relation layers
  have hksR : ∀ i, i < 4 → ∀ k ∈ (w16r2DR P spR i).ks, k < P.geom.slots.length := fun i hi k hk => by
    rw [hlen]
    exact (w16r2RelKs_facts i hi).2 k hk
  have hdgR' : ∀ i, i < 4 → ∀ k ∈ (w16r2DR P spR i).ks, (w16r2DR P spR i).dg k ≤ 80 := fun _ _ _ _ => le_rfl
  have hfR := fun i (hi : i < 4) => schedOf_facts P (w16r2RelKs i) (spR i) (fun _ => 80) (hdgR i hi)
  have hNDR : ∀ i, i < 4 → defND P (w16r2DR P spR i).ks (w16r2DR P spR i).dg ≤ 80 * 351 := fun i hi =>
    w16r2_defND_le P hdr i hi _ 80 (fun _ _ => le_rfl)
  have hcR := hcoverR_layers U key domain hs hL P hdrLen F csX msX Pb Lay B xtE A 4 (w16r2DR P spR) hvR hgdR
  -- the helper layer
  have hksH : ∀ i, i < 1 → ∀ k ∈ (w16r2DH P spH i).ks, k < P.geom.slots.length := fun _ _ k hk => by
    rw [hlen]
    exact (w16r2RelKs_facts 0 (by norm_num)).2 k hk
  have hfH := schedOf_facts P (w16r2RelKs 0) spH (fun _ => 80) hdgH
  have hNDH : ∀ i, i < 1 → defND P (w16r2DH P spH i).ks (w16r2DH P spH i).dg ≤ 80 * 351 := fun _ _ =>
    w16r2_defND_le P hdr 0 (by norm_num) _ 80 (fun _ _ => le_rfl)
  have hcH := hcoverH_layers U key domain hs hL P hdrLen F csX msX A HGd 1 (w16r2DH P spH)
    (fun G bga rs acc hT i hi _ => by
      have hi0 : i = 0 := by omega
      subst hi0
      exact hvH G bga rs acc hT)
    (fun G bga rs acc hT hall => hgdH G bga rs acc hT (hall 0 (by norm_num)))
  have hsp := hsplit_two U key domain hs hL P hdrLen F csX msX Pb Lay B fams xtE A HGd Alk T mlk hbr hhr
  have hbud : 3 * 2 ^ (126 - 106) + 2 * (2 ^ (126 - 111) + 2 ^ (126 - 113)) + 2 ^ 18 + 2 ^ 16 + 5
      + blockND P.geom.slots + 4 * (80 + 80 * 351 + 2 ^ 14 + 2 ^ 14)
      + (1 * (80 + 80 * 351 + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14)) ≤ 2 ^ 26 := by
    rw [hND]
    exact w16r2_budget_mtN
  exact block_knowledge_target_mtN U hU hK2 key domain hs hL hL64 (by omega) P hdrLen F csX msX hpolyC hEval hdeg 5
    (by norm_num) hgeom hgt hℓs hℓd hℓk Pb Lay B fams hF hW h24 xtE q A hA GA GH GM EvA EvH EvM EvX ℓo hℓo 106 111 113
    (by norm_num) (by norm_num) (by norm_num) maskE εAa εBa εAh εBh hmE hAa hBa hAh hBh hM hEA hEH T' nr hT' hnr hX
    hsem hexec 80 (80 * 351) 4 1 (w16r2DR P spR) (w16r2DH P spH) hksR hdgR' (fun i hi => (hfR i hi).1) (fun i hi => (hfR i hi).2)
    hNDR hcR Alk T mlk hN he hksH (fun _ _ _ _ => le_rfl) (fun _ _ => hfH.1) (fun _ _ => hfH.2) hNDH
    (EvHlpOf U key domain hs hL P hdrLen F csX msX A HGd) hcH hsp hbud

end Inst

end ZK60.Exec.Block
