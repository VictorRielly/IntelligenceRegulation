/-
D63, step L3 (soundness): the sumcheck under Fiat–Shamir.

`SoundSumcheck.lean` proves the interactive bound `n·d/|F|` (`sumcheck_sound`). Here the same verifier is written on a
transcript list (`scAccept`), shown to be round-by-round sound with the state function "every check so far passed and
the current claim is TRUE" and at most `d` escaping challenges per round (`sumcheck_rbr`), and compiled with
`FSRbr.lean`'s theorem.

The transcript: `[(s_0, r_0), …, (s_{n−1}, r_{n−1})]`, `s_j : Fin (d + 1) → F` the round message in the code's value
form, `r_j` the challenge. The verifier (`scAccept`), as `zkp_core::sumcheck::verify` and its caller run it: in round
`j`, `s_j(0) + s_j(1) = claim_j`, then `claim_{j+1} = interpolate_eval(s_j, r_j)`; after the last round, the
terminal check `claim_n = f(r_0, …, r_{n−1})`. Round `j` fixes variable `j`, the most significant first. That this is
the verifier of `SoundSumcheck.lean` is `scAccept_proverTr`.

The statement. Any type `X` of statements with `stmt x = (f, C)`: the polynomial (`f` of individual degree `≤ d`) and
the claimed sum. A false statement is one with `IndDegLE d f` and `C ≠ Σ_{x ∈ {0,1}^n} f(x)`. The prover chooses the
statement itself, after seeing hash values; it is part of every hash input (`FSEnc`).

What is proved.
* `scAccept_state`, `scState_round`, `sumcheck_rbr`: round-by-round soundness, `d` escaping challenges per round
  (the round step is `sumcheck_one_round`: a false claim and a passing check leave at most `d` challenges that make the
  next claim true).
* `fs_sumcheck_sound`: with challenges `chal (H (prefix))` of at most `K` digests per value, a prover making at most
  `q` hash queries makes the verifier accept a false statement with probability at most `(q + n)·d·K/|D|`.
* `fs_sumcheck_sound_uniform` (`chal = id`): `(q + n)·d/|F|`, against the interactive `n·d/|F|`.
* `fs_sumcheck_sound_code`: with the code's `challenge_fp2` (a 256-bit digest, each 128-bit half reduced mod `p`, `F`
  in bijection with `ZMod p × ZMod p`): `(q + n)·d/|F| · (1 + p/2^128)²`; for `p ≤ 2^64` (Goldilocks)
  `(q + n)·d/|F| · (1 + 2^-64)²` (`fs_sumcheck_sound_goldilocks`).

