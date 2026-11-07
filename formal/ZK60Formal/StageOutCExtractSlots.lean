/-
D63, Lean lane L12 (2026-11-07): **stage OUT-C's margin sumcheck as the code writes it** (OUTC-03 PD, private,
hosted by OUTC-04 LZC; stage_out_c.rs:338-370), and its pull-back to `OutCClauses.host_pd`.

* PD sums `y(i)·w_Δ(i)` over the `d_pad` cube (`y` read at its natural `d_pad` with the lift bits fixed, `w_Δ` the
  public int16 margin vector, zero on the pad channels) on the prover's published scalar `S`;
* LZC is a HOST: its clauses are the limb plane's single byte-lookup helper `h·(α − (limb + g)) − 1` and the pad
  `(1 − s)·limb` (`LzcClause`, `lzcW`), and its host term is `G(z)·limb(z) + u0(z)·(b + c)` (`lzcHost`;
  `G(z) = σ·256^(z − 32)` on the margin limbs, `0` elsewhere), on the claim `ν·S`.

What is proved:
* `lzcW_deg`, `lzcHost_deg`: degrees `≤ 3` and `≤ 4` (the code declares LZC's round degree 4, PD's 2);
* `pd_sum`, `lzcHost_sum`: on the cube the sums are the tables' own;
* **`margin_sound`**: over PD's rounds and then LZC's `μ`, `ν`, `τ` and rounds, for ANY published `S` and ANY provers
  (LZC's may depend on PD's challenges), both slots accept while the hosted identity
  `Σ_b y(b)·w(b) = Σ_z (G(z)·limb(z) + u0(z)·(b + c))` or one of LZC's clauses fails with probability at most
  `2·nd/|K| + (2 + nl + 4·nl)/|K|` (`sumcheck_sound` for PD, `host_sound` for LZC);
* **`margin_host_pd`**: when the tables are the base field's images through the layout maps (the live channels, the
  margin limbs, `u0` at entry 0), the hosted identity IS `OutCClauses.host_pd`, the identity `outC_sat_of_clauses`
  turns into `VerdictRel`.

Modelling boundary: as in `StageExtractCore.lean` (the openings, the CFS mask and the `M` functionals that cancel the
masked scalars, the extension round, Fiat–Shamir).
-/
import ZK60Formal.StageInExtractSlots
import ZK60Formal.StageOutCExtract

namespace ZK60.StageX

open scoped ENNReal
open Polynomial Finset ZK60.Sound

/-- LZC's two clauses: the limb plane's single byte-lookup helper and the pad (stage_out_c.rs:364-367). -/
inductive LzcClause
  | helper
  | pad
  deriving DecidableEq

instance : Fintype LzcClause :=
  ⟨{.helper, .pad}, fun x => by cases x <;> simp⟩

section Margin

variable {K : Type} [Field K]

/-- LZC's clauses on the tables' extensions: `h·(α − (limb + g)) − 1` (`helper_sum` with one single) and
`(1 − s)·limb`. -/
def lzcW {n : ℕ} (limb h s : (Fin n → Bool) → K) (α g : K) : LzcClause → (Fin n → K) → K
  | .helper => fun x => mleAt h x * (α - (mleAt limb x + g)) - 1
  | .pad => fun x => (1 - mleAt s x) * mleAt limb x

/-- LZC's host term `G·limb + u0·(b + c)` on the tables' extensions. -/
def lzcHost {n : ℕ} (Gm u0 limb : (Fin n → Bool) → K) (kc : K) (x : Fin n → K) : K :=
  mleAt Gm x * mleAt limb x + mleAt u0 x * kc

