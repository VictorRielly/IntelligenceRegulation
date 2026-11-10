/-
D63 lane L33 (2026-11-09), part 3: **the honest-verifier law of a receipt, relative to its public part, and an honest
block's composed view from the honest prover's primitive facts** (L19's hypotheses `hfac` and `hM` as theorems).

L19's `hHV_of_view` / `hHV_of_layers` conclude the law equality for EVERY two inputs. The classify run's statement
carries the public verdict, so its receipts on two inputs with different verdicts differ: the instance needs the law
equality only between inputs with the SAME public part (an input and its stand-in), and only at the value vectors
where no refusal fires (`ZKHonestStep.lean`'s guard). Finding L33-2.

* **`hHV_rel_of_view`**, **`hHV_rel_of_layers`**: a receipt that is a function of the public part and of a view (a
  family of independent layers) whose law is the same for inputs with the same public part has the same law on two such
  inputs, at every value vector where the guard does not fire;
* **`honest_roundSum`**, **`honest_hfac`**: for the honest rounds of L25 (`honestCo` of the slot's polynomial `f`), the
  claimed sum is `Σ f` and L19's slot defect is `(0, 0, T)` as soon as the terminal `f(ρ)` is the function `T` of the
  openings' view (`hterm`, L19's `hclaim` through `terminal_of_claims`): `hfac` for every slot of any kind;
* **`honest_mHonest`**: `M`'s functionals in the code's order (`codeFunsAt`) meet L19's honest conditions from the
  hand-off (`hhosted`) and the honest host sums stated on the POLYNOMIALS (`hsumH`);
* **`honest_block_view_law_eq`**: an honest block's whole composed view (the openings, every slot, `M`) has the same
  law for every data, from: the openings' law (`hA`, L19's `openingsAH_law_eq`), the slot polynomials' degrees, a
  standalone's zero sum, the terminal link `hterm`, the hand-off, the host sums and `M`'s layout `hlay`. The honest
  rounds' properties (zero gaps, the claimed sum, the terminal) and the two factoring links are DISCHARGED here; the
  same theorem serves a stage (its own slot list);
* `w16Hosts`, **`w16_hhosted`**: the hand-off as a theorem for the W16R2 slot schedule, which the R13 blocks share
  (L13's `kindOf`, `hostsOf`; L19's `w16r2_hosted_priv`): every host's hosted slots are masked.

Every premise is an explicit hypothesis.
-/
import ZK60Formal.ZKLinksRun
import ZK60Formal.HonestClassifyLinks
import ZK60Formal.ZKHonestStep

set_option autoImplicit false

namespace ZK60.ZKHonest

open scoped ENNReal
open ZK60 ZK60.ZKW16 ZK60.Hiding ZK60.Sound ZK60.ZKLinks ZK60.HonestClassify
open ZK60.Exec.Slot.W16R2 (Kind kindOf hostsOf nSlots)

/-! ## The law of a receipt relative to its public part -/

/-- **A receipt read off a view, relative to the public part** (L19's `hHV_of_view` for a statement that carries a
public output). Let the coin map `π` push the uniform coins to the view's uniform coins (`hπ`), let the receipt at a
value vector where the guard `G` does not fire be a function `Rc` of the input's public part and of the view (`hout`),
and let the view's law be the same for two inputs with the same public part (`hlaw`). Then two such inputs have
receipts of the same law at every value vector where the guard does not fire. -/
theorem hHV_rel_of_view {Q D X C Out : Type} [Fintype C] [Nonempty C] (FM : FSModel Q D X C Out)
    {Ω β Pub : Type} [Fintype Ω] [Nonempty Ω] (π : C → Ω)
    (hπ : (PMF.uniformOfFintype C).map π = PMF.uniformOfFintype Ω) (pub : X → Pub)
    (V : X → (Fin FM.k → D) → Ω → β) (Rc : Pub → (Fin FM.k → D) → β → Out) (G : (Fin FM.k → D) → Prop)
    (hout : ∀ x c v, ¬ G v → FM.out x c v = Rc (pub x) v (V x v (π c)))
    (hlaw : ∀ v x x', pub x = pub x' → ¬ G v →
      (PMF.uniformOfFintype Ω).map (V x v) = (PMF.uniformOfFintype Ω).map (V x' v)) :
    ∀ x x', pub x = pub x' → ∀ v : Fin FM.k → D, ¬ G v →
      (PMF.uniformOfFintype C).map (fun c => FM.out x c v) = (PMF.uniformOfFintype C).map (fun c => FM.out x' c v) := by
  intro x x' hp v hg
  have e : ∀ y, (PMF.uniformOfFintype C).map (fun c => FM.out y c v)
      = ((PMF.uniformOfFintype Ω).map (V y v)).map (Rc (pub y) v) := by
    intro y
    have hfun : (fun c => FM.out y c v) = (fun ω => Rc (pub y) v (V y v ω)) ∘ π := funext fun c => hout y c v hg
    rw [hfun, ← PMF.map_comp, hπ, PMF.map_comp]
    rfl
  rw [e x, e x', hlaw v x x' hp hg, hp]

/-- **A run receipt read off independent layers, relative to the public part** (L19's `hHV_of_layers`): the run's
coins push to the layers' independent coins, the receipt is a function of the public part and of the family of layer
views, and every layer's law is the same for two inputs with the same public part. -/
theorem hHV_rel_of_layers {Q D X C Out : Type} [Fintype C] [Nonempty C] (FM : FSModel Q D X C Out) {n : ℕ}
    {Ω β : Fin n → Type} {Pub : Type} [∀ i, Fintype (Ω i)] [∀ i, Nonempty (Ω i)] [∀ i, DecidableEq (β i)]
    (π : C → (i : Fin n) → Ω i)
    (hπ : (PMF.uniformOfFintype C).map π = PMF.uniformOfFintype ((i : Fin n) → Ω i)) (pub : X → Pub)
    (Vl : (Fin FM.k → D) → X → (i : Fin n) → Ω i → β i)
    (Rc : Pub → (Fin FM.k → D) → ((i : Fin n) → β i) → Out) (G : (Fin FM.k → D) → Prop)
    (hout : ∀ x c v, ¬ G v → FM.out x c v = Rc (pub x) v (fun i => Vl v x i (π c i)))
    (hlay : ∀ v x x' i, pub x = pub x' → ¬ G v →
      (PMF.uniformOfFintype (Ω i)).map (Vl v x i) = (PMF.uniformOfFintype (Ω i)).map (Vl v x' i)) :
    ∀ x x', pub x = pub x' → ∀ v : Fin FM.k → D, ¬ G v →
      (PMF.uniformOfFintype C).map (fun c => FM.out x c v) = (PMF.uniformOfFintype C).map (fun c => FM.out x' c v) :=
  hHV_rel_of_view FM π hπ pub (fun x v ω i => Vl v x i (ω i)) Rc G hout
    (fun v x x' hp hg => law_eq_pi (fun i => Vl v x i) (fun i => Vl v x' i) (fun i => hlay v x x' i hp hg))

/-! ## The honest rounds: `hfac` and the functionals' honest conditions -/

section Honest

variable {K : Type} [Field K]

/-- **The honest rounds' claimed sum is the true sum** (`chainDefect_honestCo`'s first part). -/
theorem honest_roundSum {d : ℕ} (hd : d < ringChar K) (n : ℕ) (f : (Fin (n + 1) → K) → K) (r : Fin (n + 1) → K)
    (hf : IndDegLE d f) : roundSum (honestCo d n f r 0) = cubeSum f :=
  congrArg Prod.fst (chainDefect_honestCo hd n f r hf)

/-- **`hfac` for honest slots.** If every slot's rounds are the honest rounds of its polynomial `f` (of the slot's
degree; a standalone slot's true sum `0`) and the polynomial's value at the challenges is a function `T` of the
openings' view (`hterm`), every slot's defect is the function `(0, 0, T)` of the openings' view. -/
theorem honest_hfac {Dt Ω₁ β₁ : Type} {ns : ℕ} (kind : Fin ns → Kind) (n d : Fin ns → ℕ)
    (hdc : ∀ t, d t < ringChar K) (X₁ : Dt → Ω₁ → β₁) (ρ : (t : Fin ns) → Fin (n t + 1) → K)
    (f : Dt → Ω₁ → (t : Fin ns) → (Fin (n t + 1) → K) → K) (hf : ∀ e ω₁ t, IndDegLE (d t) (f e ω₁ t))
    (hstd : ∀ e ω₁ t, kind t = .standalone → cubeSum (f e ω₁ t) = 0)
    (T : (t : Fin ns) → β₁ → K) (hterm : ∀ e ω₁ t, f e ω₁ t (ρ t) = T t (X₁ e ω₁)) :
    ∀ e ω₁ t, slotDefect (maskedOfKind (kind t)) (honestCo (d t) (n t) (f e ω₁ t) (ρ t)) (ρ t)
      = (fun x t => ((0 : K), (0 : Fin (n t) → K), T t x)) (X₁ e ω₁) t := by
  intro e ω₁ t
  rw [slotDefect_honestCo (hdc t) (maskedOfKind (kind t)) (n t) (f e ω₁ t) (ρ t) (hf e ω₁ t)
    (fun h => hstd e ω₁ t ((maskedOfKind_false_iff (kind t)).mp h)), hterm e ω₁ t]

/-- **The code's functional list meets the honest conditions** for the honest rounds, from the hand-off and the
honest host sums stated on the slot polynomials. -/
theorem honest_mHonest {ns : ℕ} (kind : Fin ns → Kind) (hosts : Fin ns → List (Fin ns × K)) (n d : Fin ns → ℕ)
    (hdc : ∀ t, d t < ringChar K) (ρ : (t : Fin ns) → Fin (n t + 1) → K)
    (f : (t : Fin ns) → (Fin (n t + 1) → K) → K) (hf : ∀ t, IndDegLE (d t) (f t))
    (hhosted : ∀ s, kind s = .host → ∀ p ∈ hosts s, maskedOfKind (kind p.1) = true)
    (hsumH : ∀ s, kind s = .host → cubeSum (f s) = ((hosts s).map (fun p => p.2 * cubeSum (f p.1))).sum) :
    ∀ i, MHonest (fun t => maskedOfKind (kind t)) (fun t => honestCo (d t) (n t) (f t) (ρ t))
      (codeFunsAt ns kind hosts i) := by
  refine codeFunsAt_honest kind hosts (fun t => honestCo (d t) (n t) (f t) (ρ t)) hhosted (fun s hs => ?_)
  have hmap : (hosts s).map (fun p => p.2 * roundSum (honestCo (d p.1) (n p.1) (f p.1) (ρ p.1) 0))
      = (hosts s).map (fun p => p.2 * cubeSum (f p.1)) :=
    List.map_congr_left (fun p _ => by rw [honest_roundSum (hdc p.1) (n p.1) (f p.1) (ρ p.1) (hf p.1)])
  show roundSum (honestCo (d s) (n s) (f s) (ρ s) 0)
    = ((hosts s).map (fun p => p.2 * roundSum (honestCo (d p.1) (n p.1) (f p.1) (ρ p.1) 0))).sum
  rw [hmap, honest_roundSum (hdc s) (n s) (f s) (ρ s) (hf s)]
  exact hsumH s hs

end Honest

/-! ## An honest block's composed view -/

/-- **An honest block's whole view has a data-independent law** (L19's `block_view_law_eq_links` with its two
factoring links DISCHARGED for the honest prover). At fixed challenges: the openings' view `X₁` has a data-independent
law (`hA`: L19's `openingsAH_law_eq`); every slot's rounds are the honest rounds of its polynomial `f e ω₁ t`
(L25's `honestCo`), of the slot's degree, a standalone's true sum `0`; the polynomial's value at the challenges is the
function `T t` of the openings' view (`hterm`: the masked terminals are claim values the openings show); the hosted
slots of every host are masked (`hhosted`) and a host's true sum is `Σ ν_k·S_k` (`hsumH`); and `M`'s honest messages and
weights carry the θ-combined functional of the code's list (`hlay`). Then the joint law of the openings' view, every
slot's view and `M`'s opening view is the same for every data `e` as for `d₀`. -/
theorem honest_block_view_law_eq {K F : Type} [Field K] [Fintype K] [Field F] [Fintype F] [Algebra F K]
    {Dt Ω₁ β₁ : Type} [Fintype Ω₁] [Nonempty Ω₁] {ns mm r Q q : ℕ} (kind : Fin ns → Kind)
    (hosts : Fin ns → List (Fin ns × K)) (n d : Fin ns → ℕ) (X₁ : Dt → Ω₁ → β₁) (d₀ : Dt)
    (hA : ∀ e, (PMF.uniformOfFintype Ω₁).map (X₁ e) = (PMF.uniformOfFintype Ω₁).map (X₁ d₀))
    (hd : ∀ t, 1 ≤ d t) (hdc : ∀ t, d t < ringChar K) (h2 : (2 : K) ≠ 0) (c : Fin ns → K) (hc : ∀ t, c t ≠ 0)
    (ρ : (t : Fin ns) → Fin (n t + 1) → K)
    (f : Dt → Ω₁ → (t : Fin ns) → (Fin (n t + 1) → K) → K) (hf : ∀ e ω₁ t, IndDegLE (d t) (f e ω₁ t))
    (hstd : ∀ e ω₁ t, kind t = .standalone → cubeSum (f e ω₁ t) = 0)
    (T : (t : Fin ns) → β₁ → K) (hterm : ∀ e ω₁ t, f e ω₁ t (ρ t) = T t (X₁ e ω₁))
    (hhosted : ∀ s, kind s = .host → ∀ p ∈ hosts s, maskedOfKind (kind p.1) = true)
    (hsumH : ∀ e ω₁ s, kind s = .host →
      cubeSum (f e ω₁ s) = ((hosts s).map (fun p => p.2 * cubeSum (f e ω₁ p.1))).sum)
    (U θ : K) (hU : U ∉ Set.range (algebraMap F K)) (κ : F) (hU2 : U ^ 2 = algebraMap F K κ)
    (P : MOpenPub F mm r Q q) (hm : 0 < mm) (hmF : (mm : F) ≠ 0) (hy : Function.Injective P.y)
    (hsum : ∀ j < 2 * mm, ∑ i, P.y i ^ j = if j = 0 ∨ j = mm then (mm : F) else 0)
    (hW : ∀ s l, P.Wre s (P.π s l) = 0 ∧ P.Wim s (P.π s l) = 0)
    (hpad : ∀ s (v : Fin mm → F), ∃ g : Fin Q → F,
      ∀ t, (Lagrange.interpolate Finset.univ P.y (v - placePads (P.π s) g)).eval (P.x t) = 0)
    (w : ((t : Fin ns) → CfsCoeffs K (n t) (d t)) → Fin r → Bool → Fin mm → F)
    (hlay : ∀ a, ∑ s, ∑ i, fp2 U (w a s true i, w a s false i) * fp2 U (P.Wre s i, P.Wim s i)
      = mfComb θ (codeFunsAt ns kind hosts) c ρ a)
    (e : Dt) :
    (PMF.uniformOfFintype ((Ω₁ × ((t : Fin ns) → CfsCoeffs K (n t) (d t))) × MCoins F mm r Q)).map
        (fun p => ((X₁ e p.1.1, fun t => slotView (maskedOfKind (kind t))
            (honestCo (d t) (n t) (f e p.1.1 t) (ρ t)) (c t) (ρ t) (p.1.2 t)),
          mOpenView κ P hm (w p.1.2) p.2))
      = (PMF.uniformOfFintype ((Ω₁ × ((t : Fin ns) → CfsCoeffs K (n t) (d t))) × MCoins F mm r Q)).map
        (fun p => ((X₁ d₀ p.1.1, fun t => slotView (maskedOfKind (kind t))
            (honestCo (d t) (n t) (f d₀ p.1.1 t) (ρ t)) (c t) (ρ t) (p.1.2 t)),
          mOpenView κ P hm (w p.1.2) p.2)) :=
  block_view_law_eq_links (fun t => maskedOfKind (kind t)) n d X₁ d₀ hA hd h2 c hc ρ
    (fun e ω₁ t => honestCo (d t) (n t) (f e ω₁ t) (ρ t)) (fun x t => ((0 : K), (0 : Fin (n t) → K), T t x))
    (honest_hfac kind n d hdc X₁ ρ f hf hstd T hterm) κ P hm hmF hy hsum hW hpad w
    (mPhi (F := F) U θ (codeFunsAt ns kind hosts) c)
    (mFactor_of_funs hU (codeFunsAt ns kind hosts) (fun t => maskedOfKind (kind t)) X₁
      (fun e ω₁ t => honestCo (d t) (n t) (f e ω₁ t) (ρ t)) c ρ
      (fun e ω₁ => honest_mHonest kind hosts n d hdc ρ (f e ω₁) (hf e ω₁) hhosted (hsumH e ω₁)) κ P w
      (hMK_of_K hU2 (codeFunsAt ns kind hosts) c ρ P w hlay)) e

/-! ## The hand-off at the W16R2 / R13 slot schedule -/

/-- **The hosts' lists of the W16R2 slot schedule** (which the R13 blocks share: `SlotR13.lean`), with the hand-off
coefficients `ν`: slot `t`'s hosted slots `hostsOf t` (L13) as indices below `nSlots`. -/
def w16Hosts {K : Type} (ν : Fin nSlots → ℕ → K) (t : Fin nSlots) : List (Fin nSlots × K) :=
  (hostsOf t.val).filterMap (fun s => if h : s < nSlots then some (⟨s, h⟩, ν t s) else none)

/-- **The hand-off, a theorem for the W16R2 / R13 slot schedule**: every hosted slot of a host is a private slot,
hence masked (L19's `codeFuns_honest`'s `hhosted`, from `w16r2_hosted_priv`). -/
theorem w16_hhosted {K : Type} (ν : Fin nSlots → ℕ → K) :
    ∀ s : Fin nSlots, kindOf s.val = .host → ∀ p ∈ w16Hosts ν s, maskedOfKind (kindOf p.1.val) = true := by
  intro s _ p hp
  obtain ⟨j, hj, hjp⟩ := List.mem_filterMap.mp hp
  by_cases h : j < nSlots
  · rw [dite_eq_left h] at hjp
    have hp1 : p.1 = ⟨j, h⟩ := (congrArg Prod.fst (Option.some.inj hjp)).symm
    have hv : p.1.val = j := congrArg Fin.val hp1
    have hk : kindOf j = Kind.priv := (w16r2_hosted_priv s j hj).1
    exact (congrArg (fun m => maskedOfKind (kindOf m)) hv).trans ((congrArg maskedOfKind hk).trans rfl)
  · rw [dite_eq_right h] at hjp
    cases hjp

end ZK60.ZKHonest
