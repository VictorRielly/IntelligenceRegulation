/-
D63, step L3 (soundness): vector challenges on the code's hash chain (the "wide digest" lemma, finding F19).

The code draws a vector challenge as several back-to-back squeezes with no absorb between them:
* `challenge_fp2_vec(n)` (`zkp_core::transcript`) is `n` calls of `challenge_fp2`, one squeeze each. It draws `λ`
  and `ρ` (`pcs.rs:952-973`, `zk_rhos`), `M`'s weights and the batching vectors;
* `challenge_indices(n, bound)` squeezes `⌈n/4⌉` times (four 8-byte chunks per squeeze): the column indices `J`;
* LogUp's `β, γ, α` are three `challenge_fp2` calls in a row (`protocol.rs:2005-2007` of the `gpu-metal` tree).
Each squeeze hashes the previous state with a counter, `D_{j+1} = H(D_j ‖ "squeeze" ‖ counter)`, so the whole vector
is a deterministic function of the state before the first squeeze. `FSChain.lean` handles one digest per step;
this file handles a STEP of `k` digests.

**The lemma.** A step is started by an item `it` and continued by forced items (`Steps`: for a squeeze `sq c` of a
`k`-wide challenge, `sq (c + 1)`, …, `sq (c + k − 1)`). Its queries are `y = link(d, it)`, then
`link(D_j, cont it j)`: each names the previous digest. Run the trace-back of `FSChain.lean` at the FIRST occurrence
of `y`: unless a collision or a guess occurs (the chain's own two terms), none of the step's later queries has been
asked yet, so the step's `k` digests are `k` fresh answers. They are then jointly uniform on `D^k`, whatever the
prover did before, and a set named by the log before `y` is hit with probability at most its share of `D^k`.
The per-step bound is the WIDE challenge's own bound, not a bound per squeeze.

**What is proved.**
* `wideSwap`, `wide_card_le`: the counting core. Fix the start query `y`; rewriting `H` along the step's own queries
  (`Function.extend`) is a bijection of `(Q → D) × D^k` that exchanges "the step's digests" with "a free `k`-tuple".
* `wideHit_prob_le`: in an adaptive run of at most `T` queries, the probability that some query `y`, at its first
  occurrence, starts a step whose later queries are all new and whose `k` digests land in a set named by the log
  before `y` (of probability at most `ε` under a uniform `k`-tuple), is at most `T·ε`.
* `chain_sound_wide`: `FSChain.lean`'s `chain_sound` for steps. The prover outputs step heads; the verifier hashes
  every step in full. If from every doomed chain (of at least `s` items, made of whole steps) a uniform `k`-tuple of
  digests for the next step escapes doom with probability at most `ε`, then a `q`-query prover makes a chain whose
  first `s` steps are doomed end up not doomed with probability at most `T·ε + collBound T D + collBound (T + 1) D`,
  `T = q + ℓ + 1` (`ℓ` bounds the verifier's items). One-digest steps give back `chain_sound` (`k = 1`).
* The state function may READ THE LOG (`St P τ`): that is what knowledge soundness needs, where the state speaks
  about a matrix extracted from the log. The hypothesis `hstab` asks that, once a chain of at least `s` items has all
  its queries logged, longer logs do not change the state of it or of its extensions (the extraction is frozen once
  the root is absorbed). A state function that ignores the log satisfies it trivially.

**What the model takes from the code.** The items of one step must be distinct (`Steps.distinct`; the squeeze
counters `c, c + 1, …` are), and `link` injective with a left inverse, as in `FSChain.lean`. The protocol wrapper
(rounds with messages, widths and counters) is `FSWideRbr.lean`.
-/
import ZK60Formal.FSChainRbr
import ZK60Formal.SoundOpeningRO

namespace ZK60.Sound

open scoped ENNReal
open Finset

section Run

variable {Q D : Type}

/-- The digests of a step started by the query `y`: the first is `H y`, the `(j + 1)`-th is the answer to `nx j` of the `j`-th (for the chain, `nx j d = link(d, item j + 1)`). -/
def wideValsN (H : Q → D) (y : Q) (nx : ℕ → D → Q) : ℕ → D
  | 0 => H y
  | j + 1 => H (nx j (wideValsN H y nx j))

/-- The first `k` digests of the step, as a vector. -/
def wideVals (H : Q → D) (y : Q) (nx : ℕ → D → Q) (k : ℕ) : Fin k → D := fun j => wideValsN H y nx j

/-- The queries of a step whose digests are `b`: `y`, then `nx j (b j)`. -/
def widePts (y : Q) (nx : ℕ → D → Q) {k : ℕ} (b : Fin k → D) (j : Fin k) : Q :=
  if (j : ℕ) = 0 then y else nx ((j : ℕ) - 1) (b ⟨(j : ℕ) - 1, lt_of_le_of_lt (Nat.sub_le _ _) j.isLt⟩)

/-- The first query of a step is its start query. -/
theorem widePts_zero (y : Q) (nx : ℕ → D → Q) {k : ℕ} (b : Fin k → D) (h0 : 0 < k) :
    widePts y nx b ⟨0, h0⟩ = y := by
  simp [widePts]

/-- The `(i + 1)`-th query of a step links the `i`-th digest. -/
theorem widePts_succ (y : Q) (nx : ℕ → D → Q) {k : ℕ} (b : Fin k → D) (i : ℕ) (hi : i + 1 < k) :
    widePts y nx b ⟨i + 1, hi⟩ = nx i (b ⟨i, by omega⟩) := by
  simp [widePts]

/-- The step's queries, read with its own digests, are answered by those digests. -/
theorem apply_widePts_wideVals (H : Q → D) (y : Q) (nx : ℕ → D → Q) (k : ℕ) (j : Fin k) :
    H (widePts y nx (wideVals H y nx k) j) = wideVals H y nx k j := by
  obtain ⟨j, hj⟩ := j
  cases j with
  | zero => simp [widePts, wideVals, wideValsN]
  | succ i =>
    rw [widePts_succ _ _ _ i hj]
    simp [wideVals, wideValsN]

/-- Rewriting `H` along the queries of a digest vector `b` (when they are distinct) makes `b` the step's digests. -/
theorem wideVals_extend (H : Q → D) (y : Q) (nx : ℕ → D → Q) (k : ℕ) (b : Fin k → D)
    (hinj : Function.Injective (widePts y nx b)) :
    wideVals (Function.extend (widePts y nx b) b H) y nx k = b := by
  have key : ∀ i (hi : i < k), wideValsN (Function.extend (widePts y nx b) b H) y nx i = b ⟨i, hi⟩ := by
    intro i
    induction i with
    | zero =>
      intro hi
      have h := hinj.extend_apply b H ⟨0, hi⟩
      rw [widePts_zero] at h
      exact h
    | succ i ih =>
      intro hi
      rw [wideValsN, ih (by omega), ← widePts_succ y nx b i hi, hinj.extend_apply]
  funext j
  exact key j j.isLt

/-- **The swap.** Exchange the step's digests under `H` with a free vector: `(H, e) ↦ (H rewritten to `e` along its own step, the old digests)`. A bijection of `(Q → D) × D^k`, its inverse rewriting `H` along the queries of the given vector. -/
noncomputable def wideSwap (y : Q) (nx : ℕ → D → Q) (k : ℕ)
    (hinj : ∀ b : Fin k → D, Function.Injective (widePts y nx b)) :
    (Q → D) × (Fin k → D) ≃ (Q → D) × (Fin k → D) where
  toFun p := (Function.extend (widePts y nx (wideVals p.1 y nx k)) p.2 p.1, wideVals p.1 y nx k)
  invFun p := (Function.extend (widePts y nx p.2) p.2 p.1, fun j => p.1 (widePts y nx p.2 j))
  left_inv p := by
    obtain ⟨H', e⟩ := p
    have hz := hinj (wideVals H' y nx k)
    refine Prod.ext ?_ ?_
    · funext x
      by_cases hx : ∃ a, widePts y nx (wideVals H' y nx k) a = x
      · obtain ⟨a, rfl⟩ := hx
        simp only
        rw [hz.extend_apply, apply_widePts_wideVals H' y nx k a]
      · simp only
        rw [Function.extend_apply' _ _ _ hx, Function.extend_apply' _ _ _ hx]
    · funext j
      exact hz.extend_apply e H' j
  right_inv p := by
    obtain ⟨H, b⟩ := p
    have hz := hinj b
    have hv := wideVals_extend H y nx k b hz
    simp only [hv]
    refine Prod.ext ?_ rfl
    funext x
    by_cases hx : ∃ a, widePts y nx b a = x
    · obtain ⟨a, rfl⟩ := hx
      simp only
      rw [hz.extend_apply]
    · simp only
      rw [Function.extend_apply' _ _ _ hx, Function.extend_apply' _ _ _ hx]

/-- **The counting core.** If an event `W H b` about the step's digests `b` survives rewriting `H` along the step's own queries, then the oracles where the step's digests satisfy it, counted `|D|^k` times, are at most the pairs `(H, b)` that satisfy it: the step's digests are as good as a free uniform vector. -/
theorem wide_card_le [Fintype Q] [DecidableEq Q] [Fintype D] (y : Q) (nx : ℕ → D → Q) (k : ℕ)
    (hinj : ∀ b : Fin k → D, Function.Injective (widePts y nx b)) (W : (Q → D) → (Fin k → D) → Prop)
    [DecidablePred (fun H : Q → D => W H (wideVals H y nx k))]
    [DecidablePred (fun p : (Q → D) × (Fin k → D) => W p.1 p.2)]
    (hW : ∀ H, W H (wideVals H y nx k) →
      ∀ e, W (Function.extend (widePts y nx (wideVals H y nx k)) e H) (wideVals H y nx k)) :
    (univ.filter (fun H : Q → D => W H (wideVals H y nx k))).card * Fintype.card D ^ k
      ≤ (univ.filter (fun p : (Q → D) × (Fin k → D) => W p.1 p.2)).card := by
  have h1 : (univ.filter (fun H : Q → D => W H (wideVals H y nx k))).card * Fintype.card D ^ k
      = ((univ.filter (fun H : Q → D => W H (wideVals H y nx k))) ×ˢ (univ : Finset (Fin k → D))).card := by
    rw [card_product, card_univ, Fintype.card_fun, Fintype.card_fin]
  rw [h1]
  refine card_le_card_of_injOn (wideSwap y nx k hinj) ?_ (wideSwap y nx k hinj).injective.injOn
  intro p hp
  simp only [coe_product, Set.mem_prod, mem_coe, mem_filter, mem_univ, true_and, and_true] at hp
  simp only [coe_filter, mem_univ, true_and, Set.mem_ofPred_eq]
  exact hW p.1 hp p.2

end Run

section Hit

variable {Q D : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]

/-- **A wide fresh hit** in a log: some entry asks, for the first time, a query `y` that starts a step of `wd y` digests (next queries `nx y`); none of the step's queries was asked before it; and the step's digests satisfy `Bad`, named by the log before `y` and by `y`. -/
def WideHit (wd : Q → ℕ) (nx : Q → ℕ → D → Q) (Bad : List (Q × D) → Q → List D → Prop) (H : Q → D)
    (L : List (Q × D)) : Prop :=
  ∃ t e, L[t]? = some e ∧ e.1 ∉ (L.take t).map Prod.fst
    ∧ (∀ j, widePts e.1 (nx e.1) (wideVals H e.1 (nx e.1) (wd e.1)) j ∉ (L.take t).map Prod.fst)
    ∧ Bad (L.take t) e.1 (List.ofFn (wideVals H e.1 (nx e.1) (wd e.1)))

/-- **The wide-digest lemma, in an adaptive run.** For a computation making at most `T` queries, and a set `Bad` named by the log and the start query, of probability at most `ε` for a uniform `wd y`-vector of digests: a wide fresh hit has probability at most `T·ε`. -/
theorem wideHit_prob_le {α : Type} (A : OC Q D α) (T : ℕ) (hA : A.Bounded T) (wd : Q → ℕ)
    (nx : Q → ℕ → D → Q) (hinj : ∀ y (b : Fin (wd y) → D), Function.Injective (widePts y (nx y) b))
    (Bad : List (Q × D) → Q → List D → Prop) (ε : ℝ≥0∞)
    (hBad : ∀ P y, (PMF.uniformOfFintype (Fin (wd y) → D)).toOuterMeasure {b | Bad P y (List.ofFn b)} ≤ ε) :
    prH (fun H => WideHit wd nx Bad H (A.runLog H).2) ≤ (T : ℝ≥0∞) * ε := by
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
  -- one position: the bijection
  have hcount : ∀ t y, ((univ.filter (fun H => W t y H (wideVals H y (nx y) (wd y)))).card : ℝ≥0∞)
      ≤ ε * (univ.filter (fun H => G t y H)).card := by
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
        ≤ (if G t y H then ε * ((Fintype.card D ^ wd y : ℕ) : ℝ≥0∞) else 0) := by
      intro H
      split_ifs with hG
      · have hb := hBad ((A.runLog H).2.take t) y
        rw [prob_uniform_eq_card (fun b : Fin (wd y) → D => Bad ((A.runLog H).2.take t) y (List.ofFn b)),
          ENNReal.div_le_iff (by exact_mod_cast Fintype.card_ne_zero) (ENNReal.natCast_ne_top _)] at hb
        refine le_trans ?_ (le_of_eq_of_le rfl (hb.trans (le_of_eq ?_)))
        · exact_mod_cast card_le_card (fun b hb' => by
            simp only [mem_filter, mem_univ, true_and] at hb' ⊢
            exact hb'.2.2)
        · rw [Fintype.card_fun, Fintype.card_fin]
      · have : univ.filter (fun b : Fin (wd y) → D => W t y H b) = ∅ :=
          filter_eq_empty_iff.mpr (fun b _ hb => hG hb.1)
        simp [this]
    have hB : ((univ.filter (fun p : (Q → D) × (Fin (wd y) → D) => W t y p.1 p.2)).card : ℝ≥0∞)
        ≤ ε * ((Fintype.card D ^ wd y : ℕ) : ℝ≥0∞) * (univ.filter (fun H => G t y H)).card := by
      rw [card_filter_prod (fun p : (Q → D) × (Fin (wd y) → D) => W t y p.1 p.2), Nat.cast_sum]
      calc ∑ H : Q → D, ((univ.filter (fun b : Fin (wd y) → D => W t y H b)).card : ℝ≥0∞)
          ≤ ∑ H : Q → D, (if G t y H then ε * ((Fintype.card D ^ wd y : ℕ) : ℝ≥0∞) else 0) :=
            sum_le_sum (fun H _ => hslice H)
        _ = ε * ((Fintype.card D ^ wd y : ℕ) : ℝ≥0∞) * (univ.filter (fun H => G t y H)).card := by
            rw [← sum_filter, sum_const, nsmul_eq_mul, mul_comm]
    have h2 : ((univ.filter (fun H => W t y H (wideVals H y (nx y) (wd y)))).card : ℝ≥0∞)
        * ((Fintype.card D ^ wd y : ℕ) : ℝ≥0∞)
        ≤ ε * (univ.filter (fun H => G t y H)).card * ((Fintype.card D ^ wd y : ℕ) : ℝ≥0∞) := by
      calc _ ≤ ((univ.filter (fun p : (Q → D) × (Fin (wd y) → D) => W t y p.1 p.2)).card : ℝ≥0∞) := by
            exact_mod_cast hA1
        _ ≤ _ := hB
        _ = _ := by ring
    exact (ENNReal.mul_le_mul_iff_left hD0 hDt).mp h2
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
    have hU : univ.filter (E t) ⊆ univ.biUnion (fun y => univ.filter (fun H => W t y H (wideVals H y (nx y) (wd y)))) := by
      intro H hH
      simp only [mem_filter, mem_univ, true_and] at hH
      obtain ⟨y, hy⟩ := hH
      exact mem_biUnion.mpr ⟨y, mem_univ _, mem_filter.mpr ⟨mem_univ _, hy⟩⟩
    calc ((univ.filter (E t)).card : ℝ≥0∞)
        ≤ ∑ y, ((univ.filter (fun H => W t y H (wideVals H y (nx y) (wd y)))).card : ℝ≥0∞) := by
          exact_mod_cast (card_le_card hU).trans card_biUnion_le
      _ ≤ ∑ y, ε * ((univ.filter (fun H => G t y H)).card : ℝ≥0∞) := sum_le_sum (fun y _ => hcount t y)
      _ = ε * ∑ y, ((univ.filter (fun H => G t y H)).card : ℝ≥0∞) := by rw [mul_sum]
      _ ≤ ε * Fintype.card (Q → D) := by gcongr; exact hdis t
  calc prH (fun H => WideHit wd nx Bad H (A.runLog H).2)
      ≤ μ (⋃ t ∈ range T, {H | E t H}) := MeasureTheory.measure_mono hsub
    _ ≤ ∑ t ∈ range T, μ {H | E t H} := MeasureTheory.measure_biUnion_finset_le _ _
    _ ≤ ∑ _t ∈ range T, ε := sum_le_sum (fun t _ => hpos t)
    _ = (T : ℝ≥0∞) * ε := by rw [sum_const, card_range, nsmul_eq_mul]

end Hit

/-! ## Steps -/

section Steps

variable {It Q D : Type}

/-- The `j`-th item of the step that `it` starts: `it`, then `cont it 0`, `cont it 1`, … -/
def stepItem (cont : It → ℕ → It) (it : It) : ℕ → It
  | 0 => it
  | j + 1 => cont it j

/-- **Steps.** Each item `it` starts a step of `wd it ≥ 1` items, itself and its forced continuation `cont it j` (for a squeeze `sq c` of a `k`-wide challenge: `sq (c + 1 + j)`); the items of a step are distinct. -/
structure Steps (It : Type) where
  wd : It → ℕ
  wd_pos : ∀ it, 0 < wd it
  cont : It → ℕ → It
  distinct : ∀ it i j, i < wd it → j < wd it → stepItem cont it i = stepItem cont it j → i = j

/-- The items of the step that `it` starts. -/
def Steps.items (S : Steps It) (it : It) : List It := (List.range (S.wd it)).map (stepItem S.cont it)

/-- Pair a step's items, from position `j`, with digests. -/
def zipItems (f : ℕ → It) : ℕ → List D → List (It × D)
  | _, [] => []
  | j, d :: ds => (f j, d) :: zipItems f (j + 1) ds

/-- The chain entries of the step that `it` starts, with the digests `ds`. -/
def Steps.ents (S : Steps It) (it : It) (ds : List D) : List (It × D) := zipItems (stepItem S.cont it) 0 ds

/-- One more digest adds one entry at the end. -/
theorem zipItems_snoc (f : ℕ → It) : ∀ (j : ℕ) (ds : List D) (d : D),
    zipItems f j (ds ++ [d]) = zipItems f j ds ++ [(f (j + ds.length), d)]
  | j, [], d => by simp [zipItems]
  | j, d' :: ds, d => by
    simp only [List.cons_append, zipItems, List.length_cons]
    rw [zipItems_snoc f (j + 1) ds d]
    simp [Nat.add_assoc, Nat.add_comm 1]

/-- A step has `wd it` items. -/
theorem Steps.items_length (S : Steps It) (it : It) : (S.items it).length = S.wd it := by
  simp [Steps.items]

/-- A step begins with the item that starts it. -/
theorem Steps.items_cons (S : Steps It) (it : It) : ∃ rest, S.items it = it :: rest := by
  obtain ⟨k, hk⟩ := Nat.exists_eq_succ_of_ne_zero (S.wd_pos it).ne'
  refine ⟨(List.range k).map (fun j => stepItem S.cont it (j + 1)), ?_⟩
  rw [Steps.items, hk, List.range_succ_eq_map, List.map_cons, List.map_map]
  rfl

/-- Expanding step heads gives at least as many items as heads. -/
theorem Steps.length_le_flatMap (S : Steps It) : ∀ hs : List It, hs.length ≤ (hs.flatMap S.items).length
  | [] => le_rfl
  | h :: hs => by
    rw [List.flatMap_cons, List.length_append, S.items_length, List.length_cons]
    have := S.length_le_flatMap hs
    have := S.wd_pos h
    omega

/-- A vector read as a list is the map over `range`. -/
theorem ofFn_eq_map_range {β : Type} (k : ℕ) (g : ℕ → β) :
    List.ofFn (fun j : Fin k => g j) = (List.range k).map g := by
  induction k with
  | zero => rfl
  | succ k ih =>
    rw [List.ofFn_succ', List.range_succ, List.map_append, ← ih, List.concat_eq_append]
    simp

/-- The step's digest vector, as a list. -/
theorem ofFn_wideVals (H : Q → D) (y : Q) (nx : ℕ → D → Q) (k : ℕ) :
    List.ofFn (wideVals H y nx k) = (List.range k).map (wideValsN H y nx) :=
  ofFn_eq_map_range k (wideValsN H y nx)

/-- An event about the list of a vector has the same probability for equal lengths. -/
theorem prob_ofFn_congr [Fintype D] [Nonempty D] {k k' : ℕ} (h : k = k') (E : List D → Prop) :
    (PMF.uniformOfFintype (Fin k → D)).toOuterMeasure {b | E (List.ofFn b)}
      = (PMF.uniformOfFintype (Fin k' → D)).toOuterMeasure {b | E (List.ofFn b)} := by
  subst h
  rfl

end Steps

namespace ChainEnc

variable {It Q D : Type} (C : ChainEnc It Q D)

/-- The next queries of the step `it` starts: the `(j + 1)`-th links the `j`-th digest with `cont it j`. -/
def stepNx (S : Steps It) (it : It) : ℕ → D → Q := fun j d => C.link d (S.cont it j)

/-- Hashing the first `m` items of a step extends the chain by those items paired with the step's first `m` digests. -/
theorem chainFrom_stepPrefix (S : Steps It) (H : Q → D) (τ : List (It × D)) (it : It) : ∀ m : ℕ,
    C.chainFrom H τ ((List.range m).map (stepItem S.cont it))
      = τ ++ S.ents it ((List.range m).map (wideValsN H (C.link (C.lastD H τ) it) (C.stepNx S it)))
  | 0 => by simp [chainFrom, Steps.ents, zipItems]
  | m + 1 => by
    rw [List.range_succ, List.map_append, List.map_append, C.chainFrom_append, chainFrom_stepPrefix S H τ it m]
    simp only [List.map_cons, List.map_nil, chainFrom, Steps.ents]
    rw [zipItems_snoc, List.length_map, List.length_range, zero_add, ← List.append_assoc]
    congr 3
    cases m with
    | zero => simp [zipItems, stepItem, wideValsN]
    | succ m =>
      rw [List.range_succ, List.map_append, List.map_cons, List.map_nil, zipItems_snoc,
        ← List.append_assoc, lastD_snoc]
      simp [stepItem, wideValsN, stepNx]

/-- **Hashing a whole step** extends the chain by the step's entries, its digests being `wideValsN` of its start query. -/
theorem chainFrom_step (S : Steps It) (H : Q → D) (τ : List (It × D)) (it : It) :
    C.chainFrom H τ (S.items it)
      = τ ++ S.ents it ((List.range (S.wd it)).map (wideValsN H (C.link (C.lastD H τ) it) (C.stepNx S it))) :=
  C.chainFrom_stepPrefix S H τ it (S.wd it)

/-- **The step where the chain escapes.** If the chain `τ` is doomed and its extension by the expanded heads `hs` is not, some head `it` (after the heads `pre`) takes the doomed chain of `pre` out of doom in one whole step. -/
theorem chain_flip_steps (S : Steps It) (H : Q → D) (St : List (It × D) → Prop) :
    ∀ (hs : List It) (τ : List (It × D)), ¬ St τ → St (C.chainFrom H τ (hs.flatMap S.items)) →
      ∃ pre it post, hs = pre ++ it :: post ∧ ¬ St (C.chainFrom H τ (pre.flatMap S.items))
        ∧ St (C.chainFrom H (C.chainFrom H τ (pre.flatMap S.items)) (S.items it))
  | [], τ, hns, hs => by
    rw [List.flatMap_nil] at hs
    exact absurd hs hns
  | it :: rest, τ, hns, hs => by
    rw [List.flatMap_cons, C.chainFrom_append] at hs
    by_cases h1 : St (C.chainFrom H τ (S.items it))
    · refine ⟨[], it, rest, rfl, ?_, ?_⟩
      · rw [List.flatMap_nil]
        exact hns
      · rw [List.flatMap_nil]
        exact h1
    · obtain ⟨pre, it', post, hpre, h2, h3⟩ := chain_flip_steps S H St rest _ h1 hs
      refine ⟨it :: pre, it', post, by rw [hpre]; rfl, ?_, ?_⟩
      · rw [List.flatMap_cons, C.chainFrom_append]
        exact h2
      · rw [List.flatMap_cons, C.chainFrom_append]
        exact h3

/-- A chain hashed from nothing carries exactly its items. -/
theorem chainFrom_nil_map_fst (H : Q → D) (its : List It) : (C.chainFrom H [] its).map Prod.fst = its := by
  obtain ⟨ext, h1, h2⟩ := C.chainFrom_eq_append H its []
  rw [h1, List.nil_append, h2]

/-- The run of a prover followed by the verifier's hashing of every step of its heads. -/
def stepRun (S : Steps It) {α : Type} (heads : α → List It) (A : OC Q D α) : OC Q D (List (It × D)) :=
  A.bind (fun o => C.chainOC ((heads o).flatMap S.items))

/-- The width of the step a query starts: the width of the item it links (`1` if it is no link). -/
def wdQ (S : Steps It) (y : Q) : ℕ := (C.ldec y).elim 1 (fun p => S.wd p.2)

/-- The next queries of the step a query starts. -/
def nxQ (S : Steps It) (y : Q) : ℕ → D → Q := fun j d => (C.ldec y).elim y (fun p => C.link d (S.cont p.2 j))

/-- A link query starts a step of its item's width. -/
theorem wdQ_link (S : Steps It) (d : D) (it : It) : C.wdQ S (C.link d it) = S.wd it := by
  simp [wdQ, C.ldec_link]

/-- A link query's next queries are its item's. -/
theorem nxQ_link (S : Steps It) (d : D) (it : It) : C.nxQ S (C.link d it) = C.stepNx S it := by
  funext j d'
  simp [nxQ, stepNx, C.ldec_link]

/-- The queries of a step are distinct (their items are, and `link` is injective). -/
theorem widePts_injective (S : Steps It) (y : Q) (b : Fin (C.wdQ S y) → D) :
    Function.Injective (widePts y (C.nxQ S y) b) := by
  rcases hy : C.ldec y with _ | ⟨d, it⟩
  · have hw : C.wdQ S y = 1 := by simp [wdQ, hy]
    intro i j _
    exact Fin.ext (by have := i.isLt; have := j.isLt; omega)
  · have hw : C.wdQ S y = S.wd it := by simp [wdQ, hy]
    have hn : ∀ j d', C.nxQ S y j d' = C.link d' (S.cont it j) := by
      intro j d'
      simp [nxQ, hy]
    have hdec : ∀ j : Fin (C.wdQ S y),
        (C.ldec (widePts y (C.nxQ S y) b j)).map Prod.snd = some (stepItem S.cont it j) := by
      intro j
      obtain ⟨j, hj⟩ := j
      cases j with
      | zero =>
        rw [widePts_zero]
        simp [hy, stepItem]
      | succ i =>
        rw [widePts_succ, hn, C.ldec_link]
        simp [stepItem]
    intro i j hij
    have h1 := hdec i
    have h2 := hdec j
    rw [hij] at h1
    rw [h1] at h2
    exact Fin.ext (S.distinct it i j (hw ▸ i.isLt) (hw ▸ j.isLt) (Option.some.inj h2))

variable [DecidableEq Q] [DecidableEq D]

/-- **The set a query names**: decode it as `link(d, it)`, trace `d` back through the log to a chain `τ`; if `τ` is doomed (at least `s` items, whole steps), the digest lists that take `τ` out of doom in the step `it` starts. -/
def stepBad (S : Steps It) (St : List (Q × D) → List (It × D) → Prop) (s ℓ : ℕ) (P : List (Q × D)) (y : Q)
    (ds : List D) : Prop :=
  ∃ d it τ, C.ldec y = some (d, it) ∧ C.traceBack P (ℓ + 1) d = some τ ∧ s ≤ τ.length
    ∧ (∃ hs : List It, τ.map Prod.fst = hs.flatMap S.items) ∧ ¬ St P τ ∧ St P (τ ++ S.ents it ds)

/-- The named set has probability at most `ε` for a uniform vector of the step's width, by the round hypothesis. -/
theorem stepBad_prob_le [Fintype D] [Nonempty D] (S : Steps It) (St : List (Q × D) → List (It × D) → Prop)
    (s ℓ : ℕ) (ε : ℝ≥0∞)
    (hround : ∀ P τ it, s ≤ τ.length → (∃ hs : List It, τ.map Prod.fst = hs.flatMap S.items) → ¬ St P τ →
      (PMF.uniformOfFintype (Fin (S.wd it) → D)).toOuterMeasure {b | St P (τ ++ S.ents it (List.ofFn b))} ≤ ε)
    (P : List (Q × D)) (y : Q) :
    (PMF.uniformOfFintype (Fin (C.wdQ S y) → D)).toOuterMeasure {b | C.stepBad S St s ℓ P y (List.ofFn b)}
      ≤ ε := by
  have hempty : ∀ (E : Set (Fin (C.wdQ S y) → D)), E = ∅ →
      (PMF.uniformOfFintype (Fin (C.wdQ S y) → D)).toOuterMeasure E ≤ ε := by
    rintro E rfl
    rw [MeasureTheory.measure_empty]
    exact zero_le
  rcases hy : C.ldec y with _ | ⟨d, it⟩
  · refine hempty _ ?_
    ext b
    simp [stepBad, hy]
  · rcases htb : C.traceBack P (ℓ + 1) d with _ | τ
    · refine hempty _ ?_
      ext b
      simp only [stepBad, hy, Option.some.injEq, Prod.mk.injEq, Set.mem_ofPred_eq, Set.mem_empty_iff_false,
        iff_false, not_exists, not_and]
      rintro d' it' τ' ⟨rfl, rfl⟩ h2
      rw [htb] at h2
      cases h2
    · by_cases hc : s ≤ τ.length ∧ (∃ hs : List It, τ.map Prod.fst = hs.flatMap S.items) ∧ ¬ St P τ
      · have hw : C.wdQ S y = S.wd it := by simp [wdQ, hy]
        have hset : {b : Fin (C.wdQ S y) → D | C.stepBad S St s ℓ P y (List.ofFn b)}
            = {b | St P (τ ++ S.ents it (List.ofFn b))} := by
          ext b
          simp only [stepBad, hy, Option.some.injEq, Prod.mk.injEq, Set.mem_ofPred_eq]
          constructor
          · rintro ⟨d', it', τ', ⟨rfl, rfl⟩, h2, -, -, -, h6⟩
            rw [htb] at h2
            cases h2
            exact h6
          · intro h
            exact ⟨d, it, τ, ⟨rfl, rfl⟩, htb, hc.1, hc.2.1, hc.2.2, h⟩
        rw [hset, prob_ofFn_congr hw (fun ds => St P (τ ++ S.ents it ds))]
        exact hround P τ it hc.1 hc.2.1 hc.2.2
      · refine hempty _ ?_
        ext b
        simp only [stepBad, hy, Option.some.injEq, Prod.mk.injEq, Set.mem_ofPred_eq, Set.mem_empty_iff_false,
          iff_false, not_exists, not_and]
        rintro d' it' τ' ⟨rfl, rfl⟩ h2 h3 h4 h5 -
        rw [htb] at h2
        cases h2
        exact hc ⟨h3, h4, h5⟩

end ChainEnc

section SoundWide

variable {It Q D : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D]

/-- **Fiat–Shamir soundness on the code's chain, with vector challenges.** Let `St P τ` be a state on chains (it may read the log `P`) such that from a doomed chain of whole steps (at least `s` items), for every next head `it`, a uniform vector of `wd it` digests escapes doom with probability at most `ε`, and such that once a chain's queries are logged a longer log does not change its state (`hstab`). A prover making at most `q` hash queries outputs heads; the verifier hashes every step of them (at most `ℓ` items). The probability that the chain of the first `s` heads is doomed while the whole chain is not is at most `T·ε + collBound T D + collBound (T + 1) D`, `T = q + ℓ + 1`. The state is evaluated with the log of the whole run (the prover's queries, then the verifier's). -/
theorem chain_sound_wide (C : ChainEnc It Q D) (S : Steps It) (St : List (Q × D) → List (It × D) → Prop)
    (s : ℕ) (ε : ℝ≥0∞)
    (hround : ∀ P τ it, s ≤ τ.length → (∃ hs : List It, τ.map Prod.fst = hs.flatMap S.items) → ¬ St P τ →
      (PMF.uniformOfFintype (Fin (S.wd it) → D)).toOuterMeasure {b | St P (τ ++ S.ents it (List.ofFn b))} ≤ ε)
    (hstab : ∀ (H : Q → D) (P P' : List (Q × D)) (τ : List (It × D)) (qs : List Q) (ext : List (It × D)),
      C.Chain H τ qs → s ≤ τ.length → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' → (∀ e ∈ P', e.2 = H e.1) →
        (St P (τ ++ ext) ↔ St P' (τ ++ ext)))
    {α : Type} (heads : α → List It) (ℓ : ℕ) (hℓ : ∀ o, ((heads o).flatMap S.items).length ≤ ℓ)
    (q : ℕ) (A : OC Q D α) (hA : A.Bounded q) :
    prH (fun H => ¬ St ((C.stepRun S heads A).runLog H).2
          (C.chainFrom H [] (((heads (A.run H)).take s).flatMap S.items))
        ∧ St ((C.stepRun S heads A).runLog H).2 (C.chainFrom H [] ((heads (A.run H)).flatMap S.items)))
      ≤ ((q + ℓ + 1 : ℕ) : ℝ≥0∞) * ε + collBound (q + ℓ + 1) D + collBound (q + ℓ + 1 + 1) D := by
  classical
  set T := q + ℓ + 1 with hT
  set Cm := C.stepRun S heads A with hCmdef
  have hCm : Cm.Bounded T :=
    (hA.bind (fun o => (C.chainOC_bounded ((heads o).flatMap S.items)).mono
      (show ((heads o).flatMap S.items).length + 1 ≤ ℓ + 1 by have := hℓ o; omega))).mono (by omega)
  have hW := wideHit_prob_le Cm T hCm (C.wdQ S) (C.nxQ S) (C.widePts_injective S) (C.stepBad S St s ℓ) ε
    (fun P y => C.stepBad_prob_le S St s ℓ ε hround P y)
  have hcoll := collision_prob_le Cm T hCm
  have hgs := freshHitQ_prob_le_gen Cm T hCm C.chainTargets (fun t => t + 1) (fun P y => C.chainTargets_card P y)
  have hsum : ∀ n : ℕ, ∑ t ∈ range n, (t + 1) = (n + 1) * (n + 1 - 1) / 2 := by
    intro n
    rw [← Finset.sum_range_id (n + 1)]
    simp [Finset.sum_range_succ']
  rw [hsum T] at hgs
  have hsub : {H : Q → D | ¬ St (Cm.runLog H).2 (C.chainFrom H [] (((heads (A.run H)).take s).flatMap S.items))
        ∧ St (Cm.runLog H).2 (C.chainFrom H [] ((heads (A.run H)).flatMap S.items))}
      ⊆ ({H | WideHit (C.wdQ S) (C.nxQ S) (C.stepBad S St s ℓ) H (Cm.runLog H).2}
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
    refine ⟨t, (y, e2), ht, hfirst, ?_, ?_⟩
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
        -- the chain of the first `i + 1` items of the step
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
      have htb := C.traceBack_chain H hPL hPnc hc' hord (ℓ - τ'.length)
      rw [show τ'.length + 1 + (ℓ - τ'.length) = ℓ + 1 by omega] at htb
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
  calc prH (fun H => ¬ St (Cm.runLog H).2 (C.chainFrom H [] (((heads (A.run H)).take s).flatMap S.items))
        ∧ St (Cm.runLog H).2 (C.chainFrom H [] ((heads (A.run H)).flatMap S.items)))
      ≤ (PMF.uniformOfFintype (Q → D)).toOuterMeasure
          (({H | WideHit (C.wdQ S) (C.nxQ S) (C.stepBad S St s ℓ) H (Cm.runLog H).2}
            ∪ {H | ∃ a ∈ OC.queries H Cm, ∃ b ∈ OC.queries H Cm, a ≠ b ∧ H a = H b})
            ∪ {H | FreshHitQ C.chainTargets (Cm.runLog H).2}) := MeasureTheory.measure_mono hsub
    _ ≤ prH (fun H => WideHit (C.wdQ S) (C.nxQ S) (C.stepBad S St s ℓ) H (Cm.runLog H).2)
          + prH (fun H => ∃ a ∈ OC.queries H Cm, ∃ b ∈ OC.queries H Cm, a ≠ b ∧ H a = H b)
          + prH (fun H => FreshHitQ C.chainTargets (Cm.runLog H).2) :=
        (MeasureTheory.measure_union_le _ _).trans (add_le_add (MeasureTheory.measure_union_le _ _) le_rfl)
    _ ≤ _ := add_le_add (add_le_add hW hcoll) hgs

end SoundWide

end ZK60.Sound
