/-
D63 lane L23 (2026-11-07), part 11: **the W16R2 instance at any block shape, and the 8B T128 and Shieldstral T128
shapes' facts** (A25: every block carries its own shape).

* `sh8BW`, `shShieldW`: L11's `sh8B` / `shShield` with the W16R2 helper counts and range sub-planes the layout export
  records at those shapes (`results/zk60_lean_l13_20261107/layout.txt`: helpers `L` 1, `D` 10, `Q` 3, `Kv` 3, `S` 4,
  `F` 4; `12` range sub-planes); L11's own `sh8B` leaves them at `0` (they enter no numerator), so its draw counts are
  not the code's (finding L23-3);
* `schedList`, `blockLen_hdr`, `defLen_shape`: a shape's schedule list; the chain lengths are affine in the header;
* **`w16r2_8B_shape_facts`**, **`w16r2_shield_shape_facts`**: at both shapes every slot degree is in `[1, 5]`,
  `blockND` is `1,099` / `1,159`, the define draws number `423` / `425`, and with a header of at most `2^19`
  operations the chains are within `2^20` (`blockLen = hdrLen + 1,264` / `+ 1,266`, `defLen = hdrLen + 1,265` /
  `+ 1,267`);
* **`block_knowledge_target_w16r2_shape`**: `block_knowledge_target_w16r2` for ANY W16R2 shape whose draws and schedule
  are L11's formulas, with degrees `≤ 5`, `blockND ≤ 2^14`, at most `4096` draws and chains within `2^20` (the budget
  `w16r2_budget_any`); with the facts above it holds at the 8B and Shieldstral T128 shapes.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.CoverW16Inst

set_option autoImplicit false

namespace ZK60.Exec.Slot.W16R2

/-- **The W16R2 8B T128 shape with its helper counts** (the layout export's `LK` lines and `nrange`). -/
def sh8BW : ShapeW := { sh8B with
  nRange := 12
  helpers := fun d => match d with
    | .L => 1 | .D => 10 | .Q => 3 | .Kv => 3 | .S => 4 | .F => 4
    | _ => 0 }

/-- **The W16R2 Shieldstral T128 shape with its helper counts.** -/
def shShieldW : ShapeW := { shShield with
  nRange := 12
  helpers := fun d => match d with
    | .L => 1 | .D => 10 | .Q => 3 | .Kv => 3 | .S => 4 | .F => 4
    | _ => 0 }

/-- A shape's schedule list (`Shape::slots`, 23 slots). -/
def schedList (sh : ShapeW) : List (ℕ × ℕ × ℕ) := (List.range nSlots).map (sched sh)

theorem schedList_length (sh : ShapeW) : (schedList sh).length = 23 := by simp [schedList]

end ZK60.Exec.Slot.W16R2

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Circuit (gP GF)
open ZK60.Exec.Slot.W16R2 (ShapeW sh8BW shShieldW schedList drawLen)
open scoped ENNReal

/-- **The block's item count is affine in the header.** -/
theorem blockLen_hdr (draws : ℕ → ℕ) (slots : List (ℕ × ℕ × ℕ)) (h : ℕ) (hne : 0 < slots.length) :
    blockLen draws slots h = h + blockLen draws slots 0 := by
  unfold blockLen
  obtain ⟨n, hn⟩ : ∃ n, slots.length = n + 1 := ⟨slots.length - 1, by omega⟩
  rw [hn, List.range_succ_eq_map]
  simp only [List.map_cons, List.sum_cons, List.map_map, Function.comp_def, Nat.succ_ne_zero, ↓reduceIte]
  omega

/-- **The define chain at a shape** whose draws and schedule are the formulas'. -/
theorem defLen_shape (P : BlockParams) (sh : ShapeW) (hdr : P.draws = drawLen sh) (hsl : P.geom.slots = schedList sh)
    (h : ℕ) : defLen P h = h + 10 + defOffW (drawLen sh) (schedList sh) 0 23 := by
  rw [defLen, defOff_eq, hdr, hsl, ZK60.Exec.Slot.W16R2.schedList_length]

/-- **The W16R2 8B T128 shape's facts.** -/
theorem w16r2_8B_shape_facts :
    (∀ k, k < 23 → 1 ≤ ((schedList sh8BW).getD k (0, 0, 0)).2.2 ∧ ((schedList sh8BW).getD k (0, 0, 0)).2.2 ≤ 5)
    ∧ blockND (schedList sh8BW) = 1099 ∧ ∑ k ∈ Finset.range 23, drawLen sh8BW k = 423
    ∧ blockLen (drawLen sh8BW) (schedList sh8BW) 0 = 1264 ∧ defOffW (drawLen sh8BW) (schedList sh8BW) 0 23 = 1255 := by
  refine ⟨by decide, by decide, by decide, by decide, by decide⟩

/-- **The W16R2 Shieldstral T128 shape's facts** (`D` pads: `SC_SS`, `SC_SSM`, `SC_DZC` one degree more, `SC_DZC` draws
the pad pair). -/
theorem w16r2_shield_shape_facts :
    (∀ k, k < 23 → 1 ≤ ((schedList shShieldW).getD k (0, 0, 0)).2.2 ∧ ((schedList shShieldW).getD k (0, 0, 0)).2.2 ≤ 5)
    ∧ blockND (schedList shShieldW) = 1159 ∧ ∑ k ∈ Finset.range 23, drawLen shShieldW k = 425
    ∧ blockLen (drawLen shShieldW) (schedList shShieldW) 0 = 1266
    ∧ defOffW (drawLen shShieldW) (schedList shShieldW) 0 23 = 1257 := by
  refine ⟨by decide, by decide, by decide, by decide, by decide⟩

