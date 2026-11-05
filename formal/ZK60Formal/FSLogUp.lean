/-
D63, step L3 (soundness): LogUp under Fiat–Shamir, on the code's chain, round by round.

`SoundLogUpBlock.lean`'s `logup_block_bound` is the interactive bound for one block, `(N + 4M − 1)/|F|` over
independent uniform `β, γ, α` (`N` lookups, `M` distinct table tuples). Its proof splits in two:
* **the fold** (`β, γ`): if some looked-up tuple is not a table tuple, the LogUp identity of the FOLDED tuples holds
  for at most `2M·|F|` of the pairs `(β, γ)` (`fold_hits_table_card`, `logup_ne_of_not_mem`): error `2M/|F|`
  (`logup_fold_round`);
* **the `α` step**: if the folded identity fails, some helpers pass every relation (single, pair and table helpers
  and the value-0 sum claim) for at most `N + 2M − 1` values of `α` (`card_helperRel_le'`): error `(N + 2M − 1)/|F|`
  (`logup_alpha_round`).
The two add up to `logup_block_bound`'s `(N + 4M − 1)/|F|` (`logup_rounds_add`). Round by round, those are the two
rounds' errors: the state after `(β, γ)` is "the folded identity holds", after `α` "some helpers pass".

**As the code runs it** (`protocol.rs:2003-2007` of the `gpu-metal` tree): the `A` root (lookups and
multiplicities) and the `M` root are absorbed, then `β = challenge_fp2()`, `γ = challenge_fp2()`,
`α = challenge_fp2()` with no absorb between, then the `H` root (the helpers). Here: a protocol of two rounds with no
message, of widths `2` (`β, γ`) and `1` (`α`); the statement carries the lookups and multiplicities (the committed data,
as values: the extraction is a separate step); the table `T` is fixed (public, part of the profile); the helpers are
the final message. The challenges are the code's `challenge_fp2` of each squeeze (`fp2Field`).

**What is proved.**
* `logup_rbrWide`: this protocol is round-by-round sound with vector challenges, per-round error at most
  `ε = (N + 2M − 1)/|F| · (1 + p/2^128)^4` (the fold round's `2M/|F|·(1 + p/2^128)^4` and the `α` round's
  `(N + 2M − 1)/|F|·(1 + p/2^128)^2` are both below it once `N ≥ 1`).
* `fs_logup_chain_sound`: a prover making at most `q` hash queries, choosing the statement itself, makes the chain
  verifier accept a FALSE LogUp statement (some looked-up tuple outside the table, `N < char F`) with probability at
  most `(q + 7)·ε + collBound (q + 7) D + collBound (q + 8) D` over `|D| = 2^256`.

