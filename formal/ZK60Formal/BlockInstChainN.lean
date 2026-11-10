/-
D63 lane L31 (2026-11-09), part 7: **the block statements for the evaluation interface with the run's facts**
(finding L31-1).

L16's `SlotEval` cannot be met at a real block: it asks its identity for every `rhoFull` extending the slot's point,
of any length. `SlotEvalN` (`SlotPolyInstEval.lean`) asks it at the sumcheck's own `n + e` canonical challenges, and
`blockSlots_terminalN` is L16's terminal theorem for it. The block theorems above only pass `hEval` down to the
terminal theorem, so each holds for `SlotEvalN` with its proof unchanged. This file re-proves that chain:

* `blockWinT_blockWinN`: `BlockWinT` is L9's `BlockWin` (L16's `blockWinT_blockWin`);
* `block_terminal_knowledge_posN`: the slots' per-position bound (L20's `block_terminal_knowledge_pos`);
* `block_knowledge_acc_RN`, **`block_knowledge_target_RN`**: the block statement on `BlockAcc ∧ R` (L28's);
* **`block_knowledge_open_w16r2N`**, **`block_knowledge_open_r13N`**, **`block_knowledge_open_r13_shieldN`**: L28's
  block statements (and this lane's at the Shieldstral schedule) with `hEval : SlotEvalN`.

Every statement and proof but the first is generated from the existing theorem by replacing `SlotEval` with
`SlotEvalN` and the cited theorem with its twin (results/zk60_lean_l31_20261109/l31_mk_chain.py). Only `propext`,
`Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.SlotPolyInstEval
import ZK60Formal.BlockInstShield

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Circuit (gP GF)
open scoped ENNReal

section ChainN

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The claims' truth discharges the terminal premise, for `SlotEvalN`** (L16's `blockWinT_blockWin`): `BlockWinT`
is L9's `BlockWin`. The slots' acceptance supplies the run's facts `SlotEvalN` asks (`blockSlots_terminalN`). -/
theorem blockWinT_blockWinN (U : K) (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (P : BlockParams) (hdrLen : ℕ) (f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (cs : Cm → ZClaim → K) (ms : List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : SlotEvalN U P cs ms f) (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2)
    (G : QB L → Dig) (out : List Op × Core) (h : BlockWinT U key domain P hdrLen f cs ms G out) :
    BlockWin U key domain L P hdrLen f G out := by
  obtain ⟨bga, rs, acc, ⟨h1, h2, h3, h4, t', hacc⟩, hcl, hm, hfalse⟩ := h
  refine ⟨h1, h2, h3, h4, bga, rs, acc, t', hacc, ?_, hfalse⟩
  exact blockSlots_terminalN U hU _ P _ _ bga rs acc t' hacc h3 h4.1 hgeom cs ms hcl hm hpolyC
    (blockSlots_fin_canon _ P _ _ bga rs acc t' hacc h3 h4 hgeom) f hEval

/-- **The block's slots with the claims' and `M`'s truth, per position, for `SlotEvalN`** (L20's
`block_terminal_knowledge_pos`, its proof unchanged). -/
theorem block_terminal_knowledge_posN [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : ∀ cu rt, SlotEvalN U P (csX cu rt) (msX cu rt) (F cu rt)) (dmax : ℕ) (hdp : dmax < gP)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ dmax
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => BlockWinT U key domain P hdrLen
        (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) G (A.run G))
      ≤ (((q * dmax + blockND P.geom.slots) : ℕ) : ℝ≥0∞) / Fintype.card K
          * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + blockLen P.draws P.geom.slots hdrLen + 1) Dig
        + collBound (q + blockLen P.draws P.geom.slots hdrLen + 1 + 1) Dig := by
  refine le_trans (MeasureTheory.measure_mono ?_)
    (block_sumchecks_fs_knowledge_pos U hU hK2 key domain hs hL hL64 hL81 P hdrLen F dmax hdp hgeom hgt q A hA)
  intro G hG
  rw [Set.mem_ofPred_eq] at hG ⊢
  exact blockWinT_blockWinN U hU key domain P hdrLen _ _ _ hpolyC (hEval _ _) (fun k hk => (hgeom k hk).1) G (A.run G) hG

/-- **The block's knowledge statement on `BlockAcc ∧ R`, for `SlotEvalN`** (L28's `block_knowledge_acc_R`, its proof
unchanged). -/
theorem block_knowledge_acc_RN [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : ∀ cu rt, SlotEvalN U P (csX cu rt) (msX cu rt) (F cu rt))
    (hdeg : ∀ cu rt k sn, IndDegLE (slotShape P k).2.2 (F cu rt k sn)) (dmax : ℕ) (hdp : dmax < gP)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ dmax
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (Rels Lks Sat : Cuts3 L → RootsO → Prop) (hsat : ∀ cu rt, Rels cu rt → Lks cu rt → Sat cu rt)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) (Rg : (QB L → Dig) → Prop)
    (εopen εrel εlk : ℝ≥0∞)
    (hOpen : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc ∧ Rg G
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
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc ∧ Rg G
        ∧ ¬ Sat (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      ≤ εopen + ((((q * dmax + blockND P.geom.slots) : ℕ) : ℝ≥0∞) / Fintype.card K
          * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + blockLen P.draws P.geom.slots hdrLen + 1) Dig
        + collBound (q + blockLen P.draws P.geom.slots hdrLen + 1 + 1) Dig) + εrel + εlk := by
  have hsc := block_terminal_knowledge_posN U hU hK2 key domain hs hL hL64 hL81 P hdrLen F csX msX hpolyC hEval dmax
    hdp hgeom hgt q A hA
  refine le_trans (MeasureTheory.measure_mono ?_)
    ((MeasureTheory.measure_union_le _ _).trans (add_le_add
      ((MeasureTheory.measure_union_le _ _).trans (add_le_add
        ((MeasureTheory.measure_union_le _ _).trans (add_le_add hOpen hsc)) hRel)) hLk))
  intro G hG
  rw [Set.mem_ofPred_eq] at hG
  obtain ⟨bga, rs, acc, hacc, hR, hns⟩ := hG
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
  · exact Or.inl (Or.inl (Or.inl ⟨bga, rs, acc, hacc, hR, ho⟩))

/-- **One block's knowledge error on `BlockAcc ∧ R` is at most the approved target plus the endpoint term, for
`SlotEvalN`** (L28's `block_knowledge_target_R`, its proof unchanged). -/
theorem block_knowledge_target_RN [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : ∀ cu rt, SlotEvalN U P (csX cu rt) (msX cu rt) (F cu rt))
    (hdeg : ∀ cu rt k sn, IndDegLE (slotShape P k).2.2 (F cu rt k sn)) (dmax : ℕ) (hd7 : dmax ≤ 7)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ dmax
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (hℓs : blockLen P.draws P.geom.slots hdrLen ≤ 2 ^ 20) (hℓd : defLen P hdrLen ≤ 2 ^ 20)
    (hℓk : hdrLen + 10 ≤ 2 ^ 20)
    (Rels Lks Sat : Cuts3 L → RootsO → Prop) (hsat : ∀ cu rt, Rels cu rt → Lks cu rt → Sat cu rt)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) (Rg : (QB L → Dig) → Prop)
    -- the openings: their good predicates, chain events and per-position bounds (L20), links on `BlockAcc ∧ R`
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
    (hsem : ∀ G, (∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc ∧ Rg G
        ∧ ¬ OpenBlk U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
          (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc) → ¬ (GA G ∧ GH G ∧ GM G))
    (hexec : ∀ G, (∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc) → Rg G → ¬ EvX G →
      (GA G ∨ EvA G) ∧ (GH G ∨ EvH G) ∧ (GM G ∨ EvM G))
    -- the endpoint claims (L22-5), a run-level term
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc ∧ Rg G
      ∧ ¬ EndTrue U (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc) ≤ εend)
    -- L13's relations: define schedules
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
    -- LogUp, with the helpers' relations by define schedules
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
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc ∧ Rg G
        ∧ ¬ Sat (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      ≤ εsTarget q + εend := by
  by_cases hq : q < 2 ^ 100
  · have hF2 : Fintype.card K = gP ^ 2 :=
      card_of_pairs gP (Equiv.ofBijective _ (ZK60.Hiding.fp2_bijective hK2 hU seven_not_square))
    have hdp : dmax < gP := lt_of_le_of_lt hd7 (by norm_num [gP])
    have hp1 : gP ≤ 2 ^ 64 := by norm_num [gP]
    have hp2 : 2 ^ 64 - 2 ^ 32 ≤ gP := by norm_num [gP]
    have hgeomD : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2
        ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L :=
      fun k hk => ⟨(hgeom k hk).1, (hgeom k hk).2.2.1, (hgeom k hk).2.2.2⟩
    have hR := rel_of_defines_pos U hU hK2 key domain hs hL hL64 hL81 P hdrLen hgeomD hgt nR DR dd NDd hksR hdgR hdegR
      hΦR hNDR q A hA _ hcoverR
    rw [hF2] at hR
    have hRu := hR.trans ((mul_le_mul' le_rfl
      (sched_pos_le_u126 gP hp1 hp2 q hq (defLen P hdrLen) hℓd dd NDd)).trans_eq (nsmul_u126 q nR _))
    have hH := rel_of_defines_pos U hU hK2 key domain hs hL hL64 hL81 P hdrLen hgeomD hgt nH DH dd NDd hksH hdgH hdegH
      hΦH hNDH q A hA EvHlp hcoverH
    rw [hF2] at hH
    have hHu := hH.trans ((mul_le_mul' le_rfl
      (sched_pos_le_u126 gP hp1 hp2 q hq (defLen P hdrLen) hℓd dd NDd)).trans_eq (nsmul_u126 q nH _))
    have hLk := lk_of_logup_pos U hU hK2 key domain hs hL hL64 hL81 P hdrLen Alk T mlk hN q A hA _ EvHlp _ hHu hsplit
    rw [hF2] at hLk
    have hLu := hLk.trans ((add_le_add le_rfl
      (lk_pos_le_u126 gP hp1 hp2 q hq (hdrLen + 10) hℓk _ he)).trans_eq (u126_add _ _ _))
    -- the openings' term, on `BlockAcc ∧ R`, with the endpoint term
    have hOpen := block_open_R U key domain hs hL P hdrLen csX msX A Rg GA GH GM EvA EvH EvM EvX _ _ _ _ εend hsem hexec
      hM hEA hEH hX hEnd
    refine (block_knowledge_acc_RN U hU hK2 key domain hs hL hL64 hL81 P hdrLen F csX msX hpolyC hEval hdeg dmax hdp
      hgeom hgt Rels Lks Sat hsat q A hA Rg _ _ _ hOpen hRu hLu).trans ?_
    rw [hF2]
    have htot := block_total_le_target gP hp1 hp2 q hq _ ℓo hℓs hℓo dmax (blockND P.geom.slots) jM jA jB hjM hjA hjB
      maskE εAa εBa εAh εBh hmE hAa hBa hAh hBh T' nr hT' hnr _ _ (nR * (dd + NDd + 2 ^ 14 + 2 ^ 14))
      (nH * (dd + NDd + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14)) le_rfl le_rfl hbud
    refine le_trans (le_of_eq ?_) (add_le_add htot (le_refl εend))
    ring
  · refine le_trans ?_ (le_trans (one_le_εsTarget (not_lt.mp hq)) le_self_add)
    calc _ ≤ (PMF.uniformOfFintype (QB L → Dig)).toOuterMeasure Set.univ :=
          MeasureTheory.measure_mono (Set.subset_univ _)
      _ = 1 := (PMF.toOuterMeasure_apply_eq_one_iff _ Set.univ).mpr (Set.subset_univ _)

end ChainN

section OpenN

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

/-- **L28's `block_knowledge_open_w16r2` with `hEval : SlotEvalN`** (its proof unchanged). -/
theorem block_knowledge_open_w16r2N [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (hdr : P.draws = W16R2.rungDraws) (hsl : P.geom.slots = W16R2.rungSlots) (htm : P.geom.terms = W16R2.rungTerms)
    (pr : Link.OProf P) (hh : pr.hdrLen ≤ 2 ^ 19)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : ∀ cu rt, SlotEvalN U P (csX cu rt) (msX cu rt) (F cu rt))
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
  exact block_knowledge_target_RN U hU hK2 key domain hs hL hL64 (by omega) P pr.hdrLen F csX msX hpolyC hEval hdeg 5
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

/-- **L28's `block_knowledge_open_r13` with `hEval : SlotEvalN`** (its proof unchanged). -/
theorem block_knowledge_open_r13N [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (hdr : P.draws = R13.rungDraws) (hsl : P.geom.slots = R13.rungSlots) (htm : P.geom.terms = R13.rungTerms)
    (pr : Link.OProf P) (hh : pr.hdrLen ≤ 2 ^ 19)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : ∀ cu rt, SlotEvalN U P (csX cu rt) (msX cu rt) (F cu rt))
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
  exact block_knowledge_target_RN U hU hK2 key domain hs hL hL64 (by omega) P pr.hdrLen F csX msX hpolyC hEval hdeg 5
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

/-- **`block_knowledge_open_r13_shield` with `hEval : SlotEvalN`** (its proof unchanged). -/
theorem block_knowledge_open_r13_shieldN [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (hdr : P.draws = R13.shieldDraws) (hsl : P.geom.slots = R13.shieldSlots) (htm : P.geom.terms = R13.shieldTerms)
    (pr : Link.OProf P) (hh : pr.hdrLen ≤ 2 ^ 19)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : ∀ cu rt, SlotEvalN U P (csX cu rt) (msX cu rt) (F cu rt))
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
  exact block_knowledge_target_RN U hU hK2 key domain hs hL hL64 (by omega) P pr.hdrLen F csX msX hpolyC hEval hdeg 5
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

end OpenN

end ZK60.Exec.Block
