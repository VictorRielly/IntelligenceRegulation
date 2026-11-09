/-
D63 lane L28 (2026-11-07), part 5: **one W16R2 block's knowledge statement with the openings' premises discharged**.

L23's `block_knowledge_target_w16r2` is the W16R2 rung's block statement, up to (among others) the openings' and `M`'s
bounds and links (`hM`, `hEA`, `hEH`, `hX`, `hsem`, `hexec`). Here those premises are DISCHARGED, at the concrete chain
(`LinkW16GlueW16.lean`, at W16R2's geometry `(h, Q, e) = (15, 280, 8052)`): `M`'s and the two openings' chain bounds
(L20's `mask_knowledge_chain_pos`, `opening_knowledge_chain_pos`, at W16R2's numbers: `M ≤ 2^-106`, `opA ≤ 2^-111`,
`opB ≤ 2^-113`), the extraction failure at the verifier's queries (L22's `extract_fail_block`), `hsem` (`hsem_geo`) and
`hexec` (`hexec_geo`). The statement is the real run's (L22-1, the coordinator's decision): the event is `BlockAcc` with the
header's squeeze count the profile's, and the endpoint claims are a run-level term (L22-5, `εend`). The composition is
L23's, re-done on that event (`block_knowledge_target_R`).

* **`block_knowledge_open_w16r2`**: for EVERY `q`,
  `Pr[BlockAcc ∧ sqN header = hdrSq ∧ ¬BlockSat] ≤ εsTarget q + εend`, given L23's remaining premises (the slot
  polynomials and the per-outcome algebra) and this lane's: the profile's fields and counts, the accumulator's reader
  on the verifier's own trace, and the semantics `csX`, `msX` reading the extracted matrices and table.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.LinkW16GlueW16
import ZK60Formal.CoverW16Inst

set_option autoImplicit false

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

