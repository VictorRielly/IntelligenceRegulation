/-
D63, step L3 (soundness): one opening of the polynomial commitment as `pcs::verify_zk_tagged` runs it, with SEVERAL
claim groups, the `λ` batching inside each group, and the claims read through the INVERSE OF THE ENCODER.

`SoundOpening.lean`'s `opening_sound` checks one claim group with fixed row weights and an abstract predicate `ok`.
Here the model follows `group_zclaims`, `zk_rhos` and `verify_zk_tagged` (`pcs.rs:926-1279`):
* a claim `c` is a row-weight vector `rw_c` (over the committed rows), a claimed value `val_c` and a group `grp c`;
  every claim of a group shares the group's column weights `cw_g` (the code groups claims by equal column key);
* the encoder is any injective linear map `enc : (μ → E) → (ι → E)` from clear vectors (message then pad entries,
  `n + Q` of them) to words; the code is its range. The code's `encode_row_zk` is such a map onto `RS[n + Q]` on the
  coset (lemma check §1);
* the claim `c` is a linear functional of the committed MESSAGE: on message rows `X`, its value is
  `Σ_i rw_c(i)·⟨X_i, cw_{grp c}⟩` (`claimValue`). The column weights are zero on the pad entries in the instance;
  the model allows any;
* the verifier draws INDEPENDENT uniform `λ_c`, one per claim (`tr.challenge_fp2_vec(members.len())` per group, not
  powers of one challenge), and the proximity weights `ρ`, all before the prover's vectors are absorbed. Group `g`'s
  row weights are `a_g = Σ_{c ∈ g} λ_c·rw_c` and its combined value is `Σ_{c ∈ g} λ_c·val_c`;
* the prover answers, as ANY functions of `(λ, ρ)`, one clear vector `v_g` per group and the clear proximity vector
  `w`. The verifier checks `⟨v_g, cw_g⟩ = Σ_{c ∈ g} λ_c·val_c` for every group, re-encodes, and at each of `Q`
  uniform column indices (drawn after the vectors) checks `enc(v_g) = Σ_i a_{g,i}·U_i` for every group and
  `enc(w) = Σ_i ρ_i·U_i` (`GroupsAccept`).

The extracted data is DECODED: `decodeRows` takes the unique codeword rows `U` agrees with outside `e` columns
(`closeTable`), then the encoder's inverse (`decodeWord`, `Function.invFun enc`). `GroupsGood` says `U` is close and
every claim holds of the decoded message rows; `groupsGood_iff` shows that this is the same as "some message rows `X`
close to `U` satisfy every claim", by unique decoding.

`groups_sound`: for any linear code of minimum distance `d` with `2e < d` and correlated agreement on lines with at
most `A ≥ e + 1` exceptions, the verifier accepts while some claim is false of the decoded message with probability at
most `A/|E| + ((N − (e + 1))/N)^Q`, the bound `opening_sound` proved for ONE group with fixed weights.
* The `λ` batching costs `1/|E|` (`batch_prob`), but only in the CLOSE case, and `1 ≤ A`: it is absorbed. The additive
  form, batching term plus the one-group bound, is `groups_sound_add`.
* Several groups cost nothing more: the close case needs only the group of one false claim; the far case needs only
  the proximity vector.
* Instances: `groups_sound_rs_half` (`N/|E| + col`) and `groups_sound_rs_third` (`(e + 1)/|E| + col`).

Interactive: `U` fixed (the extracted matrix of `SoundOpeningRO.lean` can be substituted, as there), the challenges
exactly uniform and independent; Fiat–Shamir is not modelled.
-/
import ZK60Formal.SoundOpeningRO
import ZK60Formal.SoundZeroCheck

namespace ZK60.Sound

open scoped ENNReal
open Finset Prob Code

variable {E ι κ μ G Cl : Type} [Field E]

/-! ## The decoder: the inverse of the encoder on the code -/

/-- **The decoder.** The inverse of the encoder `enc` on its range (the code): `Function.invFun enc`. On a codeword
`enc x` it returns `x` (`decodeWord_enc`); off the code its value is never used. -/
noncomputable def decodeWord (enc : (μ → E) →ₗ[E] (ι → E)) (word : ι → E) : μ → E := Function.invFun enc word

/-- Decoding a codeword returns its message (the encoder is injective). -/
theorem decodeWord_enc (enc : (μ → E) →ₗ[E] (ι → E)) (henc : Function.Injective enc) (x : μ → E) :
    decodeWord enc (enc x) = x :=
  Function.leftInverse_invFun henc x

/-- Encoding the decoding of a codeword gives the codeword back. -/
theorem enc_decodeWord (enc : (μ → E) →ₗ[E] (ι → E)) {word : ι → E} (hw : word ∈ LinearMap.range enc) :
    enc (decodeWord enc word) = word :=
  Function.invFun_eq (LinearMap.mem_range.mp hw)

open Classical in
/-- **The codeword rows a close matrix agrees with** (outside at most `e` columns). They are unique when `2e < d`
(`Close.unique`). `0` when `U` is far. -/
noncomputable def closeTable [Fintype ι] (D : Submodule E (ι → E)) (e : ℕ) (U : κ → ι → E) : κ → ι → E :=
  if h : Close D e U then Classical.choose h.exists_table else 0

