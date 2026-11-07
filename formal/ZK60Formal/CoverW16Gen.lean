/-
D63 lane L23 (2026-11-07), part 9: **the block's knowledge statement for ANY relation and lookup predicates** (so for
R13 as for W16R2), and the covers in that form.

L21's `block_knowledge_acc_mt` and `block_knowledge_target_mt` (and `block_knowledge_target_mtN`, `CoverW16Target.lean`)
are stated with W16R2's `W16Rels` / `W16Lookups` and close the case split with L11's `blockSat_of_slots`. R13 has its
own relations (`R13Rels`: W16R2's plus the byte decompositions) and lookups (one byte table), and L17's
`blockSat_of_slots_r13` closes them. Here the same theorems, same proofs, for any predicates `Rels`, `Lks` of the
extracted data and any conclusion `Sat` with `Rels ∧ Lks → Sat`:

* **`block_knowledge_acc_gen`**, **`block_knowledge_target_gen`**: L21's `_acc_mt` and L23's `_target_mtN` with
  `Rels`, `Lks`, `Sat`;
* `hcoverR_gen`, `hsplit_gen`: `CoverW16.lean`'s `hcoverR_layers` and `hsplit_two` for the goal `Rels` and the lookups
  `Lks` (the bridge `hbr` may use `Rels`, which `hLk`'s event carries).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.CoverW16Target

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal

section Gen

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **One block's knowledge statement on acceptance, `OpenTrue` form, for any relation and lookup predicates**
(L21's `block_knowledge_acc_mt` with `Rels`, `Lks` and `Sat`, `Rels ∧ Lks → Sat`; same proof). -/
theorem block_knowledge_acc_gen [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : ∀ cu rt, SlotEval U P (csX cu rt) (msX cu rt) (F cu rt))
    (hdeg : ∀ cu rt k sn, IndDegLE (slotShape P k).2.2 (F cu rt k sn)) (dmax : ℕ) (hdp : dmax < gP)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ dmax
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (Rels Lks Sat : Cuts3 L → RootsO → Prop) (hsat : ∀ cu rt, Rels cu rt → Lks cu rt → Sat cu rt)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) (εopen εrel εlk : ℝ≥0∞)
    (hOpen : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ ¬ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc) ≤ εopen)
    (hRel : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc
      ∧ (∀ k r, rs[k]? = some r → r.claimed.toK U
          = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k)))
      ∧ ¬ Rels (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) ≤ εrel)
    (hLk : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc
      ∧ (∀ k r, rs[k]? = some r → r.claimed.toK U
          = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k)))
      ∧ Rels (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)
      ∧ ¬ Lks (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) ≤ εlk) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ ¬ Sat (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      ≤ εopen + ((((q * dmax + blockND P.geom.slots) : ℕ) : ℝ≥0∞) / Fintype.card K
          * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + blockLen P.draws P.geom.slots hdrLen + 1) Dig
        + collBound (q + blockLen P.draws P.geom.slots hdrLen + 1 + 1) Dig) + εrel + εlk := by
  have hsc := block_terminal_knowledge_pos U hU hK2 key domain hs hL hL64 hL81 P hdrLen F csX msX hpolyC hEval dmax
    hdp hgeom hgt q A hA
  refine le_trans (MeasureTheory.measure_mono ?_)
    ((MeasureTheory.measure_union_le _ _).trans (add_le_add
      ((MeasureTheory.measure_union_le _ _).trans (add_le_add
        ((MeasureTheory.measure_union_le _ _).trans (add_le_add hOpen hsc)) hRel)) hLk))
  intro G hG
  rw [Set.mem_ofPred_eq] at hG
  obtain ⟨bga, rs, acc, hacc, hns⟩ := hG
  by_cases ho : OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc
  · by_cases hcl : ∀ k r, rs[k]? = some r → r.claimed.toK U
        = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k))
    · by_cases hrel : Rels (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)
      · by_cases hlk : Lks (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)
        · exact absurd (hsat _ _ hrel hlk) hns
        · exact Or.inr ⟨bga, rs, acc, hacc, ho, hcl, hrel, hlk⟩
      · exact Or.inl (Or.inr ⟨bga, rs, acc, hacc, ho, hcl, hrel⟩)
    · push Not at hcl
      obtain ⟨k, r, hr, hne⟩ := hcl
      exact Or.inl (Or.inl (Or.inr ⟨bga, rs, acc, hacc.1, ho.1, ho.mfs, k, r, hr, hdeg _ _ _ _, hne⟩))
  · exact Or.inl (Or.inl (Or.inl ⟨bga, rs, acc, hacc, ho⟩))

