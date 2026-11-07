/-
D63 lane L16 (2026-11-07), part 5: **the knowledge versions of `M`'s rounds and of the openings' Merkle layer on the
code's chain** (finding L10-6 (a) for `M` and the openings; ASSEMBLY §4.2 item a's extraction failure term).

* `maskCSubX`, `maskCSubX_rbr`: L10's `maskCSub` whose statement IS the committed data (`MData`), read off the header by
  any `xOf`: the data may be EXTRACTED from the prover's log. Round-by-round sound with L10's error `maskEps ≤ 2^-106`
  (`maskCSub_rbr`'s argument, the data any function of the header).
* **`mask_knowledge_chain`**: `M`'s three rounds on the code's chain with the mask rows and functionals extracted from
  the prover's log (any extraction frozen once the chain's first `s` entries are logged): the probability that `M`
  enters its window with its claim FALSE of the extracted data (`¬ MGood`: some functional false of the decoded rows,
  or the rows far from the code) and yet `M` is alive at the end is at most
  `(q + ℓ + 1)·maskEps + collBound T + collBound (T + 1)`, for any step parse `W` and steps (L8-3).
* `extNamedR`, `extNamedR_card`, `sum_range_four_mul_add_le`, **`extract_fail_run`**: `FSOpening.lean`'s
  `opening_extract_fail` for ANY run (a prover, then any verifier computation) and any number of roots: an opened column
  that verifies against a root the prover output, whose queries the run asked, but that is not the column extracted
  from the prover's log cut at that root's first absorption, has probability at most
  `collBound T + (2T² + (1 + nr)·T)/|D|`. With the code's chain (`absOfC`, `digOf?`): `cutAt_absD` identifies the cut
  with `ExtractW16Slots.lean`'s byte cut.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.ExtractW16Slots
import ZK60Formal.ExecOpeningFS
import ZK60Formal.SoundExtract

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal
open Polynomial Finset

/-! ## `M` with extracted data -/

section MaskX

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K)