/-- For a close matrix, `closeTable` is a table of codewords that agrees with it outside at most `e` columns. -/
theorem closeTable_spec [Fintype ι] {D : Submodule E (ι → E)} {e : ℕ} {U : κ → ι → E} (h : Close D e U) :
    (∀ i, closeTable D e U i ∈ D)
      ∧ ∃ S : Finset ι, Fintype.card ι ≤ S.card + e ∧ ∀ j ∈ S, ∀ i, U i j = closeTable D e U i j := by
  classical
  obtain ⟨S, hV, hS, hUV⟩ := Classical.choose_spec h.exists_table
  have hT : closeTable D e U = Classical.choose h.exists_table := by
    unfold closeTable
    simp only [h, ↓reduceDIte]
  rw [hT]
  exact ⟨hV, S, hS, hUV⟩

/-- **The decoded message rows** of the committed matrix: the encoder's inverse applied to each row of `closeTable`
(the extracted, decoded data). -/
noncomputable def decodeRows [Fintype ι] (enc : (μ → E) →ₗ[E] (ι → E)) (e : ℕ) (U : κ → ι → E) : κ → μ → E :=
  fun i => decodeWord enc (closeTable (LinearMap.range enc) e U i)

/-! ## Claims, groups and the verifier -/

/-- **A claim as a linear functional of the committed message.** The value of claim `c` on message rows `X`:
`Σ_i rw_c(i)·⟨X_i, cw_{grp c}⟩` (row weights, then the group's column weights). -/
def claimValue [Fintype κ] [Fintype μ] (rw : Cl → κ → E) (cw : G → μ → E) (grp : Cl → G) (X : κ → μ → E)
    (c : Cl) : E :=
  ∑ i, rw c i * ∑ t, X i t * cw (grp c) t

/-- Group `g`'s combined row weights under the batching draws `λ`: `Σ_{c ∈ g} λ_c·rw_c` (`zk_rhos`). -/
def groupWeights [Fintype Cl] [DecidableEq G] (rw : Cl → κ → E) (grp : Cl → G) (lam : Cl → E) (g : G) : κ → E :=
  ∑ c, (if grp c = g then lam c else 0) • rw c

/-- Group `g`'s combined claimed value: `Σ_{c ∈ g} λ_c·val_c` (`want` in `zk_rhos`). -/
def groupWant [Fintype Cl] [DecidableEq G] (val : Cl → E) (grp : Cl → G) (lam : Cl → E) (g : G) : E :=
  ∑ c, (if grp c = g then lam c else 0) * val c

/-- **The verifier of one opening with several groups** (`verify_zk_tagged`, the Merkle layer left out as in
`SoundOpening.lean`). For every group `g` (every group that has a claim): the group vector's claim check
`⟨v_g, cw_g⟩ = Σ_{c ∈ g} λ_c·val_c`, and at each sampled column `enc(v_g) = Σ_i a_{g,i}·U_i`; at each sampled column
`enc(w) = Σ_i ρ_i·U_i`. -/
def GroupsAccept [Fintype κ] [Fintype μ] [Fintype Cl] [DecidableEq G] (enc : (μ → E) →ₗ[E] (ι → E))
    (U : κ → ι → E) (rw : Cl → κ → E) (cw : G → μ → E) (grp : Cl → G) (val : Cl → E)
    (v : G → (Cl → E) → (κ → E) → μ → E) (w : (Cl → E) → (κ → E) → μ → E) {Q : ℕ}
    (lam : Cl → E) (ρ : κ → E) (J : Fin Q → ι) : Prop :=
  (∀ g ∈ Set.range grp, ∑ t, v g lam ρ t * cw g t = groupWant val grp lam g)
    ∧ (∀ g ∈ Set.range grp, ∀ k, enc (v g lam ρ) (J k) = comb U (groupWeights rw grp lam g) (J k))
    ∧ ∀ k, enc (w lam ρ) (J k) = comb U ρ (J k)

/-- **The good case: the decoded data satisfies every claim.** `U` is `e`-close to the code, and every claim holds of
the decoded message rows `decodeRows enc e U`. -/
def GroupsGood [Fintype ι] [Fintype κ] [Fintype μ] (enc : (μ → E) →ₗ[E] (ι → E)) (e : ℕ) (U : κ → ι → E)
    (rw : Cl → κ → E) (cw : G → μ → E) (grp : Cl → G) (val : Cl → E) : Prop :=
  Close (LinearMap.range enc) e U ∧ ∀ c, claimValue rw cw grp (decodeRows enc e U) c = val c

/-- **The decoded data is the extracted data.** For a code of minimum distance `d > 2e`, `GroupsGood` holds exactly
when SOME message rows `X`, encoded, agree with `U` outside at most `e` columns and satisfy every claim: unique
decoding makes `X` the decoded rows. -/
theorem groupsGood_iff [Fintype ι] [Fintype κ] [Fintype μ] (enc : (μ → E) →ₗ[E] (ι → E))
    (henc : Function.Injective enc) {d e : ℕ} (hd : MinDist (LinearMap.range enc) d) (h2 : 2 * e < d)
    (U : κ → ι → E) (rw : Cl → κ → E) (cw : G → μ → E) (grp : Cl → G) (val : Cl → E) :
    GroupsGood enc e U rw cw grp val
      ↔ ∃ X : κ → μ → E, (∃ S : Finset ι, Fintype.card ι ≤ S.card + e ∧ ∀ j ∈ S, ∀ i, U i j = enc (X i) j)
          ∧ ∀ c, claimValue rw cw grp X c = val c := by
  constructor
  · rintro ⟨hc, hall⟩
    obtain ⟨hV, S, hS, hUV⟩ := closeTable_spec hc
    refine ⟨decodeRows enc e U, ⟨S, hS, fun j hj i => ?_⟩, hall⟩
    rw [hUV j hj i, decodeRows, enc_decodeWord enc (hV i)]
  · rintro ⟨X, ⟨S, hS, hUX⟩, hall⟩
    have hc : Close (LinearMap.range enc) e U :=
      ⟨S, hS, fun i => mem_agreeOn.mpr ⟨enc (X i), LinearMap.mem_range_self enc _, fun j hj => hUX j hj i⟩⟩
    obtain ⟨hV, T, hT, hUV⟩ := closeTable_spec hc
    have huniq : closeTable (LinearMap.range enc) e U = fun i => enc (X i) :=
      Close.unique hd h2 hV (fun i => LinearMap.mem_range_self enc _) hT hS hUV hUX
    have hdec : decodeRows enc e U = X := by
      funext i
      simp only [decodeRows, huniq, decodeWord_enc enc henc]
    exact ⟨hc, hdec ▸ hall⟩

/-! ## Two facts the proof uses -/

/-- **The batching identity.** For message rows `X`, the `λ`-combination of group `g`'s claim errors is the error of
the group's combined claim: `Σ_{c ∈ g} λ_c·(value_c(X) − val_c) = ⟨Σ_i a_{g,i}·X_i, cw_g⟩ − Σ_{c ∈ g} λ_c·val_c`. -/
theorem batch_identity [Fintype κ] [Fintype μ] [Fintype Cl] [DecidableEq G] (rw : Cl → κ → E) (cw : G → μ → E)
    (grp : Cl → G) (val : Cl → E) (X : κ → μ → E) (lam : Cl → E) (g : G) :
    ∑ c, lam c * (if grp c = g then claimValue rw cw grp X c - val c else 0)
      = ∑ t, (∑ i, groupWeights rw grp lam g i • X i) t * cw g t - groupWant val grp lam g := by
  set ℓ : Cl → E := fun c => if grp c = g then lam c else 0 with hℓ
  have h1 : ∀ c, lam c * (if grp c = g then claimValue rw cw grp X c - val c else 0)
      = ℓ c * (∑ i, rw c i * ∑ t, X i t * cw g t) - ℓ c * val c := by
    intro c
    by_cases hc : grp c = g
    · simp only [hℓ, hc, ↓reduceIte, claimValue]
      ring
    · simp [hℓ, hc]
  have hW : ∀ t, (∑ i, groupWeights rw grp lam g i • X i) t = ∑ i, (∑ c, ℓ c * rw c i) * X i t := by
    intro t
    simp only [groupWeights, Finset.sum_apply, Pi.smul_apply, smul_eq_mul, hℓ]
  have hV : groupWant val grp lam g = ∑ c, ℓ c * val c := rfl
  rw [Finset.sum_congr rfl (fun c _ => h1 c), Finset.sum_sub_distrib, hV]
  congr 1
  simp only [hW]
  calc ∑ c, ℓ c * ∑ i, rw c i * ∑ t, X i t * cw g t
      = ∑ c, ∑ i, ∑ t, ℓ c * rw c i * X i t * cw g t := by
        refine Finset.sum_congr rfl (fun c _ => ?_)
        rw [Finset.mul_sum]
        refine Finset.sum_congr rfl (fun i _ => ?_)
        rw [Finset.mul_sum, Finset.mul_sum]
        refine Finset.sum_congr rfl (fun t _ => ?_)
        ring
    _ = ∑ i, ∑ c, ∑ t, ℓ c * rw c i * X i t * cw g t := Finset.sum_comm
    _ = ∑ i, ∑ t, ∑ c, ℓ c * rw c i * X i t * cw g t :=
        Finset.sum_congr rfl (fun i _ => Finset.sum_comm)
    _ = ∑ t, ∑ i, ∑ c, ℓ c * rw c i * X i t * cw g t := Finset.sum_comm
    _ = ∑ t, (∑ i, (∑ c, ℓ c * rw c i) * X i t) * cw g t := by
        refine Finset.sum_congr rfl (fun t _ => ?_)
        rw [Finset.sum_mul]
        refine Finset.sum_congr rfl (fun i _ => ?_)
        rw [Finset.sum_mul, Finset.sum_mul]

/-- **Two different codewords, one of them read through a close matrix.** If `x ≠ y` are codewords of a code of
minimum distance `d`, and `z` agrees with `y` on a set `S` of all but at most `e` columns, then `x` and `z` differ in
at least `d − e` columns. -/
theorem le_card_ne_add [Fintype ι] [DecidableEq ι] [DecidableEq E] {D : Submodule E (ι → E)} {d e : ℕ}
    (hd : MinDist D d) {x y z : ι → E} (hx : x ∈ D) (hy : y ∈ D) (hxy : x ≠ y) {S : Finset ι}
    (hS : Fintype.card ι ≤ S.card + e) (hz : ∀ j ∈ S, z j = y j) :
    d ≤ (univ.filter (fun j => x j ≠ z j)).card + e := by
  have hdist := hd _ (D.sub_mem hx hy) (sub_ne_zero.mpr hxy)
  rw [cnt_eq_card_filter] at hdist
  have hsub : (univ.filter (fun j => (x - y) j ≠ 0)) ⊆ (univ.filter (fun j => x j ≠ z j)) ∪ Sᶜ := by
    intro j hj
    by_cases hjS : j ∈ S
    · refine mem_union_left _ (mem_filter.mpr ⟨mem_univ j, ?_⟩)
      rw [hz j hjS]
      have := (mem_filter.mp hj).2
      rwa [Pi.sub_apply, sub_ne_zero] at this
    · exact mem_union_right _ (mem_compl.mpr hjS)
  have h1 := (card_le_card hsub).trans (card_union_le _ _)
  rw [card_compl] at h1
  omega

/-- An event that never happens has probability at most anything. -/
theorem prob_le_of_forall_not {α : Type} [Fintype α] [Nonempty α] {P : α → Prop} (h : ∀ a, ¬ P a)
    (ε : ℝ≥0∞) : (PMF.uniformOfFintype α).toOuterMeasure {a | P a} ≤ ε := by
  have hempty : {a | P a} = ∅ := by
    ext a
    simp only [Set.mem_ofPred_eq, Set.mem_empty_iff_false, iff_false]
    exact h a
  rw [hempty, MeasureTheory.measure_empty]
  exact zero_le

/-! ## The theorem -/

/-- **One opening with several claim groups and `λ` batching is sound (task 1).** Let the code (the range of the
injective encoder `enc`) have minimum distance `d`, `2e < d`, and correlated agreement on lines with at most
`A ≥ e + 1` exceptions. For any committed matrix `U`, any claims, and any prover (the group vectors and the proximity
vector may depend on `(λ, ρ)` arbitrarily), the verifier accepts while SOME claim is false of the decoded message
(`¬ GroupsGood`) with probability at most `A/|E| + ((N − (e + 1))/N)^Q`, over independent uniform `λ` (one per claim),
`ρ`, and `Q` column indices drawn uniformly with replacement.

The batching term `1/|E|` arises only when `U` is close, where the far case's `A/|E|` is not paid; `1 ≤ A` absorbs it.
-/
theorem groups_sound [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] [Nonempty ι] [Fintype κ]
    [DecidableEq κ] [Fintype μ] [Fintype Cl] [DecidableEq Cl] [DecidableEq G]
    (enc : (μ → E) →ₗ[E] (ι → E)) (henc : Function.Injective enc) {d e A : ℕ}
    (hd : MinDist (LinearMap.range enc) d) (h2 : 2 * e < d) (hA : e + 1 ≤ A)
    (hca : CAOn Unit (LinearMap.range enc) e A)
    (U : κ → ι → E) (rw : Cl → κ → E) (cw : G → μ → E) (grp : Cl → G) (val : Cl → E)
    (v : G → (Cl → E) → (κ → E) → μ → E) (w : (Cl → E) → (κ → E) → μ → E) (Q : ℕ) :
    (PMF.uniformOfFintype (((Cl → E) × (κ → E)) × (Fin Q → ι))).toOuterMeasure
        {x | GroupsAccept enc U rw cw grp val v w x.1.1 x.1.2 x.2 ∧ ¬ GroupsGood enc e U rw cw grp val}
      ≤ (A : ℝ≥0∞) / Fintype.card E
        + (((Fintype.card ι - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q := by
  classical
  set D := LinearMap.range enc with hD
  by_cases hc : Close D e U
  · -- close: decode `U`
    obtain ⟨hV, S, hS, hUV⟩ := closeTable_spec hc
    have hX : ∀ i, enc (decodeRows enc e U i) = closeTable D e U i := fun i => enc_decodeWord enc (hV i)
    by_cases hall : ∀ c, claimValue rw cw grp (decodeRows enc e U) c = val c
    · -- every claim is true of the decoded rows: the event is empty
      exact prob_le_of_forall_not (fun x hx => hx.2 ⟨hc, hall⟩) _
    · push Not at hall
      obtain ⟨c₀, hc₀⟩ := hall
      -- the errors of the claims of `c₀`'s group
      let δ : Cl → E := fun c =>
        if grp c = grp c₀ then claimValue rw cw grp (decodeRows enc e U) c - val c else 0
      have hδ : ∃ c, δ c ≠ 0 := ⟨c₀, by simp only [δ, ↓reduceIte]; exact sub_ne_zero.mpr hc₀⟩
      have hsplit : {x : ((Cl → E) × (κ → E)) × (Fin Q → ι) |
            GroupsAccept enc U rw cw grp val v w x.1.1 x.1.2 x.2 ∧ ¬ GroupsGood enc e U rw cw grp val}
          ⊆ {x | ∑ c, x.1.1 c * δ c = 0}
            ∪ {x | (∑ c, x.1.1 c * δ c ≠ 0
                ∧ ∑ t, v (grp c₀) x.1.1 x.1.2 t * cw (grp c₀) t = groupWant val grp x.1.1 (grp c₀))
              ∧ ∀ k, enc (v (grp c₀) x.1.1 x.1.2) (x.2 k)
                = comb U (groupWeights rw grp x.1.1 (grp c₀)) (x.2 k)} := by
        intro x hx
        by_cases h0 : ∑ c, x.1.1 c * δ c = 0
        · exact Or.inl h0
        · exact Or.inr ⟨⟨h0, hx.1.1 _ ⟨c₀, rfl⟩⟩, hx.1.2.1 _ ⟨c₀, rfl⟩⟩
      refine le_trans (MeasureTheory.measure_mono hsplit)
        (le_trans (MeasureTheory.measure_union_le _ _) (add_le_add ?_ ?_))
      · -- the batching: `1/|E| ≤ A/|E|`
        refine le_trans ?_
          (ENNReal.div_le_div_right (show (1 : ℝ≥0∞) ≤ A by exact_mod_cast (by omega : 1 ≤ A)) _)
        refine prob_prod_le_of_forall_snd
          (fun x : ((Cl → E) × (κ → E)) × (Fin Q → ι) => ∑ c, x.1.1 c * δ c = 0) _ (fun _ => ?_)
        refine prob_prod_le_of_forall_snd (fun y : (Cl → E) × (κ → E) => ∑ c, y.1 c * δ c = 0) _ (fun _ => ?_)
        exact batch_prob δ hδ
      · -- the combined claim of `c₀`'s group is false: the group vector is far from `Σ a_i U_i`
        refine prob_prod_le_of_forall_fst _ _ (fun y => ?_)
        by_cases hy : ∑ c, y.1 c * δ c ≠ 0
            ∧ ∑ t, v (grp c₀) y.1 y.2 t * cw (grp c₀) t = groupWant val grp y.1 (grp c₀)
        · obtain ⟨hy1, hy2⟩ := hy
          have hbatch : ∑ c, y.1 c * δ c
              = ∑ t, (∑ i, groupWeights rw grp y.1 (grp c₀) i • decodeRows enc e U i) t * cw (grp c₀) t
                - groupWant val grp y.1 (grp c₀) :=
            batch_identity rw cw grp val (decodeRows enc e U) y.1 (grp c₀)
          have hne : v (grp c₀) y.1 y.2
              ≠ ∑ i, groupWeights rw grp y.1 (grp c₀) i • decodeRows enc e U i := by
            intro heq
            apply hy1
            rw [hbatch, ← heq, hy2, sub_self]
          have hXc : enc (∑ i, groupWeights rw grp y.1 (grp c₀) i • decodeRows enc e U i)
              = comb (closeTable D e U) (groupWeights rw grp y.1 (grp c₀)) := by
            simp only [comb, map_sum, map_smul, hX]
          have hagree : ∀ j ∈ S, comb U (groupWeights rw grp y.1 (grp c₀)) j
              = comb (closeTable D e U) (groupWeights rw grp y.1 (grp c₀)) j := by
            intro j hj
            rw [comb_apply, comb_apply]
            exact sum_congr rfl fun i _ => by rw [hUV j hj i]
          have hdist := le_card_ne_add hd (LinearMap.mem_range_self enc (v (grp c₀) y.1 y.2))
            (hXc ▸ LinearMap.mem_range_self enc _) (fun h => hne (henc (h.trans hXc.symm))) hS hagree
          have ht : e + 1 ≤ (univ.filter (fun j => enc (v (grp c₀) y.1 y.2) j
              ≠ comb U (groupWeights rw grp y.1 (grp c₀)) j)).card := by
            omega
          refine le_trans (MeasureTheory.measure_mono (fun J hJ => ?_))
            (column_test_sound _ _ ht Q)
          exact hJ.2
        · exact prob_le_of_forall_not (fun J hJ => hy hJ.1) _
  · -- far: the proximity test, then the column test against the proximity vector
    have hsplit : {x : ((Cl → E) × (κ → E)) × (Fin Q → ι) |
          GroupsAccept enc U rw cw grp val v w x.1.1 x.1.2 x.2 ∧ ¬ GroupsGood enc e U rw cw grp val}
        ⊆ {x | Close D e (fun _ : Unit => comb U x.1.2)}
          ∪ {x | ¬ Close D e (fun _ : Unit => comb U x.1.2)
            ∧ ∀ k, enc (w x.1.1 x.1.2) (x.2 k) = comb U x.1.2 (x.2 k)} := by
      intro x hx
      by_cases h1 : Close D e (fun _ : Unit => comb U x.1.2)
      · exact Or.inl h1
      · exact Or.inr ⟨h1, hx.1.2.2⟩
    refine le_trans (MeasureTheory.measure_mono hsplit)
      (le_trans (MeasureTheory.measure_union_le _ _) (add_le_add ?_ ?_))
    · refine prob_prod_le_of_forall_snd
        (fun x : ((Cl → E) × (κ → E)) × (Fin Q → ι) => Close D e (fun _ : Unit => comb U x.1.2)) _
        (fun _ => ?_)
      refine prob_prod_le_of_forall_fst
        (fun y : (Cl → E) × (κ → E) => Close D e (fun _ : Unit => comb U y.2)) _ (fun _ => ?_)
      exact comb_close_prob hd h2 hA hca U hc
    · refine prob_prod_le_of_forall_fst _ _ (fun y => ?_)
      by_cases hρ : Close D e (fun _ : Unit => comb U y.2)
      · exact prob_le_of_forall_not (fun J hJ => hJ.1 hρ) _
      · have ht : e + 1 ≤ (univ.filter (fun j => enc (w y.1 y.2) j ≠ comb U y.2 j)).card := by
          by_contra hlt
          exact hρ (close_of_card_ne_le (LinearMap.mem_range_self enc (w y.1 y.2)) (by omega))
        exact le_trans (MeasureTheory.measure_mono (fun J hJ => hJ.2)) (column_test_sound _ _ ht Q)

/-- **The same bound in the requested additive form**: the batching term `1/|E|` plus the one-group bound
`A/|E| + ((N − (e + 1))/N)^Q` of `opening_sound`. (`groups_sound` shows the batching term is in fact absorbed.) -/
theorem groups_sound_add [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] [Nonempty ι] [Fintype κ]
    [DecidableEq κ] [Fintype μ] [Fintype Cl] [DecidableEq Cl] [DecidableEq G]
    (enc : (μ → E) →ₗ[E] (ι → E)) (henc : Function.Injective enc) {d e A : ℕ}
    (hd : MinDist (LinearMap.range enc) d) (h2 : 2 * e < d) (hA : e + 1 ≤ A)
    (hca : CAOn Unit (LinearMap.range enc) e A)
    (U : κ → ι → E) (rw : Cl → κ → E) (cw : G → μ → E) (grp : Cl → G) (val : Cl → E)
    (v : G → (Cl → E) → (κ → E) → μ → E) (w : (Cl → E) → (κ → E) → μ → E) (Q : ℕ) :
    (PMF.uniformOfFintype (((Cl → E) × (κ → E)) × (Fin Q → ι))).toOuterMeasure
        {x | GroupsAccept enc U rw cw grp val v w x.1.1 x.1.2 x.2 ∧ ¬ GroupsGood enc e U rw cw grp val}
      ≤ 1 / Fintype.card E + ((A : ℝ≥0∞) / Fintype.card E
        + (((Fintype.card ι - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q) :=
  le_trans (groups_sound enc henc hd h2 hA hca U rw cw grp val v w Q) le_add_self

/-! ## Our Reed–Solomon code -/

/-- **Several groups at rate 1/2 (δ/2, D59; BCIKS20 Thm 3.1).** The encoder's range is the RS code of degree `≤ K`
at `N` distinct points, `2e + K + 1 ≤ N` (the code: `K + 1 = n + q_pad` message symbols, the encoder a bijection onto
the code, lemma check §1). Some claim false of the decoded message, accepted: probability at most
`N/|E| + ((N − (e + 1))/N)^Q`. -/
theorem groups_sound_rs_half [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] [Nonempty ι] [Fintype κ]
    [DecidableEq κ] [Fintype μ] [Fintype Cl] [DecidableEq Cl] [DecidableEq G]
    (dom : ι ↪ E) {e K : ℕ} (hn : 2 * e + K + 1 ≤ Fintype.card ι)
    (enc : (μ → E) →ₗ[E] (ι → E)) (henc : Function.Injective enc) (hrange : LinearMap.range enc = rsCode dom K)
    (U : κ → ι → E) (rw : Cl → κ → E) (cw : G → μ → E) (grp : Cl → G) (val : Cl → E)
    (v : G → (Cl → E) → (κ → E) → μ → E) (w : (Cl → E) → (κ → E) → μ → E) (Q : ℕ) :
    (PMF.uniformOfFintype (((Cl → E) × (κ → E)) × (Fin Q → ι))).toOuterMeasure
        {x | GroupsAccept enc U rw cw grp val v w x.1.1 x.1.2 x.2 ∧ ¬ GroupsGood enc e U rw cw grp val}
      ≤ (Fintype.card ι : ℝ≥0∞) / Fintype.card E
        + (((Fintype.card ι - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q := by
  have hd : MinDist (LinearMap.range enc) (Fintype.card ι - K) := hrange ▸ minDist_rsCode dom K
  have hca : CAOn Unit (LinearMap.range enc) e (Fintype.card ι) := hrange ▸ caOn_rsCode dom hn
  exact groups_sound enc henc hd (by omega) (by omega) hca U rw cw grp val v w Q

/-- **Several groups at rate 1/4 (δ/3, D15).** As `groups_sound_rs_half` with `3e + K + 1 ≤ N`: probability at most
`(e + 1)/|E| + ((N − (e + 1))/N)^Q`. -/
theorem groups_sound_rs_third [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] [Nonempty ι] [Fintype κ]
    [DecidableEq κ] [Fintype μ] [Fintype Cl] [DecidableEq Cl] [DecidableEq G]
    (dom : ι ↪ E) {e K : ℕ} (hn : 3 * e + K + 1 ≤ Fintype.card ι)
    (enc : (μ → E) →ₗ[E] (ι → E)) (henc : Function.Injective enc) (hrange : LinearMap.range enc = rsCode dom K)
    (U : κ → ι → E) (rw : Cl → κ → E) (cw : G → μ → E) (grp : Cl → G) (val : Cl → E)
    (v : G → (Cl → E) → (κ → E) → μ → E) (w : (Cl → E) → (κ → E) → μ → E) (Q : ℕ) :
    (PMF.uniformOfFintype (((Cl → E) × (κ → E)) × (Fin Q → ι))).toOuterMeasure
        {x | GroupsAccept enc U rw cw grp val v w x.1.1 x.1.2 x.2 ∧ ¬ GroupsGood enc e U rw cw grp val}
      ≤ ((e + 1 : ℕ) : ℝ≥0∞) / Fintype.card E
        + (((Fintype.card ι - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q := by
  have hd : MinDist (LinearMap.range enc) (Fintype.card ι - K) := hrange ▸ minDist_rsCode dom K
  have hca : CAOn Unit (LinearMap.range enc) e (e + 1) := caOn_third hd (by omega)
  exact groups_sound enc henc hd (by omega) le_rfl hca U rw cw grp val v w Q

/-! ## With the Merkle layer: the matrix extracted from the commit log -/

section Extracted

variable {Q D S Col : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D]

/-- **The verifier of one opening with several groups and its Merkle layer**, on the run of a three-phase prover
against the oracle `H`, the draws `(λ, ρ)` and the indices `J` (`x = (H, ((λ, ρ), J))`): `P₁` commits (its first
output is the root); `P₂` sees `(λ, ρ)` and answers the clear group vectors and the clear proximity vector; `P₃` sees
`J` and opens a column at each index. Accepted: every group's claim check, and at each sampled index the opening
verifies against the root and the opened column (read by `colVal`) agrees with every re-encoded group vector and the
re-encoded proximity vector. -/
def GroupsROAccepts [Fintype κ] [Fintype μ] [Fintype Cl] [DecidableEq G] (M : MerkleEnc Q D S Col)
    (colVal : Col → κ → E) {h : ℕ} (enc : (μ → E) →ₗ[E] (Fin (2 ^ h) → E)) (rw : Cl → κ → E) (cw : G → μ → E)
    (grp : Cl → G) (val : Cl → E) {nQ : ℕ} {St₁ St₂ : Type} (P₁ : OC Q D (D × St₁))
    (P₂ : St₁ → (Cl → E) → (κ → E) → OC Q D (St₂ × (G → μ → E) × (μ → E)))
    (P₃ : St₂ → (Fin nQ → Fin (2 ^ h)) → OC Q D (Fin nQ → MerkleOpening D S Col))
    (x : (Q → D) × (((Cl → E) × (κ → E)) × (Fin nQ → Fin (2 ^ h)))) : Prop :=
  let r := (P₂ (P₁.runLog x.1).1.2 x.2.1.1 x.2.1.2).run x.1
  let ops := (P₃ r.1 x.2.2).run x.1
  (∀ g ∈ Set.range grp, ∑ t, r.2.1 g t * cw g t = groupWant val grp x.2.1.1 g)
    ∧ ∀ k, M.Opens x.1 h (P₁.runLog x.1).1.1 (x.2.2 k) (ops k)
      ∧ (∀ g ∈ Set.range grp,
          enc (r.2.1 g) (x.2.2 k) = ∑ i, groupWeights rw grp x.2.1.1 g i * colVal (ops k).col i)
      ∧ enc r.2.2 (x.2.2 k) = ∑ i, x.2.1.2 i * colVal (ops k).col i

/-- **Several groups and the `λ` batching, with the matrix EXTRACTED from the commit log.** Under the hypotheses of
`groups_sound`, for any three-phase prover (`P₁` commits with at most `q₁` hash queries; `P₂` answers `(λ, ρ)` with at
most `q₂`; `P₃` opens the indices with at most `q₃`) against a uniform random oracle, the challenges uniform,
independent of it and drawn after the root: the verifier accepts while some claim is false of the message DECODED from
the extracted matrix with probability at most
`A/|E| + ((N − (e + 1))/N)^nQ + collBound T D + extGuess T q₁ D`, `N = 2^h`, `T = q₁ + (q₂ + q₃) + nQ(h + 2)`. -/
theorem groups_sound_extracted [Fintype E] [DecidableEq E] [Fintype κ] [DecidableEq κ] [Fintype μ] [Fintype Cl]
    [DecidableEq Cl] [DecidableEq G] (M : MerkleEnc Q D S Col) (colVal : Col → κ → E) (c₀ : Col) {h : ℕ}
    (enc : (μ → E) →ₗ[E] (Fin (2 ^ h) → E)) (henc : Function.Injective enc) {d e A : ℕ}
    (hd : MinDist (LinearMap.range enc) d) (h2 : 2 * e < d) (hA : e + 1 ≤ A)
    (hca : CAOn Unit (LinearMap.range enc) e A) (rw : Cl → κ → E) (cw : G → μ → E) (grp : Cl → G)
    (val : Cl → E) (nQ : ℕ) {St₁ St₂ : Type} (q₁ q₂ q₃ : ℕ) (P₁ : OC Q D (D × St₁)) (hP₁ : P₁.Bounded q₁)
    (P₂ : St₁ → (Cl → E) → (κ → E) → OC Q D (St₂ × (G → μ → E) × (μ → E)))
    (hP₂ : ∀ st lam ρ, (P₂ st lam ρ).Bounded q₂)
    (P₃ : St₂ → (Fin nQ → Fin (2 ^ h)) → OC Q D (Fin nQ → MerkleOpening D S Col))
    (hP₃ : ∀ st J, (P₃ st J).Bounded q₃) :
    (PMF.uniformOfFintype ((Q → D) × (((Cl → E) × (κ → E)) × (Fin nQ → Fin (2 ^ h))))).toOuterMeasure
        {x | GroupsROAccepts M colVal enc rw cw grp val P₁ P₂ P₃ x
          ∧ ¬ GroupsGood enc e (extractU M colVal c₀ (P₁.runLog x.1).2 h (P₁.runLog x.1).1.1) rw cw grp val}
      ≤ (A : ℝ≥0∞) / Fintype.card E
        + (((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ
        + (collBound (q₁ + (q₂ + q₃) + nQ * (h + 2)) D + extGuess (q₁ + (q₂ + q₃) + nQ * (h + 2)) q₁ D) := by
  classical
  set μ' := (PMF.uniformOfFintype ((Q → D) × (((Cl → E) × (κ → E)) × (Fin nQ → Fin (2 ^ h))))).toOuterMeasure
  -- the matrix, and the prover's vectors, as functions of the oracle
  let U : (Q → D) → κ → Fin (2 ^ h) → E := fun H => extractU M colVal c₀ (P₁.runLog H).2 h (P₁.runLog H).1.1
  let v : (Q → D) → G → (Cl → E) → (κ → E) → μ → E :=
    fun H g lam ρ => ((P₂ (P₁.runLog H).1.2 lam ρ).run H).2.1 g
  let w : (Q → D) → (Cl → E) → (κ → E) → μ → E := fun H lam ρ => ((P₂ (P₁.runLog H).1.2 lam ρ).run H).2.2
  -- the opened columns
  let ops : (Q → D) → ((Cl → E) × (κ → E)) → (Fin nQ → Fin (2 ^ h)) → Fin nQ → MerkleOpening D S Col :=
    fun H y J => (P₃ ((P₂ (P₁.runLog H).1.2 y.1 y.2).run H).1 J).run H
  -- S₁: the matrix-fixed event of `groups_sound`, for the extracted matrix
  let S₁ : Set ((Q → D) × (((Cl → E) × (κ → E)) × (Fin nQ → Fin (2 ^ h)))) :=
    {x | GroupsAccept enc (U x.1) rw cw grp val (v x.1) (w x.1) x.2.1.1 x.2.1.2 x.2.2
      ∧ ¬ GroupsGood enc e (U x.1) rw cw grp val}
  -- S₂: some opening verifies but is not the extracted column
  let S₂ : Set ((Q → D) × (((Cl → E) × (κ → E)) × (Fin nQ → Fin (2 ^ h)))) :=
    {x | ∃ k, M.Opens x.1 h (P₁.runLog x.1).1.1 (x.2.2 k) (ops x.1 x.2.1 x.2.2 k)
      ∧ M.extractCol (P₁.runLog x.1).2 h (x.2.2 k) (P₁.runLog x.1).1.1 ≠ some (ops x.1 x.2.1 x.2.2 k).col}
  have hsub : {x | GroupsROAccepts M colVal enc rw cw grp val P₁ P₂ P₃ x
      ∧ ¬ GroupsGood enc e (extractU M colVal c₀ (P₁.runLog x.1).2 h (P₁.runLog x.1).1.1) rw cw grp val}
      ⊆ S₁ ∪ S₂ := by
    rintro ⟨H, y, J⟩ ⟨⟨hclaims, hall⟩, hgood⟩
    by_cases hS₂ : (H, y, J) ∈ S₂
    · exact Or.inr hS₂
    · left
      have hext : ∀ k, M.extractCol (P₁.runLog H).2 h (J k) (P₁.runLog H).1.1 = some (ops H y J k).col := by
        intro k
        by_contra hne
        exact hS₂ ⟨k, (hall k).1, hne⟩
      have hU : ∀ k i, U H i (J k) = colVal (ops H y J k).col i := by
        intro k i
        show colVal ((M.extractCol (P₁.runLog H).2 h (J k) (P₁.runLog H).1.1).getD c₀) i = _
        rw [hext k]
        rfl
      refine ⟨⟨hclaims, fun g hg k => ?_, fun k => ?_⟩, hgood⟩
      · rw [comb_apply]
        refine ((hall k).2.1 g hg).trans (sum_congr rfl (fun i _ => ?_))
        rw [hU k i]
      · rw [comb_apply]
        refine (hall k).2.2.trans (sum_congr rfl (fun i _ => ?_))
        rw [hU k i]
  -- S₁: `groups_sound` for each oracle
  have h₁ : μ' S₁ ≤ (A : ℝ≥0∞) / Fintype.card E
      + (((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ :=
    prob_prod_le_of_forall_fst _ _ (fun H =>
      groups_sound enc henc hd h2 hA hca (U H) rw cw grp val (v H) (w H) nQ)
  -- S₂: `extract_sound` for each draw of the challenges
  have h₂ : μ' S₂ ≤ collBound (q₁ + (q₂ + q₃) + nQ * (h + 2)) D
      + extGuess (q₁ + (q₂ + q₃) + nQ * (h + 2)) q₁ D := by
    refine prob_prod_le_of_forall_snd _ _ (fun ω => ?_)
    let B : St₁ → OC Q D (Fin nQ → ℕ × MerkleOpening D S Col) := fun st =>
      (P₂ st ω.1.1 ω.1.2).bind (fun r => (P₃ r.1 ω.2).bind (fun o => .ret (fun k => ((ω.2 k : ℕ), o k))))
    have hB : ∀ st, (B st).Bounded (q₂ + q₃) := fun st =>
      ((hP₂ st ω.1.1 ω.1.2).bind (fun r => (hP₃ r.1 ω.2).bind
        (fun o => (show (OC.ret (fun k => ((ω.2 k : ℕ), o k)) : OC Q D _).Bounded 0 from trivial)))).mono
        (by omega)
    have hrun : ∀ H st, (B st).run H
        = fun k => ((ω.2 k : ℕ), ((P₃ ((P₂ st ω.1.1 ω.1.2).run H).1 ω.2).run H) k) := by
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
  calc μ' {x | GroupsROAccepts M colVal enc rw cw grp val P₁ P₂ P₃ x
          ∧ ¬ GroupsGood enc e (extractU M colVal c₀ (P₁.runLog x.1).2 h (P₁.runLog x.1).1.1) rw cw grp val}
      ≤ μ' (S₁ ∪ S₂) := MeasureTheory.measure_mono hsub
    _ ≤ μ' S₁ + μ' S₂ := MeasureTheory.measure_union_le _ _
    _ ≤ _ := add_le_add h₁ h₂

end Extracted

end ZK60.Sound
