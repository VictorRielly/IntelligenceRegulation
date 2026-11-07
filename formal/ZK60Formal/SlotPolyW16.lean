/-
D63 lane L23 (2026-11-07), part 5: **certified slot polynomials** and the define schedules built from them.

`DefSched` (L21) separates a schedule's slots, start claims `Gd`, polynomials `Φ` and degrees `dg`, and
`block_knowledge_target_mt` asks for `(Φ ≡ 0) → Gd` (`hΦ`) and `IndDegLE (dg k) Φ` (`hdeg`) as premises. Here a slot's
polynomial carries its own certificate:

* `SlotPoly`: a start claim, a polynomial of the draw vector, a degree, the degree proof and `(Φ ≡ 0) → Gd`;
* constructors by kind, each certified by `SlotPolyW16Kinds.lean`: `SlotPoly.host` (a host with pad readers),
  `SlotPoly.zc` (`SC_TAB`), `SlotPoly.lzc` (`SC_LZC`), `SlotPoly.zs` (`SC_ZS`), `SlotPoly.priv` (a private slot at its
  own claim point), `SlotPoly.part` (a private slot whose point starts with an earlier slot's `r`), `SlotPoly.cross`
  (the drawing slot's layer for such a relation), `SlotPoly.rs` (`SC_RS`), `SlotPoly.triv`, and `SlotPoly.cast` (a
  draw vector of an equal length, e.g. `P.draws k = drawLen sh k`);
* `schedOf`, **`schedOf_facts`**: a define schedule from a family of certified polynomials over the slots `ks`, with
  `hΦ` and `hdeg` (`dg ≤ dd`) PROVED for any instance.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.SlotPolyW16Kinds
import ZK60Formal.CoverW16Target

set_option autoImplicit false

namespace ZK60.Sound.SlotW16

open Finset

/-- **A certified slot polynomial**: a start claim, a polynomial of the slot's draw vector of individual degree `dg`,
vanishing identically only when the claim holds. -/
structure SlotPoly (F : Type) [Field F] (D : ℕ) where
  Gd : Prop
  Φ : (Fin D → F) → F
  dg : ℕ
  hdeg : IndDegLE dg Φ
  hΦ : (∀ x, Φ x = 0) → Gd

namespace SlotPoly

variable {F : Type} [Field F]

/-- A slot outside a layer: the true claim and the zero polynomial. -/
def triv (D : ℕ) : SlotPoly F D where
  Gd := True
  Φ := fun _ => 0
  dg := 0
  hdeg := ZK60.StageX.IndDegLE.const 0
  hΦ := fun _ => trivial

/-- **A host** (L13's three-term polynomial; `SC_TZC`, `SC_DZC`, `SC_QZC`, `SC_KVZC`, `SC_SZC`, `SC_FZC`). -/
def host [Fintype F] [DecidableEq F] {n m D nc : ℕ} (c : Fin nc → (Fin n → Bool) → F)
    (w : Fin m → (Fin n → Bool) → F) (h M : Fin 2 → (Fin n → Bool) → F) (P : Fin 2 → Fin n → F)
    (rz rp : (Fin D → F) → F) (iμ : Fin nc → Fin D) (iτ : Fin n → Fin D) (iν : Fin 2 → Fin D)
    (hz : IndDegLE 1 rz) (hp : IndDegLE 1 rp) (hτ : Function.Injective iτ) (hm : m < Fintype.card F)
    (hsec : ∀ (ω : (F × F) × (Fin nc → F)) (τ : Fin n → F) (ν : Fin 2 → F), (0 < m ∨ ω.1 = (0, 0)) →
      ∃ x : Fin D → F, (rz x, rp x) = ω.1 ∧ (fun k => x (iμ k)) = ω.2 ∧ (fun i => x (iτ i)) = τ
        ∧ (fun i => x (iν i)) = ν) : SlotPoly F D where
  Gd := hostGd c w (fun _ => 1) h M P
  Φ := hostPhiR c w h M P rz rp iμ iτ iν
  dg := m + 2
  hdeg := hostPhiR_deg c w h M P rz rp iμ iτ iν hz hp hτ
  hΦ := fun h0 => by
    by_contra hG
    obtain ⟨x, hx⟩ := hostPhiR_nonzero c w h M P rz rp iμ iτ iν hm hsec hG
    exact hx (h0 x)

/-- **A standalone batched zero-check** (`SC_TAB`). -/
def zc [Fintype F] [DecidableEq F] {n m D nc : ℕ} (c : Fin nc → (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F)
    (rz rp : (Fin D → F) → F) (iμ : Fin nc → Fin D) (iτ : Fin n → Fin D)
    (hz : IndDegLE 1 rz) (hp : IndDegLE 1 rp) (hτ : Function.Injective iτ) (hm : m < Fintype.card F)
    (hsec : ∀ (ω : (F × F) × (Fin nc → F)) (τ : Fin n → F), (0 < m ∨ ω.1 = (0, 0)) →
      ∃ x : Fin D → F, (rz x, rp x) = ω.1 ∧ (fun k => x (iμ k)) = ω.2 ∧ (fun i => x (iτ i)) = τ) :
    SlotPoly F D where
  Gd := (∀ k b, c k b = 0) ∧ ∀ j b, w j b = 0
  Φ := zcPhiR c w rz rp iμ iτ
  dg := m + 2
  hdeg := zcPhiR_deg c w rz rp iμ iτ hz hp hτ
  hΦ := fun h0 => by
    by_contra hG
    obtain ⟨x, hx⟩ := zcPhiR_nonzero c w rz rp iμ iτ hm hsec hG
    exact hx (h0 x)

/-- **`SC_LZC`** (its helper relation at the fixed weight `1`). -/
def lzc [Fintype F] [DecidableEq F] {n m D : ℕ} (c : (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F)
    (rz rp : (Fin D → F) → F) (iτ : Fin n → Fin D) (hz : IndDegLE 1 rz) (hp : IndDegLE 1 rp)
    (hτ : Function.Injective iτ) (hm : m < Fintype.card F)
    (hsec : ∀ (ζ μp : F) (τ : Fin n → F), (0 < m ∨ (ζ, μp) = (0, 0)) →
      ∃ x : Fin D → F, (rz x, rp x) = (ζ, μp) ∧ (fun i => x (iτ i)) = τ) : SlotPoly F D where
  Gd := (∀ b, c b = 0) ∧ ∀ j b, w j b = 0
  Φ := lzcPhiR c w rz rp iτ
  dg := m + 2
  hdeg := lzcPhiR_deg c w rz rp iτ hz hp hτ
  hΦ := fun h0 => by
    by_contra hG
    obtain ⟨x, hx⟩ := lzcPhiR_nonzero c w rz rp iτ hm hsec hG
    exact hx (h0 x)

/-- **`SC_ZS`** (no draws): the helper columns' sum. -/
def zs {n : ℕ} (u : (Fin n → Bool) → F) : SlotPoly F 0 where
  Gd := ∑ b, u b = 0
  Φ := zsPhi u
  dg := 0
  hdeg := zsPhi_deg u 0
  hΦ := fun h0 => by
    by_contra hG
    obtain ⟨x, hx⟩ := zsPhi_nonzero u hG
    exact hx (h0 x)

/-- **A private slot at its own claim point.** -/
def priv {n D : ℕ} (gh M : (Fin n → Bool) → F) (ip : Fin n → Fin D) (hip : Function.Injective ip) : SlotPoly F D where
  Gd := ∀ b, gh b = M b
  Φ := privPhiR gh M ip
  dg := 1
  hdeg := privPhiR_deg gh M ip hip
  hΦ := fun h0 => by
    by_contra hG
    obtain ⟨x, hx⟩ := privPhiR_nonzero gh M ip hip hG
    exact hx (h0 x)

/-- **A private slot whose claim point starts with an earlier slot's coordinates `r`.** -/
def part {a b D : ℕ} (Dd : (Fin (a + b) → Bool) → F) (r : Fin a → F) (ip : Fin b → Fin D)
    (hip : Function.Injective ip) : SlotPoly F D where
  Gd := privPartGd Dd r
  Φ := privPartPhi Dd r ip
  dg := 1
  hdeg := privPartPhi_deg Dd r ip hip
  hΦ := fun h0 => by
    by_contra hG
    obtain ⟨x, hx⟩ := privPartPhi_nonzero Dd r ip hip hG
    exact hx (h0 x)

/-- **The drawing slot's layer for a later slot's relation** (finding L23-2). -/
def cross {a b D : ℕ} (Dd : (Fin (a + b) → Bool) → F) (iq : Fin a → Fin D) (iy : Fin b → Fin D)
    (hinj : Function.Injective (Fin.append iq iy)) : SlotPoly F D where
  Gd := ∀ z, Dd z = 0
  Φ := crossPhi Dd iq iy
  dg := 1
  hdeg := crossPhi_deg Dd iq iy hinj
  hΦ := fun h0 => by
    by_contra hG
    obtain ⟨x, hx⟩ := crossPhi_nonzero Dd iq iy hinj hG
    exact hx (h0 x)

/-- **`SC_RS`'s `λ`-batched row claim.** -/
def rs {n D : ℕ} (A B : (Fin n → Bool) → F) (il : Fin D) (ip : Fin n → Fin D)
    (hip : Function.Injective ip) (hinj : Function.Injective (Sum.elim (fun _ : Unit => il) ip)) : SlotPoly F D where
  Gd := (∀ b, A b = 0) ∧ ∀ b, B b = 0
  Φ := rsPhiR A B il ip
  dg := 2
  hdeg := rsPhiR_deg A B il ip hip
  hΦ := fun h0 => by
    by_contra hG
    obtain ⟨x, hx⟩ := rsPhiR_nonzero A B il ip hinj hG
    exact hx (h0 x)

/-- The same polynomial on a draw vector of an equal length. -/
def cast {D D' : ℕ} (e : D = D') (sp : SlotPoly F D) : SlotPoly F D' where
  Gd := sp.Gd
  Φ := fun x => sp.Φ (fun i => x (Fin.cast e i))
  dg := sp.dg
  hdeg := by
    subst e
    exact sp.hdeg
  hΦ := fun h0 => sp.hΦ fun x => by
    subst e
    exact h0 x

end SlotPoly

end ZK60.Sound.SlotW16

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Circuit (gP GF)

section Sched

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **A define schedule from certified slot polynomials** over the slots `ks` (degrees bounded by `dgOf`). -/
def schedOf (P : BlockParams) (ks : List ℕ) (sp : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (dgOf : ℕ → ℕ) : DefSched K L P :=
  ⟨ks, fun cu rt k h => (sp cu rt k h).Gd, fun cu rt k h => (sp cu rt k h).Φ, dgOf⟩

omit [Algebra GF K] in
/-- **A schedule of certified polynomials meets `hΦ` and `hdeg`** for every instance. -/
theorem schedOf_facts (P : BlockParams) (ks : List ℕ) (sp : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (dgOf : ℕ → ℕ) (hdg : ∀ cu rt k h, k ∈ ks → (sp cu rt k h).dg ≤ dgOf k) :
    (∀ k ∈ (schedOf P ks sp dgOf).ks, ∀ cu rt h, IndDegLE ((schedOf P ks sp dgOf).dg k) ((schedOf P ks sp dgOf).Φ cu rt k h))
    ∧ (∀ cu rt k h, k ∈ (schedOf P ks sp dgOf).ks → (∀ x, (schedOf P ks sp dgOf).Φ cu rt k h x = 0)
      → (schedOf P ks sp dgOf).Gd cu rt k h) :=
  ⟨fun k hk cu rt h => ZK60.StageX.IndDegLE.mono (sp cu rt k h).hdeg (hdg cu rt k h hk),
    fun cu rt k h _ h0 => (sp cu rt k h).hΦ h0⟩

end Sched

end ZK60.Exec.Block