/-- **One W16R2 rung block's knowledge error on the real run is at most the approved target plus the endpoint term, for
EVERY `q`, with the openings' and `M`'s premises discharged** (D63 lane L28). For the W16R2 rung's block verifier with
L10's fields (`maskField`, `pcsField`), a profile `pr` (the header's length and squeeze count, `A`'s and `H`'s rows and
claim counts, `M`'s spec count), the accumulator's reader `accRd` agreeing with the verifier on its own trace (L22-7),
the semantics `csX`, `msX` of the extracted matrices and table, and L23's remaining premises (the slot polynomials over
the extracted data and the per-outcome algebra): the block verifier accepts on a header of the profile's squeeze count
while the extracted planes do not satisfy `BlockSat` with probability at most `εsTarget q + εend`, `εend` the run-level
term of the endpoint claims (L22-5). -/
theorem block_knowledge_open_w16r2 [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (hdr : P.draws = W16R2.rungDraws) (hsl : P.geom.slots = W16R2.rungSlots) (htm : P.geom.terms = W16R2.rungTerms)
    (pr : Link.OProf P) (hh : pr.hdrLen ≤ 2 ^ 19)
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
    -- the openings at W16R2 (lane L28): the profile's fields, the claims' counts (L22-2), the accumulator's reader on
    -- the verifier's own trace (L22-7), the semantics reading the extracted data, the endpoint term (L22-5)
    (hm70 : pr.mI = 70) (rowsOf : Cm → ℕ) (hPm : P.maskVerify = maskField pr.tag pr.S)
    (hPp : P.pcsVerify = pcsField pr.tag rowsOf) (hrA : rowsOf .a = pr.rA) (hrH : rowsOf .h = pr.rH)
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
    (hcsA : ∀ cu rt z, csX cu rt .a z = Link.claimSem U pr.rA 14 280
      (decodeRows (Link.encG (K := K) 15 280) 8052 (Link.UxC pr.tag L (by omega) 15 pr.rA (N := 2 ^ 15) cu.1 rt.1)) z)
    (hcsH : ∀ cu rt z, csX cu rt .h z = Link.claimSem U pr.rH 14 280
      (decodeRows (Link.encG (K := K) 15 280) 8052 (Link.UxC pr.tag L (by omega) 15 pr.rH (N := 2 ^ 15) cu.2.2 rt.2.2)) z)
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
      ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)))
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
      ¬ ZK60.Layout.W16Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) fams →
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
          (ZK60.Layout.toWit Lay (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))))
      ≤ εsTarget q + εend := by
  have hlen : P.geom.slots.length = 23 := by rw [hsl]; rfl
  have hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ 5
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L := by
    intro k hk
    rw [hlen] at hk
    obtain ⟨h1, h2, h3, h4⟩ := W16R2.rung_slot_facts k hk
    simp only [slotShape, slotTerms, hsl, htm]
    exact ⟨h1, h2, by omega, by omega⟩
  have hgt : P.geom.slots.length = P.geom.terms.length := by rw [hsl, htm]; rfl
  have hℓs : blockLen P.draws P.geom.slots pr.hdrLen ≤ 2 ^ 20 := by
    rw [hdr, hsl, W16R2.rung_len]
    omega
  have hℓd : defLen P pr.hdrLen ≤ 2 ^ 20 := by
    rw [rung_defLen P hdr hsl]
    omega
  have hℓk : pr.hdrLen + 10 ≤ 2 ^ 20 := by omega
  have hND : blockND P.geom.slots = 924 := by rw [hsl]; exact rung_blockND
  -- the relation layers
  have hksR : ∀ i, i < 4 → ∀ k ∈ (w16r2DR P spR i).ks, k < P.geom.slots.length := fun i hi k hk => by
    rw [hlen]
    exact (w16r2RelKs_facts i hi).2 k hk
  have hdgR' : ∀ i, i < 4 → ∀ k ∈ (w16r2DR P spR i).ks, (w16r2DR P spR i).dg k ≤ 80 := fun _ _ _ _ => le_rfl
  have hfR := fun i (hi : i < 4) => schedOf_facts P (w16r2RelKs i) (spR i) (fun _ => 80) (hdgR i hi)
  have hNDR : ∀ i, i < 4 → defND P (w16r2DR P spR i).ks (w16r2DR P spR i).dg ≤ 80 * 351 := fun i hi =>
    w16r2_defND_le P hdr i hi _ 80 (fun _ _ => le_rfl)
  have hcR := hcoverR_layers U key domain hs hL P pr.hdrLen F csX msX Pb Lay B xtE A 4 (w16r2DR P spR) hvR hgdR
  -- the helper layer
  have hksH : ∀ i, i < 1 → ∀ k ∈ (w16r2DH P spH i).ks, k < P.geom.slots.length := fun _ _ k hk => by
    rw [hlen]
    exact (w16r2RelKs_facts 0 (by norm_num)).2 k hk
  have hfH := schedOf_facts P (w16r2RelKs 0) spH (fun _ => 80) hdgH
  have hNDH : ∀ i, i < 1 → defND P (w16r2DH P spH i).ks (w16r2DH P spH i).dg ≤ 80 * 351 := fun _ _ =>
    w16r2_defND_le P hdr 0 (by norm_num) _ 80 (fun _ _ => le_rfl)
  have hcH := hcoverH_layers U key domain hs hL P pr.hdrLen F csX msX A HGd 1 (w16r2DH P spH)
    (fun G bga rs acc hT i hi _ => by
      have hi0 : i = 0 := by omega
      subst hi0
      exact hvH G bga rs acc hT)
    (fun G bga rs acc hT hall => hgdH G bga rs acc hT (hall 0 (by norm_num)))
  have hsp := hsplit_two U key domain hs hL P pr.hdrLen F csX msX Pb Lay B fams xtE A HGd Alk T mlk hbr hhr
  have hbud : 3 * 2 ^ (126 - 106) + 2 * (2 ^ (126 - 111) + 2 ^ (126 - 113)) + 2 ^ 18 + 2 ^ 16 + 5
      + blockND P.geom.slots + 4 * (80 + 80 * 351 + 2 ^ 14 + 2 ^ 14)
      + (1 * (80 + 80 * 351 + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14)) ≤ 2 ^ 26 := by
    rw [hND]
    exact w16r2_budget_mtN
  -- the openings (lane L28): the kinds' bounds, the extraction failure, `hsem`, `hexec`
  have hbij := ZK60.Hiding.fp2_bijective hK2 hU seven_not_square
  have hF2 : Fintype.card K = gP ^ 2 := card_of_pairs gP (Equiv.ofBijective _ hbij)
  have hp1 : gP ≤ 2 ^ 64 := by norm_num [gP]
  have hp2 : 2 ^ 64 - 2 ^ 32 ≤ gP := by norm_num [gP]
  have h64 : 64 ≤ L := by omega
  have hgeomL : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L :=
    fun k hk => ⟨(hgeom k hk).1, (hgeom k hk).2.2.1, (hgeom k hk).2.2.2⟩
  have hm : (280 + 3) / 4 = pr.mI := by omega
  have hQm : 280 ≤ pr.mI * 4 := by omega
  have hnn : w16r2Prm.nn = 2 ^ 15 := by norm_num [PcsPrm.nn, w16r2Prm]
  have hPp' : ∀ (H : HIn → Dig) (cm : Cm) (root : Dig) (cl : List ZClaim) (o : OpeningZk) (t t' : Tr),
      P.pcsVerify H cm root cl o t = .ok t' →
        PcsOk H pr.tag w16r2Prm (cosetPt (rootFp 15)) (colEncLag (rootFp 14) (2 ^ 14) 280) root (rowsOf cm) 14
          (cl.map toZClaim) (toOZ o) t t' := by
    intro H cm root cl o t t' h
    rw [hPp, pcsField, mapErr_ok, w16r2OpenCheck_ok_iff] at h
    exact h
  have hM := Link.evMW_bound U hbij pr L h64 key domain hs hL accRd hL64 hk (by unfold Link.OProf.aM; omega) q A hA
  have hEA := Link.evOW_bound U hbij pr L h64 key domain hs hL accRd hL64 15 280 8052 (by norm_num) (by norm_num)
    (by norm_num) hQm pr.rA pr.nA pr.hdrLen (pr.aA + (pr.nA + pr.rA)) pr.aA pr.aBA (by omega)
    (by unfold Link.OProf.aA Link.OProf.aM; omega) (by unfold Link.OProf.aBA; omega) (fun acc => acc.claims.a) q A hA
  have hEH := Link.evOW_bound U hbij pr L h64 key domain hs hL accRd hL64 15 280 8052 (by norm_num) (by norm_num)
    (by norm_num) hQm pr.rH pr.nH (pr.hdrLen + 7) (pr.aH + (pr.nH + pr.rH)) pr.aH pr.aBH (by omega)
    (by unfold Link.OProf.aH Link.OProf.aBA Link.OProf.aA Link.OProf.aM; omega) (by unfold Link.OProf.aBH; omega)
    (fun acc => acc.claims.h ++ [P.logupSumClaim]) q A hA
  have hX := Link.extract_fail_block pr.tag L h64 key domain hs hL 280 280 256 15 15 12 q A hA
  have hsem := Link.hsem_geo U pr L hL20 hL64 key domain hs hL accRd rowsOf w16r2Prm 15 280 8052
    (colEncLag (rootFp 14) (2 ^ 14) 280) rfl rfl hnn (by decide) (by norm_num) (by norm_num) hm hPm hPp' hrA hrH hgt
    hgeomL A hcnt hRd csX msX hcsA hcsH hms
  have hexec := Link.hexec_geo U hU hbij pr L hL20 hL64 key domain hs hL accRd rowsOf w16r2Prm 15 280 8052
    (colEncLag (rootFp 14) (2 ^ 14) 280) rfl rfl rfl hnn (by decide) (by norm_num) (by norm_num) hm hQm
    (w16r2_colEnc_spec U) hPm hPp' hrA hrH hgt hgeomL hrows A hcnt hRd
  exact block_knowledge_target_R U hU hK2 key domain hs hL hL64 (by omega) P pr.hdrLen F csX msX hpolyC hEval hdeg 5
    (by norm_num) hgeom hgt hℓs hℓd hℓk
    (fun cu rt => ZK60.Layout.W16Rels S Pb Lay B (xtE cu rt))
    (fun cu rt => ZK60.Layout.W16Lookups S Pb Lay B (xtE cu rt) fams)
    (fun cu rt => ZK60.Block.BlockSat Pb (fun p => (xtE cu rt).X (Lay.dPos p)) (fun p => (xtE cu rt).X2 (Lay.dPos p))
      (ZK60.Layout.toWit Lay (xtE cu rt)))
    (fun cu rt hr hl => ZK60.Layout.blockSat_of_slots Pb Lay B _ fams hF hW h24 hr hl) q A hA
    (fun G => Link.sqN (A.run G).1 = pr.hdrSq)
    (Link.GOW U pr L h64 key domain hs hL accRd 15 280 8052 pr.rA pr.nA pr.hdrLen pr.aA (fun acc => acc.claims.a) A)
    (Link.GOW U pr L h64 key domain hs hL accRd 15 280 8052 pr.rH pr.nH (pr.hdrLen + 7) pr.aH
      (fun acc => acc.claims.h ++ [P.logupSumClaim]) A)
    (Link.GMW U pr L h64 key domain hs hL accRd A)
    (Link.EvOW U hbij pr L h64 key domain hs hL accRd 15 280 8052 hQm pr.rA pr.nA pr.hdrLen (pr.aA + (pr.nA + pr.rA))
      pr.aA pr.aBA (fun acc => acc.claims.a) A)
    (Link.EvOW U hbij pr L h64 key domain hs hL accRd 15 280 8052 hQm pr.rH pr.nH (pr.hdrLen + 7)
      (pr.aH + (pr.nH + pr.rH)) pr.aH pr.aBH (fun acc => acc.claims.h ++ [P.logupSumClaim]) A)
    (Link.EvMW U hbij pr L h64 key domain hs hL accRd A)
    (Link.EvXB pr.tag L h64 key domain hs hL 280 280 256 15 15 12 A) (2 ^ 20) le_rfl 106 111 113 (by norm_num)
    (by norm_num) (by norm_num) _ _ _ _ _ (maskEps_le hF2 hkF pr.hS) (opA_eps_w16r2 gP hp1 hp2 hF2 pr.hwA')
    opB_eps_w16r2 (opA_eps_w16r2 gP hp1 hp2 hF2 pr.hwH') opB_eps_w16r2 hM hEA hEH _ 3 (Link.xfail_T_w16r2 q) le_rfl hX
    hsem hexec εend hEnd 80 (80 * 351) 4 1 (w16r2DR P spR) (w16r2DH P spH) hksR hdgR' (fun i hi => (hfR i hi).1)
    (fun i hi => (hfR i hi).2) hNDR hcR Alk T mlk hN he hksH (fun _ _ _ _ => le_rfl) (fun _ _ => hfH.1)
    (fun _ _ => hfH.2) hNDH (EvHlpOf U key domain hs hL P pr.hdrLen F csX msX A HGd) hcH hsp hbud

end Open

end ZK60.Exec.Block
