/-
D63 lane L26 (2026-11-07), part 2: **the endpoint's column test at the unique-decoding radius, with the columns that
do not open counted as bad**: the probabilistic core of O11d for the opening `OpensU` (finding L24-1's fix).

`OpensU` asks all but at most `e` columns of the input commitment to OPEN (a verifying Merkle opening, so a leaf the
extractor can read off the prover's log). L20's `opening_knowledge_chain_pos` decodes the extracted matrix, but a
column that does not open is extracted as a default column, which may agree with the decoded codeword by accident, so
`GroupsGood` alone does not give `OpensU`. The verifier, however, checks at each of its `Q` sampled columns that the
opened column verifies (so, without an extraction failure, it is a column the extractor read) AND that it is
consistent with the proximity vector. So the column test catches the set
  `B = {j | j does not open, or Σ ρ_i U_ij ≠ enc(w)_j}`
and that is what this file counts:

* `CloseIn D e X f`: on one set of all but at most `e` columns INSIDE `X` (the columns that open), every row agrees
  with a codeword; `CloseIn.close`.
* **`closeIn_comb_prob`** (round 0): if the rows `U` are not close inside `X`, uniform weights `ρ` make `Σ ρ_i U_i`
  close inside `X` with probability at most `N/|E|` (correlated agreement when `U` is far, `A ≤ N`; when `U` is close
  to its unique table `g`, some column of the agreement set has `U_j ≠ g_j` and `ρ·(U_j − g_j) = 0`, at most `1/|E|`
  per column).
* **`closeIn_column`** (round 1): if `Σ ρ_i U_i` is not close inside `X`, then for ANY proximity vector the bad set has
  at least `e + 1` columns and `Q` uniform indices all avoid it with probability at most `((N − (e + 1))/N)^Q`.
* `xASt`, **`xA_rbrWide`**, `xBSt`, **`xB_rbrWide`**: the two rounds as round-by-round sound states on digests;
  `xACSub`, `xBCSub`, **`xACSub_rbr`**, **`xBCSub_rbr`**: on the code's chain at the windows of the opening's two
  halves (`opA`'s `(λ, ρ)` squeezes and `opB`'s index squeezes, L10-3's split), `opB`'s `ρ` read off its header;
  **`x_split`** (deterministic, as L20's `opening_split`);
* **`openX_chain_pos`**: on the code's chain, for any extraction of the matrix and of the openable set from the
  prover's log: the probability that the test's first half enters with the matrix NOT close inside the openable set
  while its second half is alive at the end is at most `(q·εA + εA + coll) + (q·εB + εB + coll)`,
  `εA = N/|F|·βLR`, `εB = ((N − (e + 1))/N)^Q·βJ`;
* the numbers: `w16r2_open_code_factsU` / `r13_open_code_factsU` (the code facts at the radii `8052` and `24,448`, with
  `A = N`), `xA_eps_w16r2` (`≤ 2^-111`), `xA_eps_r13` (`≤ 2^-110`), `xB_eps_w16r2` (`≤ 2^-113`), `xB_eps_r13`
  (`≤ 2^-172`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.OpenKnowChain
import ZK60Formal.OpeningR13

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Sound Code Prob Finset
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## Close on a set of columns that open -/

section CloseInSec

variable {E ι κ : Type} [Field E] [Fintype ι]

/-- **Close inside `X`**: on one common set of all but at most `e` columns, all of them in `X` (the columns that open),
every row agrees with a word of the code `D`. -/
def CloseIn {R : Type} (D : Submodule E (ι → E)) (e : ℕ) (X : Finset ι) (f : R → ι → E) : Prop :=
  ∃ S : Finset ι, S ⊆ X ∧ Fintype.card ι ≤ S.card + e ∧ ∀ a, f a ∈ agreeOn D S

/-- Close inside `X` is close. -/
theorem CloseIn.close {R : Type} {D : Submodule E (ι → E)} {e : ℕ} {X : Finset ι} {f : R → ι → E}
    (h : CloseIn D e X f) : Close D e f := by
  obtain ⟨S, -, hS, hf⟩ := h
  exact ⟨S, hS, hf⟩

/-- **Round 0, with the columns that open** (D63 lane L26). Let the code have minimum distance `d`, `2e < d`, and
correlated agreement on lines with at most `A ≤ N` exceptions. If the rows `U` are not close inside `X`, uniform
weights `ρ` make `Σ_i ρ_i·U_i` close inside `X` with probability at most `N/|E|`. -/
theorem closeIn_comb_prob [Fintype E] [Fintype κ] [DecidableEq κ] {D : Submodule E (ι → E)} {d e A : ℕ}
    (hd : MinDist D d) (h2 : 2 * e < d) (hA : e + 1 ≤ A) (hAN : A ≤ Fintype.card ι) (hca : CAOn Unit D e A)
    (U : κ → ι → E) (X : Finset ι) (hfar : ¬ CloseIn D e X U) :
    (PMF.uniformOfFintype (κ → E)).toOuterMeasure {r | CloseIn D e X (fun _ : Unit => comb U r)}
      ≤ (Fintype.card ι : ℝ≥0∞) / Fintype.card E := by
  classical
  by_cases hc : Close D e U
  · obtain ⟨g, S₀, hg, hS₀, hUg⟩ := hc.exists_table
    have hsub : {r : κ → E | CloseIn D e X (fun _ : Unit => comb U r)}
        ⊆ ⋃ j : ι, {r : κ → E | (∃ i, U i j - g i j ≠ 0) ∧ ∑ i, r i * (U i j - g i j) = 0} := by
      intro r hr
      obtain ⟨S, hSX, hS, hagr⟩ := hr
      obtain ⟨u, hu, hUu⟩ := mem_agreeOn.mp (hagr ())
      have hgc : comb g r ∈ D := by
        unfold comb
        exact Submodule.sum_mem _ (fun i _ => Submodule.smul_mem _ _ (hg i))
      have hcg : ∀ j ∈ S₀, comb U r j = comb g r j := by
        intro j hj
        rw [comb_apply, comb_apply]
        exact sum_congr rfl (fun i _ => by rw [hUg j hj i])
      have hug : u = comb g r := hd.decode_unique h2 hu hgc hS hS₀ hUu hcg
      by_contra hno
      apply hfar
      refine ⟨S, hSX, hS, fun i => mem_agreeOn.mpr ⟨g i, hg i, fun j hj => ?_⟩⟩
      have h1 : comb U r j = comb g r j := (hUu j hj).trans (congrFun hug j)
      have hz : ∑ i', r i' * (U i' j - g i' j) = 0 := by
        rw [comb_apply, comb_apply] at h1
        simp only [mul_sub, sum_sub_distrib, h1, sub_self]
      by_contra hne
      exact hno (Set.mem_iUnion.mpr ⟨j, ⟨⟨i, sub_ne_zero.mpr hne⟩, hz⟩⟩)
    refine (MeasureTheory.measure_mono hsub).trans ((MeasureTheory.measure_iUnion_fintype_le _ _).trans ?_)
    calc ∑ j : ι, (PMF.uniformOfFintype (κ → E)).toOuterMeasure
          {r : κ → E | (∃ i, U i j - g i j ≠ 0) ∧ ∑ i, r i * (U i j - g i j) = 0}
        ≤ ∑ _j : ι, (1 : ℝ≥0∞) / Fintype.card E := by
          refine sum_le_sum (fun j _ => ?_)
          by_cases hj : ∃ i, U i j - g i j ≠ 0
          · have hsub2 : {r : κ → E | (∃ i, U i j - g i j ≠ 0) ∧ ∑ i, r i * (U i j - g i j) = 0}
                ⊆ {r : κ → E | ∑ k, r k * (fun i => U i j - g i j) k = 0} := fun r hr => hr.2
            exact (MeasureTheory.measure_mono hsub2).trans (batch_prob (fun i => U i j - g i j) hj)
          · refine le_trans (le_of_eq ?_) zero_le
            refine MeasureTheory.measure_mono_null (fun r hr => ?_) MeasureTheory.measure_empty
            exact absurd hr.1 hj
      _ = (Fintype.card ι : ℝ≥0∞) / Fintype.card E := by
          rw [sum_const, card_univ, nsmul_eq_mul, mul_one_div]
  · have hsub : {r : κ → E | CloseIn D e X (fun _ : Unit => comb U r)}
        ⊆ {r : κ → E | Close D e (fun _ : Unit => comb U r)} := fun r hr => CloseIn.close hr
    refine (MeasureTheory.measure_mono hsub).trans ?_
    exact (comb_close_prob hd h2 hA hca U hc).trans (ENNReal.div_le_div_right (by exact_mod_cast hAN) _)

/-- **Round 1, with the columns that open** (D63 lane L26). If `Σ_i ρ_i·U_i` is not close inside `X`, then for any
codeword `w` (the re-encoded proximity vector) the bad set `{j | j ∉ X ∨ w_j ≠ (Σ ρ_i U_i)_j}` has at least `e + 1`
columns, and `Q` uniform indices all land in `X` with `w` consistent with probability at most
`((N − (e + 1))/N)^Q`. -/
theorem closeIn_column [DecidableEq ι] [Nonempty ι] [Fintype κ] {D : Submodule E (ι → E)} {e : ℕ}
    (U : κ → ι → E) (X : Finset ι) (ρ : κ → E) (w : ι → E) (hw : w ∈ D)
    (hfar : ¬ CloseIn D e X (fun _ : Unit => comb U ρ)) (Q : ℕ) :
    (PMF.uniformOfFintype (Fin Q → ι)).toOuterMeasure {J | ∀ k, J k ∈ X ∧ w (J k) = comb U ρ (J k)}
      ≤ (((Fintype.card ι - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q := by
  classical
  set B : Finset ι := univ.filter (fun j => j ∉ X ∨ w j ≠ comb U ρ j) with hB
  have hcard : e + 1 ≤ B.card := by
    by_contra hlt
    apply hfar
    refine ⟨Bᶜ, fun j hj => ?_, ?_, fun _ => mem_agreeOn.mpr ⟨w, hw, fun j hj => ?_⟩⟩
    · have h' : ¬ (j ∉ X ∨ w j ≠ comb U ρ j) := fun h => (mem_compl.mp hj) (mem_filter.mpr ⟨mem_univ j, h⟩)
      exact not_not.mp (not_or.mp h').1
    · rw [card_compl]
      have := card_le_univ B
      omega
    · have h' : ¬ (j ∉ X ∨ w j ≠ comb U ρ j) := fun h => (mem_compl.mp hj) (mem_filter.mpr ⟨mem_univ j, h⟩)
      exact (not_not.mp (not_or.mp h').2).symm
  have hset : {J : Fin Q → ι | ∀ k, J k ∈ X ∧ w (J k) = comb U ρ (J k)} = {J | ∀ k, J k ∉ B} := by
    ext J
    simp only [Set.mem_ofPred_eq, hB, mem_filter, mem_univ, true_and, not_or, not_not, ne_eq]
  rw [hset, column_miss_prob]
  gcongr

end CloseInSec

/-! ## The two rounds as round-by-round sound states -/

section XRounds

variable {F κ μ Cl : Type} [Field F] {X Mm : Type} {h : ℕ}

/-- **The column test's round 0** (the opening's `(λ, ρ)` squeezes): before, the extracted rows are close inside the
openable set; after, they are, or `Σ ρ_i U_i` is. -/
def xASt [Fintype κ] (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ) (Ux : X → κ → Fin (2 ^ h) → F)
    (Xx : X → Finset (Fin (2 ^ h))) (d₀ : Dg) (w0 : ℕ) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (x : X) :
    List (Mm × List Dg) → Prop
  | [(_, ds)] => CloseIn (LinearMap.range enc) e (Xx x) (Ux x)
      ∨ CloseIn (LinearMap.range enc) e (Xx x) (fun _ : Unit => comb (Ux x) (chalLR (vecOf d₀ w0 ds)).2)
  | _ => CloseIn (LinearMap.range enc) e (Xx x) (Ux x)

/-- **Round 0 is round-by-round sound**: from rows not close inside the openable set, the `(λ, ρ)` draw (through any
derivation with bias `βLR`) keeps the state alive with probability at most `N/|F|·βLR`. -/
theorem xA_rbrWide [Fintype F] [Fintype κ] [DecidableEq κ] [Fintype Cl] [DecidableEq Cl]
    (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) {d e A : ℕ} (hd : MinDist (LinearMap.range enc) d) (h2 : 2 * e < d)
    (hA : e + 1 ≤ A) (hAN : A ≤ 2 ^ h) (hca : CAOn Unit (LinearMap.range enc) e A) (Ux : X → κ → Fin (2 ^ h) → F)
    (Xx : X → Finset (Fin (2 ^ h))) (d₀ : Dg) (w0 : ℕ) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (βLR : ℝ≥0∞)
    (hLR : ∀ Ev : (Cl → F) × (κ → F) → Prop, (PMF.uniformOfFintype (Fin w0 → Dg)).toOuterMeasure {b | Ev (chalLR b)}
      ≤ (PMF.uniformOfFintype ((Cl → F) × (κ → F))).toOuterMeasure {y | Ev y} * βLR) :
    RbrWide (M := Mm) 1 (fun _ => w0) (xASt enc e Ux Xx d₀ w0 chalLR)
      (((2 ^ h : ℕ) : ℝ≥0∞) / Fintype.card F * βLR) where
  round x τ msg hτ hns := by
    obtain rfl : τ = [] := List.eq_nil_of_length_eq_zero (by omega)
    have hfar : ¬ CloseIn (LinearMap.range enc) e (Xx x) (Ux x) := hns
    have hset : {b : Fin w0 → Dg | xASt enc e Ux Xx d₀ w0 chalLR x ([] ++ [(msg, List.ofFn b)])}
        = {b | (fun y : (Cl → F) × (κ → F) => CloseIn (LinearMap.range enc) e (Xx x) (Ux x)
            ∨ CloseIn (LinearMap.range enc) e (Xx x) (fun _ : Unit => comb (Ux x) y.2)) (chalLR b)} := by
      ext b
      simp only [Set.mem_ofPred_eq, List.nil_append, xASt, vecOf_ofFn]
    show (PMF.uniformOfFintype (Fin w0 → Dg)).toOuterMeasure
      {b | xASt enc e Ux Xx d₀ w0 chalLR x ([] ++ [(msg, List.ofFn b)])} ≤ _
    rw [hset]
    refine (hLR (fun y : (Cl → F) × (κ → F) => CloseIn (LinearMap.range enc) e (Xx x) (Ux x)
      ∨ CloseIn (LinearMap.range enc) e (Xx x) (fun _ : Unit => comb (Ux x) y.2))).trans (mul_le_mul' ?_ le_rfl)
    have hsub : {y : (Cl → F) × (κ → F) | CloseIn (LinearMap.range enc) e (Xx x) (Ux x)
          ∨ CloseIn (LinearMap.range enc) e (Xx x) (fun _ : Unit => comb (Ux x) y.2)}
        ⊆ {y | CloseIn (LinearMap.range enc) e (Xx x) (fun _ : Unit => comb (Ux x) y.2)} :=
      fun y hy => hy.resolve_left hfar
    refine (MeasureTheory.measure_mono hsub).trans ?_
    refine prob_prod_le_of_forall_fst
      (fun y : (Cl → F) × (κ → F) => CloseIn (LinearMap.range enc) e (Xx x) (fun _ : Unit => comb (Ux x) y.2)) _
      (fun _ => ?_)
    have h0 := closeIn_comb_prob hd h2 hA (by rw [Fintype.card_fin]; exact hAN) hca (Ux x) (Xx x) hfar
    rw [Fintype.card_fin] at h0
    exact h0

/-- **The column test's round 1** (the index squeezes), its window after the group vectors: its statement gives the
matrix, the openable set and `ρ` (`rOf`, read off the header); its message is the proximity vector (`none`:
malformed). Before, round 0's alive state; after, every sampled column is in the openable set and consistent with the
proximity vector. -/
def xBSt [Fintype κ] (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ) (Ux : X → κ → Fin (2 ^ h) → F)
    (Xx : X → Finset (Fin (2 ^ h))) (rOf : X → κ → F) (d₀ : Dg) (m : ℕ) {nQ : ℕ}
    (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (x : X) : List (Option (μ → F) × List Dg) → Prop
  | [(w, ds)] => ∃ wv, w = some wv ∧ ∀ k, chalJ (vecOf d₀ m ds) k ∈ Xx x
      ∧ enc wv (chalJ (vecOf d₀ m ds) k) = comb (Ux x) (rOf x) (chalJ (vecOf d₀ m ds) k)
  | _ => CloseIn (LinearMap.range enc) e (Xx x) (Ux x)
      ∨ CloseIn (LinearMap.range enc) e (Xx x) (fun _ : Unit => comb (Ux x) (rOf x))

/-- **Round 1 is round-by-round sound**: from a doomed round 0, whatever proximity vector the prover sends, the index
draw (through any derivation with bias `βJ`) keeps the state alive with probability at most
`((N − (e + 1))/N)^Q·βJ`. -/
theorem xB_rbrWide [Fintype κ] (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ) (Ux : X → κ → Fin (2 ^ h) → F)
    (Xx : X → Finset (Fin (2 ^ h))) (rOf : X → κ → F) (d₀ : Dg) (m : ℕ) {nQ : ℕ}
    (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (βJ : ℝ≥0∞)
    (hJ : ∀ Ev : (Fin nQ → Fin (2 ^ h)) → Prop, (PMF.uniformOfFintype (Fin m → Dg)).toOuterMeasure {b | Ev (chalJ b)}
      ≤ (PMF.uniformOfFintype (Fin nQ → Fin (2 ^ h))).toOuterMeasure {J | Ev J} * βJ) :
    RbrWide 1 (fun _ => m) (xBSt enc e Ux Xx rOf d₀ m chalJ)
      ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ) where
  round x τ msg hτ hns := by
    obtain rfl : τ = [] := List.eq_nil_of_length_eq_zero (by omega)
    show (PMF.uniformOfFintype (Fin m → Dg)).toOuterMeasure
      {b | xBSt enc e Ux Xx rOf d₀ m chalJ x ([] ++ [(msg, List.ofFn b)])} ≤ _
    rcases msg with _ | wv
    · refine le_trans (le_of_eq ?_) zero_le
      rw [show {b : Fin m → Dg | xBSt enc e Ux Xx rOf d₀ m chalJ x ([] ++ [(none, List.ofFn b)])} = ∅ by
        ext b
        simp [xBSt]]
      exact MeasureTheory.measure_empty
    · have hset : {b : Fin m → Dg | xBSt enc e Ux Xx rOf d₀ m chalJ x ([] ++ [(some wv, List.ofFn b)])}
          = {b | (fun J : Fin nQ → Fin (2 ^ h) => ∀ k, J k ∈ Xx x ∧ enc wv (J k) = comb (Ux x) (rOf x) (J k))
              (chalJ b)} := by
        ext b
        simp [xBSt, vecOf_ofFn]
      rw [hset]
      have hfar : ¬ CloseIn (LinearMap.range enc) e (Xx x) (fun _ : Unit => comb (Ux x) (rOf x)) :=
        fun h' => hns (Or.inr h')
      exact (hJ _).trans (mul_le_mul' (closeIn_column (Ux x) (Xx x) (rOf x) (enc wv)
        (LinearMap.mem_range_self enc wv) hfar nQ) le_rfl)

end XRounds

/-! ## The two halves on the code's chain -/

section XChain

variable {F κ μ Cl : Type} [Field F] {h : ℕ}

/-- A header together with the matrix and the openable set extracted for it. -/
abbrev HdrXU (κ F : Type) (h : ℕ) := List (TItem × Dig) × ((κ → Fin (2 ^ h) → F) × Finset (Fin (2 ^ h)))

/-- **The test's first half on the code's chain**, at `opA`'s window `aA` (the `(λ, ρ)` squeezes), its matrix and its
openable set the extracted ones (`Ux hdr`, `Xx hdr`; both may read the prover's log). -/
noncomputable def xACSub [Fintype κ] (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (Ux : List (TItem × Dig) → κ → Fin (2 ^ h) → F) (Xx : List (TItem × Dig) → Finset (Fin (2 ^ h))) (d₀ : Dg)
    (w0 : ℕ) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (aA : ℕ) (εA : ℝ≥0∞) : CSub Dig :=
  toCSub aA (opARounds w0) εA
    (xASt (Mm := Unit) enc e (fun x : HdrXU κ F h => x.2.1) (fun x : HdrXU κ F h => x.2.2) d₀ w0 chalLR)
    (fun hdr => (hdr, (Ux hdr, Xx hdr))) (fun _ => ()) (fun _ => False)

/-- **The test's second half's state**: `opA`'s round is complete in the header, and `xBSt` with the matrix and the
openable set at `opA`'s window and `ρ` read off the header by `opA`'s reader. -/
def xBSt' [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype Cl] [DecidableEq Cl] (W : UInt64 → ℕ)
    (aA w0 : ℕ) (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ) (d₀ : Dg)
    (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (m : ℕ) {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h)))
    (x : HdrXU κ F h) (τ : List (Option (μ → F) × List Dg)) : Prop :=
  (opARead W aA w0 x.1).isSome = true ∧ xBSt enc e (fun y : HdrXU κ F h => y.2.1) (fun y => y.2.2)
    (fun y => (opBLR W aA w0 d₀ chalLR y.1).2) d₀ m chalJ x τ

/-- **The test's second half on the code's chain**, at `opB`'s window `aB` (after the group vectors), its message the
proximity vector decoded by `decB`. -/
noncomputable def xBCSub [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype Cl] [DecidableEq Cl]
    (W : UInt64 → ℕ) (aA w0 : ℕ) (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (Ux : List (TItem × Dig) → κ → Fin (2 ^ h) → F) (Xx : List (TItem × Dig) → Finset (Fin (2 ^ h))) (d₀ : Dg)
    (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (m : ℕ) {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h)))
    (labB : List UInt8) (decB : List UInt8 → Option (μ → F)) (aB : ℕ) (εB : ℝ≥0∞) : CSub Dig :=
  toCSub aB (opBRounds labB m) εB (xBSt' W aA w0 enc e d₀ chalLR m chalJ)
    (fun hdr => (hdr, (Ux (hdr.take aA), Xx (hdr.take aA)))) decB (fun _ => False)

/-- The first half is round-by-round sound on the code's chain (`xA_rbrWide`, `rbrWide_toCode`). -/
theorem xACSub_rbr [Fintype F] [Fintype κ] [DecidableEq κ] [Fintype Cl] [DecidableEq Cl]
    (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) {d e A : ℕ} (hd : MinDist (LinearMap.range enc) d) (h2 : 2 * e < d)
    (hA : e + 1 ≤ A) (hAN : A ≤ 2 ^ h) (hca : CAOn Unit (LinearMap.range enc) e A)
    (Ux : List (TItem × Dig) → κ → Fin (2 ^ h) → F) (Xx : List (TItem × Dig) → Finset (Fin (2 ^ h))) (d₀ : Dg)
    (w0 : ℕ) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (βLR : ℝ≥0∞)
    (hLR : ∀ Ev : (Cl → F) × (κ → F) → Prop, (PMF.uniformOfFintype (Fin w0 → Dg)).toOuterMeasure {b | Ev (chalLR b)}
      ≤ (PMF.uniformOfFintype ((Cl → F) × (κ → F))).toOuterMeasure {y | Ev y} * βLR) (aA : ℕ) :
    RbrWide (xACSub enc e Ux Xx d₀ w0 chalLR aA (((2 ^ h : ℕ) : ℝ≥0∞) / Fintype.card F * βLR)).R.n
      (xACSub enc e Ux Xx d₀ w0 chalLR aA (((2 ^ h : ℕ) : ℝ≥0∞) / Fintype.card F * βLR)).R.w
      (xACSub enc e Ux Xx d₀ w0 chalLR aA (((2 ^ h : ℕ) : ℝ≥0∞) / Fintype.card F * βLR)).St
      (xACSub enc e Ux Xx d₀ w0 chalLR aA (((2 ^ h : ℕ) : ℝ≥0∞) / Fintype.card F * βLR)).ε :=
  rbrWide_toCode aA (opARounds w0) _ _ _ _ _
    (xA_rbrWide (Mm := Unit) enc hd h2 hA hAN hca (fun x : HdrXU κ F h => x.2.1) (fun x : HdrXU κ F h => x.2.2) d₀
      w0 chalLR βLR hLR)

/-- The second half is round-by-round sound on the code's chain (`xB_rbrWide`, guarded by `opA`'s completed round). -/
theorem xBCSub_rbr [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype Cl] [DecidableEq Cl]
    (W : UInt64 → ℕ) (aA w0 : ℕ) (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (Ux : List (TItem × Dig) → κ → Fin (2 ^ h) → F) (Xx : List (TItem × Dig) → Finset (Fin (2 ^ h))) (d₀ : Dg)
    (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (m : ℕ) {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h)))
    (βJ : ℝ≥0∞)
    (hJ : ∀ Ev : (Fin nQ → Fin (2 ^ h)) → Prop, (PMF.uniformOfFintype (Fin m → Dg)).toOuterMeasure {b | Ev (chalJ b)}
      ≤ (PMF.uniformOfFintype (Fin nQ → Fin (2 ^ h))).toOuterMeasure {J | Ev J} * βJ)
    (labB : List UInt8) (decB : List UInt8 → Option (μ → F)) (aB : ℕ) :
    RbrWide (xBCSub W aA w0 enc e Ux Xx d₀ chalLR m chalJ labB decB aB
        ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ)).R.n
      (xBCSub W aA w0 enc e Ux Xx d₀ chalLR m chalJ labB decB aB
        ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ)).R.w
      (xBCSub W aA w0 enc e Ux Xx d₀ chalLR m chalJ labB decB aB
        ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ)).St
      (xBCSub W aA w0 enc e Ux Xx d₀ chalLR m chalJ labB decB aB
        ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ)).ε :=
  rbrWide_toCode aB (opBRounds labB m) _ _ _ _ _
    (RbrWide.and_left (fun x : HdrXU κ F h => (opARead W aA w0 x.1).isSome = true)
      (xB_rbrWide enc e (fun y : HdrXU κ F h => y.2.1) (fun y => y.2.2) (fun y => (opBLR W aA w0 d₀ chalLR y.1).2)
        d₀ m chalJ βJ hJ))

/-- **The test's split** (deterministic; as L20's `opening_split`). If the first half's window is at a step's end and
the second half's window lies in the chain, then the first half is alive at the end of the chain, or the second half
enters its window doomed: when the second half's header state holds, `opA`'s round is complete in that header,
frozen, and its `ρ` is the one the second half reads. -/
theorem x_split [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype Cl] [DecidableEq Cl]
    (W : UInt64 → ℕ) (aA aB : ℕ) (hab : aA ≤ aB) (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (Ux : List (TItem × Dig) → κ → Fin (2 ^ h) → F) (Xx : List (TItem × Dig) → Finset (Fin (2 ^ h))) (d₀ : Dg)
    (w0 : ℕ) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (m : ℕ) {nQ : ℕ}
    (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (labB : List UInt8) (decB : List UInt8 → Option (μ → F))
    (εA εB : ℝ≥0∞) (τ : List (TItem × Dig)) (hA1 : tRem W (τ.take aA) = some 0) (hB0 : aB ≤ τ.length) :
    subSt W (xACSub enc e Ux Xx d₀ w0 chalLR aA εA) τ
      ∨ ¬ (xBCSub W aA w0 enc e Ux Xx d₀ chalLR m chalJ labB decB aB εB).St (τ.take aB) [] := by
  by_cases hBst : (xBCSub W aA w0 enc e Ux Xx d₀ chalLR m chalJ labB decB aB εB).St (τ.take aB) []
  · left
    obtain ⟨hsome, hal1⟩ : (opARead W aA w0 (τ.take aB)).isSome = true ∧ _ := hBst
    obtain ⟨ds, hds⟩ := Option.isSome_iff_exists.mp hsome
    obtain ⟨x, pm, ds', hrd⟩ := opARead_some hds
    have hsplit : τ.drop aA = (τ.take aB).drop aA ++ τ.drop aB := by
      conv_lhs => rw [← List.take_append_drop aB τ]
      rw [List.drop_append_of_le_length (by rw [List.length_take]; omega)]
    have hfull : cRd (opARounds w0) W (τ.drop aA) = some ([(x, ds)], pm, ds') := by
      rw [hsplit, cRd, List.foldl_append]
      have h0 : List.foldl (cRdStep (opARounds w0) W) (some ([], none, [])) ((τ.take aB).drop aA)
          = some ([(x, ds)], pm, ds') := hrd
      rw [h0]
      exact foldl_cRdStep_frozen (opARounds w0) W (show (opARounds w0).n ≤ [(x, ds)].length from le_rfl) _
    have htt : (τ.take aB).take aA = τ.take aA := by
      rw [List.take_take, min_eq_left hab]
    right
    left
    refine ⟨hA1, ?_⟩
    have hlr : opBLR W aA w0 d₀ chalLR (τ.take aB) = chalLR (vecOf d₀ w0 (ds.map halves)) := by
      unfold opBLR
      rw [hds]
      rfl
    show liftC (fun τr => xASt (Mm := Unit) enc e (fun x : HdrXU κ F h => x.2.1) (fun x : HdrXU κ F h => x.2.2) d₀
      w0 chalLR (τ.take aA, (Ux (τ.take aA), Xx (τ.take aA))) (τr.map (fun p => ((), p.2.map halves))))
      (cRd (opARounds w0) W (τ.drop aA))
    rw [hfull]
    show CloseIn (LinearMap.range enc) e (Xx (τ.take aA)) (Ux (τ.take aA))
      ∨ CloseIn (LinearMap.range enc) e (Xx (τ.take aA))
          (fun _ : Unit => comb (Ux (τ.take aA)) (chalLR (vecOf d₀ w0 (ds.map halves))).2)
    have hal1' : CloseIn (LinearMap.range enc) e (Xx ((τ.take aB).take aA)) (Ux ((τ.take aB).take aA))
        ∨ CloseIn (LinearMap.range enc) e (Xx ((τ.take aB).take aA))
          (fun _ : Unit => comb (Ux ((τ.take aB).take aA)) (opBLR W aA w0 d₀ chalLR (τ.take aB)).2) := hal1
    rw [htt, hlr] at hal1'
    exact hal1'
  · right
    exact hBst

variable {L : ℕ}

/-- The first half's one-sub-protocol schedule at the prover's log recovered from a log. -/
noncomputable def xACsAt [Fintype κ] (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (Ux : List (QB L × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (Xx : List (QB L × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h))) (d₀ : Dg) (w0 : ℕ)
    (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (aA : ℕ) (εA : ℝ≥0∞) {α : Type} (Pv : OC (QB L) Dig α)
    (P : List (QB L × Dig)) : List (CSub Dig) :=
  [xACSub enc e (Ux (proverLog Pv P)) (Xx (proverLog Pv P)) d₀ w0 chalLR aA εA]

/-- The second half's one-sub-protocol schedule at the prover's log recovered from a log. -/
noncomputable def xBCsAt [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype Cl] [DecidableEq Cl]
    (W : UInt64 → ℕ) (aA w0 : ℕ) (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (Ux : List (QB L × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (Xx : List (QB L × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h))) (d₀ : Dg)
    (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (m : ℕ) {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h)))
    (labB : List UInt8) (decB : List UInt8 → Option (μ → F)) (aB : ℕ) (εB : ℝ≥0∞) {α : Type}
    (Pv : OC (QB L) Dig α) (P : List (QB L × Dig)) : List (CSub Dig) :=
  [xBCSub W aA w0 enc e (Ux (proverLog Pv P)) (Xx (proverLog Pv P)) d₀ chalLR m chalJ labB decB aB εB]

/-- **The endpoint's column test on the code's chain, with the per-position count** (D63 lane L26). For any extraction
`Ux` of the opening's matrix and `Xx` of the set of columns that open from the prover's log (frozen once the chain's
first `s` entries are logged, `hUx`), the first half's window at `aA > s` and the second half's at `aB ≥ aA`: the
probability that the first half's window is at a step's end with the matrix NOT close inside the openable set, while
the second half's window is at a step's end and the second half is alive at the end (every sampled column opens and is
consistent with the proximity vector), is at most `(q·εA + εA + coll) + (q·εB + εB + coll)`, `εA = N/|F|·βLR`,
`εB = ((N − (e + 1))/N)^Q·βJ`. -/
theorem openX_chain_pos [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype Cl] [DecidableEq Cl]
    (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) {d e A : ℕ} (hd : MinDist (LinearMap.range enc) d) (h2 : 2 * e < d)
    (hA : e + 1 ≤ A) (hAN : A ≤ 2 ^ h) (hca : CAOn Unit (LinearMap.range enc) e A)
    (Ux : List (QB L × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (Xx : List (QB L × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h))) (d₀ : Dg) (w0 : ℕ)
    (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (βLR : ℝ≥0∞)
    (hLR : ∀ Ev : (Cl → F) × (κ → F) → Prop, (PMF.uniformOfFintype (Fin w0 → Dg)).toOuterMeasure {b | Ev (chalLR b)}
      ≤ (PMF.uniformOfFintype ((Cl → F) × (κ → F))).toOuterMeasure {y | Ev y} * βLR)
    (m : ℕ) {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (βJ : ℝ≥0∞)
    (hJ : ∀ Ev : (Fin nQ → Fin (2 ^ h)) → Prop, (PMF.uniformOfFintype (Fin m → Dg)).toOuterMeasure {b | Ev (chalJ b)}
      ≤ (PMF.uniformOfFintype (Fin nQ → Fin (2 ^ h))).toOuterMeasure {J | Ev J} * βJ)
    (labB : List UInt8) (decB : List UInt8 → Option (μ → F)) (aA aB : ℕ) (hab : aA ≤ aB)
    (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) {It' : Type} (C : ChainEnc It' (QB L) Dig)
    (toT : It' → TItem) (St : Steps It') (hS : StepsOK W toT St) {α : Type} (heads : α → List It') (ℓ : ℕ)
    (hℓ : ∀ o, ((heads o).flatMap St.items).length ≤ ℓ) (s : ℕ) (hsa : s < aA)
    (hhd : ∀ o, (((heads o).take s).flatMap St.items).length ≤ s) (q : ℕ) (Pv : OC (QB L) Dig α) (hPv : Pv.Bounded q)
    (hUx : ∀ (H : QB L → Dig) (P P' : List (QB L × Dig)) (τ : List (It' × Dig)) (qs : List (QB L)),
      C.Chain H τ qs → τ.length = s → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' → (∀ e ∈ P', e.2 = H e.1) →
        ∀ ext : List (TItem × Dig), Ux (proverLog Pv P) ((τ.map (toTE toT) ++ ext).take aA)
          = Ux (proverLog Pv P') ((τ.map (toTE toT) ++ ext).take aA)
          ∧ Xx (proverLog Pv P) ((τ.map (toTE toT) ++ ext).take aA)
            = Xx (proverLog Pv P') ((τ.map (toTE toT) ++ ext).take aA)) :
    prH (fun H => tRem W ((cChain C toT St H (heads (Pv.run H))).take aA) = some 0
          ∧ ¬ CloseIn (LinearMap.range enc) e
              (Xx (Pv.runLog H).2 ((cChain C toT St H (heads (Pv.run H))).take aA))
              (Ux (Pv.runLog H).2 ((cChain C toT St H (heads (Pv.run H))).take aA))
          ∧ aB ≤ (cChain C toT St H (heads (Pv.run H))).length
          ∧ tRem W ((cChain C toT St H (heads (Pv.run H))).take aB) = some 0
          ∧ subSt W (xBCSub W aA w0 enc e (Ux (Pv.runLog H).2) (Xx (Pv.runLog H).2) d₀ chalLR m chalJ labB decB aB
              ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ))
            (cChain C toT St H (heads (Pv.run H))))
      ≤ ((q : ℝ≥0∞) * (((2 ^ h : ℕ) : ℝ≥0∞) / Fintype.card F * βLR) + ((2 ^ h : ℕ) : ℝ≥0∞) / Fintype.card F * βLR
          + collBound (q + ℓ + 1) Dig + collBound (q + ℓ + 1 + 1) Dig)
        + ((q : ℝ≥0∞) * ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ)
          + (((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ
          + collBound (q + ℓ + 1) Dig + collBound (q + ℓ + 1 + 1) Dig) := by
  set εA : ℝ≥0∞ := ((2 ^ h : ℕ) : ℝ≥0∞) / Fintype.card F * βLR with hεA
  set εB : ℝ≥0∞ := (((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ
    with hεB
  have hfull : ∀ H, proverLog Pv ((C.stepRun St heads Pv).runLog H).2 = (Pv.runLog H).2 := fun H => by
    rw [ChainEnc.stepRun, OC.runLog_bind]
    exact proverLog_runLog Pv H _
  have hmA : ∀ P c, c ∈ xACsAt enc e Ux Xx d₀ w0 chalLR aA εA Pv P →
      c = xACSub enc e (Ux (proverLog Pv P)) (Xx (proverLog Pv P)) d₀ w0 chalLR aA εA :=
    fun P c hc => List.mem_singleton.mp hc
  have hmB : ∀ P c, c ∈ xBCsAt W aA w0 enc e Ux Xx d₀ chalLR m chalJ labB decB aB εB Pv P →
      c = xBCSub W aA w0 enc e (Ux (proverLog Pv P)) (Xx (proverLog Pv P)) d₀ chalLR m chalJ labB decB aB εB :=
    fun P c hc => List.mem_singleton.mp hc
  have hA' := fs_code_chain_sound_sched_log_pos W hW (xACsAt enc e Ux Xx d₀ w0 chalLR aA εA Pv)
    [(xACSub enc e (Ux []) (Xx []) d₀ w0 chalLR aA εA).sk] (fun _ => rfl) εA
    (fun P c hc => by
      rw [hmA P c hc]
      exact xACSub_rbr enc hd h2 hA hAN hca _ _ d₀ w0 chalLR βLR hLR aA)
    (fun P c hc => by
      rw [hmA P c hc]
      exact le_rfl)
    (fun P k' c τ h ks ds hc _ _ _ _ hrel => by
      have hc' := hmA P c (List.mem_of_getElem? hc)
      rw [hc'] at hrel
      exact absurd hrel id)
    C toT St hS heads ℓ hℓ s
    (fun P c hc => by
      rw [hmA P c hc]
      exact hsa) hhd
    (fun H P P' τ qs hc hl hq hpre hans ext => by
      rw [xACsAt, xACsAt, allSt_singleton, allSt_singleton]
      refine subSt_congr W _ _ _ rfl rfl Iff.rfl ?_
      obtain ⟨he1, he2⟩ := hUx H P P' τ qs hc hl hq hpre hans ext
      simp only [xACSub, toCSub, he1, he2]) q Pv hPv
  have hB' := fs_code_chain_sound_sched_log_pos W hW
    (xBCsAt W aA w0 enc e Ux Xx d₀ chalLR m chalJ labB decB aB εB Pv)
    [(xBCSub W aA w0 enc e (Ux []) (Xx []) d₀ chalLR m chalJ labB decB aB εB).sk] (fun _ => rfl) εB
    (fun P c hc => by
      rw [hmB P c hc]
      exact xBCSub_rbr W aA w0 enc e _ _ d₀ chalLR m chalJ βJ hJ labB decB aB)
    (fun P c hc => by
      rw [hmB P c hc]
      exact le_rfl)
    (fun P k' c τ h ks ds hc _ _ _ _ hrel => by
      have hc' := hmB P c (List.mem_of_getElem? hc)
      rw [hc'] at hrel
      exact absurd hrel id)
    C toT St hS heads ℓ hℓ s
    (fun P c hc => by
      rw [hmB P c hc]
      exact lt_of_lt_of_le hsa hab) hhd
    (fun H P P' τ qs hc hl hq hpre hans ext => by
      rw [xBCsAt, xBCsAt, allSt_singleton, allSt_singleton]
      refine subSt_congr W _ _ _ rfl rfl Iff.rfl ?_
      obtain ⟨he1, he2⟩ := hUx H P P' τ qs hc hl hq hpre hans ext
      have htt : ((τ.map (toTE toT) ++ ext).take aB).take aA = (τ.map (toTE toT) ++ ext).take aA := by
        rw [List.take_take, min_eq_left hab]
      simp only [xBCSub, toCSub, htt, he1, he2]) q Pv hPv
  have hcA : ([(xACSub enc e (Ux []) (Xx []) d₀ w0 chalLR aA εA).sk].map
      (fun k' => (k'.R.n : ℝ≥0∞) * k'.ε)).sum = εA := by
    simp [CSub.sk, xACSub, toCSub, opARounds]
  have hcB : ([(xBCSub W aA w0 enc e (Ux []) (Xx []) d₀ chalLR m chalJ labB decB aB εB).sk].map
      (fun k' => (k'.R.n : ℝ≥0∞) * k'.ε)).sum = εB := by
    simp [CSub.sk, xBCSub, toCSub, opBRounds]
  rw [hcA] at hA'
  rw [hcB] at hB'
  refine le_trans (MeasureTheory.measure_mono ?_) ((MeasureTheory.measure_union_le _ _).trans (add_le_add hA' hB'))
  intro H hH
  rw [Set.mem_ofPred_eq] at hH
  obtain ⟨hA1, hng, hB0, hB1, hBal⟩ := hH
  have hA0 : aA ≤ (cChain C toT St H (heads (Pv.run H))).length := le_trans hab hB0
  rcases x_split W aA aB hab enc e (Ux (Pv.runLog H).2) (Xx (Pv.runLog H).2) d₀ w0 chalLR m chalJ labB decB εA εB _
      hA1 hB0 with hAal | hBdoom
  · left
    rw [Set.mem_ofPred_eq, xACsAt, hfull H, allSt_singleton]
    exact ⟨⟨0, _, rfl, hA0, hA1, hng, id⟩, hAal⟩
  · right
    rw [Set.mem_ofPred_eq, xBCsAt, hfull H, allSt_singleton]
    exact ⟨⟨0, _, rfl, hB0, hB1, hBdoom, id⟩, hBal⟩

end XChain

/-! ## The numbers at W16R2's and R13's endpoint geometry -/

section Numbers

/-- **W16R2's code facts for the test** (`N = 2^15`, `n = 2^14`, `Q = 280`, `e = 8052`, `A = N`): L20's
`w16r2_open_code_facts`, and `A ≤ N`. -/
theorem w16r2_open_code_factsU {F : Type} [Field F] [Finite F] (pts : Fin (2 ^ 15) → F)
    (hpts : Function.Injective pts) (R : RowForm F (2 ^ 14)) :
    MinDist (LinearMap.range (encLin (Q := 280) pts R)) 16105 ∧ 2 * 8052 < 16105 ∧ 8052 + 1 ≤ 2 ^ 15
      ∧ (2 ^ 15 : ℕ) ≤ 2 ^ 15 ∧ CAOn Unit (LinearMap.range (encLin (Q := 280) pts R)) 8052 (2 ^ 15) := by
  obtain ⟨hd, h2, hA, hca⟩ := w16r2_open_code_facts pts hpts R
  exact ⟨hd, h2, hA, le_rfl, hca⟩

/-- **R13's code facts for the test** (`N = 2^16`, `n = 2^14`, `Q = 256`, `e = 24,448`, `A = N`): minimum distance
`48,897`, `2e < 48,897`, correlated agreement with `A = N` (BCIKS20 at the δ/2 radius, `2e + K + 1 = 2^16`: tight). -/
theorem r13_open_code_factsU {F : Type} [Field F] [Finite F] (pts : Fin (2 ^ 16) → F)
    (hpts : Function.Injective pts) (R : RowForm F (2 ^ 14)) :
    MinDist (LinearMap.range (encLin (Q := 256) pts R)) 48897 ∧ 2 * 24448 < 48897 ∧ 24448 + 1 ≤ 2 ^ 16
      ∧ (2 ^ 16 : ℕ) ≤ 2 ^ 16 ∧ CAOn Unit (LinearMap.range (encLin (Q := 256) pts R)) 24448 (2 ^ 16) := by
  have hd := encLin_minDist (Q := 256) pts hpts R (by norm_num)
  have e1 : (2 : ℕ) ^ 16 - (2 ^ 14 + 256 - 1) = 48897 := by norm_num
  rw [e1] at hd
  exact ⟨hd, by norm_num, by norm_num, le_rfl, encLin_caOn pts hpts R (by norm_num) (by norm_num)⟩

/-- **The test's round-0 error at W16R2** (`N = 2^15`, `|F| = p²`, the `(λ, ρ)` bias over at most `2^61` squeezes at
most `2`): at most `2^-111` (the same figure as `opA`'s at the δ/2 radius, `opA_eps_w16r2`). -/
theorem xA_eps_w16r2 {F : Type} [Fintype F] (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p)
    (hF : Fintype.card F = p ^ 2) {w0 : ℕ} (hw0 : w0 ≤ 2 ^ 61) :
    ((2 ^ 15 : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0)
      ≤ (2⁻¹ : ℝ≥0∞) ^ 111 :=
  opA_eps_w16r2 p hp1 hp2 hF hw0

/-- **The test's round-0 error at R13** (`N = 2^16`): at most `2^-110`. Stated for a variable `p` (L7-4). -/
theorem xA_eps_r13 {F : Type} [Fintype F] (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p)
    (hF : Fintype.card F = p ^ 2) {w0 : ℕ} (hw0 : w0 ≤ 2 ^ 61) :
    ((2 ^ 16 : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0)
      ≤ (2⁻¹ : ℝ≥0∞) ^ 110 := by
  have hb : (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0) ≤ ((2 : ℕ) : ℝ≥0∞) := by
    exact_mod_cast fp2_bias_pow_le_two hp1 (by omega)
  have hp0 : 0 < p := by omega
  calc ((2 ^ 16 : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0)
      ≤ ((2 ^ 16 : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * ((2 : ℕ) : ℝ≥0∞) := by
        rw [hF]
        exact mul_le_mul' le_rfl hb
    _ = ((2 ^ 16 * 2 : ℕ) : ℝ≥0∞) / ((p ^ 2 * 1 : ℕ) : ℝ≥0∞) := by
        rw [← natCast_div_mul_div, Nat.cast_one, div_one]
    _ ≤ (2⁻¹ : ℝ≥0∞) ^ 110 := by
        rw [inv_two_pow_eq]
        refine natCast_div_le_div (mul_ne_zero (pow_ne_zero 2 (by omega)) one_ne_zero) (by norm_num) ?_
        calc 2 ^ 16 * 2 * 2 ^ 110 = 2 ^ 127 := by norm_num
          _ ≤ (2 ^ 64 - 2 ^ 32) ^ 2 := by norm_num
          _ ≤ p ^ 2 := Nat.pow_le_pow_left hp2 2
          _ = 1 * (p ^ 2 * 1) := by ring

/-- **The test's column error at W16R2** (`N = 2^15`, `e = 8052`, `Q = 280`, the indices exactly uniform): at most
`2^-113` (`opB_eps_w16r2`). -/
theorem xB_eps_w16r2 :
    (((Fintype.card (Fin (2 ^ 15)) - (8052 + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ 15))) ^ 280 * 1
      ≤ (2⁻¹ : ℝ≥0∞) ^ 113 :=
  opB_eps_w16r2

/-- **The test's column error at R13** (`N = 2^16`, `e = 24,448`, `Q = 256`): at most `2^-172` (L17's
`r13_col_far_nat`). -/
theorem xB_eps_r13 :
    (((Fintype.card (Fin (2 ^ 16)) - (24448 + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ 16))) ^ 256 * 1
      ≤ (2⁻¹ : ℝ≥0∞) ^ 172 := by
  rw [mul_one, Fintype.card_fin, inv_two_pow_eq, natCast_div_pow]
  exact natCast_div_le_div (by positivity) (by norm_num) R13.r13_col_far_nat

end Numbers

end ZK60.Exec
