/-
D63, step L4 (zero knowledge): the opening of `H`, whose LogUp sum claim is masked by a zero-sum pair.

`HidingOpening.openingView_law_eq` covers a commitment whose every claim carries its own FREE reserved pair (the
`A` commitment, and every commitment with no sum claim). `H` has one more claim: the value-0 LogUp sum claim
(`private_block::protocol::logup_sum_claim`). It carries no reserved pair. It is masked by the zero-sum pair `u`
(`audit_claims`: "the sum claim is not masked by the zero-sum pair alone"), two rows whose messages are uniform
SUBJECT TO summing to zero (`prove`: "each zero-sum row's first `n - 1` words" are drawn, and the last is minus their
sum). The `u` rows are also read by the evaluation claim of `u`'s own terminal, which has its own fresh pair.

So the structure is triangular, in three levels: the sum claim reads the data rows and `u`; each evaluation claim
reads the data rows, possibly `u`, and its own pair; the proximity vector reads everything. As in
`HidingOpening.lean`, `Γ` runs over the evaluation CLAIM SITES, and the view holds each claim's row combination; the
verifier's group vectors and claim values are fixed linear images of it (`openingViewH_law_eq_comp`). Because `u`'s
messages are constrained, the theorem needs the data to satisfy the public identity the sum claim proves: the data's
part of the sum claim's total is zero (the LogUp identity holds). This is exactly the "disclosed: the public LogUp identity
and nothing else" of the construction's rank check (`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md` §6), now a theorem
about the joint view with the opened columns.

The sum claim's column weights are taken as all-ones over the whole row (the zero-sum constraint is over the whole
row, and the PCS refuses a claim whose parts have different column keys, so a sub-row sum cannot share a claim with
the zero-sum rows).
-/
import ZK60Formal.HidingOpening

namespace ZK60.Hiding

open scoped ENNReal

variable {F K : Type} [Field F] [Field K] [Algebra F K]

/-- A row whose message is passed through `Z` and whose pad is free. With `Z` the prover's zero-sum generator (keep
the first `n − 1` words, set the last to minus their sum), these are the zero-sum rows `u`. -/
def zsRow {n Q : ℕ} (Z : (Fin n → F) → (Fin n → F)) (w : Row F n Q) : Row F n Q :=
  Sum.elim (Z (fun c => w (Sum.inl c))) (fun l => w (Sum.inr l))

