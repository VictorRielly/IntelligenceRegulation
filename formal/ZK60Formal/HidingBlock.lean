/-
D63, step L4 (zero knowledge): composing the layers of one block's view (honest verifier, fixed challenges).

One block's proof has three layers of coins, independent and uniform:
* `Ω₁`: the opening coins of `A` and `H` (pads, mask rows, proximity rows, zero-sum rows). Their view `X₁ d ω₁` (every
  claim's row combination, the proximity vectors, the opened columns; `openingView`, `openingViewH`) has a law that
  does not depend on the data `d` (`openingView_law_eq`, `openingViewH_law_eq`).
* `Ω₂`: the CFS mask coefficients of the slots. A slot's view `X₂ d ω₁ ω₂` (masked scalar, every round message,
  `g(ρ)`) depends on the data and the opening coins only through its chain defects, which for an honest private slot
  are `poly` of the masked terminals: the claim values, a function of `X₁` (`cfsViewMasked_joint_law_eq`,
  `slot_chainDefect`).
* `Ω₃`: `M`'s coins (pads, `b`, `u`). `M`'s view `X₃ ω₂ ω₃` depends on the mask coefficients only through the
  functional value `V`, a function of the slots' views (`g(ρ)` and the `Γ`'s) (`mOpenView_joint_law_eq`).

This file proves the composition:
* `map_pair_eq_bind`: the law of `G (Y ω) c` over independent uniform `(ω, c)` is the law of `Y` followed by `G`;
* `block_view_law_eq`: **if each layer is simulated from the layer below it, the whole view of the block has the same
  law for every data as for the reference data `d₀` (for example zero data)**: the simulator runs the openings on `d₀`,
  then the slot simulator on their view, then `M`'s simulator on the slots' view;
* `block_view_law_eq_slot_M`: the same with the slot layer and the `M` layer instantiated by the proved lemmas
  (`cfsViewMasked_joint_law_eq` for one private slot, `mOpenView_joint_law_eq` for `M`): what remains to assume is
  the opening layer (proved separately, for `A` and `H`) and the two LINKS of the instance, stated as hypotheses: the
  slot's defects are a function of the opening view, and `M`'s functional value is a function of the slot's view.

NOT covered: the links themselves for the registered layouts (which claim value is which masked terminal, which
functional is which `g(ρ)` or `Γ`), several slots at once (the same argument with `Ω₂` a product of the slots' mask
spaces), Fiat–Shamir, the Merkle layer, and the composition over the blocks of a run.
-/
import ZK60Formal.HidingMOpening
import ZK60Formal.HidingRefusal

namespace ZK60.Hiding

open scoped ENNReal

section Block

/-- **Simulation after a layer.** For independent uniform `(ω, c)`, the law of `G (Y ω) c` is the law of `Y` followed by
`G`: it depends on `Y` only through `Y`'s law. -/
theorem map_pair_eq_bind {Ω C β γ : Type} [Fintype Ω] [Nonempty Ω] [Fintype C] [Nonempty C] (Y : Ω → β)
    (G : β → C → γ) :
    (PMF.uniformOfFintype (Ω × C)).map (fun p => G (Y p.1) p.2)
      = ((PMF.uniformOfFintype Ω).map Y).bind (fun y => (PMF.uniformOfFintype C).map (G y)) := by
  rw [uniform_prod_eq_bind, PMF.map_bind, PMF.bind_map]
  congr 1
  funext ω
  rw [PMF.map_comp]
  rfl

