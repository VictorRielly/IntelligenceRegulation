/-
D63 lane L21 (2026-11-07), part 5: **the slot algebra an instance plugs into the define schedules** (L13's three-term
host polynomial, `SlotW16Sound.lean`), generic in the slot's cube, clause list and pad planes.

`block_defines_fs_knowledge` composes, on the code's chain, any start claims `Gd` and polynomials `Φ` of a slot's draws
with `(Φ ≡ 0) → Gd`. These are those claims and polynomials for L13's slot forms, with their nonvanishing proved:

* `hostPhi`, `hostGd`, `hostPhi_eq`, **`hostPhi_nonzero`**: a host slot's claim identity at its draws `(ζ, μ_pad, μ)`,
  `τ`, `ν` (the claimed sum `Σ_b hostPoly(b)` minus `Σ_i ν_i·M̃_i(p_i)`, `M_i` the hosted private slots' contractions):
  it is `Z̃(τ) + Σ_i ν_i·D_i` (`host_cubeSum`), and unless every clause and pad plane vanishes on the cube and every
  hosted difference `D_i = (g·h_i)~(p_i) − M̃_i(p_i)` is `0`, some draws make it nonzero (a clause through `μ` and a
  Boolean `τ`, a pad plane through a non-root `ζ` of `padPoly`, a difference through `ν`);
* `zcPhi`, **`zcPhi_nonzero`**: a standalone zero-check's (`SC_LZC`, `SC_TAB`, `SC_IO_*`, claimed sum `0`);
* `privPhi`, **`privPhi_nonzero`**, `privPhi_deg`: a private slot's hosted difference at its claim point (the second
  schedule: `D_i(p_i) = 0` at the drawn point, unless the pointwise identity `g·h_i = M_i` holds), of individual degree
  `1`;
* **`unmask_host`**, `unmask_standalone`: the CFS unmasking. With every claimed sum true of the masked slot polynomials
  (`claimed = Σ poly + c·Σ mask`) and `M`'s `Γ` functionals true (a host's scalar is `c_h·Σ mask_h − Σ_i κ_i·c_i·Σ mask_i`,
  a standalone's `c·Σ mask`), the unmasked identities follow: `Σ poly_h = Σ_i κ_i·Σ poly_i`, `Σ poly = 0`. This is the
  algebra that makes `block_knowledge_mt`'s `OpenTrue` (with the hosts' `Γ` functionals, finding L21-2) necessary.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.SlotW16Sound
import ZK60Formal.SoundMultilinear

set_option autoImplicit false

namespace ZK60.Sound.SlotW16

open Finset Polynomial

section Host

variable {F : Type} [Field F]