**The figure.** Per hash query the error is `(N + 2M − 1)/|F|` (the `α` round's) times `(1 + p/2^128)^4 ≈ 1 + 2^-62`:
below the count's joint `(N + 4M − 1)/|F|`, because under Fiat–Shamir an attack must win ONE round and each query
attacks one round (the maximum, not the sum, of the two rounds' errors).

**What this does not cover.** That the relations hold on the whole cube and the sum claim's value are checked by the
zero-check sumchecks and the PCS (their own protocols); the zero-sum mask row `u`; the hand-off to the slots on one
chain (`FSComposeBlock.lean` composes them, with the hand-offs as premises); the extraction of the lookups and multiplicities from the `A` commitment.
-/
import ZK60Formal.FSWideRbr
import ZK60Formal.SoundLogUpBlock

set_option autoImplicit false

namespace ZK60.Sound

open scoped ENNReal
open Finset

/-! ## LogUp's two interactive rounds -/

section Rounds

variable {F : Type} [Field F] [DecidableEq F] [Fintype F]
variable {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]

/-- The LogUp identity of the tuples folded with `(β, γ)`: `Σ_l 1/(X − fold(A_l)) = Σ_j m_j/(X − fold(T_j))`. -/
def foldedId (A : ι ⊕ (π ⊕ π) → Tup F) (T : κ → Tup F) (m : κ → F) (β γ : F) : Prop :=
  logupLhs (fun l => fold β γ (A l)) = logupRhs (fun j => fold β γ (T j)) m

/-- **A false LogUp statement**: some looked-up tuple is not a table tuple, and the lookups number fewer than the
characteristic. -/
def luFalse (A : ι ⊕ (π ⊕ π) → Tup F) (T : κ → Tup F) : Prop :=
  (∃ l, ∀ j, T j ≠ A l) ∧ Fintype.card ι + 2 * Fintype.card π < ringChar F

/-- **The fold round.** For a false statement, uniform `(β, γ)` make the folded identity hold with probability at most
`2M/|F|`, `M` the number of distinct table tuples. -/
theorem logup_fold_round (A : ι ⊕ (π ⊕ π) → Tup F) (T : κ → Tup F) (m : κ → F) (h : luFalse A T) :
    (PMF.uniformOfFintype (F × F)).toOuterMeasure {p | foldedId A T m p.1 p.2}
      ≤ ((2 * (univ.image T).card : ℕ) : ℝ≥0∞) / Fintype.card F := by
  classical
  obtain ⟨⟨l, hl⟩, hN⟩ := h
  have hcardL : Fintype.card (ι ⊕ (π ⊕ π)) = Fintype.card ι + 2 * Fintype.card π := by
    rw [Fintype.card_sum, Fintype.card_sum]
    ring
  refine prob_le_of_card_mul (fun p : F × F => foldedId A T m p.1 p.2) (2 * (univ.image T).card)
    (Fintype.card F) Fintype.card_ne_zero ?_
  have hsub : univ.filter (fun p : F × F => foldedId A T m p.1 p.2)
      ⊆ univ.filter (fun p : F × F => ∃ j, fold p.1 p.2 (A l) = fold p.1 p.2 (T j)) := by
    intro p hp
    simp only [mem_filter, mem_univ, true_and] at hp ⊢
    by_contra hno
    push Not at hno
    exact logup_ne_of_not_mem _ _ _ (by rw [hcardL]; exact hN) (i := l) (fun j hj => hno j hj.symm) hp
  calc (univ.filter (fun p : F × F => foldedId A T m p.1 p.2)).card * Fintype.card F
      ≤ ((univ.image T).card * (2 * Fintype.card F)) * Fintype.card F :=
        Nat.mul_le_mul_right _ ((card_le_card hsub).trans (fold_hits_table_card (A l) T hl))
    _ = 2 * (univ.image T).card * Fintype.card (F × F) := by
        rw [Fintype.card_prod]
        ring

/-- **The `α` round.** If the folded identity fails, a uniform `α` leaves some helpers passing every relation and the
sum claim with probability at most `(N + 2M − 1)/|F|`. -/
theorem logup_alpha_round (A : ι ⊕ (π ⊕ π) → Tup F) (T : κ → Tup F) (m : κ → F) (β γ : F)
    (h : ¬ foldedId A T m β γ) :
    (PMF.uniformOfFintype F).toOuterMeasure
        {α | ∃ H, HelperRel (fun l => fold β γ (A l)) (fun j => fold β γ (T j)) m α H}
      ≤ (((Fintype.card ι + 2 * Fintype.card π) + 2 * (univ.image T).card - 1 : ℕ) : ℝ≥0∞)
        / Fintype.card F := by
  classical
  refine (logup_helpers_bound _ _ _ h).trans (ENNReal.div_le_div_right ?_ _)
  have himg : (univ.image (fun j => fold β γ (T j))).card ≤ (univ.image T).card := by
    rw [show univ.image (fun j => fold β γ (T j)) = (univ.image T).image (fold β γ) by rw [image_image]; rfl]
    exact card_image_le
  exact_mod_cast (by omega : (Fintype.card ι + 2 * Fintype.card π) + 2 * (univ.image (fun j => fold β γ (T j))).card - 1
    ≤ (Fintype.card ι + 2 * Fintype.card π) + 2 * (univ.image T).card - 1)

/-- The two rounds' errors add up to `logup_block_bound`'s `N + 4M − 1`. -/
theorem logup_rounds_add (N M : ℕ) (hN : 1 ≤ N) : 2 * M + (N + 2 * M - 1) = N + 4 * M - 1 := by
  omega

end Rounds

/-! ## LogUp on the code's chain -/

section FS

variable {F : Type} [Field F] [Fintype F] [DecidableEq F]
variable {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
variable {X : Type}

/-- LogUp's round widths: `2` squeezes (`β, γ`), then `1` (`α`). -/
def luW : ℕ → ℕ := fun i => if i = 0 then 2 else 1

/-- Every round squeezes at least once. -/
theorem luW_pos : ∀ i, 0 < luW i := by
  intro i
  unfold luW
  split_ifs <;> omega

/-- Neither round has a message: the three squeezes follow each other. -/
def luMsg : ℕ → Bool := fun _ => false

/-- **LogUp's state on digest transcripts**: a true statement is never doomed; after `(β, γ)` (read from the two
digests by `chal`) alive iff the folded identity holds; after `α`, alive iff some helpers pass. -/
def luSt (chal : Dg → F) (T : κ → Tup F) (lu : X → (ι ⊕ (π ⊕ π) → Tup F) × (κ → F)) (x : X) :
    List (Unit × List Dg) → Prop
  | [] => ¬ luFalse (lu x).1 T
  | [(_, [d0, d1])] => ¬ luFalse (lu x).1 T ∨ foldedId (lu x).1 T (lu x).2 (chal d0) (chal d1)
  | [(_, [d0, d1]), (_, [d2])] => ¬ luFalse (lu x).1 T
      ∨ ∃ H, HelperRel (fun l => fold (chal d0) (chal d1) ((lu x).1 l)) (fun j => fold (chal d0) (chal d1) (T j))
          (lu x).2 (chal d2) H
  | _ => ¬ luFalse (lu x).1 T

/-- **LogUp's verifier**: the helpers pass every relation and the sum claim at the folded tuples and `α`. -/
def luAccept (chal : Dg → F) (T : κ → Tup F) (lu : X → (ι ⊕ (π ⊕ π) → Tup F) × (κ → F)) (x : X) :
    List (Unit × List Dg) → Helpers ι π κ F → Prop
  | [(_, [d0, d1]), (_, [d2])], H =>
      HelperRel (fun l => fold (chal d0) (chal d1) ((lu x).1 l)) (fun j => fold (chal d0) (chal d1) (T j))
        (lu x).2 (chal d2) H
  | _, _ => False

/-- The per-round error with the code's challenges: `(N + 2M − 1)/|F| · (1 + p/2^128)^4`. -/
noncomputable def luEps (p : ℕ) (T : κ → Tup F) : ℝ≥0∞ :=
  (((Fintype.card ι + 2 * Fintype.card π) + 2 * (univ.image T).card - 1 : ℕ) : ℝ≥0∞) / Fintype.card F
    * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 4

/-- The bias base is at least `1`. -/
theorem one_le_fp2_base (p : ℕ) : (1 : ℝ≥0∞) ≤ 1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞) := le_self_add

/-- **LogUp is round-by-round sound with vector challenges** (the code's `challenge_fp2`), with per-round error
`luEps`. -/
theorem logup_rbrWide (p : ℕ) [NeZero p] (eF : ZMod p × ZMod p ≃ F) (T : κ → Tup F)
    (lu : X → (ι ⊕ (π ⊕ π) → Tup F) × (κ → F)) :
    RbrWide 2 luW (luSt (fp2Field p (2 ^ 128) eF) T lu) (luEps (ι := ι) (π := π) p T) where
  round x τ m hτ hns := by
    classical
    have : Nonempty F := ⟨eF 0⟩
    rcases τ with _ | ⟨⟨u, ds⟩, _ | ⟨e2, τ⟩⟩
    · -- round 0: the fold challenges `(β, γ)`
      have hF : luFalse (lu x).1 T := not_not.mp hns
      obtain ⟨⟨l, -⟩, -⟩ := id hF
      rw [prob_ofFn_congr (show luW ([] : List (Unit × List Dg)).length = 2 from rfl)
        (fun ds => luSt (fp2Field p (2 ^ 128) eF) T lu x ([] ++ [(m, ds)]))]
      have hset : {b : Fin 2 → Dg | luSt (fp2Field p (2 ^ 128) eF) T lu x ([] ++ [(m, List.ofFn b)])}
          = {b : Fin 2 → Dg | (fun c : Fin 2 → F => foldedId (lu x).1 T (lu x).2 (c 0) (c 1))
              (fun j => fp2Field p (2 ^ 128) eF (b j))} := by
        ext b
        have hb : List.ofFn b = [b 0, b 1] := by simp [List.ofFn_succ]
        simp only [Set.mem_ofPred_eq, List.nil_append, hb, luSt]
        exact ⟨fun h => h.resolve_left (not_not.mpr hF), Or.inr⟩
      rw [hset]
      refine (prob_fp2_vec_le p eF 2 (fun c : Fin 2 → F => foldedId (lu x).1 T (lu x).2 (c 0) (c 1))).trans ?_
      rw [show (PMF.uniformOfFintype (Fin 2 → F)).toOuterMeasure {c | foldedId (lu x).1 T (lu x).2 (c 0) (c 1)}
          = (PMF.uniformOfFintype (F × F)).toOuterMeasure {c | foldedId (lu x).1 T (lu x).2 c.1 c.2} from
        prob_equiv_comp (piFinTwoEquiv (fun _ => F)) (fun c => foldedId (lu x).1 T (lu x).2 c.1 c.2)]
      have h1 := logup_fold_round (lu x).1 T (lu x).2 hF
      have hN : 1 ≤ Fintype.card ι + 2 * Fintype.card π := by
        have : 0 < Fintype.card (ι ⊕ (π ⊕ π)) := Fintype.card_pos_iff.mpr ⟨l⟩
        rw [Fintype.card_sum, Fintype.card_sum] at this
        omega
      calc (PMF.uniformOfFintype (F × F)).toOuterMeasure {c | foldedId (lu x).1 T (lu x).2 c.1 c.2}
            * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * 2)
          ≤ ((2 * (univ.image T).card : ℕ) : ℝ≥0∞) / Fintype.card F
            * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 4 := mul_le_mul' h1 le_rfl
        _ ≤ luEps (ι := ι) (π := π) p T := by
            unfold luEps
            gcongr
            omega
    · -- round 1: `α`, after the fold
      have hlen : ([(u, ds)] : List (Unit × List Dg)).length = 1 := rfl
      have hempty : ∀ (E : Set (Fin (luW ([(u, ds)] : List (Unit × List Dg)).length) → Dg)), (∀ b, b ∉ E) →
          (PMF.uniformOfFintype (Fin (luW ([(u, ds)] : List (Unit × List Dg)).length) → Dg)).toOuterMeasure E
            ≤ luEps (ι := ι) (π := π) p T := by
        intro E hE
        rw [Set.eq_empty_iff_forall_notMem.mpr hE, MeasureTheory.measure_empty]
        exact zero_le
      match ds, hns with
      | [d0, d1], hns =>
        simp only [luSt, not_or, not_not] at hns
        obtain ⟨hF, hfold⟩ := hns
        rw [prob_ofFn_congr (show luW ([(u, [d0, d1])] : List (Unit × List Dg)).length = 1 from rfl)
          (fun ds => luSt (fp2Field p (2 ^ 128) eF) T lu x ([(u, [d0, d1])] ++ [(m, ds)]))]
        have hset : {b : Fin 1 → Dg | luSt (fp2Field p (2 ^ 128) eF) T lu x ([(u, [d0, d1])] ++ [(m, List.ofFn b)])}
            = {b : Fin 1 → Dg | (fun c : Fin 1 → F => ∃ H, HelperRel
                (fun l => fold (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) ((lu x).1 l))
                (fun j => fold (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) (T j)) (lu x).2 (c 0) H)
                (fun j => fp2Field p (2 ^ 128) eF (b j))} := by
          ext b
          have hb : List.ofFn b = [b 0] := by simp [List.ofFn_succ]
          simp only [Set.mem_ofPred_eq, List.cons_append, List.nil_append, hb, luSt]
          exact ⟨fun h => h.resolve_left (not_not.mpr hF), Or.inr⟩
        rw [hset]
        refine (prob_fp2_vec_le p eF 1 (fun c : Fin 1 → F => ∃ H, HelperRel
          (fun l => fold (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) ((lu x).1 l))
          (fun j => fold (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) (T j)) (lu x).2 (c 0) H)).trans ?_
        rw [show (PMF.uniformOfFintype (Fin 1 → F)).toOuterMeasure {c | ∃ H, HelperRel
              (fun l => fold (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) ((lu x).1 l))
              (fun j => fold (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) (T j)) (lu x).2 (c 0) H}
            = (PMF.uniformOfFintype F).toOuterMeasure {α | ∃ H, HelperRel
              (fun l => fold (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) ((lu x).1 l))
              (fun j => fold (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) (T j)) (lu x).2 α H} from
          prob_equiv_comp (Equiv.funUnique (Fin 1) F) (fun α => ∃ H, HelperRel
            (fun l => fold (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) ((lu x).1 l))
            (fun j => fold (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) (T j)) (lu x).2 α H)]
        have h1 := logup_alpha_round (lu x).1 T (lu x).2 (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) hfold
        calc _ ≤ (((Fintype.card ι + 2 * Fintype.card π) + 2 * (univ.image T).card - 1 : ℕ) : ℝ≥0∞)
                / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * 1) := mul_le_mul' h1 le_rfl
          _ ≤ luEps (ι := ι) (π := π) p T :=
              mul_le_mul' le_rfl (pow_le_pow_right₀ (one_le_fp2_base p) (by norm_num))
      | [], hns =>
        refine hempty _ (fun b hb => ?_)
        exact hns hb
      | [d0], hns =>
        refine hempty _ (fun b hb => ?_)
        exact hns hb
      | d0 :: d1 :: d2 :: ds', hns =>
        refine hempty _ (fun b hb => ?_)
        exact hns hb
    · simp at hτ

