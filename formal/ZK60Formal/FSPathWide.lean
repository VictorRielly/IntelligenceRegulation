/-
D63, step L3 (soundness): the sharper Fiat–Shamir count on the code's chain (finding F25, Victor's ruling D66(4)).

`FSWide.lean`'s `chain_sound_wide` charges every position of the joint run (the prover's `q` queries and the
verifier's `ℓ + 1`) as one attempt at the SAME error `ε`. Its bound is `(q + ℓ + 1)·ε + collision terms`, so its
query-free part is `(ℓ + 1)·ε`. This file charges each position its own error:
* a prover's query may attack any round: it is charged the largest error `εmax`;
* the verifier's own query for step `it` after its chain `τ` is charged `e τ it`, the error of THAT step from THAT
  chain. The verifier's chain is read off the log (the prover is replayed to find where its part ends,
  `OC.replay`), so the charge is a function of the log before the query, as the fresh-hit argument needs.
The bound becomes `q·εmax + B + collision terms`, where `B` bounds the verifier's charge `Σ_steps e τ it` along its
own chain (`vSumFrom`). The charge may depend on the whole chain before the step (the statement, the messages, the
earlier challenges): `FSPath.lean` uses this for the path-wise bound.

**What is proved.**
* `wideHit_prob_le_pos`: `FSWide.lean`'s `wideHit_prob_le` with a position-dependent bound. If the set named at a
  position (by the log `P` before it and its query `y`) has probability at most `f P y` under a uniform vector, a wide
  fresh hit has probability at most `B`, whenever, for every oracle, the charges `f` along the run sum to at most `B`.
  The proof is `wideHit_prob_le`'s: the swap bijection position by position, now summed oracle by oracle.
* `chain_sound_wide_seq`: `chain_sound_wide` with per-step errors `e τ it` (`hround`) and the charge of the verifier's
  chain bounded by `B` (`hB`): the probability that the chain of the first `s` heads is doomed while the whole chain
  is not is at most `q·εmax + B + collBound T D + collBound (T + 1) D`, `T = q + ℓ + 1`.
