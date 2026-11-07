/-
D63 lane L24 (2026-11-07), part 1: **the sharper Fiat–Shamir count with a charge that reads the PROVER's log**, the
generic step the first-doom count (`ZoneCodeFirst.lean`) needs.

`FSPathWide.lean`'s `chain_sound_wide_seq` charges the prover's queries the largest error `εmax` and each of the
verifier's own steps `e τ it`, a function of the verifier's chain `τ` before the step. For the run-level count the
charge of a verifier step must follow ONE doom, and which doom that is depends on the data extracted from the prover's
log (which block's claim is false of the extracted planes). The proof of `chain_sound_wide_seq` already allows it: the
wide-hit lemma it rests on (`wideHit_prob_le_pos`) names its bound by the log before each position, and at a verifier
position the prover's log is the replay's own entries. This file carries that through:

* `posErrL`, `posErrL_le`: the position charge, `εmax` at a prover's position and `e (P.take r.2) τ it` at the
  verifier's (`P.take r.2` the prover's log, `r` the replay);
* `posBad_prob_le_L`: the named set has probability at most that charge, given the round bound with the charge read at
  `proverLog A P`;
* `posErr_sum_le_L`: along the run the charges sum to at most `q·εmax` plus the verifier's charge read at the prover's
  whole log `(A.runLog H).2`;
* **`chain_sound_wide_seq_L`**: `chain_sound_wide_seq` with that charge and with the WEAK stability `hstabW` (the state
  at the log before the escaping step's first query agrees with the state at the whole log, on that chain and that
  step: what the proof uses). The strong `hstab` (every extension) fails for a run whose later blocks absorb their
  roots after earlier blocks' windows (finding L24-2); `hstabW_of_hstab` derives the weak form from it where it holds.

The proofs of `posBad_prob_le_L`, `posErr_sum_le_L` and `chain_sound_wide_seq_L` are those of `FSPathWide.lean`, line for
line, with the charge's extra argument and the two stability uses replaced. Only `propext`, `Classical.choice`,
`Quot.sound`.
-/
import ZK60Formal.FSPathWide

set_option autoImplicit false

namespace ZK60.Sound

open scoped ENNReal
open Finset

namespace ChainEnc

variable {It Q D : Type} (C : ChainEnc It Q D)

/-- **The charge at a position, reading the prover's log**: `εmax` at a prover's position; at the verifier's, the
error of its step from its own chain, read with the prover's log (`P.take r.2`, the replay's own entries). -/
def posErrL (S : Steps It) (e : List (Q × D) → List (It × D) → It → ℝ≥0∞) (εmax : ℝ≥0∞) {α : Type} (A : OC Q D α)
    (heads : α → List It) (P : List (Q × D)) (y : Q) : ℝ≥0∞ :=
  match A.replay P with
  | none => εmax
  | some r =>
    match C.ldec y with
    | none => 0
    | some p => e (P.take r.2) (vChainOf ((heads r.1).flatMap S.items) (P.drop r.2)) p.2

/-- The charge never exceeds `εmax`. -/
theorem posErrL_le (S : Steps It) (e : List (Q × D) → List (It × D) → It → ℝ≥0∞) (εmax : ℝ≥0∞)
    (he : ∀ P τ it, e P τ it ≤ εmax)
    {α : Type} (A : OC Q D α) (heads : α → List It) (P : List (Q × D)) (y : Q) :
    C.posErrL S e εmax A heads P y ≤ εmax := by
  unfold posErrL
  split
  · exact le_rfl
  · split
    · exact zero_le
    · exact he _ _ _

variable [DecidableEq Q] [DecidableEq D]

