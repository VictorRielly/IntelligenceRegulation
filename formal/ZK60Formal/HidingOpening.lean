/-
D63, step L4 (zero knowledge): the clear vectors of one opening, jointly with its opened columns.

What the verifier of `pcs::verify_zk_tagged` sees of one commitment (`zkp-core/src/pcs.rs`, `open_zk`):
* one clear vector per column-weight group, `v_g = ρ_gᵀ [M | pads]` (n message entries, then Q pad entries), with
  `ρ_g ∈ Fp2^rows` built from the claims and the λ challenges;
* the proximity vector `v_P = ρ_Pᵀ [M | pads]`, with `ρ_P` a fresh uniform Fp2 weight on EVERY row;
* the opened columns: every committed row's codeword at each sampled point.

The committed rows are over the base field `Fp`; the weights are over `Fp2`. The private block masks each claim
site with its own reserved PAIR of uniformly random rows, read as `R_re + u·R_im` (`private_block::argument`
`build_claim`: coefficients `cm` and `cm·u`), and the proximity vector with a dedicated proximity pair
(`check_opening_challenges` refuses a pair whose coefficients are `Fp`-dependent). `audit_claims` enforces that
every evaluation claim carries exactly its own pair, that no pair is shared, and that nothing but the proximity
combination touches the proximity pair. Its doc comment records the joint uniformity of the clear vectors and
leaves "independence from the sampled columns" as an unproven PREMISE. `openingView_law_eq` below proves that
premise for one opening: the clear vectors and the opened columns, TOGETHER, have a law that does not depend on the
data (the zero-witness simulator).

This file models `Fp ⊂ Fp2` as any field extension `F → K` with `[K : F] = 2`.

* `pair_decomp`, `pairMask_uniform`: two base-field rows with `F`-independent coefficients hide one clear vector
  completely.
* `singleMask_reveals`, `singleMask_law_injective`: ONE base-field row with a coefficient outside `F` does not hide
  anything about a one-row table. The clear vector determines the private row exactly. This is why the pair is
  load-bearing.
* `pair_coeffs_independent`, `independent_of_det_ne_zero`: the code's two refusals (a zero mask coefficient, a zero
  proximity determinant) give exactly the independence hypotheses used here.
* `openingView_law_eq`, `openingView_law_eq_of_points`: the joint law of (group vectors, proximity vector, opened
  columns) of one opening is the same for every data matrix.

NOT covered here (each is further L4 work): the value-0 LogUp sum group on `H`, whose mask is the zero-sum pair `u`
(constrained, not uniform; the data must satisfy the public identity); the CFS channel (the masked sumchecks and the
mask commitment `M`); the salted Merkle paths of the opened columns and the hiding of the root (random-oracle
level); the Fiat–Shamir derivation of the challenges (here the weights and the sampled points are FIXED, so this is
the honest-verifier statement for one fixed challenge value); and composition over the commitments of a run.
-/
import ZK60Formal.HidingRows
import Mathlib.LinearAlgebra.FiniteDimensional.Lemmas
import Mathlib.LinearAlgebra.LinearIndependent.Lemmas

namespace ZK60.Hiding

open scoped ENNReal

variable {F K : Type} [Field F] [Field K] [Algebra F K]

/-! ## Two base-field rows hide one extension-field combination -/

/-- With `[K : F] = 2` and `a, b` linearly independent over `F`, every element of `K` is `s·a + t·b`. -/
theorem pair_decomp (hK : Module.finrank F K = 2) {a b : K} (hab : LinearIndependent F ![a, b]) (x : K) :
    ∃ s t : F, algebraMap F K s * a + algebraMap F K t * b = x := by
  have hspan := hab.span_eq_top_of_card_eq_finrank (by simp [hK])
  rw [Matrix.range_cons_cons_empty] at hspan
  have hx : x ∈ Submodule.span F ({a, b} : Set K) := by rw [hspan]; exact Submodule.mem_top
  obtain ⟨s, t, hst⟩ := Submodule.mem_span_pair.mp hx
  exact ⟨s, t, by rw [← Algebra.smul_def, ← Algebra.smul_def]; exact hst⟩

