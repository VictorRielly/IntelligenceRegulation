/-
D63 step L19 (Statement 2, zero knowledge), part 2: the per-profile LINKS as Lean functions, for `ZKLinks`'s factoring
hypotheses: which `M` functional is which `g(ρ)` or `Γ`, a host's published scalar, the code's slot kinds, and the
openings' layer at the opened set.

* **`M`'s functionals** (`MFun`; argument.rs:1478-1495, `acc.fs` / `acc.host_fs`): a standalone slot's `Γ` (`c·G`,
  `sum_weights·c`), every slot's evaluation (`g(ρ)`, `eval_weights`), a host's `Γ` (`c·G − Σ ν_k·c_k·G_k`). Their
  value on the masks (`mfMask`, what `M` proves) and on the views (`mfView`, what the verifier computes); **`mfMask_eq_
  mfView`**: for an honest prover (`MHonest`) they agree. With the θ-combination at offset 1 (D65(1), L10:
  `θ^(i+1)`) and the code's reading of an `Fp2` pair (`fp2`, injective), **`mFactor_of_funs`** gives `ZKLinks`'s
  `M` factoring `hM` from ONE layout hypothesis: `M`'s committed messages and weights carry the θ-combined mask
  functional (`hMK`, the `CfsMask`-to-a-rows layout).
* **The host's published scalar** (`hostScalar_of_views`, argument.rs:1273-1275): `c·G − Σ ν_k·c_k·G_k` is the host's
  masked claimed sum minus the hosted slots' masked scalars, for an honest host (its unmasked sum is `Σ ν_k·S_k`):
  the receipt's scalar is a function of the slot views (the receipt half of `ZKLinks.hout`).
* **The code's kinds** (`maskedOfKind`, finding L19-1): a private AND a host slot are masked slots; only a standalone
  slot is unmasked. `w16r2_hosted_priv`: every W16R2 host's hosted slots are private and come before it (`decide`).
  `codeFuns`: the functional list in the code's order, and `codeFuns_honest`.
* **The openings' layer at the opened set** (`padSurj_of_points`, `openingsAH_law_eq`): the `A` and `H` openings with
  independent coins, at most `Q` distinct opened points outside the message domain, have a data-independent joint law:
  `ZKLinks`'s `hA`.

Every premise is an explicit hypothesis.
-/
import ZK60Formal.ZKLinks
import ZK60Formal.HidingOpeningSum
import ZK60Formal.SlotW16R2

namespace ZK60.ZKLinks

open scoped ENNReal
open ZK60.Hiding ZK60.ZKW16

/-! ## One slot's view by kind -/

section SlotViews

variable {K : Type} [Field K]

theorem slotView_true {masked : Bool} (h : masked = true) {n d : ℕ} (s : Fin (n + 1) → Fin (d + 1) → K) (c : K)
    (r : Fin (n + 1) → K) (a : CfsCoeffs K n d) : slotView masked s c r a = cfsViewMasked s c r a := by
  subst h
  rfl

theorem slotView_false {masked : Bool} (h : masked = false) {n d : ℕ} (s : Fin (n + 1) → Fin (d + 1) → K) (c : K)
    (r : Fin (n + 1) → K) (a : CfsCoeffs K n d) : slotView masked s c r a = cfsView s c r a := by
  subst h
  rfl

/-- A slot's `g(ρ)` is the third part of its view, for either kind. -/
theorem slotView_eval (masked : Bool) {n d : ℕ} (s : Fin (n + 1) → Fin (d + 1) → K) (c : K) (r : Fin (n + 1) → K)
    (a : CfsCoeffs K n d) : (slotView masked s c r a).2.2 = cfsEval a r := by
  cases masked <;> rfl