/-- **`M` as a sub-protocol whose data is the statement** (L10's `maskCSub` with `X = MData` and the data read off the
header by `xOf`; `xOf` may read the prover's log). -/
noncomputable def maskCSubX (eF : ZMod gP × ZMod gP ≃ K) (dom : Fin (2 ^ 12) ↪ K) (ω : K) {σ κ : Type} [Fintype σ]
    [Fintype κ] [DecidableEq κ] {k : ℕ} (S : ℕ) (a : ℕ) (xOf : List (TItem × Dig) → MData K (Fin (2 ^ 12)) σ κ k 512)
    (eR : κ ≃ Fin (2 * S + 2)) (rel : List (TItem × Dig) → Prop) : CSub Dig :=
  toCSub a (maskRounds S) (maskEps (K := K) k S)
    (maskStCode gP eF dom ω 1024 1023 (id : MData K (Fin (2 ^ 12)) σ κ k 512 → MData K (Fin (2 ^ 12)) σ κ k 512) dg0
      eR (m2 := 64) (nQ := 256) (by norm_num)) xOf (decPoly U 1024) rel

/-- `M` with extracted data is round-by-round sound with `maskEps` (`≤ 2^-106`, `maskEps_le`). -/
theorem maskCSubX_rbr (eF : ZMod gP × ZMod gP ≃ K) (dom : Fin (2 ^ 12) ↪ K) {ω : K} (hω : IsPrimitiveRoot ω 512)
    {σ κ : Type} [Fintype σ] [Fintype κ] [DecidableEq κ] {k : ℕ} (hk : 0 < k) (S : ℕ) (a : ℕ)
    (xOf : List (TItem × Dig) → MData K (Fin (2 ^ 12)) σ κ k 512) (eR : κ ≃ Fin (2 * S + 2))
    (rel : List (TItem × Dig) → Prop) :
    RbrWide (maskCSubX U eF dom ω S a xOf eR rel).R.n (maskCSubX U eF dom ω S a xOf eR rel).R.w
      (maskCSubX U eF dom ω S a xOf eR rel).St (maskCSubX U eF dom ω S a xOf eR rel).ε :=
  rbrWide_toCode a (maskRounds S) _ _ xOf (decPoly U 1024) rel
    (mask_rbrWide_code gP eF (h := 12) (by norm_num) dom hk (by norm_num) hω (e := 1024) (K := 1023) (dd := 1534)
      (by simp only [Fintype.card_fin]; norm_num) (by norm_num) (by norm_num) id dg0 eR (m2 := 64) (nQ := 256)
      (by norm_num))

omit [DecidableEq K] in
/-- `M`'s state at its window is `MGood` of its data. -/
theorem maskCSubX_St_nil (eF : ZMod gP × ZMod gP ≃ K) (dom : Fin (2 ^ 12) ↪ K) (ω : K) {σ κ : Type} [Fintype σ]
    [Fintype κ] [DecidableEq κ] {k : ℕ} (S : ℕ) (a : ℕ) (xOf : List (TItem × Dig) → MData K (Fin (2 ^ 12)) σ κ k 512)
    (eR : κ ≃ Fin (2 * S + 2)) (rel : List (TItem × Dig) → Prop) (hdr : List (TItem × Dig)) :
    (maskCSubX U eF dom ω S a xOf eR rel).St hdr []
      ↔ MGood dom ω 1 1024 1023 (xOf hdr).wt (xOf hdr).val (xOf hdr).Ub (xOf hdr).u (xOf hdr).La (xOf hdr).Lb :=
  Iff.rfl

/-- A one-sub-protocol schedule's combined state is the sub-protocol's. -/
theorem allSt_singleton {D : Type} (W : UInt64 → ℕ) (c : CSub D) (τ : List (TItem × D)) :
    allSt W [c] τ ↔ subSt W c τ := by
  constructor
  · intro h
    exact h 0 c rfl
  · intro h k c' hc
    have hm := List.mem_of_getElem? hc
    rw [List.mem_singleton] at hm
    subst hm
    exact h

/-- `M`'s schedule at the prover's log recovered from a log. -/
noncomputable def maskCsAt (eF : ZMod gP × ZMod gP ≃ K) (dom : Fin (2 ^ 12) ↪ K) (ω : K) {σ κ : Type} [Fintype σ]
    [Fintype κ] [DecidableEq κ] {k : ℕ} (S : ℕ) (a : ℕ) {L : ℕ}
    (Dm : List (QB L × Dig) → List (TItem × Dig) → MData K (Fin (2 ^ 12)) σ κ k 512) (eR : κ ≃ Fin (2 * S + 2))
    {α : Type} (A : OC (QB L) Dig α) (P : List (QB L × Dig)) : List (CSub Dig) :=
  [maskCSubX U eF dom ω S a (Dm (proverLog A P)) eR (fun _ => False)]

/-- **`M`'s rounds with the EXTRACTED data, on the code's chain** (the knowledge version of L10's `maskCSub_rbr` in a
schedule). For any extraction `Dm` of `M`'s data (mask rows, functionals) from the prover's log, frozen once the chain's
first `s` entries are logged, `M`'s window at `a > s`: the probability that `M` enters its window with its claim false
of the extracted data and is alive at the end is at most `(q + ℓ + 1)·maskEps + collBound T + collBound (T + 1)`. -/
theorem mask_knowledge_chain (eF : ZMod gP × ZMod gP ≃ K) (dom : Fin (2 ^ 12) ↪ K) {ω : K}
    (hω : IsPrimitiveRoot ω 512) {σ κ : Type} [Fintype σ] [Fintype κ] [DecidableEq κ] {k : ℕ} (hk : 0 < k) (S : ℕ)
    (a : ℕ) {L : ℕ} (Dm : List (QB L × Dig) → List (TItem × Dig) → MData K (Fin (2 ^ 12)) σ κ k 512)
    (eR : κ ≃ Fin (2 * S + 2)) (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) {It' : Type} (C : ChainEnc It' (QB L) Dig)
    (toT : It' → TItem) (St : Steps It') (hS : StepsOK W toT St) {α : Type} (heads : α → List It') (ℓ : ℕ)
    (hℓ : ∀ o, ((heads o).flatMap St.items).length ≤ ℓ) (s : ℕ) (hsa : s < a)
    (hhd : ∀ o, (((heads o).take s).flatMap St.items).length ≤ s) (q : ℕ) (A : OC (QB L) Dig α) (hA : A.Bounded q)
    (hstab : ∀ (H : QB L → Dig) (P P' : List (QB L × Dig)) (τ : List (It' × Dig)) (qs : List (QB L)),
      C.Chain H τ qs → τ.length = s → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' → (∀ e ∈ P', e.2 = H e.1) →
        ∀ ext : List (TItem × Dig), Dm (proverLog A P) ((τ.map (toTE toT) ++ ext).take a)
          = Dm (proverLog A P') ((τ.map (toTE toT) ++ ext).take a)) :
    prH (fun H => (a ≤ (cChain C toT St H (heads (A.run H))).length
          ∧ tRem W ((cChain C toT St H (heads (A.run H))).take a) = some 0
          ∧ ¬ MGood dom ω 1 1024 1023
              (Dm (A.runLog H).2 ((cChain C toT St H (heads (A.run H))).take a)).wt
              (Dm (A.runLog H).2 ((cChain C toT St H (heads (A.run H))).take a)).val
              (Dm (A.runLog H).2 ((cChain C toT St H (heads (A.run H))).take a)).Ub
              (Dm (A.runLog H).2 ((cChain C toT St H (heads (A.run H))).take a)).u
              (Dm (A.runLog H).2 ((cChain C toT St H (heads (A.run H))).take a)).La
              (Dm (A.runLog H).2 ((cChain C toT St H (heads (A.run H))).take a)).Lb)
        ∧ subSt W (maskCSubX U eF dom ω S a (Dm (A.runLog H).2) eR (fun _ => False))
            (cChain C toT St H (heads (A.run H))))
      ≤ ((q + ℓ + 1 : ℕ) : ℝ≥0∞) * maskEps (K := K) k S + collBound (q + ℓ + 1) Dig
        + collBound (q + ℓ + 1 + 1) Dig := by
  have hfull : ∀ H, proverLog A ((C.stepRun St heads A).runLog H).2 = (A.runLog H).2 := fun H => by
    rw [ChainEnc.stepRun, OC.runLog_bind]
    exact proverLog_runLog A H _
  have hmem : ∀ P c, c ∈ maskCsAt U eF dom ω S a Dm eR A P →
      c = maskCSubX U eF dom ω S a (Dm (proverLog A P)) eR (fun _ => False) := by
    intro P c hc
    exact List.mem_singleton.mp hc
  have hmain := fs_code_chain_sound_sched_log W hW (maskCsAt U eF dom ω S a Dm eR A) (maskEps (K := K) k S)
    (fun P c hc => by
      rw [hmem P c hc]
      exact maskCSubX_rbr U eF dom hω hk S a _ eR _)
    (fun P c hc => by
      rw [hmem P c hc]
      exact le_rfl)
    (fun P k' c τ h ks ds hc _ _ _ _ hrel => by
      have hc' := hmem P c (List.mem_of_getElem? hc)
      rw [hc'] at hrel
      exact absurd hrel id)
    C toT St hS heads ℓ hℓ s
    (fun P c hc => by
      rw [hmem P c hc]
      exact hsa) hhd
    (fun H P P' τ qs hc hl hq hpre hans ext => by
      rw [maskCsAt, maskCsAt, allSt_singleton, allSt_singleton]
      refine subSt_congr W _ _ _ rfl rfl Iff.rfl ?_
      have he := hstab H P P' τ qs hc hl hq hpre hans ext
      simp only [maskCSubX, toCSub, he]) q A hA
  refine le_trans (MeasureTheory.measure_mono ?_) hmain
  intro H hH
  rw [Set.mem_ofPred_eq] at hH ⊢
  rw [maskCsAt, hfull H, allSt_singleton]
  obtain ⟨⟨h1, h2, h3⟩, h4⟩ := hH
  exact ⟨⟨0, _, rfl, h1, h2, h3, id⟩, h4⟩

end MaskX

/-! ## The Merkle extraction in any run -/

/-- `Σ_{t < n} (4t + c) ≤ 2n² + c·n`. -/
theorem sum_range_four_mul_add_le (c : ℕ) : ∀ n : ℕ, ∑ t ∈ range n, (4 * t + c) ≤ 2 * n * n + c * n
  | 0 => by simp
  | n + 1 => by
    rw [sum_range_succ]
    have ih := sum_range_four_mul_add_le c n
    nlinarith [ih]

section ExtractRun

variable {Q D S Col : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D]

/-- **The digests a run's log names for the extractor**: every Merkle child or leaf content of a logged question,
every root a logged question (or the query itself) absorbs, and the roots the replayed prover outputs. -/
def extNamedR (M : MerkleEnc Q D S Col) (absOf : Q → Option D) {α : Type} (A : OC Q D α) (rootsOf : α → List D)
    (P : List (Q × D)) (y : Q) : Finset D :=
  (P.map Prod.fst).toFinset.biUnion (fun y' => M.nodeKids y' ∪ M.leafKid y' ∪ (absOf y').toFinset)
    ∪ (absOf y).toFinset ∪ ((A.replay P).map (fun r => (rootsOf r.1).toFinset)).getD ∅

omit [Fintype Q] [Fintype D] [Nonempty D] in
/-- At most `4|P| + 1 + nr` digests. -/
theorem extNamedR_card (M : MerkleEnc Q D S Col) (absOf : Q → Option D) {α : Type} (A : OC Q D α)
    (rootsOf : α → List D) (nr : ℕ) (hnr : ∀ a, (rootsOf a).length ≤ nr) (P : List (Q × D)) (y : Q) :
    (extNamedR M absOf A rootsOf P y).card ≤ 4 * P.length + (1 + nr) := by
  unfold extNamedR
  have hk : ∀ y', (M.nodeKids y' ∪ M.leafKid y' ∪ (absOf y').toFinset).card ≤ 4 := by
    intro y'
    have h1 : (M.nodeKids y').card ≤ 2 := by
      unfold MerkleEnc.nodeKids
      split
      · exact card_le_two
      · simp
    have h2 : (M.leafKid y').card ≤ 1 := by
      unfold MerkleEnc.leafKid
      split
      · simp
      · simp
    have h3 := ChainEnc.option_card_toFinset_le (absOf y')
    refine (card_union_le _ _).trans ?_
    have := card_union_le (M.nodeKids y') (M.leafKid y')
    omega
  have hb : ((P.map Prod.fst).toFinset.biUnion
      (fun y' => M.nodeKids y' ∪ M.leafKid y' ∪ (absOf y').toFinset)).card ≤ 4 * P.length := by
    refine card_biUnion_le.trans ?_
    calc ∑ y' ∈ (P.map Prod.fst).toFinset, (M.nodeKids y' ∪ M.leafKid y' ∪ (absOf y').toFinset).card
        ≤ ∑ _y' ∈ (P.map Prod.fst).toFinset, 4 := sum_le_sum (fun y' _ => hk y')
      _ = 4 * (P.map Prod.fst).toFinset.card := by rw [sum_const, smul_eq_mul, mul_comm]
      _ ≤ 4 * P.length := Nat.mul_le_mul_left _ ((List.toFinset_card_le _).trans (by simp))
  have h4 := ChainEnc.option_card_toFinset_le (absOf y)
  have h5 : (((A.replay P).map (fun r => (rootsOf r.1).toFinset)).getD ∅).card ≤ nr := by
    rcases A.replay P with _ | r
    · simp
    · simp only [Option.map_some, Option.getD_some]
      exact (List.toFinset_card_le _).trans (hnr _)
  refine (card_union_le _ _).trans ?_
  have := card_union_le ((P.map Prod.fst).toFinset.biUnion
      (fun y' => M.nodeKids y' ∪ M.leafKid y' ∪ (absOf y').toFinset)) (absOf y).toFinset
  omega

