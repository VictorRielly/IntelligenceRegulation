/-
D63, step L4 (zero knowledge), second set of lemmas: fewer opened points than pads, sampling with replacement,
and several rows with independent pads.

`Hiding.lean` proved the square case: `Q` distinct opened points and `Q` pad coefficients give exactly uniform
opened values. The verifier of `pcs::verify_zk_tagged` draws its `Q` column indices WITH replacement
(`transcript.rs` `challenge_indices`), so in practice it sees `k ≤ Q` distinct points, some of them several times,
and it sees every committed row at each of them. This file covers those cases:

* `map_uniform_of_surjective`: pushing the uniform law of a finite group through a surjective additive map gives
  the uniform law of the target (the general tool; the fibres are cosets of the kernel).
* `padBlock_surjective`: the `k × Q` pad block `z_j · x_j^l` has full row rank when `k ≤ Q`, the `x_j` are distinct
  and every `z_j = Z_n(x_j)` is nonzero.
* `openedValuesAt_uniform`: `k ≤ Q` distinct opened points of one row give values exactly uniform on `F^k`.
* `sampledValues_law_eq`: the values of one row at ANY sampled index sequence with at most `Q` distinct indices
  (repeats allowed) have a law that does not depend on the message.
* `rowsOpenedValues_uniform`, `rowsSampledValues_law_eq`: the same for `r` rows with independent pads, jointly.
* `coset_zn_ne_zero`, `coset_points_injective`: the protocol's evaluation domain `h · ⟨ω⟩` (`h = 7`, `h^N ≠ 1`,
  the assertion in `coset_powers`) gives distinct points with `Z_n ≠ 0`, the hypotheses above.

"Independent uniform pads" is the uniform law on the product type `Fin r → Fin Q → F` (`PMF.uniformOfFintype`),
which is the joint law of `r` independent uniform pad vectors.

What these lemmas do NOT cover, and where they sit in `ZeroKnowledge` (`Statements.lean`): they are about the
opened COLUMNS alone. The clear vectors sent next to them (the group vectors and the proximity vector) are correlated
with the columns; that joint view is `HidingOpening.lean`. The masked sumcheck, the mask commitment `M`, the salted
Merkle leaves, the Fiat–Shamir composition and the composition over runs are further lemmas (plan L4).
-/
import ZK60Formal.Hiding
import Mathlib.RingTheory.RootsOfUnity.PrimitiveRoots

namespace ZK60.Hiding

open scoped ENNReal

/-! ## Uniform laws under additive maps -/

/-- A probability mass function that gives every point the same mass is the uniform distribution. -/
theorem eq_uniformOfFintype_of_const {α : Type} [Fintype α] [Nonempty α] (p : PMF α)
    (h : ∀ a b, p a = p b) : p = PMF.uniformOfFintype α := by
  classical
  obtain ⟨a0⟩ := ‹Nonempty α›
  have hsum : ∑ a, p a = 1 := by
    have h1 := p.tsum_coe
    rwa [tsum_fintype] at h1
  have hconst : ∑ a, p a = (Fintype.card α : ℝ≥0∞) * p a0 := by
    rw [Finset.sum_congr rfl (fun a _ => h a a0), Finset.sum_const, Finset.card_univ, nsmul_eq_mul]
  ext a
  rw [PMF.uniformOfFintype_apply, h a a0]
  apply ENNReal.eq_inv_of_mul_eq_one_left
  rw [mul_comm, ← hconst, hsum]

/-- Translating by a fixed element maps the uniform distribution of a finite group to itself. -/
theorem map_uniform_add_right {G : Type} [AddGroup G] [Fintype G] (t : G) :
    (PMF.uniformOfFintype G).map (fun g => g + t) = PMF.uniformOfFintype G :=
  map_uniform_of_bijective _ (Equiv.addRight t).bijective

/-- Translating on the left, likewise. -/
theorem map_uniform_add_left {G : Type} [AddGroup G] [Fintype G] (t : G) :
    (PMF.uniformOfFintype G).map (fun g => t + g) = PMF.uniformOfFintype G :=
  map_uniform_of_bijective _ (Equiv.addLeft t).bijective