omit [Fintype F] [DecidableEq F] in
/-- A doomed full transcript is rejected, whatever the helpers. -/
theorem logup_final (chal : Dg → F) (T : κ → Tup F) (lu : X → (ι ⊕ (π ⊕ π) → Tup F) × (κ → F)) :
    ∀ x τ H, τ.length = 2 → ¬ luSt chal T lu x τ → ¬ luAccept chal T lu x τ H := by
  intro x τ H _ hns hacc
  unfold luAccept at hacc
  split at hacc
  · simp only [luSt, not_or] at hns
    exact hns.2 ⟨H, hacc⟩
  · exact hacc

variable {Q : Type} [Fintype Q] [DecidableEq Q]

/-- **LogUp under Fiat–Shamir on the code's chain.** A prover making at most `q` hash queries outputs a FALSE LogUp
statement that the chain verifier accepts with probability at most `(q + 7)·luEps + collBound (q + 7) D + collBound (q
+ 8) D`. -/
theorem fs_logup_chain_sound (p : ℕ) [NeZero p] (eF : ZMod p × ZMod p ≃ F) (T : κ → Tup F)
    (lu : X → (ι ⊕ (π ⊕ π) → Tup F) × (κ → F)) (C : ChainEnc (PItem X Unit) Q Dg) (q : ℕ)
    (A : OC Q Dg (X × List Unit × Helpers ι π κ F)) (hA : A.Bounded q) :
    prH (fun H => luFalse (lu (A.run H).1).1 T
        ∧ chainAcceptsW 2 luW luW_pos luMsg () (luAccept (fp2Field p (2 ^ 128) eF) T lu) C H (A.run H).1
            (A.run H).2.1 (A.run H).2.2)
      ≤ ((q + 6 + 1 : ℕ) : ℝ≥0∞) * luEps (ι := ι) (π := π) p T + collBound (q + 6 + 1) Dg
        + collBound (q + 6 + 1 + 1) Dg := by
  have hℓ : ℓW 2 luW = 6 := by decide
  have h := fs_chain_sound_of_rbr_wide (hasMsg := luMsg) (m₀ := ()) luW_pos C (L := fun x => ¬ luFalse (lu x).1 T)
    (luEps (ι := ι) (π := π) p T) (logup_rbrWide p eF T lu) (fun x hx => hx)
    (logup_final (fp2Field p (2 ^ 128) eF) T lu) q A hA
  rw [hℓ] at h
  refine le_trans (MeasureTheory.measure_mono ?_) h
  rintro H ⟨h1, h2⟩
  exact ⟨not_not.mpr h1, h2⟩

end FS

end ZK60.Sound
