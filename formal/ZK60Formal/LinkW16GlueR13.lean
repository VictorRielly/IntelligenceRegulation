/-
D63 lane L28 (2026-11-09), part 6: **one R13 block's knowledge statement with the openings' premises discharged**
(the media app's real profile).

R13's regular opening has `log_cols 14`, rate `1/4`, `Q = q_pad = 256` (L17's `r13Prm`): the codeword length is `2^16`,
the tree depth `16`, the index squeezes `64`, and the unique-decoding radius is `e = 24448`
(`2e + (2^14 + 256) = 2^16`, tight). `M` is W16R2's (L17). So the R13 instance is `LinkW16GlueW16.lean`'s generic
machinery at the geometry `(h, Q, e) = (16, 256, 24448)`, with L17's `pcsFieldR13` (acceptance is `PcsOk` at `r13Prm`,
`r13OpenCheck_ok_iff`) and `r13_colEnc_spec`, and R13's numbers:

* **`opA_eps_r13`**: `opA`'s error at R13, `2^16/p² · bias ≤ 2^-110` (W16R2: `2^-111`), for a variable `p` (L7-4);
* **`opB_eps_r13u`**: `opB`'s error at R13's unique-decoding radius, `((2^16 − 24449)/2^16)^256 ≤ 2^-126` (in fact
  `2^-172`, L17's `r13_col_far_nat`);
* `r13_budget_open`: the R13 rung block's budget at these exponents is `30,322,419` units, under `2^25`;
* **`block_knowledge_open_r13`**: for EVERY `q`,
  `Pr[BlockAcc ∧ sqN header = hdrSq ∧ ¬BlockSat] ≤ εsTarget q + εend`, L23's `block_knowledge_target_r13` with the
  openings' and `M`'s premises (`hM`, `hEA`, `hEH`, `hX`, `hsem`, `hexec`) DISCHARGED, on the real run (L22-1) and with
  the endpoint claims as a run-level term (L22-5). The statement is generated from L23's
  (results/zk60_lean_l28_20261107/l28_mk_r13.py).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.LinkW16GlueW16
import ZK60Formal.CoverW16R13
import ZK60Formal.OpeningR13

set_option autoImplicit false

namespace ZK60.Exec.Link

open ZK60.Sound
open ZK60.Exec
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## R13's per-round errors -/

section R13Numbers

/-- **`opB`'s error at R13's unique-decoding radius** (`N = 2^16`, `e = 24448`, `Q = 256`): at most `2^-126` (in fact
`2^-172`, L17's `r13_col_far_nat`; L17-4's margin, now on the chain). -/
theorem opB_eps_r13u :
    (((Fintype.card (Fin (2 ^ 16)) - (24448 + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ 16))) ^ 256 * 1
      ≤ (2⁻¹ : ℝ≥0∞) ^ 126 := by
  rw [mul_one, Fintype.card_fin, inv_two_pow_eq, natCast_div_pow]
  refine natCast_div_le_div (by positivity) (by norm_num) ?_
  calc (2 ^ 16 - (24448 + 1)) ^ 256 * 2 ^ 126 ≤ (2 ^ 16 - (24448 + 1)) ^ 256 * 2 ^ 172 :=
        Nat.mul_le_mul_left _ (Nat.pow_le_pow_right (by norm_num) (by norm_num))
    _ ≤ 1 * (2 ^ 16) ^ 256 := ZK60.Exec.R13.r13_col_far_nat

/-- **`opA`'s error at R13** (`A = N = 2^16` at the δ/2 radius, `|F| = p²`, `p` within `2^32` below `2^64`, the
`(λ, ρ)` bias over at most `2^61` squeezes at most `2`): at most `2^-110`. Stated for a variable `p` (L7-4). -/
theorem opA_eps_r13 {F : Type} [Fintype F] (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p)
    (hF : Fintype.card F = p ^ 2) {w0 : ℕ} (hw0 : w0 ≤ 2 ^ 61) :
    ((2 ^ 16 : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0)
      ≤ (2⁻¹ : ℝ≥0∞) ^ 110 := by
  have hb : (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0) ≤ ((2 : ℕ) : ℝ≥0∞) := by
    exact_mod_cast fp2_bias_pow_le_two hp1 (by omega)
  have hp0 : 0 < p := by omega
  calc ((2 ^ 16 : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0)
      ≤ ((2 ^ 16 : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * ((2 : ℕ) : ℝ≥0∞) := by
        rw [hF]
        exact mul_le_mul' le_rfl hb
    _ = ((2 ^ 16 * 2 : ℕ) : ℝ≥0∞) / ((p ^ 2 * 1 : ℕ) : ℝ≥0∞) := by
        rw [← natCast_div_mul_div, Nat.cast_one, div_one]
    _ ≤ (2⁻¹ : ℝ≥0∞) ^ 110 := by
        rw [inv_two_pow_eq]
        refine natCast_div_le_div (mul_ne_zero (pow_ne_zero 2 (by omega)) one_ne_zero) (by norm_num) ?_
        calc 2 ^ 16 * 2 * 2 ^ 110 = 2 ^ 127 := by norm_num
          _ ≤ (2 ^ 64 - 2 ^ 32) ^ 2 := by norm_num
          _ ≤ p ^ 2 := Nat.pow_le_pow_left hp2 2
          _ = 1 * (p ^ 2 * 1) := by ring

/-- **The R13 rung block's budget at the proved opening exponents** (`M` `2^-106`, `opA` `2^-110`, `opB` `2^-126`):
exactly `30,322,419` units of `2^-126` per query, under `2^25` (L23's `r13_budget` at `105 / 105` allows
`38,579,953`: the unique-decoding radius makes `opB` cost one unit, not `2^21`). -/
theorem r13_budget_open :
    3 * 2 ^ (126 - 106) + 2 * (2 ^ (126 - 110) + 2 ^ (126 - 126)) + 2 ^ 18 + 2 ^ 16 + 5 + 924
        + 4 * (80 + 80 * 375 + 2 ^ 14 + 2 ^ 14) + (1 * (80 + 80 * 375 + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14))
      = 30322419 ∧ 30322419 ≤ 2 ^ 25 := by
  constructor <;> norm_num

end R13Numbers

end ZK60.Exec.Link

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Circuit (gP GF)
open scoped ENNReal

section Open

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

/-- **One R13 rung block's knowledge error on the real run is at most the approved target plus the endpoint term, for
EVERY `q`, with the openings' and `M`'s premises discharged** (D63 lane L28; the media app's real profile). As
`block_knowledge_open_w16r2`, at the R13 rung's schedule (L17, L23's `block_knowledge_target_r13`), with L17's fields
(`maskField`, `pcsFieldR13`), R13's opening geometry (`2^16` columns of depth `16`, `256` queries and pads, `64` index
squeezes, radius `24448`), R13's relations and lookups of the extracted R13 planes, and the shifts in their limb
windows (`R13Windows`). -/
theorem block_knowledge_open_r13 [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (hdr : P.draws = R13.rungDraws) (hsl : P.geom.slots = R13.rungSlots) (htm : P.geom.terms = R13.rungTerms)
    (pr : Link.OProf P) (hh : pr.hdrLen ≤ 2 ^ 19)
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
    -- the openings at R13 (lane L28): the profile's fields, the claims' counts (L22-2), the accumulator's reader on
    -- the verifier's own trace (L22-7), the semantics reading the extracted data, the endpoint term (L22-5)
    (hm64 : pr.mI = 64) (rowsOf : Cm → ℕ) (hPm : P.maskVerify = maskField pr.tag pr.S)
    (hPp : P.pcsVerify = ZK60.Exec.R13.pcsFieldR13 pr.tag rowsOf) (hrA : rowsOf .a = pr.rA) (hrH : rowsOf .h = pr.rH)
    (hrows : 8 * pr.rA ≤ L ∧ 8 * pr.rH ≤ L ∧ 8 * (2 * pr.S + 4) ≤ L)
    (hk : 0 < P.nFunctionals) (hkF : P.nFunctionals ≤ 2 ^ 20)
    (hcnt : ∀ G bga rs acc, BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc →
      acc.claims.a.length = pr.nA ∧ (acc.claims.h ++ [P.logupSumClaim]).length = pr.nH)
    (accRd : List (TItem × Dig) → Acc)
    (hRd : ∀ G bga rs acc, BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc →
      Link.sqN (A.run G).1 = pr.hdrSq →
        (accRd (Link.slotTrace P key domain G (A.run G))).fs ++ (accRd (Link.slotTrace P key domain G (A.run G))).hostFs
          = acc.fs ++ acc.hostFs
        ∧ (accRd (Link.slotTrace P key domain G (A.run G))).claims.a = acc.claims.a
        ∧ (accRd (Link.slotTrace P key domain G (A.run G))).claims.h = acc.claims.h)
    (hcsA : ∀ cu rt z, csX cu rt .a z = Link.claimSem U pr.rA 14 256
      (decodeRows (Link.encG (K := K) 16 256) 24448 (Link.UxC pr.tag L (by omega) 16 pr.rA (N := 2 ^ 16) cu.1 rt.1)) z)
    (hcsH : ∀ cu rt z, csX cu rt .h z = Link.claimSem U pr.rH 14 256
      (decodeRows (Link.encG (K := K) 16 256) 24448 (Link.UxC pr.tag L (by omega) 16 pr.rH (N := 2 ^ 16) cu.2.2 rt.2.2)) z)
    (hms : ∀ cu rt ts, msX cu rt ts = Link.msOfTab U pr.S (Link.colsC pr.tag L (by omega) cu.2.1 rt.2.1) ts)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = pr.hdrSq ∧ ¬ EndTrue U (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc) ≤ εend)
    -- the four relation layers (certified slot polynomials) and their per-outcome algebra
    (spR : ℕ → Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgR : ∀ i, i < 4 → ∀ cu rt k h, k ∈ w16r2RelKs i → (spR i cu rt k h).dg ≤ 80)
    (hvR : ∀ G bga rs acc, AccT U key domain hs hL P pr.hdrLen F csX msX A G bga rs acc → ∀ i, i < 4 →
      (∀ j, j < i → SchedGd (w16r2DR P spR j) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      SchedVan U P (w16r2DR P spR i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs)
    (hgdR : ∀ G bga rs acc, AccT U key domain hs hL P pr.hdrLen F csX msX A G bga rs acc →
      (∀ i, i < 4 → SchedGd (w16r2DR P spR i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      ZK60.Layout.R13.R13Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)))
    -- the helper layer and LogUp
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hvH : ∀ G bga rs acc, AccT U key domain hs hL P pr.hdrLen F csX msX A G bga rs acc →
      SchedVan U P (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs)
    (hgdH : ∀ G bga rs acc, AccT U key domain hs hL P pr.hdrLen F csX msX A G bga rs acc →
      SchedGd (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 35153256)
    (hbr : ∀ G bga rs acc, AccT U key domain hs hL P pr.hdrLen F csX msX A G bga rs acc →
      ZK60.Layout.R13.R13Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) →
      ¬ ZK60.Layout.R13.R13Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) →
      ∃ l, ∀ j, T j ≠ Alk (cutsOf key domain hs hL A G).1 l)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P pr.hdrLen F csX msX A G bga rs acc →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = pr.hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X (Lay.dPos p))
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay ((xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).toW16 S)))
      ≤ εsTarget q + εend := by
  have hlen : P.geom.slots.length = 23 := by rw [hsl]; rfl
  have hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ 5
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L := by
    intro k hk
    rw [hlen] at hk
    obtain ⟨h1, h2, h3, h4⟩ := R13.rung_slot_facts k hk
    simp only [slotShape, slotTerms, hsl, htm]
    exact ⟨h1, h2, by omega, by omega⟩
  have hgt : P.geom.slots.length = P.geom.terms.length := by rw [hsl, htm]; rfl
  have hℓs : blockLen P.draws P.geom.slots pr.hdrLen ≤ 2 ^ 20 := by
    rw [hdr, hsl, R13.rung_len]
    omega
  have hℓd : defLen P pr.hdrLen ≤ 2 ^ 20 := by
    rw [rung_defLen_r13 P hdr hsl]
    omega
  have hℓk : pr.hdrLen + 10 ≤ 2 ^ 20 := by omega
  have hND : blockND P.geom.slots = 924 := by rw [hsl, R13.rungSlots_eq_w16r2]; exact rung_blockND
  -- the relation layers
  have hksR : ∀ i, i < 4 → ∀ k ∈ (w16r2DR P spR i).ks, k < P.geom.slots.length := fun i hi k hk => by
    rw [hlen]
    exact (w16r2RelKs_facts i hi).2 k hk
  have hdgR' : ∀ i, i < 4 → ∀ k ∈ (w16r2DR P spR i).ks, (w16r2DR P spR i).dg k ≤ 80 := fun _ _ _ _ => le_rfl
  have hfR := fun i (hi : i < 4) => schedOf_facts P (w16r2RelKs i) (spR i) (fun _ => 80) (hdgR i hi)
  have hNDR : ∀ i, i < 4 → defND P (w16r2DR P spR i).ks (w16r2DR P spR i).dg ≤ 80 * 375 := fun i hi =>
    r13_defND_le P hdr i hi _ 80 (fun _ _ => le_rfl)
  have hcR := hcoverR_gen U key domain hs hL P pr.hdrLen F csX msX
    (fun cu rt => ZK60.Layout.R13.R13Rels S Pb Lay B (xtE cu rt)) A 4 (w16r2DR P spR) hvR hgdR
  -- the helper layer
  have hksH : ∀ i, i < 1 → ∀ k ∈ (w16r2DH P spH i).ks, k < P.geom.slots.length := fun _ _ k hk => by
    rw [hlen]
    exact (w16r2RelKs_facts 0 (by norm_num)).2 k hk
  have hfH := schedOf_facts P (w16r2RelKs 0) spH (fun _ => 80) hdgH
  have hNDH : ∀ i, i < 1 → defND P (w16r2DH P spH i).ks (w16r2DH P spH i).dg ≤ 80 * 375 := fun _ _ =>
    r13_defND_le P hdr 0 (by norm_num) _ 80 (fun _ _ => le_rfl)
  have hcH := hcoverH_layers U key domain hs hL P pr.hdrLen F csX msX A HGd 1 (w16r2DH P spH)
    (fun G bga rs acc hT i hi _ => by
      have hi0 : i = 0 := by omega
      subst hi0
      exact hvH G bga rs acc hT)
    (fun G bga rs acc hT hall => hgdH G bga rs acc hT (hall 0 (by norm_num)))
  have hsp := hsplit_gen U key domain hs hL P pr.hdrLen F csX msX
    (fun cu rt => ZK60.Layout.R13.R13Rels S Pb Lay B (xtE cu rt))
    (fun cu rt => ZK60.Layout.R13.R13Lookups S Pb Lay B (xtE cu rt)) A HGd Alk T mlk hbr hhr
  have hbud : 3 * 2 ^ (126 - 106) + 2 * (2 ^ (126 - 110) + 2 ^ (126 - 126)) + 2 ^ 18 + 2 ^ 16 + 5
      + blockND P.geom.slots + 4 * (80 + 80 * 375 + 2 ^ 14 + 2 ^ 14)
      + (1 * (80 + 80 * 375 + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14)) ≤ 2 ^ 26 := by
    rw [hND]
    exact r13_budget 106 110 126 (by norm_num) (by norm_num) (by norm_num)
  -- the openings (lane L28), at R13's geometry `(16, 256, 24448)`: the kinds' bounds, the extraction failure,
  -- `hsem`, `hexec`
  have hbij := ZK60.Hiding.fp2_bijective hK2 hU seven_not_square
  have hF2 : Fintype.card K = gP ^ 2 := card_of_pairs gP (Equiv.ofBijective _ hbij)
  have hp1 : gP ≤ 2 ^ 64 := by norm_num [gP]
  have hp2 : 2 ^ 64 - 2 ^ 32 ≤ gP := by norm_num [gP]
  have h64 : 64 ≤ L := by omega
  have hgeomL : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L :=
    fun k hk => ⟨(hgeom k hk).1, (hgeom k hk).2.2.1, (hgeom k hk).2.2.2⟩
  have hm : (256 + 3) / 4 = pr.mI := by omega
  have hQm : 256 ≤ pr.mI * 4 := by omega
  have hPp' : ∀ (H : HIn → Dig) (cm : Cm) (root : Dig) (cl : List ZClaim) (o : OpeningZk) (t t' : Tr),
      P.pcsVerify H cm root cl o t = .ok t' →
        PcsOk H pr.tag ZK60.Exec.R13.r13Prm (cosetPt (rootFp 16)) (colEncLag (rootFp 14) (2 ^ 14) 256) root (rowsOf cm)
          14 (cl.map toZClaim) (toOZ o) t t' := by
    intro H cm root cl o t t' h
    rw [hPp, ZK60.Exec.R13.pcsFieldR13, mapErr_ok, ZK60.Exec.R13.r13OpenCheck_ok_iff] at h
    exact h
  have hM := Link.evMW_bound U hbij pr L h64 key domain hs hL accRd hL64 hk (by unfold Link.OProf.aM; omega) q A hA
  have hEA := Link.evOW_bound U hbij pr L h64 key domain hs hL accRd hL64 16 256 24448 (by norm_num) (by norm_num)
    (by norm_num) hQm pr.rA pr.nA pr.hdrLen (pr.aA + (pr.nA + pr.rA)) pr.aA pr.aBA (by omega)
    (by unfold Link.OProf.aA Link.OProf.aM; omega) (by unfold Link.OProf.aBA; omega) (fun acc => acc.claims.a) q A hA
  have hEH := Link.evOW_bound U hbij pr L h64 key domain hs hL accRd hL64 16 256 24448 (by norm_num) (by norm_num)
    (by norm_num) hQm pr.rH pr.nH (pr.hdrLen + 7) (pr.aH + (pr.nH + pr.rH)) pr.aH pr.aBH (by omega)
    (by unfold Link.OProf.aH Link.OProf.aBA Link.OProf.aA Link.OProf.aM; omega) (by unfold Link.OProf.aBH; omega)
    (fun acc => acc.claims.h ++ [P.logupSumClaim]) q A hA
  have hX := Link.extract_fail_block pr.tag L h64 key domain hs hL 256 256 256 16 16 12 q A hA
  have hsem := Link.hsem_geo U pr L hL20 hL64 key domain hs hL accRd rowsOf ZK60.Exec.R13.r13Prm 16 256 24448
    (colEncLag (rootFp 14) (2 ^ 14) 256) rfl rfl ZK60.Exec.R13.r13Prm_nn (by decide) (by norm_num) (by norm_num) hm hPm
    hPp' hrA hrH hgt hgeomL A hcnt hRd csX msX hcsA hcsH hms
  have hexec := Link.hexec_geo U hU hbij pr L hL20 hL64 key domain hs hL accRd rowsOf ZK60.Exec.R13.r13Prm 16 256 24448
    (colEncLag (rootFp 14) (2 ^ 14) 256) rfl rfl rfl ZK60.Exec.R13.r13Prm_nn (by decide) (by norm_num) (by norm_num) hm
    hQm (ZK60.Exec.R13.r13_colEnc_spec U) hPm hPp' hrA hrH hgt hgeomL hrows A hcnt hRd
  exact block_knowledge_target_R U hU hK2 key domain hs hL hL64 (by omega) P pr.hdrLen F csX msX hpolyC hEval hdeg 5
    (by norm_num) hgeom hgt hℓs hℓd hℓk
    (fun cu rt => ZK60.Layout.R13.R13Rels S Pb Lay B (xtE cu rt))
    (fun cu rt => ZK60.Layout.R13.R13Lookups S Pb Lay B (xtE cu rt))
    (fun cu rt => ZK60.Block.BlockSat Pb (fun p => (xtE cu rt).X (Lay.dPos p)) (fun p => (xtE cu rt).X2 (Lay.dPos p))
      (ZK60.Layout.toWit Lay ((xtE cu rt).toW16 S)))
    (fun cu rt hr hl => ZK60.Layout.R13.blockSat_of_slots_r13 Pb Lay B (xtE cu rt) hW13 h24 hr hl) q A hA
    (fun G => Link.sqN (A.run G).1 = pr.hdrSq)
    (Link.GOW U pr L h64 key domain hs hL accRd 16 256 24448 pr.rA pr.nA pr.hdrLen pr.aA (fun acc => acc.claims.a) A)
    (Link.GOW U pr L h64 key domain hs hL accRd 16 256 24448 pr.rH pr.nH (pr.hdrLen + 7) pr.aH
      (fun acc => acc.claims.h ++ [P.logupSumClaim]) A)
    (Link.GMW U pr L h64 key domain hs hL accRd A)
    (Link.EvOW U hbij pr L h64 key domain hs hL accRd 16 256 24448 hQm pr.rA pr.nA pr.hdrLen (pr.aA + (pr.nA + pr.rA))
      pr.aA pr.aBA (fun acc => acc.claims.a) A)
    (Link.EvOW U hbij pr L h64 key domain hs hL accRd 16 256 24448 hQm pr.rH pr.nH (pr.hdrLen + 7)
      (pr.aH + (pr.nH + pr.rH)) pr.aH pr.aBH (fun acc => acc.claims.h ++ [P.logupSumClaim]) A)
    (Link.EvMW U hbij pr L h64 key domain hs hL accRd A)
    (Link.EvXB pr.tag L h64 key domain hs hL 256 256 256 16 16 12 A) (2 ^ 20) le_rfl 106 110 126 (by norm_num)
    (by norm_num) (by norm_num) _ _ _ _ _ (maskEps_le hF2 hkF pr.hS) (Link.opA_eps_r13 gP hp1 hp2 hF2 pr.hwA')
    Link.opB_eps_r13u (Link.opA_eps_r13 gP hp1 hp2 hF2 pr.hwH') Link.opB_eps_r13u hM hEA hEH _ 3 (Link.xfail_T_r13 q)
    le_rfl hX hsem hexec εend hEnd 80 (80 * 375) 4 1 (w16r2DR P spR) (w16r2DH P spH) hksR hdgR'
    (fun i hi => (hfR i hi).1) (fun i hi => (hfR i hi).2) hNDR hcR Alk T mlk hN he hksH (fun _ _ _ _ => le_rfl)
    (fun _ _ => hfH.1) (fun _ _ => hfH.2) hNDH (EvHlpOf U key domain hs hL P pr.hdrLen F csX msX A HGd) hcH hsp hbud

end Open

end ZK60.Exec.Block
