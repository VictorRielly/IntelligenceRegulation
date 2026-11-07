/-
D63 step L13, part 5: **the per-slot soundness of `SlotW16Sound.lean` instantiated on the code's slot polynomials**
(`SlotW16BuildSlots.lean`), and the slots' numerators at the W16R2 8B and Shieldstral shapes.

`SlotW16BuildSlots.lean` proves that each host slot's polynomial, at its terminal values, is `hostTerms`:
`eq(τ)·Z + ν₀·eq(p₁)·(gate·h₁) + ν₁·eq(p₂)·(gate·h₂)`. Here:
* **`hostTerms_hostPoly`**: at a cube point `b`, with the `eq` tables' values `eq(τ, b)`, `eq(p_i, b)` (the verifier's
  `Tab::Eq` at a Boolean point) and the gate's value, `hostTerms` IS `SlotW16Sound.hostPoly τ Z ν p g h b`: the code's
  polynomial (checked equal to the code's IR on a real receipt) is the polynomial the soundness lemmas count;
* **`host_claim_sound`**: `dens_host_hosted` read on that polynomial: if a host slot's relation fails on the committed
  cube (some clause or pad plane nonzero, or a hosted identity `gate·h_i = M_i` false), the host's claimed sum
  `Σ_b hostPoly(b) = Σ_i ν_i·M̃_i(p_i)` holds for at most an `(3n + m + 2)/|F|` share of the challenges
  `(p₁, p₂, ζ, μ_pad, μ, τ, ν)` (`n` the slot's cube, `m` its pad planes);
* **`standalone_claim_sound`**: the same for a standalone zero-check (`SC_LZC`, `SC_TAB`, `SC_IO_*`): `(m + n + 2)/|F|`;
* `hostNum`, **`w16r2_host_num_le`**: at the W16R2 8B T128 and Shieldstral T128 shapes every host slot's numerator is at
  most `3·21 + 64 + 2 = 129` for any pad count `m ≤ 64`; **`host_bound_goldilocks`**: `129/p² ≤ 2^-120`;
* `cstW_map_std`, `dzcIr_map`, **`dzc_code_eval`**: the word the executable verify arm computes as `poly(vals)`
  (`irEvalW`) on the Lean builder's `SC_DZC` IR at the code's words, read in `K`, IS `hostTerms` with `dzcClauses`
  (naturality `Ir.map` ∘ builder = builder at the images, and `toK_irEvalW`).

Only `propext`, `Classical.choice`, `Quot.sound`. The challenges here are uniform and independent (the interactive
protocol). The Fiat–Shamir composition of the slots' `define` draws on the code's chain (L8's
`fs_code_chain_sound_sched`, one wide no-message round per slot) is not proved here (doc §5).
-/
import ZK60Formal.SlotW16BuildSlots
import ZK60Formal.SlotW16Sound
import ZK60Formal.ExecSumcheckFS
import ZK60Formal.SlotW16R2

-- The evaluation proofs try a short list of simp sets (`first | … | …`) and use broad simp sets; Mathlib's style
-- linters flag the alternatives not taken and the simp arguments a branch did not need. Style warnings only.
set_option linter.unusedSimpArgs false
set_option linter.unreachableTactic false
set_option linter.unusedTactic false
set_option linter.unnecessarySeqFocus false


namespace ZK60.Exec.Slot.Compose

open ZK60.Sound ZK60.Sound.SlotW16 ZK60.Exec.Slot.Build
open scoped ENNReal
open Finset

/-! ## The code's host polynomial is `hostPoly` -/

section Bridge

variable {F : Type} [Field F]

/-- **The bridge**: at a cube point `b`, with the `eq` tables' values `eq(τ, b)`, `eq(p₁, b)`, `eq(p₂, b)` and the gate's
value `g(b)`, the code's host terms are `hostPoly`'s integrand. -/
theorem hostTerms_hostPoly {n : ℕ} (v : List F) (tau p1 p2 : ℕ) (gt : Option ℕ) (nu : List F) (z h₁ h₂ : F)
    (τ : Fin n → F) (P : Fin 2 → Fin n → F) (Z g : (Fin n → Bool) → F) (h : Fin 2 → (Fin n → Bool) → F)
    (b : Fin n → Bool) (hτ : v.getD tau 0 = eqPoly τ (fun i => bit (b i)))
    (hp1 : v.getD p1 0 = eqPoly (P 0) (fun i => bit (b i))) (hp2 : v.getD p2 0 = eqPoly (P 1) (fun i => bit (b i)))
    (hg : gV v gt = g b) (hz : z = Z b) (hh1 : h₁ = h 0 b) (hh2 : h₂ = h 1 b) :
    hostTerms v tau p1 p2 gt gt nu z h₁ h₂ = hostPoly τ Z ![nu.getD 0 0, nu.getD 1 0] P g h b := by
  unfold hostTerms hostPoly
  rw [Fin.sum_univ_two, hτ, hp1, hp2, hg, hz, hh1, hh2]
  simp only [Matrix.cons_val_zero, Matrix.cons_val_one, Matrix.head_cons]
  ring

/-- `SC_SZC`'s two hosts carry different gates (`supp(Ht)`, `supp(S)`); the same bridge with one gate per host. -/
theorem hostTerms_hostPoly₂ {n : ℕ} (v : List F) (tau p1 p2 : ℕ) (g₁ g₂ : Option ℕ) (nu : List F) (z h₁ h₂ : F)
    (τ : Fin n → F) (P : Fin 2 → Fin n → F) (Z : (Fin n → Bool) → F) (h : Fin 2 → (Fin n → Bool) → F)
    (b : Fin n → Bool) (hτ : v.getD tau 0 = eqPoly τ (fun i => bit (b i)))
    (hp1 : v.getD p1 0 = eqPoly (P 0) (fun i => bit (b i))) (hp2 : v.getD p2 0 = eqPoly (P 1) (fun i => bit (b i)))
    (hz : z = Z b) (hh1 : gV v g₁ * h₁ = h 0 b) (hh2 : gV v g₂ * h₂ = h 1 b) :
    hostTerms v tau p1 p2 g₁ g₂ nu z h₁ h₂ = hostPoly τ Z ![nu.getD 0 0, nu.getD 1 0] P (fun _ => 1) h b := by
  unfold hostTerms hostPoly
  rw [Fin.sum_univ_two, hτ, hp1, hp2, hz, ← hh1, ← hh2]
  simp only [Matrix.cons_val_zero, Matrix.cons_val_one, Matrix.head_cons]
  ring

end Bridge

/-! ## The per-slot soundness on the code's polynomial -/

section Sound

variable {F : Type} [Field F] [Fintype F] [DecidableEq F]

/-- **A host slot's claim, counted.** The challenges: the hosted slots' claim points `p₁, p₂` (drawn by the private
slots, before the host), then the host's batch `((ζ, μ_pad), μ)`, its point `τ`, its `ν`. If the host's relation fails
on its cube (a clause `c_k` or a pad plane `w_j` nonzero somewhere, or a hosted identity `g·h_i = M_i` false, `M_i` the
private slot's contraction), its claimed sum `Σ_b hostPoly(b) = Σ_i ν_i·M̃_i(p_i)` holds with probability at most
`(n + n + (m + 1 + n + 1))/|F|`. -/
theorem host_claim_sound {n m : ℕ} {ι : Type} [Fintype ι] [DecidableEq ι] (c : ι → (Fin n → Bool) → F)
    (w : Fin m → (Fin n → Bool) → F) (g : (Fin n → Bool) → F) (h M : Fin 2 → (Fin n → Bool) → F)
    (hfail : ¬ ((∀ k b, c k b = 0) ∧ (∀ j b, w j b = 0) ∧ (∀ b, g b * h 0 b = M 0 b) ∧ ∀ b, g b * h 1 b = M 1 b)) :
    (PMF.uniformOfFintype (((Fin n → F) × (Fin n → F)) × ((((F × F) × (ι → F)) × (Fin n → F)) × (Fin 2 → F)))).toOuterMeasure
        {ω | ∑ b, hostPoly ω.2.1.2 (batched c w ω.2.1.1) ω.2.2 ![ω.1.1, ω.1.2] g h b
          = ∑ i, ω.2.2 i * mleAt (M i) (![ω.1.1, ω.1.2] i)}
      ≤ ((n + n + (m + 1 + n + 1) : ℕ) : ℝ≥0∞) / Fintype.card F := by
  classical
  refine le_trans (MeasureTheory.measure_mono ?_)
    (host_hosted_sound c w (fun b => g b * h 0 b) (M 0) (fun b => g b * h 1 b) (M 1) hfail)
  intro ω hω
  simp only [Set.mem_ofPred_eq] at hω ⊢
  have e := (host_claim_iff ω.2.1.2 (batched c w ω.2.1.1) ω.2.2 ![ω.1.1, ω.1.2] g h
    (fun i => mleAt (M i) (![ω.1.1, ω.1.2] i))).mp hω
  rw [Fin.sum_univ_two] at e ⊢
  simpa using e

/-- **A standalone zero-check's claim, counted** (`SC_LZC`, `SC_TAB`, `SC_IO_*`: claimed sum `0`, no hosted term): if
its relation fails on its cube, `Σ_b eq(τ, b)·Z(b) = 0` holds with probability at most `(m + 1 + n)/|F|` over
`((ζ, μ_pad), μ)` and `τ`. -/
theorem standalone_claim_sound {n m : ℕ} {ι : Type} [Fintype ι] [DecidableEq ι] (c : ι → (Fin n → Bool) → F)
    (w : Fin m → (Fin n → Bool) → F) (hfail : (∃ k b, c k b ≠ 0) ∨ (∃ j b, w j b ≠ 0)) :
    (PMF.uniformOfFintype (((F × F) × (ι → F)) × (Fin n → F))).toOuterMeasure
        {ω | ∑ b, eqPoly ω.2 (fun i => bit (b i)) * batched c w ω.1 b = 0}
      ≤ ((m + 1 + n : ℕ) : ℝ≥0∞) / Fintype.card F := by
  classical
  have hd : Dens F (fun ω : ((F × F) × (ι → F)) × (Fin n → F) => mleAt (batched c w ω.1) ω.2 = 0) (m + 1 + n) := by
    refine dens_prod (F := F) _ (fun ω => ∀ b, batched c w ω b = 0) (m + 1) n
      (dens_mono (fun _ h => h) (dens_batchPad c w hfail)) ?_
    intro ω hω
    push Not at hω
    exact dens_mono (fun _ h => h) (dens_mle_zero (batched c w ω) hω)
  refine le_trans (MeasureTheory.measure_mono ?_) (dens_prob hd)
  intro ω hω
  simp only [Set.mem_ofPred_eq] at hω ⊢
  unfold mleAt
  rw [← hω]

end Sound

/-! ## The numerators at the W16R2 shapes -/

open ZK60.Exec.Slot.W16R2

/-- A host slot's numerator: its two hosted points (each on the host's cube), its batch and pad term, its point, `ν`. -/
def hostNum (n m : ℕ) : ℕ := n + n + (m + 1 + n + 1)

/-- The six host slots. -/
def hostSlots : List ℕ := [scTZC, scDZC, scQZC, scKVZC, scSZC, scFZC]

/-- **Every host slot's numerator at the W16R2 8B and Shieldstral shapes** is at most `129` for any pad count `m ≤ 64`
(the slots' cubes are at most `2^21`: `Dom::F`). -/
theorem w16r2_host_num_le (m : ℕ) (hm : m ≤ 64) :
    (∀ s ∈ hostSlots, hostNum (sched sh8B s).1 m ≤ 129) ∧ (∀ s ∈ hostSlots, hostNum (sched shShield s).1 m ≤ 129) := by
  have h8 : ∀ s ∈ hostSlots, (sched sh8B s).1 ≤ 21 := by decide
  have hs : ∀ s ∈ hostSlots, (sched shShield s).1 ≤ 21 := by decide
  refine ⟨fun s hsl => ?_, fun s hsl => ?_⟩
  · have := h8 s hsl
    unfold hostNum
    omega
  · have := hs s hsl
    unfold hostNum
    omega

/-- The host slots' cubes at the 8B shape: `TZC 7`, `DZC 19`, `QZC 19`, `KVZC 17`, `SZC 19`, `FZC 21`. -/
theorem w16r2_8B_host_cubes : hostSlots.map (fun s => (sched sh8B s).1) = [7, 19, 19, 17, 19, 21] := by decide

/-- **At Goldilocks² (`|F| = p²`), a numerator of at most `129` is at most `2^-120`** (a variable `p` within `2^32` below
`2^64`, L7-4). -/
theorem host_bound_goldilocks (p : ℕ) (hp : 2 ^ 64 - 2 ^ 32 ≤ p) (N : ℕ) (hN : N ≤ 129) :
    (N : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) ≤ (2⁻¹ : ℝ≥0∞) ^ 120 := by
  have hp0 : p ^ 2 ≠ 0 := by
    have : 0 < p := lt_of_lt_of_le (by norm_num) hp
    positivity
  calc (N : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) ≤ ((1 : ℕ) : ℝ≥0∞) / ((2 ^ 120 : ℕ) : ℝ≥0∞) := by
        refine ZK60.Exec.natFrac_le hp0 (by positivity) ?_
        calc N * 2 ^ 120 ≤ 129 * 2 ^ 120 := Nat.mul_le_mul_right _ hN
          _ ≤ (2 ^ 64 - 2 ^ 32) ^ 2 := by norm_num
          _ ≤ p ^ 2 := Nat.pow_le_pow_left hp 2
          _ = 1 * p ^ 2 := (one_mul _).symm
    _ = (2⁻¹ : ℝ≥0∞) ^ 120 := by
        rw [Nat.cast_one, one_div, Nat.cast_pow, Nat.cast_ofNat, ENNReal.inv_pow]


/-! ## The code's word computation read in `K` -/

section Code

open ZK60.Exec ZK60.Exec.Slot
open ZK60.Circuit (GF)

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **The code's constants read in `K` are standard** (`Fp2::ONE ↦ 1`, `Fp2::ONE.neg() ↦ −1`, `Fp2::ZERO ↦ 0`). -/
theorem cstW_map_std : (cstW.map (Fp2.toK U)).Std := by
  refine ⟨?_, ?_, ?_⟩
  · exact Fp2.toK_one U
  · show (Fp2.one.neg).toK U = -1
    rw [Fp2.toK_neg U _ Fp2.canon_one, Fp2.toK_one]
  · exact Fp2.toK_zero U

theorem getD_map_f {α β : Type} (f : α → β) : ∀ (l : List α) (n : ℕ) (d : α), (l.map f).getD n (f d) = f (l.getD n d)
  | [], _, _ => rfl
  | _ :: _, 0, _ => rfl
  | _ :: l, n + 1, d => getD_map_f f l n d

/-- **`dzc_w16`'s builder commutes with reading its coefficients elsewhere.** -/
theorem dzcIr_map {α β : Type} (f : α → β) (c : Cst α) (Rr : DzcR) (K' : DzcK) (lks : List (LkD α)) (mu nu : List α)
    (zp : ℕ → α) (groups : List (ℕ × List ℕ)) :
    (dzcIr c Rr K' lks mu nu zp groups).map f
      = dzcIr (c.map f) Rr K' (lks.map (LkD.map f)) (mu.map f) (nu.map f) (f ∘ zp) groups := by
  unfold dzcIr
  rw [zcIr_map]
  simp only [dzcPre, dzcPost, threeTerms, gatedSt, limbs16B, reqB, batchB, st, List.map_cons, List.map_nil,
    Body.map, SubTerm.map, Term.map, Cst.map, List.map_map, Function.comp_def, getD_map_f, List.length_map,
    Option.map_map] <;> rfl

/-- **The verifier's `poly(vals)` at `SC_DZC`, read in `K`**: the word the executable verify arm computes
(`irEvalW`, `slotVerifyW`'s `polyVal`) on the IR the Lean builder produces at the code's words (`SlotW16BuildCheck`
compares it with the code's) is `hostTerms` with the named clause list, read in `K`. -/
theorem dzc_code_eval (hU : U ^ 2 = algebraMap GF K 7) (Rr : DzcR) (K' : DzcK) (lks : List (LkD Fp2)) (mu nu : List Fp2) (zp : ℕ → Fp2)
    (groups : List (ℕ × List ℕ)) (hir : (dzcIr cstW Rr K' lks mu nu zp groups).Canon) (v : List Fp2) :
    (irEvalW (dzcIr cstW Rr K' lks mu nu zp groups) v).toK U
      = let c := cstW.map (Fp2.toK U)
        let w := v.map (Fp2.toK U)
        let m := mu.map (Fp2.toK U)
        hostTerms w Rr.tau Rr.pa Rr.pz Rr.gate Rr.gate (nu.map (Fp2.toK U))
          (logupSem c w Rr.h0 (fun k => m.getD (6 + k) 0) 0 (lks.map (LkD.map (Fp2.toK U)))
            + padSem c w (m.getD (6 + ((lks.map (LkD.map (Fp2.toK U))).length + 1) / 2) 0) (Fp2.toK U ∘ zp) 0 groups
            + gV w Rr.gate * batchV m (dzcClauses c Rr K' w))
          (reqV c w K'.sao Rr.ao Rr.ral) (reqV c w K'.sdown Rr.z Rr.rdl) := by
  rw [toK_irEvalW U hU _ hir, dzcIr_map, dzcIr_eval _ (cstW_map_std U)]

end Code

end ZK60.Exec.Slot.Compose