theorem lzcW_deg {n : ℕ} (limb h s : (Fin n → Bool) → K) (α g : K) : ∀ j, IndDegLE 3 (lzcW limb h s α g j)
  | .helper => by
      show IndDegLE 3 (fun x => mleAt h x * (α - (mleAt limb x + g)) - 1)
      exact IndDegLE.sub (IndDegLE.mono (IndDegLE.mul (mle_deg h le_rfl)
        (IndDegLE.sub (IndDegLE.const α) (IndDegLE.add (mle_deg limb le_rfl) (IndDegLE.const g))))
        (by norm_num)) (IndDegLE.const 1)
  | .pad => by
      show IndDegLE 3 (fun x => (1 - mleAt s x) * mleAt limb x)
      exact IndDegLE.mono (IndDegLE.mul (IndDegLE.sub (IndDegLE.const 1) (mle_deg s le_rfl))
        (mle_deg limb le_rfl)) (by norm_num)

theorem lzcHost_deg {n : ℕ} (Gm u0 limb : (Fin n → Bool) → K) (kc : K) :
    IndDegLE (3 + 1) (lzcHost Gm u0 limb kc) :=
  IndDegLE.mono (IndDegLE.add (IndDegLE.mul (mle_deg Gm le_rfl) (mle_deg limb le_rfl))
    (IndDegLE.mul (mle_deg u0 le_rfl) (IndDegLE.const (d := 1) kc))) (by norm_num)

theorem lzcHost_sum {n : ℕ} (Gm u0 limb : (Fin n → Bool) → K) (kc : K) :
    cubeSum (lzcHost Gm u0 limb kc) = ∑ z, (Gm z * limb z + u0 z * kc) := by
  simp only [cubeSum, lzcHost, mleAt_bit]

theorem pd_sum {n : ℕ} (Y Wd : (Fin n → Bool) → K) :
    cubeSum (fun x => mleAt Y x * mleAt Wd x) = ∑ b, Y b * Wd b := by
  simp only [cubeSum, mleAt_bit]

/-- LZC's clauses vanish on the whole limb plane. -/
def LzcHolds {n : ℕ} (limb h s : (Fin n → Bool) → K) (α g : K) : Prop :=
  ∀ j, ∀ b : Fin n → Bool, lzcW limb h s α g j (bitv b) = 0