/-- **Pushing a uniform law through a surjective additive map gives the uniform law.** The image law is invariant
under every translation of the target (a translate of the target is the image of a translate of the source), and a
translation-invariant law on a finite group is uniform. -/
theorem map_uniform_of_surjective {G H : Type} [AddGroup G] [AddGroup H] [Fintype G] [Fintype H]
    (f : G → H) (hadd : ∀ x y, f (x + y) = f x + f y) (hf : Function.Surjective f) :
    (PMF.uniformOfFintype G).map f = PMF.uniformOfFintype H := by
  have hinv : ∀ h0 : H, ((PMF.uniformOfFintype G).map f).map (fun h => h + h0)
      = (PMF.uniformOfFintype G).map f := by
    intro h0
    obtain ⟨g0, rfl⟩ := hf h0
    have hc : ((fun h => h + f g0) ∘ f) = f ∘ (fun g => g + g0) := by
      funext g
      simp [hadd]
    rw [PMF.map_comp, hc, ← PMF.map_comp, map_uniform_add_right]
  have key : ∀ h0 x : H, (PMF.uniformOfFintype G).map f (x + h0) = (PMF.uniformOfFintype G).map f x := by
    intro h0 x
    conv_lhs => rw [← hinv h0]
    rw [PMF.map_apply, tsum_eq_single x]
    · simp
    · intro y hy
      have hne : x + h0 ≠ y + h0 := fun hxy => hy (add_right_cancel hxy).symm
      simp [hne]
  apply eq_uniformOfFintype_of_const
  intro a b
  calc (PMF.uniformOfFintype G).map f a = (PMF.uniformOfFintype G).map f (a + (-a + b)) := (key _ _).symm
    _ = (PMF.uniformOfFintype G).map f b := by rw [add_neg_cancel_left]

/-- The affine form: a fixed offset plus a surjective additive map of a uniform variable is uniform. -/
theorem map_uniform_add_left_of_surjective {G H : Type} [AddGroup G] [AddGroup H] [Fintype G] [Fintype H]
    (f : G → H) (hadd : ∀ x y, f (x + y) = f x + f y) (hf : Function.Surjective f) (c : H) :
    (PMF.uniformOfFintype G).map (fun g => c + f g) = PMF.uniformOfFintype H := by
  have : (fun g => c + f g) = (fun h => c + h) ∘ f := rfl
  rw [this, ← PMF.map_comp, map_uniform_of_surjective f hadd hf, map_uniform_add_left]

/-! ## The `k × Q` pad block -/

variable {F : Type} [Field F] [Fintype F] {Q k : ℕ}

/-- The pad block of one row at `k` opened points: entry `(j, l)` is `z_j · x_j^l`, where `z_j = Z_n(x_j)`. The
opened value at `x_j` is the message part plus `(padBlock x z *ᵥ g) j`. -/
def padBlock (x z : Fin k → F) : Matrix (Fin k) (Fin Q) F := fun j l => z j * x j ^ (l : ℕ)

omit [Fintype F] in
theorem padBlock_mulVec (x z : Fin k → F) (g : Fin Q → F) (j : Fin k) :
    (padBlock x z).mulVec g j = z j * ∑ l : Fin Q, g l * x j ^ (l : ℕ) := by
  simp only [padBlock, Matrix.mulVec, dotProduct, Finset.mul_sum]
  refine Finset.sum_congr rfl (fun l _ => ?_)
  ring