/-- **A mask pair hides one clear vector.** Let `w` be any vector over `K` (the data's contribution and every other
row's), and let the clear vector be `w + a·R₁ + b·R₂`, where `R₁, R₂` are independent uniform vectors over `F` (the two
rows of a reserved pair) and `a, b` are `F`-independent. Then the clear vector is uniform over `K`, whatever `w` is.
At a claim site `a = λ·e` and `b = λ·e·u` (`pair_coeffs_independent`); for the proximity vector `a, b` are the two
proximity-pair weights (`independent_of_det_ne_zero`). This is ONE vector alone; `openingView_law_eq` is the joint
statement with the other vectors and the opened columns. -/
theorem pairMask_uniform [Fintype F] [Fintype K] {ι : Type} [Fintype ι] [DecidableEq ι]
    (hK : Module.finrank F K = 2) {a b : K} (hab : LinearIndependent F ![a, b]) (w : ι → K) :
    (PMF.uniformOfFintype ((ι → F) × (ι → F))).map
        (fun R => w + fun c => algebraMap F K (R.1 c) * a + algebraMap F K (R.2 c) * b)
      = PMF.uniformOfFintype (ι → K) := by
  refine map_uniform_add_left_of_surjective
    (fun R : (ι → F) × (ι → F) => fun c => algebraMap F K (R.1 c) * a + algebraMap F K (R.2 c) * b) ?_ ?_ w
  · intro R S
    funext c
    simp only [Prod.fst_add, Prod.snd_add, Pi.add_apply, map_add]
    ring
  · intro y
    choose s t hst using fun c => pair_decomp hK hab (y c)
    exact ⟨(s, t), funext hst⟩

/-! ## One base-field row does not hide an extension-field combination -/