What is not covered here: the code's transcript is a hash chain, not a hash of the prefix (the same sumcheck on the
chain is `FSChainRbr.lean`'s `fs_sumcheck_chain_sound`); the polynomial
`f` is a value of the statement here, while in a receipt it is the committed tables (the extractor's job). The CFS
mask and the last-round extension turn a false claim into a false statement for this theorem deterministically, for
every `c` (`sumcheck_sound_masked`, `sumcheck_sound_extended`); drawing `c` and running the sumcheck on ONE chain is
the composition of two protocols, which is not stated yet.
-/
import ZK60Formal.FSChallenge
import ZK60Formal.SoundSumcheck

namespace ZK60.Sound

open scoped ENNReal
open Finset

section Transcript

variable {F : Type} [Field F] {d : ℕ}

/-- **The state function**: every round check so far passed, and the current claim is the true sum of the restricted
polynomial (`[]`: the claim `C` is `Σ f`). A transcript longer than `n` is doomed. -/
def scState : List ((Fin (d + 1) → F) × F) → (n : ℕ) → ((Fin n → F) → F) → F → Prop
  | [], _, f, C => C = cubeSum f
  | _ :: _, 0, _, _ => False
  | (s, r) :: τ, n + 1, f, C => s 0 + s 1 = C ∧ scState τ n (fun x => f (Fin.cons r x)) (interpEval s r)

/-- **The verifier on a transcript list**: in each round `s(0) + s(1) = claim`, then the claim `interpEval s r`
about `f` with the variable fixed to `r`; after exactly `n` rounds, the terminal check `claim = f(r)`. -/
def scAccept : List ((Fin (d + 1) → F) × F) → (n : ℕ) → ((Fin n → F) → F) → F → Prop
  | [], 0, f, C => C = f Fin.elim0
  | [], _ + 1, _, _ => False
  | _ :: _, 0, _, _ => False
  | (s, r) :: τ, n + 1, f, C => s 0 + s 1 = C ∧ scAccept τ n (fun x => f (Fin.cons r x)) (interpEval s r)

/-- The transcript an interactive prover strategy (`SoundSumcheck.lean`'s `Prover`) produces against the challenges
`r`. -/
def proverTr : (n : ℕ) → Prover F d n → (Fin n → F) → List ((Fin (d + 1) → F) × F)
  | 0, _, _ => []
  | n + 1, P, r => (P.1, r 0) :: proverTr n (P.2 (r 0)) (Fin.tail r)

/-- **The list verifier is `SoundSumcheck.lean`'s verifier**: on the transcript of a prover strategy it accepts exactly
when `Accepts` does. -/
theorem scAccept_proverTr : ∀ (n : ℕ) (f : (Fin n → F) → F) (C : F) (P : Prover F d n) (r : Fin n → F),
    scAccept (proverTr n P r) n f C ↔ Accepts n f C P r
  | 0, f, C, P, r => Iff.rfl
  | n + 1, f, C, P, r => by
    simp only [proverTr, scAccept, Accepts]
    rw [scAccept_proverTr n]

/-- **An accepted transcript ends in a true state** (the terminal check makes the last claim true). -/
theorem scAccept_state : ∀ (τ : List ((Fin (d + 1) → F) × F)) (n : ℕ) (f : (Fin n → F) → F) (C : F),
    scAccept τ n f C → scState τ n f C
  | [], 0, f, C, h => by
    simp only [scAccept] at h
    simp only [scState, cubeSum_zero]
    exact h
  | [], _ + 1, _, _, h => by simp [scAccept] at h
  | _ :: _, 0, _, _, h => by simp [scAccept] at h
  | (s, r) :: τ, n + 1, f, C, h => by
    simp only [scAccept] at h
    simp only [scState]
    exact ⟨h.1, scAccept_state τ n _ _ h.2⟩

/-- An accepted transcript has exactly `n` rounds. -/
theorem scAccept_length : ∀ (τ : List ((Fin (d + 1) → F) × F)) (n : ℕ) (f : (Fin n → F) → F) (C : F),
    scAccept τ n f C → τ.length = n
  | [], 0, _, _, _ => rfl
  | [], _ + 1, _, _, h => by simp [scAccept] at h
  | _ :: _, 0, _, _, h => by simp [scAccept] at h
  | (s, r) :: τ, n + 1, f, C, h => by
    simp only [scAccept] at h
    simp only [List.length_cons]
    rw [scAccept_length τ n _ _ h.2]

variable [Fintype F] [DecidableEq F]

/-- **One round, round by round.** From a doomed transcript of fewer than `n` rounds (a check already failed, or the
current claim is false), whatever the next message `s`, at most `d` challenges `r` lead to a state that is not doomed.
The step is `sumcheck_one_round`; it needs `f` of individual degree `≤ d` and `d < char F`. -/
theorem scState_round (hd : d < ringChar F) :
    ∀ (τ : List ((Fin (d + 1) → F) × F)) (n : ℕ) (f : (Fin n → F) → F) (C : F), IndDegLE d f →
      τ.length < n → ¬ scState τ n f C → ∀ s : Fin (d + 1) → F,
        EscapesWithin (fun r => scState (τ ++ [(s, r)]) n f C) d
  | [], 0, _, _, _, hlt, _, _ => absurd hlt (Nat.lt_irrefl 0)
  | [], n + 1, f, C, hf, _, hns, s => by
    have hC : C ≠ cubeSum f := by simpa [scState] using hns
    by_cases hs : s 0 + s 1 = C
    · refine ⟨univ.filter (fun r => interpEval s r = cubeSum (fun x => f (Fin.cons r x))),
        sumcheck_one_round hd hf hC s hs, fun r hr => ?_⟩
      simp only [List.nil_append, scState] at hr
      exact mem_filter.mpr ⟨mem_univ _, hr.2⟩
    · refine ⟨∅, by simp, fun r hr => ?_⟩
      simp only [List.nil_append, scState] at hr
      exact absurd hr.1 hs
  | _ :: _, 0, _, _, _, hlt, _, _ => absurd hlt (Nat.not_lt_zero _)
  | (s', r') :: τ, n + 1, f, C, hf, hlt, hns, s => by
    simp only [scState, not_and] at hns
    by_cases hc : s' 0 + s' 1 = C
    · obtain ⟨B, hB, hmem⟩ := scState_round hd τ n (fun x => f (Fin.cons r' x)) (interpEval s' r') (hf.cons r')
        (by simp only [List.length_cons] at hlt; omega) (hns hc) s
      refine ⟨B, hB, fun r hr => hmem r ?_⟩
      simp only [List.cons_append, scState] at hr
      exact hr.2
    · refine ⟨∅, by simp, fun r hr => ?_⟩
      simp only [List.cons_append, scState] at hr
      exact absurd hr.1 hc

/-- **The sumcheck is round-by-round sound** with `d` escaping challenges per round, for statements `stmt x = (f, C)`.
The language: `f` is not of individual degree `≤ d` (no claim is made), or the claim is true. The state function:
`f` outside the promise, or `scState`. -/
theorem sumcheck_rbr {X : Type} {n : ℕ} (hd : d < ringChar F) (stmt : X → ((Fin n → F) → F) × F) :
    RbrSound n (fun x => ¬ IndDegLE d (stmt x).1 ∨ (stmt x).2 = cubeSum (stmt x).1)
      (fun x (τ : List ((Fin (d + 1) → F) × F)) (_ : Unit) => scAccept τ n (stmt x).1 (stmt x).2)
      (fun x (τ : List ((Fin (d + 1) → F) × F)) => ¬ IndDegLE d (stmt x).1 ∨ scState τ n (stmt x).1 (stmt x).2)
      d where
  start x hL := by
    simp only [not_or, not_not] at hL
    simp only [scState, not_or, not_not]
    exact hL
  round x τ s hlt hns := by
    simp only [not_or, not_not] at hns
    obtain ⟨B, hB, hmem⟩ := scState_round hd τ n _ _ hns.1 hlt hns.2 s
    refine ⟨B, hB, fun r hr => hmem r ?_⟩
    exact hr.resolve_left (not_not.mpr hns.1)
  final x τ _ _ hns hacc := by
    simp only [not_or, not_not] at hns
    exact hns.2 (scAccept_state τ n _ _ hacc)

end Transcript

/-! ## The sumcheck under Fiat–Shamir -/

section FS

variable {F : Type} [Field F] [Fintype F] [DecidableEq F] {d : ℕ}
variable {X Q D : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]

/-- **Fiat–Shamir sumcheck soundness.** Challenges `r_j = chal (H (enc x τ_j s_j))`, at most `K` digests per
challenge value. A prover making at most `q` hash queries outputs a statement `x` (with `f` of individual degree
`≤ d` and a FALSE claim `C ≠ Σ f`) and `n` round messages that the verifier accepts, with probability at most
`(q + n)·d·K/|D|`. -/
theorem fs_sumcheck_sound {n : ℕ} (hd : d < ringChar F) (stmt : X → ((Fin n → F) → F) × F)
    (E : FSEnc X (Fin (d + 1) → F) F Q) (chal : D → F) (K : ℕ)
    (hK : ∀ c, (univ.filter (fun dg : D => chal dg = c)).card ≤ K)
    (q : ℕ) (A : OC Q D (X × List (Fin (d + 1) → F) × Unit)) (hA : A.Bounded q) :
    prH (fun H => IndDegLE d (stmt (A.run H).1).1 ∧ (stmt (A.run H).1).2 ≠ cubeSum (stmt (A.run H).1).1
        ∧ scAccept (fsTr E chal H (A.run H).1 [] (A.run H).2.1) n (stmt (A.run H).1).1 (stmt (A.run H).1).2)
      ≤ (((q + n) * (d * K) : ℕ) : ℝ≥0∞) / Fintype.card D := by
  refine le_trans (MeasureTheory.measure_mono ?_) (fs_sound_of_rbr (sumcheck_rbr hd stmt) E chal K hK q A hA)
  rintro H ⟨h1, h2, h3⟩
  refine ⟨fun h => h.elim (fun h' => h' h1) h2, ?_, h3⟩
  have hl := scAccept_length _ _ _ _ h3
  rw [fsTr_length, List.length_nil, zero_add] at hl
  exact hl

/-- **Uniform challenges** (`chal = id`, the digest is the challenge): the Fiat–Shamir sumcheck error is
`(q + n)·d/|F|`; the interactive one (`sumcheck_sound`) is `n·d/|F|`. -/
theorem fs_sumcheck_sound_uniform {n : ℕ} (hd : d < ringChar F) (stmt : X → ((Fin n → F) → F) × F)
    (E : FSEnc X (Fin (d + 1) → F) F Q) (q : ℕ) (A : OC Q F (X × List (Fin (d + 1) → F) × Unit))
    (hA : A.Bounded q) :
    prH (fun H => IndDegLE d (stmt (A.run H).1).1 ∧ (stmt (A.run H).1).2 ≠ cubeSum (stmt (A.run H).1).1
        ∧ scAccept (fsTr E id H (A.run H).1 [] (A.run H).2.1) n (stmt (A.run H).1).1 (stmt (A.run H).1).2)
      ≤ (((q + n) * d : ℕ) : ℝ≥0∞) / Fintype.card F := by
  have : Nonempty F := ⟨0⟩
  refine le_trans (MeasureTheory.measure_mono ?_) (fs_sound_uniform (sumcheck_rbr hd stmt) E q A hA)
  rintro H ⟨h1, h2, h3⟩
  refine ⟨fun h => h.elim (fun h' => h' h1) h2, ?_, h3⟩
  have hl := scAccept_length _ _ _ _ h3
  rw [fsTr_length, List.length_nil, zero_add] at hl
  exact hl

/-- **The sumcheck with the code's `challenge_fp2`.** The digest is 256 bits, read as two 128-bit halves; each is
reduced mod `p`; `ι` reads the pair as a field element (for `Fp2`, `c0 + U·c1`). The Fiat–Shamir error is
`(q + n)·d/|F| · (1 + p/2^128)²`. -/
theorem fs_sumcheck_sound_code {n p : ℕ} [NeZero p] (hd : d < ringChar F) (ι : ZMod p × ZMod p ≃ F)
    (stmt : X → ((Fin n → F) → F) × F) (E : FSEnc X (Fin (d + 1) → F) F Q) (q : ℕ)
    (A : OC Q (Fin (2 ^ 128) × Fin (2 ^ 128)) (X × List (Fin (d + 1) → F) × Unit)) (hA : A.Bounded q) :
    prH (fun H => IndDegLE d (stmt (A.run H).1).1 ∧ (stmt (A.run H).1).2 ≠ cubeSum (stmt (A.run H).1).1
        ∧ scAccept (fsTr E (fp2Field p (2 ^ 128) ι) H (A.run H).1 [] (A.run H).2.1) n (stmt (A.run H).1).1
            (stmt (A.run H).1).2)
      ≤ (((q + n) * d : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2 := by
  have : Nonempty F := ⟨0⟩
  have hF : Fintype.card F = p ^ 2 := by
    rw [← Fintype.card_congr ι, Fintype.card_prod, ZMod.card, sq]
  have h := fs_sound_of_rbr_bias (sumcheck_rbr hd stmt) E (fp2Field p (2 ^ 128) ι) ((2 ^ 128 / p + 1) ^ 2)
    (card_fp2Field_fiber_le (2 ^ 128) p ι) q A hA
  refine le_trans (MeasureTheory.measure_mono ?_) (h.trans ?_)
  · rintro H ⟨h1, h2, h3⟩
    refine ⟨fun h => h.elim (fun h' => h' h1) h2, ?_, h3⟩
    have hl := scAccept_length _ _ _ _ h3
    rw [fsTr_length, List.length_nil, zero_add] at hl
    exact hl
  · gcongr
    exact biasFactor_fp2_le (2 ^ 128) p hF

/-- **Goldilocks** (`p ≤ 2^64`, so `p = 2^64 − 2^32 + 1` qualifies): the Fiat–Shamir sumcheck error with the code's
`challenge_fp2` is at most `(q + n)·d/|F| · (1 + 2^-64)²`. -/
theorem fs_sumcheck_sound_goldilocks {n p : ℕ} [NeZero p] (hp : p ≤ 2 ^ 64) (hd : d < ringChar F)
    (ι : ZMod p × ZMod p ≃ F) (stmt : X → ((Fin n → F) → F) × F) (E : FSEnc X (Fin (d + 1) → F) F Q) (q : ℕ)
    (A : OC Q (Fin (2 ^ 128) × Fin (2 ^ 128)) (X × List (Fin (d + 1) → F) × Unit)) (hA : A.Bounded q) :
    prH (fun H => IndDegLE d (stmt (A.run H).1).1 ∧ (stmt (A.run H).1).2 ≠ cubeSum (stmt (A.run H).1).1
        ∧ scAccept (fsTr E (fp2Field p (2 ^ 128) ι) H (A.run H).1 [] (A.run H).2.1) n (stmt (A.run H).1).1
            (stmt (A.run H).1).2)
      ≤ (((q + n) * d : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (2⁻¹ : ℝ≥0∞) ^ 64) ^ 2 :=
  (fs_sumcheck_sound_code hd ι stmt E q A hA).trans (mul_le_mul' le_rfl (bias_le_two_pow_64 p hp))

end FS

end ZK60.Sound
