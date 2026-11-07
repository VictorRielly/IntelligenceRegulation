/-
D63 step L19 (Statement 2, zero knowledge), part 1: the LAYOUT LINKS of one block's honest-verifier view, so that the
hypothesis `hHV` of `ZKW16Step.fs_step` (and of `ZKW16Shape.zk_within_target_of_shape`) is DERIVED from
`ZKW16View.block_view_law_eq_slots_M` and named properties of the honest prover, generic in the block's shape.

`block_view_law_eq_slots_M` (L14) takes two links as hypotheses about chosen functions: rounds `S'` computed from the
openings' view with the same defects as every slot's honest rounds (`hdef`), and a message family `w'` computed from
the views below `M` with the same functional value as `M`'s honest messages (`hV`). This file replaces both choices by
FACTORING statements, which is what the layout gives:
* `slotDefect`, `slotLink_iff`: what a slot's simulation must match, as one value (a masked slot: its middle defects
  and terminal; an unmasked slot: its whole chain defects);
* `defectRep`, **`hdef_of_defectFun`**: if every slot's defect is a function `δ` of the openings' view, a representative
  family `S'` exists and meets `hdef` (no construction of rounds is needed);
* `slotDefect_honest`: an honest slot (zero gaps, a standalone's claimed sum `0`) has defect `(0, 0, T)`, `T` its
  terminal; so `δ` is "the terminal is a function of the openings' view" (the masked terminals are claim values);
* `mRep`, **`hV_of_mFactor`**: if `M`'s functional value (both components) is a function `Φ` of the views below, a
  representative `w'` exists and meets `hV`;
* **`block_view_law_eq_links`**: `block_view_law_eq_slots_M` with the two factoring hypotheses in place of `S'`, `w'`;
* **`hHV_of_view`**: a receipt that is a function of a view whose law does not depend on the data (at every value
  vector, i.e. at every fixed challenge set) has the same law on every two inputs, through any coin map that pushes the
  uniform coins to the uniform view coins (the hidden salts are the coins the receipt does not read);
* **`hHV_of_blockLinks`**: the assembled form: the block's composed view at every value vector (the openings, every
  slot of any kind, `M`), the two factoring links, and the receipt read off that view give `hHV` for ANY two inputs,
  in particular an input and its stand-in (`hHV_standin`, the exact hypothesis of `zk_within_target_of_shape`).

Generic in the block shape: the slot count `ns`, the kinds `masked`, the shapes `(n t, d t)`, `M`'s geometry
`(mm, r, Q, q)` and the openings' coin and view types are parameters; nothing is W16R2's (R13 and W16R3 are instances).

Every premise is an explicit hypothesis.
-/
import ZK60Formal.ZKW16Shape

namespace ZK60.ZKLinks

open scoped ENNReal
open ZK60.Hiding ZK60.ZKW16

/-! ## The slots' defects factor through the openings' view -/

section Defects

variable {K : Type} [Field K]

/-- **What a slot's simulation must reproduce, as one value.** A masked slot (a private slot, or a host slot: both send
a masked claimed sum, finding L19-1) needs its middle defects and its terminal value; an unmasked slot (a standalone
slot, whose claimed sum `0` is public) needs its whole chain defects. -/
def slotDefect (masked : Bool) {n d : ℕ} (s : Fin (n + 1) → Fin (d + 1) → K) (r : Fin (n + 1) → K) :
    K × (Fin n → K) × K :=
  if masked then (0, (chainDefect s r).2) else chainDefect s r

