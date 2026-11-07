/-
D63 lane L18 (2026-11-07), part 6: **the classify run's schedule with lane L20's per-position count** (finding L18-2
revisited). L8's composition charges every one of the run's `T = q + ℓ + 1` positions the largest error; L20's
`fs_code_chain_sound_sched_log_pos` (CountW16Chain.lean, merged at perf `c25c9944`) charges the prover's `q` queries
the largest error and the verifier's own chain only the rounds each step starts: `q·εmax + Σ_c n_c·ε_c` plus the two
collision terms. This file applies it to the WHOLE run's schedule (`runSched`: stage IN-C, the `L` blocks, stage
OUT-C), with a schedule that does not read the prover's log (the soundness form; the knowledge form is L20's own
statement, with log-reading states).

* **`classify_run_fs_sound_sched_pos`**: for the run's schedule, round-by-round sound sub-protocols with errors
  `≤ εmax`, releases forward only, every window after the run header's first item: a false claim entering any window
  and every sub-protocol alive at the end has probability at most `q·εmax + Σ_{c ∈ run} n_c·ε_c + collBound T +
  collBound (T + 1)`. The query-free part is the SUM of every part's rounds' errors over the whole run: 26 blocks'
  constants (L20: about `2^-104.2` for one W16R2 block) plus the stages' [ESTIMATE: about `2^-99.5` for the run], so
  the one-zone path-wise count of D66(4) is still what brings the run under `εsTarget`'s `2^-100` (finding L18-2).

Every premise is an explicit hypothesis; no `sorry`, axiom or `native_decide`.
-/
import ZK60Formal.ProtocolClassifyFS
import ZK60Formal.CountW16Chain

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Sound

section Pos

variable {D It' : Type} [Fintype D] [Nonempty D] [DecidableEq D] {Q : Type} [Fintype Q] [DecidableEq Q]

/-- **The WHOLE classify run's schedule with the per-position count** (L20's `fs_code_chain_sound_sched_log_pos` with
a schedule that does not read the prover's log): the prover's queries are charged the largest error `εmax`, the
verifier's own chain the sum over the run's sub-protocols of their rounds' errors, `Σ_c n_c·ε_c`. -/
theorem classify_run_fs_sound_sched_pos (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) (cin : List (CSub D))
    (cblk : ℕ → List (CSub D)) (L : ℕ) (cout : List (CSub D)) (εmax : ℝ≥0∞)
    (hR : ∀ c ∈ runSched cin cblk L cout, RbrWide c.R.n c.R.w c.St c.ε ∧ c.ε ≤ εmax)
    (hframe : ∀ (k : ℕ) (c : CSub D) (τ : List (TItem × D)) (h : TItem) (ks : List UInt64) (ds : List D),
      (runSched cin cblk L cout)[k]? = some c → tRem W τ = some 0 → ks.length + 1 = tWd W h →
      ds.length = ks.length + 1 → ¬ subSt W c τ → c.rel (τ ++ stE h ks ds) →
        ∃ k' c', k < k' ∧ (runSched cin cblk L cout)[k']? = some c' ∧ ¬ subSt W c' τ)
    (hwin : ∀ c ∈ runSched cin cblk L cout, 0 < c.a)
    (C : ChainEnc It' Q D) (toT : It' → TItem) (S : Steps It') (hS : StepsOK W toT S)
    {α : Type} (heads : α → List It') (ℓ : ℕ) (hℓ : ∀ o, ((heads o).flatMap S.items).length ≤ ℓ)
    (q : ℕ) (A : OC Q D α) (hA : A.Bounded q) :
    prH (fun H => (∃ (k : ℕ) (c : CSub D), (runSched cin cblk L cout)[k]? = some c
          ∧ c.a ≤ (cChain C toT S H (heads (A.run H))).length
          ∧ tRem W ((cChain C toT S H (heads (A.run H))).take c.a) = some 0
          ∧ ¬ c.St ((cChain C toT S H (heads (A.run H))).take c.a) []
          ∧ ¬ c.rel ((cChain C toT S H (heads (A.run H))).take c.a))
        ∧ allSt W (runSched cin cblk L cout) (cChain C toT S H (heads (A.run H))))
      ≤ (q : ℝ≥0∞) * εmax + ((runSched cin cblk L cout).map (fun c => (c.R.n : ℝ≥0∞) * c.ε)).sum
        + collBound (q + ℓ + 1) D + collBound (q + ℓ + 1 + 1) D := by
  have h := fs_code_chain_sound_sched_log_pos W hW (fun _ => runSched cin cblk L cout)
    ((runSched cin cblk L cout).map CSub.sk) (fun _ => rfl) εmax (fun _ c hc => (hR c hc).1)
    (fun _ c hc => (hR c hc).2) (fun _ => hframe) C toT S hS heads ℓ hℓ 0 (fun _ c hc => hwin c hc)
    (fun o => by simp) (fun _ _ _ _ _ _ _ _ _ _ _ => Iff.rfl) q A hA
  rw [List.map_map] at h
  exact h

end Pos

end ZK60.ProtocolClassify
