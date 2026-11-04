/-
D63, step L4 (zero knowledge): the mask commitment `M` and its pad block.

How `M` is built (`hashline/src/zk.rs`, `mask_commit` and `mask_commit_tagged`; the private block calls the tagged
one ONCE per block, `private_block/protocol.rs`, and opens it ONCE, `zk::mask_open`):
* there are `2 · #masks` "a-rows", the real and imaginary parts of each sumcheck's CFS mask coefficients
  (`CfsMask.coeffs`, `L = n_vars · d + 2` of them);
* each a-row is a MESSAGE of `m = 512` base-field symbols: positions `0..L` hold the coefficients, positions
  `L..L+256` hold `MASK_Q = 256` fresh uniform pads (`rng.fp_vec(MASK_Q)`), the remaining positions hold zeros
  (`assert!(part.len() + MASK_Q <= m)`);
* the message is read as the VALUES of a polynomial on `G_512` (`ntt.inverse(&mut msg)`: the NTT is in natural
  order, so position `i` is the value at `ω_512^i`), i.e. the row is `p = Σ_i msg_i · L_i`, the Lagrange basis of
  `G_512`, of degree `< 512`;
* the row is evaluated on the coset `7 · G_4096` (`encode_coeffs_coset`, `coset_powers(7, 4096)` asserts
  `7^4096 ≠ 1`), the columns are salted and Merkle-committed, and `MASK_Q = 256` column indices are sampled WITH
  replacement (`challenge_indices(MASK_Q, dom)`).

So the pads are NOT in the `Z_n · g` form of the A/H commitments (`Hiding.lean`): they sit in message positions and
reach an opened point `x` through the Lagrange basis, `Σ_l g_l · L_{π l}(x)`. For `G_m` the `m`-th roots of unity,
`L_i(x) = (x^m − 1) · y_i / (m · (x − y_i))`, so the `k × Q` pad block is `diag(Z(x_j)/m) · C · diag(y_{π l})` with
`C_{jl} = 1/(x_j − y_{π l})` a Cauchy matrix: the note of `ZK60_LEAN_L4_FINDINGS_20261104.md` is right about the
structure. The proof below does not need the Cauchy determinant. It uses a degree count that works for ANY distinct
message points: a polynomial of degree `< m` that vanishes at the `m − k` non-pad message points and at the `k` opened
points is zero.

* `mPadBlock_surjective`: the pad block of `k ≤ Q` distinct opened points outside the message domain has full row
  rank.
* `mOpened_uniform`: hence one a-row's opened values are exactly uniform for every message (every value of the mask
  coefficients and of the fixed zero positions).
* `mRowsOpened_uniform`, `mRowsSampled_law_eq`: the same for several rows with independent pads, jointly, and under
  sampling with replacement (at most `Q` distinct indices).
* `mRowMsg_eq`: the code's layout (coefficients, then pads, then zeros) is exactly "a fixed message plus pads at the
  positions `L + l`".
* `mask_aRows_law_eq`: the protocol statement on `M`'s evaluation domain.