/-- The weights of an `H` opening. The sum claim weighs the data rows by `sD` and the two zero-sum rows by `sa`, `sb`
(the code: `1` and `u`). Evaluation claim `κ` weighs the data rows by `wD κ`, the zero-sum rows by `wU κ` (nonzero
only for `u`'s terminal claim), and its own pair by `a κ`, `b κ`. The proximity vector weighs everything. -/
structure WeightsH (K : Type) (Dat Γ : Type) where
  sD : Dat → K
  sa : K
  sb : K
  wD : Γ → Dat → K
  wU : Γ → Bool → K
  a : Γ → K
  b : Γ → K
  pD : Dat → K
  pU : Bool → K
  pG : Γ × Bool → K
  pa : K
  pb : K

/-- The coins: data-row pads, the two zero-sum rows' coins (message through `Z`, free pad), the evaluation pairs,
the proximity pair. -/
abbrev CoinsH (F : Type) (n Q : ℕ) (Dat Γ : Type) :=
  (Dat → Fin Q → F) × (Bool → Row F n Q) × (Γ × Bool → Row F n Q) × (Bool → Row F n Q)

/-- The view: the sum claim's row combination, every evaluation claim's row combination, the proximity vector, and
the opened columns of the data rows, the zero-sum rows, the pairs and the proximity pair. -/
abbrev ViewH (F K : Type) (n Q k : ℕ) (Dat Γ : Type) :=
  Row K n Q × (Γ → Row K n Q) × Row K n Q × (Dat → Fin k → F) × (Bool → Fin k → F)
    × (Γ × Bool → Fin k → F) × (Bool → Fin k → F)

/-- The view of an `H` opening, given the opened points (`E`), the zero-sum generator `Z`, the weights, the data
messages `d` and the coins. -/
def openingViewH {n Q k : ℕ} {Dat Γ : Type} [Fintype Dat] [Fintype Γ]
    (E : Matrix (Fin k) (Fin n ⊕ Fin Q) F) (Z : (Fin n → F) → (Fin n → F)) (ω : WeightsH K Dat Γ)
    (d : Dat → Fin n → F) (r : CoinsH F n Q Dat Γ) : ViewH F K n Q k Dat Γ :=
  ( fun c => ∑ i, ω.sD i * algebraMap F K (Sum.elim (d i) (r.1 i) c)
      + ω.sa * algebraMap F K (zsRow Z (r.2.1 true) c) + ω.sb * algebraMap F K (zsRow Z (r.2.1 false) c),
    fun g c => ∑ i, ω.wD g i * algebraMap F K (Sum.elim (d i) (r.1 i) c)
      + ∑ s, ω.wU g s * algebraMap F K (zsRow Z (r.2.1 s) c)
      + ω.a g * algebraMap F K (r.2.2.1 (g, true) c) + ω.b g * algebraMap F K (r.2.2.1 (g, false) c),
    fun c => ∑ i, ω.pD i * algebraMap F K (Sum.elim (d i) (r.1 i) c)
      + ∑ s, ω.pU s * algebraMap F K (zsRow Z (r.2.1 s) c)
      + ∑ gs, ω.pG gs * algebraMap F K (r.2.2.1 gs c)
      + ω.pa * algebraMap F K (r.2.2.2 true c) + ω.pb * algebraMap F K (r.2.2.2 false c),
    fun i j => ∑ c, E j c * Sum.elim (d i) (r.1 i) c,
    fun s j => ∑ c, E j c * zsRow Z (r.2.1 s) c,
    fun gs j => ∑ c, E j c * r.2.2.1 gs c,
    fun s j => ∑ c, E j c * r.2.2.2 s c )

section JointH

variable {n Q k : ℕ} {Dat Γ : Type} [Fintype Dat] [DecidableEq Dat] [Fintype Γ] [DecidableEq Γ]

/-- Two weights decomposed in an `F`-basis `(a, b)` of `K`: `Σ_i w_i·↑x_i = a·Σ_i ↑s_i↑x_i + b·Σ_i ↑t_i↑x_i`. -/
theorem sum_decomp {ι : Type} [Fintype ι] (a b : K) (w : ι → K) (s t : ι → F)
    (hst : ∀ i, algebraMap F K (s i) * a + algebraMap F K (t i) * b = w i) (x : ι → K) :
    ∑ i, w i * x i = a * ∑ i, algebraMap F K (s i) * x i + b * ∑ i, algebraMap F K (t i) * x i := by
  rw [Finset.mul_sum, Finset.mul_sum, ← Finset.sum_add_distrib]
  refine Finset.sum_congr rfl (fun i _ => ?_)
  rw [← hst i]
  ring

/-- **The joint view of an `H` opening depends on the data only through the public identity.** Under the hypotheses
of `openingView_law_eq`, plus: the sum claim's two zero-sum rows have `F`-independent coefficients (`1` and `u`);
`Z` is additive and reaches every zero-sum message (the prover's generator does, `zeroSumGen_add`,
`zeroSumGen_surj`); and the data satisfies the identity the sum claim proves (its part of the sum claim's total is
`0`). Then the law of the whole view (sum vector, claim vectors, proximity vector, every opened column) equals its
law at `d = 0`. -/
theorem openingViewH_law_eq [Fintype F] (hK : Module.finrank F K = 2)
    (E : Matrix (Fin k) (Fin n ⊕ Fin Q) F) (Z : (Fin n → F) → (Fin n → F))
    (hZadd : ∀ w w', Z (w + w') = Z w + Z w') (hZ : ∀ v : Fin n → F, ∑ c, v c = 0 → ∃ w, Z w = v)
    (ω : WeightsH K Dat Γ) (hs : LinearIndependent F ![ω.sa, ω.sb])
    (hab : ∀ g, LinearIndependent F ![ω.a g, ω.b g]) (hp : LinearIndependent F ![ω.pa, ω.pb])
    (hE : Function.Surjective (fun p : Fin Q → F => fun j => ∑ l, E j (Sum.inr l) * p l))
    (d : Dat → Fin n → F) (hd : ∑ c, ∑ i, ω.sD i * algebraMap F K (d i c) = 0) :
    (PMF.uniformOfFintype (CoinsH F n Q Dat Γ)).map (openingViewH E Z ω d)
      = (PMF.uniformOfFintype (CoinsH F n Q Dat Γ)).map (openingViewH E Z ω 0) := by
  -- Step 1: data pads and difference rows, as in `openingView_law_eq`.
  choose pd hpd using fun i => hE (fun j => ∑ c, E j (Sum.inl c) * d i c)
  have hpd' : ∀ i j, ∑ l, E j (Sum.inr l) * pd i l = ∑ c, E j (Sum.inl c) * d i c :=
    fun i j => congrFun (hpd i) j
  set δ : Dat → Row F n Q := fun i => Sum.elim (d i) (-pd i) with hδdef
  have hδ : ∀ i j, ∑ c, E j c * δ i c = 0 := by
    intro i j
    simp only [hδdef, Fintype.sum_sum_type, Sum.elim_inl, Sum.elim_inr, Pi.neg_apply, mul_neg,
      Finset.sum_neg_distrib]
    rw [hpd' i j, add_neg_cancel]
  have hsub : ∀ (u w : Row F n Q) j, ∑ c, E j c * u c = 0 → ∑ c, E j c * w c = 0 →
      ∑ c, E j c * (u c - w c) = 0 := by
    intro u w j hu hw
    simp only [mul_sub, Finset.sum_sub_distrib, hu, hw, sub_zero]
  -- Step 2: coordinates.
  choose σS τS hS using fun i => pair_decomp hK hs (ω.sD i)
  choose σ τ hστ using fun g i => pair_decomp hK (hab g) (ω.wD g i)
  choose σU τU hU using fun g s => pair_decomp hK (hab g) (ω.wU g s)
  choose σP τP hP using fun i => pair_decomp hK hp (ω.pD i)
  choose σPU τPU hPU using fun s => pair_decomp hK hp (ω.pU s)
  choose σG τG hG using fun gs => pair_decomp hK hp (ω.pG gs)
  -- Step 3: the zero-sum rows absorb the sum claim's data part; its messages sum to zero by `hd`.
  set ΔU1 : Row F n Q := fun c => ∑ i, σS i * δ i c with hΔU1
  set ΔU0 : Row F n Q := fun c => ∑ i, τS i * δ i c with hΔU0
  set ΔU : Bool → Row F n Q := fun s => cond s ΔU1 ΔU0 with hΔU
  have hUt : ΔU true = ΔU1 := rfl
  have hUf : ΔU false = ΔU0 := rfl
  have hzero : (∑ c, ∑ i, σS i * d i c) = 0 ∧ (∑ c, ∑ i, τS i * d i c) = 0 := by
    have hexp : ∀ c, ∑ i, ω.sD i * algebraMap F K (d i c)
        = ω.sa * algebraMap F K (∑ i, σS i * d i c) + ω.sb * algebraMap F K (∑ i, τS i * d i c) := by
      intro c
      rw [sum_decomp ω.sa ω.sb ω.sD σS τS hS]
      simp only [map_sum, map_mul]
    have hsplit2 : ∑ c, ∑ i, ω.sD i * algebraMap F K (d i c)
        = ω.sa * algebraMap F K (∑ c, ∑ i, σS i * d i c)
          + ω.sb * algebraMap F K (∑ c, ∑ i, τS i * d i c) := by
      rw [Finset.sum_congr rfl (fun c _ => hexp c)]
      simp only [map_sum, Finset.sum_add_distrib, Finset.mul_sum]
    exact (LinearIndependent.pair_iff.mp hs) _ _
      (by rw [Algebra.smul_def, Algebra.smul_def]; linear_combination hd - hsplit2)
  have hmsg : ∀ s, ∑ c, ΔU s (Sum.inl c) = 0 := by
    rintro (_ | _)
    · simpa [hUf, hΔU0, hδdef] using hzero.2
    · simpa [hUt, hΔU1, hδdef] using hzero.1
  choose W hW using fun s => hZ (fun c => ΔU s (Sum.inl c)) (hmsg s)
  set rU : Bool → Row F n Q := fun s => Sum.elim (W s) (fun l => ΔU s (Sum.inr l)) with hrU
  have hzsShift : ∀ (V : Row F n Q) s c, zsRow Z (V + rU s) c = zsRow Z V c + ΔU s c := by
    intro V s c
    cases c with
    | inl c =>
      have hm : (fun c' => (V + rU s) (Sum.inl c')) = (fun c' => V (Sum.inl c')) + W s := by
        funext c'
        simp [hrU]
      simp only [zsRow, Sum.elim_inl]
      rw [hm, hZadd, Pi.add_apply, hW s]
    | inr l =>
      simp [zsRow, hrU]
  have hΔUann : ∀ s j, ∑ c, E j c * ΔU s c = 0 := by
    rintro (_ | _) j
    · rw [hUf]
      exact ann_sum E _ δ hδ j
    · rw [hUt]
      exact ann_sum E _ δ hδ j
  -- Step 4: each evaluation pair absorbs its claim's data part and its reading of the zero-sum shift.
  set ΔA : Γ → Row F n Q := fun g c => (∑ i, σ g i * δ i c) - ∑ s, σU g s * ΔU s c with hΔA
  set ΔB : Γ → Row F n Q := fun g c => (∑ i, τ g i * δ i c) - ∑ s, τU g s * ΔU s c with hΔB
  set ΔG : Γ × Bool → Row F n Q := fun gs => cond gs.2 (ΔA gs.1) (ΔB gs.1) with hΔG
  have hGt : ∀ g, ΔG (g, true) = ΔA g := fun g => rfl
  have hGf : ∀ g, ΔG (g, false) = ΔB g := fun g => rfl
  have hΔGann : ∀ gs j, ∑ c, E j c * ΔG gs c = 0 := by
    rintro ⟨g, _ | _⟩ j
    · rw [hGf]
      exact hsub _ _ j (ann_sum E _ δ hδ j) (ann_sum E _ ΔU hΔUann j)
    · rw [hGt]
      exact hsub _ _ j (ann_sum E _ δ hδ j) (ann_sum E _ ΔU hΔUann j)
  -- Step 5: the proximity pair absorbs the rest.
  set ΔP1 : Row F n Q := fun c =>
    (∑ i, σP i * δ i c) - ∑ s, σPU s * ΔU s c - ∑ gs, σG gs * ΔG gs c with hΔP1
  set ΔP0 : Row F n Q := fun c =>
    (∑ i, τP i * δ i c) - ∑ s, τPU s * ΔU s c - ∑ gs, τG gs * ΔG gs c with hΔP0
  set ΔP : Bool → Row F n Q := fun s => cond s ΔP1 ΔP0 with hΔP
  have hPt : ΔP true = ΔP1 := rfl
  have hPf : ΔP false = ΔP0 := rfl
  have hΔPann : ∀ s j, ∑ c, E j c * ΔP s c = 0 := by
    rintro (_ | _) j
    · rw [hPf]
      exact hsub _ _ j (hsub _ _ j (ann_sum E _ δ hδ j) (ann_sum E _ ΔU hΔUann j))
        (ann_sum E _ ΔG hΔGann j)
    · rw [hPt]
      exact hsub _ _ j (hsub _ _ j (ann_sum E _ δ hδ j) (ann_sum E _ ΔU hΔUann j))
        (ann_sum E _ ΔG hΔGann j)
  set rd : CoinsH F n Q Dat Γ := (pd, rU, ΔG, ΔP) with hrd
  have hsplit : ∀ (p : Dat → Fin Q → F) i c,
      Sum.elim (d i) (p i) c = Sum.elim (0 : Fin n → F) (p i + pd i) c + δ i c := by
    intro p i c
    cases c <;> simp [hδdef]
  -- Step 6: the real view equals the zero-data view at shifted coins.
  have hview : ∀ r : CoinsH F n Q Dat Γ, openingViewH E Z ω d r = openingViewH E Z ω 0 (r + rd) := by
    intro r
    obtain ⟨p, U, A, P⟩ := r
    simp only [openingViewH, hrd, Prod.mk_add_mk, Pi.add_apply, Pi.zero_apply, Prod.mk.injEq]
    refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
    · -- the sum claim's row combination
      funext c
      have hkey : ∑ i, ω.sD i * algebraMap F K (δ i c)
          = ω.sa * algebraMap F K (ΔU1 c) + ω.sb * algebraMap F K (ΔU0 c) := by
        rw [sum_decomp ω.sa ω.sb ω.sD σS τS hS]
        simp only [hΔU1, hΔU0, map_sum, map_mul]
      simp_rw [hzsShift, hUt, hUf, hsplit p, map_add, mul_add, Finset.sum_add_distrib]
      linear_combination hkey
    · -- the evaluation claims' row combinations
      funext g c
      have hkey : ∑ i, ω.wD g i * algebraMap F K (δ i c) - ∑ s, ω.wU g s * algebraMap F K (ΔU s c)
          = ω.a g * algebraMap F K (ΔA g c) + ω.b g * algebraMap F K (ΔB g c) := by
        rw [sum_decomp (ω.a g) (ω.b g) (ω.wD g) (σ g) (τ g) (hστ g),
          sum_decomp (ω.a g) (ω.b g) (ω.wU g) (σU g) (τU g) (hU g)]
        simp only [hΔA, hΔB, map_sub, map_sum, map_mul]
        ring
      rw [hGt, hGf]
      simp_rw [hzsShift, hsplit p, map_add, mul_add, Finset.sum_add_distrib]
      linear_combination hkey
    · -- the proximity vector
      funext c
      have hD : ∑ i, ω.pD i * algebraMap F K (δ i c)
          = ω.pa * ∑ i, algebraMap F K (σP i) * algebraMap F K (δ i c)
            + ω.pb * ∑ i, algebraMap F K (τP i) * algebraMap F K (δ i c) :=
        sum_decomp ω.pa ω.pb ω.pD σP τP hP _
      have hDU : ∑ s, ω.pU s * algebraMap F K (ΔU s c)
          = ω.pa * ∑ s, algebraMap F K (σPU s) * algebraMap F K (ΔU s c)
            + ω.pb * ∑ s, algebraMap F K (τPU s) * algebraMap F K (ΔU s c) :=
        sum_decomp ω.pa ω.pb ω.pU σPU τPU hPU _
      have hGs : ∑ gs, ω.pG gs * algebraMap F K (ΔG gs c)
          = ω.pa * ∑ gs, algebraMap F K (σG gs) * algebraMap F K (ΔG gs c)
            + ω.pb * ∑ gs, algebraMap F K (τG gs) * algebraMap F K (ΔG gs c) :=
        sum_decomp ω.pa ω.pb ω.pG σG τG hG _
      have hP1 : algebraMap F K (ΔP1 c)
          = ∑ i, algebraMap F K (σP i) * algebraMap F K (δ i c)
            - ∑ s, algebraMap F K (σPU s) * algebraMap F K (ΔU s c)
            - ∑ gs, algebraMap F K (σG gs) * algebraMap F K (ΔG gs c) := by
        simp only [hΔP1, map_sub, map_sum, map_mul]
      have hP0 : algebraMap F K (ΔP0 c)
          = ∑ i, algebraMap F K (τP i) * algebraMap F K (δ i c)
            - ∑ s, algebraMap F K (τPU s) * algebraMap F K (ΔU s c)
            - ∑ gs, algebraMap F K (τG gs) * algebraMap F K (ΔG gs c) := by
        simp only [hΔP0, map_sub, map_sum, map_mul]
      rw [hPt, hPf]
      simp_rw [hzsShift, hsplit p, map_add, mul_add, Finset.sum_add_distrib]
      rw [hP1, hP0]
      linear_combination hD - hDU - hGs
    · -- the data rows' opened values
      funext i j
      simp only [Fintype.sum_sum_type, Sum.elim_inl, Sum.elim_inr, Pi.zero_apply, mul_zero,
        Finset.sum_const_zero, zero_add, Pi.add_apply, mul_add, Finset.sum_add_distrib]
      linear_combination -(hpd' i j)
    · -- the zero-sum rows' opened values
      funext s j
      simp only [hzsShift, mul_add, Finset.sum_add_distrib]
      rw [hΔUann s j, add_zero]
    · -- the pairs' opened values
      funext gs j
      simp only [mul_add, Finset.sum_add_distrib]
      rw [hΔGann gs j, add_zero]
    · -- the proximity pair's opened values
      funext s j
      simp only [mul_add, Finset.sum_add_distrib]
      rw [hΔPann s j, add_zero]
  have hfun : openingViewH E Z ω d = (openingViewH E Z ω 0) ∘ (fun r => r + rd) := funext hview
  rw [hfun, ← PMF.map_comp, map_uniform_add_right]

/-- Anything computed from the `H` view by a fixed map (the group vectors, the claim values, copies of repeated
samples) inherits `openingViewH_law_eq`. -/
theorem openingViewH_law_eq_comp [Fintype F] {β : Type} (φ : ViewH F K n Q k Dat Γ → β)
    (E : Matrix (Fin k) (Fin n ⊕ Fin Q) F) (Z : (Fin n → F) → (Fin n → F)) (ω : WeightsH K Dat Γ)
    (d : Dat → Fin n → F)
    (h : (PMF.uniformOfFintype (CoinsH F n Q Dat Γ)).map (openingViewH E Z ω d)
      = (PMF.uniformOfFintype (CoinsH F n Q Dat Γ)).map (openingViewH E Z ω 0)) :
    (PMF.uniformOfFintype (CoinsH F n Q Dat Γ)).map (φ ∘ openingViewH E Z ω d)
      = (PMF.uniformOfFintype (CoinsH F n Q Dat Γ)).map (φ ∘ openingViewH E Z ω 0) := by
  rw [← PMF.map_comp, ← PMF.map_comp, h]

end JointH

/-- The prover's zero-sum generator: keep the first `n − 1` words, set the last to minus their sum
(`private_block::protocol`, the H commitment: `row[n - 1] = sum.neg()`). -/
def zeroSumGen {n : ℕ} (w : Fin (n + 1) → F) : Fin (n + 1) → F :=
  fun c => if c = Fin.last n then -∑ i : Fin n, w i.castSucc else w c

/-- The generator is additive. -/
theorem zeroSumGen_add {n : ℕ} (w w' : Fin (n + 1) → F) :
    zeroSumGen (w + w') = zeroSumGen w + zeroSumGen w' := by
  funext c
  simp only [zeroSumGen, Pi.add_apply]
  by_cases hc : c = Fin.last n
  · rw [ite_eq_left hc, ite_eq_left hc, ite_eq_left hc, Finset.sum_add_distrib, neg_add]
  · rw [ite_eq_right hc, ite_eq_right hc, ite_eq_right hc]

/-- The generator reaches every zero-sum vector (it fixes it). -/
theorem zeroSumGen_surj {n : ℕ} (v : Fin (n + 1) → F) (hv : ∑ c, v c = 0) : ∃ w, zeroSumGen w = v := by
  refine ⟨v, ?_⟩
  funext c
  simp only [zeroSumGen]
  by_cases hc : c = Fin.last n
  · rw [ite_eq_left hc, hc]
    rw [Fin.sum_univ_castSucc] at hv
    linear_combination -hv
  · rw [ite_eq_right hc]

end ZK60.Hiding