/-- At a shape with the facts, a header of at most `2^19` operations keeps both chains within `2^20`. -/
theorem shape_chains_le (P : BlockParams) (sh : ShapeW) (hdr : P.draws = drawLen sh) (hsl : P.geom.slots = schedList sh)
    (bl dl : ℕ) (hbl : blockLen (drawLen sh) (schedList sh) 0 = bl) (hdl : defOffW (drawLen sh) (schedList sh) 0 23 = dl)
    (hb : bl ≤ 2 ^ 19) (hd : dl + 10 ≤ 2 ^ 19) (hdrLen : ℕ) (hh : hdrLen ≤ 2 ^ 19) :
    blockLen P.draws P.geom.slots hdrLen ≤ 2 ^ 20 ∧ defLen P hdrLen ≤ 2 ^ 20 := by
  refine ⟨?_, ?_⟩
  · rw [hdr, hsl, blockLen_hdr _ _ _ (by rw [ZK60.Exec.Slot.W16R2.schedList_length]; norm_num), hbl]
    omega
  · rw [defLen_shape P sh hdr hsl, hdl]
    omega

section Shape

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

/-- **One W16R2 block's knowledge error is at most the approved target, for EVERY `q`, at ANY W16R2 shape** whose draws
and schedule are L11's formulas (`drawLen sh`, `schedList sh`), with slot degrees in `[1, 5]`, `blockND ≤ 2^14`, at most
`4096` draws, terminal counts `≤ 2^14` and both chains within `2^20` (at the 8B and Shieldstral T128 shapes:
`w16r2_8B_shape_facts`, `w16r2_shield_shape_facts`, `shape_chains_le`). The remaining premises are
`block_knowledge_target_w16r2`'s. -/
theorem block_knowledge_target_w16r2_shape [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (sh : ZK60.Exec.Slot.W16R2.ShapeW) (hdr : P.draws = ZK60.Exec.Slot.W16R2.drawLen sh)
    (hsl : P.geom.slots = ZK60.Exec.Slot.W16R2.schedList sh) (hgt23 : P.geom.terms.length = 23)
    (htm : ∀ k, k < 23 → slotTerms P k ≤ 2 ^ 14)
    (hfacts : ∀ k, k < 23 → 1 ≤ ((ZK60.Exec.Slot.W16R2.schedList sh).getD k (0, 0, 0)).2.2
      ∧ ((ZK60.Exec.Slot.W16R2.schedList sh).getD k (0, 0, 0)).2.2 ≤ 5)
    (hND : blockND (ZK60.Exec.Slot.W16R2.schedList sh) ≤ 2 ^ 14)
    (hNd : ∑ k ∈ Finset.range 23, ZK60.Exec.Slot.W16R2.drawLen sh k ≤ 4096)
    (hdrLen : ℕ) (hℓs : blockLen P.draws P.geom.slots hdrLen ≤ 2 ^ 20) (hℓd : defLen P hdrLen ≤ 2 ^ 20)
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
  have hlen : P.geom.slots.length = 23 := by rw [hsl]; exact ZK60.Exec.Slot.W16R2.schedList_length sh
  have hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ 5
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L := by
    intro k hk
    rw [hlen] at hk
    obtain ⟨h1, h2⟩ := hfacts k hk
    have h4 := htm k hk
    simp only [slotShape, hsl]
    exact ⟨h1, h2, by omega, by omega⟩
  have hgt : P.geom.slots.length = P.geom.terms.length := by rw [hlen, hgt23]
  have hℓk : hdrLen + 10 ≤ 2 ^ 20 := by
    have := hℓd
    unfold defLen at this
    omega
  have hND' : blockND P.geom.slots ≤ 2 ^ 14 := by rw [hsl]; exact hND
  have hNd' : ∑ k ∈ Finset.range 23, P.draws k ≤ 4096 := by rw [hdr]; exact hNd
  -- the relation layers
  have hksR : ∀ i, i < 4 → ∀ k ∈ (w16r2DR P spR i).ks, k < P.geom.slots.length := fun i hi k hk => by
    rw [hlen]
    exact (w16r2RelKs_facts i hi).2 k hk
  have hdgR' : ∀ i, i < 4 → ∀ k ∈ (w16r2DR P spR i).ks, (w16r2DR P spR i).dg k ≤ 80 := fun _ _ _ _ => le_rfl
  have hfR := fun i (hi : i < 4) => schedOf_facts P (w16r2RelKs i) (spR i) (fun _ => 80) (hdgR i hi)
  have hNDR : ∀ i, i < 4 → defND P (w16r2DR P spR i).ks (w16r2DR P spR i).dg ≤ 80 * 4096 := fun i hi =>
    shape_defND_le P 4096 hNd' i hi _ 80 (fun _ _ => le_rfl)
  have hcR := hcoverR_layers U key domain hs hL P hdrLen F csX msX Pb Lay B xtE A 4 (w16r2DR P spR) hvR hgdR
  -- the helper layer
  have hksH : ∀ i, i < 1 → ∀ k ∈ (w16r2DH P spH i).ks, k < P.geom.slots.length := fun _ _ k hk => by
    rw [hlen]
    exact (w16r2RelKs_facts 0 (by norm_num)).2 k hk
  have hfH := schedOf_facts P (w16r2RelKs 0) spH (fun _ => 80) hdgH
  have hNDH : ∀ i, i < 1 → defND P (w16r2DH P spH i).ks (w16r2DH P spH i).dg ≤ 80 * 4096 := fun _ _ =>
    shape_defND_le P 4096 hNd' 0 (by norm_num) _ 80 (fun _ _ => le_rfl)
  have hcH := hcoverH_layers U key domain hs hL P hdrLen F csX msX A HGd 1 (w16r2DH P spH)
    (fun G bga rs acc hT i hi _ => by
      have hi0 : i = 0 := by omega
      subst hi0
      exact hvH G bga rs acc hT)
    (fun G bga rs acc hT hall => hgdH G bga rs acc hT (hall 0 (by norm_num)))
  have hsp := hsplit_two U key domain hs hL P hdrLen F csX msX Pb Lay B fams xtE A HGd Alk T mlk hbr hhr
  have hbud : 3 * 2 ^ (126 - 106) + 2 * (2 ^ (126 - 111) + 2 ^ (126 - 113)) + 2 ^ 18 + 2 ^ 16 + 5
      + blockND P.geom.slots + 4 * (80 + 80 * 4096 + 2 ^ 14 + 2 ^ 14)
      + (1 * (80 + 80 * 4096 + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14)) ≤ 2 ^ 26 :=
    w16r2_budget_any 5 _ (by norm_num) hND'
  exact block_knowledge_target_mtN U hU hK2 key domain hs hL hL64 (by omega) P hdrLen F csX msX hpolyC hEval hdeg 5
    (by norm_num) hgeom hgt hℓs hℓd hℓk Pb Lay B fams hF hW h24 xtE q A hA GA GH GM EvA EvH EvM EvX ℓo hℓo 106 111 113
    (by norm_num) (by norm_num) (by norm_num) maskE εAa εBa εAh εBh hmE hAa hBa hAh hBh hM hEA hEH T' nr hT' hnr hX
    hsem hexec 80 (80 * 4096) 4 1 (w16r2DR P spR) (w16r2DH P spH) hksR hdgR' (fun i hi => (hfR i hi).1) (fun i hi => (hfR i hi).2)
    hNDR hcR Alk T mlk hN he hksH (fun _ _ _ _ => le_rfl) (fun _ _ => hfH.1) (fun _ _ => hfH.2) hNDH
    (EvHlpOf U key domain hs hL P hdrLen F csX msX A HGd) hcH hsp hbud

end Shape

end ZK60.Exec.Block
