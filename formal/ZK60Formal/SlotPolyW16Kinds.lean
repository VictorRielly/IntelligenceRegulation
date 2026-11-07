/-
D63 lane L23 (2026-11-07), part 4: **the W16R2 slots' identities as polynomials of their draw vectors, by kind**
(generic in the slot's cube, clauses and pad planes; L21's `hostPhi`, `zcPhi`, `lzcPhi`, `rsPhi`, `privPhi`).

A define schedule (`DefSched`) takes, per slot, a polynomial `Φ` of the slot's draw vector with `(Φ ≡ 0) → Gd` (`hΦ`)
and an individual degree (`hdeg`). L21's `hostPhiAt` reads every draw at a coordinate; a W16R2 slot without a pad term
draws no `ζ` and no `μ_pad` (L11's `draws`: `p = 0`), and a private slot's claim point may begin with coordinates drawn
by ANOTHER slot (`SC_KMM`, `SC_VMM` reuse `SC_QMM`'s `r_q`; `SC_UMM` reuses `SC_GMM`'s `r_tf`; finding L23-2). This file
gives each kind's `Φ` with readers, its degree, and its nonvanishing:

* `exists_assign`, `sum_elim_inj`: values at injectively placed coordinates can be written independently;
* `batchedR_deg`, `hostPhiR`, **`hostPhiR_deg`** (`≤ m + 2`), `batched_pad0`, **`hostPhiR_nonzero`**: a host (`SC_TZC`, `SC_DZC`,
  `SC_QZC`, `SC_KVZC`, `SC_SZC`, `SC_FZC`) with the pad readers either coordinates or the constant `0` (then `m = 0`);
  the gate folded into the hosted values (`g = 1`, `h_i = gate_i·host_i`: `SC_SZC`'s two gates);
* `zcPhiR`, **`zcPhiR_deg`**, **`zcPhiR_nonzero`**: a standalone batched zero-check (`SC_TAB`);
* `lzcPhiR`, **`lzcPhiR_deg`**, **`lzcPhiR_nonzero`**: `SC_LZC` with its fixed helper weight (L13-2);
* `zsPhi`, `zsPhi_deg`, `zsPhi_nonzero`: `SC_ZS` draws nothing; its identity `Σ u = 0` is a constant;
* `privPhiR`, **`privPhiR_deg`**, **`privPhiR_nonzero`**: a private slot at its own claim point;
* `privPartPhi`, **`privPartPhi_deg`**, **`privPartPhi_nonzero`**: a private slot whose claim point starts with an
  earlier slot's coordinates `r` (its start claim: the partial extension at `r` vanishes on the rest of the cube);
* `mle2_split`, `crossPhi`, **`crossPhi_deg`**, **`crossPhi_nonzero`**, **`crossPhi_van`**: the drawing slot's layer
  for such a relation (its own `r` and a free block of its own coordinates; it vanishes once the partial claim holds);
* `rsPhiR`, **`rsPhiR_deg`**, **`rsPhiR_nonzero`**: `SC_RS`'s `λ`-batched row claim.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RelW16HostDeg

set_option autoImplicit false

namespace ZK60.Sound.SlotW16

open Finset Polynomial

section Kinds

variable {F : Type} [Field F]

/-! ## Writing values at coordinates -/

/-- **Values at injectively placed coordinates can be written independently.** -/
theorem exists_assign {D : ℕ} {ι : Type} (σ : ι → Fin D) (hσ : Function.Injective σ) (v : ι → F) :
    ∃ x : Fin D → F, ∀ i, x (σ i) = v i := by
  classical
  refine ⟨fun j => if h : ∃ i, σ i = j then v h.choose else 0, fun i => ?_⟩
  have h : ∃ i', σ i' = σ i := ⟨i, rfl⟩
  show (if h : ∃ i', σ i' = σ i then v h.choose else 0) = v i
  rw [dite_eq_left h]
  exact congrArg v (hσ h.choose_spec)

/-- Two injective coordinate maps with disjoint images give an injective map on the sum. -/
theorem sum_elim_inj {α β γ : Type} (f : α → γ) (g : β → γ) (hf : Function.Injective f)
    (hg : Function.Injective g) (hfg : ∀ a b, f a ≠ g b) : Function.Injective (Sum.elim f g) := by
  intro x y h
  cases x with
  | inl a =>
    cases y with
    | inl a' => exact congrArg Sum.inl (hf h)
    | inr b' => exact absurd h (hfg a b')
  | inr b =>
    cases y with
    | inl a' => exact absurd h.symm (hfg a' b)
    | inr b' => exact congrArg Sum.inr (hg h)

