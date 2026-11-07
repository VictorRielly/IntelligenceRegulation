/-
D63 step L14 (Statement 2, zero knowledge), part 3: one W16R2 block's WHOLE honest-verifier view, composed, at fixed
challenges: the two openings (`A` and `H`), EVERY slot at once (of each of the three kinds), and `M`.

`HidingBlock.lean`'s `block_view_law_eq_slot_M` composes the openings, ONE private slot and `M`. A W16R2 block has 23
slots (`SlotW16R2.nSlots`) of three kinds (`SlotW16R2.Kind`: a private slot publishes `S + c·G`, a standalone slot
`c·G` of the public claimed sum `0`, a host slot `c·G` of a claimed sum computed from the earlier scalars and the
challenges), each with its own shape `(n, d)` and mask coefficients, all drawn independently. This file:

* `slotView`, `SlotLink`, `slotView_shift`: one slot's view by kind (`cfsViewMasked` for a private slot, `cfsView` for
  the others) and the coin translate that carries the honest rounds to any rounds with the same defects (the middle
  defects and the terminal value for a private slot; the whole chain defects, the public claimed sum included, for the
  others);
* `slots_shift`: ONE translate of all the slots' mask coefficients at once (the product of the per-slot translates);
* `law_eq_prod`: two independent layers with data-independent laws have a data-independent joint law (the `A` and `H`
  openings, `openingView_law_eq` and `openingViewH_law_eq`);
* **`block_view_law_eq_slots_M`**: if the openings' law does not depend on the data, every slot's defects are those of
  rounds computed from the openings' view (the LINK: each slot's terminal value is `poly` of masked terminals, which are
  claim values the openings show), and `M`'s functional value is a function of the views below (the LINK: the verifier
  computes `V` from the `g(ρ)`'s and the `Γ`'s), then the joint law of the whole block view (openings, every slot,
  `M`) is the same for every data as for `d₀`;
* `map_comp_law_eq`: a receipt that is a function of that view (and of the public challenges) then has the same law
  for every data: the hypothesis `hHV` of `ZKW16Step.fs_step`.

The links themselves are hypotheses (`hdef`, `hV`): which claim value is which masked terminal, and which `M` functional
is which `g(ρ)` or `Γ`, are fixed by L9's `slotAcc` / `buildClaim` order and L11's slot list (`SlotW16R2.kindOf`,
`hostsOf`); stating them as Lean functions of the registered layout is the per-profile part left (L14 doc §5).

Every premise is an explicit hypothesis; no `sorry`, axiom or `native_decide`.
-/
import ZK60Formal.HidingBlock

namespace ZK60.ZKW16

open scoped ENNReal
open ZK60.Hiding

/-! ## One slot of any kind -/

section Slots

variable {K : Type} [Field K]

/-- One slot's view by kind: a private slot (`masked = true`) publishes the masked scalar `S + c·G` (`cfsViewMasked`),
a standalone or host slot the scalar `c·G` of a claimed sum the verifier computes (`cfsView`); then every round message
and `g(ρ)`. -/
def slotView (masked : Bool) {n d : ℕ} (s : Fin (n + 1) → Fin (d + 1) → K) (c : K) (r : Fin (n + 1) → K)
    (a : CfsCoeffs K n d) : K × (Fin (n + 1) → Fin (d + 1) → K) × K :=
  if masked then cfsViewMasked s c r a else cfsView s c r a