/-- **A host's published scalar from the views** (argument.rs:1273-1275). An honest host (masked) with hosted masked
slots `hs` (coefficients `ν`), whose unmasked claimed sum is `Σ ν_k·S_k` (`hsum`, the host polynomial's cube sum
`host_cubeSum` with a true relation), publishes `c·G − Σ ν_k·c_k·G_k`, which equals its masked claimed sum minus the
hosted slots' masked scalars: a function of the slot views. -/
theorem hostScalar_of_views {ns : ℕ} (masked : Fin ns → Bool) (n d : Fin ns → ℕ)
    (S : (t : Fin ns) → Fin (n t + 1) → Fin (d t + 1) → K) (c : Fin ns → K) (ρ : (t : Fin ns) → Fin (n t + 1) → K)
    (a : (t : Fin ns) → CfsCoeffs K (n t) (d t)) (t : Fin ns) (hs : List (Fin ns × K))
    (ht : masked t = true) (hk : ∀ p ∈ hs, masked p.1 = true)
    (hsum : roundSum (S t 0) = (hs.map (fun p => p.2 * roundSum (S p.1 0))).sum) :
    c t * cfsTotal (a t) - (hs.map (fun p => p.2 * (c p.1 * cfsTotal (a p.1)))).sum
      = (slotView (masked t) (S t) (c t) (ρ t) (a t)).1
        - (hs.map (fun p => p.2 * (slotView (masked p.1) (S p.1) (c p.1) (ρ p.1) (a p.1)).1)).sum := by
  have hmap : hs.map (fun p => p.2 * (slotView (masked p.1) (S p.1) (c p.1) (ρ p.1) (a p.1)).1)
      = hs.map (fun p => p.2 * roundSum (S p.1 0) + p.2 * (c p.1 * cfsTotal (a p.1))) := by
    refine List.map_congr_left (fun p hp => ?_)
    rw [slotView_true (hk p hp)]
    show p.2 * (roundSum (S p.1 0) + c p.1 * cfsTotal (a p.1)) = _
    ring
  have hadd : ∀ l : List (Fin ns × K), (l.map (fun p => p.2 * roundSum (S p.1 0) + p.2 * (c p.1 * cfsTotal (a p.1)))).sum
      = (l.map (fun p => p.2 * roundSum (S p.1 0))).sum + (l.map (fun p => p.2 * (c p.1 * cfsTotal (a p.1)))).sum := by
    intro l
    induction l with
    | nil => simp
    | cons p l ih => simp only [List.map_cons, List.sum_cons, ih]; ring
  rw [hmap, hadd, slotView_true ht, ← hsum]
  show _ = roundSum (S t 0) + c t * cfsTotal (a t) - _
  ring