/-- **The margin sumcheck, sound** (PD private, hosted by LZC). For tables fixed before both slots' challenges (all
in `A_out`, `H_out`), ANY published scalar `S` and ANY provers: PD accepts `S`, LZC accepts `ν·S`, and yet the hosted
margin identity or one of LZC's clauses fails, with probability at most `2·nd/|K| + (2 + nl + 4·nl)/|K|`. -/
theorem margin_sound [Fintype K] [DecidableEq K] (hd4 : 3 + 1 < ringChar K) {nd nl : ℕ}
    (Y Wd : (Fin nd → Bool) → K) (S : K) (Pp : Prover K 2 nd) (limb h s Gm u0 : (Fin nl → Bool) → K) (α g kc : K)
    (Pl : (Fin nd → K) → ((LzcClause → K) × K) × (Fin nl → K) → Prover K (3 + 1) nl) :
    pr (fun ω : (Fin nd → K) × ((((LzcClause → K) × K) × (Fin nl → K)) × (Fin nl → K)) =>
        Accepts nd (fun x => mleAt Y x * mleAt Wd x) S Pp ω.1 ∧
        Accepts nl (fun x => eqPoly ω.2.1.2 x * batched (lzcW limb h s α g) ω.2.1.1.1 x +
            ω.2.1.1.2 * lzcHost Gm u0 limb kc x) (ω.2.1.1.2 * S) (Pl ω.1 ω.2.1) ω.2.2 ∧
        ¬ ((∑ b, Y b * Wd b = ∑ z, (Gm z * limb z + u0 z * kc)) ∧ LzcHolds limb h s α g))
      ≤ ((nd * 2 : ℕ) : ℝ≥0∞) / Fintype.card K + ((2 + (nl + nl * (3 + 1)) : ℕ) : ℝ≥0∞) / Fintype.card K := by
  classical
  have hd2 : 2 < ringChar K := lt_trans (by norm_num) hd4
  have hsub : ∀ ω : (Fin nd → K) × ((((LzcClause → K) × K) × (Fin nl → K)) × (Fin nl → K)),
      (Accepts nd (fun x => mleAt Y x * mleAt Wd x) S Pp ω.1 ∧
        Accepts nl (fun x => eqPoly ω.2.1.2 x * batched (lzcW limb h s α g) ω.2.1.1.1 x +
            ω.2.1.1.2 * lzcHost Gm u0 limb kc x) (ω.2.1.1.2 * S) (Pl ω.1 ω.2.1) ω.2.2 ∧
        ¬ ((∑ b, Y b * Wd b = ∑ z, (Gm z * limb z + u0 z * kc)) ∧ LzcHolds limb h s α g)) →
      (Accepts nd (fun x => mleAt Y x * mleAt Wd x) S Pp ω.1 ∧ S ≠ ∑ b, Y b * Wd b) ∨
      (Accepts nl (fun x => eqPoly ω.2.1.2 x * batched (lzcW limb h s α g) ω.2.1.1.1 x +
            ω.2.1.1.2 * lzcHost Gm u0 limb kc x) (ω.2.1.1.2 * S) (Pl ω.1 ω.2.1) ω.2.2 ∧
        ((∃ j, ∃ b : Fin nl → Bool, lzcW limb h s α g j (bitv b) ≠ 0) ∨ cubeSum (lzcHost Gm u0 limb kc) ≠ S)) := by
    rintro ω ⟨hp, hl, hbad⟩
    by_cases hS : S = ∑ b, Y b * Wd b
    · refine Or.inr ⟨hl, ?_⟩
      by_cases hc : LzcHolds limb h s α g
      · refine Or.inr ?_
        rw [lzcHost_sum, hS]
        exact fun he => hbad ⟨he.symm, hc⟩
      · refine Or.inl ?_
        by_contra hn
        push Not at hn
        exact hc hn
    · exact Or.inl ⟨hp, hS⟩
  refine (pr_mono hsub).trans ((pr_or_le _ _).trans (add_le_add ?_ ?_))
  · -- PD: a false published sum
    refine (pr_fst_le (fun ρ => Accepts nd (fun x => mleAt Y x * mleAt Wd x) S Pp ρ ∧ S ≠ ∑ b, Y b * Wd b)).trans ?_
    by_cases hS : S = ∑ b, Y b * Wd b
    · exact pr_le_of_not _ (fun ρ hρ => hρ.2 hS) _
    · refine (pr_mono (E' := fun ρ => Accepts nd (fun x => mleAt Y x * mleAt Wd x) S Pp ρ)
        (fun ρ hρ => hρ.1)).trans ?_
      refine sumcheck_sound hd2 (IndDegLE.mul (mle_deg Y le_rfl) (mle_deg Wd le_rfl)) ?_ Pp
      rw [pd_sum]
      exact hS
  · -- LZC: a false clause or a false hosted sum, at every PD challenge
    refine pr_prod_le _ (fun ρ => ?_)
    by_cases hb : (∃ j, ∃ b : Fin nl → Bool, lzcW limb h s α g j (bitv b) ≠ 0) ∨
        cubeSum (lzcHost Gm u0 limb kc) ≠ S
    · refine (pr_mono (E' := fun ω : (((LzcClause → K) × K) × (Fin nl → K)) × (Fin nl → K) =>
        Accepts nl (fun x => eqPoly ω.1.2 x * batched (lzcW limb h s α g) ω.1.1.1 x + ω.1.1.2 * lzcHost Gm u0 limb kc x)
          (ω.1.1.2 * S) (Pl ρ ω.1) ω.2) (fun ω hω => hω.1)).trans ?_
      exact host_sound hd4 (lzcW limb h s α g) (lzcW_deg limb h s α g) (lzcHost Gm u0 limb kc)
        (lzcHost_deg Gm u0 limb kc) S hb (Pl ρ)
    · exact pr_le_of_not _ (fun ω hω => hb hω.2) _

end Margin

section PullBack

open ZK60.Circuit ZK60.Out

variable {K : Type} [Field K]

/-- **The hosted margin identity is `OutCClauses.host_pd`.** With the PD tables the images of the live channels'
words `y_i` and the margin vector `w_Δ(i)` (zero on the pad channels), the LZC tables the images of the margin limbs
`ml_k` at their entries `mpos k` (`32 + k`) with `G = σ·2^(8k)` there and zero elsewhere, `u0` the indicator of entry
`z0`, and the public constant the image of `b + c`: the identity on `K` is the base-field identity
`σ·δ + (b + c) = Σ_i y_i·w_Δ(i)`, `δ` the margin limbs recomposed. -/
theorem margin_host_pd (φ : GF →+* K) {d nd nl L : ℕ} (b : ℕ) (c : ℤ) (y : Fin d → GF) (wΔ : Fin d → ℤ)
    (dpos : Fin d → (Fin nd → Bool)) (hdpos : Function.Injective dpos) (Y Wd : (Fin nd → Bool) → K)
    (hY : ∀ i, Y (dpos i) = φ (y i)) (hW : ∀ i, Wd (dpos i) = φ (wΔ i : GF))
    (hW0 : ∀ x, x ∉ Set.range dpos → Wd x = 0) (mpos : Fin L → (Fin nl → Bool)) (hmpos : Function.Injective mpos)
    (z0 : Fin nl → Bool) (Gm u0 limb : (Fin nl → Bool) → K) (ml : Fin L → GF)
    (hG : ∀ j, Gm (mpos j) = φ (sigOf b * (2 : GF) ^ (8 * (j : ℕ)))) (hG0 : ∀ z, z ∉ Set.range mpos → Gm z = 0)
    (hu : ∀ z, u0 z = if z = z0 then 1 else 0) (hl : ∀ j, limb (mpos j) = φ (ml j))
    (hsum : ∑ x, Y x * Wd x = ∑ z, (Gm z * limb z + u0 z * φ ((b : GF) + (c : GF)))) :
    sigOf b * limbSum ml + ((b : GF) + (c : GF)) = ∑ i, y i * (wΔ i : GF) := by
  classical
  have h1 : ∑ x, Y x * Wd x = φ (∑ i, y i * (wΔ i : GF)) := by
    rw [cube_sum_of_pad dpos hdpos (fun x => Y x * Wd x) (fun x hx => by rw [hW0 x hx, mul_zero]), map_sum]
    exact Finset.sum_congr rfl (fun i _ => by rw [hY, hW, map_mul])
  have h3 : ∑ z, u0 z * φ ((b : GF) + (c : GF)) = φ ((b : GF) + (c : GF)) := by
    simp only [hu, ite_mul, one_mul, zero_mul, Finset.sum_ite_eq', Finset.mem_univ, ite_true]
  have h4 : ∑ z, Gm z * limb z = φ (sigOf b * limbSum ml) := by
    rw [cube_sum_of_pad mpos hmpos (fun z => Gm z * limb z) (fun z hz => by rw [hG0 z hz, zero_mul])]
    unfold limbSum
    rw [Finset.mul_sum, map_sum]
    exact Finset.sum_congr rfl (fun j _ => by rw [hG, hl, ← map_mul, mul_assoc])
  have h2 : ∑ z, (Gm z * limb z + u0 z * φ ((b : GF) + (c : GF))) =
      φ (sigOf b * limbSum ml + ((b : GF) + (c : GF))) := by
    rw [Finset.sum_add_distrib, h3, h4, ← map_add]
  exact (φ.injective (h1.symm.trans (hsum.trans h2))).symm

end PullBack

end ZK60.StageX