omit [Fintype F] in
/-- **The pad block has full row rank** when there are at most `Q` opened points, they are distinct, and they lie
outside the message domain. Its first `k` columns form the invertible square block of `Hiding.padMatrix`; a preimage
is that block's preimage padded with zeros. -/
theorem padBlock_surjective (hkQ : k ≤ Q) (x z : Fin k → F) (hx : Function.Injective x)
    (hz : ∀ j, z j ≠ 0) : Function.Surjective (padBlock (Q := Q) x z).mulVec := by
  classical
  intro y
  obtain ⟨g', hg'⟩ := (Matrix.mulVec_surjective_iff_isUnit.mpr (padMatrix_isUnit x z hx hz)) y
  refine ⟨fun l => if h : (l : ℕ) < k then g' ⟨l, h⟩ else 0, ?_⟩
  rw [← hg']
  funext j
  simp only [Matrix.mulVec, dotProduct, padBlock, padMatrix, Matrix.diagonal_mul, Matrix.vandermonde_apply]
  symm
  refine Fintype.sum_of_injective (Fin.castLE hkQ) (Fin.castLE_injective hkQ) _ _ ?_ ?_
  · intro l hl
    have hlk : ¬ ((l : ℕ) < k) := by
      intro h
      exact hl ⟨⟨l, h⟩, Fin.ext (by simp)⟩
    simp [hlk]
  · intro i
    simp [i.isLt]

/-! ## One row at `k ≤ Q` distinct points -/

/-- The values of one committed row at `k` opened points `x_j`: the message part `m j = d(x_j)` plus
`Z_n(x_j) · g(x_j)` with `z j = Z_n(x_j)` and the pad `g` given by its `Q` coefficients. For `k = Q` this is
`Hiding.openedValues`. -/
def openedValuesAt (x z m : Fin k → F) (g : Fin Q → F) : Fin k → F :=
  fun j => m j + z j * ∑ l : Fin Q, g l * x j ^ (l : ℕ)

/-- **Fewer distinct opened points than pad coefficients: still exactly uniform, for every message.** For `k ≤ Q`
distinct points outside the message domain, the `k` opened values of one row are uniform on `F^k`, whatever the
message. For privacy: opening at most `Q` distinct columns of one row reveals nothing about its message. -/
theorem openedValuesAt_uniform (hkQ : k ≤ Q) (x z m : Fin k → F) (hx : Function.Injective x)
    (hz : ∀ j, z j ≠ 0) :
    (PMF.uniformOfFintype (Fin Q → F)).map (openedValuesAt x z m) = PMF.uniformOfFintype (Fin k → F) := by
  have h : openedValuesAt (Q := Q) x z m = fun g : Fin Q → F => m + (padBlock x z).mulVec g := by
    funext g j
    simp [openedValuesAt, padBlock_mulVec]
  rw [h]
  exact map_uniform_add_left_of_surjective (padBlock (Q := Q) x z).mulVec
    (fun a b => Matrix.mulVec_add _ a b) (padBlock_surjective hkQ x z hx hz) m

/-! ## Sampling with replacement -/

variable {N q : ℕ}

/-- The values of one committed row at a sampled index sequence `s : Fin q → Fin N` (repeats allowed): index `i`
of the evaluation domain is the point `x i`, where the message part is `m i` and `Z_n` is `zx i`. -/
def sampledValues (x zx m : Fin N → F) (s : Fin q → Fin N) (g : Fin Q → F) : Fin q → F :=
  fun t => m (s t) + zx (s t) * ∑ l : Fin Q, g l * x (s t) ^ (l : ℕ)

/-- The distinct sampled indices, enumerated: `S.card` of them, in the order of `Finset.equivFin`. -/
noncomputable def distinctPoints (s : Fin q → Fin N) : Fin (Finset.univ.image s).card → Fin N :=
  fun j => ((Finset.univ.image s).equivFin.symm j : Fin N)

/-- Where each sample sits among the distinct indices. -/
noncomputable def distinctIndex (s : Fin q → Fin N) (t : Fin q) : Fin (Finset.univ.image s).card :=
  (Finset.univ.image s).equivFin ⟨s t, Finset.mem_image_of_mem s (Finset.mem_univ t)⟩

theorem distinctPoints_injective (s : Fin q → Fin N) : Function.Injective (distinctPoints s) := by
  intro i j hij
  exact (Finset.univ.image s).equivFin.symm.injective (Subtype.ext hij)

theorem distinctPoints_index (s : Fin q → Fin N) (t : Fin q) : distinctPoints s (distinctIndex s t) = s t := by
  simp [distinctPoints, distinctIndex]

omit [Fintype F] in
theorem sampledValues_eq_comp (x zx m : Fin N → F) (s : Fin q → Fin N) :
    sampledValues (Q := Q) x zx m s
      = (fun v t => v (distinctIndex s t))
        ∘ openedValuesAt (x ∘ distinctPoints s) (zx ∘ distinctPoints s) (m ∘ distinctPoints s) := by
  funext g t
  simp [sampledValues, openedValuesAt, distinctPoints_index]

/-- **Sampling with replacement: the law of the opened values does not depend on the message.** Let the evaluation
domain have distinct points `x i` outside the message domain (`zx i ≠ 0`), and let the verifier's sample sequence
`s` (any length, repeats allowed) hit at most `Q` distinct indices. Then the values of one row at the samples have
the same law for any two messages `m`, `m'`. (Their common law: uniform on the distinct samples, copied to the
repeats.) For privacy: the column test with `Q` draws, with replacement, reveals nothing about one row's message;
`Q ≤ q_pad` is what the PCS asserts (`commit_zk_owned_with`: "fewer pad symbols than opened columns"). -/
theorem sampledValues_law_eq (x zx : Fin N → F) (hx : Function.Injective x) (hz : ∀ i, zx i ≠ 0)
    (s : Fin q → Fin N) (hs : (Finset.univ.image s).card ≤ Q) (m m' : Fin N → F) :
    (PMF.uniformOfFintype (Fin Q → F)).map (sampledValues x zx m s)
      = (PMF.uniformOfFintype (Fin Q → F)).map (sampledValues x zx m' s) := by
  have hinj : Function.Injective (x ∘ distinctPoints s) := hx.comp (distinctPoints_injective s)
  have hz' : ∀ j, (zx ∘ distinctPoints s) j ≠ 0 := fun j => hz _
  rw [sampledValues_eq_comp, sampledValues_eq_comp, ← PMF.map_comp, ← PMF.map_comp,
    openedValuesAt_uniform hs _ _ (m ∘ distinctPoints s) hinj hz',
    openedValuesAt_uniform hs _ _ (m' ∘ distinctPoints s) hinj hz']

/-! ## Several rows with independent pads -/

variable {r : ℕ}

/-- The values of `r` committed rows at the same `k` opened points; row `i` has message part `m i` and pad `G i`. -/
def rowsOpenedValues (x z : Fin k → F) (m : Fin r → Fin k → F) (G : Fin r → Fin Q → F) : Fin r → Fin k → F :=
  fun i => openedValuesAt x z (m i) (G i)

/-- **Several rows, independent pads: the opened values are jointly uniform, for any messages.** With `k ≤ Q`
distinct opened points outside the message domain and `r` rows with independent uniform pads, the `r × k` opened
values are uniform on `(F^k)^r`, whatever the `r` messages. For privacy: an opened column (one entry per committed
row) reveals nothing about any of the rows, nor about relations between them. -/
theorem rowsOpenedValues_uniform (hkQ : k ≤ Q) (x z : Fin k → F) (m : Fin r → Fin k → F)
    (hx : Function.Injective x) (hz : ∀ j, z j ≠ 0) :
    (PMF.uniformOfFintype (Fin r → Fin Q → F)).map (rowsOpenedValues x z m)
      = PMF.uniformOfFintype (Fin r → Fin k → F) := by
  have h : rowsOpenedValues (Q := Q) x z m
      = fun G : Fin r → Fin Q → F => m + fun i => (padBlock x z).mulVec (G i) := by
    funext G i j
    simp [rowsOpenedValues, openedValuesAt, padBlock_mulVec]
  rw [h]
  refine map_uniform_add_left_of_surjective
    (fun G : Fin r → Fin Q → F => fun i => (padBlock x z).mulVec (G i)) ?_ ?_ m
  · intro a b
    funext i
    simp [Matrix.mulVec_add]
  · intro Y
    choose G hG using fun i => padBlock_surjective (Q := Q) hkQ x z hx hz (Y i)
    exact ⟨G, funext hG⟩

/-- The values of `r` committed rows at a sampled index sequence (repeats allowed). -/
def rowsSampledValues (x zx : Fin N → F) (m : Fin r → Fin N → F) (s : Fin q → Fin N)
    (G : Fin r → Fin Q → F) : Fin r → Fin q → F :=
  fun i => sampledValues x zx (m i) s (G i)

/-- **Several rows, sampling with replacement: the law of the opened columns does not depend on the messages.**
Under the hypotheses of `sampledValues_law_eq`, the opened columns of `r` rows with independent uniform pads have the
same law for any two message matrices. -/
theorem rowsSampledValues_law_eq (x zx : Fin N → F) (hx : Function.Injective x) (hz : ∀ i, zx i ≠ 0)
    (s : Fin q → Fin N) (hs : (Finset.univ.image s).card ≤ Q) (m m' : Fin r → Fin N → F) :
    (PMF.uniformOfFintype (Fin r → Fin Q → F)).map (rowsSampledValues x zx m s)
      = (PMF.uniformOfFintype (Fin r → Fin Q → F)).map (rowsSampledValues x zx m' s) := by
  have hinj : Function.Injective (x ∘ distinctPoints s) := hx.comp (distinctPoints_injective s)
  have hcomp : ∀ mm : Fin r → Fin N → F, rowsSampledValues (Q := Q) x zx mm s
      = (fun V i t => V i (distinctIndex s t))
        ∘ rowsOpenedValues (x ∘ distinctPoints s) (zx ∘ distinctPoints s) (fun i => mm i ∘ distinctPoints s) := by
    intro mm
    funext G i t
    simp [rowsSampledValues, rowsOpenedValues, sampledValues, openedValuesAt, distinctPoints_index]
  have hz' : ∀ j, (zx ∘ distinctPoints s) j ≠ 0 := fun j => hz _
  rw [hcomp, hcomp, ← PMF.map_comp, ← PMF.map_comp,
    rowsOpenedValues_uniform hs _ _ (fun i => m i ∘ distinctPoints s) hinj hz',
    rowsOpenedValues_uniform hs _ _ (fun i => m' i ∘ distinctPoints s) hinj hz']

/-! ## The protocol's evaluation domain -/

omit [Fintype F] in
/-- **The coset points lie outside the message domain.** The message domain is the subgroup of order `n`, where
`Z_n(X) = X^n − 1` vanishes. The codeword is evaluated on `h · ⟨ω⟩` with `ω^N = 1`, `n ∣ N` and `h^N ≠ 1` (the
assertion of `pcs::coset_powers`, `h = 7`). Then `Z_n(h ω^j) ≠ 0` for every `j`. -/
theorem coset_zn_ne_zero {n : ℕ} (hn : n ∣ N) (h ω : F) (hω : ω ^ N = 1) (hh : h ^ N ≠ 1) (j : ℕ) :
    (h * ω ^ j) ^ n - 1 ≠ 0 := by
  intro h0
  have h1 : (h * ω ^ j) ^ n = 1 := sub_eq_zero.mp h0
  obtain ⟨c, rfl⟩ := hn
  apply hh
  calc h ^ (n * c) = h ^ (n * c) * ((ω ^ (n * c)) ^ j) := by rw [hω, one_pow, mul_one]
    _ = ((h * ω ^ j) ^ n) ^ c := by ring
    _ = 1 := by rw [h1, one_pow]

omit [Fintype F] in
/-- **The coset points are distinct**: `j ↦ h ω^j` is injective on `[0, N)` when `ω` has order exactly `N` and
`h ≠ 0`. Distinct column indices are distinct points. -/
theorem coset_points_injective (h ω : F) (hh : h ≠ 0) (hω : IsPrimitiveRoot ω N) :
    Function.Injective (fun j : Fin N => h * ω ^ (j : ℕ)) := by
  intro i j hij
  have hpow : ω ^ (i : ℕ) = ω ^ (j : ℕ) := mul_left_cancel₀ hh hij
  exact Fin.ext (hω.pow_inj i.isLt j.isLt hpow)

/-- **The column test on the protocol's domain hides every row, jointly.** The evaluation domain is `h · ⟨ω⟩` with
`ω` of order `N`, `n ∣ N`, `h ≠ 0` and `h^N ≠ 1`; the verifier samples indices with replacement, hitting at most
`Q` distinct ones; the `r` rows have independent uniform pads of `Q` coefficients. Then the law of all the opened
column entries is the same for any two message matrices. -/
theorem coset_rowsSampledValues_law_eq {n : ℕ} (hn : n ∣ N) (h ω : F) (hh0 : h ≠ 0) (hh : h ^ N ≠ 1)
    (hω : IsPrimitiveRoot ω N) (s : Fin q → Fin N) (hs : (Finset.univ.image s).card ≤ Q)
    (m m' : Fin r → Fin N → F) :
    (PMF.uniformOfFintype (Fin r → Fin Q → F)).map
        (rowsSampledValues (fun j => h * ω ^ (j : ℕ)) (fun j => (h * ω ^ (j : ℕ)) ^ n - 1) m s)
      = (PMF.uniformOfFintype (Fin r → Fin Q → F)).map
        (rowsSampledValues (fun j => h * ω ^ (j : ℕ)) (fun j => (h * ω ^ (j : ℕ)) ^ n - 1) m' s) :=
  rowsSampledValues_law_eq _ _ (coset_points_injective h ω hh0 hω)
    (fun j => coset_zn_ne_zero hn h ω hω.pow_eq_one hh j) s hs m m'

end ZK60.Hiding
