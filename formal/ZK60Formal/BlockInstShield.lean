/-
D63 lane L31 (2026-11-09), part 4: **one Shieldstral T128 R13 block's knowledge statement** (the media app's classifier
block), with the openings' premises discharged (L28's proof at the Shieldstral schedule) and then L28's bookkeeping
premises discharged (this lane).

L28's `block_knowledge_open_r13` is stated at the R13 development rung's schedule (375 draws, 296 rounds). The app's
classifier blocks run L17's Shieldstral T128 R13 schedule (`R13.shieldSlots`, `shieldTerms`, `shieldDraws`: 451 draws,
370 rounds, degrees in `[1, 5]`). The proof is L28's with the schedule's facts replaced:

* `shield_defLen_r13` (`defLen = hdrLen + 1,293`), `shield_draws_sum_r13` (451), `shield_defND_le_r13`,
  `shield_blockND_r13` (1,159), `shield_budget_r13` (the block's budget at the proved opening exponents:
  `30,353,054` units, under `2^25`);
* **`block_knowledge_open_r13_shield`**: L28's statement at the Shieldstral schedule (generated from L28's theorem and
  proof, results/zk60_lean_l31_20261109/l31_mk_shield.py);
* **`block_knowledge_shield_r13`**: the same with the profile (`Link.profR13Shield`), the fields, `hcnt`, `hRd` and the
  reading definitions discharged, as `block_knowledge_rung_r13`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockInstProf

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## The Shieldstral T128 R13 schedule's numbers -/

/-- **At the Shieldstral T128 R13 block** the verifier's operations up to the end of the slot loop number
`hdrLen + 1293`. -/
theorem shield_defLen_r13 (P : BlockParams) (hdr : P.draws = R13.shieldDraws) (hsl : P.geom.slots = R13.shieldSlots)
    (h : ℕ) : defLen P h = h + 1293 := by
  have e : defOffW R13.shieldDraws R13.shieldSlots 0 R13.shieldSlots.length = 1283 := by decide
  rw [defLen, defOff_eq, hdr, hsl, e]

/-- The Shieldstral T128 R13 block's define draws: `451` in all. -/
theorem shield_draws_sum_r13 : ∑ k ∈ Finset.range 23, R13.shieldDraws k = 451 := by decide

/-- **At the Shieldstral T128 R13 block** a relation layer's draws weigh at most `dd·451`. -/
theorem shield_defND_le_r13 (P : BlockParams) (hdr : P.draws = R13.shieldDraws) (i : ℕ) (hi : i < 4) (dg : ℕ → ℕ)
    (dd : ℕ) (hdg : ∀ k ∈ w16r2RelKs i, dg k ≤ dd) : defND P (w16r2RelKs i) dg ≤ dd * 451 := by
  have h := defND_le P _ dg dd 23 hdg (w16r2RelKs_facts i hi).1 (w16r2RelKs_facts i hi).2
  rw [hdr, shield_draws_sum_r13] at h
  exact h

/-- The Shieldstral T128 R13 schedule's slot numerators: `Σ (n + e)·d = 1159`. -/
theorem shield_blockND_r13 : blockND R13.shieldSlots = 1159 := by decide

/-- **The Shieldstral T128 R13 block's budget at the proved opening exponents** (`M` `2^-106`, `opA` `2^-110`, `opB`
`2^-126`), four relation layers and one helper layer: `30,353,054` units of `2^-126` per query, under `2^26`. -/
theorem shield_budget_r13 :
    3 * 2 ^ (126 - 106) + 2 * (2 ^ (126 - 110) + 2 ^ (126 - 126)) + 2 ^ 18 + 2 ^ 16 + 5 + 1159
        + 4 * (80 + 80 * 451 + 2 ^ 14 + 2 ^ 14) + (1 * (80 + 80 * 451 + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14))
      ≤ 2 ^ 26 := by
  norm_num

theorem shield_budget_r13_val :
    3 * 2 ^ (126 - 106) + 2 * (2 ^ (126 - 110) + 2 ^ (126 - 126)) + 2 ^ 18 + 2 ^ 16 + 5 + 1159
        + 4 * (80 + 80 * 451 + 2 ^ 14 + 2 ^ 14) + (1 * (80 + 80 * 451 + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14))
      = 30353054 ∧ 30353054 ≤ 2 ^ 25 := by
  constructor <;> norm_num