/-- **The named set has probability at most the charge** read with the prover's log. -/
theorem posBad_prob_le_L [Fintype D] [Nonempty D] (S : Steps It) (St : List (Q × D) → List (It × D) → Prop)
    (s ℓ : ℕ) (e : List (Q × D) → List (It × D) → It → ℝ≥0∞) (εmax : ℝ≥0∞) (he : ∀ P τ it, e P τ it ≤ εmax)
    {α : Type} (A : OC Q D α)
    (hround : ∀ P τ it, s ≤ τ.length → (∃ hs : List It, τ.map Prod.fst = hs.flatMap S.items) → ¬ St P τ →
      (PMF.uniformOfFintype (Fin (S.wd it) → D)).toOuterMeasure {b | St P (τ ++ S.ents it (List.ofFn b))}
        ≤ e (proverLog A P) τ it)
    (heads : α → List It) (P : List (Q × D)) (y : Q) :
    (PMF.uniformOfFintype (Fin (C.wdQ S y) → D)).toOuterMeasure
        {b | C.posBad S St s ℓ A heads P y (List.ofFn b)} ≤ C.posErrL S e εmax A heads P y := by
  have hempty : ∀ (E : Set (Fin (C.wdQ S y) → D)), (∀ b, b ∉ E) →
      (PMF.uniformOfFintype (Fin (C.wdQ S y) → D)).toOuterMeasure E ≤ C.posErrL S e εmax A heads P y := by
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
            {b | St P (τ ++ S.ents it (List.ofFn b))} ≤ e (proverLog A P) τ it := by
          rw [prob_ofFn_congr hw (fun ds => St P (τ ++ S.ents it ds))]
          exact hround P τ it hc.1 hc.2.1 hc.2.2
        rcases hr : A.replay P with _ | r
        · have hf : C.posErrL S e εmax A heads P y = εmax := by simp [posErrL, hr]
          rw [hf]
          exact (MeasureTheory.measure_mono hsub).trans (hμ.trans (he _ τ it))
        · have hf : C.posErrL S e εmax A heads P y
              = e (P.take r.2) (vChainOf ((heads r.1).flatMap S.items) (P.drop r.2)) it := by
            simp [posErrL, hr, hy]
          have hpl : proverLog A P = P.take r.2 := by simp [proverLog, hr]
          rw [hpl] at hμ
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

/-! ## The chain with per-step errors read off the prover's log -/

section SoundSeqL

variable {It Q D : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D]