/-- **A host slot's claim identity at its draws**: its claimed-sum polynomial minus the hosted slots' true sums. -/
def hostPhi {n m : ℕ} {ι : Type} [Fintype ι] (c : ι → (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F)
    (g : (Fin n → Bool) → F) (h M : Fin 2 → (Fin n → Bool) → F) (P : Fin 2 → Fin n → F)
    (ω : (F × F) × (ι → F)) (τ : Fin n → F) (ν : Fin 2 → F) : F :=
  ∑ b, hostPoly τ (batched c w ω) ν P g h b - ∑ i, ν i * mleAt (M i) (P i)

/-- **The host's start claim**: every clause and pad plane vanishes on the cube, and every hosted difference at its
claim point is `0`. -/
def hostGd {n m : ℕ} {ι : Type} (c : ι → (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F)
    (g : (Fin n → Bool) → F) (h M : Fin 2 → (Fin n → Bool) → F) (P : Fin 2 → Fin n → F) : Prop :=
  (∀ k b, c k b = 0) ∧ (∀ j b, w j b = 0) ∧ ∀ i, mleAt (fun b => g b * h i b) (P i) = mleAt (M i) (P i)

theorem hostPhi_eq {n m : ℕ} {ι : Type} [Fintype ι] (c : ι → (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F)
    (g : (Fin n → Bool) → F) (h M : Fin 2 → (Fin n → Bool) → F) (P : Fin 2 → Fin n → F)
    (ω : (F × F) × (ι → F)) (τ : Fin n → F) (ν : Fin 2 → F) :
    hostPhi c w g h M P ω τ ν = mleAt (batched c w ω) τ
      + ∑ i, ν i * (mleAt (fun b => g b * h i b) (P i) - mleAt (M i) (P i)) := by
  unfold hostPhi
  rw [host_cubeSum, Fin.sum_univ_two, Fin.sum_univ_two, Fin.sum_univ_two]
  ring

/-- The batched relation with zero weights vanishes. -/
theorem batched_zero {B ι : Type} [Fintype ι] {m : ℕ} (c : ι → B → F) (w : Fin m → B → F) (b : B) :
    batched c w ((0, 0), 0) b = 0 := by
  simp [batched]

/-- A nonzero polynomial of degree below the field's size has a non-root. -/
theorem exists_eval_ne_zero [Fintype F] [DecidableEq F] (p : F[X]) (hp : p ≠ 0) (hd : p.natDegree < Fintype.card F) :
    ∃ r, p.eval r ≠ 0 := by
  by_contra hall
  have hall' : ∀ r, p.eval r = 0 := fun r => by
    by_contra hr
    exact hall ⟨r, hr⟩
  have h1 := card_roots_le p hp
  rw [filter_true_of_mem (fun r _ => hall' r), card_univ] at h1
  omega

/-- **Unless the host's start claim holds, some draws make its identity nonzero** (for at most `|F| − 1` pad planes). -/
theorem hostPhi_nonzero [Fintype F] [DecidableEq F] {n m : ℕ} {ι : Type} [Fintype ι] [DecidableEq ι]
    (c : ι → (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F) (g : (Fin n → Bool) → F)
    (h M : Fin 2 → (Fin n → Bool) → F) (P : Fin 2 → Fin n → F) (hm : m < Fintype.card F)
    (hG : ¬ hostGd c w g h M P) : ∃ ω τ ν, hostPhi c w g h M P ω τ ν ≠ 0 := by
  by_cases hD : ∀ i, mleAt (fun b => g b * h i b) (P i) = mleAt (M i) (P i)
  · have hD0 : ∀ ν : Fin 2 → F, ∑ i, ν i * (mleAt (fun b => g b * h i b) (P i) - mleAt (M i) (P i)) = 0 := by
      intro ν
      refine sum_eq_zero (fun i _ => ?_)
      rw [hD i, sub_self, mul_zero]
    by_cases hc : ∀ k b, c k b = 0
    · have hw : ∃ j b, w j b ≠ 0 := by
        by_contra hno
        apply hG
        refine ⟨hc, fun j b => ?_, hD⟩
        by_contra hjb
        exact hno ⟨j, b, hjb⟩
      obtain ⟨j₀, b₀, hb₀⟩ := hw
      obtain ⟨ζ, hζ⟩ := exists_eval_ne_zero (padPoly w b₀) (padPoly_ne w b₀ j₀ hb₀)
        (lt_of_le_of_lt (padPoly_natDegree w b₀) hm)
      refine ⟨((ζ, 1), 0), fun i => bit (b₀ i), 0, ?_⟩
      rw [hostPhi_eq, hD0, add_zero, mleAt_bit]
      have hb : batched c w ((ζ, 1), 0) b₀ = (padPoly w b₀).eval ζ := by
        rw [padPoly_eval]
        simp [batched, hc]
      rw [hb]
      exact hζ
    · have hc' : ∃ k b, c k b ≠ 0 := by
        by_contra hno
        apply hc
        intro k b
        by_contra hkb
        exact hno ⟨k, b, hkb⟩
      obtain ⟨k₀, b₀, hb₀⟩ := hc'
      refine ⟨((0, 0), fun k => if k = k₀ then 1 else 0), fun i => bit (b₀ i), 0, ?_⟩
      rw [hostPhi_eq, hD0, add_zero, mleAt_bit]
      have hb : batched c w ((0, 0), fun k => if k = k₀ then 1 else 0) b₀ = c k₀ b₀ := by
        simp only [batched, zero_mul, add_zero]
        rw [sum_eq_single k₀ (fun k _ hk => by rw [ite_eq_right hk, zero_mul])
          (fun hk => absurd (mem_univ k₀) hk), ite_eq_left rfl, one_mul]
      rw [hb]
      exact hb₀
  · have hD' : ∃ i, mleAt (fun b => g b * h i b) (P i) ≠ mleAt (M i) (P i) := by
      by_contra hno
      apply hD
      intro i
      by_contra hi
      exact hno ⟨i, hi⟩
    obtain ⟨i₀, hi₀⟩ := hD'
    refine ⟨((0, 0), 0), fun _ => 0, fun i => if i = i₀ then 1 else 0, ?_⟩
    rw [hostPhi_eq]
    have hz : batched c w ((0, 0), 0) = fun _ => 0 := funext (fun b => batched_zero c w b)
    have hm0 : mleAt (fun _ : Fin n → Bool => (0 : F)) (fun _ => 0) = 0 := by simp [mleAt]
    rw [hz, hm0, zero_add, sum_eq_single i₀ (fun i _ hi => by rw [ite_eq_right hi, zero_mul])
      (fun hi => absurd (mem_univ i₀) hi), ite_eq_left rfl, one_mul]
    exact sub_ne_zero.mpr hi₀

/-- **A standalone zero-check's identity at its draws** (claimed sum `0`). -/
def zcPhi {n m : ℕ} {ι : Type} [Fintype ι] (c : ι → (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F)
    (ω : (F × F) × (ι → F)) (τ : Fin n → F) : F :=
  mleAt (batched c w ω) τ

/-- **Unless every clause and pad plane vanishes, some draws make the standalone identity nonzero.** -/
theorem zcPhi_nonzero [Fintype F] [DecidableEq F] {n m : ℕ} {ι : Type} [Fintype ι] [DecidableEq ι]
    (c : ι → (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F) (hm : m < Fintype.card F)
    (hG : ¬ ((∀ k b, c k b = 0) ∧ ∀ j b, w j b = 0)) : ∃ ω τ, zcPhi c w ω τ ≠ 0 := by
  by_cases hc : ∀ k b, c k b = 0
  · have hw : ∃ j b, w j b ≠ 0 := by
      by_contra hno
      apply hG
      refine ⟨hc, fun j b => ?_⟩
      by_contra hjb
      exact hno ⟨j, b, hjb⟩
    obtain ⟨j₀, b₀, hb₀⟩ := hw
    obtain ⟨ζ, hζ⟩ := exists_eval_ne_zero (padPoly w b₀) (padPoly_ne w b₀ j₀ hb₀)
      (lt_of_le_of_lt (padPoly_natDegree w b₀) hm)
    refine ⟨((ζ, 1), 0), fun i => bit (b₀ i), ?_⟩
    rw [zcPhi, mleAt_bit]
    have hb : batched c w ((ζ, 1), 0) b₀ = (padPoly w b₀).eval ζ := by
      rw [padPoly_eval]
      simp [batched, hc]
    rw [hb]
    exact hζ
  · have hc' : ∃ k b, c k b ≠ 0 := by
      by_contra hno
      apply hc
      intro k b
      by_contra hkb
      exact hno ⟨k, b, hkb⟩
    obtain ⟨k₀, b₀, hb₀⟩ := hc'
    refine ⟨((0, 0), fun k => if k = k₀ then 1 else 0), fun i => bit (b₀ i), ?_⟩
    rw [zcPhi, mleAt_bit]
    have hb : batched c w ((0, 0), fun k => if k = k₀ then 1 else 0) b₀ = c k₀ b₀ := by
      simp only [batched, zero_mul, add_zero]
      rw [sum_eq_single k₀ (fun k _ hk => by rw [ite_eq_right hk, zero_mul])
        (fun hk => absurd (mem_univ k₀) hk), ite_eq_left rfl, one_mul]
    rw [hb]
    exact hb₀

/-- **`SC_LZC`'s identity with its FIXED helper weight** (finding L13-2: `rel + μ_pad·pad`, the helper relation's
weight the constant `1`, slot_ir.rs:1059): `Z(b) = c(b) + μ_pad·Σ_j ζ^j·w_j(b)` at `τ`. -/
def lzcPhi {n m : ℕ} (c : (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F) (ζ μp : F) (τ : Fin n → F) : F :=
  mleAt (fun b => c b + μp * ∑ j : Fin m, ζ ^ (j : ℕ) * w j b) τ

/-- **The fixed weight is sound for ONE helper relation**: unless it and every pad plane vanish, some draws make the
identity nonzero. (A second `Dom::L` helper relation would need a random weight between the two.) -/
theorem lzcPhi_nonzero [Fintype F] [DecidableEq F] {n m : ℕ} (c : (Fin n → Bool) → F)
    (w : Fin m → (Fin n → Bool) → F) (hm : m < Fintype.card F) (hG : ¬ ((∀ b, c b = 0) ∧ ∀ j b, w j b = 0)) :
    ∃ ζ μp τ, lzcPhi c w ζ μp τ ≠ 0 := by
  by_cases hc : ∀ b, c b = 0
  · have hw : ∃ j b, w j b ≠ 0 := by
      by_contra hno
      apply hG
      refine ⟨hc, fun j b => ?_⟩
      by_contra hjb
      exact hno ⟨j, b, hjb⟩
    obtain ⟨j₀, b₀, hb₀⟩ := hw
    obtain ⟨ζ, hζ⟩ := exists_eval_ne_zero (padPoly w b₀) (padPoly_ne w b₀ j₀ hb₀)
      (lt_of_le_of_lt (padPoly_natDegree w b₀) hm)
    refine ⟨ζ, 1, fun i => bit (b₀ i), ?_⟩
    rw [lzcPhi, mleAt_bit]
    simpa [hc b₀, padPoly_eval] using hζ
  · have hc' : ∃ b, c b ≠ 0 := by
      by_contra hno
      apply hc
      intro b
      by_contra hb
      exact hno ⟨b, hb⟩
    obtain ⟨b₀, hb₀⟩ := hc'
    refine ⟨0, 0, fun i => bit (b₀ i), ?_⟩
    rw [lzcPhi, mleAt_bit]
    simpa using hb₀

/-- **`SC_RS`'s `λ`-batched row claim at its point** (`SlotW16Sound.dens_rowsum`): the two row identities' residuals
`A` (the exp row sum) and `B` (the selector row sum). -/
def rsPhi {n : ℕ} (A B : (Fin n → Bool) → F) (lam : F) (p : Fin n → F) : F := mleAt A p + lam * mleAt B p

/-- **Unless both row identities hold, some draws make the batched row claim nonzero.** -/
theorem rsPhi_nonzero {n : ℕ} (A B : (Fin n → Bool) → F) (hG : ¬ ((∀ b, A b = 0) ∧ ∀ b, B b = 0)) :
    ∃ lam p, rsPhi A B lam p ≠ 0 := by
  by_cases hA : ∀ b, A b = 0
  · have hB : ∃ b, B b ≠ 0 := by
      by_contra hno
      apply hG
      refine ⟨hA, fun b => ?_⟩
      by_contra hb
      exact hno ⟨b, hb⟩
    obtain ⟨b₀, hb₀⟩ := hB
    refine ⟨1, fun i => bit (b₀ i), ?_⟩
    rw [rsPhi, mleAt_bit, mleAt_bit, hA b₀, zero_add, one_mul]
    exact hb₀
  · have hA' : ∃ b, A b ≠ 0 := by
      by_contra hno
      apply hA
      intro b
      by_contra hb
      exact hno ⟨b, hb⟩
    obtain ⟨b₀, hb₀⟩ := hA'
    refine ⟨0, fun i => bit (b₀ i), ?_⟩
    rw [rsPhi, mleAt_bit, zero_mul, add_zero]
    exact hb₀

/-- **A private slot's hosted difference at its claim point.** -/
def privPhi {n : ℕ} (gh M : (Fin n → Bool) → F) (p : Fin n → F) : F := mleAt gh p - mleAt M p

/-- **Unless the hosted identity holds pointwise, some claim point makes the difference nonzero.** -/
theorem privPhi_nonzero {n : ℕ} (gh M : (Fin n → Bool) → F) (hG : ¬ ∀ b, gh b = M b) : ∃ p, privPhi gh M p ≠ 0 := by
  have hb : ∃ b, gh b ≠ M b := by
    by_contra hno
    apply hG
    intro b
    by_contra hb
    exact hno ⟨b, hb⟩
  obtain ⟨b, hb⟩ := hb
  exact ⟨fun i => bit (b i), by rw [privPhi, mleAt_bit, mleAt_bit]; exact sub_ne_zero.mpr hb⟩

/-- The difference is multilinear in the claim point. -/
theorem privPhi_deg {n : ℕ} (gh M : (Fin n → Bool) → F) : IndDegLE 1 (privPhi gh M) := by
  have e : privPhi gh M = fun p => mleAt (fun b => gh b - M b) p := funext (fun p => mleAt_sub gh M p)
  rw [e]
  exact indDegLE_mleAt _

/-! ## The CFS unmasking -/

/-- **A host's unmasked identity** (CFS): its claimed sum `scalar_h + Σ κ_i·scalar_i` is its masked polynomial's sum
`Σ poly_h + c_h·Σ mask_h`; each hosted private slot's claimed sum `scalar_i` is `Σ poly_i + c_i·Σ mask_i`; and `M`'s
`Γ` functional of the host says `scalar_h = c_h·Σ mask_h − Σ κ_i·c_i·Σ mask_i` (`slotAcc`'s `hostFs`). Then
`Σ poly_h = Σ κ_i·Σ poly_i`: the scalars and masks drop out. -/
theorem unmask_host (sh ch mh Sh : F) (κ c m S sc : Fin 2 → F) (hh : sh + ∑ i, κ i * sc i = Sh + ch * mh)
    (hp : ∀ i, sc i = S i + c i * m i) (hΓ : sh = ch * mh - ∑ i, κ i * (c i * m i)) :
    Sh = ∑ i, κ i * S i := by
  rw [Fin.sum_univ_two] at hh hΓ ⊢
  rw [hp 0, hp 1] at hh
  linear_combination hΓ - hh

/-- **A standalone zero-check's unmasked identity**: claimed sum `scalar = Σ poly + c·Σ mask` and `M`'s `Γ` functional
`scalar = c·Σ mask` give `Σ poly = 0`. -/
theorem unmask_standalone (s cc mm Sp : F) (hh : s = Sp + cc * mm) (hΓ : s = cc * mm) : Sp = 0 := by
  linear_combination hΓ - hh

end Host

end ZK60.Sound.SlotW16
