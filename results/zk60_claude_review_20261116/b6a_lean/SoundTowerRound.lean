import ZK60Formal.ThirdParty.FlashProve.Code.Half

/-!
# B6a tower: three counting facts (Claude review, 2026-11-25 UTC)

Companion to Sol's `results/zk60_sol_20261105_w16r3/b6a/B6aFoldSoundness.lean`
(`exceptional_affine_folds`, `unique_successor`). It uses the same objects: `Code.rsCode points
(width - 1)` on `points : Fin length ↪ E`, the radius `e = (length - width) / 2`, agreement on a
set `S` written `∀ i ∈ S, word i = codeword i` with `length ≤ S.card + e`, and `Prob.cnt` for counts.
In the prose (`WP_S_SOUNDNESS_20261124.md`) N = `length`, K = `width`.

1. `switch_far`, `switch_far_radius` (the far/close switch). A word within e of one codeword
   disagrees with every other codeword in at least N - K + 1 - e, hence at least e + 1, positions.
   This is the count the switch uses after `unique_successor` has fixed the decoded codeword.
2. `samples_avoid_pred`, `samples_avoid`, `switch_samples_sharp`, `switch_samples` (the column
   samples). Index tuples `Fin t → Fin N` that miss a set of at least b positions number at most
   (N - b)^t; so at most (N - e - 1)^t (sharper: (K - 1 + e)^t) sample tuples see no disagreement
   between the word and a wrong codeword.
3. `rounds_union`, `rounds_union_finset`, `rounds_union_fixed` (the fold rounds). Over k rounds
   with challenges in a finite E, where round i's exceptional set may depend on the challenges of
   rounds before i and has at most B elements, at most k * B * |E|^(k-1) challenge tuples hit some
   round's exceptional set. With B = N this composes with `exceptional_affine_folds` per round.

Only counts are stated. Nothing probabilistic is claimed (a reader divides by N^t or |E|^k), and
nothing here concerns Fiat-Shamir, hashing or Merkle binding.
-/

namespace ZK60.B6a.SoundTowerRound

open Code Prob

/-! ## 1. The switch count -/