/-- `SlotLink` is the equality of `slotDefect`. -/
theorem slotLink_iff (masked : Bool) {n d : ℕ} (s s' : Fin (n + 1) → Fin (d + 1) → K) (r : Fin (n + 1) → K) :
    SlotLink masked s s' r ↔ slotDefect masked s r = slotDefect masked s' r := by
  cases masked with
  | true =>
    show (chainDefect s r).2 = (chainDefect s' r).2
      ↔ ((0 : K), (chainDefect s r).2) = ((0 : K), (chainDefect s' r).2)
    exact ⟨fun h => by rw [h], fun h => (Prod.mk.inj h).2⟩
  | false => exact Iff.rfl

/-- **An honest slot's defect**: zero gaps, a claimed sum `0` when unmasked (a standalone zero-check), and terminal
value `T` give the defect `(0, 0, T)`, for either kind. -/
theorem slotDefect_honest (masked : Bool) {n d : ℕ} (s : Fin (n + 1) → Fin (d + 1) → K) (r : Fin (n + 1) → K)
    (T : K) (hmid : (chainDefect s r).2.1 = 0) (hsum : masked = false → (chainDefect s r).1 = 0)
    (hT : (chainDefect s r).2.2 = T) :
    slotDefect masked s r = (0, 0, T) := by
  cases masked with
  | true =>
    show ((0 : K), (chainDefect s r).2) = (0, 0, T)
    exact Prod.ext rfl (Prod.ext hmid hT)
  | false =>
    show chainDefect s r = (0, 0, T)
    exact Prod.ext (hsum rfl) (Prod.ext hmid hT)

open Classical in
/-- **A representative of the defects**: for an openings' view `x`, the honest rounds of SOME data and coins that show
`x` (zero when no data shows `x`). -/
noncomputable def defectRep {Dt Ω₁ β₁ : Type} {ns : ℕ} {n d : Fin ns → ℕ} (X₁ : Dt → Ω₁ → β₁)
    (S : Dt → Ω₁ → (t : Fin ns) → Fin (n t + 1) → Fin (d t + 1) → K) (x : β₁) :
    (t : Fin ns) → Fin (n t + 1) → Fin (d t + 1) → K :=
  if h : ∃ p : Dt × Ω₁, X₁ p.1 p.2 = x then S h.choose.1 h.choose.2 else 0

/-- **The slot link from a factoring of the defects.** If every slot's defect is a function `δ` of the openings' view,
the representative `defectRep` meets `block_view_law_eq_slots_M`'s `hdef`. -/
theorem hdef_of_defectFun {Dt Ω₁ β₁ : Type} {ns : ℕ} (masked : Fin ns → Bool) {n d : Fin ns → ℕ}
    (X₁ : Dt → Ω₁ → β₁) (ρ : (t : Fin ns) → Fin (n t + 1) → K)
    (S : Dt → Ω₁ → (t : Fin ns) → Fin (n t + 1) → Fin (d t + 1) → K)
    (δ : β₁ → (t : Fin ns) → K × (Fin (n t) → K) × K)
    (hfac : ∀ e ω₁ t, slotDefect (masked t) (S e ω₁ t) (ρ t) = δ (X₁ e ω₁) t) :
    ∀ e ω₁ t, SlotLink (masked t) (S e ω₁ t) (defectRep X₁ S (X₁ e ω₁) t) (ρ t) := by
  classical
  intro e ω₁ t
  rw [slotLink_iff]
  have h : ∃ p : Dt × Ω₁, X₁ p.1 p.2 = X₁ e ω₁ := ⟨(e, ω₁), rfl⟩
  have hrep : defectRep X₁ S (X₁ e ω₁) = S h.choose.1 h.choose.2 := by
    unfold defectRep
    rw [dite_eq_left h]
  rw [hrep, hfac, hfac, h.choose_spec]

/-- **The defects factor when the terminals do.** If every slot is honest (zero gaps; a standalone slot's claimed sum
`0`) and its terminal value is a function `T t` of the openings' view (the masked terminals are claim values the
openings show, and the terminal is `poly` of them: `slot_chainDefect`), then the defects factor through the openings'
view with `δ x t = (0, 0, T t x)`. -/
theorem defectFun_of_terminals {Dt Ω₁ β₁ : Type} {ns : ℕ} (masked : Fin ns → Bool) {n d : Fin ns → ℕ}
    (X₁ : Dt → Ω₁ → β₁) (ρ : (t : Fin ns) → Fin (n t + 1) → K)
    (S : Dt → Ω₁ → (t : Fin ns) → Fin (n t + 1) → Fin (d t + 1) → K) (T : (t : Fin ns) → β₁ → K)
    (hmid : ∀ e ω₁ t, (chainDefect (S e ω₁ t) (ρ t)).2.1 = 0)
    (hsum : ∀ e ω₁ t, masked t = false → (chainDefect (S e ω₁ t) (ρ t)).1 = 0)
    (hT : ∀ e ω₁ t, (chainDefect (S e ω₁ t) (ρ t)).2.2 = T t (X₁ e ω₁)) :
    ∀ e ω₁ t, slotDefect (masked t) (S e ω₁ t) (ρ t) = (fun x t => ((0 : K), (0 : Fin (n t) → K), T t x)) (X₁ e ω₁) t :=
  fun e ω₁ t => slotDefect_honest (masked t) _ _ _ (hmid e ω₁ t) (hsum e ω₁ t) (hT e ω₁ t)

end Defects

/-! ## `M`'s functional value factors through the views -/

section MLink

variable {F : Type} [Field F] {mm r Q q : ℕ}

open Classical in
/-- **A representative of `M`'s messages**: for a view `y`, the honest messages of SOME data and coins that show `y`
(zero when none does). -/
noncomputable def mRep {Dt Ω₁ Ωs γ : Type} (Y : Dt → Ω₁ → Ωs → γ) (w : Ωs → Fin r → Bool → Fin mm → F) (y : γ) :
    Fin r → Bool → Fin mm → F :=
  if h : ∃ p : Dt × Ω₁ × Ωs, Y p.1 p.2.1 p.2.2 = y then w h.choose.2.2 else 0

/-- **The `M` link from a factoring of the functional value.** If `M`'s functional value (both components) is a function
`Φ` of the views below it, the representative `mRep` meets `block_view_law_eq_slots_M`'s `hV`. -/
theorem hV_of_mFactor (κ : F) (P : MOpenPub F mm r Q q) {Dt Ω₁ Ωs γ : Type} (Y : Dt → Ω₁ → Ωs → γ)
    (w : Ωs → Fin r → Bool → Fin mm → F) (Φ : γ → F × F)
    (hfac : ∀ e ω₁ a, (mValRe κ P (w a), mValIm P (w a)) = Φ (Y e ω₁ a)) :
    ∀ e ω₁ a, mValRe κ P (w a) = mValRe κ P (mRep Y w (Y e ω₁ a))
      ∧ mValIm P (w a) = mValIm P (mRep Y w (Y e ω₁ a)) := by
  classical
  intro e ω₁ a
  have h : ∃ p : Dt × Ω₁ × Ωs, Y p.1 p.2.1 p.2.2 = Y e ω₁ a := ⟨(e, ω₁, a), rfl⟩
  have hrep : mRep Y w (Y e ω₁ a) = w h.choose.2.2 := by
    unfold mRep
    rw [dite_eq_left h]
  have h1 := hfac e ω₁ a
  have h2 := hfac h.choose.1 h.choose.2.1 h.choose.2.2
  rw [h.choose_spec, ← h1] at h2
  rw [hrep]
  exact ⟨(Prod.mk.inj h2).1.symm, (Prod.mk.inj h2).2.symm⟩

end MLink

/-! ## The block's composed view, with the factoring links -/

/-- **One block's whole view, composed, from the factoring links** (honest verifier, fixed challenges). As
`block_view_law_eq_slots_M`, with its two chosen functions replaced by what the layout gives: every slot's defect is a
function `δ` of the openings' view (`hfac`), and `M`'s functional value is a function `Φ` of the openings' view and
every slot's view (`hM`). -/
theorem block_view_law_eq_links {K F : Type} [Field K] [Fintype K] [Field F] [Fintype F] {Dt Ω₁ β₁ : Type}
    [Fintype Ω₁] [Nonempty Ω₁] {ns mm r Q q : ℕ} (masked : Fin ns → Bool) (n d : Fin ns → ℕ)
    (X₁ : Dt → Ω₁ → β₁) (d₀ : Dt)
    (hA : ∀ e, (PMF.uniformOfFintype Ω₁).map (X₁ e) = (PMF.uniformOfFintype Ω₁).map (X₁ d₀))
    (hd : ∀ t, 1 ≤ d t) (h2 : (2 : K) ≠ 0) (c : Fin ns → K) (hc : ∀ t, c t ≠ 0)
    (ρ : (t : Fin ns) → Fin (n t + 1) → K)
    (S : Dt → Ω₁ → (t : Fin ns) → Fin (n t + 1) → Fin (d t + 1) → K)
    (δ : β₁ → (t : Fin ns) → K × (Fin (n t) → K) × K)
    (hfac : ∀ e ω₁ t, slotDefect (masked t) (S e ω₁ t) (ρ t) = δ (X₁ e ω₁) t)
    (κ : F) (P : MOpenPub F mm r Q q) (hm : 0 < mm) (hmF : (mm : F) ≠ 0) (hy : Function.Injective P.y)
    (hsum : ∀ j < 2 * mm, ∑ i, P.y i ^ j = if j = 0 ∨ j = mm then (mm : F) else 0)
    (hW : ∀ s l, P.Wre s (P.π s l) = 0 ∧ P.Wim s (P.π s l) = 0)
    (hpad : ∀ s (v : Fin mm → F), ∃ g : Fin Q → F,
      ∀ t, (Lagrange.interpolate Finset.univ P.y (v - placePads (P.π s) g)).eval (P.x t) = 0)
    (w : ((t : Fin ns) → CfsCoeffs K (n t) (d t)) → Fin r → Bool → Fin mm → F)
    (Φ : β₁ × ((t : Fin ns) → K × (Fin (n t + 1) → Fin (d t + 1) → K) × K) → F × F)
    (hM : ∀ e ω₁ a, (mValRe κ P (w a), mValIm P (w a))
      = Φ (X₁ e ω₁, fun t => slotView (masked t) (S e ω₁ t) (c t) (ρ t) (a t)))
    (e : Dt) :
    (PMF.uniformOfFintype ((Ω₁ × ((t : Fin ns) → CfsCoeffs K (n t) (d t))) × MCoins F mm r Q)).map
        (fun p => ((X₁ e p.1.1, fun t => slotView (masked t) (S e p.1.1 t) (c t) (ρ t) (p.1.2 t)),
          mOpenView κ P hm (w p.1.2) p.2))
      = (PMF.uniformOfFintype ((Ω₁ × ((t : Fin ns) → CfsCoeffs K (n t) (d t))) × MCoins F mm r Q)).map
        (fun p => ((X₁ d₀ p.1.1, fun t => slotView (masked t) (S d₀ p.1.1 t) (c t) (ρ t) (p.1.2 t)),
          mOpenView κ P hm (w p.1.2) p.2)) :=
  block_view_law_eq_slots_M masked n d X₁ d₀ hA hd h2 c hc ρ S (defectRep X₁ S)
    (hdef_of_defectFun masked X₁ ρ S δ hfac) κ P hm hmF hy hsum hW hpad w
    (mRep (fun e ω₁ (a : (t : Fin ns) → CfsCoeffs K (n t) (d t)) =>
      (X₁ e ω₁, fun t => slotView (masked t) (S e ω₁ t) (c t) (ρ t) (a t))) w)
    (hV_of_mFactor κ P (fun e ω₁ (a : (t : Fin ns) → CfsCoeffs K (n t) (d t)) =>
      (X₁ e ω₁, fun t => slotView (masked t) (S e ω₁ t) (c t) (ρ t) (a t))) w Φ hM) e

/-! ## The receipt: `hHV` -/

section Receipt

/-- **A receipt read off a data-independent view has a data-independent law.** Let the coin map `π` push the uniform
coins of the receipt to the uniform coins of the view (`hπ`; the coins the receipt does not read, such as the salts of
the unopened columns, are integrated out), let the receipt at every value vector `v` be a function `Rc v` of the view
(`hout`), and let the view's law at every `v` be the same for every input as for `x₀` (`hlaw`). Then the receipts of
any two inputs have the same law at every `v`: `fs_step`'s `hHV`. -/
theorem hHV_of_view {Q D X C Out : Type} [Fintype C] [Nonempty C] (FM : FSModel Q D X C Out)
    {Ω β : Type} [Fintype Ω] [Nonempty Ω] (π : C → Ω)
    (hπ : (PMF.uniformOfFintype C).map π = PMF.uniformOfFintype Ω)
    (V : X → (Fin FM.k → D) → Ω → β) (Rc : (Fin FM.k → D) → β → Out)
    (hout : ∀ x c v, FM.out x c v = Rc v (V x v (π c)))
    (x₀ : X) (hlaw : ∀ v x, (PMF.uniformOfFintype Ω).map (V x v) = (PMF.uniformOfFintype Ω).map (V x₀ v)) :
    ∀ x x' (v : Fin FM.k → D), (PMF.uniformOfFintype C).map (fun c => FM.out x c v)
      = (PMF.uniformOfFintype C).map (fun c => FM.out x' c v) := by
  have e : ∀ x (v : Fin FM.k → D), (PMF.uniformOfFintype C).map (fun c => FM.out x c v)
      = ((PMF.uniformOfFintype Ω).map (V x v)).map (Rc v) := by
    intro x v
    have hfun : (fun c => FM.out x c v) = (fun ω => Rc v (V x v ω)) ∘ π := funext fun c => hout x c v
    rw [hfun, ← PMF.map_comp, hπ, PMF.map_comp]
    rfl
  intro x x' v
  rw [e x v, e x' v, hlaw v x, hlaw v x']

/-- **The assembled link (one block, every value vector).** At every value vector `v` (every fixed challenge set) let
the block's view be L14's composed view: the openings' view `X₁ v x`, every slot's view at its kind (`masked`), its
shape, its challenges `c v`, `ρ v` and honest rounds `S v x`, and `M`'s opening view at public data `P v` of the honest
messages `w v`. Suppose the links hold at every `v`: the openings' law does not depend on the input (`hA`), every
slot's defect is a function `δ v` of the openings' view (`hfac`), and `M`'s functional value is a function `Φ v` of the
views below (`hM`); and the receipt is read off that view through a coin map `π` that pushes the uniform coins to the
uniform view coins (`hπ`, `hout`). Then `hHV` holds for every two inputs. -/
theorem hHV_of_blockLinks {K F : Type} [Field K] [Fintype K] [Field F] [Fintype F]
    {Q D X C Out : Type} [Fintype C] [Nonempty C] (FM : FSModel Q D X C Out)
    {Ω₁ β₁ : Type} [Fintype Ω₁] [Nonempty Ω₁] {ns mm r Qm q : ℕ} (masked : Fin ns → Bool) (n d : Fin ns → ℕ)
    (hd : ∀ t, 1 ≤ d t) (h2 : (2 : K) ≠ 0) (hm : 0 < mm) (hmF : (mm : F) ≠ 0) (κ : F)
    (X₁ : (Fin FM.k → D) → X → Ω₁ → β₁) (x₀ : X)
    (hA : ∀ v x, (PMF.uniformOfFintype Ω₁).map (X₁ v x) = (PMF.uniformOfFintype Ω₁).map (X₁ v x₀))
    (c : (Fin FM.k → D) → Fin ns → K) (hc : ∀ v t, c v t ≠ 0)
    (ρ : (Fin FM.k → D) → (t : Fin ns) → Fin (n t + 1) → K)
    (S : (Fin FM.k → D) → X → Ω₁ → (t : Fin ns) → Fin (n t + 1) → Fin (d t + 1) → K)
    (δ : (Fin FM.k → D) → β₁ → (t : Fin ns) → K × (Fin (n t) → K) × K)
    (hfac : ∀ v x ω₁ t, slotDefect (masked t) (S v x ω₁ t) (ρ v t) = δ v (X₁ v x ω₁) t)
    (P : (Fin FM.k → D) → MOpenPub F mm r Qm q) (hy : ∀ v, Function.Injective (P v).y)
    (hsum : ∀ v, ∀ j < 2 * mm, ∑ i, (P v).y i ^ j = if j = 0 ∨ j = mm then (mm : F) else 0)
    (hW : ∀ v s l, (P v).Wre s ((P v).π s l) = 0 ∧ (P v).Wim s ((P v).π s l) = 0)
    (hpad : ∀ v s (u : Fin mm → F), ∃ g : Fin Qm → F,
      ∀ t, (Lagrange.interpolate Finset.univ (P v).y (u - placePads ((P v).π s) g)).eval ((P v).x t) = 0)
    (w : (Fin FM.k → D) → ((t : Fin ns) → CfsCoeffs K (n t) (d t)) → Fin r → Bool → Fin mm → F)
    (Φ : (Fin FM.k → D) → β₁ × ((t : Fin ns) → K × (Fin (n t + 1) → Fin (d t + 1) → K) × K) → F × F)
    (hM : ∀ v x ω₁ a, (mValRe κ (P v) (w v a), mValIm (P v) (w v a))
      = Φ v (X₁ v x ω₁, fun t => slotView (masked t) (S v x ω₁ t) (c v t) (ρ v t) (a t)))
    (π : C → (Ω₁ × ((t : Fin ns) → CfsCoeffs K (n t) (d t))) × MCoins F mm r Qm)
    (hπ : (PMF.uniformOfFintype C).map π
      = PMF.uniformOfFintype ((Ω₁ × ((t : Fin ns) → CfsCoeffs K (n t) (d t))) × MCoins F mm r Qm))
    (Rc : (Fin FM.k → D) →
      (β₁ × ((t : Fin ns) → K × (Fin (n t + 1) → Fin (d t + 1) → K) × K)) × MView F mm r q → Out)
    (hout : ∀ x c' v, FM.out x c' v = Rc v
      ((X₁ v x (π c').1.1, fun t => slotView (masked t) (S v x (π c').1.1 t) (c v t) (ρ v t) ((π c').1.2 t)),
        mOpenView κ (P v) hm (w v (π c').1.2) (π c').2)) :
    ∀ x x' (v : Fin FM.k → D), (PMF.uniformOfFintype C).map (fun c' => FM.out x c' v)
      = (PMF.uniformOfFintype C).map (fun c' => FM.out x' c' v) :=
  hHV_of_view FM π hπ
    (fun x v p => ((X₁ v x p.1.1, fun t => slotView (masked t) (S v x p.1.1 t) (c v t) (ρ v t) (p.1.2 t)),
      mOpenView κ (P v) hm (w v p.1.2) p.2)) Rc hout x₀
    (fun v x => block_view_law_eq_links masked n d (X₁ v) x₀ (hA v) hd h2 (c v) (hc v) (ρ v) (S v) (δ v)
      (hfac v) κ (P v) hm hmF (hy v) (hsum v) (hW v) (hpad v) (w v) (Φ v) (hM v) x)

/-- **`hHV` in the stand-in form** (the hypothesis of `oneStep_of_fsModel`, `w16r2_zeroKnowledge_of_fsModel` and
`zk_within_target_of_shape`): any input against its stand-in, from the any-two-inputs form. -/
theorem hHV_standin {Q D Coins : Type} {M : IntModel} {P : Protocol Q D Coins M} [Inhabited M.Input]
    [Fintype Coins] [Nonempty Coins] (FM : M.Weights → FSModel Q D M.Input Coins (P.Stmt × P.Receipt))
    (h : ∀ W x x' (v : Fin (FM W).k → D), (PMF.uniformOfFintype Coins).map (fun c => (FM W).out x c v)
      = (PMF.uniformOfFintype Coins).map (fun c => (FM W).out x' c v)) :
    ∀ W x (v : Fin (FM W).k → D), (PMF.uniformOfFintype Coins).map (fun c => (FM W).out x c v)
      = (PMF.uniformOfFintype Coins).map
          (fun c => (FM W).out (standin P W (M.publicPart (M.forward W x), P.leak x)) c v) :=
  fun W x v => h W x _ v

end Receipt

end ZK60.ZKLinks
