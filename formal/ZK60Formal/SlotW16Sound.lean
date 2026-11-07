/-
D63 step L11, part 3: **per-slot soundness of the W16R2 slots** (interactive, challenges uniform and independent), on
the existing `Sound*` lemmas. Generic in the slot's shape, so it serves W16R3's batched slots too.

The three slot kinds of the code (`layout.rs:1067-1114`) reduce to three claims:
* a PRIVATE slot publishes its true cube sum `S` (masked): a matmul's `Σ_c A(r, c)·W̃(c)` is the multilinear extension
  of the contraction `M = Σ_c A·W` at its claim point (`matmul_sum`, `mle2`); a row sum's is the extension of the row
  totals (`rowsum_sum`);
* a HOST zero-check claims `Σ_x [eq(τ, x)·Z(x) + Σ_i ν_i·eq(p_i, x)·g(x)·h_i(x)] = Σ_i ν_i·S_i`
  (`host_cubeSum`, `host_claim_iff`): the batched relation `Z` (every clause `μ_k·c_k`, the helper relations, the
  pad term `μ_pad·(1 − supp)·Σ_j ζ^j·plane_j`) vanishes at `τ`, and each hosted identity `g·h_i = M_i` holds at `p_i`;
* a STANDALONE slot claims `0` (`SC_TAB`, `SC_LZC`, `SC_IO_*` are zero-checks of their own; `SC_ZS` is LogUp's sum).

What is proved (only `propext`, `Classical.choice`, `Quot.sound`), with `F` any finite field and every challenge
uniform and independent (the Fiat–Shamir step is L7/L8's, `exec_sumchecks_fs_sound`):
* the counting calculus: `Dens` (`|E|·|F| ≤ k·|Ω|`), `dens_prob` (then `Pr[E] ≤ k/|F|`), `dens_prod` (condition on
  the first coordinates), `dens_union`, `dens_fst`, `dens_snd`;
* the base densities: `dens_affine` (a nonzero linear form: `1`), `dens_mle_zero` (`mle_zero_card_le`: `n`),
  `dens_mleEq` (two different cube functions agree at a random point: `n`), `dens_root` (a nonzero polynomial of
  degree `≤ d`: `d`);
* **`dens_batchPad`**: the batched relation at one cube point, with `m` pad planes batched by `ζ`-powers: if some
  clause or some pad plane is nonzero anywhere, `Z` vanishes on the whole cube with density at most `m + 1`;
* **`dens_host`**: the host's claim with its `ν`-batched hosted differences `D_i`: if the relation fails or some
  `D_i ≠ 0`, the claim holds with density at most `m + 1 + n + 1`;
* **`dens_host_hosted`**: a host and its two hosted private slots (their claim points `p_1, p_2` drawn first): if the
  host's relation fails or a hosted identity `H_i = M_i` fails on its cube, all three claims hold with density at most
  `n_1 + n_2 + m + n + 2` (`host_hosted_sound`: the probability `≤ (n_1 + n_2 + m + n + 2)/|F|`);
* **`dens_rowsum`**: `SC_RS`'s `λ`-batched row claim (`Σ_j mask·e = sum` and `Σ_j zsel = 1` per row, at `p_ht`):
  at most `n + 1`;
* `helperClause_single`, `helperClause_pair`: the zero-check's LogUp helper clauses (`argument::helper_sum`) are
  exactly `HelperRel`'s (SoundLogUpBlock.lean), so their vanishing is `logup_block_bound`'s premise.
-/
import ZK60Formal.SoundZeroCheck
import ZK60Formal.SoundLogUpBlock

namespace ZK60.Sound.SlotW16

open scoped ENNReal
open Finset Polynomial

/-! ## Counting with densities -/

section Dens

variable (F : Type) [Fintype F]

/-- `E` has density at most `k/|F|` in `Ω`: `|E|·|F| ≤ k·|Ω|`. -/
def Dens {Ω : Type} [Fintype Ω] (E : Ω → Prop) [DecidablePred E] (k : ℕ) : Prop :=
  (univ.filter E).card * Fintype.card F ≤ k * Fintype.card Ω

variable {F}

theorem dens_prob {Ω : Type} [Fintype Ω] [Nonempty Ω] [Nonempty F] {E : Ω → Prop} [DecidablePred E] {k : ℕ}
    (h : Dens F E k) :
    (PMF.uniformOfFintype Ω).toOuterMeasure {ω | E ω} ≤ (k : ℝ≥0∞) / Fintype.card F :=
  prob_le_of_card_mul E k (Fintype.card F) Fintype.card_ne_zero h

theorem dens_mono {Ω : Type} [Fintype Ω] {E E' : Ω → Prop} [DecidablePred E] [DecidablePred E'] {k : ℕ}
    (hE : ∀ ω, E ω → E' ω) (h : Dens F E' k) : Dens F E k :=
  le_trans (Nat.mul_le_mul_right _ (card_le_card fun x hx =>
    mem_filter.mpr ⟨mem_univ _, hE x (mem_filter.mp hx).2⟩)) h

theorem dens_le {Ω : Type} [Fintype Ω] {E : Ω → Prop} [DecidablePred E] {k k' : ℕ} (hk : k ≤ k')
    (h : Dens F E k) : Dens F E k' :=
  h.trans (Nat.mul_le_mul_right _ hk)

theorem dens_empty {Ω : Type} [Fintype Ω] {E : Ω → Prop} [DecidablePred E] (h : ∀ ω, ¬ E ω) : Dens F E 0 := by
  unfold Dens
  rw [filter_false_of_mem (fun ω _ => h ω)]
  simp

/-- **Conditioning on the first coordinates**: if `A` has density `a`, and off `A` every slice of `E` has density
`b`, then `E` has density `a + b`. -/
theorem dens_prod {α β : Type} [Fintype α] [Fintype β] (E : α × β → Prop) [DecidablePred E]
    (A : α → Prop) [DecidablePred A] (a b : ℕ) (hA : Dens F A a)
    (hB : ∀ x, ¬ A x → Dens F (fun y => E (x, y)) b) : Dens F E (a + b) := by
  unfold Dens at *
  rw [card_filter_prod, sum_mul, Fintype.card_prod]
  have hx : ∀ x, (univ.filter (fun y => E (x, y))).card * Fintype.card F
      ≤ (if A x then Fintype.card β * Fintype.card F else 0) + b * Fintype.card β := by
    intro x
    by_cases h : A x
    · rw [ite_eq_left h]
      exact (Nat.mul_le_mul_right _ ((card_filter_le _ _).trans (le_of_eq card_univ))).trans (Nat.le_add_right _ _)
    · rw [ite_eq_right h, zero_add]
      exact hB x h
  calc ∑ x, (univ.filter (fun y => E (x, y))).card * Fintype.card F
      ≤ ∑ x, ((if A x then Fintype.card β * Fintype.card F else 0) + b * Fintype.card β) :=
        sum_le_sum fun x _ => hx x
    _ = (univ.filter A).card * (Fintype.card β * Fintype.card F) + Fintype.card α * (b * Fintype.card β) := by
        rw [sum_add_distrib, ← sum_filter, sum_const, sum_const, card_univ, smul_eq_mul, smul_eq_mul]
    _ ≤ (a + b) * (Fintype.card α * Fintype.card β) := by
        have := Nat.mul_le_mul_right (Fintype.card β) hA
        nlinarith [this]

theorem dens_union {Ω : Type} [Fintype Ω] (E₁ E₂ : Ω → Prop) [DecidablePred E₁] [DecidablePred E₂] {k₁ k₂ : ℕ}
    (h₁ : Dens F E₁ k₁) (h₂ : Dens F E₂ k₂) : Dens F (fun ω => E₁ ω ∨ E₂ ω) (k₁ + k₂) := by
  classical
  unfold Dens at *
  rw [filter_or]
  calc (univ.filter E₁ ∪ univ.filter E₂).card * Fintype.card F
      ≤ ((univ.filter E₁).card + (univ.filter E₂).card) * Fintype.card F :=
        Nat.mul_le_mul_right _ (card_union_le _ _)
    _ ≤ (k₁ + k₂) * Fintype.card Ω := by nlinarith [h₁, h₂]

/-- An event of the first coordinates keeps its density on a product. -/
theorem dens_fst {α β : Type} [Fintype α] [Fintype β] (A : α → Prop) [DecidablePred A] {a : ℕ} (h : Dens F A a) :
    Dens F (fun p : α × β => A p.1) a := by
  have := dens_prod (F := F) (fun p : α × β => A p.1) A a 0 h (fun x hx => dens_empty (fun _ => hx))
  simpa using this

/-- An event of the second coordinates keeps its density on a product. -/
theorem dens_snd {α β : Type} [Fintype α] [Fintype β] (B : β → Prop) [DecidablePred B] {b : ℕ} (h : Dens F B b) :
    Dens F (fun p : α × β => B p.2) b := by
  have := dens_prod (F := F) (fun p : α × β => B p.2) (fun _ : α => False) 0 b (by unfold Dens; simp)
    (fun _ _ => h)
  simpa using this

end Dens

/-! ## Base densities -/

section Base

variable {F : Type} [Field F] [Fintype F] [DecidableEq F]

/-- **A nonzero linear form**: `a + Σ_i ν_i·D_i = 0` for at most one value of `ν_{i₀}` per choice of the others. -/
theorem dens_affine {ι : Type} [Fintype ι] [DecidableEq ι] (a : F) (D : ι → F) (hD : ∃ i, D i ≠ 0) :
    Dens F (fun ν : ι → F => a + ∑ i, ν i * D i = 0) 1 := by
  obtain ⟨i₀, hi₀⟩ := hD
  unfold Dens
  let e := Equiv.piSplitAt i₀ (fun _ : ι => F)
  have hcard : (univ.filter (fun ν : ι → F => a + ∑ i, ν i * D i = 0)).card
      ≤ (univ : Finset ({i // i ≠ i₀} → F)).card := by
    refine card_le_card_of_injOn (fun ν => (e ν).2) (fun _ _ => mem_univ _) ?_
    intro ν₁ h₁' ν₂ h₂' h12
    have h₁ : a + ∑ i, ν₁ i * D i = 0 := by simpa using h₁'
    have h₂ : a + ∑ i, ν₂ i * D i = 0 := by simpa using h₂'
    have hrest : ∀ i, i ≠ i₀ → ν₁ i = ν₂ i := fun i hi => congrFun h12 ⟨i, hi⟩
    have hsplit : ∀ ν : ι → F, ∑ i, ν i * D i = ν i₀ * D i₀ + ∑ i ∈ ({i₀}ᶜ : Finset ι), ν i * D i :=
      fun ν => Fintype.sum_eq_add_sum_compl i₀ _
    have hsum : ∑ i ∈ ({i₀}ᶜ : Finset ι), ν₁ i * D i = ∑ i ∈ ({i₀}ᶜ : Finset ι), ν₂ i * D i :=
      sum_congr rfl (fun i hi => by rw [hrest i (by simpa using hi)])
    have h0 : ν₁ i₀ = ν₂ i₀ := by
      have := h₁.trans h₂.symm
      rw [hsplit, hsplit, hsum] at this
      have h' : ν₁ i₀ * D i₀ = ν₂ i₀ * D i₀ := by linear_combination this
      exact mul_right_cancel₀ hi₀ h'
    funext i
    by_cases hi : i = i₀
    · subst hi
      exact h0
    · exact hrest i hi
  have hsize : Fintype.card ({i // i ≠ i₀} → F) * Fintype.card F = Fintype.card (ι → F) := by
    rw [Fintype.card_congr e, Fintype.card_prod, mul_comm]
  calc (univ.filter (fun ν : ι → F => a + ∑ i, ν i * D i = 0)).card * Fintype.card F
      ≤ (univ : Finset ({i // i ≠ i₀} → F)).card * Fintype.card F := Nat.mul_le_mul_right _ hcard
    _ = 1 * Fintype.card (ι → F) := by rw [card_univ, hsize, one_mul]

/-- **The zero-check point** (`mle_zero_card_le`): a cube function nonzero somewhere has an extension vanishing at a
random point with density at most `n`. -/
theorem dens_mle_zero {n : ℕ} (P : (Fin n → Bool) → F) (hP : ∃ b, P b ≠ 0) :
    Dens F (fun τ : Fin n → F => mleAt P τ = 0) n := by
  unfold Dens
  rw [Fintype.card_fun, Fintype.card_fin]
  convert mle_zero_card_le n P hP

omit [Fintype F] [DecidableEq F] in
theorem mleAt_sub {n : ℕ} (P Q : (Fin n → Bool) → F) (τ : Fin n → F) :
    mleAt P τ - mleAt Q τ = mleAt (fun b => P b - Q b) τ := by
  unfold mleAt
  rw [← sum_sub_distrib]
  exact sum_congr rfl fun b _ => by ring

/-- **A hosted identity at its claim point**: two cube functions that differ somewhere agree at a random point with
density at most `n`. -/
theorem dens_mleEq {n : ℕ} (P Q : (Fin n → Bool) → F) (h : ∃ b, P b ≠ Q b) :
    Dens F (fun p : Fin n → F => mleAt P p = mleAt Q p) n := by
  obtain ⟨b, hb⟩ := h
  refine dens_mono (fun p hp => ?_) (dens_mle_zero (fun b => P b - Q b) ⟨b, sub_ne_zero.mpr hb⟩)
  rw [← mleAt_sub, hp, sub_self]

/-- **A nonzero polynomial of degree `≤ d`** vanishes at a random point with density at most `d`. -/
theorem dens_root (p : F[X]) (hp : p ≠ 0) {d : ℕ} (hd : p.natDegree ≤ d) :
    Dens F (fun r : F => p.eval r = 0) d := by
  unfold Dens
  exact Nat.mul_le_mul_right _ ((card_roots_le p hp).trans hd)

end Base

/-! ## The batched relation of a zero-check -/

section Batch

variable {F : Type} [Field F] [Fintype F] [DecidableEq F]

/-- **The batched relation at a cube point** (`dzc_w16` and its siblings): `Σ_k μ_k·c_k(b) + μ_pad·Σ_{j<m} ζ^j·w_j(b)`,
where `c_k` are the slot's clauses (the gated arithmetic clauses `gate·clause`, the LogUp helper relations, the
activation / exp tuple relations, each with its own `μ` entry) and `w_j = (1 − supp)·plane_j` the pad term's planes. The
challenges are `((ζ, μ_pad), μ)`. -/
def batched {B ι : Type} [Fintype ι] {m : ℕ} (c : ι → B → F) (w : Fin m → B → F) (ω : (F × F) × (ι → F)) (b : B) : F :=
  ∑ k, ω.2 k * c k b + ω.1.2 * ∑ j : Fin m, ω.1.1 ^ (j : ℕ) * w j b

/-- The pad term's polynomial in `ζ` at a point. -/
noncomputable def padPoly {B : Type} {m : ℕ} (w : Fin m → B → F) (b : B) : F[X] := ∑ j : Fin m, C (w j b) * X ^ (j : ℕ)

omit [Fintype F] [DecidableEq F] in
theorem padPoly_eval {B : Type} {m : ℕ} (w : Fin m → B → F) (b : B) (ζ : F) :
    (padPoly w b).eval ζ = ∑ j : Fin m, ζ ^ (j : ℕ) * w j b := by
  unfold padPoly
  rw [eval_finsetSum]
  exact sum_congr rfl fun j _ => by rw [eval_mul, eval_C, eval_pow, eval_X, mul_comm]

omit [Fintype F] [DecidableEq F] in
theorem padPoly_ne {B : Type} {m : ℕ} (w : Fin m → B → F) (b : B) (j₀ : Fin m) (h : w j₀ b ≠ 0) :
    padPoly w b ≠ 0 := by
  intro h0
  have hc := congrArg (fun p => Polynomial.coeff p (j₀ : ℕ)) h0
  simp only [padPoly, finsetSum_coeff, coeff_C_mul_X_pow, coeff_zero] at hc
  rw [sum_eq_single j₀ (fun j _ hj => by rw [ite_eq_right (fun e => hj (Fin.ext e).symm)])
    (fun h => absurd (mem_univ _) h), ite_eq_left rfl] at hc
  exact h hc

omit [Fintype F] [DecidableEq F] in
theorem padPoly_natDegree {B : Type} {m : ℕ} (w : Fin m → B → F) (b : B) : (padPoly w b).natDegree ≤ m := by
  unfold padPoly
  refine natDegree_sum_le_of_forall_le _ _ fun j _ => (natDegree_C_mul_X_pow_le _ _).trans ?_
  exact le_of_lt j.isLt

/-- A line `a + λ·b` vanishes for at most one `λ` unless `a = b = 0`. -/
theorem dens_line (a b : F) (h : a ≠ 0 ∨ b ≠ 0) : Dens F (fun l : F => a + l * b = 0) 1 := by
  unfold Dens
  refine Nat.mul_le_mul_right _ ((card_le_one.mpr fun l₁ h₁ l₂ h₂ => ?_).trans (le_of_eq (by simp)))
  simp only [mem_filter, mem_univ, true_and] at h₁ h₂
  by_cases hb : b = 0
  · rw [hb, mul_zero, add_zero] at h₁
    exact absurd h₁ (h.resolve_right (fun h' => h' hb))
  · have : (l₁ - l₂) * b = 0 := by linear_combination h₁ - h₂
    exact sub_eq_zero.mp ((mul_eq_zero.mp this).resolve_right hb)

/-- **The batch kills a failing relation with density at most `m + 1`.** If some clause or some pad plane is nonzero
at some cube point, the batched relation vanishes on the whole cube for at most a `(m + 1)/|F|` share of the
challenges `((ζ, μ_pad), μ)`: a clause is caught by `μ` (`1`), a pad plane by `ζ` (`m`, the degree of the pad term's
polynomial) and then `μ_pad` (`1`). -/
theorem dens_batchPad {B ι : Type} [Fintype B] [Fintype ι] [DecidableEq ι] {m : ℕ} (c : ι → B → F)
    (w : Fin m → B → F) (h : (∃ k b, c k b ≠ 0) ∨ (∃ j b, w j b ≠ 0)) :
    Dens F (fun ω : (F × F) × (ι → F) => ∀ b, batched c w ω b = 0) (m + 1) := by
  classical
  by_cases hc : ∃ k b, c k b ≠ 0
  · obtain ⟨k₀, b₀, hk⟩ := hc
    refine dens_le (by omega) (dens_prod (F := F) _ (fun _ : F × F => False) 0 1 (dens_empty fun _ h => h) ?_)
    intro x _
    refine dens_mono (fun μ hμ => ?_)
      (dens_affine (x.2 * ∑ j : Fin m, x.1 ^ (j : ℕ) * w j b₀) (fun k => c k b₀) ⟨k₀, hk⟩)
    have := hμ b₀
    unfold batched at this
    linear_combination this
  · push Not at hc
    obtain ⟨j₀, b₀, hj⟩ := h.resolve_left (by push Not; exact hc)
    have hev : ∀ ω : (F × F) × (ι → F), (∀ b, batched c w ω b = 0) →
        (padPoly w b₀).eval ω.1.1 = 0 ∨ ω.1.2 = 0 := by
      intro ω hω
      have h1 := hω b₀
      unfold batched at h1
      rw [sum_eq_zero (fun k _ => by rw [hc k b₀, mul_zero]), zero_add, ← padPoly_eval] at h1
      rcases mul_eq_zero.mp h1 with h2 | h2
      · exact Or.inr h2
      · exact Or.inl h2
    refine dens_mono hev (dens_fst (F := F) (β := ι → F) (fun x : F × F => (padPoly w b₀).eval x.1 = 0 ∨ x.2 = 0) ?_)
    refine dens_prod (F := F) _ (fun ζ : F => (padPoly w b₀).eval ζ = 0) m 1
      (dens_root _ (padPoly_ne w b₀ j₀ hj) (padPoly_natDegree w b₀)) (fun ζ hζ => ?_)
    refine dens_mono (fun μp hμp => ?_) (dens_line (0 : F) 1 (Or.inr one_ne_zero))
    rcases hμp with h' | h'
    · exact absurd h' hζ
    · have h'' : μp = 0 := h'
      rw [h'']
      ring

end Batch

/-! ## A host zero-check -/

section Host

variable {F : Type} [Field F] [Fintype F] [DecidableEq F]

/-- **The host slot's polynomial at a cube point** (`three_terms`, slot_ir_accuracy.rs:102-109; the closures of
`dzc_w16` 498, `fzc_w16` 532, `qzc_w16` 565, `szc_w16`'s groups, `SC_TZC` 2097-2100): `eq(τ, x)·Z(x)` plus, per
hosted slot `i`, `ν_i·eq(p_i, x)·g(x)·h_i(x)`. -/
def hostPoly {n : ℕ} (τ : Fin n → F) (Z : (Fin n → Bool) → F) (ν : Fin 2 → F) (p : Fin 2 → Fin n → F)
    (g : (Fin n → Bool) → F) (h : Fin 2 → (Fin n → Bool) → F) (b : Fin n → Bool) : F :=
  eqPoly τ (fun i => bit (b i)) * Z b + ∑ i, ν i * (eqPoly (p i) (fun k => bit (b k)) * (g b * h i b))

omit [Fintype F] [DecidableEq F] in
/-- **The host's cube sum**: `Z̃(τ) + Σ_i ν_i·(g·h_i)~(p_i)`. -/
theorem host_cubeSum {n : ℕ} (τ : Fin n → F) (Z : (Fin n → Bool) → F) (ν : Fin 2 → F) (p : Fin 2 → Fin n → F)
    (g : (Fin n → Bool) → F) (h : Fin 2 → (Fin n → Bool) → F) :
    ∑ b, hostPoly τ Z ν p g h b = mleAt Z τ + ∑ i, ν i * mleAt (fun b => g b * h i b) (p i) := by
  unfold hostPoly mleAt
  rw [sum_add_distrib, sum_comm]
  congr 1
  exact sum_congr rfl fun i _ => by rw [mul_sum]

omit [Fintype F] [DecidableEq F] in
/-- **The host's claim** (the claimed sum `Σ_i ν_i·S_i`, `S_i` the hosted slots' true sums): it holds exactly when the
batched relation's extension at `τ` plus the `ν`-batched hosted differences `D_i = (g·h_i)~(p_i) − S_i` vanish. -/
theorem host_claim_iff {n : ℕ} (τ : Fin n → F) (Z : (Fin n → Bool) → F) (ν : Fin 2 → F) (p : Fin 2 → Fin n → F)
    (g : (Fin n → Bool) → F) (h : Fin 2 → (Fin n → Bool) → F) (S : Fin 2 → F) :
    ∑ b, hostPoly τ Z ν p g h b = ∑ i, ν i * S i ↔
      mleAt Z τ + ∑ i, ν i * (mleAt (fun b => g b * h i b) (p i) - S i) = 0 := by
  rw [host_cubeSum]
  constructor
  · intro e
    have : ∑ i, ν i * (mleAt (fun b => g b * h i b) (p i) - S i)
        = ∑ i, ν i * mleAt (fun b => g b * h i b) (p i) - ∑ i, ν i * S i := by
      rw [← sum_sub_distrib]
      exact sum_congr rfl fun i _ => by ring
    rw [this]
    linear_combination e
  · intro e
    have : ∑ i, ν i * (mleAt (fun b => g b * h i b) (p i) - S i)
        = ∑ i, ν i * mleAt (fun b => g b * h i b) (p i) - ∑ i, ν i * S i := by
      rw [← sum_sub_distrib]
      exact sum_congr rfl fun i _ => by ring
    rw [this] at e
    linear_combination e

/-- **The host zero-check, counted.** The challenges are `(((ζ, μ_pad), μ), τ), ν)`, drawn after the clauses, the
pad planes and the hosted differences `D` are fixed. If some clause or pad plane is nonzero somewhere, or some hosted
difference is nonzero, the host's claim holds for at most an `(m + 1 + n + 1)/|F|` share of them. -/
theorem dens_host {n : ℕ} {ι : Type} [Fintype ι] [DecidableEq ι] {m : ℕ} (c : ι → (Fin n → Bool) → F)
    (w : Fin m → (Fin n → Bool) → F) (D : Fin 2 → F)
    (hfail : ¬ ((∀ k b, c k b = 0) ∧ (∀ j b, w j b = 0) ∧ ∀ i, D i = 0)) :
    Dens F (fun ω : (((F × F) × (ι → F)) × (Fin n → F)) × (Fin 2 → F) =>
      mleAt (batched c w ω.1.1) ω.1.2 + ∑ i, ω.2 i * D i = 0) (m + 1 + n + 1) := by
  classical
  by_cases hD : ∃ i, D i ≠ 0
  · refine dens_le (by omega) (dens_prod (F := F) _ (fun _ => False) 0 1 (dens_empty fun _ h => h) ?_)
    intro x _
    exact dens_mono (fun _ h => h) (dens_affine (mleAt (batched c w x.1) x.2) D hD)
  · push Not at hD
    have hrel : (∃ k b, c k b ≠ 0) ∨ (∃ j b, w j b ≠ 0) := by
      by_contra hn
      push Not at hn
      exact hfail ⟨hn.1, hn.2, hD⟩
    refine dens_le (by omega) (dens_prod (F := F) _
      (fun x : ((F × F) × (ι → F)) × (Fin n → F) => mleAt (batched c w x.1) x.2 = 0) (m + 1 + n) 0 ?_ ?_)
    · refine dens_prod (F := F) _ (fun ω => ∀ b, batched c w ω b = 0) (m + 1) n
        (dens_mono (fun _ h => h) (dens_batchPad c w hrel)) ?_
      intro ω hω
      push Not at hω
      exact dens_mono (fun _ h => h) (dens_mle_zero (batched c w ω) hω)
    · intro x hx
      refine dens_empty fun ν hν => hx ?_
      simpa [hD] using hν

/-- **A host and its two hosted private slots, counted.** The hosted slots' claim points `p_1, p_2` are drawn first;
the hosted slots' true sums are `M̃_i(p_i)` (`matmul_sum`, `rowsum_sum`) and the host's terms `H̃_i(p_i)`. If the host's
relation fails somewhere, or some hosted identity `H_i = M_i` fails somewhere on its cube, all three claims hold for at
most an `(n_1 + n_2 + m + 1 + n + 1)/|F|` share of the challenges. -/
theorem dens_host_hosted {n n₁ n₂ : ℕ} {ι : Type} [Fintype ι] [DecidableEq ι] {m : ℕ}
    (c : ι → (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F)
    (H₁ M₁ : (Fin n₁ → Bool) → F) (H₂ M₂ : (Fin n₂ → Bool) → F)
    (hfail : ¬ ((∀ k b, c k b = 0) ∧ (∀ j b, w j b = 0) ∧ (∀ b, H₁ b = M₁ b) ∧ ∀ b, H₂ b = M₂ b)) :
    Dens F (fun ω : ((Fin n₁ → F) × (Fin n₂ → F)) × ((((F × F) × (ι → F)) × (Fin n → F)) × (Fin 2 → F)) =>
      mleAt (batched c w ω.2.1.1) ω.2.1.2
        + ∑ i, ω.2.2 i * ![mleAt H₁ ω.1.1 - mleAt M₁ ω.1.1, mleAt H₂ ω.1.2 - mleAt M₂ ω.1.2] i = 0)
      (n₁ + n₂ + (m + 1 + n + 1)) := by
  classical
  refine dens_prod (F := F) _ (fun p : (Fin n₁ → F) × (Fin n₂ → F) =>
      ((∃ b, H₁ b ≠ M₁ b) ∧ mleAt H₁ p.1 = mleAt M₁ p.1) ∨ ((∃ b, H₂ b ≠ M₂ b) ∧ mleAt H₂ p.2 = mleAt M₂ p.2))
    (n₁ + n₂) _ ?_ ?_
  · refine dens_union (F := F) _ _ ?_ ?_
    · refine dens_fst (F := F) (β := Fin n₂ → F) (fun p₁ => (∃ b, H₁ b ≠ M₁ b) ∧ mleAt H₁ p₁ = mleAt M₁ p₁) ?_
      by_cases h₁ : ∃ b, H₁ b ≠ M₁ b
      · exact dens_mono (fun p hp => hp.2) (dens_mleEq H₁ M₁ h₁)
      · exact dens_le (Nat.zero_le _) (dens_empty fun p hp => h₁ hp.1)
    · refine dens_snd (F := F) (α := Fin n₁ → F) (fun p₂ => (∃ b, H₂ b ≠ M₂ b) ∧ mleAt H₂ p₂ = mleAt M₂ p₂) ?_
      by_cases h₂ : ∃ b, H₂ b ≠ M₂ b
      · exact dens_mono (fun p hp => hp.2) (dens_mleEq H₂ M₂ h₂)
      · exact dens_le (Nat.zero_le _) (dens_empty fun p hp => h₂ hp.1)
  · intro p hp
    refine dens_mono (fun _ h => h)
      (dens_host c w ![mleAt H₁ p.1 - mleAt M₁ p.1, mleAt H₂ p.2 - mleAt M₂ p.2] ?_)
    rintro ⟨hc, hw, hD⟩
    refine hfail ⟨hc, hw, ?_, ?_⟩
    · by_contra h₁
      push Not at h₁
      have h0 : mleAt H₁ p.1 - mleAt M₁ p.1 = 0 := hD 0
      exact hp (Or.inl ⟨h₁, sub_eq_zero.mp h0⟩)
    · by_contra h₂
      push Not at h₂
      have h0 : mleAt H₂ p.2 - mleAt M₂ p.2 = 0 := hD 1
      exact hp (Or.inr ⟨h₂, sub_eq_zero.mp h0⟩)

/-- **The same as a probability**: at most `(n_1 + n_2 + m + n + 2)/|F|`. -/
theorem host_hosted_sound {n n₁ n₂ : ℕ} {ι : Type} [Fintype ι] [DecidableEq ι] {m : ℕ}
    (c : ι → (Fin n → Bool) → F) (w : Fin m → (Fin n → Bool) → F)
    (H₁ M₁ : (Fin n₁ → Bool) → F) (H₂ M₂ : (Fin n₂ → Bool) → F)
    (hfail : ¬ ((∀ k b, c k b = 0) ∧ (∀ j b, w j b = 0) ∧ (∀ b, H₁ b = M₁ b) ∧ ∀ b, H₂ b = M₂ b)) :
    (PMF.uniformOfFintype (((Fin n₁ → F) × (Fin n₂ → F)) × ((((F × F) × (ι → F)) × (Fin n → F)) × (Fin 2 → F)))).toOuterMeasure
        {ω | mleAt (batched c w ω.2.1.1) ω.2.1.2
          + ∑ i, ω.2.2 i * ![mleAt H₁ ω.1.1 - mleAt M₁ ω.1.1, mleAt H₂ ω.1.2 - mleAt M₂ ω.1.2] i = 0}
      ≤ ((n₁ + n₂ + (m + 1 + n + 1) : ℕ) : ℝ≥0∞) / Fintype.card F := by
  classical
  exact dens_prob (dens_host_hosted c w H₁ M₁ H₂ M₂ hfail)

/-- **`SC_RS`'s row claim, counted** (argument.rs:2135-2148, hosted by `SC_SZC`): `Σ_j mask·e − sum` (`A`) and
`Σ_j zsel − 1` (`B`), per row, batched by `λ` (drawn after `p_ht`) and read at `p_ht`. If either is nonzero at some row,
`Ã(p) + λ·B̃(p) = 0` for at most an `(n + 1)/|F|` share of `(p_ht, λ)`. -/
theorem dens_rowsum {n : ℕ} (A B : (Fin n → Bool) → F) (h : ¬ ((∀ b, A b = 0) ∧ ∀ b, B b = 0)) :
    Dens F (fun ω : (Fin n → F) × F => mleAt A ω.1 + ω.2 * mleAt B ω.1 = 0) (n + 1) := by
  classical
  refine dens_prod (F := F) _ (fun p => mleAt A p = 0 ∧ mleAt B p = 0) n 1 ?_ ?_
  · by_cases hA : ∃ b, A b ≠ 0
    · exact dens_mono (fun p hp => hp.1) (dens_mle_zero A hA)
    · have hB : ∃ b, B b ≠ 0 := by
        by_contra hB
        push Not at hA hB
        exact h ⟨hA, hB⟩
      exact dens_mono (fun p hp => hp.2) (dens_mle_zero B hB)
  · intro p hp
    refine dens_mono (fun l hl => ?_) (dens_line (mleAt A p) (mleAt B p) (by tauto))
    exact hl

end Host

/-! ## The private slots' sums (product cubes) -/

section Private

variable {F : Type} [Field F]

/-- The multilinear extension over a product of two cubes, at `(r, s)`: `Σ_{z,j} eq(r, z)·eq(s, j)·P(z, j)`. -/
def mle2 {a b : ℕ} (P : (Fin a → Bool) → (Fin b → Bool) → F) (r : Fin a → F) (s : Fin b → F) : F :=
  ∑ z, ∑ j, eqPoly r (fun i => bit (z i)) * eqPoly s (fun i => bit (j i)) * P z j

/-- **A private matmul slot's true sum is the extension of the contraction at its claim point** (`SC_QMM` … `SC_DMM`,
argument.rs:2150-2190, 2299-2331): the slot sums `Ã(r, c)·W̃(c)` over the inner cube `c`, where `Ã(r, c)` is the
plane read with its row coordinates fixed at `r` (`priv_table`, `Coord::Fixed`) and `W̃(c) = Σ_j eq(s, j)·W(c, j)` the
weights folded with `eq(s, ·)` (`fold_rows_i8` / `accuracy_fold::fold`). It is `M̃(r, s)` with `M(z, j) = Σ_c A(z, c)·W(c, j)`. -/
theorem matmul_sum {a b k : ℕ} (A : (Fin a → Bool) → (Fin k → Bool) → F) (W : (Fin k → Bool) → (Fin b → Bool) → F)
    (r : Fin a → F) (s : Fin b → F) :
    ∑ c, (∑ z, eqPoly r (fun i => bit (z i)) * A z c) * (∑ j, eqPoly s (fun i => bit (j i)) * W c j)
      = mle2 (fun z j => ∑ c, A z c * W c j) r s := by
  unfold mle2
  simp_rw [Finset.sum_mul_sum, Finset.mul_sum]
  conv_lhs => rw [Finset.sum_comm]
  refine sum_congr rfl fun z _ => ?_
  conv_lhs => rw [Finset.sum_comm]
  exact sum_congr rfl fun j _ => sum_congr rfl fun c _ => by ring

/-- `mle2` is the iterated extension. -/
theorem mle2_eq {a b : ℕ} (P : (Fin a → Bool) → (Fin b → Bool) → F) (r : Fin a → F) (s : Fin b → F) :
    mle2 P r s = mleAt (fun z => mleAt (fun j => P z j) s) r := by
  unfold mle2 mleAt
  refine sum_congr rfl fun z _ => ?_
  rw [mul_sum]
  exact sum_congr rfl fun j _ => by ring

variable [Fintype F] [DecidableEq F]

/-- **The product-cube extension vanishes at a random point with density at most `b + a`**, the points drawn
`s` then `r` (any order of independent draws gives the same count). -/
theorem dens_mle2_zero {a b : ℕ} (P : (Fin a → Bool) → (Fin b → Bool) → F) (hP : ∃ z j, P z j ≠ 0) :
    Dens F (fun ω : (Fin b → F) × (Fin a → F) => mle2 P ω.2 ω.1 = 0) (b + a) := by
  classical
  obtain ⟨z₀, j₀, h₀⟩ := hP
  refine dens_prod (F := F) _ (fun s => mleAt (fun j => P z₀ j) s = 0) b a (dens_mle_zero _ ⟨j₀, h₀⟩) ?_
  intro s hs
  refine dens_mono (fun r hr => ?_) (dens_mle_zero (fun z => mleAt (fun j => P z j) s) ⟨z₀, hs⟩)
  rw [← mle2_eq]
  exact hr

/-- **A hosted identity on a product cube at its random claim point**: density at most `b + a`. -/
theorem dens_mle2Eq {a b : ℕ} (P Q : (Fin a → Bool) → (Fin b → Bool) → F) (h : ∃ z j, P z j ≠ Q z j) :
    Dens F (fun ω : (Fin b → F) × (Fin a → F) => mle2 P ω.2 ω.1 = mle2 Q ω.2 ω.1) (b + a) := by
  obtain ⟨z, j, hzj⟩ := h
  refine dens_mono (fun ω hω => ?_) (dens_mle2_zero (fun z j => P z j - Q z j) ⟨z, j, sub_ne_zero.mpr hzj⟩)
  have e : mle2 (fun z j => P z j - Q z j) ω.2 ω.1 = mle2 P ω.2 ω.1 - mle2 Q ω.2 ω.1 := by
    unfold mle2
    rw [← sum_sub_distrib]
    refine sum_congr rfl fun z _ => ?_
    rw [← sum_sub_distrib]
    exact sum_congr rfl fun j _ => by ring
  rw [e, hω, sub_self]

end Private

/-! ## The flat cube of the code and the product form -/

section Flat

variable {F : Type} [Field F]

/-- **The code's flat claim point `cat(r, s)` (`argument::cat`) and the flat cube `(row bits, column bits)`,
most-significant first**: `eq` of two appended points is the product of the `eq`s. -/
theorem eqPoly_append {a b : ℕ} (r : Fin a → F) (s : Fin b → F) (x : Fin a → F) (y : Fin b → F) :
    eqPoly (Fin.append r s) (Fin.append x y) = eqPoly r x * eqPoly s y := by
  unfold eqPoly
  rw [Fin.prod_univ_add]
  simp only [Fin.append_left, Fin.append_right]

/-- **The extension over the flat cube at a flat point is the product-cube extension** (`Fin.appendEquiv`): so the
host's `eq(p, x)` over `Dom::D`'s `lt + ld` variables reads the hosted slot's `(r_t, r_j)` exactly as `mle2` does. -/
theorem mleAt_append {a b : ℕ} (P : (Fin (a + b) → Bool) → F) (r : Fin a → F) (s : Fin b → F) :
    mleAt P (Fin.append r s) = mle2 (fun z j => P (Fin.append z j)) r s := by
  unfold mleAt mle2
  rw [← (Fin.appendEquiv (α := Bool) a b).sum_comp
      (fun x : Fin (a + b) → Bool => eqPoly (Fin.append r s) (fun i => (bit (x i) : F)) * P x),
    Fintype.sum_prod_type]
  refine sum_congr rfl fun z _ => sum_congr rfl fun j _ => ?_
  simp only [Fin.appendEquiv_apply]
  have hb : (fun i => (bit (Fin.append z j i) : F)) = Fin.append (fun i => (bit (z i) : F)) (fun i => (bit (j i) : F)) := by
    funext i
    induction i using Fin.addCases with
    | left k => simp
    | right k => simp
  rw [hb, eqPoly_append]
  rfl

end Flat

/-! ## LogUp's helper clauses -/

section Helpers

variable {F : Type} [Field F]

/-- **A single lookup's helper clause** (`helper_sum`, argument.rs:1760: `h·d − 1`, `d = α − value`) vanishes exactly when
`HelperRel`'s single relation holds. -/
theorem helperClause_single (h d : F) : h * d - 1 = 0 ↔ h * d = 1 := sub_eq_zero

/-- **A pair's helper clause** (argument.rs:1758: `h·d₁·d₂ − (d₁ + d₂)`) vanishes exactly when `HelperRel`'s pair relation
holds. -/
theorem helperClause_pair (h d₁ d₂ : F) : h * d₁ * d₂ - (d₁ + d₂) = 0 ↔ h * (d₁ * d₂) = d₁ + d₂ := by
  rw [sub_eq_zero, mul_assoc]

/-- **A table helper's clause** (`SC_TAB`, argument_accuracy.rs:779: `h·(α − t) − m`) vanishes exactly when
`HelperRel`'s table relation holds. -/
theorem helperClause_table (h t m α : F) : h * (α - t) - m = 0 ↔ h * (α - t) = m := sub_eq_zero

end Helpers

end ZK60.Sound.SlotW16
