/-
D63 lane L20 (2026-11-07), part 5: **one block's knowledge statement on the block verifier's acceptance, with the
openings' term composed and the per-position count, against the approved target**.

L16's `block_knowledge` (`ExtractW16Block.lean`) bounds the event "the SLOTS accept and the extracted planes fail
`BlockSat`" by `εopen + εsc + εrel + εlk`, with `hOpen` a named hypothesis on the same slots-only event. That
hypothesis cannot be proved as stated: a prover can make the slots accept with claims that are false of the committed
data and simply fail the openings (finding L20-1). The knowledge statement the receipt needs is about the block
verifier's ACCEPTANCE (the slots, `M` and both openings), and there `εopen` is a theorem of the openings:

* `BlockAcc`: the slots accept (`SlotsAcc`) and `blockVerify` accepts on the same transcript;
* **`block_knowledge_acc`**: `block_knowledge` on `BlockAcc`, with the per-position slots' term
  (`block_terminal_knowledge_pos`), and `hOpen`, `hRel`, `hLk` needed only on `BlockAcc` (weaker hypotheses);
* **`block_open_knowledge`**: `hOpen` on `BlockAcc` from the openings: if (`hsem`) the claims and `M` functionals are
  true of the extracted data whenever the extracted `A`, `H` matrices and `M` rows satisfy their openings' good
  predicates (`GroupsGood`, `MGood`), and (`hexec`) an accepting block whose opened columns are the extracted ones has
  each opening's good predicate or its chain event, then `εopen ≤ εM + εA + εH + εX`, where `εM`, `εA`, `εH` are the
  chain bounds (`mask_knowledge_chain_pos`, `opening_knowledge_chain_pos` for `A` and for `H`) and `εX` the extraction
  failure (`extract_fail_run`);
* **`block_knowledge_target`**: everything together, for every `q`: the block's knowledge error is at most
  `εsTarget q = q·2^-100 + 2^-100`, given the openings' and `M`'s chain bounds at their proved parameters
  (`maskEps ≤ 2^-106`, `opA ≤ 2^-111`, `opB ≤ 2^-113`), the extraction failure, and L13's / LogUp's budgets.

