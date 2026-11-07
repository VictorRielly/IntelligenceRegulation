/-
D63 lane L23 (2026-11-07), part 3: **`block_knowledge_target_mt` with any number of define schedules** (finding
L23-2), and the W16R2 schedules' slot lists and numbers.

L21's `block_knowledge_target_mt` covers `hRel`'s event by TWO define schedules and the helpers' event by two. At W16R2
two do not suffice (finding L23-2): the claim points of `SC_KMM`, `SC_VMM` and `SC_UMM` start with coordinates drawn by
ANOTHER slot (`SC_QMM`'s `r_q`, `SC_GMM`'s `r_tf`, L11's `claimPoint`), so the Schwartz–Zippel escape over those
coordinates happens at `SC_QMM`'s (`SC_GMM`'s) define step against a later slot's relation; with one polynomial per slot
per schedule, the cover needs one more layer per such relation at the drawing slot. This file:

* **`block_knowledge_target_mtN`**: L21's theorem, same proof, with `nR` relation schedules and `nH` helper schedules,
  the budget `… + nR·(dd + NDd + 2^15) + (nH·(dd + NDd + 2^15) + LogUp) ≤ 2^26`;
* `w16r2RelKs`, `w16r2RelKs_facts`: the W16R2 relation layers' slots: layer 0 the hosts and standalone zero-checks
  (`SC_TZC`, `SC_LZC`, `SC_DZC`, `SC_QZC`, `SC_KVZC`, `SC_SZC`, `SC_FZC`, `SC_TAB`, `SC_ZS`), layer 1 the private
  slots (`SC_SS` … `SC_DMM`), layer 2 `SC_QMM` (for `SC_KMM`'s `r_q`) and `SC_GMM` (for `SC_UMM`'s `r_tf`), layer 3
  `SC_QMM` (for `SC_VMM`'s `r_q`); each list distinct and below `23` (`IO_IN` / `IO_OUT` are the run's boundary, not
  `W16Rels`);
* `w16r2_defND_le`: at the rung any such layer weighs `≤ dd·351` (`rung_defND_le`); `shape_defND_le` for any shape whose
  draws sum to at most `N`;
* **`w16r2_budget_mtN`**: four relation layers and one helper layer at the rung: `30,263,665 ≤ 2^26`;
  `w16r2_budget_any`: at any W16R2 shape with degrees `≤ 7`, `blockND ≤ 2^14` and at most `4096` draws:
  `31,777,127 ≤ 2^26`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.CoverW16Unmask

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal

section Target

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