/-- **One block's knowledge error is at most the approved target, for EVERY `q`, for any relation and lookup
predicates** (`block_knowledge_target_mtN` with `Rels`, `Lks`, `Sat`; same proof). -/
theorem block_knowledge_target_gen [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : ∀ cu rt, SlotEval U P (csX cu rt) (msX cu rt) (F cu rt))
    (hdeg : ∀ cu rt k sn, IndDegLE (slotShape P k).2.2 (F cu rt k sn)) (dmax : ℕ) (hd7 : dmax ≤ 7)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ dmax
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (hℓs : blockLen P.draws P.geom.slots hdrLen ≤ 2 ^ 20) (hℓd : defLen P hdrLen ≤ 2 ^ 20)
    (hℓk : hdrLen + 10 ≤ 2 ^ 20)
    (Rels Lks Sat : Cuts3 L → RootsO → Prop) (hsat : ∀ cu rt, Rels cu rt → Lks cu rt → Sat cu rt)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    -- the openings: their good predicates, chain events and per-position bounds (L20)
    (GA GH GM EvA EvH EvM EvX : (QB L → Dig) → Prop) (ℓo : ℕ) (hℓo : ℓo ≤ 2 ^ 20)
    (jM jA jB : ℕ) (hjM : jM ≤ 126) (hjA : jA ≤ 126) (hjB : jB ≤ 126)
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
    -- L13's relations: two define schedules
    (dd NDd nR nH : ℕ) (DR DH : ℕ → DefSched K L P)
    (hksR : ∀ i, i < nR → ∀ k ∈ (DR i).ks, k < P.geom.slots.length)
    (hdgR : ∀ i, i < nR → ∀ k ∈ (DR i).ks, (DR i).dg k ≤ dd)
    (hdegR : ∀ i, i < nR → ∀ k ∈ (DR i).ks, ∀ cu rt h, IndDegLE ((DR i).dg k) ((DR i).Φ cu rt k h))
    (hΦR : ∀ i, i < nR → ∀ cu rt k h, k ∈ (DR i).ks → (∀ x, (DR i).Φ cu rt k h x = 0) → (DR i).Gd cu rt k h)
    (hNDR : ∀ i, i < nR → defND P (DR i).ks (DR i).dg ≤ NDd)
    (hcoverR : ∀ G, (∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc
      ∧ (∀ k r, rs[k]? = some r → r.claimed.toK U
          = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k)))
      ∧ ¬ Rels (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      → ∃ i, i < nR ∧ DefWin U key domain P hdrLen (DR i).ks (DR i).Gd (DR i).Φ
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) G (A.run G))
    -- LogUp, with the helpers' relations by two define schedules
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 35153256)
    (hksH : ∀ i, i < nH → ∀ k ∈ (DH i).ks, k < P.geom.slots.length)
    (hdgH : ∀ i, i < nH → ∀ k ∈ (DH i).ks, (DH i).dg k ≤ dd)
    (hdegH : ∀ i, i < nH → ∀ k ∈ (DH i).ks, ∀ cu rt h, IndDegLE ((DH i).dg k) ((DH i).Φ cu rt k h))
    (hΦH : ∀ i, i < nH → ∀ cu rt k h, k ∈ (DH i).ks → (∀ x, (DH i).Φ cu rt k h x = 0) → (DH i).Gd cu rt k h)
    (hNDH : ∀ i, i < nH → defND P (DH i).ks (DH i).dg ≤ NDd)
    (EvHlp : (QB L → Dig) → Prop)
    (hcoverH : ∀ G, EvHlp G → ∃ i, i < nH ∧ DefWin U key domain P hdrLen (DH i).ks (DH i).Gd (DH i).Φ
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) G (A.run G))
    (hsplit : ∀ G, (∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc
      ∧ (∀ k r, rs[k]? = some r → r.claimed.toK U
          = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k)))
      ∧ Rels (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)
      ∧ ¬ Lks (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      → EvHlp G ∨ LkWin U key domain P hdrLen Alk T mlk (cutsOf key domain hs hL A G).1 G (A.run G))
    -- the budget
    (hbud : 3 * 2 ^ (126 - jM) + 2 * (2 ^ (126 - jA) + 2 ^ (126 - jB)) + 2 ^ 18 + 2 ^ 16 + dmax + blockND P.geom.slots
      + nR * (dd + NDd + 2 ^ 14 + 2 ^ 14) + (nH * (dd + NDd + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14))
      ≤ 2 ^ 26) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ ¬ Sat (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      ≤ εsTarget q := by
  by_cases hq : q < 2 ^ 100
  · have hF2 : Fintype.card K = gP ^ 2 :=
      card_of_pairs gP (Equiv.ofBijective _ (ZK60.Hiding.fp2_bijective hK2 hU seven_not_square))
    have hdp : dmax < gP := lt_of_le_of_lt hd7 (by norm_num [gP])
    have hp1 : gP ≤ 2 ^ 64 := by norm_num [gP]
    have hp2 : 2 ^ 64 - 2 ^ 32 ≤ gP := by norm_num [gP]
    have hgeomD : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2
        ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L :=
      fun k hk => ⟨(hgeom k hk).1, (hgeom k hk).2.2.1, (hgeom k hk).2.2.2⟩
    -- `hRel`: two define schedules, per position
    have hR := rel_of_defines_pos U hU hK2 key domain hs hL hL64 hL81 P hdrLen hgeomD hgt nR DR dd NDd hksR hdgR hdegR
      hΦR hNDR q A hA _ hcoverR
    rw [hF2] at hR
    have hRu := hR.trans ((mul_le_mul' le_rfl
      (sched_pos_le_u126 gP hp1 hp2 q hq (defLen P hdrLen) hℓd dd NDd)).trans_eq (nsmul_u126 q nR _))
    -- the helpers: two define schedules, per position
    have hH := rel_of_defines_pos U hU hK2 key domain hs hL hL64 hL81 P hdrLen hgeomD hgt nH DH dd NDd hksH hdgH hdegH
      hΦH hNDH q A hA EvHlp hcoverH
    rw [hF2] at hH
    have hHu := hH.trans ((mul_le_mul' le_rfl
      (sched_pos_le_u126 gP hp1 hp2 q hq (defLen P hdrLen) hℓd dd NDd)).trans_eq (nsmul_u126 q nH _))
    -- `hLk`: LogUp, per position
    have hLk := lk_of_logup_pos U hU hK2 key domain hs hL hL64 hL81 P hdrLen Alk T mlk hN q A hA _ EvHlp _ hHu hsplit
    rw [hF2] at hLk
    have hLu := hLk.trans ((add_le_add le_rfl
      (lk_pos_le_u126 gP hp1 hp2 q hq (hdrLen + 10) hℓk _ he)).trans_eq (u126_add _ _ _))
    -- the openings' term
    have hOpen := block_open_knowledge
      (fun G => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc)
      (fun G => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ ¬ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
          (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc)
      GA GH GM EvA EvH EvM EvX _ _ _ _
      (fun G _ ha hh hm hb => hsem G hb ⟨ha, hh, hm⟩) hexec hM hEA hEH hX
    have hOpen' : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ ¬ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
          (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc)
        ≤ ((q : ℝ≥0∞) * maskE + 3 * maskE + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig)
          + (((q : ℝ≥0∞) * εAa + εAa + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig)
            + ((q : ℝ≥0∞) * εBa + εBa + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig))
          + (((q : ℝ≥0∞) * εAh + εAh + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig)
            + ((q : ℝ≥0∞) * εBh + εBh + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig))
          + (collBound T' Dig + ((2 * T' * T' + (1 + nr) * T' : ℕ) : ℝ≥0∞) / Fintype.card Dig) := by
      refine le_trans (MeasureTheory.measure_mono ?_) hOpen
      intro G hG
      rw [Set.mem_ofPred_eq] at hG ⊢
      obtain ⟨bga, rs, acc, hacc, hbad⟩ := hG
      exact ⟨⟨bga, rs, acc, hacc⟩, ⟨bga, rs, acc, hacc, hbad⟩⟩
    refine (block_knowledge_acc_gen U hU hK2 key domain hs hL hL64 hL81 P hdrLen F csX msX hpolyC hEval hdeg dmax hdp
      hgeom hgt Rels Lks Sat hsat q A hA _ _ _ hOpen' hRu hLu).trans ?_
    rw [hF2]
    exact block_total_le_target gP hp1 hp2 q hq _ ℓo hℓs hℓo dmax (blockND P.geom.slots) jM jA jB hjM hjA hjB
      maskE εAa εBa εAh εBh hmE hAa hBa hAh hBh T' nr hT' hnr _ _ (nR * (dd + NDd + 2 ^ 14 + 2 ^ 14))
      (nH * (dd + NDd + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14)) le_rfl le_rfl hbud
  · refine le_trans ?_ (one_le_εsTarget (not_lt.mp hq))
    calc _ ≤ (PMF.uniformOfFintype (QB L → Dig)).toOuterMeasure Set.univ :=
          MeasureTheory.measure_mono (Set.subset_univ _)
      _ = 1 := (PMF.toOuterMeasure_apply_eq_one_iff _ Set.univ).mpr (Set.subset_univ _)


/-- **`hcoverR` for any relation predicate**, from per-outcome facts for `n` layered schedules. -/
theorem hcoverR_gen (U : K) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (Rels : Cuts3 L → RootsO → Prop) (A : OC (QB L) Dig (List Op × Core)) (n : ℕ) (DR : ℕ → DefSched K L P)
    (hv : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc → ∀ i, i < n →
      (∀ j, j < i → SchedGd (DR j) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      SchedVan U P (DR i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs)
    (hgd : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc →
      (∀ i, i < n → SchedGd (DR i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      Rels (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) :
    ∀ G, (∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc
      ∧ (∀ k r, rs[k]? = some r → r.claimed.toK U
          = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k)))
      ∧ ¬ Rels (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      → ∃ i, i < n ∧ DefWin U key domain P hdrLen (DR i).ks (DR i).Gd (DR i).Φ
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) G (A.run G) := by
  intro G hG
  obtain ⟨bga, rs, acc, hacc, ho, hcl, hng⟩ := hG
  have hT : AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc := ⟨hacc, ho, hcl⟩
  exact cover_layers U key domain P hdrLen n DR _ _ G (A.run G) bga rs acc _ hacc.1 (hv G bga rs acc hT)
    (hgd G bga rs acc hT) hng

/-- **`hsplit` for any relation and lookup predicates**: the bridge may use the relations, which `hLk`'s event
carries. -/
theorem hsplit_gen {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ] (U : K) (key : Option Dig)
    (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)
    (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (Rels Lks : Cuts3 L → RootsO → Prop)
    (A : OC (QB L) Dig (List Op × Core)) (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hbr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc →
      Rels (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) →
      ¬ Lks (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) →
      ∃ l, ∀ j, T j ≠ Alk (cutsOf key domain hs hL A G).1 l)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U) Hh) :
    ∀ G, (∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc
      ∧ (∀ k r, rs[k]? = some r → r.claimed.toK U
          = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k)))
      ∧ Rels (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)
      ∧ ¬ Lks (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      → EvHlpOf U key domain hs hL P hdrLen F csX msX A HGd G
        ∨ LkWin U key domain P hdrLen Alk T mlk (cutsOf key domain hs hL A G).1 G (A.run G) := by
  intro G hG
  obtain ⟨bga, rs, acc, hacc, ho, hcl, hrel, hnl⟩ := hG
  have hT : AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc := ⟨hacc, ho, hcl⟩
  by_cases hh : HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga
  · exact Or.inr ⟨bga, rs, acc, hacc.1, hbr G bga rs acc hT hrel hnl, hhr G bga rs acc hT hh⟩
  · exact Or.inl ⟨bga, rs, acc, hT, hh⟩

end Gen

end ZK60.Exec.Block