/-- A constant has every individual degree. -/
theorem indDeg_const0 {N : ℕ} (d : ℕ) (c : F) : IndDegLE d (fun _ : Fin N → F => c) :=
  ZK60.StageX.IndDegLE.const c

/-! ## A host slot -/

/-- **A host's identity with readers for `ζ` and `μ_pad`** (a coordinate of the draw vector, or the constant `0` where
the slot has no pad term) and coordinates for `μ`, `τ`, `ν`; the gates folded into the hosted values. -/
def hostPhiR {n m D nc : ℕ} (c : Fin nc → (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F)
    (h M : Fin 2 → (Fin n → Bool) → F) (P : Fin 2 → Fin n → F) (rz rp : (Fin D → F) → F)
    (iμ : Fin nc → Fin D) (iτ : Fin n → Fin D) (iν : Fin 2 → Fin D) (x : Fin D → F) : F :=
  hostPhi c w (fun _ => 1) h M P ((rz x, rp x), fun k => x (iμ k)) (fun i => x (iτ i)) (fun i => x (iν i))

/-- The batched relation at a cube point, read off the draw vector: individual degree at most `m + 1`. -/
theorem batchedR_deg {B : Type} {m D nc : ℕ} (c : Fin nc → B → F) (w : Fin m → B → F) (rz rp : (Fin D → F) → F)
    (iμ : Fin nc → Fin D) (hz : IndDegLE 1 rz) (hp : IndDegLE 1 rp) (b : B) :
    IndDegLE (m + 1) (fun x : Fin D → F => batched c w ((rz x, rp x), fun k => x (iμ k)) b) := by
  have h1 : IndDegLE (m + 1) (fun x : Fin D → F => ∑ k, x (iμ k) * c k b) := by
    refine indDeg_sum (fun k => ?_)
    exact ZK60.StageX.IndDegLE.mono
      (ZK60.StageX.IndDegLE.mul (indDeg_coord (iμ k)) (ZK60.StageX.IndDegLE.const (d := 0) (c k b))) (by omega)
  have h2 : IndDegLE m (fun x : Fin D → F => ∑ j : Fin m, rz x ^ (j : ℕ) * w j b) := by
    refine indDeg_sum (fun j => ?_)
    refine ZK60.StageX.IndDegLE.mono (ZK60.StageX.IndDegLE.mul (indDeg_pow hz (j : ℕ))
      (ZK60.StageX.IndDegLE.const (d := 0) (w j b))) ?_
    have := j.isLt
    omega
  have h3 : IndDegLE (m + 1) (fun x : Fin D → F => rp x * ∑ j : Fin m, rz x ^ (j : ℕ) * w j b) :=
    ZK60.StageX.IndDegLE.mono (ZK60.StageX.IndDegLE.mul hp h2) (by omega)
  exact ZK60.StageX.IndDegLE.add h1 h3

/-- **A host's identity has individual degree at most `m + 2`** for readers of degree `≤ 1` and `τ` at distinct
coordinates. -/
theorem hostPhiR_deg {n m D nc : ℕ} (c : Fin nc → (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F)
    (h M : Fin 2 → (Fin n → Bool) → F) (P : Fin 2 → Fin n → F) (rz rp : (Fin D → F) → F)
    (iμ : Fin nc → Fin D) (iτ : Fin n → Fin D) (iν : Fin 2 → Fin D)
    (hz : IndDegLE 1 rz) (hp : IndDegLE 1 rp) (hτ : Function.Injective iτ) :
    IndDegLE (m + 2) (hostPhiR c w h M P rz rp iμ iτ iν) := by
  have hb := batchedR_deg c w rz rp iμ hz hp
  have heq : ∀ b : Fin n → Bool, IndDegLE 1 (fun x : Fin D → F => eqPoly (fun i => x (iτ i)) (fun i => bit (b i))) :=
    fun b => indDeg_sel (indDeg_eqPoly_bit b) iτ hτ
  have e : hostPhiR c w h M P rz rp iμ iτ iν = fun x => (∑ b : Fin n → Bool, eqPoly (fun i => x (iτ i))
      (fun i => bit (b i)) * batched c w ((rz x, rp x), fun k => x (iμ k)) b)
      + ∑ i, x (iν i) * (mleAt (fun b => (fun _ => (1 : F)) b * h i b) (P i) - mleAt (M i) (P i)) := by
    funext x
    simp only [hostPhiR, hostPhi_eq, mleAt]
  rw [e]
  refine ZK60.StageX.IndDegLE.add ?_ ?_
  · refine indDeg_sum (fun b => ?_)
    have := ZK60.StageX.IndDegLE.mul (heq b) (hb b)
    rw [show 1 + (m + 1) = m + 2 by omega] at this
    exact this
  · refine indDeg_sum (fun i => ?_)
    exact ZK60.StageX.IndDegLE.mono (ZK60.StageX.IndDegLE.mul (indDeg_coord (iν i))
      (ZK60.StageX.IndDegLE.const (d := 0) _)) (by omega)

/-- Without pad planes the batched relation does not read `ζ`, `μ_pad`. -/
theorem batched_pad0 {B ι : Type} [Fintype ι] (c : ι → B → F) (w : Fin 0 → B → F) (ω : (F × F) × (ι → F)) (b : B) :
    batched c w ω b = batched c w ((0, 0), ω.2) b := by
  simp [batched]

/-- **Unless the host's start claim holds, some draw vector makes its identity nonzero**, given that the readers can
take any values (`hsec`; where the slot has no pad term, only the pad values `(0, 0)` are needed). -/
theorem hostPhiR_nonzero [Fintype F] [DecidableEq F] {n m D nc : ℕ} (c : Fin nc → (Fin n → Bool) → F)
    (w : Fin m → (Fin n → Bool) → F) (h M : Fin 2 → (Fin n → Bool) → F) (P : Fin 2 → Fin n → F)
    (rz rp : (Fin D → F) → F) (iμ : Fin nc → Fin D) (iτ : Fin n → Fin D) (iν : Fin 2 → Fin D)
    (hm : m < Fintype.card F)
    (hsec : ∀ (ω : (F × F) × (Fin nc → F)) (τ : Fin n → F) (ν : Fin 2 → F), (0 < m ∨ ω.1 = (0, 0)) →
      ∃ x : Fin D → F, (rz x, rp x) = ω.1 ∧ (fun k => x (iμ k)) = ω.2 ∧ (fun i => x (iτ i)) = τ
        ∧ (fun i => x (iν i)) = ν)
    (hG : ¬ hostGd c w (fun _ => 1) h M P) : ∃ x, hostPhiR c w h M P rz rp iμ iτ iν x ≠ 0 := by
  obtain ⟨ω, τ, ν, hne⟩ := hostPhi_nonzero c w (fun _ => 1) h M P hm hG
  by_cases hm0 : 0 < m
  · obtain ⟨x, h1, h2, h3, h4⟩ := hsec ω τ ν (Or.inl hm0)
    refine ⟨x, ?_⟩
    rw [hostPhiR, h1, h2, h3, h4]
    exact hne
  · have hm0' : m = 0 := by omega
    subst hm0'
    obtain ⟨x, h1, h2, h3, h4⟩ := hsec ((0, 0), ω.2) τ ν (Or.inr rfl)
    refine ⟨x, ?_⟩
    have hx : hostPhiR c w h M P rz rp iμ iτ iν x = hostPhi c w (fun _ => 1) h M P ((0, 0), ω.2) τ ν := by
      unfold hostPhiR
      rw [h1, h2, h3, h4]
    have e : hostPhi c w (fun _ => 1) h M P ((0, 0), ω.2) τ ν = hostPhi c w (fun _ => 1) h M P ω τ ν := by
      unfold hostPhi hostPoly
      simp only [← batched_pad0 c w ω]
    rw [hx, e]
    exact hne

/-! ## Standalone zero-checks -/

/-- **A standalone batched zero-check** (`SC_TAB`) with pad readers and coordinates for `μ`, `τ`. -/
def zcPhiR {n m D nc : ℕ} (c : Fin nc → (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F)
    (rz rp : (Fin D → F) → F) (iμ : Fin nc → Fin D) (iτ : Fin n → Fin D) (x : Fin D → F) : F :=
  zcPhi c w ((rz x, rp x), fun k => x (iμ k)) (fun i => x (iτ i))

theorem zcPhiR_deg {n m D nc : ℕ} (c : Fin nc → (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F)
    (rz rp : (Fin D → F) → F) (iμ : Fin nc → Fin D) (iτ : Fin n → Fin D)
    (hz : IndDegLE 1 rz) (hp : IndDegLE 1 rp) (hτ : Function.Injective iτ) :
    IndDegLE (m + 2) (zcPhiR c w rz rp iμ iτ) := by
  have e : zcPhiR c w rz rp iμ iτ = fun x => ∑ b : Fin n → Bool, eqPoly (fun i => x (iτ i)) (fun i => bit (b i))
      * batched c w ((rz x, rp x), fun k => x (iμ k)) b := by
    funext x
    simp only [zcPhiR, zcPhi, mleAt]
  rw [e]
  refine indDeg_sum (fun b => ?_)
  have := ZK60.StageX.IndDegLE.mul (indDeg_sel (indDeg_eqPoly_bit b) iτ hτ) (batchedR_deg c w rz rp iμ hz hp b)
  rw [show 1 + (m + 1) = m + 2 by omega] at this
  exact this

/-- **Unless every clause and pad plane vanishes, some draw vector makes the standalone identity nonzero.** -/
theorem zcPhiR_nonzero [Fintype F] [DecidableEq F] {n m D nc : ℕ} (c : Fin nc → (Fin n → Bool) → F)
    (w : Fin m → (Fin n → Bool) → F) (rz rp : (Fin D → F) → F) (iμ : Fin nc → Fin D) (iτ : Fin n → Fin D)
    (hm : m < Fintype.card F)
    (hsec : ∀ (ω : (F × F) × (Fin nc → F)) (τ : Fin n → F), (0 < m ∨ ω.1 = (0, 0)) →
      ∃ x : Fin D → F, (rz x, rp x) = ω.1 ∧ (fun k => x (iμ k)) = ω.2 ∧ (fun i => x (iτ i)) = τ)
    (hG : ¬ ((∀ k b, c k b = 0) ∧ ∀ j b, w j b = 0)) : ∃ x, zcPhiR c w rz rp iμ iτ x ≠ 0 := by
  obtain ⟨ω, τ, hne⟩ := zcPhi_nonzero c w hm hG
  by_cases hm0 : 0 < m
  · obtain ⟨x, h1, h2, h3⟩ := hsec ω τ (Or.inl hm0)
    exact ⟨x, by rw [zcPhiR, h1, h2, h3]; exact hne⟩
  · have hm0' : m = 0 := by omega
    subst hm0'
    obtain ⟨x, h1, h2, h3⟩ := hsec ((0, 0), ω.2) τ (Or.inr rfl)
    refine ⟨x, ?_⟩
    have hx : zcPhiR c w rz rp iμ iτ x = zcPhi c w ((0, 0), ω.2) τ := by
      unfold zcPhiR
      rw [h1, h2, h3]
    have e : zcPhi c w ((0, 0), ω.2) τ = zcPhi c w ω τ := by
      unfold zcPhi mleAt
      simp only [← batched_pad0 c w ω]
    rw [hx, e]
    exact hne

/-- **`SC_LZC`'s identity** (its helper relation at the fixed weight `1`, L13-2) with pad readers and `τ`'s coordinates. -/
def lzcPhiR {n m D : ℕ} (c : (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F) (rz rp : (Fin D → F) → F)
    (iτ : Fin n → Fin D) (x : Fin D → F) : F :=
  lzcPhi c w (rz x) (rp x) (fun i => x (iτ i))

theorem lzcPhiR_deg {n m D : ℕ} (c : (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F)
    (rz rp : (Fin D → F) → F) (iτ : Fin n → Fin D) (hz : IndDegLE 1 rz) (hp : IndDegLE 1 rp)
    (hτ : Function.Injective iτ) : IndDegLE (m + 2) (lzcPhiR c w rz rp iτ) := by
  have e : lzcPhiR c w rz rp iτ = fun x => ∑ b : Fin n → Bool, eqPoly (fun i => x (iτ i)) (fun i => bit (b i))
      * (c b + rp x * ∑ j : Fin m, rz x ^ (j : ℕ) * w j b) := by
    funext x
    simp only [lzcPhiR, lzcPhi, mleAt]
  rw [e]
  refine indDeg_sum (fun b => ?_)
  have h2 : IndDegLE m (fun x : Fin D → F => ∑ j : Fin m, rz x ^ (j : ℕ) * w j b) := by
    refine indDeg_sum (fun j => ?_)
    refine ZK60.StageX.IndDegLE.mono (ZK60.StageX.IndDegLE.mul (indDeg_pow hz (j : ℕ))
      (ZK60.StageX.IndDegLE.const (d := 0) (w j b))) ?_
    have := j.isLt
    omega
  have h3 : IndDegLE (m + 1) (fun x : Fin D → F => c b + rp x * ∑ j : Fin m, rz x ^ (j : ℕ) * w j b) :=
    ZK60.StageX.IndDegLE.add (ZK60.StageX.IndDegLE.const _)
      (ZK60.StageX.IndDegLE.mono (ZK60.StageX.IndDegLE.mul hp h2) (by omega))
  have := ZK60.StageX.IndDegLE.mul (indDeg_sel (indDeg_eqPoly_bit b) iτ hτ) h3
  rw [show 1 + (m + 1) = m + 2 by omega] at this
  exact this

theorem lzcPhiR_nonzero [Fintype F] [DecidableEq F] {n m D : ℕ} (c : (Fin n → Bool) → F)
    (w : Fin m → (Fin n → Bool) → F) (rz rp : (Fin D → F) → F) (iτ : Fin n → Fin D) (hm : m < Fintype.card F)
    (hsec : ∀ (ζ μp : F) (τ : Fin n → F), (0 < m ∨ (ζ, μp) = (0, 0)) →
      ∃ x : Fin D → F, (rz x, rp x) = (ζ, μp) ∧ (fun i => x (iτ i)) = τ)
    (hG : ¬ ((∀ b, c b = 0) ∧ ∀ j b, w j b = 0)) : ∃ x, lzcPhiR c w rz rp iτ x ≠ 0 := by
  obtain ⟨ζ, μp, τ, hne⟩ := lzcPhi_nonzero c w hm hG
  by_cases hm0 : 0 < m
  · obtain ⟨x, h1, h2⟩ := hsec ζ μp τ (Or.inl hm0)
    refine ⟨x, ?_⟩
    simp only [Prod.mk.injEq] at h1
    rw [lzcPhiR, h1.1, h1.2, h2]
    exact hne
  · have hm0' : m = 0 := by omega
    subst hm0'
    obtain ⟨x, h1, h2⟩ := hsec 0 0 τ (Or.inr rfl)
    refine ⟨x, ?_⟩
    rw [lzcPhiR, h2]
    have e : ∀ a b : F, lzcPhi c w a b τ = lzcPhi c w ζ μp τ := by
      intro a b
      simp [lzcPhi]
    rw [e]
    exact hne

/-- **`SC_ZS`'s identity** (it draws nothing): the helper columns' sum. -/
def zsPhi {n : ℕ} (u : (Fin n → Bool) → F) (_x : Fin 0 → F) : F := ∑ b, u b

theorem zsPhi_deg {n : ℕ} (u : (Fin n → Bool) → F) (d : ℕ) : IndDegLE d (zsPhi u) := fun i _ => i.elim0

theorem zsPhi_nonzero {n : ℕ} (u : (Fin n → Bool) → F) (hG : ¬ ∑ b, u b = 0) : ∃ x, zsPhi u x ≠ 0 :=
  ⟨fun i => i.elim0, hG⟩

/-! ## Private slots -/

/-- **A private slot's hosted difference at its own claim point** (the point's coordinates `ip` in its draw vector). -/
def privPhiR {n D : ℕ} (gh M : (Fin n → Bool) → F) (ip : Fin n → Fin D) (x : Fin D → F) : F :=
  privPhi gh M (fun i => x (ip i))

theorem privPhiR_deg {n D : ℕ} (gh M : (Fin n → Bool) → F) (ip : Fin n → Fin D) (hip : Function.Injective ip) :
    IndDegLE 1 (privPhiR gh M ip) :=
  indDeg_sel (privPhi_deg gh M) ip hip

theorem privPhiR_nonzero {n D : ℕ} (gh M : (Fin n → Bool) → F) (ip : Fin n → Fin D) (hip : Function.Injective ip)
    (hG : ¬ ∀ b, gh b = M b) : ∃ x, privPhiR gh M ip x ≠ 0 := by
  obtain ⟨p, hp⟩ := privPhi_nonzero gh M hG
  obtain ⟨x, hx⟩ := exists_assign ip hip p
  refine ⟨x, ?_⟩
  have e : (fun i => x (ip i)) = p := funext hx
  rw [privPhiR, e]
  exact hp

/-- **A private slot whose claim point starts with an earlier slot's coordinates `r`** (`SC_KMM`, `SC_VMM`: `SC_QMM`'s
`r_q`; `SC_UMM`: `SC_GMM`'s `r_tf`): its difference `D` at `(r, its own coordinates)`. -/
def privPartPhi {a b D : ℕ} (Dd : (Fin (a + b) → Bool) → F) (r : Fin a → F) (ip : Fin b → Fin D) (x : Fin D → F) :
    F :=
  mleAt Dd (Fin.append r (fun i => x (ip i)))

/-- Its start claim: the partial extension at `r` vanishes on the rest of the cube. -/
def privPartGd {a b : ℕ} (Dd : (Fin (a + b) → Bool) → F) (r : Fin a → F) : Prop :=
  ∀ j : Fin b → Bool, mle2 (fun z j' => Dd (Fin.append z j')) r (fun i => bit (j i)) = 0

theorem eqPoly_bit_bit {n : ℕ} (b b' : Fin n → Bool) :
    eqPoly (fun i => (bit (b i) : F)) (fun i => bit (b' i)) = if b = b' then 1 else 0 := eqPoly_bit b b'

/-- `mle2 P r s = Σ_j eq(s, j)·mle2 P r (j)`: the second block's extension of the first block's partial extension. -/
theorem mle2_split {a b : ℕ} (P : (Fin a → Bool) → (Fin b → Bool) → F) (r : Fin a → F) (s : Fin b → F) :
    mle2 P r s = ∑ j : Fin b → Bool, eqPoly s (fun i => bit (j i)) * mle2 P r (fun i => bit (j i)) := by
  classical
  unfold mle2
  have h : ∀ j : Fin b → Bool, ∑ z : Fin a → Bool, ∑ j' : Fin b → Bool,
      eqPoly r (fun i => bit (z i)) * eqPoly (fun i => (bit (j i) : F)) (fun i => bit (j' i)) * P z j'
      = ∑ z : Fin a → Bool, eqPoly r (fun i => bit (z i)) * P z j := by
    intro j
    refine sum_congr rfl fun z _ => ?_
    rw [Fintype.sum_eq_single j (fun j' hj' => by rw [eqPoly_bit_bit, ite_eq_right (Ne.symm hj')]; ring)]
    rw [eqPoly_bit_bit, ite_eq_left rfl]
    ring
  simp only [h]
  rw [sum_comm]
  refine sum_congr rfl fun j _ => ?_
  rw [mul_sum]
  refine sum_congr rfl fun z _ => ?_
  ring

/-- The extension at `(r, Boolean j)` is the partial extension at `r`, read at `j`. -/
theorem mleAt_append_bit {a b : ℕ} (Dd : (Fin (a + b) → Bool) → F) (r : Fin a → F) (j : Fin b → Bool) :
    mleAt Dd (Fin.append r (fun i => bit (j i))) = mle2 (fun z j' => Dd (Fin.append z j')) r (fun i => bit (j i)) :=
  mleAt_append Dd r _

/-- Fixing a first block of coordinates keeps the individual degree. -/
theorem indDeg_append_left {a b d : ℕ} {f : (Fin (a + b) → F) → F} (hf : IndDegLE d f) (r : Fin a → F) :
    IndDegLE d (fun y : Fin b → F => f (Fin.append r y)) := by
  intro j y
  obtain ⟨p, hp, hpe⟩ := hf (Fin.natAdd a j) (Fin.append r y)
  refine ⟨p, hp, fun t => ?_⟩
  have e : Fin.append r (Function.update y j t) = Function.update (Fin.append r y) (Fin.natAdd a j) t := by
    funext i
    induction i using Fin.addCases with
    | left i =>
      have hi := i.isLt
      rw [Fin.append_left, Function.update_of_ne (by
        intro h
        have := congrArg Fin.val h
        simp at this
        omega), Fin.append_left]
    | right i =>
      rw [Fin.append_right]
      by_cases hij : i = j
      · subst hij
        simp
      · rw [Function.update_of_ne hij, Function.update_of_ne (by
          intro h
          apply hij
          exact Fin.ext (by have := congrArg Fin.val h; simp at this; omega)), Fin.append_right]
  show f (Fin.append r (Function.update y j t)) = _
  rw [e]
  exact hpe t

theorem privPartPhi_deg {a b D : ℕ} (Dd : (Fin (a + b) → Bool) → F) (r : Fin a → F) (ip : Fin b → Fin D)
    (hip : Function.Injective ip) : IndDegLE 1 (privPartPhi Dd r ip) :=
  indDeg_sel (indDeg_append_left (indDegLE_mleAt Dd) r) ip hip

theorem privPartPhi_nonzero {a b D : ℕ} (Dd : (Fin (a + b) → Bool) → F) (r : Fin a → F) (ip : Fin b → Fin D)
    (hip : Function.Injective ip) (hG : ¬ privPartGd Dd r) : ∃ x, privPartPhi Dd r ip x ≠ 0 := by
  have hj : ∃ j : Fin b → Bool, mle2 (fun z j' => Dd (Fin.append z j')) r (fun i => bit (j i)) ≠ 0 := by
    by_contra hno
    apply hG
    intro j
    by_contra hj
    exact hno ⟨j, hj⟩
  obtain ⟨j, hj⟩ := hj
  obtain ⟨x, hx⟩ := exists_assign ip hip (fun i => (bit (j i) : F))
  refine ⟨x, ?_⟩
  have e : (fun i => x (ip i)) = fun i => (bit (j i) : F) := funext hx
  rw [privPartPhi, e, mleAt_append_bit]
  exact hj

/-- **The drawing slot's layer for a later slot's relation** (L23-2): `D` at the drawing slot's own `r` (coordinates
`iq`) and a block of its own free coordinates `iy`. -/
def crossPhi {a b D : ℕ} (Dd : (Fin (a + b) → Bool) → F) (iq : Fin a → Fin D) (iy : Fin b → Fin D) (x : Fin D → F) :
    F :=
  mleAt Dd (Fin.append (fun i => x (iq i)) (fun i => x (iy i)))

theorem crossPhi_deg {a b D : ℕ} (Dd : (Fin (a + b) → Bool) → F) (iq : Fin a → Fin D) (iy : Fin b → Fin D)
    (hinj : Function.Injective (Fin.append iq iy)) : IndDegLE 1 (crossPhi Dd iq iy) := by
  have e : crossPhi Dd iq iy = fun x => mleAt Dd (fun i => x (Fin.append iq iy i)) := by
    funext x
    unfold crossPhi
    congr 1
    funext i
    induction i using Fin.addCases with
    | left i => simp
    | right i => simp
  rw [e]
  exact indDeg_sel (indDegLE_mleAt Dd) _ hinj

theorem crossPhi_nonzero {a b D : ℕ} (Dd : (Fin (a + b) → Bool) → F) (iq : Fin a → Fin D) (iy : Fin b → Fin D)
    (hinj : Function.Injective (Fin.append iq iy)) (hG : ¬ ∀ z, Dd z = 0) : ∃ x, crossPhi Dd iq iy x ≠ 0 := by
  have hz : ∃ z, Dd z ≠ 0 := by
    by_contra hno
    apply hG
    intro z
    by_contra hz
    exact hno ⟨z, hz⟩
  obtain ⟨z, hz⟩ := hz
  obtain ⟨x, hx⟩ := exists_assign _ hinj (fun i => (bit (z i) : F))
  refine ⟨x, ?_⟩
  have e : Fin.append (fun i => x (iq i)) (fun i => x (iy i)) = fun i => (bit (z i) : F) := by
    funext i
    induction i using Fin.addCases with
    | left i =>
      rw [Fin.append_left, ← hx]
      simp
    | right i =>
      rw [Fin.append_right, ← hx]
      simp
  rw [crossPhi, e, mleAt_bit]
  exact hz

/-- **The drawing slot's layer vanishes once the later slot's partial claim holds at the drawn `r`.** -/
theorem crossPhi_van {a b D : ℕ} (Dd : (Fin (a + b) → Bool) → F) (iq : Fin a → Fin D) (iy : Fin b → Fin D)
    (x : Fin D → F) (h : privPartGd Dd (fun i => x (iq i))) : crossPhi Dd iq iy x = 0 := by
  rw [crossPhi, mleAt_append, mle2_split]
  refine sum_eq_zero fun j _ => ?_
  rw [h j, mul_zero]

/-! ## `SC_RS` -/

/-- **`SC_RS`'s `λ`-batched row claim** with `λ` at `il` and its point at `ip`. -/
def rsPhiR {n D : ℕ} (A B : (Fin n → Bool) → F) (il : Fin D) (ip : Fin n → Fin D) (x : Fin D → F) : F :=
  rsPhi A B (x il) (fun i => x (ip i))

theorem rsPhiR_deg {n D : ℕ} (A B : (Fin n → Bool) → F) (il : Fin D) (ip : Fin n → Fin D)
    (hip : Function.Injective ip) : IndDegLE 2 (rsPhiR A B il ip) := by
  unfold rsPhiR rsPhi
  exact ZK60.StageX.IndDegLE.add (ZK60.StageX.IndDegLE.mono (indDeg_sel (indDegLE_mleAt A) ip hip) (by omega))
    (ZK60.StageX.IndDegLE.mul (indDeg_coord il) (indDeg_sel (indDegLE_mleAt B) ip hip))

theorem rsPhiR_nonzero {n D : ℕ} (A B : (Fin n → Bool) → F) (il : Fin D) (ip : Fin n → Fin D)
    (hinj : Function.Injective (Sum.elim (fun _ : Unit => il) ip)) (hG : ¬ ((∀ b, A b = 0) ∧ ∀ b, B b = 0)) :
    ∃ x, rsPhiR A B il ip x ≠ 0 := by
  obtain ⟨lam, p, hp⟩ := rsPhi_nonzero A B hG
  obtain ⟨x, hx⟩ := exists_assign _ hinj (Sum.elim (fun _ => lam) p)
  refine ⟨x, ?_⟩
  have h1 : x il = lam := hx (Sum.inl ())
  have h2 : (fun i => x (ip i)) = p := funext fun i => hx (Sum.inr i)
  rw [rsPhiR, h1, h2]
  exact hp

/-- **`SC_RS`'s cube sum is its `λ`-batched row claim** (`rsIr_eval`'s `supp·eq(p_ht)·(mask·e + λ·zsel)` on the row cube
times the column cube): `(Σ_j gS·mask·E)~(p) + λ·(Σ_j gS·Z)~(p)`, `SlotW16Sound.dens_rowsum`'s form. -/
theorem rs_cubeSum {a b : ℕ} (p : Fin a → F) (gS mask E Z : (Fin a → Bool) → (Fin b → Bool) → F) (lam : F) :
    ∑ r : Fin a → Bool, ∑ j : Fin b → Bool, eqPoly p (fun i => bit (r i)) * (gS r j * (mask r j * E r j + lam * Z r j))
      = mleAt (fun r => ∑ j, gS r j * (mask r j * E r j)) p + lam * mleAt (fun r => ∑ j, gS r j * Z r j) p := by
  unfold mleAt
  rw [Finset.mul_sum, ← Finset.sum_add_distrib]
  refine Finset.sum_congr rfl fun r _ => ?_
  rw [Finset.mul_sum, Finset.mul_sum, Finset.mul_sum, ← Finset.sum_add_distrib]
  refine Finset.sum_congr rfl fun j _ => ?_
  ring

/-- **`SC_SZC`'s hosted `SC_RS` term on its cube**: the row point's `eq` over the row coordinates only, summed over the
column cube, is `2^b` times the row extension (the code's `ν_0·per_row` coefficient, `per_row = 2^b`). -/
theorem rs_host_cubeSum {a b : ℕ} (p : Fin a → F) (g S : (Fin a → Bool) → F) (lam : F) :
    ∑ r : Fin a → Bool, ∑ _j : Fin b → Bool, eqPoly p (fun i => bit (r i)) * (g r * (S r + lam))
      = (2 : F) ^ b * mleAt (fun r => g r * (S r + lam)) p := by
  unfold mleAt
  rw [Finset.mul_sum]
  refine Finset.sum_congr rfl fun r _ => ?_
  rw [Finset.sum_const, Finset.card_univ, Fintype.card_fun, Fintype.card_bool, Fintype.card_fin, nsmul_eq_mul]
  push_cast
  ring

end Kinds

end ZK60.Sound.SlotW16