/-- **One block's knowledge error is at most the approved target, for EVERY `q`, with `nR` relation and `nH` helper
define schedules** (D63 lane L23, finding L23-2; L21's `block_knowledge_target_mt` with `2` replaced by `nR`, `nH`,
same proof). For any block shape: the openings' and `M`'s chain bounds and links as L20's (`hsem` for `OpenTrue`);
`hRel`'s event covered by `nR` define schedules (`hcoverR`), `hLk`'s split (`hsplit`) into the helpers' event covered
by `nH` schedules and a win against LogUp; every schedule with escape counts `≤ dd` and `Σ draws·dg ≤ NDd`; LogUp's
`N + 2M ≤ 35,153,256`; and the budget. Then the block verifier accepts while the extracted planes do not satisfy
`BlockSat` with probability at most `εsTarget q = q·2^-100 + 2^-100`. -/
theorem block_knowledge_target_mtN [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
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
    (Pb : ZK60.Block.BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf) (B : ZK60.Layout.W16Pub S Pb Lay)
    (fams : List (ℕ × ℕ)) (hF : ZK60.Circuit.FamsOK fams) (hW : ZK60.Layout.W16Widths S fams) (h24 : S.h24 = true)
    (xtE : Cuts3 L → RootsO → ZK60.Layout.W16Data Ct Cw Cg Cj Cd Cf)
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
      ∧ ¬ ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)))
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
      ∧ ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      ∧ ¬ ZK60.Layout.W16Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) fams)
      → EvHlp G ∨ LkWin U key domain P hdrLen Alk T mlk (cutsOf key domain hs hL A G).1 G (A.run G))
    -- the budget
    (hbud : 3 * 2 ^ (126 - jM) + 2 * (2 ^ (126 - jA) + 2 ^ (126 - jB)) + 2 ^ 18 + 2 ^ 16 + dmax + blockND P.geom.slots
      + nR * (dd + NDd + 2 ^ 14 + 2 ^ 14) + (nH * (dd + NDd + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14))
      ≤ 2 ^ 26) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X (Lay.dPos p))
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))))
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
    refine (block_knowledge_acc_mt U hU hK2 key domain hs hL hL64 hL81 P hdrLen F csX msX hpolyC hEval hdeg dmax hdp
      hgeom hgt Pb Lay B fams hF hW h24 xtE q A hA _ _ _ hOpen' hRu hLu).trans ?_
    rw [hF2]
    exact block_total_le_target gP hp1 hp2 q hq _ ℓo hℓs hℓo dmax (blockND P.geom.slots) jM jA jB hjM hjA hjB
      maskE εAa εBa εAh εBh hmE hAa hBa hAh hBh T' nr hT' hnr _ _ (nR * (dd + NDd + 2 ^ 14 + 2 ^ 14))
      (nH * (dd + NDd + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14)) le_rfl le_rfl hbud
  · refine le_trans ?_ (one_le_εsTarget (not_lt.mp hq))
    calc _ ≤ (PMF.uniformOfFintype (QB L → Dig)).toOuterMeasure Set.univ :=
          MeasureTheory.measure_mono (Set.subset_univ _)
      _ = 1 := (PMF.toOuterMeasure_apply_eq_one_iff _ Set.univ).mpr (Set.subset_univ _)


end Target

/-! ## The W16R2 relation layers -/

section Lists

/-- **The W16R2 relation layers' slots** (finding L23-2): layer 0 the hosts and standalone zero-checks, layer 1 the
private slots at their own claim points, layer 2 `SC_QMM` (the escape of `SC_KMM`'s `r_q`) and `SC_GMM` (of `SC_UMM`'s
`r_tf`), layer 3 `SC_QMM` (of `SC_VMM`'s `r_q`). -/
def w16r2RelKs : ℕ → List ℕ
  | 0 => [2, 3, 14, 15, 16, 17, 18, 19, 20]
  | 1 => [0, 1, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
  | 2 => [5, 11]
  | 3 => [5]
  | _ => []

/-- Each layer's slots are distinct W16R2 slots. -/
theorem w16r2RelKs_facts : ∀ i, i < 4 → (w16r2RelKs i).Nodup ∧ ∀ k ∈ w16r2RelKs i, k < 23 := by decide

/-- Every slot but the run's boundary slots `IO_IN`, `IO_OUT` (and the hosted slots' extra layers) is in layer 0 or 1. -/
theorem w16r2RelKs_cover : ∀ k, k < 21 → k ∈ w16r2RelKs 0 ∨ k ∈ w16r2RelKs 1 := by decide

/-- **At the W16R2 rung** a layer's draws weigh at most `dd·351`. -/
theorem w16r2_defND_le (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (i : ℕ) (hi : i < 4) (dg : ℕ → ℕ)
    (dd : ℕ) (hdg : ∀ k ∈ w16r2RelKs i, dg k ≤ dd) : defND P (w16r2RelKs i) dg ≤ dd * 351 :=
  rung_defND_le P hdr _ dg dd hdg (w16r2RelKs_facts i hi).1 (w16r2RelKs_facts i hi).2

/-- **At any block shape** whose 23 slots draw at most `N` challenges in all, a layer weighs at most `dd·N`. -/
theorem shape_defND_le (P : BlockParams) (N : ℕ) (hN : ∑ k ∈ Finset.range 23, P.draws k ≤ N) (i : ℕ) (hi : i < 4)
    (dg : ℕ → ℕ) (dd : ℕ) (hdg : ∀ k ∈ w16r2RelKs i, dg k ≤ dd) : defND P (w16r2RelKs i) dg ≤ dd * N :=
  (defND_le P _ dg dd 23 hdg (w16r2RelKs_facts i hi).1 (w16r2RelKs_facts i hi).2).trans (Nat.mul_le_mul_left _ hN)

/-- The rung's slot rounds weighted by degree: `blockND = 924`. -/
theorem rung_blockND : blockND W16R2.rungSlots = 924 := by decide

/-- **W16R2's whole block with four relation layers and one helper layer, at the rung** (`M ≤ 2^-106`,
`opA ≤ 2^-111`, `opB ≤ 2^-113`, `dmax = 5`, `blockND = 924`, escape counts `≤ 80`, `351` draws): `30,263,665 ≤ 2^26`. -/
theorem w16r2_budget_mtN :
    3 * 2 ^ (126 - 106) + 2 * (2 ^ (126 - 111) + 2 ^ (126 - 113)) + 2 ^ 18 + 2 ^ 16 + 5 + 924
      + 4 * (80 + 80 * 351 + 2 ^ 14 + 2 ^ 14) + (1 * (80 + 80 * 351 + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14))
      ≤ 2 ^ 26 := by norm_num

/-- **At any W16R2 shape** with slot degrees `≤ 7`, `blockND ≤ 2^14`, escape counts `≤ 80` and at most `4096` draws, four
relation layers and one helper layer fit: `31,777,127 ≤ 2^26`. -/
theorem w16r2_budget_any (dmax ND : ℕ) (hd : dmax ≤ 7) (hND : ND ≤ 2 ^ 14) :
    3 * 2 ^ (126 - 106) + 2 * (2 ^ (126 - 111) + 2 ^ (126 - 113)) + 2 ^ 18 + 2 ^ 16 + dmax + ND
      + 4 * (80 + 80 * 4096 + 2 ^ 14 + 2 ^ 14) + (1 * (80 + 80 * 4096 + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14))
      ≤ 2 ^ 26 := by
  refine le_trans (Nat.add_le_add_right (Nat.add_le_add_right (Nat.add_le_add (Nat.add_le_add_left hd _) hND) _) _) ?_
  norm_num

end Lists

end ZK60.Exec.Block
