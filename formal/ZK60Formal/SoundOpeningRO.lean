/-
D63, step L3 (soundness): one opening of the polynomial commitment with its Merkle layer, the committed matrix
EXTRACTED from the committer's hash-query log instead of assumed fixed (task 4).

`SoundOpening.lean`'s `opening_sound` takes the committed matrix `U` as given. Here the prover is a three-phase oracle
computation against a uniformly random oracle `H`, in the order of `pcs::verify_zk_tagged` with the challenges drawn
INTERACTIVELY (exactly uniform, independent of `H`; Fiat–Shamir is not modelled):
1. `P₁` (at most `q₁` hash queries) outputs the root and a state. The root precedes every challenge.
2. The verifier draws the proximity weights `ρ : κ → E` uniformly; `P₂` (at most `q₂` queries) sees `ρ` and answers
   the group vector's and the proximity vector's codewords (elements of the code: the verifier re-encodes what it is
   sent, so they are codewords by construction).
3. The verifier draws `nQ` column indices `J` uniformly with replacement; `P₃` (at most `q₃` queries) sees `J` and
   opens a column at each of them.
The verifier accepts (`ROAccepts`) when the claim holds of the group vector's codeword and, at each sampled index, the
Merkle opening verifies against the root (a path of the tree's depth `h`) and the opened column agrees with both
vectors (`Σ_i a_i·col_i` and `Σ_i ρ_i·col_i`).

The matrix `extractU` is read off `P₁`'s log alone by `extractCol` (a default column where extraction fails). It is
therefore a function of `H` and fixed before `ρ` and `J`: exactly the matrix `opening_sound` needs.

`opening_sound_extracted`: the verifier accepts while the EXTRACTED matrix does not decode to rows satisfying the claim
with probability at most
  `A/|E| + ((N − (e + 1))/N)^nQ + collBound T D + extGuess T q₁ D`,  `N = 2^h`, `T = q₁ + (q₂ + q₃) + nQ(h + 2)`:
the field term, the column term, and the Merkle extraction error (collisions, and an unqueried path guess).
-/
import ZK60Formal.SoundExtract
import ZK60Formal.SoundOpening

namespace ZK60.Sound

open scoped ENNReal
open Finset Prob Code

/-! ## Averaging over one coordinate of a uniform pair -/

/-- The uniform probability of an event is its count over the size of the space. -/
theorem prob_uniform_eq_card {Ω : Type} [Fintype Ω] [Nonempty Ω] (E : Ω → Prop) [DecidablePred E] :
    (PMF.uniformOfFintype Ω).toOuterMeasure {ω | E ω} = ((univ.filter E).card : ℝ≥0∞) / Fintype.card Ω := by
  rw [PMF.toOuterMeasure_uniformOfFintype_apply, Fintype.card_ofFinset]
  have hfilt : (univ.filter (fun ω => ω ∈ {ω | E ω})) = univ.filter E := by
    ext ω
    simp
  rw [hfilt]

/-- **Averaging over the first coordinate.** If, for every first draw `a`, the event has probability at most `ε` over
the second draw, it has probability at most `ε` over the pair. -/
theorem prob_prod_le_of_forall_fst {α β : Type} [Fintype α] [Nonempty α] [Fintype β] [Nonempty β]
    (P : α × β → Prop) (ε : ℝ≥0∞) (h : ∀ a, (PMF.uniformOfFintype β).toOuterMeasure {b | P (a, b)} ≤ ε) :
    (PMF.uniformOfFintype (α × β)).toOuterMeasure {x | P x} ≤ ε := by
  classical
  have hβ0 : (Fintype.card β : ℝ≥0∞) ≠ 0 := by exact_mod_cast Fintype.card_ne_zero
  have hβt : (Fintype.card β : ℝ≥0∞) ≠ ⊤ := ENNReal.natCast_ne_top _
  have hp0 : (Fintype.card (α × β) : ℝ≥0∞) ≠ 0 := by exact_mod_cast Fintype.card_ne_zero
  have hpt : (Fintype.card (α × β) : ℝ≥0∞) ≠ ⊤ := ENNReal.natCast_ne_top _
  have hslice : ∀ a, ((univ.filter (fun b => P (a, b))).card : ℝ≥0∞) ≤ ε * Fintype.card β := by
    intro a
    have := h a
    rw [prob_uniform_eq_card (fun b => P (a, b))] at this
    exact (ENNReal.div_le_iff hβ0 hβt).mp this
  rw [prob_uniform_eq_card P, ENNReal.div_le_iff hp0 hpt, card_filter_prod, Nat.cast_sum, Fintype.card_prod,
    Nat.cast_mul]
  calc ∑ a : α, ((univ.filter (fun b => P (a, b))).card : ℝ≥0∞) ≤ ∑ _a : α, ε * Fintype.card β :=
        sum_le_sum (fun a _ => hslice a)
    _ = ε * (Fintype.card α * Fintype.card β) := by
        rw [sum_const, card_univ, nsmul_eq_mul]
        ring

/-- **Averaging over the second coordinate.** If, for every second draw `b`, the event has probability at most `ε`
over the first draw, it has probability at most `ε` over the pair. -/
theorem prob_prod_le_of_forall_snd {α β : Type} [Fintype α] [Nonempty α] [Fintype β] [Nonempty β]
    (P : α × β → Prop) (ε : ℝ≥0∞) (h : ∀ b, (PMF.uniformOfFintype α).toOuterMeasure {a | P (a, b)} ≤ ε) :
    (PMF.uniformOfFintype (α × β)).toOuterMeasure {x | P x} ≤ ε := by
  classical
  have hα0 : (Fintype.card α : ℝ≥0∞) ≠ 0 := by exact_mod_cast Fintype.card_ne_zero
  have hαt : (Fintype.card α : ℝ≥0∞) ≠ ⊤ := ENNReal.natCast_ne_top _
  have hp0 : (Fintype.card (α × β) : ℝ≥0∞) ≠ 0 := by exact_mod_cast Fintype.card_ne_zero
  have hpt : (Fintype.card (α × β) : ℝ≥0∞) ≠ ⊤ := ENNReal.natCast_ne_top _
  have hslice : ∀ b, ((univ.filter (fun a => P (a, b))).card : ℝ≥0∞) ≤ ε * Fintype.card α := by
    intro b
    have := h b
    rw [prob_uniform_eq_card (fun a => P (a, b))] at this
    exact (ENNReal.div_le_iff hα0 hαt).mp this
  have hcount : (univ.filter P).card = ∑ b : β, (univ.filter (fun a : α => P (a, b))).card := by
    rw [card_filter, Fintype.sum_prod_type_right]
    refine sum_congr rfl (fun b _ => ?_)
    rw [card_filter]
  rw [prob_uniform_eq_card P, ENNReal.div_le_iff hp0 hpt, hcount, Nat.cast_sum, Fintype.card_prod,
    Nat.cast_mul]
  calc ∑ b : β, ((univ.filter (fun a => P (a, b))).card : ℝ≥0∞) ≤ ∑ _b : β, ε * Fintype.card α :=
        sum_le_sum (fun b _ => hslice b)
    _ = ε * (Fintype.card α * Fintype.card β) := by
        rw [sum_const, card_univ, nsmul_eq_mul]
        ring

/-! ## One opening with its Merkle layer -/

section Opening

variable {Q D S Col : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D]
variable {E κ : Type} [Field E] [Fintype E] [DecidableEq E] [Fintype κ] [DecidableEq κ]

/-- **The extracted matrix**: row `i`, column `j` is entry `i` of the column the extractor reads off the commit log at
position `j` (a default column `c₀` where it fails). `val` reads a column's entries. -/
def extractU (M : MerkleEnc Q D S Col) (val : Col → κ → E) (c₀ : Col) (L : List (Q × D)) (h : ℕ) (root : D) :
    κ → Fin (2 ^ h) → E :=
  fun i j => val ((M.extractCol L h j root).getD c₀) i

/-- **The verifier of one opening with its Merkle layer**, on the run of a three-phase prover against the oracle `H`,
the weights `ρ` and the indices `J` (`x = (H, (ρ, J))`): `P₁` commits (its first output is the root), `P₂` sees `ρ`
and answers the group vector's and the proximity vector's codewords, `P₃` sees `J` and opens a column at each index.
It accepts when the claim holds of the group vector's codeword and, at each sampled index, the opening verifies
against the root and the opened column agrees with both vectors. -/
def ROAccepts (M : MerkleEnc Q D S Col) (val : Col → κ → E) (a : κ → E) {h : ℕ} {C : Submodule E (Fin (2 ^ h) → E)}
    (ok : (Fin (2 ^ h) → E) → Prop) {nQ : ℕ} {St₁ St₂ : Type} (P₁ : OC Q D (D × St₁))
    (P₂ : St₁ → (κ → E) → OC Q D (St₂ × C × C))
    (P₃ : St₂ → (Fin nQ → Fin (2 ^ h)) → OC Q D (Fin nQ → MerkleOpening D S Col))
    (x : (Q → D) × ((κ → E) × (Fin nQ → Fin (2 ^ h)))) : Prop :=
  let r := (P₂ (P₁.runLog x.1).1.2 x.2.1).run x.1
  let ops := (P₃ r.1 x.2.2).run x.1
  ok (r.2.1 : Fin (2 ^ h) → E) ∧ ∀ k, M.Opens x.1 h (P₁.runLog x.1).1.1 (x.2.2 k) (ops k)
    ∧ (r.2.1 : Fin (2 ^ h) → E) (x.2.2 k) = ∑ i, a i * val (ops k).col i
    ∧ (r.2.2 : Fin (2 ^ h) → E) (x.2.2 k) = ∑ i, x.2.1 i * val (ops k).col i

/-- **One opening is sound with the matrix EXTRACTED from the commit log (task 4).** Let the code `C` over the `2^h`
leaf positions have minimum distance `d`, `2e < d`, and correlated agreement on lines with at most `A ≥ e + 1`
exceptions. For any three-phase prover (`P₁` commits with at most `q₁` hash queries, then `P₂` answers the weights `ρ`
with at most `q₂`, then `P₃` opens the indices `J` with at most `q₃`), with `H` a uniform random oracle and `ρ`, `J`
uniform and independent of it (drawn after the root, in that order): the verifier accepts while the matrix extracted
from `P₁`'s log does not decode to rows satisfying the claim with probability at most
`A/|E| + ((N − (e + 1))/N)^nQ + collBound T D + extGuess T q₁ D`, `N = 2^h`, `T = q₁ + (q₂ + q₃) + nQ(h + 2)`. -/
theorem opening_sound_extracted (M : MerkleEnc Q D S Col) (val : Col → κ → E) (c₀ : Col) {h : ℕ}
    {C : Submodule E (Fin (2 ^ h) → E)} {d e A : ℕ} (hd : MinDist C d) (h2 : 2 * e < d) (hA : e + 1 ≤ A)
    (hca : CAOn Unit C e A) (a : κ → E) (ok : (Fin (2 ^ h) → E) → Prop) (nQ : ℕ) {St₁ St₂ : Type}
    (q₁ q₂ q₃ : ℕ) (P₁ : OC Q D (D × St₁)) (hP₁ : P₁.Bounded q₁)
    (P₂ : St₁ → (κ → E) → OC Q D (St₂ × C × C)) (hP₂ : ∀ st ρ, (P₂ st ρ).Bounded q₂)
    (P₃ : St₂ → (Fin nQ → Fin (2 ^ h)) → OC Q D (Fin nQ → MerkleOpening D S Col))
    (hP₃ : ∀ st J, (P₃ st J).Bounded q₃) :
    (PMF.uniformOfFintype ((Q → D) × ((κ → E) × (Fin nQ → Fin (2 ^ h))))).toOuterMeasure
        {x | ROAccepts M val a ok P₁ P₂ P₃ x
          ∧ ¬ OpeningGood C e (extractU M val c₀ (P₁.runLog x.1).2 h (P₁.runLog x.1).1.1) a ok}
      ≤ (A : ℝ≥0∞) / Fintype.card E
        + (((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ
        + (collBound (q₁ + (q₂ + q₃) + nQ * (h + 2)) D + extGuess (q₁ + (q₂ + q₃) + nQ * (h + 2)) q₁ D) := by
  classical
  set μ := (PMF.uniformOfFintype ((Q → D) × ((κ → E) × (Fin nQ → Fin (2 ^ h))))).toOuterMeasure
  -- the matrix, and the two vectors, as functions of the oracle
  let U : (Q → D) → κ → Fin (2 ^ h) → E := fun H => extractU M val c₀ (P₁.runLog H).2 h (P₁.runLog H).1.1
  let g : (Q → D) → (κ → E) → Fin (2 ^ h) → E := fun H ρ => ((P₂ (P₁.runLog H).1.2 ρ).run H).2.1
  let w : (Q → D) → (κ → E) → Fin (2 ^ h) → E := fun H ρ => ((P₂ (P₁.runLog H).1.2 ρ).run H).2.2
  -- the opened columns, as functions of the oracle and the challenges
  let ops : (Q → D) → (κ → E) → (Fin nQ → Fin (2 ^ h)) → Fin nQ → MerkleOpening D S Col :=
    fun H ρ J => (P₃ ((P₂ (P₁.runLog H).1.2 ρ).run H).1 J).run H
  -- S₁: the matrix-fixed event of `opening_sound`, for the extracted matrix
  let S₁ : Set ((Q → D) × ((κ → E) × (Fin nQ → Fin (2 ^ h)))) :=
    {x | OpeningAccepts (U x.1) a ok (g x.1) (w x.1) x.2.1 x.2.2 ∧ ¬ OpeningGood C e (U x.1) a ok}
  -- S₂: some opening verifies but is not the extracted column
  let S₂ : Set ((Q → D) × ((κ → E) × (Fin nQ → Fin (2 ^ h)))) :=
    {x | ∃ k, M.Opens x.1 h (P₁.runLog x.1).1.1 (x.2.2 k) (ops x.1 x.2.1 x.2.2 k)
      ∧ M.extractCol (P₁.runLog x.1).2 h (x.2.2 k) (P₁.runLog x.1).1.1 ≠ some (ops x.1 x.2.1 x.2.2 k).col}
  have hsub : {x | ROAccepts M val a ok P₁ P₂ P₃ x
      ∧ ¬ OpeningGood C e (extractU M val c₀ (P₁.runLog x.1).2 h (P₁.runLog x.1).1.1) a ok} ⊆ S₁ ∪ S₂ := by
    rintro ⟨H, ρ, J⟩ ⟨⟨hok, hall⟩, hgood⟩
    by_cases hS₂ : (H, ρ, J) ∈ S₂
    · exact Or.inr hS₂
    · left
      have hext : ∀ k, M.extractCol (P₁.runLog H).2 h (J k) (P₁.runLog H).1.1 = some (ops H ρ J k).col := by
        intro k
        by_contra hne
        exact hS₂ ⟨k, (hall k).1, hne⟩
      have hU : ∀ k i, U H i (J k) = val (ops H ρ J k).col i := by
        intro k i
        show val ((M.extractCol (P₁.runLog H).2 h (J k) (P₁.runLog H).1.1).getD c₀) i = _
        rw [hext k]
        rfl
      refine ⟨⟨hok, fun k => ?_, fun k => ?_⟩, hgood⟩
      · rw [comb_apply]
        refine (hall k).2.1.trans (sum_congr rfl (fun i _ => ?_))
        rw [hU k i]
      · rw [comb_apply]
        refine (hall k).2.2.trans (sum_congr rfl (fun i _ => ?_))
        rw [hU k i]
  -- S₁: `opening_sound` for each oracle
  have h₁ : μ S₁ ≤ (A : ℝ≥0∞) / Fintype.card E
      + (((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ :=
    prob_prod_le_of_forall_fst _ _ (fun H => opening_sound hd h2 hA hca (U H) a ok (g H) (w H)
      (fun ρ => ((P₂ (P₁.runLog H).1.2 ρ).run H).2.1.2) (fun ρ => ((P₂ (P₁.runLog H).1.2 ρ).run H).2.2.2) nQ)
  -- S₂: `extract_sound` for each pair of challenges
  have h₂ : μ S₂ ≤ collBound (q₁ + (q₂ + q₃) + nQ * (h + 2)) D + extGuess (q₁ + (q₂ + q₃) + nQ * (h + 2)) q₁ D := by
    refine prob_prod_le_of_forall_snd _ _ (fun ω => ?_)
    let B : St₁ → OC Q D (Fin nQ → ℕ × MerkleOpening D S Col) := fun st =>
      (P₂ st ω.1).bind (fun r => (P₃ r.1 ω.2).bind (fun o => .ret (fun k => ((ω.2 k : ℕ), o k))))
    have hB : ∀ st, (B st).Bounded (q₂ + q₃) := fun st =>
      ((hP₂ st ω.1).bind (fun r => (hP₃ r.1 ω.2).bind
        (fun o => (show (OC.ret (fun k => ((ω.2 k : ℕ), o k)) : OC Q D _).Bounded 0 from trivial)))).mono
        (by omega)
    have hrun : ∀ H st, (B st).run H = fun k => ((ω.2 k : ℕ), ((P₃ ((P₂ st ω.1).run H).1 ω.2).run H) k) := by
      intro H st
      simp only [B, OC.run_bind]
      rfl
    refine le_trans (MeasureTheory.measure_mono ?_) (M.extract_sound h q₁ (q₂ + q₃) nQ P₁ hP₁ B hB)
    rintro H ⟨k, hk1, hk2⟩
    refine ⟨k, ?_, ?_⟩
    · rw [hrun]
      exact hk1
    · rw [hrun]
      exact hk2
  calc μ {x | ROAccepts M val a ok P₁ P₂ P₃ x
          ∧ ¬ OpeningGood C e (extractU M val c₀ (P₁.runLog x.1).2 h (P₁.runLog x.1).1.1) a ok}
      ≤ μ (S₁ ∪ S₂) := MeasureTheory.measure_mono hsub
    _ ≤ μ S₁ + μ S₂ := MeasureTheory.measure_union_le _ _
    _ ≤ _ := add_le_add h₁ h₂

/-- **One rate-1/2 opening (δ/2, D59) with the matrix extracted.** The Reed–Solomon code of degree `≤ K` at the
`N = 2^h` distinct points `dom`, with `2e + K + 1 ≤ N`: the bound of `opening_sound_rs_half`, `N/|E|` plus the column
term, plus the Merkle extraction error. -/
theorem opening_sound_extracted_rs_half (M : MerkleEnc Q D S Col) (val : Col → κ → E) (c₀ : Col) {h : ℕ}
    (dom : Fin (2 ^ h) ↪ E) {e K : ℕ} (hn : 2 * e + K + 1 ≤ Fintype.card (Fin (2 ^ h)))
    (a : κ → E) (ok : (Fin (2 ^ h) → E) → Prop) (nQ : ℕ) {St₁ St₂ : Type}
    (q₁ q₂ q₃ : ℕ) (P₁ : OC Q D (D × St₁)) (hP₁ : P₁.Bounded q₁)
    (P₂ : St₁ → (κ → E) → OC Q D (St₂ × rsCode dom K × rsCode dom K)) (hP₂ : ∀ st ρ, (P₂ st ρ).Bounded q₂)
    (P₃ : St₂ → (Fin nQ → Fin (2 ^ h)) → OC Q D (Fin nQ → MerkleOpening D S Col))
    (hP₃ : ∀ st J, (P₃ st J).Bounded q₃) :
    (PMF.uniformOfFintype ((Q → D) × ((κ → E) × (Fin nQ → Fin (2 ^ h))))).toOuterMeasure
        {x | ROAccepts M val a ok P₁ P₂ P₃ x
          ∧ ¬ OpeningGood (rsCode dom K) e (extractU M val c₀ (P₁.runLog x.1).2 h (P₁.runLog x.1).1.1) a ok}
      ≤ (Fintype.card (Fin (2 ^ h)) : ℝ≥0∞) / Fintype.card E
        + (((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ
        + (collBound (q₁ + (q₂ + q₃) + nQ * (h + 2)) D + extGuess (q₁ + (q₂ + q₃) + nQ * (h + 2)) q₁ D) :=
  opening_sound_extracted M val c₀ (minDist_rsCode dom K) (by omega) (by omega) (caOn_rsCode dom hn) a ok nQ
    q₁ q₂ q₃ P₁ hP₁ P₂ hP₂ P₃ hP₃

end Opening

end ZK60.Sound
