/-
D63, step L3 (soundness): the zero-check composed with its sumcheck on ONE chain, with every premise of the
composition PROVED (a worked instance of `FSCompose.lean`).

`SoundZeroCheck.lean`'s `zerocheck_sound` is the interactive bound: `τ`, then the sumcheck of `eq(τ, ·)·R` on the claim
`0`, accepted for a relation `R` that is nonzero somewhere on the cube with probability at most
`(n + n·(d + 1))/|F|`, the SUM of the `τ` term and the rounds' terms. Here the two run as one schedule on the code's chain
(`zcSched`): the `τ` round (`mleSP`, `ℓ = n` squeezes, no message) hands its claim to the sumcheck (`sumcheckSP`, `n`
rounds of degree `d + 1`), whose statement reads `τ` off the transcript before its window (`zcPoint`).

**What is proved.**
* `zc_handover`: when the `τ` round leaves the claim false (`mleAt R τ ≠ 0`), the sumcheck's claim
  `Σ_x eq(τ, x)·R(x) = 0` is false (`cubeSum_eq_mul`): the reduction hands its doom forward.
* `zc_frame`, `zc_start`, `zc_final`: the three premises of `fs_chain_sound_sched`, for this schedule.
* `fs_zerocheck_chain_sound`: a prover making at most `q` hash queries gets the chain verifier to accept a relation
  that is nonzero somewhere on the cube with probability at most
  `T·max(n/|F|·(1 + p/2^128)^(2n), (d + 1)/|F|·(1 + p/2^128)²) + collBound T + collBound (T + 1)`,
  `T = q + ℓW + 1`. Per hash query: the MAXIMUM of the `τ` term and one round's term, where the interactive bound adds
  `n` of the latter to the former.

**What this does not cover.** `R` is a value of the statement (in a receipt it is built from committed tables: the
extraction); the slot's batching, its CFS coefficient and its hand-off to the openings are `FSComposeBlock.lean`'s
premises.
-/
import ZK60Formal.FSComposeBlock

set_option autoImplicit false

namespace ZK60.Sound

open scoped ENNReal
open Finset

section ZeroCheck

variable {F : Type} [Field F] [Fintype F] [DecidableEq F] {d n : ℕ} {X : Type}

/-- **The zero-check point** read off the transcript before the sumcheck: the `τ` round's digests. -/
def zcPoint (p : ℕ) (ι : ZMod p × ZMod p ≃ F) (d₀ : Dg) : List ((Fin (d + 2) → F) × List Dg) → Fin n → F
  | [(_, ds)] => fun j => fp2Field p (2 ^ 128) ι (vecOf d₀ n ds j)
  | _ => fun _ => 0

/-- **The sumcheck's statement**: `eq(τ, ·)·R` with the claim `0`. -/
def zcStmt (p : ℕ) (ι : ZMod p × ZMod p ≃ F) (d₀ : Dg) (R : X → (Fin n → F) → F)
    (y : X × List ((Fin (d + 2) → F) × List Dg)) : ((Fin n → F) → F) × F :=
  (fun z => eqPoly (zcPoint (d := d) p ι d₀ y.2) z * R y.1 z, 0)

/-- `R`'s values on the cube, as the `τ` round's table. -/
def zcTable (R : X → (Fin n → F) → F) (y : X × List ((Fin (d + 2) → F) × List Dg)) (b : Fin n → Bool) : F :=
  R y.1 (fun i => bit (b i))

/-- The `τ` round: `R`'s cube values vanish, then their multilinear extension vanishes at `τ`. -/
noncomputable def zcC0 (p : ℕ) [NeZero p] (ι : ZMod p × ZMod p ≃ F) (R : X → (Fin n → F) → F) (d₀ : Dg) :
    SubProt X (Fin (d + 2) → F) Dg :=
  mleSP (ℓ := n) p ι (zcTable (d := d) R) d₀ false (fun _ _ => True) (fun _ _ => True)