omit [Fintype Q] [Fintype D] [Nonempty D] [DecidableEq Q] [DecidableEq D] in
/-- **The charges along the run sum to at most `q·εmax` plus the verifier's charge**, the verifier's read with the
prover's log: the prover's positions are at most `q`, each charged at most `εmax`; the verifier's position `m + 1` is
charged its item `m` at its own chain and the prover's whole log. -/
theorem posErr_sum_le_L (C : ChainEnc It Q D) (S : Steps It) (e : List (Q × D) → List (It × D) → It → ℝ≥0∞)
    (εmax : ℝ≥0∞) (he : ∀ P τ it, e P τ it ≤ εmax) {α : Type} (heads : α → List It) (ℓ : ℕ)
    (hℓ : ∀ o, ((heads o).flatMap S.items).length ≤ ℓ) (q : ℕ) (A : OC Q D α) (hA : A.Bounded q)
    (H : Q → D) :
    ∑ t ∈ range (q + ℓ + 1), gpos (C.posErrL S e εmax A heads) ((C.stepRun S heads A).runLog H).2 t
      ≤ (q : ℝ≥0∞) * εmax + C.vSumFrom (e (A.runLog H).2) H [] ((heads (A.run H)).flatMap S.items) := by
  set its := (heads (A.run H)).flatMap S.items with hits
  set LA := (A.runLog H).2 with hLA
  set LV := ((C.chainOC its).runLog H).2 with hLV
  set k := LA.length with hk
  set g := gpos (C.posErrL S e εmax A heads) ((C.stepRun S heads A).runLog H).2 with hg
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
    · exact C.posErrL_le S e εmax he A heads _ _
    · exact zero_le
  -- a verifier's position
  have hgV : ∀ t, g (k + t) = match LV[t]? with
      | some en => (match C.ldec en.1 with
          | none => 0
          | some p => e LA (ChainEnc.vChainOf its (LV.take t)) p.2)
      | none => 0 := by
    intro t
    have hrep : A.replay (LA ++ LV.take t) = some (A.run H, k) := OC.replay_runLog_append H A _
    have htake : (LA ++ LV).take (k + t) = LA ++ LV.take t := by
      rw [List.take_append, List.take_of_length_le (by omega), show k + t - LA.length = t by omega]
    have hget : (LA ++ LV)[k + t]? = LV[t]? := by
      rw [List.getElem?_append_right (by omega), show k + t - LA.length = t by omega]
    have hdrop : (LA ++ LV.take t).drop k = LV.take t := List.drop_left' rfl
    have htk : (LA ++ LV.take t).take k = LA := List.take_left' rfl
    simp only [hg, gpos, hL, hget, htake]
    rcases LV[t]? with _ | en
    · rfl
    · simp only [ChainEnc.posErrL, hrep, hdrop, htk]
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
  have hgS : ∀ m, g (k + (m + 1)) = C.vPos (e LA) H [] its m := by
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
    _ ≤ (q : ℝ≥0∞) * εmax + C.vSumFrom (e LA) H [] its := by
        refine add_le_add (mul_le_mul' (by exact_mod_cast hkq) le_rfl) (le_of_eq ?_)
        rw [show q + ℓ + 1 = (q + ℓ) + 1 from rfl, Finset.sum_range_succ', hg0, add_zero]
        rw [← C.vSumFrom_eq_sum (e LA) H [] its (q + ℓ) (by omega)]
        exact sum_congr rfl (fun m _ => hgS m)

/-- **Fiat–Shamir soundness on the code's chain with per-step errors read off the PROVER's log** (D63 lane L24;
`chain_sound_wide_seq` with two changes). Let `St P τ` be a state on chains (it may read the log `P`) such that from a
doomed chain of whole steps (at least `s` items), for every next head `it`, a uniform vector of `wd it` digests escapes
doom with probability at most `e (proverLog A P) τ it ≤ εmax`: the step's error may depend on the prover's own log
(recovered by replay), not only on the chain. And the state at the log before the escaping step's first query agrees
with the state at the whole log on that chain and that step (`hstabW`, the weak form of `hstab`: only where the proof
uses it). A prover making at most `q` hash queries outputs heads; the verifier hashes every step of them (at most `ℓ`
items), and its own chain, charged with the prover's log, is at most `B` (`hB`). The probability that the chain of the
first `s` heads is doomed while the whole chain is not is at most `q·εmax + B + collBound T D + collBound (T + 1) D`,
`T = q + ℓ + 1`. -/
theorem chain_sound_wide_seq_L (C : ChainEnc It Q D) (S : Steps It) (St : List (Q × D) → List (It × D) → Prop)
    (s : ℕ) (e : List (Q × D) → List (It × D) → It → ℝ≥0∞) (εmax : ℝ≥0∞) (he : ∀ P τ it, e P τ it ≤ εmax)
    {α : Type} (A : OC Q D α)
    (hround : ∀ P τ it, s ≤ τ.length → (∃ hs : List It, τ.map Prod.fst = hs.flatMap S.items) → ¬ St P τ →
      (PMF.uniformOfFintype (Fin (S.wd it) → D)).toOuterMeasure {b | St P (τ ++ S.ents it (List.ofFn b))}
        ≤ e (proverLog A P) τ it)
    (hstabW : ∀ (H : Q → D) (L : List (Q × D)) (t : ℕ) (τ : List (It × D)) (qs : List Q) (it : It) (e2 : D),
      C.Chain H τ qs → s ≤ τ.length → (∃ hs : List It, τ.map Prod.fst = hs.flatMap S.items) →
      (∀ z ∈ qs, z ∈ (L.take t).map Prod.fst) → (∀ e ∈ L, e.2 = H e.1) →
      L[t]? = some (C.link (C.lastD H τ) it, e2) → C.link (C.lastD H τ) it ∉ (L.take t).map Prod.fst →
        (St (L.take t) τ ↔ St L τ) ∧ ∀ ds : List D, (St (L.take t) (τ ++ S.ents it ds) ↔ St L (τ ++ S.ents it ds)))
    (heads : α → List It) (ℓ : ℕ) (hℓ : ∀ o, ((heads o).flatMap S.items).length ≤ ℓ)
    (B : ℝ≥0∞) (hB : ∀ H : Q → D, C.vSumFrom (e (A.runLog H).2) H [] ((heads (A.run H)).flatMap S.items) ≤ B)
    (q : ℕ) (hA : A.Bounded q) :
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
    (C.posBad S St s ℓ A heads) (C.posErrL S e εmax A heads)
    (fun P y => C.posBad_prob_le_L S St s ℓ e εmax he A hround heads P y) ((q : ℝ≥0∞) * εmax + B)
    (fun H => (posErr_sum_le_L C S e εmax he heads ℓ hℓ q A hA H).trans (add_le_add le_rfl (hB H)))
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
      have hwh : ∃ hs : List It, τ'.map Prod.fst = hs.flatMap S.items :=
        ⟨hds.take s ++ pre, by rw [hτ'0, C.chainFrom_nil_map_fst]⟩
      have hstW := hstabW H L t τ' qs' it e2 hc' hs_le hwh hord hL ht hfirst
      have hst1 := hstW.1
      have hvals : List.ofFn (wideVals H y (C.nxQ S y) (C.wdQ S y))
          = (List.range (S.wd it)).map (wideValsN H y (C.stepNx S it)) := by
        rw [ofFn_wideVals, hwd, hnx]
      have hst2 := hstW.2 (List.ofFn (wideVals H y (C.nxQ S y) (C.wdQ S y)))
      rw [C.chainFrom_step] at hs'
      refine ⟨C.lastD H τ', it, τ', C.ldec_link _ _, htb, hs_le, hwh, fun h => hns' (hst1.mp h), hst2.mpr ?_⟩
      rw [hvals]
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

omit [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D] in
/-- **The usual stability gives the weak form**: where a longer log never changes a logged chain's state, on any
extension (`chain_sound_wide_seq`'s `hstab`), the weak form `hstabW` of `chain_sound_wide_seq_L` holds. -/
theorem hstabW_of_hstab (C : ChainEnc It Q D) (S : Steps It) (St : List (Q × D) → List (It × D) → Prop) (s : ℕ)
    (hstab : ∀ (H : Q → D) (P P' : List (Q × D)) (τ : List (It × D)) (qs : List Q) (ext : List (It × D)),
      C.Chain H τ qs → s ≤ τ.length → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' → (∀ e ∈ P', e.2 = H e.1) →
        (St P (τ ++ ext) ↔ St P' (τ ++ ext))) :
    ∀ (H : Q → D) (L : List (Q × D)) (t : ℕ) (τ : List (It × D)) (qs : List Q) (it : It) (e2 : D),
      C.Chain H τ qs → s ≤ τ.length → (∃ hs : List It, τ.map Prod.fst = hs.flatMap S.items) →
      (∀ z ∈ qs, z ∈ (L.take t).map Prod.fst) → (∀ e ∈ L, e.2 = H e.1) →
      L[t]? = some (C.link (C.lastD H τ) it, e2) → C.link (C.lastD H τ) it ∉ (L.take t).map Prod.fst →
        (St (L.take t) τ ↔ St L τ) ∧ ∀ ds : List D, (St (L.take t) (τ ++ S.ents it ds) ↔ St L (τ ++ S.ents it ds)) := by
  intro H L t τ qs it e2 hc hs _ hq hL _ _
  refine ⟨?_, fun ds => hstab H (L.take t) L τ qs (S.ents it ds) hc hs hq (List.take_prefix t L) hL⟩
  have h := hstab H (L.take t) L τ qs [] hc hs hq (List.take_prefix t L) hL
  rw [List.append_nil] at h
  exact h

end SoundSeqL

end ZK60.Sound