/-- **One block's view, composed.** Let the opening view `X₁ d` have a data-independent law (`hA`); let the slot view
`X₂` be simulated jointly from the opening view by `S₂` (`hS`, the form of `cfsViewMasked_joint_law_eq`); and let `M`'s
view `X₃` be simulated jointly from the first two by `S₃` (`hM`, the form of `mOpenView_joint_law_eq`). Then the joint
law of all three views is the same for every data `d` as for `d₀`. For privacy: a simulator that runs the openings on
`d₀` (zero data), the slot simulator on their output and `M`'s simulator on the slots' output reproduces one block's
whole PCS + sumcheck view exactly (at fixed challenges). -/
theorem block_view_law_eq {Dt Ω₁ Ω₂ Ω₃ β₁ β₂ β₃ : Type} [Fintype Ω₁] [Nonempty Ω₁] [Fintype Ω₂] [Nonempty Ω₂]
    [Fintype Ω₃] [Nonempty Ω₃] (X₁ : Dt → Ω₁ → β₁) (X₂ : Dt → Ω₁ → Ω₂ → β₂) (X₃ : Ω₂ → Ω₃ → β₃)
    (S₂ : β₁ → Ω₂ → β₂) (S₃ : β₁ × β₂ → Ω₃ → β₃) (d₀ : Dt)
    (hA : ∀ d, (PMF.uniformOfFintype Ω₁).map (X₁ d) = (PMF.uniformOfFintype Ω₁).map (X₁ d₀))
    (hS : ∀ d, (PMF.uniformOfFintype (Ω₁ × Ω₂)).map (fun p => (X₁ d p.1, X₂ d p.1 p.2))
      = (PMF.uniformOfFintype (Ω₁ × Ω₂)).map (fun p => (X₁ d p.1, S₂ (X₁ d p.1) p.2)))
    (hM : ∀ d, (PMF.uniformOfFintype ((Ω₁ × Ω₂) × Ω₃)).map
        (fun p => ((X₁ d p.1.1, X₂ d p.1.1 p.1.2), X₃ p.1.2 p.2))
      = (PMF.uniformOfFintype ((Ω₁ × Ω₂) × Ω₃)).map
        (fun p => ((X₁ d p.1.1, X₂ d p.1.1 p.1.2), S₃ (X₁ d p.1.1, X₂ d p.1.1 p.1.2) p.2)))
    (d : Dt) :
    (PMF.uniformOfFintype ((Ω₁ × Ω₂) × Ω₃)).map (fun p => ((X₁ d p.1.1, X₂ d p.1.1 p.1.2), X₃ p.1.2 p.2))
      = (PMF.uniformOfFintype ((Ω₁ × Ω₂) × Ω₃)).map
        (fun p => ((X₁ d₀ p.1.1, X₂ d₀ p.1.1 p.1.2), X₃ p.1.2 p.2)) := by
  have hstep : ∀ e : Dt, (PMF.uniformOfFintype ((Ω₁ × Ω₂) × Ω₃)).map
      (fun p => ((X₁ e p.1.1, X₂ e p.1.1 p.1.2), X₃ p.1.2 p.2))
      = (((PMF.uniformOfFintype Ω₁).map (X₁ e)).bind
          (fun x => (PMF.uniformOfFintype Ω₂).map (fun c => (x, S₂ x c)))).bind
        (fun y => (PMF.uniformOfFintype Ω₃).map (fun c => (y, S₃ y c))) := by
    intro e
    rw [hM e]
    rw [map_pair_eq_bind (fun ω : Ω₁ × Ω₂ => (X₁ e ω.1, X₂ e ω.1 ω.2)) (fun y c => (y, S₃ y c))]
    rw [hS e]
    rw [map_pair_eq_bind (X₁ e) (fun x c => (x, S₂ x c))]
  rw [hstep d, hstep d₀, hA d]