/-- A word that agrees with the codeword `c` on a set `S` of all but at most e positions
disagrees with any other codeword `c'` in at least N - K + 1 - e positions. -/
theorem switch_far {E : Type} [Field E] {length width : ℕ} (points : Fin length ↪ E)
    (positive : 0 < width) (fits : width ≤ length)
    {w c c' : Fin length → E} {S : Finset (Fin length)}
    (hc : c ∈ rsCode points (width - 1)) (hc' : c' ∈ rsCode points (width - 1)) (hne : c' ≠ c)
    (sizeS : length ≤ S.card + (length - width) / 2) (sameS : ∀ i ∈ S, w i = c i) :
    length - width + 1 - (length - width) / 2 ≤ cnt (fun i : Fin length => w i ≠ c' i) := by
  have hd : length - (width - 1) ≤ cnt (fun j : Fin length => (c - c') j ≠ 0) := by
    have h := minDist_rsCode points (width - 1) (c - c')
      ((rsCode points (width - 1)).sub_mem hc hc') (sub_ne_zero.mpr hne.symm)
    rw [Fintype.card_fin] at h
    exact h
  have hsplit : cnt (fun j : Fin length => (c - c') j ≠ 0) ≤
      cnt (fun i : Fin length => w i ≠ c' i) + cnt (fun i : Fin length => i ∉ S) := by
    refine cnt_le_add fun i hi => ?_
    have hi' : (c - c') i ≠ 0 := hi
    by_cases hS : i ∈ S
    · left
      show w i ≠ c' i
      rw [sameS i hS]
      intro h
      apply hi'
      rw [Pi.sub_apply, h, sub_self]
    · exact Or.inr hS
  have hout : cnt (fun i : Fin length => i ∉ S) + S.card ≤ length := by
    have h := cnt_add_card_le (C := Fin length) (P := fun i => i ∉ S) (S := S)
      (fun j hj hn => hn hj)
    rw [Fintype.card_fin] at h
    exact h
  omega

/-- The form the switch quotes: at least e + 1 disagreements. -/
theorem switch_far_radius {E : Type} [Field E] {length width : ℕ} (points : Fin length ↪ E)
    (positive : 0 < width) (fits : width ≤ length)
    {w c c' : Fin length → E} {S : Finset (Fin length)}
    (hc : c ∈ rsCode points (width - 1)) (hc' : c' ∈ rsCode points (width - 1)) (hne : c' ≠ c)
    (sizeS : length ≤ S.card + (length - width) / 2) (sameS : ∀ i ∈ S, w i = c i) :
    (length - width) / 2 + 1 ≤ cnt (fun i : Fin length => w i ≠ c' i) := by
  refine le_trans ?_ (switch_far points positive fits hc hc' hne sizeS sameS)
  omega

/-! ## 2. The column samples -/

/-- Tuples of t positions all of whose entries satisfy `P`, where `P` fails in at least b
positions, number at most (N - b)^t. -/
theorem samples_avoid_pred {length : ℕ} (P : Fin length → Prop) (t b : ℕ)
    (hb : b ≤ cnt (fun i : Fin length => ¬ P i)) :
    cnt (fun s : Fin t → Fin length => ∀ j, P (s j)) ≤ (length - b) ^ t := by
  have h : cnt P + cnt (fun i : Fin length => ¬ P i) = length := by
    have h0 := cnt_add_cnt_not P
    rw [Fintype.card_fin] at h0
    exact h0
  calc cnt (fun s : Fin t → Fin length => ∀ j, P (s j)) = cnt P ^ t := cnt_forall_pow P t
    _ ≤ (length - b) ^ t := Nat.pow_le_pow_left (by omega) t

/-- Index tuples none of whose entries lies in a set `B` of at least b positions number at most
(N - b)^t. -/
theorem samples_avoid {length : ℕ} (t b : ℕ) (B : Finset (Fin length)) (hb : b ≤ B.card) :
    cnt (fun s : Fin t → Fin length => ∀ j, s j ∉ B) ≤ (length - b) ^ t := by
  have hB : cnt (fun i : Fin length => i ∉ B) + B.card ≤ length := by
    have h := cnt_add_card_le (C := Fin length) (P := fun i => i ∉ B) (S := B)
      (fun j hj hn => hn hj)
    rw [Fintype.card_fin] at h
    exact h
  calc cnt (fun s : Fin t → Fin length => ∀ j, s j ∉ B)
      = cnt (fun i : Fin length => i ∉ B) ^ t := cnt_forall_pow (fun i : Fin length => i ∉ B) t
    _ ≤ (length - b) ^ t := Nat.pow_le_pow_left (by omega) t

/-- Items 1 and 2 together, sharp form: under the hypotheses of `switch_far`, at most
(K - 1 + e)^t sample tuples see the word agree with the other codeword at every sample. -/
theorem switch_samples_sharp {E : Type} [Field E] {length width : ℕ} (points : Fin length ↪ E)
    (positive : 0 < width) (fits : width ≤ length)
    {w c c' : Fin length → E} {S : Finset (Fin length)}
    (hc : c ∈ rsCode points (width - 1)) (hc' : c' ∈ rsCode points (width - 1)) (hne : c' ≠ c)
    (sizeS : length ≤ S.card + (length - width) / 2) (sameS : ∀ i ∈ S, w i = c i) (t : ℕ) :
    cnt (fun s : Fin t → Fin length => ∀ j, w (s j) = c' (s j)) ≤
      (width - 1 + (length - width) / 2) ^ t := by
  refine le_trans (samples_avoid_pred (fun i : Fin length => w i = c' i) t
    (length - width + 1 - (length - width) / 2)
    (switch_far points positive fits hc hc' hne sizeS sameS)) ?_
  apply Nat.pow_le_pow_left
  omega

/-- Items 1 and 2 together, in the form of the note: at most (N - e - 1)^t sample tuples. -/
theorem switch_samples {E : Type} [Field E] {length width : ℕ} (points : Fin length ↪ E)
    (positive : 0 < width) (fits : width ≤ length)
    {w c c' : Fin length → E} {S : Finset (Fin length)}
    (hc : c ∈ rsCode points (width - 1)) (hc' : c' ∈ rsCode points (width - 1)) (hne : c' ≠ c)
    (sizeS : length ≤ S.card + (length - width) / 2) (sameS : ∀ i ∈ S, w i = c i) (t : ℕ) :
    cnt (fun s : Fin t → Fin length => ∀ j, w (s j) = c' (s j)) ≤
      (length - (length - width) / 2 - 1) ^ t := by
  refine le_trans (switch_samples_sharp points positive fits hc hc' hne sizeS sameS t) ?_
  apply Nat.pow_le_pow_left
  omega

/-! ## 3. Union over the fold rounds

Round i's exceptional set is `Bad i r`, a property of the challenge of round i, given the whole
challenge tuple `r`. The hypothesis `prefix_only` says that it is the same for any two tuples
that agree in every round j < i. So it is a function of the earlier challenges only: it may not
look at round i's own challenge nor at any later one. That is exactly the round-by-round
situation, where the prover's state before round i (and so the set of challenges that are bad
for it) is fixed by the challenges already drawn. The exceptional set of round i is counted by
`cnt` (at most B values), so `exceptional_affine_folds` (a `cnt` bound by N) plugs in as given. -/

/-- The union bound over k rounds with exceptional sets that depend on earlier challenges. -/
theorem rounds_union {E : Type} [Fintype E] (k B : ℕ)
    (Bad : Fin k → (Fin k → E) → E → Prop)
    (prefix_only : ∀ (i : Fin k) (r r' : Fin k → E), (∀ j, j < i → r j = r' j) →
      Bad i r = Bad i r')
    (small : ∀ i r, cnt (Bad i r) ≤ B) :
    cnt (fun r : Fin k → E => ∃ i, Bad i r (r i)) ≤ k * B * Fintype.card E ^ (k - 1) := by
  have hround : ∀ i : Fin k,
      cnt (fun r : Fin k → E => Bad i r (r i)) ≤ B * Fintype.card E ^ (k - 1) := by
    intro i
    let g : (Fin k → E) ≃ ({j : Fin k // j ≠ i} → E) × E :=
      (Equiv.piSplitAt i (fun _ => E)).trans (Equiv.prodComm _ _)
    -- Two tuples rebuilt from the same rest agree away from round i.
    have key : ∀ (ρ : {j : Fin k // j ≠ i} → E) (x y : E) (j : Fin k), j ≠ i →
        g.symm (ρ, x) j = g.symm (ρ, y) j := by
      intro ρ x y j hj
      have h1 : (g (g.symm (ρ, x))).1 ⟨j, hj⟩ = ρ ⟨j, hj⟩ :=
        congrArg (fun p : ({j : Fin k // j ≠ i} → E) × E => p.1 ⟨j, hj⟩) (g.apply_symm_apply (ρ, x))
      have h2 : (g (g.symm (ρ, y))).1 ⟨j, hj⟩ = ρ ⟨j, hj⟩ :=
        congrArg (fun p : ({j : Fin k // j ≠ i} → E) × E => p.1 ⟨j, hj⟩) (g.apply_symm_apply (ρ, y))
      exact h1.trans h2.symm
    have hcongr : cnt (fun r : Fin k → E => Bad i r (r i)) =
        cnt (fun p : ({j : Fin k // j ≠ i} → E) × E => Bad i (g.symm p) p.2) := by
      refine Eq.trans (cnt_congr fun r => ?_) (cnt_equiv g (fun p => Bad i (g.symm p) p.2))
      show Bad i r (r i) ↔ Bad i (g.symm (g r)) (g r).2
      rw [Equiv.symm_apply_apply]
      exact Iff.rfl
    have hne : Fintype.card {j : Fin k // j ≠ i} = k - 1 := by
      have h := Fintype.card_subtype_compl (fun j : Fin k => j = i)
      simp only [Fintype.card_subtype_eq, Fintype.card_fin] at h
      exact h
    have hcard : Fintype.card ({j : Fin k // j ≠ i} → E) = Fintype.card E ^ (k - 1) := by
      rw [Fintype.card_fun, hne]
    rw [hcongr]
    calc cnt (fun p : ({j : Fin k // j ≠ i} → E) × E => Bad i (g.symm p) p.2)
        ≤ Fintype.card ({j : Fin k // j ≠ i} → E) * B := by
          refine cnt_prod_le (fun p : ({j : Fin k // j ≠ i} → E) × E => Bad i (g.symm p) p.2)
            B fun ρ => ?_
          apply cnt_le_of_forall_finset
          intro Y hY
          rcases Y.eq_empty_or_nonempty with hE | ⟨y, -⟩
          · rw [hE, Finset.card_empty]
            exact Nat.zero_le B
          · refine le_trans (card_le_cnt (P := Bad i (g.symm (ρ, y))) Y fun x hx => ?_)
              (small i (g.symm (ρ, y)))
            have hx' : Bad i (g.symm (ρ, x)) x := hY x hx
            rwa [prefix_only i (g.symm (ρ, x)) (g.symm (ρ, y))
              (fun j hj => key ρ x y j (ne_of_lt hj))] at hx'
      _ = B * Fintype.card E ^ (k - 1) := by rw [hcard, Nat.mul_comm]
  calc cnt (fun r : Fin k → E => ∃ i, Bad i r (r i))
      ≤ Fintype.card (Fin k) * (B * Fintype.card E ^ (k - 1)) :=
        cnt_exists_le_mul (fun i (r : Fin k → E) => Bad i r (r i)) _ hround
    _ = k * B * Fintype.card E ^ (k - 1) := by rw [Fintype.card_fin, Nat.mul_assoc]

/-- The same with the exceptional sets given as finite sets. -/
theorem rounds_union_finset {E : Type} [Fintype E] (k B : ℕ)
    (Bad : Fin k → (Fin k → E) → Finset E)
    (prefix_only : ∀ (i : Fin k) (r r' : Fin k → E), (∀ j, j < i → r j = r' j) →
      Bad i r = Bad i r')
    (small : ∀ i r, (Bad i r).card ≤ B) :
    cnt (fun r : Fin k → E => ∃ i, r i ∈ Bad i r) ≤ k * B * Fintype.card E ^ (k - 1) :=
  rounds_union k B (fun i r x => x ∈ Bad i r)
    (fun i r r' h => by
      show (fun x => x ∈ Bad i r) = (fun x => x ∈ Bad i r')
      rw [prefix_only i r r' h])
    (fun i r => cnt_le_of_forall_finset fun Y hY =>
      le_trans (Finset.card_le_card fun x hx => hY x hx) (small i r))

/-- The non-adaptive special case: fixed exceptional sets. -/
theorem rounds_union_fixed {E : Type} [Fintype E] (k B : ℕ) (Bad : Fin k → Finset E)
    (small : ∀ i, (Bad i).card ≤ B) :
    cnt (fun r : Fin k → E => ∃ i, r i ∈ Bad i) ≤ k * B * Fintype.card E ^ (k - 1) :=
  rounds_union_finset k B (fun i _ => Bad i) (fun _ _ _ _ => rfl) (fun i _ => small i)

#print axioms switch_far
#print axioms switch_far_radius
#print axioms samples_avoid_pred
#print axioms samples_avoid
#print axioms switch_samples_sharp
#print axioms switch_samples
#print axioms rounds_union
#print axioms rounds_union_finset
#print axioms rounds_union_fixed

end ZK60.B6a.SoundTowerRound