section Shield

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

/-- **One Shieldstral T128 R13 block's knowledge error on the real run is at most the approved target plus the endpoint
term, for EVERY `q`, with the openings' and `M`'s premises discharged** (L28's `block_knowledge_open_r13` at the media
app's classifier block's schedule; the proof is L28's with the schedule's facts replaced). -/
theorem block_knowledge_open_r13_shield [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (hdr : P.draws = R13.shieldDraws) (hsl : P.geom.slots = R13.shieldSlots) (htm : P.geom.terms = R13.shieldTerms)
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
    obtain ⟨h1, h2, h3, h4⟩ := R13.shield_slot_facts k hk
    simp only [slotShape, slotTerms, hsl, htm]
    exact ⟨h1, h2, by omega, by omega⟩
  have hgt : P.geom.slots.length = P.geom.terms.length := by rw [hsl, htm]; rfl
  have hℓs : blockLen P.draws P.geom.slots pr.hdrLen ≤ 2 ^ 20 := by
    rw [hdr, hsl, R13.shield_len]
    omega
  have hℓd : defLen P pr.hdrLen ≤ 2 ^ 20 := by
    rw [shield_defLen_r13 P hdr hsl]
    omega
  have hℓk : pr.hdrLen + 10 ≤ 2 ^ 20 := by omega
  have hND : blockND P.geom.slots = 1159 := by rw [hsl]; exact shield_blockND_r13
  -- the relation layers
  have hksR : ∀ i, i < 4 → ∀ k ∈ (w16r2DR P spR i).ks, k < P.geom.slots.length := fun i hi k hk => by
    rw [hlen]
    exact (w16r2RelKs_facts i hi).2 k hk
  have hdgR' : ∀ i, i < 4 → ∀ k ∈ (w16r2DR P spR i).ks, (w16r2DR P spR i).dg k ≤ 80 := fun _ _ _ _ => le_rfl
  have hfR := fun i (hi : i < 4) => schedOf_facts P (w16r2RelKs i) (spR i) (fun _ => 80) (hdgR i hi)
  have hNDR : ∀ i, i < 4 → defND P (w16r2DR P spR i).ks (w16r2DR P spR i).dg ≤ 80 * 451 := fun i hi =>
    shield_defND_le_r13 P hdr i hi _ 80 (fun _ _ => le_rfl)
  have hcR := hcoverR_gen U key domain hs hL P pr.hdrLen F csX msX
    (fun cu rt => ZK60.Layout.R13.R13Rels S Pb Lay B (xtE cu rt)) A 4 (w16r2DR P spR) hvR hgdR
  -- the helper layer
  have hksH : ∀ i, i < 1 → ∀ k ∈ (w16r2DH P spH i).ks, k < P.geom.slots.length := fun _ _ k hk => by
    rw [hlen]
    exact (w16r2RelKs_facts 0 (by norm_num)).2 k hk
  have hfH := schedOf_facts P (w16r2RelKs 0) spH (fun _ => 80) hdgH
  have hNDH : ∀ i, i < 1 → defND P (w16r2DH P spH i).ks (w16r2DH P spH i).dg ≤ 80 * 451 := fun _ _ =>
    shield_defND_le_r13 P hdr 0 (by norm_num) _ 80 (fun _ _ => le_rfl)
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
      + blockND P.geom.slots + 4 * (80 + 80 * 451 + 2 ^ 14 + 2 ^ 14)
      + (1 * (80 + 80 * 451 + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14)) ≤ 2 ^ 26 := by
    rw [hND]
    exact shield_budget_r13
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
    le_rfl hX hsem hexec εend hEnd 80 (80 * 451) 4 1 (w16r2DR P spR) (w16r2DH P spH) hksR hdgR'
    (fun i hi => (hfR i hi).1) (fun i hi => (hfR i hi).2) hNDR hcR Alk T mlk hN he hksH (fun _ _ _ _ => le_rfl)
    (fun _ _ => hfH.1) (fun _ _ => hfH.2) hNDH (EvHlpOf U key domain hs hL P pr.hdrLen F csX msX A HGd) hcH hsp hbud

/-- **One Shieldstral T128 R13 block's knowledge error on the real run, with L28's bookkeeping premises discharged**
(D63 lane L31; the media app's classifier block). As `block_knowledge_rung_r13`, for a Shieldstral T128 R13 block
verifier (`Link.IsShieldR13`) and the reading definitions `Link.csShieldR13`, `Link.msRung`. -/
theorem block_knowledge_shield_r13 [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsShieldR13 P tag rowsOf)
    (hdc : Link.DefCm P Link.aCntR13Shield Link.hCntR13Shield)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : ∀ cu rt, SlotEval U P ((Link.csShieldR13 U tag hL20 csE) cu rt) ((Link.msRung U tag hL20) cu rt) (F cu rt))
    (hdeg : ∀ cu rt k sn, IndDegLE (slotShape P k).2.2 (F cu rt k sn))
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
    (hvR : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F (Link.csShieldR13 U tag hL20 csE) (Link.msRung U tag
      hL20) A G bga rs acc → ∀ i, i < 4 →
      (∀ j, j < i → SchedGd (w16r2DR P spR j) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      SchedVan U P (w16r2DR P spR i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs)
    (hgdR : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F (Link.csShieldR13 U tag hL20 csE) (Link.msRung U tag
      hL20) A G bga rs acc →
      (∀ i, i < 4 → SchedGd (w16r2DR P spR i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      ZK60.Layout.R13.R13Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)))
    -- the helper layer and LogUp
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hvH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F (Link.csShieldR13 U tag hL20 csE) (Link.msRung U tag
      hL20) A G bga rs acc →
      SchedVan U P (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs)
    (hgdH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F (Link.csShieldR13 U tag hL20 csE) (Link.msRung U tag
      hL20) A G bga rs acc →
      SchedGd (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 35153256)
    (hbr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F (Link.csShieldR13 U tag hL20 csE) (Link.msRung U tag
      hL20) A G bga rs acc →
      ZK60.Layout.R13.R13Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) →
      ¬ ZK60.Layout.R13.R13Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) →
      ∃ l, ∀ j, T j ≠ Alk (cutsOf key domain hs hL A G).1 l)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F (Link.csShieldR13 U tag hL20 csE) (Link.msRung U tag
      hL20) A G bga rs acc →
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
  have hlen23 : P.geom.slots.length = 23 := by rw [hP.hsl]; rfl
  have hd1 : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 := by
    intro k hk
    rw [hlen23] at hk
    have h1 := (R13.shield_slot_facts k hk).1
    simp only [slotShape, hP.hsl]
    exact h1
  exact block_knowledge_open_r13_shield U hU hK2 key domain hs hL hL64 hL20 P hP.hdr hP.hsl hP.htm
    (Link.profR13Shield P hP.hdr hP.hsl hP.hag hP.hhg tag hdrLen hdrSq hh hq) hh F
    (Link.csShieldR13 U tag hL20 csE) (Link.msRung U tag hL20) hpolyC hEval hdeg Pb Lay B hW13 h24 xtE q A hA rfl rowsOf
    hP.hPm hP.hPp hP.hrA hP.hrH
    ⟨by show 8 * 4577 ≤ L; omega, by show 8 * 4390 ≤ L; omega, by show 8 * (2 * 23 + 4) ≤ L; omega⟩
    (by rw [hP.hnf]; norm_num) (by rw [hP.hnf]; norm_num)
    (fun G bga rs acc hacc => Link.hcnt_of_defCm P hdrLen key domain Link.aCntR13Shield Link.hCntR13Shield 146 54 23 hlen23
      Link.cnt_sums.2.2.2.2.1 Link.cnt_sums.2.2.2.2.2 hdc G (A.run G) bga rs acc hacc.1)
    (tAccRd P hdrLen)
    (fun G bga rs acc hacc _ => by
      rw [accRd_slotTrace P hdrLen key domain hd1 G (A.run G) bga rs acc hacc.1]
      exact ⟨rfl, rfl, rfl⟩)
    (fun _ _ _ => rfl) (fun _ _ _ => rfl) (fun _ _ _ => rfl) εend hEnd spR hdgR hvR hgdR HGd spH hdgH hvH hgdH Alk T
    mlk hN he hbr hhr

end Shield

end ZK60.Exec.Block
