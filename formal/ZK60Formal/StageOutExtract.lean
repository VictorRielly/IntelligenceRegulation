/-
D63, Lean lane L12 (2026-11-07): **stage OUT (the next token), the L3 part** (ASSEMBLY §4.2 item e, L1L2 findings
§16): from the stage verifier's accepted checks to `OutSat` (CircuitOut.lean), the final norm, the head and the keyed
greedy argmax.

The code (stage_out.rs:290-560): the final norm is OUT-C's (`FNormClauses`, StageOutCExtract.lean); the head and the
argmax are
* SO_HEAD (private): `Σ_i y(i)·W'(r_j, i)`, `r_j` a fresh point of the vocabulary cube `Vo` drawn AFTER `A_out` and
  `H_out` (stage_out.rs:411-419), `W'(r_j, i) = Σ_{z<V} eq(r_j, z)·m_z·W[z][i]` (`head_fold`);
* SO_VZC (host of HEAD): `e(1 − e)`, the keyed-difference limbs' helpers, the pad, and the host term
  `ν·eq(r_j, z)·l*(z)`, `l*(z) = s(z)·(M + 2^{−v}·(z − tok − δ(z)))` (:451-489). Hosting gives
  `Σ_z eq(r_j, z)·l*(z) = Σ_z eq(r_j, z)·l(z)`, `l(z) = Σ_i y_i·m_z·W[z][i]`: the two tables' extensions agree at `r_j`;
* SO_RSEL (standalone, claim 0): `Σ_z [s(z)·e(z)·(c₁ + c₂·z + c₃·δ(z)) − u0(z)·(c₁ + c₂·tok)]` with fresh `c`
  (:493-508): `c₁·(Σe − 1) + c₂·(Σ e·z − tok) + c₃·Σ e·δ = 0`;
* SO_IOOUT: the output token endpoint is `u0·tok` (:532-538).

What is proved:
* **`head_sz_prob`**: if the tables `l*` and `l` (fixed before `r_j`) differ somewhere, their extensions agree at a
  uniform `r_j` with probability at most `log V_pad/|K|` — the head's Schwartz–Zippel step, which reads the hosted MLE
  identity as `l*_z = l_z` at every `z < V` (`head_tables_eq`);
* **`rsel_batch_sound`** and `rsel_cube_sum`: the batched claim gives the three identities `Σe = 1`, `Σ e·z = tok`,
  `Σ e·δ = 0` except with probability `1/|K|` over `c`;
* **`out_sat_of_clauses`**: the final norm's clauses, VZC's per-entry clauses, the three identities and the limb bytes
  give `OutSat`;
* `out_endpoint_word`: SO_IOOUT ties the output endpoint's word 0 to the token word `A_TOK`.
-/
import ZK60Formal.StageOutCExtract

namespace ZK60.StageX

open scoped ENNReal
open Polynomial Finset ZK60.Sound

/-! ## The head's Schwartz–Zippel step -/

section Head

variable {B K : Type} [Field B] [Field K]