/-- What a slot's simulation needs: for a private slot the middle defects and the terminal value; for the others the
whole chain defects (their claimed sum is public: `0` for a standalone slot, the hosted sum for a host). -/
def SlotLink (masked : Bool) {n d : ℕ} (s s' : Fin (n + 1) → Fin (d + 1) → K) (r : Fin (n + 1) → K) : Prop :=
  if masked then (chainDefect s r).2 = (chainDefect s' r).2 else chainDefect s r = chainDefect s' r

/-- **One slot's coin translate**, for either kind. -/
theorem slotView_shift (masked : Bool) {n d : ℕ} (hd : 1 ≤ d) (h2 : (2 : K) ≠ 0) {c : K} (hc : c ≠ 0)
    (r : Fin (n + 1) → K) (s s' : Fin (n + 1) → Fin (d + 1) → K) (h : SlotLink masked s s' r) :
    ∃ Δ : CfsCoeffs K n d, ∀ a, slotView masked s c r a = slotView masked s' c r (a + Δ) := by
  cases masked with
  | true =>
    have h' : (chainDefect s r).2 = (chainDefect s' r).2 := h
    obtain ⟨Δ, hΔ⟩ := cfsViewMasked_shift hd h2 hc r s s' h'
    exact ⟨Δ, fun a => hΔ a⟩
  | false =>
    have h' : chainDefect s r = chainDefect s' r := h
    obtain ⟨Δ, hΔ⟩ := cfsView_shift hd h2 hc r s s' h'
    exact ⟨Δ, fun a => hΔ a⟩

/-- **Every slot at once.** The slots' mask coefficients are independent (`Π t, CfsCoeffs K (n t) (d t)`); per-slot
links give ONE translate of all of them carrying every slot's honest view to its simulated view. -/
theorem slots_shift {ns : ℕ} (masked : Fin ns → Bool) (n d : Fin ns → ℕ) (hd : ∀ t, 1 ≤ d t) (h2 : (2 : K) ≠ 0)
    (c : Fin ns → K) (hc : ∀ t, c t ≠ 0) (ρ : (t : Fin ns) → Fin (n t + 1) → K)
    (S S' : (t : Fin ns) → Fin (n t + 1) → Fin (d t + 1) → K) (h : ∀ t, SlotLink (masked t) (S t) (S' t) (ρ t)) :
    ∃ Δ : (t : Fin ns) → CfsCoeffs K (n t) (d t), ∀ a : (t : Fin ns) → CfsCoeffs K (n t) (d t),
      (fun t => slotView (masked t) (S t) (c t) (ρ t) (a t))
        = (fun t => slotView (masked t) (S' t) (c t) (ρ t) ((a + Δ) t)) := by
  choose Δ hΔ using fun t => slotView_shift (masked t) (hd t) h2 (hc t) (ρ t) (S t) (S' t) (h t)
  exact ⟨Δ, fun a => funext fun t => hΔ t (a t)⟩

/-- **Every slot at once, as a law**: for fixed challenges, the slots' joint view has the same law for any two
families of rounds with the same links. -/
theorem slots_law_eq [Fintype K] {ns : ℕ} (masked : Fin ns → Bool) (n d : Fin ns → ℕ) (hd : ∀ t, 1 ≤ d t)
    (h2 : (2 : K) ≠ 0) (c : Fin ns → K) (hc : ∀ t, c t ≠ 0) (ρ : (t : Fin ns) → Fin (n t + 1) → K)
    (S S' : (t : Fin ns) → Fin (n t + 1) → Fin (d t + 1) → K) (h : ∀ t, SlotLink (masked t) (S t) (S' t) (ρ t)) :
    (PMF.uniformOfFintype ((t : Fin ns) → CfsCoeffs K (n t) (d t))).map
        (fun a t => slotView (masked t) (S t) (c t) (ρ t) (a t))
      = (PMF.uniformOfFintype ((t : Fin ns) → CfsCoeffs K (n t) (d t))).map
        (fun a t => slotView (masked t) (S' t) (c t) (ρ t) (a t)) := by
  obtain ⟨Δ, hΔ⟩ := slots_shift masked n d hd h2 c hc ρ S S' h
  have hfun : (fun a : (t : Fin ns) → CfsCoeffs K (n t) (d t) => fun t => slotView (masked t) (S t) (c t) (ρ t) (a t))
      = (fun a : (t : Fin ns) → CfsCoeffs K (n t) (d t) => fun t => slotView (masked t) (S' t) (c t) (ρ t) (a t))
        ∘ (fun a => a + Δ) := funext hΔ
  rw [hfun, ← PMF.map_comp, map_uniform_add_right]

end Slots

/-! ## Independent layers -/

/-- **Two independent layers**: if each has a data-independent law, so does the pair (the `A` and `H` openings, each by
`openingView_law_eq` / `openingViewH_law_eq`, with independent coins). -/
theorem law_eq_prod {Ω Ω' β γ : Type} [Fintype Ω] [Nonempty Ω] [Fintype Ω'] [Nonempty Ω'] (f f' : Ω → β)
    (g g' : Ω' → γ) (hf : (PMF.uniformOfFintype Ω).map f = (PMF.uniformOfFintype Ω).map f')
    (hg : (PMF.uniformOfFintype Ω').map g = (PMF.uniformOfFintype Ω').map g') :
    (PMF.uniformOfFintype (Ω × Ω')).map (fun p => (f p.1, g p.2))
      = (PMF.uniformOfFintype (Ω × Ω')).map (fun p => (f' p.1, g' p.2)) := by
  have e : ∀ (u : Ω → β) (w : Ω' → γ), (PMF.uniformOfFintype (Ω × Ω')).map (fun p => (u p.1, w p.2))
      = ((PMF.uniformOfFintype Ω).map u).bind
          (fun a => ((PMF.uniformOfFintype Ω').map w).map (fun b => (a, b))) := by
    intro u w
    rw [map_pair_eq_bind u (fun a c => (a, w c))]
    congr 1
    funext a
    rw [PMF.map_comp]
    rfl
  rw [e f g, e f' g', hf, hg]

/-- A receipt computed from a view with a data-independent law has a data-independent law. -/
theorem map_comp_law_eq {Ω β γ : Type} [Fintype Ω] [Nonempty Ω] (V V' : Ω → β) (R : β → γ)
    (h : (PMF.uniformOfFintype Ω).map V = (PMF.uniformOfFintype Ω).map V') :
    (PMF.uniformOfFintype Ω).map (fun ω => R (V ω)) = (PMF.uniformOfFintype Ω).map (fun ω => R (V' ω)) := by
  have e : ∀ U : Ω → β, (PMF.uniformOfFintype Ω).map (fun ω => R (U ω)) = ((PMF.uniformOfFintype Ω).map U).map R :=
    fun U => (PMF.map_comp U _ R).symm
  rw [e V, e V', h]

/-! ## One block: the openings, every slot, `M` -/

/-- **One block's whole view, composed** (honest verifier, fixed challenges). Let the openings' view `X₁` have a
data-independent law (`hA`); let every slot `t` (of kind `masked t`, shape `(n t, d t)`) have unmasked rounds
`S e ω₁ t` whose defects are those of rounds `S' (X₁ e ω₁) t` computed from the openings' view (`hdef`, the link of
the masked terminals); and let `M`'s mask-coefficient messages `w` have the functional value of `w'` applied to the
views below (`hV`, the link of the `g(ρ)`'s and `Γ`'s). Then the joint law of (the openings, EVERY slot, `M`) over
independent uniform opening coins, slot masks and `M` coins is the same for every data `e` as for `d₀`. -/
theorem block_view_law_eq_slots_M {K F : Type} [Field K] [Fintype K] [Field F] [Fintype F] {Dt Ω₁ β₁ : Type}
    [Fintype Ω₁] [Nonempty Ω₁] {ns mm r Q q : ℕ} (masked : Fin ns → Bool) (n d : Fin ns → ℕ)
    (X₁ : Dt → Ω₁ → β₁) (d₀ : Dt)
    (hA : ∀ e, (PMF.uniformOfFintype Ω₁).map (X₁ e) = (PMF.uniformOfFintype Ω₁).map (X₁ d₀))
    (hd : ∀ t, 1 ≤ d t) (h2 : (2 : K) ≠ 0) (c : Fin ns → K) (hc : ∀ t, c t ≠ 0)
    (ρ : (t : Fin ns) → Fin (n t + 1) → K)
    (S : Dt → Ω₁ → (t : Fin ns) → Fin (n t + 1) → Fin (d t + 1) → K)
    (S' : β₁ → (t : Fin ns) → Fin (n t + 1) → Fin (d t + 1) → K)
    (hdef : ∀ e ω₁ t, SlotLink (masked t) (S e ω₁ t) (S' (X₁ e ω₁) t) (ρ t))
    (κ : F) (P : MOpenPub F mm r Q q) (hm : 0 < mm) (hmF : (mm : F) ≠ 0) (hy : Function.Injective P.y)
    (hsum : ∀ j < 2 * mm, ∑ i, P.y i ^ j = if j = 0 ∨ j = mm then (mm : F) else 0)
    (hW : ∀ s l, P.Wre s (P.π s l) = 0 ∧ P.Wim s (P.π s l) = 0)
    (hpad : ∀ s (v : Fin mm → F), ∃ g : Fin Q → F,
      ∀ t, (Lagrange.interpolate Finset.univ P.y (v - placePads (P.π s) g)).eval (P.x t) = 0)
    (w : ((t : Fin ns) → CfsCoeffs K (n t) (d t)) → Fin r → Bool → Fin mm → F)
    (w' : β₁ × ((t : Fin ns) → K × (Fin (n t + 1) → Fin (d t + 1) → K) × K) → Fin r → Bool → Fin mm → F)
    (hV : ∀ e ω₁ a,
      mValRe κ P (w a) = mValRe κ P (w' (X₁ e ω₁, fun t => slotView (masked t) (S e ω₁ t) (c t) (ρ t) (a t)))
        ∧ mValIm P (w a) = mValIm P (w' (X₁ e ω₁, fun t => slotView (masked t) (S e ω₁ t) (c t) (ρ t) (a t))))
    (e : Dt) :
    (PMF.uniformOfFintype ((Ω₁ × ((t : Fin ns) → CfsCoeffs K (n t) (d t))) × MCoins F mm r Q)).map
        (fun p => ((X₁ e p.1.1, fun t => slotView (masked t) (S e p.1.1 t) (c t) (ρ t) (p.1.2 t)),
          mOpenView κ P hm (w p.1.2) p.2))
      = (PMF.uniformOfFintype ((Ω₁ × ((t : Fin ns) → CfsCoeffs K (n t) (d t))) × MCoins F mm r Q)).map
        (fun p => ((X₁ d₀ p.1.1, fun t => slotView (masked t) (S d₀ p.1.1 t) (c t) (ρ t) (p.1.2 t)),
          mOpenView κ P hm (w p.1.2) p.2)) := by
  refine block_view_law_eq (Ω₂ := (t : Fin ns) → CfsCoeffs K (n t) (d t)) (Ω₃ := MCoins F mm r Q)
    (β₂ := (t : Fin ns) → K × (Fin (n t + 1) → Fin (d t + 1) → K) × K) (β₃ := MView F mm r q) X₁
    (fun e ω₁ (a : (t : Fin ns) → CfsCoeffs K (n t) (d t)) t => slotView (masked t) (S e ω₁ t) (c t) (ρ t) (a t))
    (fun (a : (t : Fin ns) → CfsCoeffs K (n t) (d t)) (cM : MCoins F mm r Q) => mOpenView κ P hm (w a) cM)
    (fun x (a : (t : Fin ns) → CfsCoeffs K (n t) (d t)) t => slotView (masked t) (S' x t) (c t) (ρ t) (a t))
    (fun y (cM : MCoins F mm r Q) => mOpenView κ P hm (w' y) cM) d₀ hA ?_ ?_ e
  · intro e'
    beta_reduce
    choose Δ hΔ using fun ω₁ => slots_shift masked n d hd h2 c hc ρ (S e' ω₁) (S' (X₁ e' ω₁)) (hdef e' ω₁)
    have hfun : (fun p : Ω₁ × ((t : Fin ns) → CfsCoeffs K (n t) (d t)) =>
          (X₁ e' p.1, fun t => slotView (masked t) (S e' p.1 t) (c t) (ρ t) (p.2 t)))
        = (fun p : Ω₁ × ((t : Fin ns) → CfsCoeffs K (n t) (d t)) =>
          (X₁ e' p.1, fun t => slotView (masked t) (S' (X₁ e' p.1) t) (c t) (ρ t) (p.2 t)))
          ∘ (fun p => (p.1, p.2 + Δ p.1)) := by
      funext p
      exact Prod.ext rfl (hΔ p.1 p.2)
    rw [hfun, ← PMF.map_comp, map_uniform_shift_snd]
  · intro e'
    beta_reduce
    exact mOpenView_joint_law_eq κ P hm hmF hy hsum hW hpad
      (fun ω : Ω₁ × ((t : Fin ns) → CfsCoeffs K (n t) (d t)) =>
        (X₁ e' ω.1, fun t => slotView (masked t) (S e' ω.1 t) (c t) (ρ t) (ω.2 t)))
      (fun ω => w ω.2) w' (fun ω => hV e' ω.1 ω.2)

end ZK60.ZKW16