What this does NOT cover: the clear product polynomial `q'`, the clear proximity vector, and the `b` and `u` rows that
mask them (the joint law of `M`'s whole opening view), the salted Merkle layer (`HidingMerkle.lean`), Fiat–Shamir,
and composition. `M` must be opened at most once: a second opening would raise the number of distinct points above the
pad count, which is exactly what this lemma forbids (the private block opens it once; checked in the code, not here).
-/
import ZK60Formal.HidingRows
import Mathlib.LinearAlgebra.Lagrange

namespace ZK60.Hiding

open scoped ENNReal
open Polynomial

section MPad

variable {F : Type} [Field F]

/-- Pads placed at the message positions `π l`: position `i` holds `g l` when `i = π l`, and `0` at every position
that is not a pad position. -/
def placePads {m Q : ℕ} (π : Fin Q → Fin m) (g : Fin Q → F) : Fin m → F :=
  fun i => ∑ l, if π l = i then g l else 0

/-- Placing pads is additive in the pads (bookkeeping for the uniform-law argument). -/
theorem placePads_add {m Q : ℕ} (π : Fin Q → Fin m) (g g' : Fin Q → F) :
    placePads π (g + g') = placePads π g + placePads π g' := by
  funext i
  simp only [placePads, Pi.add_apply, ← Finset.sum_add_distrib]
  refine Finset.sum_congr rfl (fun l _ => ?_)
  split_ifs <;> simp

/-- At a pad position `π l` the placed message holds the pad `g l`. -/
theorem placePads_apply_pos {m Q : ℕ} {π : Fin Q → Fin m} (hπ : Function.Injective π) (g : Fin Q → F)
    (l : Fin Q) : placePads π g (π l) = g l := by
  unfold placePads
  rw [Finset.sum_eq_single l]
  · simp
  · intro l' _ hl'
    simp [hπ.ne hl']
  · simp

/-- The opened values of one row of `M`: the row is the interpolant on the message domain `y` (for `M`, `G_512` in the
NTT's natural order) of its message `msg`, a polynomial of degree `< m`, read at the opened points `x`. -/
noncomputable def mOpened {m k : ℕ} (y : Fin m → F) (x : Fin k → F) (msg : Fin m → F) : Fin k → F :=
  fun j => (Lagrange.interpolate Finset.univ y msg).eval (x j)

/-- An `M` row's opened values are additive in its message (the interpolant is linear). -/
theorem mOpened_add {m k : ℕ} (y : Fin m → F) (x : Fin k → F) (a b : Fin m → F) :
    mOpened y x (a + b) = mOpened y x a + mOpened y x b := by
  funext j
  simp [mOpened, map_add, eval_add]

/-- **The degree count.** A message that is zero outside a set `T` of `k` positions, and whose interpolant vanishes
at `k` distinct points outside the message domain, is zero: the interpolant has degree `< m` and vanishes at the
`m − k` message points outside `T` and at the `k` extra points, `m` distinct points in all. -/
theorem interpolate_vanish {m k : ℕ} (y : Fin m → F) (hy : Function.Injective y)
    (x : Fin k → F) (hx : Function.Injective x) (hxy : ∀ j i, x j ≠ y i)
    (T : Finset (Fin m)) (hT : T.card = k) (msg : Fin m → F) (hmsg : ∀ i, i ∉ T → msg i = 0)
    (hval : ∀ j, (Lagrange.interpolate Finset.univ y msg).eval (x j) = 0) : msg = 0 := by
  classical
  set P := Lagrange.interpolate Finset.univ y msg with hP
  have hyinj : Set.InjOn y (Finset.univ : Finset (Fin m)) := hy.injOn
  have hdeg : P.degree < ((Finset.univ : Finset (Fin m)).card : WithBot ℕ) :=
    Lagrange.degree_interpolate_lt msg hyinj
  let v : Fin m ⊕ Fin k → F := Sum.elim y x
  have hv : Function.Injective v := by
    rintro (a | a) (b | b) h
    · exact congrArg Sum.inl (hy h)
    · exact absurd h.symm (hxy b a)
    · exact absurd h (hxy a b)
    · exact congrArg Sum.inr (hx h)
  let s : Finset (Fin m ⊕ Fin k) := Tᶜ.disjSum Finset.univ
  have hTm : T.card ≤ m := by simpa using Finset.card_le_univ T
  have hs : s.card = m := by
    simp only [s, Finset.card_disjSum, Finset.card_compl, Fintype.card_fin, Finset.card_univ, hT]
    omega
  have hP0 : P = 0 := by
    refine Polynomial.eq_zero_of_degree_lt_of_eval_index_eq_zero s hv.injOn ?_ ?_
    · rw [hs]
      simpa using hdeg
    · rintro (i | j) hi
      · have hiT : i ∉ T := by simpa [s] using hi
        show P.eval (y i) = 0
        rw [hP, Lagrange.eval_interpolate_at_node msg hyinj (Finset.mem_univ i)]
        exact hmsg i hiT
      · exact hval j
  funext i
  have h1 := Lagrange.eval_interpolate_at_node msg hyinj (Finset.mem_univ i)
  rw [← hP, hP0, eval_zero] at h1
  exact h1.symm

/-- **`M`'s pad block has full row rank.** Let the message domain `y` have `m` distinct points, let the `Q` pads sit
at distinct message positions `π l`, and let the `k ≤ Q` opened points `x_j` be distinct and outside the message
domain. Then every target vector of opened values is reached by some pad vector (with every other message position
zero). This is the property "the pad block is full rank on any `Q` distinct opened points" for `M`, whose pads reach
the opened points through the Lagrange basis of `G_512` (a scaled Cauchy block) instead of `Z_n · x^l`. -/
theorem mPadBlock_surjective [Fintype F] {m Q k : ℕ} (y : Fin m → F) (hy : Function.Injective y)
    (π : Fin Q → Fin m) (hπ : Function.Injective π) (hkQ : k ≤ Q)
    (x : Fin k → F) (hx : Function.Injective x) (hxy : ∀ j i, x j ≠ y i) :
    Function.Surjective (fun g : Fin Q → F => mOpened y x (placePads π g)) := by
  classical
  let ext : (Fin k → F) → (Fin Q → F) := fun v l => if h : (l : ℕ) < k then v ⟨l, h⟩ else 0
  let Φ : (Fin k → F) → (Fin k → F) := fun v => mOpened y x (placePads π (ext v))
  have hinj : Function.Injective Φ := by
    intro v v' h
    set msg := placePads π (ext v) - placePads π (ext v') with hmsg
    let T : Finset (Fin m) := Finset.univ.image (π ∘ Fin.castLE hkQ)
    have hT : T.card = k := by
      rw [Finset.card_image_of_injective _ (hπ.comp (Fin.castLE_injective hkQ))]
      simp
    have hout : ∀ i, i ∉ T → msg i = 0 := by
      intro i hi
      simp only [hmsg, Pi.sub_apply, placePads, ← Finset.sum_sub_distrib]
      refine Finset.sum_eq_zero (fun l _ => ?_)
      by_cases hl : π l = i
      · have hlk : ¬ ((l : ℕ) < k) := by
          intro hlk
          apply hi
          refine Finset.mem_image.mpr ⟨⟨l, hlk⟩, Finset.mem_univ _, ?_⟩
          rw [← hl]
          rfl
        simp [hl, ext, hlk]
      · simp [hl]
    have hval : ∀ j, (Lagrange.interpolate Finset.univ y msg).eval (x j) = 0 := by
      intro j
      have hj := congrFun h j
      simp only [Φ, mOpened] at hj
      rw [hmsg, map_sub, eval_sub, hj, sub_self]
    have h0 := interpolate_vanish y hy x hx hxy T hT msg hout hval
    funext l
    have h1 := congrFun h0 (π (Fin.castLE hkQ l))
    simp only [hmsg, Pi.sub_apply, Pi.zero_apply, placePads_apply_pos hπ, sub_eq_zero] at h1
    simpa [ext] using h1
  intro t
  obtain ⟨v, hv⟩ := Finite.surjective_of_injective hinj t
  exact ⟨ext v, hv⟩

/-- **One row of `M`: the opened values are exactly uniform, for every message.** Under the hypotheses of
`mPadBlock_surjective`, for every fixed message `w` (the mask coefficients and the zero positions; its entries at the
pad positions are irrelevant), the opened values of `w + pads` over uniform pads are uniform on `F^k`. For privacy:
opening at most `Q = 256` distinct columns of `M` reveals nothing about any one row's mask coefficients. -/
theorem mOpened_uniform [Fintype F] {m Q k : ℕ} (y : Fin m → F) (hy : Function.Injective y)
    (π : Fin Q → Fin m) (hπ : Function.Injective π) (hkQ : k ≤ Q)
    (x : Fin k → F) (hx : Function.Injective x) (hxy : ∀ j i, x j ≠ y i) (w : Fin m → F) :
    (PMF.uniformOfFintype (Fin Q → F)).map (fun g => mOpened y x (w + placePads π g))
      = PMF.uniformOfFintype (Fin k → F) := by
  have h : (fun g : Fin Q → F => mOpened y x (w + placePads π g))
      = fun g => mOpened y x w + mOpened y x (placePads π g) := by
    funext g
    rw [mOpened_add]
  rw [h]
  exact map_uniform_add_left_of_surjective _ (fun a b => by rw [placePads_add, mOpened_add])
    (mPadBlock_surjective y hy π hπ hkQ x hx hxy) _

/-- The opened values of `r` rows of `M` at the same `k` points; row `i` has the fixed message `W i` and the pads
`G i`, placed at its own pad positions `π i` (in `mask_commit` each sumcheck's mask has its own length `L_s`, so its
pads start at `L_s`). -/
noncomputable def mRowsOpened {m Q k r : ℕ} (y : Fin m → F) (x : Fin k → F) (π : Fin r → Fin Q → Fin m)
    (W : Fin r → Fin m → F) (G : Fin r → Fin Q → F) : Fin r → Fin k → F :=
  fun i => mOpened y x (W i + placePads (π i) (G i))

/-- **Several rows of `M`, independent pads: the opened values are jointly uniform, for any messages.** For privacy:
the opened columns of `M`'s a-rows (one entry per a-row) reveal nothing about the mask coefficients of any sumcheck,
nor about relations between them. -/
theorem mRowsOpened_uniform [Fintype F] {m Q k r : ℕ} (y : Fin m → F) (hy : Function.Injective y)
    (π : Fin r → Fin Q → Fin m) (hπ : ∀ i, Function.Injective (π i)) (hkQ : k ≤ Q)
    (x : Fin k → F) (hx : Function.Injective x) (hxy : ∀ j i, x j ≠ y i) (W : Fin r → Fin m → F) :
    (PMF.uniformOfFintype (Fin r → Fin Q → F)).map (mRowsOpened y x π W)
      = PMF.uniformOfFintype (Fin r → Fin k → F) := by
  have h : mRowsOpened y x π W
      = fun G : Fin r → Fin Q → F => (fun i => mOpened y x (W i))
          + fun i => mOpened y x (placePads (π i) (G i)) := by
    funext G i
    simp [mRowsOpened, mOpened_add]
  rw [h]
  refine map_uniform_add_left_of_surjective
    (fun G : Fin r → Fin Q → F => fun i => mOpened y x (placePads (π i) (G i))) ?_ ?_ _
  · intro a b
    funext i
    simp [placePads_add, mOpened_add]
  · intro Y
    choose G hG using fun i => mPadBlock_surjective y hy (π i) (hπ i) hkQ x hx hxy (Y i)
    exact ⟨G, funext hG⟩

/-- The opened values of `r` rows of `M` at a sampled index sequence `s` of the evaluation domain `X` (repeats
allowed). -/
noncomputable def mRowsSampled {m Q N q r : ℕ} (y : Fin m → F) (X : Fin N → F) (π : Fin r → Fin Q → Fin m)
    (W : Fin r → Fin m → F) (s : Fin q → Fin N) (G : Fin r → Fin Q → F) : Fin r → Fin q → F :=
  fun i t => (Lagrange.interpolate Finset.univ y (W i + placePads (π i) (G i))).eval (X (s t))

/-- **Sampling with replacement: the law of `M`'s opened a-row columns does not depend on the messages.** Let the
evaluation domain `X` have distinct points outside the message domain, and let the verifier's sample sequence `s` hit
at most `Q` distinct indices. Then the opened values of `r` rows with independent uniform pads have the same law for
any two message matrices `W`, `W'` (any two values of all the mask coefficients). -/
theorem mRowsSampled_law_eq [Fintype F] {m Q N q r : ℕ} (y : Fin m → F) (hy : Function.Injective y)
    (π : Fin r → Fin Q → Fin m) (hπ : ∀ i, Function.Injective (π i)) (X : Fin N → F) (hX : Function.Injective X)
    (hXy : ∀ j i, X j ≠ y i) (s : Fin q → Fin N) (hs : (Finset.univ.image s).card ≤ Q)
    (W W' : Fin r → Fin m → F) :
    (PMF.uniformOfFintype (Fin r → Fin Q → F)).map (mRowsSampled y X π W s)
      = (PMF.uniformOfFintype (Fin r → Fin Q → F)).map (mRowsSampled y X π W' s) := by
  have hinj : Function.Injective (X ∘ distinctPoints s) := hX.comp (distinctPoints_injective s)
  have hcomp : ∀ WW : Fin r → Fin m → F, mRowsSampled y X π WW s
      = (fun V i t => V i (distinctIndex s t)) ∘ mRowsOpened y (X ∘ distinctPoints s) π WW := by
    intro WW
    funext G i t
    simp [mRowsSampled, mRowsOpened, mOpened, distinctPoints_index]
  have hXy' : ∀ j i, (X ∘ distinctPoints s) j ≠ y i := fun j i => hXy _ i
  rw [hcomp, hcomp, ← PMF.map_comp, ← PMF.map_comp,
    mRowsOpened_uniform y hy π hπ hs _ hinj hXy' W, mRowsOpened_uniform y hy π hπ hs _ hinj hXy' W']

/-! ## The code's layout and `M`'s domain -/

/-- One a-row message as `mask_commit` lays it out: positions `0..L` hold the row's `L` coefficients (the real or
imaginary parts of a `CfsMask`'s coefficients), positions `L..L+Q` the `Q` pads, the rest zeros. -/
def mRowMsg (m : ℕ) {L Q : ℕ} (coef : Fin L → F) (g : Fin Q → F) : Fin m → F :=
  fun i => if h : (i : ℕ) < L then coef ⟨i, h⟩
    else if h' : (i : ℕ) < L + Q then g ⟨i - L, by omega⟩ else 0

/-- The pad positions of an a-row: `L + l`. -/
def mPadPos {L Q m : ℕ} (hLQ : L + Q ≤ m) : Fin Q → Fin m := fun l => ⟨L + l, by omega⟩

/-- The pad positions `L + l` are distinct, so the pads fill `Q` different message positions. -/
theorem mPadPos_injective {L Q m : ℕ} (hLQ : L + Q ≤ m) : Function.Injective (mPadPos hLQ) := by
  intro a b h
  simp only [mPadPos, Fin.mk.injEq] at h
  exact Fin.ext (by omega)

/-- **The code's layout is "a fixed message plus pads at the positions `L + l`".** So the lemmas above apply to
`mask_commit`'s rows with `W i = mRowMsg m (coefficients of row i) 0` and `π i = mPadPos (hLQ i)`. -/
theorem mRowMsg_eq {L Q m : ℕ} (hLQ : L + Q ≤ m) (coef : Fin L → F) (g : Fin Q → F) :
    mRowMsg m coef g = mRowMsg m coef (0 : Fin Q → F) + placePads (mPadPos hLQ) g := by
  funext i
  simp only [Pi.add_apply]
  by_cases h1 : (i : ℕ) < L
  · have hp : placePads (mPadPos hLQ) g i = 0 := by
      refine Finset.sum_eq_zero (fun l _ => ?_)
      have : mPadPos hLQ l ≠ i := by
        intro he
        have := congrArg Fin.val he
        simp only [mPadPos] at this
        omega
      simp [this]
    simp [mRowMsg, h1, hp]
  · by_cases h2 : (i : ℕ) < L + Q
    · have hl : mPadPos hLQ ⟨i - L, by omega⟩ = i := Fin.ext (by simp only [mPadPos]; omega)
      have hp : placePads (mPadPos hLQ) g i = g ⟨i - L, by omega⟩ := by
        simpa [hl] using placePads_apply_pos (mPadPos_injective hLQ) g ⟨i - L, by omega⟩
      simp [mRowMsg, h1, h2, hp]
    · have hp : placePads (mPadPos hLQ) g i = 0 := by
        refine Finset.sum_eq_zero (fun l _ => ?_)
        have : mPadPos hLQ l ≠ i := by
          intro he
          have := congrArg Fin.val he
          simp only [mPadPos] at this
          omega
        simp [this]
      simp [mRowMsg, h1, h2, hp]

/-- The coset points lie outside a message domain of `m`-th roots of unity: `(h ω^j)^m ≠ 1` when `m ∣ N`,
`ω^N = 1` and `h^N ≠ 1` (`coset_zn_ne_zero`), while every point of `G_m` satisfies `y^m = 1`. -/
theorem coset_ne_root {m N : ℕ} (hmN : m ∣ N) (h ω : F) (hω : ω ^ N = 1) (hh : h ^ N ≠ 1)
    (y : F) (hy : y ^ m = 1) (j : ℕ) : h * ω ^ j ≠ y := by
  intro he
  apply coset_zn_ne_zero hmN h ω hω hh j
  rw [he, hy, sub_self]

/-- A sample of `q ≤ Q` indices hits at most `Q` distinct indices; `mask_open` samples `MASK_Q = Q` indices. -/
theorem card_image_le_of_le {N q Q : ℕ} (s : Fin q → Fin N) (hq : q ≤ Q) :
    (Finset.univ.image s).card ≤ Q :=
  (Finset.card_image_le.trans (by simp)).trans hq

/-- **`M`'s opened a-row columns hide every mask coefficient (the protocol statement).** The message domain is `G_m`
(`m = 512`; any injective enumeration `y` of `m`-th roots of unity, e.g. `y i = ω_512^i`); a-row `i` holds its `L i`
coefficients, then `Q` pads, then zeros (`L i + Q ≤ m`, the `assert!` in `mask_commit`); the evaluation domain is the
coset `h · ⟨ω⟩` with `ω` of order `N` (`N = 4096`), `m ∣ N`, `h ≠ 0` and `h^N ≠ 1` (`h = 7`, asserted by
`coset_powers`); the verifier samples `q ≤ Q` indices with replacement (`q = Q = 256`). Then, over independent uniform
pads, the law of all the opened a-row entries is the same for any two choices of the coefficients `coef`, `coef'`
(the CFS masks of every sumcheck of the block). -/
theorem mask_aRows_law_eq [Fintype F] {Q m N q r : ℕ} (L : Fin r → ℕ) (hLQ : ∀ i, L i + Q ≤ m) (hmN : m ∣ N)
    (y : Fin m → F) (hy : Function.Injective y) (hroots : ∀ i, y i ^ m = 1)
    (h ω : F) (hh0 : h ≠ 0) (hh : h ^ N ≠ 1) (hω : IsPrimitiveRoot ω N)
    (s : Fin q → Fin N) (hq : q ≤ Q) (coef coef' : ∀ i : Fin r, Fin (L i) → F) :
    (PMF.uniformOfFintype (Fin r → Fin Q → F)).map
        (fun G i t => (Lagrange.interpolate Finset.univ y (mRowMsg m (coef i) (G i))).eval
          (h * ω ^ ((s t : Fin N) : ℕ)))
      = (PMF.uniformOfFintype (Fin r → Fin Q → F)).map
        (fun G i t => (Lagrange.interpolate Finset.univ y (mRowMsg m (coef' i) (G i))).eval
          (h * ω ^ ((s t : Fin N) : ℕ))) := by
  have hX : Function.Injective (fun j : Fin N => h * ω ^ (j : ℕ)) := coset_points_injective h ω hh0 hω
  have hXy : ∀ (j : Fin N) (i : Fin m), (fun j : Fin N => h * ω ^ (j : ℕ)) j ≠ y i :=
    fun j i => coset_ne_root hmN h ω hω.pow_eq_one hh (y i) (hroots i) j
  have hform : ∀ cc : ∀ i : Fin r, Fin (L i) → F,
      (fun (G : Fin r → Fin Q → F) i t =>
          (Lagrange.interpolate Finset.univ y (mRowMsg m (cc i) (G i))).eval (h * ω ^ ((s t : Fin N) : ℕ)))
        = mRowsSampled y (fun j : Fin N => h * ω ^ (j : ℕ)) (fun i => mPadPos (hLQ i))
            (fun i => mRowMsg m (cc i) (0 : Fin Q → F)) s := by
    intro cc
    funext G i t
    simp only [mRowsSampled]
    rw [mRowMsg_eq (hLQ i) (cc i) (G i)]
  rw [hform coef, hform coef']
  exact mRowsSampled_law_eq y hy (fun i => mPadPos (hLQ i)) (fun i => mPadPos_injective (hLQ i)) _ hX hXy s
    (card_image_le_of_le s hq) _ _

end MPad

end ZK60.Hiding