/-- **The head's Schwartz–Zippel step.** For the keyed values `l*` (VZC's `lstar`) and the head values `l` on the
`Vo` cube (`2^n` entries), both functions of `A_out` alone and so fixed before `r_j`: if they differ somewhere, their
multilinear extensions agree at a uniform `r_j` with probability at most `n/|K|`. -/
theorem head_sz_prob [Fintype K] (φ : B →+* K) {n : ℕ} (Ls Lh : (Fin n → Bool) → B) :
    pr (fun r : Fin n → K => mleAt (fun b => φ (Ls b)) r = mleAt (fun b => φ (Lh b)) r ∧ Ls ≠ Lh)
      ≤ (n : ℝ≥0∞) / Fintype.card K := by
  by_cases h : Ls = Lh
  · exact pr_le_of_not _ (fun r hr => hr.2 h) _
  · refine (pr_mono (E' := fun r => mleAt (fun b => φ (Ls b)) r = mleAt (fun b => φ (Lh b)) r)
      (fun r hr => hr.1)).trans ?_
    exact mle_eq_prob _ _ (fun he => h (funext fun b => φ.injective (congrFun he b)))

/-- Equal cube tables are equal at the logical entries `vpos z`. -/
theorem head_tables_eq {Bt : Type} {V n : ℕ} (vpos : Fin V → (Fin n → Bool)) {Ls Lh : (Fin n → Bool) → Bt} (h : Ls = Lh)
    (z : Fin V) : Ls (vpos z) = Lh (vpos z) := by
  rw [h]

end Head

/-! ## SO_RSEL's batched claim -/

section Rsel

variable {K : Type} [Field K]

/-- The three residues of the selector: `Σe − 1`, `Σ e·z − tok`, `Σ e·δ`. -/
def rselRes {V : ℕ} (e δ : Fin V → K) (tok : K) : Fin 3 → K :=
  ![∑ z, e z - 1, ∑ z, e z * ((z : ℕ) : K) - tok, ∑ z, e z * δ z]

/-- **SO_RSEL's cube sum** (stage_out.rs:503-506): over the `Vo` cube, with the live selector `s` (1 exactly at the
logical entries `vpos z`), the index column `ι` (`z` there), `u0` the indicator of entry `b0`, the claim's polynomial
sums to `c₁·(Σe − 1) + c₂·(Σ e·z − tok) + c₃·Σ e·δ`. -/
theorem rsel_cube_sum {Cv : Type} [Fintype Cv] [DecidableEq Cv] {V : ℕ} (vpos : Fin V → Cv)
    (hvpos : Function.Injective vpos) (b0 : Cv) (s io u0 ec dc : Cv → K) (tok : K) (c : Fin 3 → K)
    (hs1 : ∀ z, s (vpos z) = 1) (hs0 : ∀ b, b ∉ Set.range vpos → s b = 0) (hio : ∀ z, io (vpos z) = ((z : ℕ) : K))
    (hu : ∀ b, u0 b = if b = b0 then 1 else 0) :
    ∑ b, (s b * ec b * (c 0 + c 1 * io b + c 2 * dc b) - u0 b * (c 0 + c 1 * tok))
      = ∑ k, c k * rselRes (fun z => ec (vpos z)) (fun z => dc (vpos z)) tok k := by
  rw [Finset.sum_sub_distrib]
  have h1 : ∑ b, s b * ec b * (c 0 + c 1 * io b + c 2 * dc b)
      = ∑ z, s (vpos z) * ec (vpos z) * (c 0 + c 1 * io (vpos z) + c 2 * dc (vpos z)) :=
    cube_sum_of_pad vpos hvpos (fun b => s b * ec b * (c 0 + c 1 * io b + c 2 * dc b))
      (fun b hb => by rw [hs0 b hb, zero_mul, zero_mul])
  have h2 : ∑ b, u0 b * (c 0 + c 1 * tok) = c 0 + c 1 * tok := by
    simp only [hu, ite_mul, one_mul, zero_mul, Finset.sum_ite_eq', Finset.mem_univ, ite_true]
  rw [h1, h2]
  have h3 : ∑ z, s (vpos z) * ec (vpos z) * (c 0 + c 1 * io (vpos z) + c 2 * dc (vpos z))
      = ∑ z, (c 0 * ec (vpos z) + c 1 * (ec (vpos z) * ((z : ℕ) : K)) + c 2 * (ec (vpos z) * dc (vpos z))) :=
    Finset.sum_congr rfl (fun z _ => by rw [hs1, hio]; ring)
  rw [h3, Finset.sum_add_distrib, Finset.sum_add_distrib, ← Finset.mul_sum, ← Finset.mul_sum, ← Finset.mul_sum]
  simp only [rselRes, Fin.sum_univ_three, Matrix.cons_val_zero, Matrix.cons_val_one, Matrix.cons_val_two,
    Matrix.head_cons, Matrix.tail_cons]
  ring

/-- **SO_RSEL, sound.** For `e`, `δ`, `tok` fixed before the coefficients `c` (all in `A_out`): if some residue is
nonzero, the batched value vanishes with probability at most `1/|K|` over uniform `c` (`batch_prob`); the RSEL
sumcheck itself (`sumcheck_sound`, claim `0`) certifies the batched value. -/
theorem rsel_batch_sound [Fintype K] [DecidableEq K] {V : ℕ} (e δ : Fin V → K) (tok : K) :
    pr (fun c : Fin 3 → K => ∑ k, c k * rselRes e δ tok k = 0 ∧ ¬ ∀ k, rselRes e δ tok k = 0)
      ≤ (1 : ℝ≥0∞) / Fintype.card K := by
  classical
  by_cases h : ∀ k, rselRes e δ tok k = 0
  · exact pr_le_of_not _ (fun c hc => hc.2 h) _
  · push Not at h
    refine (pr_mono (E' := fun c : Fin 3 → K => ∑ k, c k * rselRes e δ tok k = 0) (fun c hc => hc.1)).trans ?_
    exact batch_prob (rselRes e δ tok) h

/-- The three residues vanish: the three identities. -/
theorem rselRes_zero {V : ℕ} {e δ : Fin V → K} {tok : K} (h : ∀ k, rselRes e δ tok k = 0) :
    ∑ z, e z = 1 ∧ ∑ z, e z * ((z : ℕ) : K) = tok ∧ ∑ z, e z * δ z = 0 := by
  have h0 := h 0
  have h1 := h 1
  have h2 := h 2
  simp only [rselRes, Matrix.cons_val_zero, Matrix.cons_val_one, Matrix.cons_val_two, Matrix.head_cons,
    Matrix.tail_cons] at h0 h1 h2
  exact ⟨sub_eq_zero.mp h0, sub_eq_zero.mp h1, h2⟩

end Rsel

/-! ## The clauses at the logical positions, and `OutSat` -/

section Clauses

open ZK60 ZK60.Model ZK60.Circuit ZK60.Block ZK60.Out

/-- **Stage OUT's clauses at the logical positions**, for the stage's own `x` and the token word `tok` (`A_TOK`):
the final norm's (`FNormClauses`); VZC's per-entry clauses at every `z < V` — `e(1 − e) = 0`, the keyed difference's
limbs bytes, and the host identity `l*_z = l_z` (the hosted MLE identity at `r_j` read per entry, `head_sz_prob`);
and RSEL's three identities (`rsel_batch_sound`). -/
structure OutClauses {n : ℕ} (P : OutPublic n) (x : Fin n → GF) (tok : GF) extends
    FNormClauses P.ceps P.cn P.g0 P.tn x where
  M : GF
  e : Fin P.V → GF
  lam : Fin P.V → Fin P.limbs → GF
  bool : ∀ z, e z * (1 - e z) = 0
  host : ∀ z : Fin P.V, M + ((2 : GF) ^ P.vlog)⁻¹ * (((z : ℕ) : GF) - tok - limbSum (lam z)) =
    ∑ i, y i * (((P.mult z : ℤ) * P.head z i : ℤ) : GF)
  sum1 : ∑ z, e z = 1
  sumz : ∑ z : Fin P.V, e z * ((z : ℕ) : GF) = tok
  sumd : ∑ z, e z * limbSum (lam z) = 0
  b_lam : ∀ z j, InRange 8 (lam z j)

/-- **Stage OUT's clauses give `OutSat`**: the final norm relation and the keyed argmax relation on the hosted head
values, for the token word. -/
theorem out_sat_of_clauses {n : ℕ} (P : OutPublic n) (x : Fin n → GF) (tok : GF) (C : OutClauses P x tok) :
    OutSat P x tok :=
  ⟨C.D, C.y, fnormRel_of_clauses C.toFNormClauses, C.M, C.e, fun z => limbSum (C.lam z),
    ⟨C.bool, fun z => limbSum_byteLimbs (C.b_lam z), C.host, C.sum1, C.sumz, C.sumd⟩⟩

/-- **SO_IOOUT's identity** (`end − u0·tok`, over the output endpoint's whole plane): the output token endpoint's
word `w0` is the token word, every other word zero. -/
theorem out_endpoint_word {W : Type} [DecidableEq W] (w0 : W) (ep : W → GF) (tok : GF) (u0 : W → GF)
    (hu : ∀ w, u0 w = if w = w0 then 1 else 0) (hio : ∀ w, ep w - u0 w * tok = 0) :
    ep w0 = tok ∧ ∀ w, w ≠ w0 → ep w = 0 := by
  constructor
  · have h := hio w0
    rw [hu, ite_eq_left rfl, one_mul] at h
    exact sub_eq_zero.mp h
  · intro w hw
    have h := hio w
    rw [hu, ite_eq_right hw, zero_mul, sub_zero] at h
    exact h

end Clauses

end ZK60.StageX
