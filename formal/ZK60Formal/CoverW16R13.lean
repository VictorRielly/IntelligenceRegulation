/-
D63 lane L23 (2026-11-07), part 10: **the R13 rung instance of the block's knowledge statement** (the media app's
classifier blocks; L17's reduction).

R13 runs W16R2's 23 slots with the same kinds, hosts, cubes and degrees (L17, `SlotR13.lean`), so W16R2's relation
layers (`w16r2RelKs`) and certified slot polynomials apply unchanged; only the draws (`R13.rungDraws`, `375` in all),
the terminal counts and the relations / lookups differ. `block_knowledge_target_r13` is `block_knowledge_target_gen`
with `R13Rels`, `R13Lookups` and L17's `blockSat_of_slots_r13` (the R13 data read as W16 data satisfies `BlockSat`).

* `rung_defLen_r13`, `r13_draws_sum`, `r13_defND_le`, `r13_budget`: the R13 rung's numbers (`defLen = hdrLen + 1069`,
  `375` draws, any opening geometry with `M ≤ 2^-106` and each regular round `≤ 2^-105`: at most `38,579,953 ≤ 2^26`);
* **`block_knowledge_target_r13`**: one R13 rung block's knowledge error is at most `εsTarget q` for every `q`, with the
  same remaining premises as at W16R2 (the openings' links, the slot polynomials over the extracted data, and the
  per-outcome algebra: `hvR`, `hgdR` now to `R13Rels`, `hvH`, `hgdH`, the lookup bridge `hbr` to `R13Lookups`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.CoverW16Inst
import ZK60Formal.CoverW16Gen
import ZK60Formal.LayoutR13
import ZK60Formal.ExecBlockR13

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Circuit (gP GF)
open scoped ENNReal

section R13Inst

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

/-- **At the R13 rung** the verifier's operations up to the end of the slot loop number `hdrLen + 1069`. -/
theorem rung_defLen_r13 (P : BlockParams) (hdr : P.draws = R13.rungDraws) (hsl : P.geom.slots = R13.rungSlots)
    (h : ℕ) : defLen P h = h + 1069 := by
  have e : defOffW R13.rungDraws R13.rungSlots 0 R13.rungSlots.length = 1059 := by decide
  rw [defLen, defOff_eq, hdr, hsl, e]

/-- The R13 rung's define draws: `375` in all. -/
theorem r13_draws_sum : ∑ k ∈ Finset.range 23, R13.rungDraws k = 375 := by decide

/-- **At the R13 rung** a relation layer's draws weigh at most `dd·375`. -/
theorem r13_defND_le (P : BlockParams) (hdr : P.draws = R13.rungDraws) (i : ℕ) (hi : i < 4) (dg : ℕ → ℕ)
    (dd : ℕ) (hdg : ∀ k ∈ w16r2RelKs i, dg k ≤ dd) : defND P (w16r2RelKs i) dg ≤ dd * 375 := by
  have h := defND_le P _ dg dd 23 hdg (w16r2RelKs_facts i hi).1 (w16r2RelKs_facts i hi).2
  rw [hdr, r13_draws_sum] at h
  exact h

/-- **The R13 rung's whole block**, four relation layers and one helper layer, for any opening geometry with
`M ≤ 2^-106` and each regular round `≤ 2^-105`: at most `38,579,953 ≤ 2^26`. -/
theorem r13_budget (jM jA jB : ℕ) (hjM : 106 ≤ jM) (hjA : 105 ≤ jA) (hjB : 105 ≤ jB) :
    3 * 2 ^ (126 - jM) + 2 * (2 ^ (126 - jA) + 2 ^ (126 - jB)) + 2 ^ 18 + 2 ^ 16 + 5 + 924
      + 4 * (80 + 80 * 375 + 2 ^ 14 + 2 ^ 14) + (1 * (80 + 80 * 375 + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14))
      ≤ 2 ^ 26 := by
  have h1 : 2 ^ (126 - jM) ≤ 2 ^ 20 := Nat.pow_le_pow_right (by norm_num) (by omega)
  have h2 : 2 ^ (126 - jA) ≤ 2 ^ 21 := Nat.pow_le_pow_right (by norm_num) (by omega)
  have h3 : 2 ^ (126 - jB) ≤ 2 ^ 21 := Nat.pow_le_pow_right (by norm_num) (by omega)
  refine le_trans (Nat.add_le_add_right (Nat.add_le_add_right (Nat.add_le_add_right (Nat.add_le_add_right
    (Nat.add_le_add_right (Nat.add_le_add_right (Nat.add_le_add (Nat.mul_le_mul_left 3 h1)
      (Nat.mul_le_mul_left 2 (Nat.add_le_add h2 h3))) _) _) _) _) _) _) ?_
  norm_num

/-- **One R13 rung block's knowledge error is at most the approved target, for EVERY `q`** (D63 lane L23; L17's
reduction). As `block_knowledge_target_w16r2`, at the R13 rung's schedule, with R13's relations and lookups of the
extracted R13 planes, any opening geometry with `M ≤ 2^-106` and each regular round `≤ 2^-105`, and the shifts in their
limb windows (`R13Windows`). -/
theorem block_knowledge_target_r13 [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (hdr : P.draws = R13.rungDraws) (hsl : P.geom.slots = R13.rungSlots) (htm : P.geom.terms = R13.rungTerms)
    (hdrLen : ℕ) (hh : hdrLen ≤ 2 ^ 19)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : ∀ cu rt, SlotEval U P (csX cu rt) (msX cu rt) (F cu rt))
    (hdeg : ∀ cu rt k sn, IndDegLE (slotShape P k).2.2 (F cu rt k sn))
    (Pb : ZK60.Block.BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf) (B : ZK60.Layout.W16Pub S Pb Lay)
    {ls : ℕ} (hW13 : ZK60.Layout.R13.R13Windows S ls) (h24 : S.h24 = true)
    (xtE : Cuts3 L → RootsO → ZK60.Layout.R13.R13Data Ct Cw Cg Cj Cd Cf ls)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    -- the openings: their good predicates, chain events and per-position bounds (L20), at W16R2's geometry
    (GA GH GM EvA EvH EvM EvX : (QB L → Dig) → Prop) (ℓo : ℕ) (hℓo : ℓo ≤ 2 ^ 20)
    (jM jA jB : ℕ) (hjM : 106 ≤ jM ∧ jM ≤ 126) (hjA : 105 ≤ jA ∧ jA ≤ 126) (hjB : 105 ≤ jB ∧ jB ≤ 126)
    (maskE εAa εBa εAh εBh : ℝ≥0∞) (hmE : maskE ≤ (2⁻¹ : ℝ≥0∞) ^ jM)
    (hAa : εAa ≤ (2⁻¹ : ℝ≥0∞) ^ jA) (hBa : εBa ≤ (2⁻¹ : ℝ≥0∞) ^ jB)
    (hAh : εAh ≤ (2⁻¹ : ℝ≥0∞) ^ jA) (hBh : εBh ≤ (2⁻¹ : ℝ≥0∞) ^ jB)
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
      ZK60.Layout.R13.R13Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)))
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
      ZK60.Layout.R13.R13Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) →
      ¬ ZK60.Layout.R13.R13Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) →
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
          (ZK60.Layout.toWit Lay ((xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).toW16 S)))
      ≤ εsTarget q := by
  have hlen : P.geom.slots.length = 23 := by rw [hsl]; rfl
  have hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ 5
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L := by
    intro k hk
    rw [hlen] at hk
    obtain ⟨h1, h2, h3, h4⟩ := R13.rung_slot_facts k hk
    simp only [slotShape, slotTerms, hsl, htm]
    exact ⟨h1, h2, by omega, by omega⟩
  have hgt : P.geom.slots.length = P.geom.terms.length := by rw [hsl, htm]; rfl
  have hℓs : blockLen P.draws P.geom.slots hdrLen ≤ 2 ^ 20 := by
    rw [hdr, hsl, R13.rung_len]
    omega
  have hℓd : defLen P hdrLen ≤ 2 ^ 20 := by
    rw [rung_defLen_r13 P hdr hsl]
    omega
  have hℓk : hdrLen + 10 ≤ 2 ^ 20 := by omega
  have hND : blockND P.geom.slots = 924 := by rw [hsl, R13.rungSlots_eq_w16r2]; exact rung_blockND
  -- the relation layers
  have hksR : ∀ i, i < 4 → ∀ k ∈ (w16r2DR P spR i).ks, k < P.geom.slots.length := fun i hi k hk => by
    rw [hlen]
    exact (w16r2RelKs_facts i hi).2 k hk
  have hdgR' : ∀ i, i < 4 → ∀ k ∈ (w16r2DR P spR i).ks, (w16r2DR P spR i).dg k ≤ 80 := fun _ _ _ _ => le_rfl
  have hfR := fun i (hi : i < 4) => schedOf_facts P (w16r2RelKs i) (spR i) (fun _ => 80) (hdgR i hi)
  have hNDR : ∀ i, i < 4 → defND P (w16r2DR P spR i).ks (w16r2DR P spR i).dg ≤ 80 * 375 := fun i hi =>
    r13_defND_le P hdr i hi _ 80 (fun _ _ => le_rfl)
  have hcR := hcoverR_gen U key domain hs hL P hdrLen F csX msX
    (fun cu rt => ZK60.Layout.R13.R13Rels S Pb Lay B (xtE cu rt)) A 4 (w16r2DR P spR) hvR hgdR
  -- the helper layer
  have hksH : ∀ i, i < 1 → ∀ k ∈ (w16r2DH P spH i).ks, k < P.geom.slots.length := fun _ _ k hk => by
    rw [hlen]
    exact (w16r2RelKs_facts 0 (by norm_num)).2 k hk
  have hfH := schedOf_facts P (w16r2RelKs 0) spH (fun _ => 80) hdgH
  have hNDH : ∀ i, i < 1 → defND P (w16r2DH P spH i).ks (w16r2DH P spH i).dg ≤ 80 * 375 := fun _ _ =>
    r13_defND_le P hdr 0 (by norm_num) _ 80 (fun _ _ => le_rfl)
  have hcH := hcoverH_layers U key domain hs hL P hdrLen F csX msX A HGd 1 (w16r2DH P spH)
    (fun G bga rs acc hT i hi _ => by
      have hi0 : i = 0 := by omega
      subst hi0
      exact hvH G bga rs acc hT)
    (fun G bga rs acc hT hall => hgdH G bga rs acc hT (hall 0 (by norm_num)))
  have hsp := hsplit_gen U key domain hs hL P hdrLen F csX msX
    (fun cu rt => ZK60.Layout.R13.R13Rels S Pb Lay B (xtE cu rt))
    (fun cu rt => ZK60.Layout.R13.R13Lookups S Pb Lay B (xtE cu rt)) A HGd Alk T mlk hbr hhr
  have hbud : 3 * 2 ^ (126 - jM) + 2 * (2 ^ (126 - jA) + 2 ^ (126 - jB)) + 2 ^ 18 + 2 ^ 16 + 5
      + blockND P.geom.slots + 4 * (80 + 80 * 375 + 2 ^ 14 + 2 ^ 14)
      + (1 * (80 + 80 * 375 + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14)) ≤ 2 ^ 26 := by
    rw [hND]
    exact r13_budget jM jA jB hjM.1 hjA.1 hjB.1
  exact block_knowledge_target_gen U hU hK2 key domain hs hL hL64 (by omega) P hdrLen F csX msX hpolyC hEval hdeg 5
    (by norm_num) hgeom hgt hℓs hℓd hℓk
    (fun cu rt => ZK60.Layout.R13.R13Rels S Pb Lay B (xtE cu rt))
    (fun cu rt => ZK60.Layout.R13.R13Lookups S Pb Lay B (xtE cu rt))
    (fun cu rt => ZK60.Block.BlockSat Pb (fun p => (xtE cu rt).X (Lay.dPos p)) (fun p => (xtE cu rt).X2 (Lay.dPos p))
      (ZK60.Layout.toWit Lay ((xtE cu rt).toW16 S)))
    (fun cu rt hr hl => ZK60.Layout.R13.blockSat_of_slots_r13 Pb Lay B (xtE cu rt) hW13 h24 hr hl)
    q A hA GA GH GM EvA EvH EvM EvX ℓo hℓo jM jA jB
    hjM.2 hjA.2 hjB.2 maskE εAa εBa εAh εBh hmE hAa hBa hAh hBh hM hEA hEH T' nr hT' hnr hX
    hsem hexec 80 (80 * 375) 4 1 (w16r2DR P spR) (w16r2DH P spH) hksR hdgR' (fun i hi => (hfR i hi).1) (fun i hi => (hfR i hi).2)
    hNDR hcR Alk T mlk hN he hksH (fun _ _ _ _ => le_rfl) (fun _ _ => hfH.1) (fun _ _ => hfH.2) hNDH
    (EvHlpOf U key domain hs hL P hdrLen F csX msX A HGd) hcH hsp hbud

end R13Inst

end ZK60.Exec.Block