/-- **The extraction fails rarely, in ANY run** (`opening_extract_fail` for a prover followed by any verifier
computation `V`, and several roots). An opening that verifies at some position against one of the roots the prover
output, all of whose queries the run asked, but whose column is not the one extracted from the prover's log cut at
that root's first absorption (`cutAt absOf`), has probability at most `collBound T D + (2T² + (1 + nr)·T)/|D|`, `T`
the run's queries, `nr` the number of roots. -/
theorem extract_fail_run (M : MerkleEnc Q D S Col) (absOf : Q → Option D) {α β : Type} (A : OC Q D α)
    (rootsOf : α → List D) (nr : ℕ) (hnr : ∀ a, (rootsOf a).length ≤ nr) (V : α → OC Q D β) (T : ℕ)
    (hCm : (A.bind V).Bounded T) :
    prH (fun H => ∃ r ∈ rootsOf (A.run H), ∃ (h j : ℕ) (o : MerkleOpening D S Col), M.Opens H h r j o
        ∧ (∀ v ∈ M.openQs H j o, v ∈ OC.queries H (A.bind V))
        ∧ M.extractCol (cutAt absOf r (A.runLog H).2) h j r ≠ some o.col)
      ≤ collBound T D + ((2 * T * T + (1 + nr) * T : ℕ) : ℝ≥0∞) / Fintype.card D := by
  classical
  set Cm := A.bind V with hCmdef
  set FX : List (Q × D) → Q → Finset D := extNamedR M absOf A rootsOf with hFX
  have hcoll := collision_prob_le Cm T hCm
  have hfr := freshHitQ_prob_le_gen Cm T hCm FX (fun t => 4 * t + (1 + nr))
    (fun P y => extNamedR_card M absOf A rootsOf nr hnr P y)
  have hfr' : prH (fun H => FreshHitQ FX (Cm.runLog H).2)
      ≤ ((2 * T * T + (1 + nr) * T : ℕ) : ℝ≥0∞) / Fintype.card D :=
    hfr.trans (ENNReal.div_le_div_right (Nat.cast_le.mpr (sum_range_four_mul_add_le (1 + nr) T)) _)
  refine le_trans (MeasureTheory.measure_mono ?_) ((MeasureTheory.measure_union_le _ _).trans
    (add_le_add hcoll hfr'))
  rintro H ⟨r, hr, h, j, o, hop, hv, hne⟩
  set Lp := (A.runLog H).2 with hLp
  set Lc := cutAt absOf r Lp with hLcdef
  obtain ⟨Lr, hLr⟩ : ∃ Lr, (Cm.runLog H).2 = Lp ++ Lr := ⟨_, OC.runLog_bind H A V⟩
  have hLpQ : ∀ y ∈ Lp.map Prod.fst, y ∈ OC.queries H Cm := by
    intro y hy
    show y ∈ (Cm.runLog H).2.map Prod.fst
    rw [hLr, List.map_append]
    exact List.mem_append_left _ hy
  have hLcA : ∀ e ∈ Lc, e.2 = H e.1 := fun e he => OC.runLog_answer H A e (List.mem_of_mem_take he)
  rcases M.extract_of_opens H Lc hLcA r hop with hext | ⟨v, hvq, hb⟩
  · exact absurd hext hne
  rcases hb with ⟨y, hy, hyv, hHy⟩ | ⟨hvL, hvT⟩
  · left
    have hyLp : y ∈ Lp.map Prod.fst := by
      obtain ⟨e', he', rfl⟩ := List.mem_map.mp hy
      exact List.mem_map_of_mem (List.mem_of_mem_take he')
    exact ⟨y, hLpQ y hyLp, v, hv v hvq, hyv, hHy⟩
  · right
    have hvC : v ∈ (Cm.runLog H).2.map Prod.fst := hv v hvq
    refine freshHitQ_of_first H (OC.runLog_answer H Cm) FX hvC (fun t e ht he hfirst => ?_)
    set c := Lp.findIdx (isAbsAt absOf r) with hc
    have hLc : Lc = Lp.take c := rfl
    have hsplit : (Cm.runLog H).2 = Lc ++ (Lp.drop c ++ Lr) := by
      rw [hLr, hLc, ← List.append_assoc, List.take_append_drop]
    have htc : Lc.length ≤ t := first_after_prefix hvL (by rw [← hsplit]; exact ht) he
    have hpre : Lc <+: (Cm.runLog H).2.take t := by
      rw [hsplit, List.take_append, List.take_of_length_le htc]
      exact List.prefix_append _ _
    rw [MerkleEnc.targets, Finset.mem_insert] at hvT
    rcases hvT with hvr | hvb
    · rw [hvr]
      by_cases hcl : c < Lp.length
      · have hpc : isAbsAt absOf r (Lp[c]'hcl) = true := List.findIdx_getElem
        have hra : absOf (Lp[c]'hcl).1 = some r := by simpa [isAbsAt] using hpc
        have hLclen : Lc.length = c := by rw [hLc, List.length_take, min_eq_left hcl.le]
        have hLc_c : (Cm.runLog H).2[c]? = some (Lp[c]'hcl) := by
          rw [hLr, List.getElem?_append_left hcl, List.getElem?_eq_getElem hcl]
        rcases Nat.lt_or_ge c t with hlt | hge
        · have hmem : (Lp[c]'hcl).1 ∈ ((Cm.runLog H).2.take t).map Prod.fst := mem_take_of_getElem? hLc_c hlt
          refine mem_union_left _ (mem_union_left _ (mem_biUnion.mpr ⟨_, List.mem_toFinset.mpr hmem, ?_⟩))
          refine mem_union_right _ ?_
          rw [hra]
          simp
        · have htc' : t = c := le_antisymm hge (hLclen ▸ htc)
          rw [htc'] at ht
          have hee : e = Lp[c]'hcl := Option.some.inj (ht.symm.trans hLc_c)
          refine mem_union_left _ (mem_union_right _ ?_)
          rw [← he, hee, hra]
          simp
      · have hcl' : c = Lp.length := le_antisymm List.findIdx_le_length (not_lt.mp hcl)
        have hLcLp : Lc = Lp := by rw [hLc, hcl', List.take_length]
        have htLp : Lp.length ≤ t := hLcLp ▸ htc
        have hrep : A.replay ((Cm.runLog H).2.take t) = some (A.run H, Lp.length) := by
          rw [hLr, List.take_append, List.take_of_length_le htLp]
          exact OC.replay_runLog_append H A _
        refine mem_union_right _ ?_
        rw [hrep]
        simp [hr]
    · obtain ⟨y', hy', hvy'⟩ := mem_biUnion.mp hvb
      have hy'P : y' ∈ ((Cm.runLog H).2.take t).map Prod.fst := by
        obtain ⟨e', he', rfl⟩ := List.mem_map.mp (List.mem_toFinset.mp hy')
        exact List.mem_map_of_mem (hpre.subset he')
      exact mem_union_left _ (mem_union_left _ (mem_biUnion.mpr ⟨y', List.mem_toFinset.mpr hy'P,
        mem_union_left _ hvy'⟩))

end ExtractRun

/-! ## The code's chain: the digest cut is the byte cut -/

theorem bind_digOf_eq_iff (o : Option (List UInt8)) (r : Dig) : o.bind digOf? = some r ↔ o = some r.toList := by
  cases o with
  | none => simp
  | some x =>
    simp only [Option.bind_some, Option.some.injEq]
    constructor
    · intro h
      unfold digOf? at h
      split at h
      · cases h
        rfl
      · cases h
    · rintro rfl
      exact digOf?_toList r

/-- **The digest a query absorbs**, on a chain encoding of the code's items: its absorbed bytes as a 32-byte digest. -/
def absD {L : ℕ} {Q : Type} (C : ChainEnc (ItB L) Q Dig) (y : Q) : Option Dig := (Block.absOfC C y).bind digOf?

/-- The cut at a digest's first absorption is the cut at its bytes' (`ExtractW16Slots.lean`'s `cuts3`). -/
theorem cutAt_absD {L : ℕ} {Q : Type} (C : ChainEnc (ItB L) Q Dig) (r : Dig) (P : List (Q × Dig)) :
    cutAt (absD C) r P = cutAt (Block.absOfC C) r.toList P := by
  have hp : isAbsAt (absD C) r = (isAbsAt (Block.absOfC C) r.toList : Q × Dig → Bool) := by
    funext e
    unfold isAbsAt absD
    exact decide_eq_decide.mpr (bind_digOf_eq_iff _ r)
  unfold cutAt
  rw [hp]

end ZK60.Exec