/-- The sumcheck of `eq(τ, ·)·R` on the claim `0`, round degree `d + 1`. -/
noncomputable def zcC1 (p : ℕ) [NeZero p] (hd : d + 1 < ringChar F) (ι : ZMod p × ZMod p ≃ F)
    (R : X → (Fin n → F) → F) (d₀ : Dg) : SubProt X (Fin (d + 2) → F) Dg :=
  sumcheckSP (d := d + 1) (n := n) p hd ι (zcStmt p ι d₀ R) id d₀ (fun _ _ => True) (fun _ _ => True)

/-- **The zero-check's schedule**: the `τ` round, then the sumcheck. -/
noncomputable def zcSched (p : ℕ) [NeZero p] (hd : d + 1 < ringChar F) (ι : ZMod p × ZMod p ≃ F)
    (R : X → (Fin n → F) → F) (d₀ : Dg) : List (SubProt X (Fin (d + 2) → F) Dg) :=
  [zcC0 p ι R d₀, zcC1 p hd ι R d₀]

/-- **The zero-check's verifier**: the sumcheck's verifier on the rounds after `τ`, for `eq(τ, ·)·R` and the claim `0`. -/
def zcAccept (p : ℕ) (ι : ZMod p × ZMod p ≃ F) (R : X → (Fin n → F) → F) (d₀ : Dg) (x : X)
    (τ : List ((Fin (d + 2) → F) × List Dg)) (_ : Unit) : Prop :=
  scAccept (chalTr (fp2Field p (2 ^ 128) ι) d₀ (τ.drop 1)) n (zcStmt (d := d) p ι d₀ R (x, τ.take 1)).1
    (zcStmt (d := d) p ι d₀ R (x, τ.take 1)).2

variable (p : ℕ) [NeZero p] (hd : d + 1 < ringChar F) (ι : ZMod p × ZMod p ≃ F) (R : X → (Fin n → F) → F)
  (d₀ : Dg)

/-- The schedule has `1 + n` rounds. -/
theorem zc_nOf : nOf (zcSched p hd ι R d₀) = 1 + n := rfl

/-- The `τ` round's state, in its window: before it, `R` vanishes on the cube; after it, its extension at `τ`. -/
theorem zc_S0 (x : X) (τ : List ((Fin (d + 2) → F) × List Dg)) (h : τ.length ≤ 1) :
    SOf (zcSched p hd ι R d₀) 0 x τ ↔ mleSt p ι (zcTable (d := d) R) d₀ (x, []) τ := by
  rw [SOf_win (cs := zcSched p hd ι R d₀) (k := 0) (c := zcC0 p ι R d₀) rfl x τ (Nat.zero_le _) h]
  rfl

/-- The sumcheck's state, in its window. -/
theorem zc_S1 (x : X) (τ : List ((Fin (d + 2) → F) × List Dg)) (h1 : 1 ≤ τ.length) (h2 : τ.length ≤ 1 + n) :
    SOf (zcSched p hd ι R d₀) 1 x τ
      ↔ scStW (d := d + 1) p ι (zcStmt p ι d₀ R) d₀ (x, τ.take 1) ((τ.drop 1).map (fun e => (id e.1, e.2))) := by
  rw [SOf_win (cs := zcSched p hd ι R d₀) (k := 1) (c := zcC1 p hd ι R d₀) rfl x τ h1 h2]
  rfl

