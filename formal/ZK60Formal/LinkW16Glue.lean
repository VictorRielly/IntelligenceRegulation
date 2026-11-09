/-
D63 lane L28 (2026-11-07), part 3: **the block's knowledge statement with the openings' term split as the real run
needs it** (L22-1, L22-5).

L21's `block_knowledge_target_mt` (and L23's `_mtN`, `_gen`) bound `Pr[BlockAcc ∧ ¬Sat]` given, among others, the
openings' links `hsem` (the openings' good predicates give `OpenTrue`) and `hexec` (on EVERY accepting run). Two facts
of the real run stop those two premises from being proved as stated:

* **L22-5 (the endpoint claims)**: `OpenTrue` contains the truth of `acc.claims.inp` and `acc.claims.out`, which the
  block verifier does not open (the run's boundary and endpoint openings do). So `hsem` can only give the block's own
  part, `OpenBlk` (`A`'s and `H`'s claims, `H`'s LogUp sum claim, every `M` functional), and the endpoint part is a
  run-level premise `hEnd : Pr[BlockAcc ∧ R ∧ ¬EndTrue] ≤ εend`.
* **L22-1 (the header's squeeze count)**: the openings' step parse is fixed only when the header's squeeze count is the
  profile's. The coordinator's decision: state the result on `BlockAcc ∧ R`, `R` the run's restriction (the verifier
  fixes the header), which narrows no approved statement. Here `R` is any predicate of the oracle; `hexec` is needed
  only on `BlockAcc ∧ R`.

Both are carried by restricting the EVENT, so no prover wrapper is needed (the wrapper of L22-1 is the same thing:
`BlockAcc` of the wrapped prover is `BlockAcc ∧ R` of the original). The case split of L21 / L23 is re-done on the
restricted event; every bound it composes is the existing one, cited:

* `EndTrue`, `OpenBlk`, `openTrue_of`: the endpoint claims' truth, the block's own part, and `OpenTrue` from the two;
* **`block_knowledge_acc_R`**: L23's `block_knowledge_acc_gen` on `BlockAcc ∧ R` (`hOpen` on `BlockAcc ∧ R` only;
  the slots' term `block_terminal_knowledge_pos`, and `hRel`, `hLk` as before);
* **`block_open_R`**: L20's `block_open_knowledge` with `Acc := BlockAcc ∧ R`, `Bad := ¬OpenBlk`, plus the endpoint
  term: `Pr[BlockAcc ∧ R ∧ ¬OpenTrue] ≤ εM + εA + εH + εX + εend`;
* **`block_knowledge_target_R`**: L23's `block_knowledge_target_gen` on `BlockAcc ∧ R`, with `hsem` for `OpenBlk`,
  `hexec` on `BlockAcc ∧ R` and the endpoint premise: `Pr[BlockAcc ∧ R ∧ ¬Sat] ≤ εsTarget q + εend`, for EVERY `q`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.CoverW16Gen

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal

section Split

variable {K : Type} [Field K] [Algebra GF K]

/-- **The endpoint claims true of some data** (`acc.claims.inp`, `acc.claims.out`: opened by the run, L16-5). -/
def EndTrue (U : K) (cs : Cm → ZClaim → K) (acc : Acc) : Prop :=
  (∀ c ∈ acc.claims.inp, cs .inp c = c.value.toK U) ∧ ∀ c ∈ acc.claims.out, cs .out c = c.value.toK U

/-- **What the block's own openings and `M` check**: `A`'s and `H`'s claims, `H`'s LogUp sum claim, every functional `M`
receives (the hosts' included). -/
def OpenBlk (U : K) (P : BlockParams) (cs : Cm → ZClaim → K) (ms : List (ℕ × List Fp2) → K) (acc : Acc) : Prop :=
  (∀ c ∈ acc.claims.a, cs .a c = c.value.toK U) ∧ (∀ c ∈ acc.claims.h, cs .h c = c.value.toK U)
    ∧ MTrue U ms (acc.fs ++ acc.hostFs) ∧ cs .h P.logupSumClaim = P.logupSumClaim.value.toK U

/-- `OpenTrue` is the block's part and the endpoint part. -/
theorem openTrue_of {U : K} {P : BlockParams} {cs : Cm → ZClaim → K} {ms : List (ℕ × List Fp2) → K} {acc : Acc}
    (hb : OpenBlk U P cs ms acc) (he : EndTrue U cs acc) : OpenTrue U P cs ms acc := by
  refine ⟨fun cm c hc => ?_, hb.2.2.1, hb.2.2.2⟩
  cases cm with
  | a => exact hb.1 c hc
  | h => exact hb.2.1 c hc
  | inp => exact he.1 c hc
  | out => exact he.2 c hc

end Split

section Acc

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The block's knowledge statement on `BlockAcc ∧ R`** (L23's `block_knowledge_acc_gen`, its case split on the
restricted event: the openings' event is needed only there). -/
theorem block_knowledge_acc_R [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
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
  have hsc := block_terminal_knowledge_pos U hU hK2 key domain hs hL hL64 hL81 P hdrLen F csX msX hpolyC hEval dmax
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

end Acc

section Open

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The openings' term on `BlockAcc ∧ R`, with the endpoint claims split off** (L22-5): L20's
`block_open_knowledge` with `Acc := BlockAcc ∧ R` and the block's own part `OpenBlk`, plus the run-level endpoint term.
-/
theorem block_open_R (U : K) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (A : OC (QB L) Dig (List Op × Core)) (Rg : (QB L → Dig) → Prop)
    (GA GH GM EvA EvH EvM EvX : (QB L → Dig) → Prop) (εM εA εH εX εend : ℝ≥0∞)
    (hsem : ∀ G, (∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc ∧ Rg G
        ∧ ¬ OpenBlk U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
          (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc) → ¬ (GA G ∧ GH G ∧ GM G))
    (hexec : ∀ G, (∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc) → Rg G → ¬ EvX G →
      (GA G ∨ EvA G) ∧ (GH G ∨ EvH G) ∧ (GM G ∨ EvM G))
    (hM : prH EvM ≤ εM) (hEA : prH EvA ≤ εA) (hEH : prH EvH ≤ εH) (hX : prH EvX ≤ εX)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc ∧ Rg G
      ∧ ¬ EndTrue U (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc) ≤ εend) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc ∧ Rg G
      ∧ ¬ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc) ≤ (εM + εA + εH + εX) + εend := by
  have hO := block_open_knowledge
    (fun G => (∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc) ∧ Rg G)
    (fun G => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc ∧ Rg G
      ∧ ¬ OpenBlk U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc)
    GA GH GM EvA EvH EvM EvX εM εA εH εX
    (fun G _ ha hh hm hb => hsem G hb ⟨ha, hh, hm⟩) (fun G hacc hx => hexec G hacc.1 hacc.2 hx) hM hEA hEH hX
  refine le_trans (MeasureTheory.measure_mono ?_) ((MeasureTheory.measure_union_le _ _).trans (add_le_add hO hEnd))
  intro G hG
  rw [Set.mem_ofPred_eq] at hG
  obtain ⟨bga, rs, acc, hacc, hR, ho⟩ := hG
  by_cases hb : OpenBlk U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc
  · by_cases he : EndTrue U (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc
    · exact absurd (openTrue_of hb he) ho
    · exact Or.inr ⟨bga, rs, acc, hacc, hR, he⟩
  · exact Or.inl ⟨⟨⟨bga, rs, acc, hacc⟩, hR⟩, ⟨bga, rs, acc, hacc, hR, hb⟩⟩

end Open

section Target

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **One block's knowledge error on `BlockAcc ∧ R` is at most the approved target plus the endpoint term, for EVERY
`q`** (L23's `block_knowledge_target_gen` with the openings' links as the real run gives them: `hsem` for the block's
own part `OpenBlk`, `hexec` on `BlockAcc ∧ R`, the endpoint claims' run-level term `εend`). -/
theorem block_knowledge_target_R [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
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
    refine (block_knowledge_acc_R U hU hK2 key domain hs hL hL64 hL81 P hdrLen F csX msX hpolyC hEval hdeg dmax hdp
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

end Target

end ZK60.Exec.Block
