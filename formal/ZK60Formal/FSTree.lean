/-
D63, step L3 (soundness): Fiat–Shamir on a TREE of chains (finding F26, the D55 fork-join).

`FSWide.lean`'s `chain_sound_wide` is about ONE chain. The D55 verifier hashes several: every fork's transcript is
rebuilt from the common state `S0` (`run_fork.rs`, `fork`), and the join continues from `S0` and absorbs the forks'
end states. Each of those transcripts is a chain from the start query; they share the trunk up to `S0` and then
diverge. This file proves the one-chain bound for any family of such chains, with ONE union over the hash queries,
not one per chain.

**Why the rate stays the maximum.** In `chain_sound_wide` the escaping step is found by tracing back the state digest
of its first query through the log before that query (`traceBack`). The trace-back of a digest is ONE path, so a query
names at most one branch and one round of it. The bad set charged to the query is that round's escape set; the
per-query rate is the largest error over all rounds of all branches, and the union over the branches happens at the
level of events, inside one `T·ε` bound.

**What is new: step widths read off the log.** A squeeze query is `state ‖ "squeeze" ‖ counter`. In D55 every branch
starts its squeezes at the same counter (`S0`'s), and the same counter starts a step of a DIFFERENT width in different
branches (a fork's `β, γ` is two squeezes, the join's first `λ, ρ` is `w0`). So a step's width is not a function of
the query alone, as `FSWide.lean`'s `Steps` needs; it is a function of the query and of the path its state digest
traces back to. Hence:
* `WideHitP`, `wideHitP_prob_le`: `FSWide.lean`'s wide-digest lemma with the width `wd P y` and the next queries
  `nx P y` read off the log `P` before the query. The swap of `wideSwap` is applied for each log prefix separately (the
  prefix is fixed by the swap, which only touches the step's own fresh queries), and the prefixes are summed.
* `stQ`, `wdT`, `nxT`, `stepBadT`: the branch's steps (`S b`, `b` read off the traced path by `br`), its width and next
  queries, and `FSWide.lean`'s `stepBad` with those steps. `stepBadT_prob_le`: its probability is at most `ε`.
* `flip_subset`: the event inclusion of `chain_sound_wide` for one chain of branch `b` whose queries are among those of
  ANY computation `Cm`: if its first `s` steps are doomed and the whole chain is not, then a wide hit, a collision or a
  guess occurs in `Cm`'s log.
* `tree_sound_wide`: **the theorem.** The prover, then a verifier `V` that hashes any family of chains (each from the
  start query, each of whole steps of its branch, computed from the prover's output AND from the oracle, so a join may
  absorb digests of the forks): the probability that SOME chain of the family flips is at most
  `T·ε + collBound T D + collBound (T + 1) D`, `T = q + v`, `v` the verifier's query budget. Cross-branch digest
  collisions are in `collBound T`, which covers every pair of queries of the whole run.
* `chainsOC`, `chainsOC_run`, `chainsOC_queries`, `chainsOC_bounded`: the verifier's hashing of several chains in turn.

**What it assumes** (premises): the branch of a path is fixed once its first `s` items are (`hbr`, for the verifier's
chains: the branch head is among the first `s` items); each branch's steps are `FSWide.lean`'s (distinct items in a
step, `link` injective). The protocol wrapper (branch heads, the readers, the fork and join transcripts of D55) is
`FSTreeRbr.lean`; the D55 instance at the 8B parameters is `FSTreeD55.lean`.
-/
import ZK60Formal.FSCompose
import ZK60Formal.FSOpening

set_option autoImplicit false

namespace ZK60.Sound

open scoped ENNReal
open Finset

/-! ## The wide-digest lemma with widths read off the log -/

section HitP

variable {Q D : Type}

/-- **A wide fresh hit, widths read off the log**: some entry asks, for the first time, a query `y` that starts a step
of `wd P y` digests (next queries `nx P y`), `P` the log before it; none of the step's queries was asked before it; and
the step's digests satisfy `Bad P y`. -/
def WideHitP (wd : List (Q × D) → Q → ℕ) (nx : List (Q × D) → Q → ℕ → D → Q)
    (Bad : List (Q × D) → Q → List D → Prop) (H : Q → D) (L : List (Q × D)) : Prop :=
  ∃ t e, L[t]? = some e ∧ e.1 ∉ (L.take t).map Prod.fst
    ∧ (∀ j, widePts e.1 (nx (L.take t) e.1) (wideVals H e.1 (nx (L.take t) e.1) (wd (L.take t) e.1)) j
        ∉ (L.take t).map Prod.fst)
    ∧ Bad (L.take t) e.1 (List.ofFn (wideVals H e.1 (nx (L.take t) e.1) (wd (L.take t) e.1)))

variable [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]

/-- **The wide-digest lemma, with widths read off the log.** For a computation making at most `T` queries, widths and
next queries computed from the log before the query, and a set `Bad` of probability at most `ε` for a uniform vector of
that width: a wide fresh hit has probability at most `T·ε`. -/
theorem wideHitP_prob_le {α : Type} (A : OC Q D α) (T : ℕ) (hA : A.Bounded T)
    (wd : List (Q × D) → Q → ℕ) (nx : List (Q × D) → Q → ℕ → D → Q)
    (hinj : ∀ P y (b : Fin (wd P y) → D), Function.Injective (widePts y (nx P y) b))
    (Bad : List (Q × D) → Q → List D → Prop) (ε : ℝ≥0∞)
    (hBad : ∀ P y, (PMF.uniformOfFintype (Fin (wd P y) → D)).toOuterMeasure {b | Bad P y (List.ofFn b)} ≤ ε) :
    prH (fun H => WideHitP wd nx Bad H (A.runLog H).2) ≤ (T : ℝ≥0∞) * ε := by
  classical
  set μ := (PMF.uniformOfFintype (Q → D)).toOuterMeasure
  let G : ℕ → Q → (Q → D) → Prop := fun t y H =>
    ∃ e, (A.runLog H).2[t]? = some e ∧ e.1 = y ∧ y ∉ ((A.runLog H).2.take t).map Prod.fst
  -- the event at position `t`, query `y` and log prefix `P₀`
  let W : ℕ → (y : Q) → (P₀ : List (Q × D)) → (Q → D) → (Fin (wd P₀ y) → D) → Prop := fun t y P₀ H b =>
    (G t y H ∧ (A.runLog H).2.take t = P₀) ∧ (∀ j, widePts y (nx P₀ y) b j ∉ P₀.map Prod.fst)
      ∧ Bad P₀ y (List.ofFn b)
  let E : ℕ → (Q → D) → Prop := fun t H => ∃ y, W t y ((A.runLog H).2.take t) H
    (wideVals H y (nx ((A.runLog H).2.take t) y) (wd ((A.runLog H).2.take t) y))
  have hsub : {H | WideHitP wd nx Bad H (A.runLog H).2} ⊆ ⋃ t ∈ range T, {H | E t H} := by
    intro H hH
    obtain ⟨t, e, h1, h2, h3, h4⟩ := hH
    have ht : t < (A.runLog H).2.length := (List.getElem?_eq_some_iff.mp h1).1
    simp only [Set.mem_iUnion, Set.mem_ofPred_eq, mem_range]
    exact ⟨t, lt_of_lt_of_le ht (OC.runLog_length_le H A T hA), e.1, ⟨⟨e, h1, rfl, h2⟩, rfl⟩, h3, h4⟩
  -- one position, one query, one log prefix: the bijection
  have hcount : ∀ t y P₀, ((univ.filter (fun H => W t y P₀ H (wideVals H y (nx P₀ y) (wd P₀ y)))).card : ℝ≥0∞)
      ≤ ε * (univ.filter (fun H => G t y H ∧ (A.runLog H).2.take t = P₀)).card := by
    intro t y P₀
    have hD0 : ((Fintype.card D ^ wd P₀ y : ℕ) : ℝ≥0∞) ≠ 0 := by
      have : Fintype.card D ^ wd P₀ y ≠ 0 := pow_ne_zero _ Fintype.card_ne_zero
      exact_mod_cast this
    have hDt : ((Fintype.card D ^ wd P₀ y : ℕ) : ℝ≥0∞) ≠ ⊤ := ENNReal.natCast_ne_top _
    have hinv : ∀ H, W t y P₀ H (wideVals H y (nx P₀ y) (wd P₀ y)) → ∀ e,
        W t y P₀ (Function.extend (widePts y (nx P₀ y) (wideVals H y (nx P₀ y) (wd P₀ y))) e H)
          (wideVals H y (nx P₀ y) (wd P₀ y)) := by
      intro H hW e
      obtain ⟨⟨⟨e₀, h1, h2, h3⟩, hP⟩, hpts, hbad⟩ := hW
      set H' := Function.extend (widePts y (nx P₀ y) (wideVals H y (nx P₀ y) (wd P₀ y))) e H
      have hagree : ∀ e' ∈ (A.runLog H).2.take t, H' e'.1 = H e'.1 := by
        intro e' he'
        refine Function.extend_apply' _ _ _ ?_
        rintro ⟨a, ha⟩
        have hmem : e'.1 ∈ P₀.map Prod.fst := by
          rw [← hP]
          exact List.mem_map_of_mem he'
        exact hpts a (ha ▸ hmem)
      have hag := OC.runLog_take_agree H H' A t hagree
      refine ⟨⟨?_, by rw [hag.1]; exact hP⟩, hpts, hbad⟩
      have hq : ((A.runLog H').2[t]?).map Prod.fst = some y := by
        rw [hag.2, h1]
        simp [h2]
      obtain ⟨e', he', he'1⟩ := Option.map_eq_some_iff.mp hq
      exact ⟨e', he', he'1, by rw [hag.1]; exact h3⟩
    have hA1 := wide_card_le y (nx P₀ y) (wd P₀ y) (hinj P₀ y) (W t y P₀) hinv
    have hslice : ∀ H, ((univ.filter (fun b : Fin (wd P₀ y) → D => W t y P₀ H b)).card : ℝ≥0∞)
        ≤ (if G t y H ∧ (A.runLog H).2.take t = P₀ then ε * ((Fintype.card D ^ wd P₀ y : ℕ) : ℝ≥0∞) else 0) := by
      intro H
      split_ifs with hG
      · have hb := hBad P₀ y
        rw [prob_uniform_eq_card (fun b : Fin (wd P₀ y) → D => Bad P₀ y (List.ofFn b)),
          ENNReal.div_le_iff (by exact_mod_cast Fintype.card_ne_zero) (ENNReal.natCast_ne_top _)] at hb
        refine le_trans ?_ (le_of_eq_of_le rfl (hb.trans (le_of_eq ?_)))
        · exact_mod_cast card_le_card (fun b hb' => by
            simp only [mem_filter, mem_univ, true_and] at hb' ⊢
            exact hb'.2.2)
        · rw [Fintype.card_fun, Fintype.card_fin]
      · have : univ.filter (fun b : Fin (wd P₀ y) → D => W t y P₀ H b) = ∅ :=
          filter_eq_empty_iff.mpr (fun b _ hb => hG hb.1)
        simp [this]
    have hB : ((univ.filter (fun p : (Q → D) × (Fin (wd P₀ y) → D) => W t y P₀ p.1 p.2)).card : ℝ≥0∞)
        ≤ ε * ((Fintype.card D ^ wd P₀ y : ℕ) : ℝ≥0∞)
          * (univ.filter (fun H => G t y H ∧ (A.runLog H).2.take t = P₀)).card := by
      rw [card_filter_prod (fun p : (Q → D) × (Fin (wd P₀ y) → D) => W t y P₀ p.1 p.2), Nat.cast_sum]
      calc ∑ H : Q → D, ((univ.filter (fun b : Fin (wd P₀ y) → D => W t y P₀ H b)).card : ℝ≥0∞)
          ≤ ∑ H : Q → D, (if G t y H ∧ (A.runLog H).2.take t = P₀
              then ε * ((Fintype.card D ^ wd P₀ y : ℕ) : ℝ≥0∞) else 0) :=
            sum_le_sum (fun H _ => hslice H)
        _ = ε * ((Fintype.card D ^ wd P₀ y : ℕ) : ℝ≥0∞)
              * (univ.filter (fun H => G t y H ∧ (A.runLog H).2.take t = P₀)).card := by
            rw [← sum_filter, sum_const, nsmul_eq_mul, mul_comm]
    have h2 : ((univ.filter (fun H => W t y P₀ H (wideVals H y (nx P₀ y) (wd P₀ y)))).card : ℝ≥0∞)
        * ((Fintype.card D ^ wd P₀ y : ℕ) : ℝ≥0∞)
        ≤ ε * (univ.filter (fun H => G t y H ∧ (A.runLog H).2.take t = P₀)).card
          * ((Fintype.card D ^ wd P₀ y : ℕ) : ℝ≥0∞) := by
      calc _ ≤ ((univ.filter (fun p : (Q → D) × (Fin (wd P₀ y) → D) => W t y P₀ p.1 p.2)).card : ℝ≥0∞) := by
            exact_mod_cast hA1
        _ ≤ _ := hB
        _ = _ := by ring
    exact (ENNReal.mul_le_mul_iff_left hD0 hDt).mp h2
  -- one position, one query: sum over the log prefixes
  have hfib : ∀ t y, ((univ.filter (fun H => W t y ((A.runLog H).2.take t) H
        (wideVals H y (nx ((A.runLog H).2.take t) y) (wd ((A.runLog H).2.take t) y)))).card : ℝ≥0∞)
      ≤ ε * (univ.filter (fun H => G t y H)).card := by
    intro t y
    set img := univ.image (fun H : Q → D => (A.runLog H).2.take t) with himg
    have hsub2 : univ.filter (fun H => W t y ((A.runLog H).2.take t) H
          (wideVals H y (nx ((A.runLog H).2.take t) y) (wd ((A.runLog H).2.take t) y)))
        ⊆ img.biUnion (fun P₀ => univ.filter (fun H => W t y P₀ H (wideVals H y (nx P₀ y) (wd P₀ y)))) := by
      intro H hH
      refine mem_biUnion.mpr ⟨(A.runLog H).2.take t, mem_image_of_mem _ (mem_univ H), ?_⟩
      simp only [mem_filter, mem_univ, true_and] at hH ⊢
      exact hH
    have hpart : (univ.filter (fun H => G t y H)).card
        = ∑ P₀ ∈ img, ((univ.filter (fun H => G t y H)).filter (fun H => (A.runLog H).2.take t = P₀)).card :=
      card_eq_sum_card_fiberwise (fun H _ => mem_image_of_mem _ (mem_univ H))
    simp only [filter_filter] at hpart
    calc ((univ.filter (fun H => W t y ((A.runLog H).2.take t) H
          (wideVals H y (nx ((A.runLog H).2.take t) y) (wd ((A.runLog H).2.take t) y)))).card : ℝ≥0∞)
        ≤ ∑ P₀ ∈ img, ((univ.filter (fun H => W t y P₀ H (wideVals H y (nx P₀ y) (wd P₀ y)))).card : ℝ≥0∞) := by
          exact_mod_cast (card_le_card hsub2).trans card_biUnion_le
      _ ≤ ∑ P₀ ∈ img, ε * ((univ.filter (fun H => G t y H ∧ (A.runLog H).2.take t = P₀)).card : ℝ≥0∞) :=
          sum_le_sum (fun P₀ _ => hcount t y P₀)
      _ = ε * (univ.filter (fun H => G t y H)).card := by
          rw [← mul_sum, hpart, Nat.cast_sum]
  -- the points named at one position are distinct
  have hdis : ∀ t, ∑ y, ((univ.filter (fun H => G t y H)).card : ℝ≥0∞) ≤ Fintype.card (Q → D) := by
    intro t
    have : ∑ y, (univ.filter (fun H => G t y H)).card ≤ Fintype.card (Q → D) := by
      simp only [card_filter]
      rw [sum_comm]
      calc ∑ H : Q → D, ∑ y : Q, (if G t y H then 1 else 0)
          = ∑ H : Q → D, (univ.filter (fun y => G t y H)).card := by simp only [card_filter]
        _ ≤ ∑ _H : Q → D, 1 := by
            refine sum_le_sum (fun H _ => ?_)
            rw [card_le_one]
            intro a ha b hb
            obtain ⟨e, h1, rfl, -⟩ := (mem_filter.mp ha).2
            obtain ⟨e', h1', rfl, -⟩ := (mem_filter.mp hb).2
            rw [h1] at h1'
            cases h1'
            rfl
        _ = Fintype.card (Q → D) := by simp
    exact_mod_cast this
  have hpos : ∀ t, μ {H | E t H} ≤ ε := by
    intro t
    have hΩ0 : (Fintype.card (Q → D) : ℝ≥0∞) ≠ 0 := by exact_mod_cast Fintype.card_ne_zero
    have hΩt : (Fintype.card (Q → D) : ℝ≥0∞) ≠ ⊤ := ENNReal.natCast_ne_top _
    rw [prob_uniform_eq_card (E t), ENNReal.div_le_iff hΩ0 hΩt]
    have hU : univ.filter (E t) ⊆ univ.biUnion (fun y => univ.filter (fun H => W t y ((A.runLog H).2.take t) H
        (wideVals H y (nx ((A.runLog H).2.take t) y) (wd ((A.runLog H).2.take t) y)))) := by
      intro H hH
      simp only [mem_filter, mem_univ, true_and] at hH
      obtain ⟨y, hy⟩ := hH
      exact mem_biUnion.mpr ⟨y, mem_univ _, mem_filter.mpr ⟨mem_univ _, hy⟩⟩
    calc ((univ.filter (E t)).card : ℝ≥0∞)
        ≤ ∑ y, ((univ.filter (fun H => W t y ((A.runLog H).2.take t) H
            (wideVals H y (nx ((A.runLog H).2.take t) y) (wd ((A.runLog H).2.take t) y)))).card : ℝ≥0∞) := by
          exact_mod_cast (card_le_card hU).trans card_biUnion_le
      _ ≤ ∑ y, ε * ((univ.filter (fun H => G t y H)).card : ℝ≥0∞) := sum_le_sum (fun y _ => hfib t y)
      _ = ε * ∑ y, ((univ.filter (fun H => G t y H)).card : ℝ≥0∞) := by rw [mul_sum]
      _ ≤ ε * Fintype.card (Q → D) := by gcongr; exact hdis t
  calc prH (fun H => WideHitP wd nx Bad H (A.runLog H).2)
      ≤ μ (⋃ t ∈ range T, {H | E t H}) := MeasureTheory.measure_mono hsub
    _ ≤ ∑ t ∈ range T, μ {H | E t H} := MeasureTheory.measure_biUnion_finset_le _ _
    _ ≤ ∑ _t ∈ range T, ε := sum_le_sum (fun t _ => hpos t)
    _ = (T : ℝ≥0∞) * ε := by rw [sum_const, card_range, nsmul_eq_mul]

end HitP

/-! ## Branch steps, read off the traced path -/

namespace ChainEnc

variable {It Q D B : Type} (C : ChainEnc It Q D)

variable [DecidableEq Q] [DecidableEq D]

/-- **The steps of the branch a query attacks**: decode the query as `link(d, it)`, trace `d` back through the log
`P` to a path `τ`, and take the steps of `τ`'s branch `br τ` (`S b₀` when the query is no link or nothing traces). -/
def stQ (S : B → Steps It) (br : List It → B) (b₀ : B) (ℓ : ℕ) (P : List (Q × D)) (y : Q) : Steps It :=
  match C.ldec y with
  | none => S b₀
  | some p =>
    match C.traceBack P (ℓ + 1) p.1 with
    | none => S b₀
    | some τ => S (br (τ.map Prod.fst))

/-- The width of the step a query starts, read off the log. -/
def wdT (S : B → Steps It) (br : List It → B) (b₀ : B) (ℓ : ℕ) (P : List (Q × D)) (y : Q) : ℕ :=
  C.wdQ (C.stQ S br b₀ ℓ P y) y

/-- The next queries of the step a query starts, read off the log. -/
def nxT (S : B → Steps It) (br : List It → B) (b₀ : B) (ℓ : ℕ) (P : List (Q × D)) (y : Q) : ℕ → D → Q :=
  C.nxQ (C.stQ S br b₀ ℓ P y) y

/-- **The set a query names**, with the steps of the branch it attacks: `FSWide.lean`'s `stepBad`. -/
def stepBadT (S : B → Steps It) (br : List It → B) (b₀ : B) (St : List (Q × D) → List (It × D) → Prop)
    (s ℓ : ℕ) (P : List (Q × D)) (y : Q) (ds : List D) : Prop :=
  C.stepBad (C.stQ S br b₀ ℓ P y) St s ℓ P y ds

/-- A query that links a digest tracing back to `τ` attacks `τ`'s branch. -/
theorem stQ_eq (S : B → Steps It) (br : List It → B) (b₀ : B) (ℓ : ℕ) (P : List (Q × D)) {y : Q} {d : D}
    {it : It} {τ : List (It × D)} (hy : C.ldec y = some (d, it)) (htb : C.traceBack P (ℓ + 1) d = some τ) :
    C.stQ S br b₀ ℓ P y = S (br (τ.map Prod.fst)) := by
  simp [stQ, hy, htb]

/-- **The named set has probability at most `ε`**: by the round hypothesis of the traced path's branch. -/
theorem stepBadT_prob_le [Fintype D] [Nonempty D] (S : B → Steps It) (br : List It → B) (b₀ : B)
    (St : List (Q × D) → List (It × D) → Prop) (s ℓ : ℕ) (ε : ℝ≥0∞)
    (hround : ∀ P τ it, s ≤ τ.length →
      (∃ hs : List It, τ.map Prod.fst = hs.flatMap (S (br (τ.map Prod.fst))).items) → ¬ St P τ →
      (PMF.uniformOfFintype (Fin ((S (br (τ.map Prod.fst))).wd it) → D)).toOuterMeasure
        {b | St P (τ ++ (S (br (τ.map Prod.fst))).ents it (List.ofFn b))} ≤ ε)
    (P : List (Q × D)) (y : Q) :
    (PMF.uniformOfFintype (Fin (C.wdT S br b₀ ℓ P y) → D)).toOuterMeasure
      {b | C.stepBadT S br b₀ St s ℓ P y (List.ofFn b)} ≤ ε := by
  have hempty : ∀ (k : ℕ) (E : Set (Fin k → D)), E = ∅ →
      (PMF.uniformOfFintype (Fin k → D)).toOuterMeasure E ≤ ε := by
    rintro k E rfl
    rw [MeasureTheory.measure_empty]
    exact zero_le
  unfold wdT stepBadT
  rcases hy : C.ldec y with _ | ⟨d, it⟩
  · refine hempty _ _ ?_
    ext b
    simp [stepBad, hy]
  · rcases htb : C.traceBack P (ℓ + 1) d with _ | τ
    · refine hempty _ _ ?_
      ext b
      simp only [stepBad, hy, Option.some.injEq, Prod.mk.injEq, Set.mem_ofPred_eq, Set.mem_empty_iff_false,
        iff_false, not_exists, not_and]
      rintro d' it' τ' ⟨rfl, rfl⟩ h2
      rw [htb] at h2
      cases h2
    · rw [C.stQ_eq S br b₀ ℓ P hy htb]
      set S' := S (br (τ.map Prod.fst)) with hS'
      by_cases hc : s ≤ τ.length ∧ (∃ hs : List It, τ.map Prod.fst = hs.flatMap S'.items) ∧ ¬ St P τ
      · have hw : C.wdQ S' y = S'.wd it := by simp [wdQ, hy]
        have hset : {b : Fin (C.wdQ S' y) → D | C.stepBad S' St s ℓ P y (List.ofFn b)}
            = {b | St P (τ ++ S'.ents it (List.ofFn b))} := by
          ext b
          simp only [stepBad, hy, Option.some.injEq, Prod.mk.injEq, Set.mem_ofPred_eq]
          constructor
          · rintro ⟨d', it', τ', ⟨rfl, rfl⟩, h2, -, -, -, h6⟩
            rw [htb] at h2
            cases h2
            exact h6
          · intro h
            exact ⟨d, it, τ, ⟨rfl, rfl⟩, htb, hc.1, hc.2.1, hc.2.2, h⟩
        rw [hset, prob_ofFn_congr hw (fun ds => St P (τ ++ S'.ents it ds))]
        exact hround P τ it hc.1 hc.2.1 hc.2.2
      · refine hempty _ _ ?_
        ext b
        simp only [stepBad, hy, Option.some.injEq, Prod.mk.injEq, Set.mem_ofPred_eq, Set.mem_empty_iff_false,
          iff_false, not_exists, not_and]
        rintro d' it' τ' ⟨rfl, rfl⟩ h2 h3 h4 h5 -
        rw [htb] at h2
        cases h2
        exact hc ⟨h3, h4, h5⟩

end ChainEnc

/-! ## One chain of a tree, inside any computation -/

section Flip

variable {It Q D B : Type} [DecidableEq Q] [DecidableEq D]

/-- **The event inclusion, for one chain of a tree.** A chain of branch `b` (heads `hds`, whole steps of `S b`) whose
queries are all asked by a computation `Cm`: if the chain of its first `s` heads is doomed and the whole chain is not
(states read with `Cm`'s log), then `Cm`'s log has a wide hit (widths and steps of the branch the query traces back
to), or a collision, or a guess. This is `chain_sound_wide`'s inclusion; the branch of the escaping step is read off
its traced path, which is the chain's own prefix (`hbr`). -/
theorem flip_subset (C : ChainEnc It Q D) (S : B → Steps It) (br : List It → B) (b₀ : B)
    (St : List (Q × D) → List (It × D) → Prop) (s ℓ : ℕ)
    (hstab : ∀ (H : Q → D) (P P' : List (Q × D)) (τ : List (It × D)) (qs : List Q) (ext : List (It × D)),
      C.Chain H τ qs → s ≤ τ.length → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' → (∀ e ∈ P', e.2 = H e.1) →
        (St P (τ ++ ext) ↔ St P' (τ ++ ext)))
    {β : Type} (Cm : OC Q D β) (H : Q → D) (b : B) (hds : List It)
    (hbr : ∀ its : List It, br ((hds.take s).flatMap (S b).items ++ its) = b)
    (hℓ : (hds.flatMap (S b).items).length ≤ ℓ)
    (hqV : ∀ y ∈ OC.queries H (C.chainOC (hds.flatMap (S b).items)), y ∈ OC.queries H Cm)
    (hns : ¬ St (Cm.runLog H).2 (C.chainFrom H [] ((hds.take s).flatMap (S b).items)))
    (hs : St (Cm.runLog H).2 (C.chainFrom H [] (hds.flatMap (S b).items))) :
    (WideHitP (C.wdT S br b₀ ℓ) (C.nxT S br b₀ ℓ) (C.stepBadT S br b₀ St s ℓ) H (Cm.runLog H).2
      ∨ ∃ a ∈ OC.queries H Cm, ∃ a' ∈ OC.queries H Cm, a ≠ a' ∧ H a = H a')
      ∨ FreshHitQ C.chainTargets (Cm.runLog H).2 := by
  classical
  by_cases hg : FreshHitQ C.chainTargets (Cm.runLog H).2
  · exact Or.inr hg
  by_cases hc : ∃ a ∈ OC.queries H Cm, ∃ a' ∈ OC.queries H Cm, a ≠ a' ∧ H a = H a'
  · exact Or.inl (Or.inr hc)
  refine Or.inl (Or.inl ?_)
  have hnc : ∀ a ∈ OC.queries H Cm, ∀ a' ∈ OC.queries H Cm, a ≠ a' → H a ≠ H a' := by
    intro a ha a' ha' hne hH
    exact hc ⟨a, ha, a', ha', hne, hH⟩
  set SB := S b with hSB
  set L := (Cm.runLog H).2 with hLdef
  have hL : ∀ e ∈ L, e.2 = H e.1 := OC.runLog_answer H Cm
  set its := hds.flatMap SB.items with hits
  -- the chain's queries are logged
  have hqL : ∀ y ∈ OC.queries H (C.chainOC its), y ∈ L.map Prod.fst := fun y hy => hqV y hy
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
      = C.chainFrom H (C.chainFrom H [] ((hds.take s).flatMap SB.items)) ((hds.drop s).flatMap SB.items) := by
    rw [← C.chainFrom_append, ← List.flatMap_append, List.take_append_drop]
  rw [hfull] at hs
  obtain ⟨pre, it, post, hpre, hns', hs'⟩ := C.chain_flip_steps SB H (St L) (hds.drop s) _ hns hs
  set τ' := C.chainFrom H (C.chainFrom H [] ((hds.take s).flatMap SB.items)) (pre.flatMap SB.items) with hτ'
  have hτ'0 : τ' = C.chainFrom H [] ((hds.take s ++ pre).flatMap SB.items) := by
    rw [hτ', List.flatMap_append, C.chainFrom_append]
  have hits_split : its = (hds.take s ++ pre).flatMap SB.items ++ (SB.items it ++ post.flatMap SB.items) := by
    rw [hits]
    conv_lhs => rw [← List.take_append_drop s hds, hpre]
    simp [List.flatMap_append, List.append_assoc]
  have hτ'len : τ'.length = ((hds.take s ++ pre).flatMap SB.items).length := by
    rw [hτ'0, C.chainFrom_length, List.length_nil, zero_add]
  have hs_le : s ≤ τ'.length := by
    rw [hτ'len]
    refine le_trans ?_ (SB.length_le_flatMap _)
    rw [List.length_append, hlen_hd]
    omega
  have hτ'ℓ : τ'.length + SB.wd it ≤ ℓ := by
    have h1 := hℓ
    rw [hits_split, List.length_append, List.length_append, SB.items_length] at h1
    omega
  -- the chain `τ'` and its queries
  have hc' := C.chain_chainFrom H ((hds.take s ++ pre).flatMap SB.items) [] [C.start] ChainEnc.Chain.nil
  rw [← hτ'0] at hc'
  set qs' := [C.start] ++ OC.queries H (C.chainOCFrom (H C.start) [] ((hds.take s ++ pre).flatMap SB.items))
    with hqs'
  have hqsplit : OC.queries H (C.chainOC its) = C.start ::
      (OC.queries H (C.chainOCFrom (H C.start) [] ((hds.take s ++ pre).flatMap SB.items))
        ++ (OC.queries H (C.chainOCFrom (H C.start) τ' (SB.items it))
          ++ OC.queries H (C.chainOCFrom (H C.start) (C.chainFrom H τ' (SB.items it)) (post.flatMap SB.items)))) := by
    rw [ChainEnc.chainOC, OC.queries_ask, hits_split, C.chainOCFrom_queries_append,
      C.chainOCFrom_queries_append, ← hτ'0]
  have hq'L : ∀ z ∈ qs', z ∈ L.map Prod.fst := by
    intro z hz
    refine hqL z ?_
    rw [hqsplit]
    rcases List.mem_append.mp hz with hz | hz
    · rw [List.mem_singleton] at hz
      rw [hz]
      exact List.mem_cons_self
    · exact List.mem_cons_of_mem _ (List.mem_append_left _ hz)
  have hstepL : ∀ z ∈ OC.queries H (C.chainOCFrom (H C.start) τ' (SB.items it)), z ∈ L.map Prod.fst := by
    intro z hz
    refine hqL z ?_
    rw [hqsplit]
    exact List.mem_cons_of_mem _ (List.mem_append_right _ (List.mem_append_left _ hz))
  -- the step's first query and its first occurrence
  set y := C.link (C.lastD H τ') it with hy
  obtain ⟨rest, hrest⟩ := SB.items_cons it
  have hyq : y ∈ OC.queries H (C.chainOCFrom (H C.start) τ' (SB.items it)) := by
    rw [hrest, ChainEnc.chainOCFrom, OC.queries_ask]
    exact List.mem_cons_self
  obtain ⟨t, ⟨e1, e2⟩, ht, he, hfirst⟩ := exists_first (hstepL y hyq)
  simp only at he
  subst he
  have hPL : ∀ e ∈ L.take t, e.2 = H e.1 := fun e he => hL e (List.mem_of_mem_take he)
  have hPnc : ∀ a ∈ (L.take t).map Prod.fst, ∀ a' ∈ (L.take t).map Prod.fst, a ≠ a' → H a ≠ H a' := by
    intro a ha a' ha'
    exact hnc a (mem_of_mem_take_map ha) a' (mem_of_mem_take_map ha')
  have hord : ∀ z ∈ qs', z ∈ (L.take t).map Prod.fst := C.chain_ordered H hL hg hc' hq'L it ht rfl
  -- the trace-back recovers `τ'`, so the query attacks branch `b`
  have htb := C.traceBack_chain H hPL hPnc hc' hord (ℓ - τ'.length)
  rw [show τ'.length + 1 + (ℓ - τ'.length) = ℓ + 1 by omega] at htb
  have hτ'map : τ'.map Prod.fst = (hds.take s).flatMap SB.items ++ pre.flatMap SB.items := by
    rw [hτ'0, C.chainFrom_nil_map_fst, List.flatMap_append]
  have hbrτ : br (τ'.map Prod.fst) = b := by
    rw [hτ'map]
    exact hbr _
  have hstQ : C.stQ S br b₀ ℓ (L.take t) y = SB := by
    rw [C.stQ_eq S br b₀ ℓ (L.take t) (C.ldec_link _ _) htb, hbrτ]
  have hwd : C.wdT S br b₀ ℓ (L.take t) y = SB.wd it := by
    rw [ChainEnc.wdT, hstQ]
    exact C.wdQ_link SB _ it
  have hnx : C.nxT S br b₀ ℓ (L.take t) y = C.stepNx SB it := by
    rw [ChainEnc.nxT, hstQ]
    exact C.nxQ_link SB _ it
  refine ⟨t, (y, e2), ht, hfirst, ?_, ?_⟩
  · -- the later queries of the step were not asked before its first one
    intro j
    obtain ⟨j, hj⟩ := j
    cases j with
    | zero =>
      rw [widePts_zero]
      exact hfirst
    | succ i =>
      have hi : i + 1 < SB.wd it := hwd ▸ hj
      rw [widePts_succ]
      simp only [wideVals]
      rw [hnx]
      intro hmem
      obtain ⟨e', he'mem, he'1⟩ := List.mem_map.mp hmem
      obtain ⟨t', ht'⟩ := List.mem_iff_getElem?.mp he'mem
      rw [List.getElem?_take] at ht'
      split_ifs at ht' with htt'
      set f := stepItem SB.cont it with hf
      have hc'' := C.chain_chainFrom H ((List.range (i + 1)).map f) τ' qs' hc'
      have hpre_items : SB.items it = (List.range (i + 1)).map f
          ++ (List.range (SB.wd it - (i + 1))).map (fun j => f (i + 1 + j)) := by
        rw [Steps.items, ← hf]
        conv_lhs => rw [show SB.wd it = (i + 1) + (SB.wd it - (i + 1)) by omega]
        rw [List.range_add, List.map_append, List.map_map]
        rfl
      have hpq : ∀ z ∈ OC.queries H (C.chainOCFrom (H C.start) τ' ((List.range (i + 1)).map f)),
          z ∈ OC.queries H (C.chainOCFrom (H C.start) τ' (SB.items it)) := by
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
          = wideValsN H y (C.stepNx SB it) i := by
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
  · -- the step's digests are named by the log before it
    have hst1 := hstab H (L.take t) L τ' qs' [] hc' hs_le hord (List.take_prefix t L) hL
    rw [List.append_nil] at hst1
    have hvals : List.ofFn (wideVals H y (C.nxT S br b₀ ℓ (L.take t) y) (C.wdT S br b₀ ℓ (L.take t) y))
        = (List.range (SB.wd it)).map (wideValsN H y (C.stepNx SB it)) := by
      rw [ofFn_wideVals, hwd, hnx]
    have hst2 := hstab H (L.take t) L τ' qs'
      (SB.ents it (List.ofFn (wideVals H y (C.nxT S br b₀ ℓ (L.take t) y) (C.wdT S br b₀ ℓ (L.take t) y))))
      hc' hs_le hord (List.take_prefix t L) hL
    rw [C.chainFrom_step] at hs'
    show C.stepBad (C.stQ S br b₀ ℓ (L.take t) y) St s ℓ (L.take t) y _
    rw [hstQ]
    refine ⟨C.lastD H τ', it, τ', C.ldec_link _ _, htb, hs_le, ⟨hds.take s ++ pre, ?_⟩,
      fun h => hns' (hst1.mp h), hst2.mpr ?_⟩
    · rw [hτ'0, C.chainFrom_nil_map_fst]
    · rw [hvals]
      exact hs'

end Flip

/-! ## The tree theorem -/

section Tree

variable {It Q D B : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D]

/-- **Fiat–Shamir soundness on a tree of chains.** A prover making at most `q` hash queries, then a verifier `V` making
at most `v`, which hashes a family of chains: each `(b, hs)` of `chains H o` is a chain from the start query of the
heads `hs`, expanded by branch `b`'s steps `S b`; the family may depend on the oracle (a join's heads carry digests of
the forks). Let `St` be a state on chains (it may read the log, `hstab` as in `chain_sound_wide`) such that from every
doomed path of at least `s` items, whole steps of its own branch (`br`), a uniform vector of the next step's width
escapes doom with probability at most `ε`. If each chain's branch is fixed by its first `s` heads (`hbr`), the
probability that SOME chain of the family is doomed at its first `s` heads and not doomed at its end is at most
`T·ε + collBound T D + collBound (T + 1) D`, `T = q + v`: one union over the queries, whatever the number of chains. -/
theorem tree_sound_wide (C : ChainEnc It Q D) (S : B → Steps It) (br : List It → B) (b₀ : B)
    (St : List (Q × D) → List (It × D) → Prop) (s : ℕ) (ε : ℝ≥0∞)
    (hround : ∀ P τ it, s ≤ τ.length →
      (∃ hs : List It, τ.map Prod.fst = hs.flatMap (S (br (τ.map Prod.fst))).items) → ¬ St P τ →
      (PMF.uniformOfFintype (Fin ((S (br (τ.map Prod.fst))).wd it) → D)).toOuterMeasure
        {b | St P (τ ++ (S (br (τ.map Prod.fst))).ents it (List.ofFn b))} ≤ ε)
    (hstab : ∀ (H : Q → D) (P P' : List (Q × D)) (τ : List (It × D)) (qs : List Q) (ext : List (It × D)),
      C.Chain H τ qs → s ≤ τ.length → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' → (∀ e ∈ P', e.2 = H e.1) →
        (St P (τ ++ ext) ↔ St P' (τ ++ ext)))
    {α β : Type} (V : α → OC Q D β) (v : ℕ) (hV : ∀ o, (V o).Bounded v)
    (chains : (Q → D) → α → List (B × List It)) (ℓ : ℕ)
    (hℓ : ∀ H o, ∀ c ∈ chains H o, (c.2.flatMap (S c.1).items).length ≤ ℓ)
    (hbr : ∀ H o, ∀ c ∈ chains H o, ∀ its : List It, br ((c.2.take s).flatMap (S c.1).items ++ its) = c.1)
    (hqV : ∀ H o, ∀ c ∈ chains H o, ∀ y ∈ OC.queries H (C.chainOC (c.2.flatMap (S c.1).items)),
      y ∈ OC.queries H (V o))
    (q : ℕ) (A : OC Q D α) (hA : A.Bounded q) :
    prH (fun H => ∃ c ∈ chains H (A.run H),
        ¬ St ((A.bind V).runLog H).2 (C.chainFrom H [] ((c.2.take s).flatMap (S c.1).items))
        ∧ St ((A.bind V).runLog H).2 (C.chainFrom H [] (c.2.flatMap (S c.1).items)))
      ≤ ((q + v : ℕ) : ℝ≥0∞) * ε + collBound (q + v) D + collBound (q + v + 1) D := by
  classical
  set T := q + v with hT
  set Cm := A.bind V with hCmdef
  have hCm : Cm.Bounded T := hA.bind hV
  have hW := wideHitP_prob_le Cm T hCm (C.wdT S br b₀ ℓ) (C.nxT S br b₀ ℓ)
    (fun P y b => C.widePts_injective (C.stQ S br b₀ ℓ P y) y b) (C.stepBadT S br b₀ St s ℓ) ε
    (fun P y => C.stepBadT_prob_le S br b₀ St s ℓ ε hround P y)
  have hcoll := collision_prob_le Cm T hCm
  have hgs := freshHitQ_prob_le_gen Cm T hCm C.chainTargets (fun t => t + 1) (fun P y => C.chainTargets_card P y)
  have hsum : ∀ n : ℕ, ∑ t ∈ range n, (t + 1) = (n + 1) * (n + 1 - 1) / 2 := by
    intro n
    rw [← Finset.sum_range_id (n + 1)]
    simp [Finset.sum_range_succ']
  rw [hsum T] at hgs
  have hsub : {H : Q → D | ∃ c ∈ chains H (A.run H),
        ¬ St (Cm.runLog H).2 (C.chainFrom H [] ((c.2.take s).flatMap (S c.1).items))
        ∧ St (Cm.runLog H).2 (C.chainFrom H [] (c.2.flatMap (S c.1).items))}
      ⊆ ({H | WideHitP (C.wdT S br b₀ ℓ) (C.nxT S br b₀ ℓ) (C.stepBadT S br b₀ St s ℓ) H (Cm.runLog H).2}
          ∪ {H | ∃ a ∈ OC.queries H Cm, ∃ a' ∈ OC.queries H Cm, a ≠ a' ∧ H a = H a'})
        ∪ {H | FreshHitQ C.chainTargets (Cm.runLog H).2} := by
    rintro H ⟨c, hcm, hns, hs⟩
    have hq : ∀ y ∈ OC.queries H (C.chainOC (c.2.flatMap (S c.1).items)), y ∈ OC.queries H Cm := by
      intro y hy
      rw [hCmdef, OC.queries_bind]
      exact List.mem_append_right _ (hqV H _ c hcm y hy)
    exact flip_subset C S br b₀ St s ℓ hstab Cm H c.1 c.2 (hbr H _ c hcm) (hℓ H _ c hcm) hq hns hs
  calc prH (fun H => ∃ c ∈ chains H (A.run H),
        ¬ St (Cm.runLog H).2 (C.chainFrom H [] ((c.2.take s).flatMap (S c.1).items))
        ∧ St (Cm.runLog H).2 (C.chainFrom H [] (c.2.flatMap (S c.1).items)))
      ≤ (PMF.uniformOfFintype (Q → D)).toOuterMeasure
          (({H | WideHitP (C.wdT S br b₀ ℓ) (C.nxT S br b₀ ℓ) (C.stepBadT S br b₀ St s ℓ) H (Cm.runLog H).2}
            ∪ {H | ∃ a ∈ OC.queries H Cm, ∃ a' ∈ OC.queries H Cm, a ≠ a' ∧ H a = H a'})
            ∪ {H | FreshHitQ C.chainTargets (Cm.runLog H).2}) := MeasureTheory.measure_mono hsub
    _ ≤ prH (fun H => WideHitP (C.wdT S br b₀ ℓ) (C.nxT S br b₀ ℓ) (C.stepBadT S br b₀ St s ℓ) H (Cm.runLog H).2)
          + prH (fun H => ∃ a ∈ OC.queries H Cm, ∃ a' ∈ OC.queries H Cm, a ≠ a' ∧ H a = H a')
          + prH (fun H => FreshHitQ C.chainTargets (Cm.runLog H).2) :=
        (MeasureTheory.measure_union_le _ _).trans (add_le_add (MeasureTheory.measure_union_le _ _) le_rfl)
    _ ≤ _ := add_le_add (add_le_add hW hcoll) hgs

end Tree

/-! ## The verifier's hashing of several chains -/

namespace ChainEnc

variable {It Q D : Type} (C : ChainEnc It Q D)

/-- **Several chains, one after the other**, each hashed from the start query. -/
def chainsOC : List (List It) → OC Q D (List (List (It × D)))
  | [] => .ret []
  | its :: rest => (C.chainOC its).bind (fun τ => (chainsOC rest).bind (fun τs => .ret (τ :: τs)))

/-- The hashing of several chains computes each chain. -/
theorem chainsOC_run (H : Q → D) : ∀ ls : List (List It), (C.chainsOC ls).run H = ls.map (C.chainFrom H [])
  | [] => rfl
  | its :: rest => by
    simp only [chainsOC, OC.run_bind, C.chainOC_run, chainsOC_run H rest, List.map_cons]
    rfl

/-- Every chain's queries are among the queries of the hashing of the family. -/
theorem chainsOC_queries (H : Q → D) : ∀ (ls : List (List It)), ∀ its ∈ ls,
    ∀ y ∈ OC.queries H (C.chainOC its), y ∈ OC.queries H (C.chainsOC ls)
  | [], its, h, _, _ => absurd h List.not_mem_nil
  | its' :: rest, its, h, y, hy => by
    simp only [chainsOC, OC.queries_bind]
    rcases List.mem_cons.mp h with rfl | h
    · exact List.mem_append_left _ hy
    · exact List.mem_append_right _ (List.mem_append_left _ (chainsOC_queries H rest its h y hy))

/-- The hashing of several chains asks, for each, its items and the start query. -/
theorem chainsOC_bounded : ∀ ls : List (List It), (C.chainsOC ls).Bounded ((ls.map (fun its => its.length + 1)).sum)
  | [] => trivial
  | its :: rest => by
    rw [chainsOC, List.map_cons, List.sum_cons]
    refine (C.chainOC_bounded its).bind (fun τ => ?_)
    have := (chainsOC_bounded rest).bind
      (fun τs => (show (OC.ret (τ :: τs) : OC Q D (List (List (It × D)))).Bounded 0 from trivial))
    simpa using this

end ChainEnc

end ZK60.Sound