/-- **The hand-off.** If the `τ` round leaves the claim false (`R`'s extension at `τ` is nonzero), the sumcheck's claim
`Σ_x eq(τ, x)·R(x) = 0` is false. -/
theorem zc_handover (hR : ∀ x, IndDegLE d (R x)) (x : X) (τ : List ((Fin (d + 2) → F) × List Dg))
    (hτ : τ.length = 1) (h0 : ¬ SOf (zcSched p hd ι R d₀) 0 x τ) : ¬ SOf (zcSched p hd ι R d₀) 1 x τ := by
  obtain ⟨⟨m, ds⟩, rfl⟩ : ∃ e, τ = [e] := List.length_eq_one_iff.mp hτ
  rw [zc_S0 p hd ι R d₀ x _ (by simp)] at h0
  rw [zc_S1 p hd ι R d₀ x _ (by simp) (by simp)]
  simp only [mleSt] at h0
  simp only [scStW, List.take_succ_cons, List.take_zero, List.drop_succ_cons, List.drop_zero, List.map_nil,
    chalTr, scState, not_or, not_not]
  refine ⟨(hR x).eq_mul _, fun h => h0 ?_⟩
  simp only [zcStmt] at h
  rw [cubeSum_eq_mul] at h
  exact h.symm

/-- **The frame condition**: the sumcheck is not started during `τ`'s round, and once `τ`'s round is over its state
is released only when the sumcheck has taken over its doom. -/
theorem zc_frame (hR : ∀ x, IndDegLE d (R x)) :
    ∀ k x τ m (b : Fin (wOf (zcSched p hd ι R d₀) τ.length) → Dg), τ.length < nOf (zcSched p hd ι R d₀) →
      ownOf (zcSched p hd ι R d₀) τ.length ≠ k → ¬ SOf (zcSched p hd ι R d₀) k x τ →
      SOf (zcSched p hd ι R d₀) k x (τ ++ [(m, List.ofFn b)]) → ∃ k', k < k' ∧ ¬ SOf (zcSched p hd ι R d₀) k' x τ := by
  intro k x τ m b hlt hown hns _
  rw [zc_nOf] at hlt
  rcases k with _ | _ | k
  · -- the `τ` round's state, after its window
    have h1 : 1 ≤ τ.length := by
      by_contra h0
      have : τ.length = 0 := by omega
      exact hown (by rw [this]; rfl)
    rcases Nat.lt_or_ge 1 τ.length with h | h
    · exact absurd ((SOf_post (cs := zcSched p hd ι R d₀) (k := 0) (c := zcC0 p ι R d₀) rfl x τ h).mpr trivial) hns
    · exact ⟨1, Nat.zero_lt_one, zc_handover p hd ι R d₀ hR x τ (by omega) hns⟩
  · -- the sumcheck's state, before its window
    have h0 : τ.length < 1 := by
      by_contra h1
      exact hown (ownOf_eq_of_window (zcSched p hd ι R d₀) 1 τ.length (zcC1 p hd ι R d₀) rfl
        (by show 1 ≤ τ.length; omega) (by show τ.length < 1 + n; omega))
    exact absurd ((SOf_pend (cs := zcSched p hd ι R d₀) (k := 1) (c := zcC1 p hd ι R d₀) rfl x τ h0).mpr trivial) hns
  · exact absurd (SOf_none (cs := zcSched p hd ι R d₀) (k := k + 1 + 1)
      (by simp only [zcSched, List.length_cons, List.length_nil]; omega) x τ) hns

/-- **The start condition**: a relation nonzero somewhere on the cube dooms the `τ` round at the start. -/
theorem zc_start (x : X) (hx : ¬ ∀ b : Fin n → Bool, R x (fun i => bit (b i)) = 0) :
    ∃ k, ¬ SOf (zcSched p hd ι R d₀) k x [] :=
  ⟨0, by rw [zc_S0 p hd ι R d₀ x [] (Nat.zero_le _)]; exact hx⟩

/-- **The final condition**: a doomed end is rejected by the sumcheck's verifier. -/
theorem zc_final (hR : ∀ x, IndDegLE d (R x)) (x : X) (τ : List ((Fin (d + 2) → F) × List Dg)) (mf : Unit)
    (hl : τ.length = nOf (zcSched p hd ι R d₀)) (hd' : ∃ k, ¬ SOf (zcSched p hd ι R d₀) k x τ) :
    ¬ zcAccept (d := d) p ι R d₀ x τ mf := by
  rw [zc_nOf] at hl
  have h1 : ¬ SOf (zcSched p hd ι R d₀) 1 x τ := by
    obtain ⟨k, hk⟩ := hd'
    rcases k with _ | _ | k
    · rcases Nat.lt_or_ge 1 τ.length with h | h
      · exact absurd ((SOf_post (cs := zcSched p hd ι R d₀) (k := 0) (c := zcC0 p ι R d₀) rfl x τ h).mpr trivial) hk
      · exact zc_handover p hd ι R d₀ hR x τ (by omega) hk
    · exact hk
    · exact absurd (SOf_none (cs := zcSched p hd ι R d₀) (k := k + 1 + 1)
      (by simp only [zcSched, List.length_cons, List.length_nil]; omega) x τ) hk
  rw [zc_S1 p hd ι R d₀ x τ (by omega) (by omega)] at h1
  intro hacc
  apply h1
  have hmap : (τ.drop 1).map (fun e : (Fin (d + 2) → F) × List Dg => (id e.1, e.2)) = τ.drop 1 := by
    simp
  rw [scStW, hmap]
  exact Or.inr (scAccept_state _ _ _ _ hacc)

/-- Both sub-protocols squeeze at least once per round (`n ≥ 1`). -/
theorem zc_wpos (hn : 0 < n) : ∀ c ∈ zcSched p hd ι R d₀, ∀ i, 0 < c.w i := by
  intro c hc
  simp only [zcSched, List.mem_cons, List.not_mem_nil, or_false] at hc
  rcases hc with rfl | rfl
  · exact fun _ => hn
  · exact fun _ => one_pos

variable {Q : Type} [Fintype Q] [DecidableEq Q]

/-- **The zero-check on the code's chain, composed with its sumcheck.** A prover making at most `q` hash queries gets
the chain verifier to accept a relation `R` (individual degree `≤ d`) that is NONZERO somewhere on the cube with
probability at most `T·max(n/|F|·(1 + p/2^128)^(2n), (d + 1)/|F|·(1 + p/2^128)²) + collBound T + collBound (T + 1)`,
`T = q + ℓW + 1`. Every premise of the composition is proved here. -/
theorem fs_zerocheck_chain_sound (hR : ∀ x, IndDegLE d (R x)) (hn : 0 < n) {m₀ : Fin (d + 2) → F}
    (C : ChainEnc (PItem X (Fin (d + 2) → F)) Q Dg) (q : ℕ)
    (A : OC Q Dg (X × List (Fin (d + 2) → F) × Unit)) (hA : A.Bounded q) :
    prH (fun H => ¬ (∀ b : Fin n → Bool, R (A.run H).1 (fun i => bit (b i)) = 0)
        ∧ chainAcceptsW (nOf (zcSched p hd ι R d₀)) (wOf (zcSched p hd ι R d₀))
          (wOf_pos _ (zc_wpos p hd ι R d₀ hn))
          (msgOf (zcSched p hd ι R d₀)) m₀ (zcAccept (d := d) p ι R d₀) C H (A.run H).1 (A.run H).2.1
          (A.run H).2.2)
      ≤ ((q + ℓW (nOf (zcSched p hd ι R d₀)) (wOf (zcSched p hd ι R d₀)) + 1 : ℕ) : ℝ≥0∞)
          * max ((n : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * n))
            (((d + 1 : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2)
        + collBound (q + ℓW (nOf (zcSched p hd ι R d₀)) (wOf (zcSched p hd ι R d₀)) + 1) Dg
        + collBound (q + ℓW (nOf (zcSched p hd ι R d₀)) (wOf (zcSched p hd ι R d₀)) + 1 + 1) Dg := by
  refine fs_chain_sound_sched (zcSched p hd ι R d₀) (zc_wpos p hd ι R d₀ hn) C
    (L := fun x => ∀ b : Fin n → Bool, R x (fun i => bit (b i)) = 0) _ ?_ (zc_frame p hd ι R d₀ hR)
    (fun x hx => zc_start p hd ι R d₀ x hx) (zc_final p hd ι R d₀ hR) q A hA
  intro c hc
  simp only [zcSched, List.mem_cons, List.not_mem_nil, or_false] at hc
  rcases hc with rfl | rfl
  · exact le_max_left _ _
  · exact le_max_right _ _

end ZeroCheck

end ZK60.Sound