* The pieces: `vSumFrom` (the verifier's charge, item by item), `vSumFrom_eq_sum` (the same as a sum over positions),
  the verifier's log (`chainOC_runLog_fst`, `chainOC_runLog_snd`, `chainOCFrom_queries_length`), `vChainOf` (the
  verifier's chain read back from its log) and `vChainOf_take` (it is the chain).

**Why the verifier's chain is read back.** The trace-back of `FSChain.lean` recovers a chain from the log, but only
outside the collision and guess events. The charge must bound the sum along the run for EVERY oracle, so at a
verifier position it is computed from the verifier's own log entries, and the named set is restricted to the case
where the traced-back chain IS that chain (`ChainEnc.posBad`). At the escaping step's first occurrence this holds
outside the two events: both chains trace back to themselves and end at the same digest.
-/
import ZK60Formal.FSCompose
import ZK60Formal.FSOpening

set_option autoImplicit false

namespace ZK60.Sound

open scoped ENNReal
open Finset

/-! ## The wide fresh-hit lemma with a position-dependent bound -/

section HitPos

variable {Q D : Type}

/-- **The charge at position `t` of a log**: `f` of the log before it and its query (`0` past the end). -/
def gpos (f : List (Q × D) → Q → ℝ≥0∞) (L : List (Q × D)) (t : ℕ) : ℝ≥0∞ :=
  match L[t]? with
  | some e => f (L.take t) e.1
  | none => 0

variable [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]

/-- **The wide-digest lemma with a position-dependent bound.** For a computation making at most `T` queries, and a
set `Bad` named by the log and the start query whose probability under a uniform vector is at most `f P y`: if the
charges along the run sum to at most `B` for every oracle, a wide fresh hit has probability at most `B`. -/
theorem wideHit_prob_le_pos {α : Type} (A : OC Q D α) (T : ℕ) (hA : A.Bounded T) (wd : Q → ℕ)
    (nx : Q → ℕ → D → Q) (hinj : ∀ y (b : Fin (wd y) → D), Function.Injective (widePts y (nx y) b))
    (Bad : List (Q × D) → Q → List D → Prop) (f : List (Q × D) → Q → ℝ≥0∞)
    (hBad : ∀ P y, (PMF.uniformOfFintype (Fin (wd y) → D)).toOuterMeasure {b | Bad P y (List.ofFn b)} ≤ f P y)
    (B : ℝ≥0∞) (hB : ∀ H, ∑ t ∈ range T, gpos f (A.runLog H).2 t ≤ B) :
    prH (fun H => WideHit wd nx Bad H (A.runLog H).2) ≤ B := by
  classical
  set μ := (PMF.uniformOfFintype (Q → D)).toOuterMeasure
  let G : ℕ → Q → (Q → D) → Prop := fun t y H =>
    ∃ e, (A.runLog H).2[t]? = some e ∧ e.1 = y ∧ y ∉ ((A.runLog H).2.take t).map Prod.fst
  let W : ℕ → (y : Q) → (Q → D) → (Fin (wd y) → D) → Prop := fun t y H b =>
    G t y H ∧ (∀ j, widePts y (nx y) b j ∉ ((A.runLog H).2.take t).map Prod.fst)
      ∧ Bad ((A.runLog H).2.take t) y (List.ofFn b)
  let E : ℕ → (Q → D) → Prop := fun t H => ∃ y, W t y H (wideVals H y (nx y) (wd y))
  have hsub : {H | WideHit wd nx Bad H (A.runLog H).2} ⊆ ⋃ t ∈ range T, {H | E t H} := by
    intro H hH
    obtain ⟨t, e, h1, h2, h3, h4⟩ := hH
    have ht : t < (A.runLog H).2.length := (List.getElem?_eq_some_iff.mp h1).1
    simp only [Set.mem_iUnion, Set.mem_ofPred_eq, mem_range]
    exact ⟨t, lt_of_lt_of_le ht (OC.runLog_length_le H A T hA), e.1, ⟨e, h1, rfl, h2⟩, h3, h4⟩
  -- one position and one start query: the bijection, with the bound read oracle by oracle
  have hcount : ∀ t y, ((univ.filter (fun H => W t y H (wideVals H y (nx y) (wd y)))).card : ℝ≥0∞)
      ≤ ∑ H : Q → D, (if G t y H then f ((A.runLog H).2.take t) y else 0) := by
    intro t y
    have hD0 : ((Fintype.card D ^ wd y : ℕ) : ℝ≥0∞) ≠ 0 := by
      have : Fintype.card D ^ wd y ≠ 0 := pow_ne_zero _ Fintype.card_ne_zero
      exact_mod_cast this
    have hDt : ((Fintype.card D ^ wd y : ℕ) : ℝ≥0∞) ≠ ⊤ := ENNReal.natCast_ne_top _
    have hinv : ∀ H, W t y H (wideVals H y (nx y) (wd y)) → ∀ e,
        W t y (Function.extend (widePts y (nx y) (wideVals H y (nx y) (wd y))) e H) (wideVals H y (nx y) (wd y)) := by
      intro H hW e
      obtain ⟨⟨e₀, h1, h2, h3⟩, hpts, hbad⟩ := hW
      set H' := Function.extend (widePts y (nx y) (wideVals H y (nx y) (wd y))) e H
      have hagree : ∀ e' ∈ (A.runLog H).2.take t, H' e'.1 = H e'.1 := by
        intro e' he'
        refine Function.extend_apply' _ _ _ ?_
        rintro ⟨a, ha⟩
        exact hpts a (ha ▸ List.mem_map_of_mem he')
      have hag := OC.runLog_take_agree H H' A t hagree
      refine ⟨?_, ?_, ?_⟩
      · have hq : ((A.runLog H').2[t]?).map Prod.fst = some y := by
          rw [hag.2, h1]
          simp [h2]
        obtain ⟨e', he', he'1⟩ := Option.map_eq_some_iff.mp hq
        exact ⟨e', he', he'1, by rw [hag.1]; exact h3⟩
      · intro j
        rw [hag.1]
        exact hpts j
      · rw [hag.1]
        exact hbad
    have hA1 := wide_card_le y (nx y) (wd y) (hinj y) (W t y) hinv
    have hslice : ∀ H, ((univ.filter (fun b : Fin (wd y) → D => W t y H b)).card : ℝ≥0∞)
        ≤ (if G t y H then f ((A.runLog H).2.take t) y else 0) * ((Fintype.card D ^ wd y : ℕ) : ℝ≥0∞) := by
      intro H
      split_ifs with hG
      · have hb := hBad ((A.runLog H).2.take t) y
        rw [prob_uniform_eq_card (fun b : Fin (wd y) → D => Bad ((A.runLog H).2.take t) y (List.ofFn b)),
          ENNReal.div_le_iff (by exact_mod_cast Fintype.card_ne_zero) (ENNReal.natCast_ne_top _)] at hb
        refine le_trans ?_ (hb.trans (le_of_eq ?_))
        · exact_mod_cast card_le_card (fun b hb' => by
            simp only [mem_filter, mem_univ, true_and] at hb' ⊢
            exact hb'.2.2)
        · rw [Fintype.card_fun, Fintype.card_fin, Nat.cast_pow]
      · have : univ.filter (fun b : Fin (wd y) → D => W t y H b) = ∅ :=
          filter_eq_empty_iff.mpr (fun b _ hb => hG hb.1)
        simp [this]
    have hB' : ((univ.filter (fun p : (Q → D) × (Fin (wd y) → D) => W t y p.1 p.2)).card : ℝ≥0∞)
        ≤ (∑ H : Q → D, (if G t y H then f ((A.runLog H).2.take t) y else 0))
          * ((Fintype.card D ^ wd y : ℕ) : ℝ≥0∞) := by
      rw [card_filter_prod (fun p : (Q → D) × (Fin (wd y) → D) => W t y p.1 p.2), Nat.cast_sum, sum_mul]
      exact sum_le_sum (fun H _ => hslice H)
    have h2 : ((univ.filter (fun H => W t y H (wideVals H y (nx y) (wd y)))).card : ℝ≥0∞)
        * ((Fintype.card D ^ wd y : ℕ) : ℝ≥0∞)
        ≤ (∑ H : Q → D, (if G t y H then f ((A.runLog H).2.take t) y else 0))
          * ((Fintype.card D ^ wd y : ℕ) : ℝ≥0∞) :=
      le_trans (by exact_mod_cast hA1) hB'
    exact (ENNReal.mul_le_mul_iff_left hD0 hDt).mp h2
  -- one position: only the query actually asked there is named
  have hone : ∀ t H, ∑ y, (if G t y H then f ((A.runLog H).2.take t) y else 0) ≤ gpos f (A.runLog H).2 t := by
    intro t H
    by_cases hex : ∃ y, G t y H
    · obtain ⟨y₀, e₀, h1, h2, -⟩ := hex
      have hsum : ∑ y, (if G t y H then f ((A.runLog H).2.take t) y else 0)
          ≤ f ((A.runLog H).2.take t) y₀ := by
        rw [Finset.sum_eq_single y₀]
        · split_ifs <;> simp
        · intro y _ hy
          refine ite_eq_right ?_
          rintro ⟨e', h1', h2', -⟩
          rw [h1, Option.some.injEq] at h1'
          subst h1'
          exact hy (h2'.symm.trans h2)
        · intro h
          exact absurd (mem_univ _) h
      refine hsum.trans (le_of_eq ?_)
      simp only [gpos, h1, h2]
    · simp only [not_exists] at hex
      have h0 : ∀ y, (if G t y H then f ((A.runLog H).2.take t) y else 0) = 0 := fun y => ite_eq_right (hex y)
      simp only [h0, sum_const_zero]
      exact zero_le
  have hpos : ∀ t, μ {H | E t H} ≤ (∑ H : Q → D, gpos f (A.runLog H).2 t) / Fintype.card (Q → D) := by
    intro t
    rw [prob_uniform_eq_card (E t)]
    refine ENNReal.div_le_div_right ?_ _
    have hU : univ.filter (E t)
        ⊆ univ.biUnion (fun y => univ.filter (fun H => W t y H (wideVals H y (nx y) (wd y)))) := by
      intro H hH
      simp only [mem_filter, mem_univ, true_and] at hH
      obtain ⟨y, hy⟩ := hH
      exact mem_biUnion.mpr ⟨y, mem_univ _, mem_filter.mpr ⟨mem_univ _, hy⟩⟩
    calc ((univ.filter (E t)).card : ℝ≥0∞)
        ≤ ∑ y, ((univ.filter (fun H => W t y H (wideVals H y (nx y) (wd y)))).card : ℝ≥0∞) := by
          exact_mod_cast (card_le_card hU).trans card_biUnion_le
      _ ≤ ∑ y, ∑ H : Q → D, (if G t y H then f ((A.runLog H).2.take t) y else 0) :=
          sum_le_sum (fun y _ => hcount t y)
      _ = ∑ H : Q → D, ∑ y, (if G t y H then f ((A.runLog H).2.take t) y else 0) := sum_comm
      _ ≤ ∑ H : Q → D, gpos f (A.runLog H).2 t := sum_le_sum (fun H _ => hone t H)
  have hΩ0 : (Fintype.card (Q → D) : ℝ≥0∞) ≠ 0 := by exact_mod_cast Fintype.card_ne_zero
  have hΩt : (Fintype.card (Q → D) : ℝ≥0∞) ≠ ⊤ := ENNReal.natCast_ne_top _
  calc prH (fun H => WideHit wd nx Bad H (A.runLog H).2)
      ≤ μ (⋃ t ∈ range T, {H | E t H}) := MeasureTheory.measure_mono hsub
    _ ≤ ∑ t ∈ range T, μ {H | E t H} := MeasureTheory.measure_biUnion_finset_le _ _
    _ ≤ ∑ t ∈ range T, (∑ H : Q → D, gpos f (A.runLog H).2 t) / Fintype.card (Q → D) :=
        sum_le_sum (fun t _ => hpos t)
    _ = (∑ H : Q → D, ∑ t ∈ range T, gpos f (A.runLog H).2 t) / Fintype.card (Q → D) := by
        simp only [div_eq_mul_inv, ← sum_mul]
        rw [sum_comm]
    _ ≤ (∑ _H : Q → D, B) / Fintype.card (Q → D) :=
        ENNReal.div_le_div_right (sum_le_sum (fun H _ => hB H)) _
    _ = B := by
        rw [sum_const, card_univ, nsmul_eq_mul, mul_comm, ENNReal.mul_div_cancel_right hΩ0 hΩt]

end HitPos

/-! ## The verifier's charge, and the verifier's chain read back from its log -/

section Pieces

/-- A list of pairs is the zip of its first components with its second components (cut at any length). -/
theorem zip_map_fst_take {α β : Type} : ∀ (l : List (α × β)) (m : ℕ),
    (l.map Prod.fst).zip ((l.map Prod.snd).take m) = l.take m
  | [], _ => by simp
  | _ :: _, 0 => by simp
  | e :: l, m + 1 => by
    simp only [List.map_cons, List.take_succ_cons, List.zip_cons_cons]
    rw [zip_map_fst_take l m]

end Pieces

namespace ChainEnc

variable {It Q D : Type} (C : ChainEnc It Q D)

/-- **The verifier's charge**: each item `it` of its chain is charged `e τ it`, `τ` the chain before it. -/
def vSumFrom (e : List (It × D) → It → ℝ≥0∞) (H : Q → D) : List (It × D) → List It → ℝ≥0∞
  | _, [] => 0
  | τ, it :: its => e τ it + vSumFrom e H (τ ++ [(it, H (C.link (C.lastD H τ) it))]) its

/-- The charge at position `m` of an item list hashed from `τ`: its item there, at the chain of the items before it. -/
def vPos (e : List (It × D) → It → ℝ≥0∞) (H : Q → D) (τ : List (It × D)) (its : List It) (m : ℕ) : ℝ≥0∞ :=
  match its[m]? with
  | some it => e (C.chainFrom H τ (its.take m)) it
  | none => 0

/-- **The verifier's charge, position by position.** -/
theorem vSumFrom_eq_sum (e : List (It × D) → It → ℝ≥0∞) (H : Q → D) :
    ∀ (τ : List (It × D)) (its : List It) (T : ℕ), its.length ≤ T →
      ∑ m ∈ range T, C.vPos e H τ its m = C.vSumFrom e H τ its
  | τ, [], T, _ => by simp [vPos, vSumFrom]
  | τ, it :: its, T, hT => by
    obtain ⟨T, rfl⟩ : ∃ T', T = T' + 1 := ⟨T - 1, by simp only [List.length_cons] at hT; omega⟩
    rw [Finset.sum_range_succ', vSumFrom, add_comm (e τ it)]
    congr 1
    · rw [← vSumFrom_eq_sum e H _ its T (by simp only [List.length_cons] at hT; omega)]
      refine sum_congr rfl (fun m _ => ?_)
      simp only [vPos, List.getElem?_cons_succ, List.take_succ_cons, chainFrom]

/-- The verifier's hashing from `τ` asks one query per item. -/
theorem chainOCFrom_queries_length (H : Q → D) : ∀ (τ : List (It × D)) (its : List It),
    (OC.queries H (C.chainOCFrom (H C.start) τ its)).length = its.length
  | _, [] => by simp [chainOCFrom, OC.queries, OC.runLog]
  | τ, it :: its => by
    rw [chainOCFrom, OC.queries_ask, List.length_cons, chainOCFrom_queries_length H _ its, List.length_cons]

/-- The answers of the verifier's hashing from `τ` are the digests of the chain's new entries. -/
theorem chainOCFrom_runLog_snd (H : Q → D) : ∀ (τ : List (It × D)) (its : List It),
    ((C.chainOCFrom (H C.start) τ its).runLog H).2.map Prod.snd
      = ((C.chainFrom H τ its).drop τ.length).map Prod.snd
  | τ, [] => by simp [chainOCFrom, chainFrom, OC.runLog]
  | τ, it :: its => by
    have ih := chainOCFrom_runLog_snd H (τ ++ [(it, H (C.link (C.lastD H τ) it))]) its
    obtain ⟨ext, hext, -⟩ := C.chainFrom_eq_append H its (τ ++ [(it, H (C.link (C.lastD H τ) it))])
    rw [hext, List.drop_left' rfl] at ih
    have h1 : C.chainFrom H τ (it :: its) = τ ++ ((it, H (C.link (C.lastD H τ) it)) :: ext) := by
      rw [chainFrom, hext, List.append_assoc, List.singleton_append]
    rw [h1, List.drop_left' rfl, List.map_cons, ← ih]
    rfl

/-- **The verifier's questions**: the start query, the links of the first `m` items, then the link of item `m` with
the chain of the first `m` items. -/
theorem chainOC_queries_eq (H : Q → D) (its : List It) (m : ℕ) (hm : m < its.length) :
    ∃ rest, OC.queries H (C.chainOC its)
      = (C.start :: OC.queries H (C.chainOCFrom (H C.start) [] (its.take m)))
        ++ C.link (C.lastD H (C.chainFrom H [] (its.take m))) its[m] :: rest := by
  have h : OC.queries H (C.chainOCFrom (H C.start) [] its)
      = OC.queries H (C.chainOCFrom (H C.start) [] (its.take m))
        ++ OC.queries H (C.chainOCFrom (H C.start) (C.chainFrom H [] (its.take m)) (its[m] :: its.drop (m + 1))) := by
    conv_lhs => rw [show its = its.take m ++ its.drop m from (List.take_append_drop m its).symm]
    rw [C.chainOCFrom_queries_append, List.drop_eq_getElem_cons hm]
  refine ⟨OC.queries H (C.chainOCFrom (H C.start) (C.chainFrom H [] (its.take m)
    ++ [(its[m], H (C.link (C.lastD H (C.chainFrom H [] (its.take m))) its[m]))]) (its.drop (m + 1))), ?_⟩
  rw [chainOC, OC.queries_ask, h, chainOCFrom, OC.queries_ask, List.cons_append]
  rfl

/-- The verifier's log has one entry more than its items. -/
theorem chainOC_runLog_length (H : Q → D) (its : List It) :
    ((C.chainOC its).runLog H).2.length = its.length + 1 := by
  have h := C.chainOCFrom_queries_length H [] its
  simp only [OC.queries, List.length_map] at h
  show ((C.chainOCFrom (H C.start) [] its).runLog H).2.length + 1 = its.length + 1
  rw [h]

/-- The first entry of the verifier's log asks the start query. -/
theorem chainOC_runLog_zero (H : Q → D) (its : List It) :
    (((C.chainOC its).runLog H).2[0]?).map Prod.fst = some C.start := rfl

/-- Entry `m + 1` of the verifier's log asks the link of item `m` with the chain of the first `m` items. -/
theorem chainOC_runLog_succ (H : Q → D) (its : List It) (m : ℕ) (hm : m < its.length) :
    (((C.chainOC its).runLog H).2[m + 1]?).map Prod.fst
      = some (C.link (C.lastD H (C.chainFrom H [] (its.take m))) its[m]) := by
  obtain ⟨rest, hrest⟩ := C.chainOC_queries_eq H its m hm
  have hlen : (C.start :: OC.queries H (C.chainOCFrom (H C.start) [] (its.take m))).length = m + 1 := by
    rw [List.length_cons, C.chainOCFrom_queries_length H [] (its.take m), List.length_take, min_eq_left hm.le]
  have hq : (OC.queries H (C.chainOC its))[m + 1]?
      = some (C.link (C.lastD H (C.chainFrom H [] (its.take m))) its[m]) := by
    rw [hrest, List.getElem?_append_right hlen.le, hlen, Nat.sub_self, List.getElem?_cons_zero]
  rw [← List.getElem?_map]
  exact hq

/-- The first `m + 1` questions of the verifier's log are the queries of the chain of its first `m` items. -/
theorem chainOC_runLog_take_fst (H : Q → D) (its : List It) (m : ℕ) (hm : m < its.length) :
    ((((C.chainOC its).runLog H).2.take (m + 1)).map Prod.fst)
      = C.start :: OC.queries H (C.chainOCFrom (H C.start) [] (its.take m)) := by
  obtain ⟨rest, hrest⟩ := C.chainOC_queries_eq H its m hm
  have hlen : (C.start :: OC.queries H (C.chainOCFrom (H C.start) [] (its.take m))).length = m + 1 := by
    rw [List.length_cons, C.chainOCFrom_queries_length H [] (its.take m), List.length_take, min_eq_left hm.le]
  rw [List.map_take]
  change (OC.queries H (C.chainOC its)).take (m + 1) = _
  rw [hrest, List.take_left' hlen]

/-- A chain hashed from nothing, cut after `m` entries, is the chain of the first `m` items. -/
theorem chainFrom_take (H : Q → D) (its : List It) (m : ℕ) (hm : m ≤ its.length) :
    (C.chainFrom H [] its).take m = C.chainFrom H [] (its.take m) := by
  have hsplit : C.chainFrom H [] its = C.chainFrom H (C.chainFrom H [] (its.take m)) (its.drop m) := by
    rw [← C.chainFrom_append, List.take_append_drop]
  obtain ⟨ext, hext, -⟩ := C.chainFrom_eq_append H (its.drop m) (C.chainFrom H [] (its.take m))
  rw [hsplit, hext, List.take_left' (by rw [C.chainFrom_length, List.length_nil, zero_add, List.length_take,
    min_eq_left hm])]

/-- **The verifier's chain read back from its log** `V` (its start query, then one link per item): the items paired
with the answers after the first. -/
def vChainOf (its : List It) (V : List (Q × D)) : List (It × D) := its.zip ((V.drop 1).map Prod.snd)

/-- **Read back from the verifier's first `m + 1` log entries, it is the chain of its first `m` items.** -/
theorem vChainOf_take (H : Q → D) (its : List It) (m : ℕ) (hm : m ≤ its.length) :
    vChainOf its (((C.chainOC its).runLog H).2.take (m + 1)) = C.chainFrom H [] (its.take m) := by
  have hans : (((C.chainOC its).runLog H).2.drop 1).map Prod.snd = (C.chainFrom H [] its).map Prod.snd := by
    have h := C.chainOCFrom_runLog_snd H [] its
    rw [List.length_nil, List.drop_zero] at h
    exact h
  unfold vChainOf
  rw [List.drop_take, show m + 1 - 1 = m by omega, List.map_take, hans]
  have hz := zip_map_fst_take (C.chainFrom H [] its) m
  rw [C.chainFrom_nil_map_fst] at hz
  rw [hz, C.chainFrom_take H its m hm]

variable [DecidableEq Q] [DecidableEq D]

/-- **The set named at a position**, for the sharper count: `stepBad`; and, at a position of the verifier (the
prover's replay ends inside the log before it), only when the traced-back chain is the verifier's own chain. -/
def posBad (S : Steps It) (St : List (Q × D) → List (It × D) → Prop) (s ℓ : ℕ) {α : Type} (A : OC Q D α)
    (heads : α → List It) (P : List (Q × D)) (y : Q) (ds : List D) : Prop :=
  C.stepBad S St s ℓ P y ds ∧ ∀ r, A.replay P = some r → ∀ d it τ, C.ldec y = some (d, it) →
    C.traceBack P (ℓ + 1) d = some τ → τ = vChainOf ((heads r.1).flatMap S.items) (P.drop r.2)

/-- **The charge at a position**: `εmax` at a prover's position; at the verifier's, the error of its step from its
own chain. -/
def posErr (S : Steps It) (e : List (It × D) → It → ℝ≥0∞) (εmax : ℝ≥0∞) {α : Type} (A : OC Q D α)
    (heads : α → List It) (P : List (Q × D)) (y : Q) : ℝ≥0∞ :=
  match A.replay P with
  | none => εmax
  | some r =>
    match C.ldec y with
    | none => 0
    | some p => e (vChainOf ((heads r.1).flatMap S.items) (P.drop r.2)) p.2

omit [DecidableEq Q] [DecidableEq D] in
/-- The charge never exceeds `εmax`. -/
theorem posErr_le (S : Steps It) (e : List (It × D) → It → ℝ≥0∞) (εmax : ℝ≥0∞) (he : ∀ τ it, e τ it ≤ εmax)
    {α : Type} (A : OC Q D α) (heads : α → List It) (P : List (Q × D)) (y : Q) :
    C.posErr S e εmax A heads P y ≤ εmax := by
  unfold posErr
  split
  · exact le_rfl
  · split
    · exact zero_le
    · exact he _ _

/-- **The named set has probability at most the charge.** -/
theorem posBad_prob_le [Fintype D] [Nonempty D] (S : Steps It) (St : List (Q × D) → List (It × D) → Prop)
    (s ℓ : ℕ) (e : List (It × D) → It → ℝ≥0∞) (εmax : ℝ≥0∞) (he : ∀ τ it, e τ it ≤ εmax)
    (hround : ∀ P τ it, s ≤ τ.length → (∃ hs : List It, τ.map Prod.fst = hs.flatMap S.items) → ¬ St P τ →
      (PMF.uniformOfFintype (Fin (S.wd it) → D)).toOuterMeasure {b | St P (τ ++ S.ents it (List.ofFn b))}
        ≤ e τ it)
    {α : Type} (A : OC Q D α) (heads : α → List It) (P : List (Q × D)) (y : Q) :
    (PMF.uniformOfFintype (Fin (C.wdQ S y) → D)).toOuterMeasure
        {b | C.posBad S St s ℓ A heads P y (List.ofFn b)} ≤ C.posErr S e εmax A heads P y := by
  have hempty : ∀ (E : Set (Fin (C.wdQ S y) → D)), (∀ b, b ∉ E) →
      (PMF.uniformOfFintype (Fin (C.wdQ S y) → D)).toOuterMeasure E ≤ C.posErr S e εmax A heads P y := by
    intro E hE
    rw [Set.eq_empty_iff_forall_notMem.mpr hE, MeasureTheory.measure_empty]
    exact zero_le
  rcases hy : C.ldec y with _ | ⟨d, it⟩
  · refine hempty _ (fun b hb => ?_)
    obtain ⟨⟨d', it', τ', h1, -⟩, -⟩ := hb
    rw [hy] at h1
    cases h1
  · rcases htb : C.traceBack P (ℓ + 1) d with _ | τ
    · refine hempty _ (fun b hb => ?_)
      obtain ⟨⟨d', it', τ', h1, h2, -⟩, -⟩ := hb
      rw [hy, Option.some.injEq, Prod.mk.injEq] at h1
      obtain ⟨rfl, rfl⟩ := h1
      rw [htb] at h2
      cases h2
    · by_cases hc : s ≤ τ.length ∧ (∃ hs : List It, τ.map Prod.fst = hs.flatMap S.items) ∧ ¬ St P τ
      · have hw : C.wdQ S y = S.wd it := by simp [wdQ, hy]
        have hsub : {b : Fin (C.wdQ S y) → D | C.posBad S St s ℓ A heads P y (List.ofFn b)}
            ⊆ {b | St P (τ ++ S.ents it (List.ofFn b))} := by
          rintro b ⟨⟨d', it', τ', h1, h2, -, -, -, h6⟩, -⟩
          rw [hy, Option.some.injEq, Prod.mk.injEq] at h1
          obtain ⟨rfl, rfl⟩ := h1
          rw [htb, Option.some.injEq] at h2
          subst h2
          exact h6
        have hμ : (PMF.uniformOfFintype (Fin (C.wdQ S y) → D)).toOuterMeasure
            {b | St P (τ ++ S.ents it (List.ofFn b))} ≤ e τ it := by
          rw [prob_ofFn_congr hw (fun ds => St P (τ ++ S.ents it ds))]
          exact hround P τ it hc.1 hc.2.1 hc.2.2
        rcases hr : A.replay P with _ | r
        · have hf : C.posErr S e εmax A heads P y = εmax := by simp [posErr, hr]
          rw [hf]
          exact (MeasureTheory.measure_mono hsub).trans (hμ.trans (he τ it))
        · have hf : C.posErr S e εmax A heads P y
              = e (vChainOf ((heads r.1).flatMap S.items) (P.drop r.2)) it := by
            simp [posErr, hr, hy]
          by_cases hv : τ = vChainOf ((heads r.1).flatMap S.items) (P.drop r.2)
          · rw [hf, ← hv]
            exact (MeasureTheory.measure_mono hsub).trans hμ
          · refine hempty _ (fun b hb => ?_)
            exact hv (hb.2 r hr d it τ hy htb)
      · refine hempty _ (fun b hb => ?_)
        obtain ⟨⟨d', it', τ', h1, h2, h3, h4, h5, -⟩, -⟩ := hb
        rw [hy, Option.some.injEq, Prod.mk.injEq] at h1
        obtain ⟨rfl, rfl⟩ := h1
        rw [htb, Option.some.injEq] at h2
        subst h2
        exact hc ⟨h3, h4, h5⟩

end ChainEnc

/-! ## The chain with per-step errors -/

section SoundSeq

variable {It Q D : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D]

omit [Fintype Q] [Fintype D] [Nonempty D] [DecidableEq Q] [DecidableEq D] in
/-- **The charges along the run sum to at most `q·εmax` plus the verifier's charge.** The prover's positions are at
most `q`, each charged at most `εmax`; the verifier's position `m + 1` is charged its item `m` at its own chain. -/
theorem posErr_sum_le (C : ChainEnc It Q D) (S : Steps It) (e : List (It × D) → It → ℝ≥0∞) (εmax : ℝ≥0∞)
    (he : ∀ τ it, e τ it ≤ εmax) {α : Type} (heads : α → List It) (ℓ : ℕ)
    (hℓ : ∀ o, ((heads o).flatMap S.items).length ≤ ℓ) (q : ℕ) (A : OC Q D α) (hA : A.Bounded q)
    (H : Q → D) :
    ∑ t ∈ range (q + ℓ + 1), gpos (C.posErr S e εmax A heads) ((C.stepRun S heads A).runLog H).2 t
      ≤ (q : ℝ≥0∞) * εmax + C.vSumFrom e H [] ((heads (A.run H)).flatMap S.items) := by
  set its := (heads (A.run H)).flatMap S.items with hits
  set LA := (A.runLog H).2 with hLA
  set LV := ((C.chainOC its).runLog H).2 with hLV
  set k := LA.length with hk
  set g := gpos (C.posErr S e εmax A heads) ((C.stepRun S heads A).runLog H).2 with hg
  have hL : ((C.stepRun S heads A).runLog H).2 = LA ++ LV := by
    rw [ChainEnc.stepRun, OC.runLog_bind]
  have hkq : k ≤ q := OC.runLog_length_le H A q hA
  have hlenV : LV.length = its.length + 1 := C.chainOC_runLog_length H its
  have hitsℓ : its.length ≤ ℓ := hℓ _
  -- every position is charged at most `εmax`
  have hgle : ∀ t, g t ≤ εmax := by
    intro t
    simp only [hg, gpos]
    split
    · exact C.posErr_le S e εmax he A heads _ _
    · exact zero_le
  -- a verifier's position
  have hgV : ∀ t, g (k + t) = match LV[t]? with
      | some en => (match C.ldec en.1 with
          | none => 0
          | some p => e (ChainEnc.vChainOf its (LV.take t)) p.2)
      | none => 0 := by
    intro t
    have hrep : A.replay (LA ++ LV.take t) = some (A.run H, k) := OC.replay_runLog_append H A _
    have htake : (LA ++ LV).take (k + t) = LA ++ LV.take t := by
      rw [List.take_append, List.take_of_length_le (by omega), show k + t - LA.length = t by omega]
    have hget : (LA ++ LV)[k + t]? = LV[t]? := by
      rw [List.getElem?_append_right (by omega), show k + t - LA.length = t by omega]
    have hdrop : (LA ++ LV.take t).drop k = LV.take t := List.drop_left' rfl
    simp only [hg, gpos, hL, hget, htake]
    rcases LV[t]? with _ | en
    · rfl
    · simp only [ChainEnc.posErr, hrep, hdrop]
      rfl
  -- the start query is charged nothing
  have hg0 : g (k + 0) = 0 := by
    rw [hgV 0]
    have h0 : (LV[0]?).map Prod.fst = some C.start := C.chainOC_runLog_zero H its
    rcases hv : LV[0]? with _ | en
    · rfl
    · rw [hv, Option.map_some, Option.some.injEq] at h0
      simp only [h0, C.ldec_start]
  -- the verifier's position `m + 1` is charged its item `m` at its own chain
  have hgS : ∀ m, g (k + (m + 1)) = C.vPos e H [] its m := by
    intro m
    rw [hgV (m + 1)]
    unfold ChainEnc.vPos
    by_cases hm : m < its.length
    · have h1 := C.chainOC_runLog_succ H its m hm
      rw [← hLV] at h1
      obtain ⟨en, hen, hen1⟩ := Option.map_eq_some_iff.mp h1
      rw [hen, List.getElem?_eq_getElem hm]
      simp only [hen1, C.ldec_link]
      rw [hLV, C.vChainOf_take H its m hm.le]
    · have hnone : LV[m + 1]? = none := List.getElem?_eq_none (by omega)
      rw [hnone, List.getElem?_eq_none (by omega)]
  calc ∑ t ∈ range (q + ℓ + 1), g t
      ≤ ∑ t ∈ range (k + (q + ℓ + 1)), g t :=
        Finset.sum_le_sum_of_subset (range_subset_range.mpr (by omega))
    _ = ∑ t ∈ range k, g t + ∑ t ∈ range (q + ℓ + 1), g (k + t) := Finset.sum_range_add _ _ _
    _ ≤ (k : ℝ≥0∞) * εmax + ∑ t ∈ range (q + ℓ + 1), g (k + t) := by
        gcongr
        calc ∑ t ∈ range k, g t ≤ ∑ _t ∈ range k, εmax := sum_le_sum (fun t _ => hgle t)
          _ = (k : ℝ≥0∞) * εmax := by rw [sum_const, card_range, nsmul_eq_mul]
    _ ≤ (q : ℝ≥0∞) * εmax + C.vSumFrom e H [] its := by
        refine add_le_add (mul_le_mul' (by exact_mod_cast hkq) le_rfl) (le_of_eq ?_)
        rw [show q + ℓ + 1 = (q + ℓ) + 1 from rfl, Finset.sum_range_succ', hg0, add_zero]
        rw [← C.vSumFrom_eq_sum e H [] its (q + ℓ) (by omega)]
        exact sum_congr rfl (fun m _ => hgS m)

/-- **Fiat–Shamir soundness on the code's chain with per-step errors (the sharper count).** Let `St P τ` be a state
on chains (it may read the log `P`) such that from a doomed chain of whole steps (at least `s` items), for every next
head `it`, a uniform vector of `wd it` digests escapes doom with probability at most `e τ it ≤ εmax`, and such that
once a chain's queries are logged a longer log does not change its state (`hstab`). A prover making at most `q` hash
queries outputs heads; the verifier hashes every step of them (at most `ℓ` items), and its own chain is charged at
most `B` (`hB`). The probability that the chain of the first `s` heads is doomed while the whole chain is not is at most
`q·εmax + B + collBound T D + collBound (T + 1) D`, `T = q + ℓ + 1`. -/
theorem chain_sound_wide_seq (C : ChainEnc It Q D) (S : Steps It) (St : List (Q × D) → List (It × D) → Prop)
    (s : ℕ) (e : List (It × D) → It → ℝ≥0∞) (εmax : ℝ≥0∞) (he : ∀ τ it, e τ it ≤ εmax)
    (hround : ∀ P τ it, s ≤ τ.length → (∃ hs : List It, τ.map Prod.fst = hs.flatMap S.items) → ¬ St P τ →
      (PMF.uniformOfFintype (Fin (S.wd it) → D)).toOuterMeasure {b | St P (τ ++ S.ents it (List.ofFn b))}
        ≤ e τ it)
    (hstab : ∀ (H : Q → D) (P P' : List (Q × D)) (τ : List (It × D)) (qs : List Q) (ext : List (It × D)),
      C.Chain H τ qs → s ≤ τ.length → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' → (∀ e ∈ P', e.2 = H e.1) →
        (St P (τ ++ ext) ↔ St P' (τ ++ ext)))
    {α : Type} (heads : α → List It) (ℓ : ℕ) (hℓ : ∀ o, ((heads o).flatMap S.items).length ≤ ℓ)
    (B : ℝ≥0∞) (hB : ∀ (H : Q → D) (o : α), C.vSumFrom e H [] ((heads o).flatMap S.items) ≤ B)
    (q : ℕ) (A : OC Q D α) (hA : A.Bounded q) :
    prH (fun H => ¬ St ((C.stepRun S heads A).runLog H).2
          (C.chainFrom H [] (((heads (A.run H)).take s).flatMap S.items))
        ∧ St ((C.stepRun S heads A).runLog H).2 (C.chainFrom H [] ((heads (A.run H)).flatMap S.items)))
      ≤ (q : ℝ≥0∞) * εmax + B + collBound (q + ℓ + 1) D + collBound (q + ℓ + 1 + 1) D := by
  classical
  set T := q + ℓ + 1 with hT
  set Cm := C.stepRun S heads A with hCmdef
  have hCm : Cm.Bounded T :=
    (hA.bind (fun o => (C.chainOC_bounded ((heads o).flatMap S.items)).mono
      (show ((heads o).flatMap S.items).length + 1 ≤ ℓ + 1 by have := hℓ o; omega))).mono (by omega)
  have hW := wideHit_prob_le_pos Cm T hCm (C.wdQ S) (C.nxQ S) (C.widePts_injective S)
    (C.posBad S St s ℓ A heads) (C.posErr S e εmax A heads)
    (fun P y => C.posBad_prob_le S St s ℓ e εmax he hround A heads P y) ((q : ℝ≥0∞) * εmax + B)
    (fun H => (posErr_sum_le C S e εmax he heads ℓ hℓ q A hA H).trans (add_le_add le_rfl (hB H _)))
  have hcoll := collision_prob_le Cm T hCm
  have hgs := freshHitQ_prob_le_gen Cm T hCm C.chainTargets (fun t => t + 1) (fun P y => C.chainTargets_card P y)
  have hsum : ∀ n : ℕ, ∑ t ∈ range n, (t + 1) = (n + 1) * (n + 1 - 1) / 2 := by
    intro n
    rw [← Finset.sum_range_id (n + 1)]
    simp [Finset.sum_range_succ']
  rw [hsum T] at hgs
  have hsub : {H : Q → D | ¬ St (Cm.runLog H).2 (C.chainFrom H [] (((heads (A.run H)).take s).flatMap S.items))
        ∧ St (Cm.runLog H).2 (C.chainFrom H [] ((heads (A.run H)).flatMap S.items))}
      ⊆ ({H | WideHit (C.wdQ S) (C.nxQ S) (C.posBad S St s ℓ A heads) H (Cm.runLog H).2}
          ∪ {H | ∃ a ∈ OC.queries H Cm, ∃ b ∈ OC.queries H Cm, a ≠ b ∧ H a = H b})
        ∪ {H | FreshHitQ C.chainTargets (Cm.runLog H).2} := by
    rintro H ⟨hns, hs⟩
    by_cases hg : FreshHitQ C.chainTargets (Cm.runLog H).2
    · exact Or.inr hg
    by_cases hc : ∃ a ∈ OC.queries H Cm, ∃ b ∈ OC.queries H Cm, a ≠ b ∧ H a = H b
    · exact Or.inl (Or.inr hc)
    refine Or.inl (Or.inl ?_)
    have hnc : ∀ a ∈ OC.queries H Cm, ∀ b ∈ OC.queries H Cm, a ≠ b → H a ≠ H b := by
      intro a ha b hb hab hH
      exact hc ⟨a, ha, b, hb, hab, hH⟩
    set L := (Cm.runLog H).2 with hLdef
    have hL : ∀ e ∈ L, e.2 = H e.1 := OC.runLog_answer H Cm
    set hds := heads (A.run H) with hhds
    set its := hds.flatMap S.items with hits
    -- the verifier's queries are logged
    have hqV : ∀ y ∈ OC.queries H (C.chainOC its), y ∈ L.map Prod.fst := by
      intro y hy
      show y ∈ OC.queries H Cm
      rw [hCmdef, ChainEnc.stepRun, OC.queries_bind]
      exact List.mem_append_right _ hy
    -- the header is followed by at least one step
    have htl : hds.drop s ≠ [] := by
      intro h0
      apply hns
      rw [List.drop_eq_nil_iff] at h0
      rw [List.take_of_length_le h0]
      exact hs
    have hlen_hd : (hds.take s).length = s := by
      rw [List.length_take]
      have : s < hds.length := by
        by_contra hle
        exact htl (List.drop_eq_nil_iff.mpr (by omega))
      omega
    have hfull : C.chainFrom H [] its
        = C.chainFrom H (C.chainFrom H [] ((hds.take s).flatMap S.items)) ((hds.drop s).flatMap S.items) := by
      rw [← C.chainFrom_append, ← List.flatMap_append, List.take_append_drop]
    rw [hfull] at hs
    obtain ⟨pre, it, post, hpre, hns', hs'⟩ := C.chain_flip_steps S H (St L) (hds.drop s) _ hns hs
    set τ' := C.chainFrom H (C.chainFrom H [] ((hds.take s).flatMap S.items)) (pre.flatMap S.items) with hτ'
    have hτ'0 : τ' = C.chainFrom H [] ((hds.take s ++ pre).flatMap S.items) := by
      rw [hτ', List.flatMap_append, C.chainFrom_append]
    have hits_split : its = (hds.take s ++ pre).flatMap S.items ++ (S.items it ++ post.flatMap S.items) := by
      rw [hits]
      conv_lhs => rw [← List.take_append_drop s hds, hpre]
      simp [List.flatMap_append, List.append_assoc]
    have hτ'len : τ'.length = ((hds.take s ++ pre).flatMap S.items).length := by
      rw [hτ'0, C.chainFrom_length, List.length_nil, zero_add]
    have hs_le : s ≤ τ'.length := by
      rw [hτ'len]
      refine le_trans ?_ (S.length_le_flatMap _)
      rw [List.length_append, hlen_hd]
      omega
    have hτ'ℓ : τ'.length + S.wd it ≤ ℓ := by
      have h1 := hℓ (A.run H)
      rw [← hhds, ← hits, hits_split, List.length_append, List.length_append, S.items_length] at h1
      omega
    -- the chain `τ'` and its queries
    have hc' := C.chain_chainFrom H ((hds.take s ++ pre).flatMap S.items) [] [C.start] ChainEnc.Chain.nil
    rw [← hτ'0] at hc'
    set qs' := [C.start] ++ OC.queries H (C.chainOCFrom (H C.start) [] ((hds.take s ++ pre).flatMap S.items))
      with hqs'
    have hqsplit : OC.queries H (C.chainOC its) = C.start ::
        (OC.queries H (C.chainOCFrom (H C.start) [] ((hds.take s ++ pre).flatMap S.items))
          ++ (OC.queries H (C.chainOCFrom (H C.start) τ' (S.items it))
            ++ OC.queries H (C.chainOCFrom (H C.start) (C.chainFrom H τ' (S.items it)) (post.flatMap S.items)))) := by
      rw [ChainEnc.chainOC, OC.queries_ask, hits_split, C.chainOCFrom_queries_append,
        C.chainOCFrom_queries_append, ← hτ'0]
    have hq'L : ∀ z ∈ qs', z ∈ L.map Prod.fst := by
      intro z hz
      refine hqV z ?_
      rw [hqsplit]
      rcases List.mem_append.mp hz with hz | hz
      · rw [List.mem_singleton] at hz
        rw [hz]
        exact List.mem_cons_self
      · exact List.mem_cons_of_mem _ (List.mem_append_left _ hz)
    have hstepL : ∀ z ∈ OC.queries H (C.chainOCFrom (H C.start) τ' (S.items it)), z ∈ L.map Prod.fst := by
      intro z hz
      refine hqV z ?_
      rw [hqsplit]
      exact List.mem_cons_of_mem _ (List.mem_append_right _ (List.mem_append_left _ hz))
    -- the step's first query and its first occurrence
    set y := C.link (C.lastD H τ') it with hy
    obtain ⟨rest, hrest⟩ := S.items_cons it
    have hyq : y ∈ OC.queries H (C.chainOCFrom (H C.start) τ' (S.items it)) := by
      rw [hrest, ChainEnc.chainOCFrom, OC.queries_ask]
      exact List.mem_cons_self
    obtain ⟨t, ⟨e1, e2⟩, ht, he, hfirst⟩ := exists_first (hstepL y hyq)
    simp only at he
    subst he
    have hPL : ∀ e ∈ L.take t, e.2 = H e.1 := fun e he => hL e (List.mem_of_mem_take he)
    have hPnc : ∀ a ∈ (L.take t).map Prod.fst, ∀ b ∈ (L.take t).map Prod.fst, a ≠ b → H a ≠ H b := by
      intro a ha b hb
      exact hnc a (mem_of_mem_take_map ha) b (mem_of_mem_take_map hb)
    have hord : ∀ z ∈ qs', z ∈ (L.take t).map Prod.fst := C.chain_ordered H hL hg hc' hq'L it ht rfl
    have hwd : C.wdQ S y = S.wd it := C.wdQ_link S _ it
    have hnx : C.nxQ S y = C.stepNx S it := C.nxQ_link S _ it
    have htb := C.traceBack_chain H hPL hPnc hc' hord (ℓ - τ'.length)
    rw [show τ'.length + 1 + (ℓ - τ'.length) = ℓ + 1 by omega] at htb
    refine ⟨t, (y, e2), ht, hfirst, ?_, ?_, ?_⟩
    · -- the later queries of the run were not asked before its first one
      intro j
      obtain ⟨j, hj⟩ := j
      cases j with
      | zero =>
        rw [widePts_zero]
        exact hfirst
      | succ i =>
        have hi : i + 1 < S.wd it := hwd ▸ hj
        rw [widePts_succ]
        simp only [wideVals]
        rw [hnx]
        intro hmem
        obtain ⟨e', he'mem, he'1⟩ := List.mem_map.mp hmem
        obtain ⟨t', ht'⟩ := List.mem_iff_getElem?.mp he'mem
        rw [List.getElem?_take] at ht'
        split_ifs at ht' with htt'
        set f := stepItem S.cont it with hf
        have hc'' := C.chain_chainFrom H ((List.range (i + 1)).map f) τ' qs' hc'
        have hpre_items : S.items it = (List.range (i + 1)).map f
            ++ (List.range (S.wd it - (i + 1))).map (fun j => f (i + 1 + j)) := by
          rw [Steps.items, ← hf]
          conv_lhs => rw [show S.wd it = (i + 1) + (S.wd it - (i + 1)) by omega]
          rw [List.range_add, List.map_append, List.map_map]
          rfl
        have hpq : ∀ z ∈ OC.queries H (C.chainOCFrom (H C.start) τ' ((List.range (i + 1)).map f)),
            z ∈ OC.queries H (C.chainOCFrom (H C.start) τ' (S.items it)) := by
          intro z hz
          rw [hpre_items, C.chainOCFrom_queries_append]
          exact List.mem_append_left _ hz
        have hq''L : ∀ z ∈ qs' ++ OC.queries H (C.chainOCFrom (H C.start) τ' ((List.range (i + 1)).map f)),
            z ∈ L.map Prod.fst := by
          intro z hz
          rcases List.mem_append.mp hz with hz | hz
          · exact hq'L z hz
          · exact hstepL z (hpq z hz)
        have hlast : C.lastD H (C.chainFrom H τ' ((List.range (i + 1)).map f))
            = wideValsN H y (C.stepNx S it) i := by
          rw [C.chainFrom_stepPrefix, List.range_succ, List.map_append, List.map_cons, List.map_nil, Steps.ents,
            zipItems_snoc, ← List.append_assoc, ChainEnc.lastD_snoc]
        have hpt : e'.1 = C.link (C.lastD H (C.chainFrom H τ' ((List.range (i + 1)).map f))) (f (i + 1)) := by
          rw [he'1, hlast]
          rfl
        have hyq' : y ∈ qs' ++ OC.queries H (C.chainOCFrom (H C.start) τ' ((List.range (i + 1)).map f)) := by
          refine List.mem_append_right _ ?_
          rw [List.range_succ_eq_map, List.map_cons, ChainEnc.chainOCFrom, OC.queries_ask]
          exact List.mem_cons_self
        have hy' := C.chain_ordered H hL hg hc'' hq''L (f (i + 1)) ht' hpt y hyq'
        exact hfirst (mem_take_mono hy' htt'.le)
    · -- the run's digests are named by the log before it
      have hst1 := hstab H (L.take t) L τ' qs' [] hc' hs_le hord (List.take_prefix t L) hL
      rw [List.append_nil] at hst1
      have hvals : List.ofFn (wideVals H y (C.nxQ S y) (C.wdQ S y))
          = (List.range (S.wd it)).map (wideValsN H y (C.stepNx S it)) := by
        rw [ofFn_wideVals, hwd, hnx]
      have hst2 := hstab H (L.take t) L τ' qs' (S.ents it (List.ofFn (wideVals H y (C.nxQ S y) (C.wdQ S y))))
        hc' hs_le hord (List.take_prefix t L) hL
      rw [C.chainFrom_step] at hs'
      refine ⟨C.lastD H τ', it, τ', C.ldec_link _ _, htb, hs_le, ⟨hds.take s ++ pre, ?_⟩,
        fun h => hns' (hst1.mp h), hst2.mpr ?_⟩
      · rw [hτ'0, C.chainFrom_nil_map_fst]
      · rw [hvals]
        exact hs'
    · -- at a verifier's position, the traced-back chain is the verifier's own
      intro r hr d' it' τ'' hy' htb'
      rw [C.ldec_link, Option.some.injEq, Prod.mk.injEq] at hy'
      obtain ⟨rfl, rfl⟩ := hy'
      rw [htb, Option.some.injEq] at htb'
      subst htb'
      set LA := (A.runLog H).2 with hLA
      set LV := ((C.chainOC its).runLog H).2 with hLV
      have hLsplit : L = LA ++ LV := by
        rw [hLdef, hCmdef, ChainEnc.stepRun, OC.runLog_bind]
      -- the replay ends where the prover's log does
      have hrfull : A.replay L = some r := by
        have h := OC.replay_append_of_some A (L.take t) (L.drop t) r hr
        rwa [List.take_append_drop] at h
      have hrr : r = (A.run H, LA.length) := by
        rw [hLsplit, OC.replay_runLog_append] at hrfull
        exact (Option.some.inj hrfull).symm
      subst hrr
      have hkt : LA.length ≤ t := by
        have h := ZK60.OC.replay_le_length A (L.take t) _ hr
        rw [List.length_take] at h
        exact le_trans h (min_le_left _ _)
      -- the query at `t` is the verifier's, at its own position `t - |LA|`
      have hget : LV[t - LA.length]? = some (y, e2) := by
        rw [← List.getElem?_append_right hkt, ← hLsplit]
        exact ht
      have htlt : t - LA.length < LV.length := (List.getElem?_eq_some_iff.mp hget).1
      have hlenV : LV.length = its.length + 1 := C.chainOC_runLog_length H its
      obtain ⟨m, hm⟩ : ∃ m, t - LA.length = m + 1 := by
        rcases hj : t - LA.length with _ | m
        · exfalso
          have h0 : (LV[0]?).map Prod.fst = some C.start := C.chainOC_runLog_zero H its
          rw [← hj, hget, Option.map_some, Option.some.injEq] at h0
          exact C.link_ne_start _ _ h0
        · exact ⟨m, rfl⟩
      have hmlt : m < its.length := by omega
      -- the verifier's chain of its first `m` items
      set ρ := C.chainFrom H [] (its.take m) with hρ
      have hq := C.chainOC_runLog_succ H its m hmlt
      rw [← hLV, ← hm, hget, Option.map_some, Option.some.injEq] at hq
      have hq' : y = C.link (C.lastD H ρ) its[m] := by simpa using hq
      have hdig : C.lastD H τ' = C.lastD H ρ := by
        have h := C.ldec_link (C.lastD H τ') it
        rw [← hy, hq', C.ldec_link, Option.some.injEq, Prod.mk.injEq] at h
        exact h.1.symm
      have hcρ := C.chain_chainFrom H (its.take m) [] [C.start] ChainEnc.Chain.nil
      have hρq : ∀ z ∈ [C.start] ++ OC.queries H (C.chainOCFrom (H C.start) [] (its.take m)),
          z ∈ (L.take t).map Prod.fst := by
        intro z hz
        have h1 : z ∈ ((LV.take (m + 1)).map Prod.fst) := by
          rw [C.chainOC_runLog_take_fst H its m hmlt]
          simpa using hz
        have htake : L.take t = LA ++ LV.take (m + 1) := by
          rw [hLsplit, List.take_append, List.take_of_length_le (by omega), ← hm]
        rw [htake, List.map_append]
        exact List.mem_append_right _ h1
      have hρlen : ρ.length = m := by
        rw [hρ, C.chainFrom_length, List.length_nil, zero_add, List.length_take, min_eq_left hmlt.le]
      have htbρ := C.traceBack_chain H hPL hPnc hcρ hρq (ℓ - ρ.length)
      have hitsℓ : its.length ≤ ℓ := hℓ (A.run H)
      rw [show ρ.length + 1 + (ℓ - ρ.length) = ℓ + 1 by omega, ← hdig, htb,
        Option.some.injEq] at htbρ
      rw [htbρ]
      have hdrop : (L.take t).drop LA.length = LV.take (m + 1) := by
        rw [hLsplit, List.take_append, List.take_of_length_le (by omega), ← hm, List.drop_left' rfl]
      rw [hdrop, hLV, C.vChainOf_take H its m hmlt.le]
  calc prH (fun H => ¬ St (Cm.runLog H).2 (C.chainFrom H [] (((heads (A.run H)).take s).flatMap S.items))
        ∧ St (Cm.runLog H).2 (C.chainFrom H [] ((heads (A.run H)).flatMap S.items)))
      ≤ (PMF.uniformOfFintype (Q → D)).toOuterMeasure
          (({H | WideHit (C.wdQ S) (C.nxQ S) (C.posBad S St s ℓ A heads) H (Cm.runLog H).2}
            ∪ {H | ∃ a ∈ OC.queries H Cm, ∃ b ∈ OC.queries H Cm, a ≠ b ∧ H a = H b})
            ∪ {H | FreshHitQ C.chainTargets (Cm.runLog H).2}) := MeasureTheory.measure_mono hsub
    _ ≤ prH (fun H => WideHit (C.wdQ S) (C.nxQ S) (C.posBad S St s ℓ A heads) H (Cm.runLog H).2)
          + prH (fun H => ∃ a ∈ OC.queries H Cm, ∃ b ∈ OC.queries H Cm, a ≠ b ∧ H a = H b)
          + prH (fun H => FreshHitQ C.chainTargets (Cm.runLog H).2) :=
        (MeasureTheory.measure_union_le _ _).trans (add_le_add (MeasureTheory.measure_union_le _ _) le_rfl)
    _ ≤ _ := add_le_add (add_le_add hW hcoll) hgs

end SoundSeq

end ZK60.Sound