/-- **One block with one private slot and `M`, the slot and `M` layers instantiated.** The opening layer is given by
its law (`hA`, from `openingView_law_eq` / `openingViewH_law_eq`); the slot is one CFS-masked sumcheck with masked scalar
(`cfsViewMasked`) whose unmasked rounds `s d ω₁` have middle defects and terminal equal to those of `s'` applied to the
opening view (`hdef`, the link `slot_chainDefect`: `poly` of the masked terminals, which are claim values); `M`'s
messages are a layout `w` of the slot's mask coefficients whose functional value equals that of `w'` applied to the
views below (`hV`, the link: `V` is computed by the verifier from `g(ρ)` and the scalars). Then one block's whole view
has the same law for every data as for `d₀`. -/
theorem block_view_law_eq_slot_M {K F : Type} [Field K] [Fintype K] [Field F] [Fintype F] {Dt Ω₁ β₁ : Type}
    [Fintype Ω₁] [Nonempty Ω₁] {n d m r Q q : ℕ}
    (X₁ : Dt → Ω₁ → β₁) (d₀ : Dt)
    (hA : ∀ e, (PMF.uniformOfFintype Ω₁).map (X₁ e) = (PMF.uniformOfFintype Ω₁).map (X₁ d₀))
    -- the slot
    (hd : 1 ≤ d) (h2 : (2 : K) ≠ 0) {c : K} (hc : c ≠ 0) (ρ : Fin (n + 1) → K)
    (s : Dt → Ω₁ → Fin (n + 1) → Fin (d + 1) → K) (s' : β₁ → Fin (n + 1) → Fin (d + 1) → K)
    (hdef : ∀ e ω₁, (chainDefect (s e ω₁) ρ).2 = (chainDefect (s' (X₁ e ω₁)) ρ).2)
    -- `M`
    (κ : F) (P : MOpenPub F m r Q q) (hm : 0 < m) (hmF : (m : F) ≠ 0) (hy : Function.Injective P.y)
    (hsum : ∀ j < 2 * m, ∑ i, P.y i ^ j = if j = 0 ∨ j = m then (m : F) else 0)
    (hW : ∀ s l, P.Wre s (P.π s l) = 0 ∧ P.Wim s (P.π s l) = 0)
    (hpad : ∀ s (v : Fin m → F), ∃ g : Fin Q → F,
      ∀ t, (Lagrange.interpolate Finset.univ P.y (v - placePads (P.π s) g)).eval (P.x t) = 0)
    (w : CfsCoeffs K n d → Fin r → Bool → Fin m → F)
    (w' : β₁ × (K × (Fin (n + 1) → Fin (d + 1) → K) × K) → Fin r → Bool → Fin m → F)
    (hV : ∀ e ω₁ a,
      mValRe κ P (w a) = mValRe κ P (w' (X₁ e ω₁, cfsViewMasked (s e ω₁) c ρ a))
        ∧ mValIm P (w a) = mValIm P (w' (X₁ e ω₁, cfsViewMasked (s e ω₁) c ρ a)))
    (e : Dt) :
    (PMF.uniformOfFintype ((Ω₁ × CfsCoeffs K n d) × MCoins F m r Q)).map
        (fun p => ((X₁ e p.1.1, cfsViewMasked (s e p.1.1) c ρ p.1.2), mOpenView κ P hm (w p.1.2) p.2))
      = (PMF.uniformOfFintype ((Ω₁ × CfsCoeffs K n d) × MCoins F m r Q)).map
        (fun p => ((X₁ d₀ p.1.1, cfsViewMasked (s d₀ p.1.1) c ρ p.1.2), mOpenView κ P hm (w p.1.2) p.2)) := by
  refine block_view_law_eq X₁ (fun e ω₁ a => cfsViewMasked (s e ω₁) c ρ a) (fun a cM => mOpenView κ P hm (w a) cM)
    (fun x a => cfsViewMasked (s' x) c ρ a) (fun y cM => mOpenView κ P hm (w' y) cM) d₀ hA ?_ ?_ e
  · intro e'
    exact cfsViewMasked_joint_law_eq hd h2 hc ρ (X₁ e') (s e') s' (hdef e')
  · intro e'
    exact mOpenView_joint_law_eq κ P hm hmF hy hsum hW hpad
      (fun ω : Ω₁ × CfsCoeffs K n d => (X₁ e' ω.1, cfsViewMasked (s e' ω.1) c ρ ω.2))
      (fun ω => w ω.2) w' (fun ω => hV e' ω.1 ω.2)

end Block

end ZK60.Hiding