/-- **A single base-field mask row reveals a one-row table completely.** Take a private row `T` over `F`, masked at
its claim site by ONE uniformly random base-field row `R` with a challenge `e ∈ K` outside `F` (any Fp2 challenge
with a nonzero `u`-part). The clear vector is `(1 − e)·T + e·R`. Then a fixed map `dec` recovers `T` from it, for
every `T` and every `R`: in the basis `(1, β)` of `K`, `β = (1 − e)/e`, the `β`-coordinate of `v_c / e` is `T_c`.
This is the formal content of the construction's negative control "one base row per claim … a singleton plane fully
recovered" (`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md` §6). The single-row form described in `hashline/src/zk.rs` (a)(ii)
and used by the `zkp-core` test rig (`pcs.rs` `zk_tests::rig`) has exactly this shape for its sub-row claim (`S`, mask
row 18): that rig is NOT a hiding configuration over Fp2, although its marginal top-byte chi-square test passes. -/
theorem singleMask_reveals (hK : Module.finrank F K = 2) (e : K) (he : e ∉ Set.range (algebraMap F K))
    {ι : Type} :
    ∃ dec : (ι → K) → (ι → F), ∀ T R : ι → F,
      dec (fun c => (1 - e) * algebraMap F K (T c) + e * algebraMap F K (R c)) = T := by
  have he0 : e ≠ 0 := fun h => he ⟨0, by simp [h]⟩
  -- `β = (1 − e)/e = e⁻¹ − 1` is outside `F`, so `(1, β)` is a basis of `K` over `F`
  have hli : LinearIndependent F ![(1 : K), e⁻¹ - 1] := by
    rw [LinearIndependent.pair_iff' one_ne_zero]
    intro s hs
    apply he
    rw [Algebra.smul_def, mul_one] at hs
    refine ⟨(s + 1)⁻¹, ?_⟩
    have hs1 : algebraMap F K (s + 1) = e⁻¹ := by
      rw [map_add, map_one, hs]
      ring
    rw [map_inv₀, hs1, inv_inv]
  let B := basisOfLinearIndependentOfCardEqFinrank hli (by simp [hK])
  have hB : ⇑B = ![(1 : K), e⁻¹ - 1] := coe_basisOfLinearIndependentOfCardEqFinrank hli _
  have hB0 : B 0 = 1 := by rw [hB]; rfl
  have hB1 : B 1 = e⁻¹ - 1 := by rw [hB]; rfl
  refine ⟨fun v c => B.coord 1 (v c * e⁻¹), ?_⟩
  intro T R
  funext c
  have hee : e * e⁻¹ = 1 := mul_inv_cancel₀ he0
  have hv : ((1 - e) * algebraMap F K (T c) + e * algebraMap F K (R c)) * e⁻¹
      = T c • (e⁻¹ - 1) + R c • (1 : K) := by
    rw [Algebra.smul_def, Algebra.smul_def]
    linear_combination (algebraMap F K (R c) - algebraMap F K (T c)) * hee
  show B.coord 1 (((1 - e) * algebraMap F K (T c) + e * algebraMap F K (R c)) * e⁻¹) = T c
  rw [hv, ← hB1, ← hB0, map_add, map_smul, map_smul, Module.Basis.coord_apply, Module.Basis.coord_apply,
    Module.Basis.repr_self, Module.Basis.repr_self]
  simp

/-- Hence the LAW of the singly masked clear vector determines the private row: two different rows give two
different laws. (So no simulator that does not know `T` can reproduce it.) -/
theorem singleMask_law_injective [Fintype F] (hK : Module.finrank F K = 2) (e : K)
    (he : e ∉ Set.range (algebraMap F K)) {ι : Type} [Fintype ι] [DecidableEq ι] (T T' : ι → F)
    (h : (PMF.uniformOfFintype (ι → F)).map
            (fun R c => (1 - e) * algebraMap F K (T c) + e * algebraMap F K (R c))
          = (PMF.uniformOfFintype (ι → F)).map
            (fun R c => (1 - e) * algebraMap F K (T' c) + e * algebraMap F K (R c))) :
    T = T' := by
  obtain ⟨dec, hdec⟩ := singleMask_reveals (ι := ι) hK e he
  have h2 := congrArg (PMF.map dec) h
  rw [PMF.map_comp, PMF.map_comp] at h2
  have hc : ∀ U : ι → F,
      (dec ∘ fun (R : ι → F) c => (1 - e) * algebraMap F K (U c) + e * algebraMap F K (R c))
        = Function.const (ι → F) U := by
    intro U
    funext R
    exact hdec U R
  rw [hc T, hc T', PMF.map_const, PMF.map_const] at h2
  have h3 := congrArg (fun p : PMF (ι → F) => p T) h2
  by_contra hne
  simp [PMF.pure_apply, hne] at h3

/-! ## The code's refusals give the independence hypotheses -/

/-- **A claim site's pair coefficients are independent.** The pair enters a group vector with coefficients
`c = λ·e` and `c·u` (`build_claim`: `cm` and `cm·u`, times the group's λ). They are `F`-independent exactly when
`c ≠ 0`, given `u ∉ F`. `audit_claims` refuses a zero terminal mask coefficient and `check_opening_challenges` a zero
group member coefficient, so `c ≠ 0`. -/
theorem pair_coeffs_independent {c u : K} (hc : c ≠ 0) (hu : u ∉ Set.range (algebraMap F K)) :
    LinearIndependent F ![c, c * u] := by
  rw [LinearIndependent.pair_iff' hc]
  intro s hs
  apply hu
  refine ⟨s, ?_⟩
  rw [Algebra.smul_def] at hs
  exact mul_left_cancel₀ hc (by rw [← hs, mul_comm])

/-- **The proximity-pair refusal is exactly independence.** Write `a = a₀ + a₁·u` and `b = b₀ + b₁·u` with
`aᵢ, bᵢ ∈ F` and `u ∉ F`. If `a₀·b₁ − a₁·b₀ ≠ 0` (the `determinant` that `check_opening_challenges` refuses when
zero), then `a, b` are `F`-independent. -/
theorem independent_of_det_ne_zero {u : K} (hu : u ∉ Set.range (algebraMap F K)) (a₀ a₁ b₀ b₁ : F)
    (hdet : a₀ * b₁ - a₁ * b₀ ≠ 0) :
    LinearIndependent F ![algebraMap F K a₀ + algebraMap F K a₁ * u,
      algebraMap F K b₀ + algebraMap F K b₁ * u] := by
  rw [LinearIndependent.pair_iff]
  intro s t hst
  -- `1, u` are independent: `x + y·u = 0` forces `x = y = 0`
  have hbasis : ∀ x y : F, algebraMap F K x + algebraMap F K y * u = 0 → x = 0 ∧ y = 0 := by
    intro x y hxy
    by_cases hy : y = 0
    · subst hy
      simp only [map_zero, zero_mul, add_zero] at hxy
      exact ⟨(map_eq_zero_iff _ (algebraMap F K).injective).mp hxy, rfl⟩
    · exfalso
      apply hu
      refine ⟨-x / y, ?_⟩
      have hy' : algebraMap F K y ≠ 0 := (map_ne_zero_iff _ (algebraMap F K).injective).mpr hy
      rw [map_div₀, map_neg, div_eq_iff hy']
      linear_combination -hxy
  have h := hbasis (s * a₀ + t * b₀) (s * a₁ + t * b₁) (by
    rw [Algebra.smul_def, Algebra.smul_def] at hst
    simp only [map_add, map_mul]
    linear_combination hst)
  obtain ⟨h0, h1⟩ := h
  constructor
  · have : s * (a₀ * b₁ - a₁ * b₀) = 0 := by linear_combination b₁ * h0 - b₀ * h1
    exact (mul_eq_zero.mp this).resolve_right hdet
  · have : t * (a₀ * b₁ - a₁ * b₀) = 0 := by linear_combination a₀ * h1 - a₁ * h0
    exact (mul_eq_zero.mp this).resolve_right hdet

/-! ## The joint view of one opening -/

/-- One committed row in the clear: `n` message entries, then `Q` pad entries (`OpeningZk`'s "n message entries then
Q pad entries"; the encoder `encode_row_zk` is a bijection from these `n + Q` symbols onto the code). -/
abbrev Row (F : Type) (n Q : ℕ) := Fin n ⊕ Fin Q → F

/-- The weights of one opening, by role of the row. The rows are split into: data rows `Dat` (every row that is not
a designated pair, INCLUDING extra mask rows; their contents are arbitrary, so the theorem holds for random ones too);
one designated reserved pair per group `g ∈ Γ` (rows `(g, true)` and `(g, false)`, read as `R_re`, `R_im`); and the
proximity pair. Group `g` weighs the data rows by `wD g` and its own pair by `a g`, `b g`, and touches no other
group's pair and not the proximity pair (`audit_claims`). The proximity vector weighs everything. -/
structure Weights (K : Type) (Dat Γ : Type) where
  wD : Γ → Dat → K
  a : Γ → K
  b : Γ → K
  pD : Dat → K
  pG : Γ × Bool → K
  pa : K
  pb : K

/-- The prover's coins for one commitment: the pads of the data rows, and the full contents (message and pad) of
the designated pairs and of the proximity pair. -/
abbrev Coins (F : Type) (n Q : ℕ) (Dat Γ : Type) :=
  (Dat → Fin Q → F) × (Γ × Bool → Row F n Q) × (Bool → Row F n Q)

/-- The verifier's view of one opening: the group vectors, the proximity vector, and the opened columns of the data
rows, of the pairs and of the proximity pair, at the `k` opened points. -/
abbrev View (F K : Type) (n Q k : ℕ) (Dat Γ : Type) :=
  (Γ → Row K n Q) × Row K n Q × (Dat → Fin k → F) × (Γ × Bool → Fin k → F) × (Bool → Fin k → F)

/-- The view, given the evaluation matrix `E` of the opened points (row `j`: the codeword at point `j` is
`∑_c E j c · row c`), the weights, the data messages `d` and the coins. For the protocol's encoder,
`E j (inr l) = Z_n(x_j) · x_j^l` and `E j (inl c)` is the `c`-th Lagrange basis polynomial of the message domain at
`x_j`; only the first block matters below. -/
def openingView {n Q k : ℕ} {Dat Γ : Type} [Fintype Dat] [Fintype Γ]
    (E : Matrix (Fin k) (Fin n ⊕ Fin Q) F) (ω : Weights K Dat Γ) (d : Dat → Fin n → F)
    (r : Coins F n Q Dat Γ) : View F K n Q k Dat Γ :=
  ( fun g c => ∑ i, ω.wD g i * algebraMap F K (Sum.elim (d i) (r.1 i) c)
      + ω.a g * algebraMap F K (r.2.1 (g, true) c) + ω.b g * algebraMap F K (r.2.1 (g, false) c),
    fun c => ∑ i, ω.pD i * algebraMap F K (Sum.elim (d i) (r.1 i) c)
      + ∑ gs, ω.pG gs * algebraMap F K (r.2.1 gs c)
      + ω.pa * algebraMap F K (r.2.2 true c) + ω.pb * algebraMap F K (r.2.2 false c),
    fun i j => ∑ c, E j c * Sum.elim (d i) (r.1 i) c,
    fun gs j => ∑ c, E j c * r.2.1 gs c,
    fun s j => ∑ c, E j c * r.2.2 s c )

section Joint

variable {n Q k : ℕ} {Dat Γ : Type} [Fintype Dat] [DecidableEq Dat] [Fintype Γ] [DecidableEq Γ]

/-- Rows the opened points cannot see (`E` annihilates them) are closed under `F`-linear combinations. -/
theorem ann_sum {ι : Type} [Fintype ι] (E : Matrix (Fin k) (Fin n ⊕ Fin Q) F) (s : ι → F)
    (w : ι → Row F n Q) (hw : ∀ i j, ∑ c, E j c * w i c = 0) (j : Fin k) :
    ∑ c, E j c * (∑ i, s i * w i c) = 0 := by
  simp_rw [Finset.mul_sum]
  rw [Finset.sum_comm]
  refine Finset.sum_eq_zero (fun i _ => ?_)
  have : ∑ c, E j c * (s i * w i c) = s i * ∑ c, E j c * w i c := by
    rw [Finset.mul_sum]
    exact Finset.sum_congr rfl (fun c _ => by ring)
  rw [this, hw i j, mul_zero]

/-- **The joint view of one opening does not depend on the data (the zero-witness simulator).** Fix the opened
points (through `E`) and the challenges (through the weights). Suppose:
* `[K : F] = 2` (Fp2 over Fp);
* each group's designated pair has `F`-independent coefficients (`pair_coeffs_independent`);
* the proximity pair has `F`-independent coefficients (`independent_of_det_ne_zero`);
* the pad block of the opened points is surjective (`padBlock_surjective`: at most `Q` distinct points outside the
  message domain).
Then for every data matrix `d`, the law of (group vectors, proximity vector, all opened columns) over uniform coins
equals its law at `d = 0`. A simulator that runs the honest opening on the zero matrix with fresh coins therefore
produces exactly the real view. The claimed values are functions of the clear vectors, and repeated samples are a
fixed copy of these columns, so they are covered too.

The proof shifts the coins: the data rows' pads absorb the data's opened values (`hE`), each group's pair absorbs
the data's contribution to its clear vector (its coordinates in the pair's basis), and the proximity pair absorbs the
rest. Every shift is invisible at the opened points, and a shift of uniform coins is uniform. -/
theorem openingView_law_eq [Fintype F] (hK : Module.finrank F K = 2)
    (E : Matrix (Fin k) (Fin n ⊕ Fin Q) F) (ω : Weights K Dat Γ)
    (hab : ∀ g, LinearIndependent F ![ω.a g, ω.b g]) (hp : LinearIndependent F ![ω.pa, ω.pb])
    (hE : Function.Surjective (fun p : Fin Q → F => fun j => ∑ l, E j (Sum.inr l) * p l))
    (d : Dat → Fin n → F) :
    (PMF.uniformOfFintype (Coins F n Q Dat Γ)).map (openingView E ω d)
      = (PMF.uniformOfFintype (Coins F n Q Dat Γ)).map (openingView E ω 0) := by
  -- Step 1: pads that make the zero message show the data's opened values.
  choose pd hpd using fun i => hE (fun j => ∑ c, E j (Sum.inl c) * d i c)
  have hpd' : ∀ i j, ∑ l, E j (Sum.inr l) * pd i l = ∑ c, E j (Sum.inl c) * d i c :=
    fun i j => congrFun (hpd i) j
  -- the difference rows: the data message with the negated compensating pad; `E` cannot see them
  set δ : Dat → Row F n Q := fun i => Sum.elim (d i) (-pd i) with hδdef
  have hδ : ∀ i j, ∑ c, E j c * δ i c = 0 := by
    intro i j
    simp only [hδdef, Fintype.sum_sum_type, Sum.elim_inl, Sum.elim_inr, Pi.neg_apply, mul_neg,
      Finset.sum_neg_distrib]
    rw [hpd' i j, add_neg_cancel]
  -- Step 2: coordinates of every weight in the pair bases.
  choose σ τ hστ using fun g i => pair_decomp hK (hab g) (ω.wD g i)
  choose σP τP hP using fun i => pair_decomp hK hp (ω.pD i)
  choose σG τG hG using fun gs => pair_decomp hK hp (ω.pG gs)
  -- Step 3: the coins shift.
  set ΔA : Γ → Row F n Q := fun g c => ∑ i, σ g i * δ i c with hΔA
  set ΔB : Γ → Row F n Q := fun g c => ∑ i, τ g i * δ i c with hΔB
  set ΔG : Γ × Bool → Row F n Q := fun gs => cond gs.2 (ΔA gs.1) (ΔB gs.1) with hΔG
  have hGt : ∀ g, ΔG (g, true) = ΔA g := fun g => rfl
  have hGf : ∀ g, ΔG (g, false) = ΔB g := fun g => rfl
  set ΔP1 : Row F n Q := fun c => (∑ i, σP i * δ i c) - ∑ gs, σG gs * ΔG gs c with hΔP1
  set ΔP0 : Row F n Q := fun c => (∑ i, τP i * δ i c) - ∑ gs, τG gs * ΔG gs c with hΔP0
  set ΔP : Bool → Row F n Q := fun s => cond s ΔP1 ΔP0 with hΔP
  have hPt : ΔP true = ΔP1 := rfl
  have hPf : ΔP false = ΔP0 := rfl
  have hΔGann : ∀ gs j, ∑ c, E j c * ΔG gs c = 0 := by
    rintro ⟨g, _ | _⟩ j
    · rw [hGf]
      exact ann_sum E _ δ hδ j
    · rw [hGt]
      exact ann_sum E _ δ hδ j
  have hΔPann : ∀ s j, ∑ c, E j c * ΔP s c = 0 := by
    have hsub : ∀ (u w : Row F n Q) j, ∑ c, E j c * u c = 0 → ∑ c, E j c * w c = 0 →
        ∑ c, E j c * (u c - w c) = 0 := by
      intro u w j hu hw
      simp only [mul_sub, Finset.sum_sub_distrib, hu, hw, sub_zero]
    rintro (_ | _) j
    · rw [hPf]
      exact hsub _ _ j (ann_sum E _ δ hδ j) (ann_sum E _ ΔG hΔGann j)
    · rw [hPt]
      exact hsub _ _ j (ann_sum E _ δ hδ j) (ann_sum E _ ΔG hΔGann j)
  set rd : Coins F n Q Dat Γ := (pd, ΔG, ΔP) with hrd
  -- the data rows split into the zero-message rows with shifted pads, plus the difference rows
  have hsplit : ∀ (p : Dat → Fin Q → F) i c,
      Sum.elim (d i) (p i) c = Sum.elim (0 : Fin n → F) (p i + pd i) c + δ i c := by
    intro p i c
    cases c <;> simp [hδdef]
  -- Step 4: the real view equals the zero-data view at shifted coins.
  have hview : ∀ r : Coins F n Q Dat Γ, openingView E ω d r = openingView E ω 0 (r + rd) := by
    intro r
    obtain ⟨p, A, P⟩ := r
    simp only [openingView, hrd, Prod.mk_add_mk, Pi.add_apply, Pi.zero_apply, Prod.mk.injEq]
    refine ⟨?_, ?_, ?_, ?_, ?_⟩
    · -- group vectors
      funext g c
      have hkey : ∑ i, ω.wD g i * algebraMap F K (δ i c)
          = ω.a g * algebraMap F K (ΔA g c) + ω.b g * algebraMap F K (ΔB g c) := by
        simp only [hΔA, hΔB, map_sum, map_mul, Finset.mul_sum, ← Finset.sum_add_distrib]
        refine Finset.sum_congr rfl (fun i _ => ?_)
        rw [← hστ g i]
        ring
      rw [hGt, hGf]
      simp_rw [hsplit p, map_add, mul_add, Finset.sum_add_distrib]
      linear_combination hkey
    · -- the proximity vector
      funext c
      have hD : ∑ i, ω.pD i * algebraMap F K (δ i c)
          = ω.pa * ∑ i, algebraMap F K (σP i) * algebraMap F K (δ i c)
            + ω.pb * ∑ i, algebraMap F K (τP i) * algebraMap F K (δ i c) := by
        rw [Finset.mul_sum, Finset.mul_sum, ← Finset.sum_add_distrib]
        refine Finset.sum_congr rfl (fun i _ => ?_)
        rw [← hP i]
        ring
      have hGs : ∑ gs, ω.pG gs * algebraMap F K (ΔG gs c)
          = ω.pa * ∑ gs, algebraMap F K (σG gs) * algebraMap F K (ΔG gs c)
            + ω.pb * ∑ gs, algebraMap F K (τG gs) * algebraMap F K (ΔG gs c) := by
        rw [Finset.mul_sum, Finset.mul_sum, ← Finset.sum_add_distrib]
        refine Finset.sum_congr rfl (fun gs _ => ?_)
        rw [← hG gs]
        ring
      have hP1 : algebraMap F K (ΔP1 c)
          = ∑ i, algebraMap F K (σP i) * algebraMap F K (δ i c)
            - ∑ gs, algebraMap F K (σG gs) * algebraMap F K (ΔG gs c) := by
        simp only [hΔP1, map_sub, map_sum, map_mul]
      have hP0 : algebraMap F K (ΔP0 c)
          = ∑ i, algebraMap F K (τP i) * algebraMap F K (δ i c)
            - ∑ gs, algebraMap F K (τG gs) * algebraMap F K (ΔG gs c) := by
        simp only [hΔP0, map_sub, map_sum, map_mul]
      rw [hPt, hPf]
      simp_rw [hsplit p, map_add, mul_add, Finset.sum_add_distrib]
      rw [hP1, hP0]
      linear_combination hD - hGs
    · -- the data rows' opened values
      funext i j
      simp only [Fintype.sum_sum_type, Sum.elim_inl, Sum.elim_inr, Pi.zero_apply, mul_zero,
        Finset.sum_const_zero, zero_add, Pi.add_apply, mul_add, Finset.sum_add_distrib]
      linear_combination -(hpd' i j)
    · -- the pairs' opened values
      funext gs j
      simp only [mul_add, Finset.sum_add_distrib]
      rw [hΔGann gs j, add_zero]
    · -- the proximity pair's opened values
      funext s j
      simp only [mul_add, Finset.sum_add_distrib]
      rw [hΔPann s j, add_zero]
  -- Step 5: a translate of uniform coins is uniform.
  have hfun : openingView E ω d = (openingView E ω 0) ∘ (fun r => r + rd) := funext hview
  rw [hfun, ← PMF.map_comp, map_uniform_add_right]

/-- **The same, on the protocol's opened points.** With the pad block of the encoder
(`E j (inr l) = z_j · x_j^l`, `z_j = Z_n(x_j)`), it suffices that there are `k ≤ Q` opened points, distinct and
outside the message domain (`coset_points_injective`, `coset_zn_ne_zero`). The message block of `E` is arbitrary. -/
theorem openingView_law_eq_of_points [Fintype F] (hK : Module.finrank F K = 2)
    (hkQ : k ≤ Q) (x z : Fin k → F) (hx : Function.Injective x) (hz : ∀ j, z j ≠ 0)
    (E : Matrix (Fin k) (Fin n ⊕ Fin Q) F) (hEpad : ∀ j l, E j (Sum.inr l) = z j * x j ^ (l : ℕ))
    (ω : Weights K Dat Γ) (hab : ∀ g, LinearIndependent F ![ω.a g, ω.b g])
    (hp : LinearIndependent F ![ω.pa, ω.pb]) (d : Dat → Fin n → F) :
    (PMF.uniformOfFintype (Coins F n Q Dat Γ)).map (openingView E ω d)
      = (PMF.uniformOfFintype (Coins F n Q Dat Γ)).map (openingView E ω 0) := by
  refine openingView_law_eq hK E ω hab hp ?_ d
  intro y
  obtain ⟨g, hg⟩ := padBlock_surjective (Q := Q) hkQ x z hx hz y
  refine ⟨g, ?_⟩
  rw [← hg]
  funext j
  simp only [hEpad, Matrix.mulVec, dotProduct, padBlock]

end Joint

end ZK60.Hiding