Every theorem is per block shape (`BlockParams`, `W16Layout`, `W16Pub`, range families: A25). Only `propext`,
`Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.CountW16Target
import ZK60Formal.OpenKnowChain

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal

section Acc

variable {L : ℕ}

/-- **The block verifier accepts**: the slots accept a canonical core of the verifier's shape after a header of
`hdrLen` operations (`SlotsAcc`, with the slot loop's result `(bga, rs, acc)`), and `blockVerify` (the functional
count, `M`, `check_opening`, the `A` and `H` openings) accepts on the same transcript. -/
def BlockAcc (key : Option Dig) (domain : List UInt8) (P : BlockParams) (hdrLen : ℕ) (G : QB L → Dig)
    (out : List Op × Core) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc) : Prop :=
  SlotsAcc key domain P hdrLen G out bga rs acc
    ∧ ∃ io t', blockVerify (liftH G) P out.2 (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) out.1) = .ok (io, t')

end Acc

section Block

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

/-- **One block's knowledge statement on the block verifier's acceptance** (D63 lane L20; L16's `block_knowledge`
with the per-position slots' term, on `BlockAcc`). For any block shape: the probability that the block verifier
accepts while the extracted planes do NOT satisfy `BlockSat` at the logical positions is at most
`εopen + εsc + εrel + εlk`, `εsc = (q·dmax + blockND)/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`
(proved, per position), `εopen`, `εrel`, `εlk` bounding the named events on `BlockAcc`. -/
theorem block_knowledge_acc [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
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
    (Pb : ZK60.Block.BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf) (B : ZK60.Layout.W16Pub S Pb Lay)
    (fams : List (ℕ × ℕ)) (hF : ZK60.Circuit.FamsOK fams) (hW : ZK60.Layout.W16Widths S fams) (h24 : S.h24 = true)
    (xtE : Cuts3 L → RootsO → ZK60.Layout.W16Data Ct Cw Cg Cj Cd Cf)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) (εopen εrel εlk : ℝ≥0∞)
    (hOpen : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ ¬ (ClaimsTrue U (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc.claims
        ∧ MTrue U (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc.fs)) ≤ εopen)
    (hRel : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ (∀ k r, rs[k]? = some r → r.claimed.toK U
          = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k)))
      ∧ ¬ ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))) ≤ εrel)
    (hLk : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ ¬ ZK60.Layout.W16Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) fams) ≤ εlk) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X (Lay.dPos p))
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))))
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
  by_cases ho : ClaimsTrue U (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc.claims
      ∧ MTrue U (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc.fs
  · by_cases hcl : ∀ k r, rs[k]? = some r → r.claimed.toK U
        = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k))
    · by_cases hrel : ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      · by_cases hlk : ZK60.Layout.W16Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) fams
        · exact absurd (ZK60.Layout.blockSat_of_slots Pb Lay B _ fams hF hW h24 hrel hlk) hns
        · exact Or.inr ⟨bga, rs, acc, hacc, hlk⟩
      · exact Or.inl (Or.inr ⟨bga, rs, acc, hacc, hcl, hrel⟩)
    · push Not at hcl
      obtain ⟨k, r, hr, hne⟩ := hcl
      exact Or.inl (Or.inl (Or.inr ⟨bga, rs, acc, hacc.1, ho.1, ho.2, k, r, hr, hdeg _ _ _ _, hne⟩))
  · exact Or.inl (Or.inl (Or.inl ⟨bga, rs, acc, hacc, ho⟩))

end Block

/-! ## The openings' term, composed -/

section Open

variable {Q D : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]

/-- **The openings' and `M`'s knowledge term, composed** (D63 lane L20). Let `Acc` be the block's acceptance and `Bad`
"some claim handed to an opening, or some `M` functional, is false of the extracted data". Let `GA`, `GH`, `GM` be the
openings' good predicates on the extracted data (`A`'s and `H`'s `GroupsGood` at `opA`'s window, `M`'s `MGood` at its
window), `EvA`, `EvH`, `EvM` their chain events (`opening_knowledge_chain_pos`'s, `mask_knowledge_chain_pos`'s), `EvX`
the extraction failure (`extract_fail_run`'s). Given the two deterministic links
* `hsem` (the claims' semantics): on acceptance, `GA ∧ GH ∧ GM` makes every claim and `M` functional true of the
  extracted data,
* `hexec` (the executable link): on acceptance without an extraction failure, each opening's good predicate holds or
  its chain event does (its windows are at a step's end and it is alive at the end of the chain, read off the
  verifier's own items with the opened columns equal to the extracted ones),
the probability of `Acc ∧ Bad` is at most `εM + εA + εH + εX`. -/
theorem block_open_knowledge (Acc Bad GA GH GM EvA EvH EvM EvX : (Q → D) → Prop) (εM εA εH εX : ℝ≥0∞)
    (hsem : ∀ H, Acc H → GA H → GH H → GM H → ¬ Bad H)
    (hexec : ∀ H, Acc H → ¬ EvX H → (GA H ∨ EvA H) ∧ (GH H ∨ EvH H) ∧ (GM H ∨ EvM H))
    (hM : prH EvM ≤ εM) (hA : prH EvA ≤ εA) (hH : prH EvH ≤ εH) (hX : prH EvX ≤ εX) :
    prH (fun H => Acc H ∧ Bad H) ≤ εM + εA + εH + εX := by
  refine le_trans (MeasureTheory.measure_mono ?_)
    ((MeasureTheory.measure_union_le _ _).trans (add_le_add
      ((MeasureTheory.measure_union_le _ _).trans (add_le_add
        ((MeasureTheory.measure_union_le _ _).trans (add_le_add hM hA)) hH)) hX))
  intro H hH'
  rw [Set.mem_ofPred_eq] at hH'
  obtain ⟨hacc, hbad⟩ := hH'
  by_cases hx : EvX H
  · exact Or.inr hx
  obtain ⟨ha, hh, hm⟩ := hexec H hacc hx
  rcases hm with hm | hm
  · rcases ha with ha | ha
    · rcases hh with hh | hh
      · exact absurd hbad (hsem H hacc ha hh hm)
      · exact Or.inl (Or.inr hh)
    · exact Or.inl (Or.inl (Or.inr ha))
  · exact Or.inl (Or.inl (Or.inl hm))

end Open

/-! ## The block's knowledge error against the approved target -/

section Target

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

/-- **One block's knowledge error is at most the approved target, for EVERY `q`** (D63 lane L20; L16-1 closed for the
block). For any block shape whose slots have degree `≤ 7` and at most `2^20` chain items, with the openings' and `M`'s
chain events bounded at their proved per-position bounds (`mask_knowledge_chain_pos`: `q·maskE + 3·maskE + coll`,
`maskE ≤ 2^-jM`; `opening_knowledge_chain_pos` for `A` and `H`: `(q·εA + εA + coll) + (q·εB + εB + coll)`,
`εA ≤ 2^-jA`, `εB ≤ 2^-jB`; W16R2: `jM = 106`, `jA = 111`, `jB = 113`), the extraction failure (`extract_fail_run`,
at most three roots and `2^22·(q + 1)` queries), the two deterministic links `hsem`, `hexec`, and L13's and LogUp's
terms within their budgets (`εrel ≤ (q + 1)·crel/2^126`, `εlk ≤ (q + 1)·clk/2^126`, the budget `hbud`; at W16R2 it is
`dmax + blockND + crel + clk ≤ 2^25`): the probability that the
block verifier accepts while the extracted planes do not satisfy `BlockSat` is at most `εsTarget q = q·2^-100 +
2^-100`. -/
theorem block_knowledge_target [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
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
    (hℓs : blockLen P.draws P.geom.slots hdrLen ≤ 2 ^ 20)
    (Pb : ZK60.Block.BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf) (B : ZK60.Layout.W16Pub S Pb Lay)
    (fams : List (ℕ × ℕ)) (hF : ZK60.Circuit.FamsOK fams) (hW : ZK60.Layout.W16Widths S fams) (h24 : S.h24 = true)
    (xtE : Cuts3 L → RootsO → ZK60.Layout.W16Data Ct Cw Cg Cj Cd Cf)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    -- the openings: their good predicates, chain events and per-position bounds
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
        ∧ ¬ (ClaimsTrue U (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc.claims
          ∧ MTrue U (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc.fs)) → ¬ (GA G ∧ GH G ∧ GM G))
    (hexec : ∀ G, (∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc) → ¬ EvX G →
      (GA G ∨ EvA G) ∧ (GH G ∨ EvH G) ∧ (GM G ∨ EvM G))
    -- L13's relations and LogUp, within their budgets
    (εrel εlk : ℝ≥0∞) (crel clk : ℕ)
    (hbud : 3 * 2 ^ (126 - jM) + 2 * (2 ^ (126 - jA) + 2 ^ (126 - jB)) + 2 ^ 18 + 2 ^ 16 + dmax + blockND P.geom.slots
      + crel + clk ≤ 2 ^ 26)
    (hrelB : εrel ≤ u126 q crel) (hlkB : εlk ≤ u126 q clk)
    (hRel : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ (∀ k r, rs[k]? = some r → r.claimed.toK U
          = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k)))
      ∧ ¬ ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))) ≤ εrel)
    (hLk : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ ¬ ZK60.Layout.W16Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) fams) ≤ εlk) :
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
    -- the openings' term
    have hOpen := block_open_knowledge
      (fun G => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc)
      (fun G => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ ¬ (ClaimsTrue U (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc.claims
          ∧ MTrue U (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc.fs))
      GA GH GM EvA EvH EvM EvX _ _ _ _
      (fun G _ ha hh hm hb => hsem G hb ⟨ha, hh, hm⟩) hexec hM hEA hEH hX
    have hOpen' : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ ¬ (ClaimsTrue U (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc.claims
          ∧ MTrue U (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc.fs))
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
    refine (block_knowledge_acc U hU hK2 key domain hs hL hL64 hL81 P hdrLen F csX msX hpolyC hEval hdeg dmax hdp
      hgeom hgt Pb Lay B fams hF hW h24 xtE q A hA _ εrel εlk hOpen' hRel hLk).trans ?_
    rw [hF2]
    exact block_total_le_target gP (by norm_num [gP]) (by norm_num [gP]) q hq _ ℓo hℓs hℓo dmax
      (blockND P.geom.slots) jM jA jB hjM hjA hjB maskE εAa εBa εAh εBh hmE hAa hBa hAh hBh T' nr hT' hnr εrel εlk crel
      clk hrelB hlkB hbud
  · refine le_trans ?_ (one_le_εsTarget (by omega))
    calc _ ≤ (PMF.uniformOfFintype (QB L → Dig)).toOuterMeasure Set.univ :=
          MeasureTheory.measure_mono (Set.subset_univ _)
      _ = 1 := (PMF.toOuterMeasure_apply_eq_one_iff _ Set.univ).mpr (Set.subset_univ _)

end Target

end ZK60.Exec.Block