/-- **Which slot claim value is which masked terminal** (argument.rs:1471-1476, `build_claim`; L9's `slotClaims`). A slot
whose rounds are an honest sumcheck of `poly` with one identity extension round (`slot_chainDefect`'s hypotheses) and
whose masked terminals are the claim values `claimVal x (claimOf i)` read off the openings' view `x` has zero gaps and
terminal value `poly` of those claim values: `ZKLinks.defectFun_of_terminals`'s `hmid` and `hT`, with
`T x = poly (claimVal x ∘ claimOf)`. -/
theorem terminal_of_claims {n d m : ℕ} {β₁ ι : Type} (P : (Fin m → K) → K) (fin ext : Fin m → K) (S : K)
    (s : Fin (n + 2) → Fin (d + 1) → K) (r : Fin (n + 2) → K) (h0 : roundSum (s 0) = S)
    (hchain : ∀ j : Fin n, roundSum (s j.succ.castSucc) = peval (s j.castSucc.castSucc) (r j.castSucc.castSucc))
    (hfin : peval (s (Fin.last n).castSucc) (r (Fin.last n).castSucc) = P fin)
    (hext : ∀ x, peval (s (Fin.last (n + 1))) x = extRoundFun P fin ext x) (hP : P ext = 0)
    (claimVal : β₁ → ι → K) (claimOf : Fin m → ι) (x : β₁)
    (hclaim : ∀ i, maskedTerminal (fin i) (ext i) (r (Fin.last (n + 1))) = claimVal x (claimOf i)) :
    (chainDefect s r).2.1 = 0 ∧ (chainDefect s r).2.2 = P (fun i => claimVal x (claimOf i)) := by
  rw [slot_chainDefect P fin ext S s r h0 hchain hfin hext hP]
  exact ⟨rfl, congrArg P (funext hclaim)⟩

end SlotViews

/-! ## `M`'s functionals -/

/-- **One of `M`'s mask functionals** (argument.rs:1478-1495): a standalone slot's `Γ` (`c·G`), a slot's evaluation
`g(ρ)`, or a host's `Γ` with its hosted slots and coefficients `(hs, ν)`. -/
inductive MFun (K : Type) (ns : ℕ) where
  | total (t : Fin ns)
  | eval (t : Fin ns)
  | host (t : Fin ns) (hs : List (Fin ns × K))

section MFuns

variable {K : Type} [Field K]

variable {ns : ℕ} {n d : Fin ns → ℕ}

/-- The functional's value on the masks: what `M`'s test proves of the committed coefficients. -/
def mfMask (c : Fin ns → K) (ρ : (t : Fin ns) → Fin (n t + 1) → K) :
    MFun K ns → ((t : Fin ns) → CfsCoeffs K (n t) (d t)) → K
  | .total t, a => c t * cfsTotal (a t)
  | .eval t, a => cfsEval (a t) (ρ t)
  | .host t hs, a => c t * cfsTotal (a t) - (hs.map (fun p => p.2 * (c p.1 * cfsTotal (a p.1)))).sum

/-- The functional's value from the views: what the verifier computes (`value: scalar`, `value: g_val`). -/
def mfView (c : Fin ns → K) :
    MFun K ns → ((t : Fin ns) → K × (Fin (n t + 1) → Fin (d t + 1) → K) × K) → K
  | .total t, y => c t * (y t).1
  | .eval t, y => (y t).2.2
  | .host t hs, y => (y t).1 - (hs.map (fun p => p.2 * (y p.1).1)).sum

/-- **The honest prover's conditions for one functional**: a `total` functional sits on an unmasked (standalone) slot;
a host functional on a masked slot whose hosted slots are masked and whose unmasked claimed sum is `Σ ν_k·S_k`. -/
def MHonest (masked : Fin ns → Bool) (S : (t : Fin ns) → Fin (n t + 1) → Fin (d t + 1) → K) : MFun K ns → Prop
  | .total t => masked t = false
  | .eval _ => True
  | .host t hs => masked t = true ∧ (∀ p ∈ hs, masked p.1 = true)
      ∧ roundSum (S t 0) = (hs.map (fun p => p.2 * roundSum (S p.1 0))).sum

/-- **Which `M` functional is which `g(ρ)` or `Γ`**: for an honest prover, every functional's value on the masks is its
value on the slot views. -/
theorem mfMask_eq_mfView (masked : Fin ns → Bool) (S : (t : Fin ns) → Fin (n t + 1) → Fin (d t + 1) → K)
    (c : Fin ns → K) (ρ : (t : Fin ns) → Fin (n t + 1) → K) (f : MFun K ns) (hf : MHonest masked S f)
    (a : (t : Fin ns) → CfsCoeffs K (n t) (d t)) :
    mfMask c ρ f a = mfView c f (fun t => slotView (masked t) (S t) (c t) (ρ t) (a t)) := by
  cases f with
  | total t =>
    show c t * cfsTotal (a t) = c t * (slotView (masked t) (S t) (c t) (ρ t) (a t)).1
    rw [slotView_false (show masked t = false from hf)]
    rfl
  | eval t =>
    show cfsEval (a t) (ρ t) = (slotView (masked t) (S t) (c t) (ρ t) (a t)).2.2
    rw [slotView_eval]
  | host t hs =>
    obtain ⟨ht, hk, hsum⟩ := hf
    exact hostScalar_of_views masked n d S c ρ a t hs ht hk hsum

/-- The θ-combined value of `nf` functionals at offset 1 (`θ^(i+1)`, D65(1)), on the masks. -/
def mfComb (θ : K) {nf : ℕ} (mf : Fin nf → MFun K ns) (c : Fin ns → K) (ρ : (t : Fin ns) → Fin (n t + 1) → K)
    (a : (t : Fin ns) → CfsCoeffs K (n t) (d t)) : K :=
  ∑ i : Fin nf, θ ^ ((i : ℕ) + 1) * mfMask c ρ (mf i) a

/-- The θ-combined value, from the views: `V`, what the verifier compares with `M`'s opening. -/
def viewComb (θ : K) {nf : ℕ} (mf : Fin nf → MFun K ns) (c : Fin ns → K)
    (y : (t : Fin ns) → K × (Fin (n t + 1) → Fin (d t + 1) → K) × K) : K :=
  ∑ i : Fin nf, θ ^ ((i : ℕ) + 1) * mfView c (mf i) y

/-- For an honest prover the combined value on the masks is the verifier's `V` from the views. -/
theorem mfComb_eq_viewComb (θ : K) {nf : ℕ} (mf : Fin nf → MFun K ns) (masked : Fin ns → Bool)
    (S : (t : Fin ns) → Fin (n t + 1) → Fin (d t + 1) → K) (c : Fin ns → K) (ρ : (t : Fin ns) → Fin (n t + 1) → K)
    (hf : ∀ i, MHonest masked S (mf i)) (a : (t : Fin ns) → CfsCoeffs K (n t) (d t)) :
    mfComb θ mf c ρ a = viewComb θ mf c (fun t => slotView (masked t) (S t) (c t) (ρ t) (a t)) := by
  unfold mfComb viewComb
  refine Finset.sum_congr rfl (fun i _ => ?_)
  rw [mfMask_eq_mfView masked S c ρ (mf i) (hf i) a]

end MFuns

/-! ## `M`'s factoring hypothesis from the functionals -/

section MFactor

variable {F K : Type} [Field F] [Field K] [Algebra F K] {mm r Q q : ℕ}

open Classical in
/-- **`M`'s functional value as a function of the views** (`ZKLinks.block_view_law_eq_links`'s `Φ`): the `Fp2` pair
whose reading is the verifier's `V` (zero when none is). -/
noncomputable def mPhi (U θ : K) {ns nf : ℕ} {n d : Fin ns → ℕ} (mf : Fin nf → MFun K ns) (c : Fin ns → K)
    {β₁ : Type} (y : β₁ × ((t : Fin ns) → K × (Fin (n t + 1) → Fin (d t + 1) → K) × K)) : F × F :=
  if h : ∃ p : F × F, fp2 U p = viewComb θ mf c y.2 then h.choose else 0

/-- **The `M` link from the functional list.** If `M`'s honest messages `w` and its public weights carry the
θ-combined mask functional of the list `mf` (`hMK`: the reading of `M`'s functional value in `Fp2` is `mfComb`; the
`CfsMask`-to-a-rows layout with `combined_weights`), and the prover is honest for every functional (`hf`), then `M`'s
functional value is the function `mPhi` of the views: `ZKLinks.block_view_law_eq_links`'s `hM`. -/
theorem mFactor_of_funs {U θ : K} (hU : U ∉ Set.range (algebraMap F K)) {ns nf : ℕ} {n d : Fin ns → ℕ}
    (mf : Fin nf → MFun K ns) (masked : Fin ns → Bool) {Dt Ω₁ β₁ : Type} (X₁ : Dt → Ω₁ → β₁)
    (S : Dt → Ω₁ → (t : Fin ns) → Fin (n t + 1) → Fin (d t + 1) → K) (c : Fin ns → K)
    (ρ : (t : Fin ns) → Fin (n t + 1) → K) (hf : ∀ e ω₁ i, MHonest masked (S e ω₁) (mf i))
    (κF : F) (P : MOpenPub F mm r Q q) (w : ((t : Fin ns) → CfsCoeffs K (n t) (d t)) → Fin r → Bool → Fin mm → F)
    (hMK : ∀ a, fp2 U (mValRe κF P (w a), mValIm P (w a)) = mfComb θ mf c ρ a) :
    ∀ e ω₁ a, (mValRe κF P (w a), mValIm P (w a))
      = mPhi (F := F) U θ mf c (X₁ e ω₁, fun t => slotView (masked t) (S e ω₁ t) (c t) (ρ t) (a t)) := by
  classical
  intro e ω₁ a
  have hV : fp2 U (mValRe κF P (w a), mValIm P (w a))
      = viewComb θ mf c (fun t => slotView (masked t) (S e ω₁ t) (c t) (ρ t) (a t)) := by
    rw [hMK, mfComb_eq_viewComb θ mf masked (S e ω₁) c ρ (hf e ω₁) a]
  have h : ∃ p : F × F,
      fp2 U p = viewComb θ mf c (X₁ e ω₁, fun t => slotView (masked t) (S e ω₁ t) (c t) (ρ t) (a t)).2 :=
    ⟨_, hV⟩
  unfold mPhi
  rw [dite_eq_left h]
  exact fp2_injective hU (hV.trans h.choose_spec.symm)

/-- **The `CfsMask`-to-a-rows layout, read in `K`** (`hMK` of `mFactor_of_funs` from a statement about `Fp2` values):
if the committed messages' coefficients against `M`'s combined weights, read as `Fp2` elements, sum to the θ-combined
functional (`hlay`, the code's `combined_weights` against `a_coefs`), then so does the reading of `M`'s functional
value (`fp2_mVal`, `U² = κ`). -/
theorem hMK_of_K {U θ : K} {κF : F} (hU2 : U ^ 2 = algebraMap F K κF) {ns nf : ℕ} {n d : Fin ns → ℕ}
    (mf : Fin nf → MFun K ns) (c : Fin ns → K) (ρ : (t : Fin ns) → Fin (n t + 1) → K) (P : MOpenPub F mm r Q q)
    (w : ((t : Fin ns) → CfsCoeffs K (n t) (d t)) → Fin r → Bool → Fin mm → F)
    (hlay : ∀ a, ∑ s, ∑ i, fp2 U (w a s true i, w a s false i) * fp2 U (P.Wre s i, P.Wim s i) = mfComb θ mf c ρ a) :
    ∀ a, fp2 U (mValRe κF P (w a), mValIm P (w a)) = mfComb θ mf c ρ a :=
  fun a => (fp2_mVal U κF hU2 P (w a)).symm.trans (hlay a)

end MFactor

/-! ## The code's kinds and functional order -/

section Code

open ZK60.Exec.Slot.W16R2

/-- **The code's slot kinds as view kinds** (finding L19-1): a private slot and a host slot both send a MASKED claimed
sum (a private slot `S + c·G`; a host `c·G − Σ ν_k·c_k·G_k`, whose claimed sum is that plus the hosted scalars, so its
round messages start from `Σ ν_k·S_k + c·G`); only a standalone slot (claimed sum `0`, scalar `c·G`) is unmasked. -/
def maskedOfKind : Kind → Bool
  | .priv => true
  | .host => true
  | .standalone => false

theorem maskedOfKind_false_iff (k : Kind) : maskedOfKind k = false ↔ k = .standalone := by
  cases k <;> simp [maskedOfKind]

/-- **W16R2's hand-off order** (layout.rs:1107-1114): every host's two hosted slots are private slots and come before
the host in the transcript. -/
theorem w16r2_hosted_priv : ∀ t : Fin nSlots, ∀ s ∈ hostsOf t.val, kindOf s = .priv ∧ s < t.val := by
  decide

/-- Every W16R2 host has exactly two hosted slots, and only hosts host. -/
theorem w16r2_hosts_two : ∀ t : Fin nSlots, (kindOf t.val = .host → (hostsOf t.val).length = 2)
    ∧ (kindOf t.val ≠ .host → hostsOf t.val = []) := by
  decide

variable {K : Type} [Field K]

/-- **`M`'s functionals in the code's declared order** (argument.rs:1478: "[Γ_s if standalone] eval_s; host Γs
last"): per slot in order, a standalone slot's `Γ` then its evaluation; then every host's `Γ`, in slot order. -/
def codeFuns (ns : ℕ) (kind : Fin ns → Kind) (hosts : Fin ns → List (Fin ns × K)) : List (MFun K ns) :=
  (List.finRange ns).flatMap (fun s => if kind s = .standalone then [MFun.total s, MFun.eval s] else [MFun.eval s])
    ++ (List.finRange ns).filterMap (fun s => if kind s = .host then some (MFun.host s (hosts s)) else none)

/-- **The code's list meets the honest conditions** when every host's hosted slots are masked and every honest host's
unmasked claimed sum is `Σ ν_k·S_k`. -/
theorem codeFuns_honest {ns : ℕ} {n d : Fin ns → ℕ} (kind : Fin ns → Kind) (hosts : Fin ns → List (Fin ns × K))
    (S : (t : Fin ns) → Fin (n t + 1) → Fin (d t + 1) → K)
    (hhosted : ∀ s, kind s = .host → ∀ p ∈ hosts s, maskedOfKind (kind p.1) = true)
    (hsum : ∀ s, kind s = .host → roundSum (S s 0) = ((hosts s).map (fun p => p.2 * roundSum (S p.1 0))).sum) :
    ∀ f ∈ codeFuns ns kind hosts, MHonest (fun t => maskedOfKind (kind t)) S f := by
  intro f hf
  simp only [codeFuns, List.mem_append, List.mem_flatMap, List.mem_filterMap, List.mem_finRange, true_and] at hf
  rcases hf with ⟨s, hs⟩ | ⟨s, hs⟩
  · by_cases hk : kind s = .standalone
    · rw [ite_eq_left hk] at hs
      rcases List.mem_cons.mp hs with rfl | hs'
      · show maskedOfKind (kind s) = false
        rw [hk]
        rfl
      · obtain rfl := List.mem_singleton.mp hs'
        trivial
    · rw [ite_eq_right hk] at hs
      obtain rfl := List.mem_singleton.mp hs
      trivial
  · by_cases hk : kind s = .host
    · rw [ite_eq_left hk] at hs
      obtain rfl := Option.some.inj hs
      refine ⟨?_, hhosted s hk, hsum s hk⟩
      show maskedOfKind (kind s) = true
      rw [hk]
      rfl
    · rw [ite_eq_right hk] at hs
      cases hs

/-- The code's list as an indexed family (`Fin` its length), for `mfComb` and `mFactor_of_funs`. -/
def codeFunsAt (ns : ℕ) (kind : Fin ns → Kind) (hosts : Fin ns → List (Fin ns × K)) :
    Fin (codeFuns ns kind hosts).length → MFun K ns :=
  fun i => (codeFuns ns kind hosts).get i

theorem codeFunsAt_honest {ns : ℕ} {n d : Fin ns → ℕ} (kind : Fin ns → Kind) (hosts : Fin ns → List (Fin ns × K))
    (S : (t : Fin ns) → Fin (n t + 1) → Fin (d t + 1) → K)
    (hhosted : ∀ s, kind s = .host → ∀ p ∈ hosts s, maskedOfKind (kind p.1) = true)
    (hsum : ∀ s, kind s = .host → roundSum (S s 0) = ((hosts s).map (fun p => p.2 * roundSum (S p.1 0))).sum) :
    ∀ i, MHonest (fun t => maskedOfKind (kind t)) S (codeFunsAt ns kind hosts i) :=
  fun i => codeFuns_honest kind hosts S hhosted hsum _ (List.get_mem _ i)

end Code

/-! ## The openings' layer at the opened set -/

section Openings

variable {F K : Type} [Field F] [Field K] [Algebra F K]

/-- **The pad block of the opened set is surjective** (the hypothesis `hE` of `openingView_law_eq` and
`openingViewH_law_eq`) when the encoder's pad entries are `z_j·x_j^l` at `k ≤ Q` distinct points outside the message
domain (`z_j ≠ 0`): the opened columns lie within the pads. -/
theorem padSurj_of_points [Fintype F] {n Q k : ℕ} (hkQ : k ≤ Q) (x z : Fin k → F) (hx : Function.Injective x)
    (hz : ∀ j, z j ≠ 0) (E : Matrix (Fin k) (Fin n ⊕ Fin Q) F) (hEpad : ∀ j l, E j (Sum.inr l) = z j * x j ^ (l : ℕ)) :
    Function.Surjective (fun p : Fin Q → F => fun j => ∑ l, E j (Sum.inr l) * p l) := by
  intro y
  obtain ⟨g, hg⟩ := padBlock_surjective (Q := Q) hkQ x z hx hz y
  refine ⟨g, ?_⟩
  rw [← hg]
  funext j
  simp only [hEpad, Matrix.mulVec, dotProduct, padBlock]

/-- **The `A` and `H` openings together** (independent coins): if each opening's coins and weights are as
`openingView_law_eq` and `openingViewH_law_eq` need (the reserved pairs' and the proximity pair's coefficients
independent, the pad blocks of the opened sets surjective, `H`'s zero-sum generator, and the honest `H` data summing to
zero, `hdH`), the joint law of the two openings' views does not depend on the data: `ZKLinks`'s `hA`. -/
theorem openingsAH_law_eq [Fintype F] (hK : Module.finrank F K = 2)
    {nA QA kA nH QH kH : ℕ} {DatA ΓA DatH ΓH : Type} [Fintype DatA] [DecidableEq DatA] [Fintype ΓA]
    [DecidableEq ΓA] [Fintype DatH] [DecidableEq DatH] [Fintype ΓH] [DecidableEq ΓH] {Dt : Type}
    (EA : Matrix (Fin kA) (Fin nA ⊕ Fin QA) F) (ωA : Weights K DatA ΓA)
    (habA : ∀ g, LinearIndependent F ![ωA.a g, ωA.b g]) (hpA : LinearIndependent F ![ωA.pa, ωA.pb])
    (hEA : Function.Surjective (fun p : Fin QA → F => fun j => ∑ l, EA j (Sum.inr l) * p l))
    (EH : Matrix (Fin kH) (Fin nH ⊕ Fin QH) F) (Z : (Fin nH → F) → (Fin nH → F))
    (hZadd : ∀ u u', Z (u + u') = Z u + Z u') (hZ : ∀ u : Fin nH → F, ∑ c, u c = 0 → ∃ u', Z u' = u)
    (ωH : WeightsH K DatH ΓH) (hsH : LinearIndependent F ![ωH.sa, ωH.sb])
    (habH : ∀ g, LinearIndependent F ![ωH.a g, ωH.b g]) (hpH : LinearIndependent F ![ωH.pa, ωH.pb])
    (hEH : Function.Surjective (fun p : Fin QH → F => fun j => ∑ l, EH j (Sum.inr l) * p l))
    (dA : Dt → DatA → Fin nA → F) (dH : Dt → DatH → Fin nH → F)
    (hdH : ∀ e, ∑ c, ∑ i, ωH.sD i * algebraMap F K (dH e i c) = 0) (e e₀ : Dt) :
    (PMF.uniformOfFintype (Coins F nA QA DatA ΓA × CoinsH F nH QH DatH ΓH)).map
        (fun p => (openingView EA ωA (dA e) p.1, openingViewH EH Z ωH (dH e) p.2))
      = (PMF.uniformOfFintype (Coins F nA QA DatA ΓA × CoinsH F nH QH DatH ΓH)).map
        (fun p => (openingView EA ωA (dA e₀) p.1, openingViewH EH Z ωH (dH e₀) p.2)) := by
  have h0 : ∀ e', (PMF.uniformOfFintype (Coins F nA QA DatA ΓA × CoinsH F nH QH DatH ΓH)).map
      (fun p => (openingView EA ωA (dA e') p.1, openingViewH EH Z ωH (dH e') p.2))
      = (PMF.uniformOfFintype (Coins F nA QA DatA ΓA × CoinsH F nH QH DatH ΓH)).map
        (fun p => (openingView EA ωA 0 p.1, openingViewH EH Z ωH 0 p.2)) := fun e' =>
    law_eq_prod _ _ _ _ (openingView_law_eq hK EA ωA habA hpA hEA (dA e'))
      (openingViewH_law_eq hK EH Z hZadd hZ ωH hsH habH hpH hEH (dH e') (hdH e'))
  rw [h0 e, h0 e₀]

end Openings

end ZK60.ZKLinks
