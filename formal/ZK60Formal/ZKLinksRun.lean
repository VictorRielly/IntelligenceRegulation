/-
D63 step L19 (Statement 2, zero knowledge), part 7: a RUN's view as independent layers (L14's item 4, generic).

A classify run is one transcript end to end, so it is ONE receipt (L14 §3.1): its view at fixed challenges is the view
of every block (the openings, every slot, `M`; `ZKLinks.block_view_law_eq_links`), of the token stages IN-C and OUT-C
(their masked slots and openings, the same composition with their own slot lists), and of the boundary commitments'
openings, each on ITS OWN coins. This file composes any finite family of such layers:

* `map_eq_of_card`: two maps of uniform coins with the same preimage counts have the same law;
* **`law_eq_pi`**: a family of independent layers (`Fin n`-indexed, each on its own coin type), each with a law that does
  not depend on the data, has a joint law that does not depend on the data (`ZKW16View.law_eq_prod` for `n` layers);
* **`hHV_of_layers`**: a run receipt read off such a family of layer views has the `hHV` of `fs_step` for every two
  inputs (through `ZKLinks.hHV_of_view`).

With `ZKCountBudget.ZKKinds.add` (the run's counts are the sum of its layers' counts), this is what L18's classify run
instance takes: each block and each stage as a layer whose law is `block_view_law_eq_links` at that layer's slot list.

Every premise is an explicit hypothesis.
-/
import ZK60Formal.ZKLinks

namespace ZK60.ZKLinks

open scoped ENNReal
open Finset ZK60.ZKW16

/-- **Equal preimage counts, equal laws**: two maps of uniform coins that put the same number of coins on every value
have the same law. -/
theorem map_eq_of_card {Ω β : Type} [Fintype Ω] [Nonempty Ω] [DecidableEq β] (F G : Ω → β)
    (h : ∀ b, (univ.filter (fun ω => F ω = b)).card = (univ.filter (fun ω => G ω = b)).card) :
    (PMF.uniformOfFintype Ω).map F = (PMF.uniformOfFintype Ω).map G := by
  have e : ∀ (U : Ω → β) (b : β), (PMF.uniformOfFintype Ω).map U b
      = ((univ.filter (fun ω => U ω = b)).card : ℝ≥0∞) * (Fintype.card Ω : ℝ≥0∞)⁻¹ := by
    intro U b
    rw [PMF.map_apply, tsum_fintype]
    simp only [PMF.uniformOfFintype_apply]
    rw [sum_ite, sum_const_zero, add_zero, sum_const, nsmul_eq_mul,
      filter_congr (fun ω _ => (eq_comm : b = U ω ↔ U ω = b))]
  ext b
  rw [e F b, e G b, h b]

/-- **Independent layers, a whole family**: if each of `n` layers, on its own coins, has a law that does not depend on
the data, the joint law of all of them over independent coins does not depend on the data either. -/
theorem law_eq_pi {n : ℕ} {Ω β : Fin n → Type} [∀ i, Fintype (Ω i)] [∀ i, Nonempty (Ω i)]
    [∀ i, DecidableEq (β i)] (f f' : (i : Fin n) → Ω i → β i)
    (h : ∀ i, (PMF.uniformOfFintype (Ω i)).map (f i) = (PMF.uniformOfFintype (Ω i)).map (f' i)) :
    (PMF.uniformOfFintype ((i : Fin n) → Ω i)).map (fun ω i => f i (ω i))
      = (PMF.uniformOfFintype ((i : Fin n) → Ω i)).map (fun ω i => f' i (ω i)) := by
  classical
  refine map_eq_of_card _ _ (fun b => ?_)
  have hpi : ∀ g : (i : Fin n) → Ω i → β i,
      (univ.filter (fun ω : (i : Fin n) → Ω i => (fun i => g i (ω i)) = b)).card
        = ∏ i, (univ.filter (fun x : Ω i => g i x = b i)).card := by
    intro g
    rw [← Fintype.card_piFinset]
    congr 1
    ext ω
    simp only [mem_filter, mem_univ, true_and, Fintype.mem_piFinset, funext_iff]
  rw [hpi f, hpi f']
  refine prod_congr rfl (fun i _ => ?_)
  exact card_eq_of_map_eq (h i) (fun o => o = b i) (fun _ => Iff.rfl) (fun _ => Iff.rfl)

/-- **A run receipt read off independent layers** (`hHV` for every two inputs). Let the run's coins push to the
layers' independent coins (`hπ`), let the receipt at every value vector be a function of the family of layer views
(`hout`), and let every layer's view have a data-independent law at every value vector (`hlay`). Then the receipts of
any two inputs have the same law at every value vector. -/
theorem hHV_of_layers {Q D X C Out : Type} [Fintype C] [Nonempty C] (FM : FSModel Q D X C Out) {n : ℕ}
    {Ω β : Fin n → Type} [∀ i, Fintype (Ω i)] [∀ i, Nonempty (Ω i)]
    [∀ i, DecidableEq (β i)] (π : C → (i : Fin n) → Ω i)
    (hπ : (PMF.uniformOfFintype C).map π = PMF.uniformOfFintype ((i : Fin n) → Ω i))
    (Vl : (Fin FM.k → D) → X → (i : Fin n) → Ω i → β i) (Rc : (Fin FM.k → D) → ((i : Fin n) → β i) → Out)
    (hout : ∀ x c v, FM.out x c v = Rc v (fun i => Vl v x i (π c i))) (x₀ : X)
    (hlay : ∀ v x i, (PMF.uniformOfFintype (Ω i)).map (Vl v x i) = (PMF.uniformOfFintype (Ω i)).map (Vl v x₀ i)) :
    ∀ x x' (v : Fin FM.k → D), (PMF.uniformOfFintype C).map (fun c => FM.out x c v)
      = (PMF.uniformOfFintype C).map (fun c => FM.out x' c v) :=
  hHV_of_view FM π hπ (fun x v ω i => Vl v x i (ω i)) Rc hout x₀
    (fun v x => law_eq_pi (fun i => Vl v x i) (fun i => Vl v x₀ i) (hlay v x))

end ZK60.ZKLinks
