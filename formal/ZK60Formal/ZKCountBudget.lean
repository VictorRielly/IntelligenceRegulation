/-
D63 step L19 (Statement 2, zero knowledge), part 6: the budget with every query at its own rate, against the approved
`εzkTarget q R = q·2^-128 + R·2^-120`, for EVERY `q` and EVERY `R`.

The per-step error of the weighted hybrid (`ZKCountHyb`, from `ZKCountStep.oneStepW_of_fsModel`) in rate form
(`wStep`): `2(q·δp + j·ωp) + 4·εc + 2(q·δh + R·ωh)`, where
* `δp` (`δh`): one distinguisher query's chance of hitting a programmed point before the request (a hidden point
  after it), the WORST single query;
* `ωp` (`ωh`): one other receipt's honest prover's chance, over ALL its queries each at its own kind's rate;
* `εc`: two points colliding or one landing in the dependency set.

* `fsStepW_le_wStep`: the counted error of `oneStepW_of_fsModel` is at most `wStep`;
* **`wBudget_le`**: `Σ_{j<R} wStep ≤ εzkTarget q R` for every `q` and every `R ≤ 2^r` when
  `2^(r+1)·(δp + δh) ≤ 2^-128` and `2^(r+1)·(ωp + ωh) + 4·εc ≤ 2^-120`;
* **`wBudget_every_R`**: with `δp + δh ≤ 2^-249`, `ωp + ωh ≤ 2^-242` and `εc ≤ 2^-124`, the error capped at `1` is
  within `εzkTarget q R` for EVERY `q` and EVERY `R` (above `2^120` receipts the target is at least `1`);
* **`zk_every_R`**: the assembled statement (`Statements.lean`'s `ZeroKnowledge`, the stand-in simulator), every
  instance obligation an explicit hypothesis, the error within the approved target with NO receipt cap;
* `ZKKinds` (a receipt's counts by hash kind: transcript points and their multiplicity, column points, leaves, nodes,
  the bits of freshness of a column point, the prover's queries by kind), its rates, and **`ZKKinds.every_R`**: a
  shape criterion in powers of two that gives the three conditions (`qpT·mT ≤ 2^13`, `mT ≤ 2^4`, the other counts
  `≤ 2^c` with `2c + 252` bits of column freshness); **`ZKKinds.cap_R`**: the cap `R ≤ 2^(133 − b)` when only
  `qpT·mT ≤ 2^b` (finding L19-2: the term that blocks a whole classify run as one receipt), `RunK.cap_112`;
* `W16R2K.kinds`, **`W16R2K.every_R`**: W16R2's block at the ESTIMATED kinds meets the criterion.

Every premise is an explicit hypothesis.
-/
import ZK60Formal.ZKCountHyb

namespace ZK60.ZKCount

open scoped ENNReal
open Finset ZK60.ZKW16 ZK60.ZKHybrid

/-! ## The step in rate form -/

/-- **The per-step error, every query at its own rate.** -/
noncomputable def wStep (δp ωp δh ωh εc : ℝ≥0∞) (q R j : ℕ) : ℝ≥0∞ :=
  2 * ((q : ℝ≥0∞) * δp + (j : ℝ≥0∞) * ωp) + 4 * εc + 2 * ((q : ℝ≥0∞) * δh + (R : ℝ≥0∞) * ωh)

/-- `oneStepW_of_fsModel`'s counted error at the hybrid's budgets, in rate form. -/
theorem fsStepW_le_wStep (q R j Km Wp Kc KUm Wpa NCV NC : ℕ) (δp ωp δh ωh εc : ℝ≥0∞)
    (hδp : (Km : ℝ≥0∞) / NCV ≤ δp) (hωp : (Wp : ℝ≥0∞) / NCV ≤ ωp) (hεc : (Kc : ℝ≥0∞) / NCV ≤ εc)
    (hδh : (KUm : ℝ≥0∞) / NC ≤ δh) (hωh : (Wpa : ℝ≥0∞) / NC ≤ ωh) :
    (((2 * ((q * Km + j * Wp) + 2 * Kc)) : ℕ) : ℝ≥0∞) / NCV + (((2 * (q * KUm + R * Wpa)) : ℕ) : ℝ≥0∞) / NC
      ≤ wStep δp ωp δh ωh εc q R j := by
  have e1 : (((2 * ((q * Km + j * Wp) + 2 * Kc)) : ℕ) : ℝ≥0∞) / NCV
      = 2 * ((q : ℝ≥0∞) * ((Km : ℝ≥0∞) / NCV) + (j : ℝ≥0∞) * ((Wp : ℝ≥0∞) / NCV)) + 4 * ((Kc : ℝ≥0∞) / NCV) := by
    push_cast
    rw [div_eq_mul_inv, div_eq_mul_inv, div_eq_mul_inv, div_eq_mul_inv]
    ring
  have e2 : (((2 * (q * KUm + R * Wpa)) : ℕ) : ℝ≥0∞) / NC
      = 2 * ((q : ℝ≥0∞) * ((KUm : ℝ≥0∞) / NC) + (R : ℝ≥0∞) * ((Wpa : ℝ≥0∞) / NC)) := by
    push_cast
    rw [div_eq_mul_inv, div_eq_mul_inv, div_eq_mul_inv]
    ring
  rw [e1, e2]
  unfold wStep
  gcongr

/-! ## The budget -/

/-- **The budget meets the approved target for every `q` and every `R ≤ 2^r`**, given
`2^(r+1)·(δp + δh) ≤ 2^-128` and `2^(r+1)·(ωp + ωh) + 4·εc ≤ 2^-120`. -/
theorem wBudget_le (q R r : ℕ) (hR : R ≤ 2 ^ r) (δp ωp δh ωh εc : ℝ≥0∞)
    (hA : 2 ^ (r + 1) * (δp + δh) ≤ (2⁻¹ : ℝ≥0∞) ^ 128)
    (hB : 2 ^ (r + 1) * (ωp + ωh) + 4 * εc ≤ (2⁻¹ : ℝ≥0∞) ^ 120) :
    ∑ j ∈ range R, wStep δp ωp δh ωh εc q R j ≤ εzkTarget q R := by
  have hR' : (R : ℝ≥0∞) ≤ 2 ^ r := by exact_mod_cast hR
  have hterm : ∀ j ∈ range R, wStep δp ωp δh ωh εc q R j
      ≤ (q : ℝ≥0∞) * (2 * (δp + δh)) + (2 * ((R : ℝ≥0∞) * (ωp + ωh)) + 4 * εc) := by
    intro j hj
    have hjR : (j : ℝ≥0∞) ≤ R := by exact_mod_cast (mem_range.mp hj).le
    unfold wStep
    calc 2 * ((q : ℝ≥0∞) * δp + (j : ℝ≥0∞) * ωp) + 4 * εc + 2 * ((q : ℝ≥0∞) * δh + (R : ℝ≥0∞) * ωh)
        ≤ 2 * ((q : ℝ≥0∞) * δp + (R : ℝ≥0∞) * ωp) + 4 * εc + 2 * ((q : ℝ≥0∞) * δh + (R : ℝ≥0∞) * ωh) := by
          gcongr
      _ = (q : ℝ≥0∞) * (2 * (δp + δh)) + (2 * ((R : ℝ≥0∞) * (ωp + ωh)) + 4 * εc) := by ring
  have h2r : (2 : ℝ≥0∞) * 2 ^ r = 2 ^ (r + 1) := by ring
  have hA' : (R : ℝ≥0∞) * (2 * (δp + δh)) ≤ (2⁻¹ : ℝ≥0∞) ^ 128 := by
    calc (R : ℝ≥0∞) * (2 * (δp + δh)) ≤ 2 ^ r * (2 * (δp + δh)) := mul_le_mul_left hR' _
      _ = 2 ^ (r + 1) * (δp + δh) := by rw [← h2r]; ring
      _ ≤ _ := hA
  have hB' : 2 * ((R : ℝ≥0∞) * (ωp + ωh)) + 4 * εc ≤ (2⁻¹ : ℝ≥0∞) ^ 120 := by
    calc 2 * ((R : ℝ≥0∞) * (ωp + ωh)) + 4 * εc ≤ 2 * (2 ^ r * (ωp + ωh)) + 4 * εc := by gcongr
      _ = 2 ^ (r + 1) * (ωp + ωh) + 4 * εc := by rw [← h2r]; ring
      _ ≤ _ := hB
  calc ∑ j ∈ range R, wStep δp ωp δh ωh εc q R j
      ≤ ∑ _j ∈ range R, ((q : ℝ≥0∞) * (2 * (δp + δh)) + (2 * ((R : ℝ≥0∞) * (ωp + ωh)) + 4 * εc)) :=
        sum_le_sum hterm
    _ = (R : ℝ≥0∞) * ((q : ℝ≥0∞) * (2 * (δp + δh)) + (2 * ((R : ℝ≥0∞) * (ωp + ωh)) + 4 * εc)) := by
        rw [sum_const, card_range, nsmul_eq_mul]
    _ = (q : ℝ≥0∞) * ((R : ℝ≥0∞) * (2 * (δp + δh))) + (R : ℝ≥0∞) * (2 * ((R : ℝ≥0∞) * (ωp + ωh)) + 4 * εc) := by
        ring
    _ ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 128 + (R : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 120 :=
        add_le_add (mul_le_mul_right hA' _) (mul_le_mul_right hB' _)
    _ = εzkTarget q R := rfl

/-- Above `2^120` receipts the approved target is at least `1`. -/
theorem one_le_target_of_large (q R : ℕ) (hR : 2 ^ 120 ≤ R) : (1 : ℝ≥0∞) ≤ εzkTarget q R := by
  have hR' : (2 : ℝ≥0∞) ^ 120 ≤ R := by exact_mod_cast hR
  have h1 : (1 : ℝ≥0∞) = 2 ^ 120 * (2⁻¹ : ℝ≥0∞) ^ (120 + 0) := by
    rw [two_pow_mul_inv_pow 120 0, pow_zero]
  calc (1 : ℝ≥0∞) = 2 ^ 120 * (2⁻¹ : ℝ≥0∞) ^ 120 := h1
    _ ≤ (R : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 120 := mul_le_mul_left hR' _
    _ ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 128 + (R : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 120 := le_add_self
    _ = εzkTarget q R := rfl

/-- **For EVERY `q` and EVERY `R`.** With `δp + δh ≤ 2^-249`, `ωp + ωh ≤ 2^-242` and `εc ≤ 2^-124`, the summed error
capped at `1` is within the approved `εzkTarget q R`: below `2^120` receipts by `wBudget_le`, above by
`one_le_target_of_large`. No receipt cap. -/
theorem wBudget_every_R (δp ωp δh ωh εc : ℝ≥0∞) (hδ : δp + δh ≤ (2⁻¹ : ℝ≥0∞) ^ 249)
    (hω : ωp + ωh ≤ (2⁻¹ : ℝ≥0∞) ^ 242) (hεc : εc ≤ (2⁻¹ : ℝ≥0∞) ^ 124) (q R : ℕ) :
    min (∑ j ∈ range R, wStep δp ωp δh ωh εc q R j) 1 ≤ εzkTarget q R := by
  rcases lt_or_ge R (2 ^ 120) with hR | hR
  · refine (min_le_left _ _).trans (wBudget_le q R 120 hR.le δp ωp δh ωh εc ?_ ?_)
    · calc (2 : ℝ≥0∞) ^ (120 + 1) * (δp + δh) ≤ 2 ^ 121 * (2⁻¹ : ℝ≥0∞) ^ (121 + 128) := mul_le_mul_right hδ _
        _ = (2⁻¹ : ℝ≥0∞) ^ 128 := two_pow_mul_inv_pow 121 128
    · have h1 : (2 : ℝ≥0∞) ^ (120 + 1) * (ωp + ωh) ≤ (2⁻¹ : ℝ≥0∞) ^ 121 :=
        calc (2 : ℝ≥0∞) ^ (120 + 1) * (ωp + ωh) ≤ 2 ^ 121 * (2⁻¹ : ℝ≥0∞) ^ (121 + 121) := mul_le_mul_right hω _
          _ = (2⁻¹ : ℝ≥0∞) ^ 121 := two_pow_mul_inv_pow 121 121
      have h2 : 4 * εc ≤ (2⁻¹ : ℝ≥0∞) ^ 122 :=
        calc 4 * εc ≤ 4 * (2⁻¹ : ℝ≥0∞) ^ 124 := mul_le_mul_right hεc _
          _ = (2 : ℝ≥0∞) ^ 2 * (2⁻¹ : ℝ≥0∞) ^ (2 + 122) := by ring
          _ = (2⁻¹ : ℝ≥0∞) ^ 122 := two_pow_mul_inv_pow 2 122
      calc (2 : ℝ≥0∞) ^ (120 + 1) * (ωp + ωh) + 4 * εc ≤ (2⁻¹ : ℝ≥0∞) ^ 121 + (2⁻¹ : ℝ≥0∞) ^ 122 :=
            add_le_add h1 h2
        _ ≤ (2⁻¹ : ℝ≥0∞) ^ 121 + (2⁻¹ : ℝ≥0∞) ^ 121 := add_le_add le_rfl (inv_pow_le_inv_pow (by norm_num))
        _ = (2 : ℝ≥0∞) ^ 1 * (2⁻¹ : ℝ≥0∞) ^ (1 + 120) := by ring
        _ = (2⁻¹ : ℝ≥0∞) ^ 120 := two_pow_mul_inv_pow 1 120
  · exact (min_le_right _ _).trans (one_le_target_of_large q R hR)

/-! ## The assembled statement, every `q`, every `R` -/

section Assembled

variable {Q D Coins : Type} [DecidableEq Q] {M : IntModel} {P : Protocol Q D Coins M} [Inhabited M.Input]
  [Fintype Q] [Fintype D] [Nonempty D] [Fintype Coins] [Nonempty Coins]

open Classical in
/-- **Zero knowledge within the approved target for EVERY `q` and EVERY `R`** (D63 Statement 2, no receipt cap).
For every weight set `W`, let the protocol's prover be the honest prover of a Fiat–Shamir receipt model `FM W` (`hP`),
given also as a `qp`-question computation (`pOC`, `hrun`, `hbd`) within the weighted budgets `Wp W` (before a request,
weights `Kf W`) and `Wpa W` (after it, weights `KUf W`); let its receipts on an input and on the stand-in have the same
honest-verifier law at every value vector (`hHV`, `ZKLinks.hHV_of_blockLinks`); let one query `z` hit some point for at
most `Kf W z` of the `(c, v)` (`hKw`), two points collide for at most `Kc W` (`hKc`), and a query set of weight `Wt`
read off the receipt catch a hidden point for at most `Wt` coins (`hUw`); let the single queries weigh at most `Km W`
and `KUm W`. If the rates are as stated (`hrδp` … `hrωh`) and `δp + δh ≤ 2^-249`, `ωp + ωh ≤ 2^-242`,
`εc ≤ 2^-124`, the protocol is zero knowledge with the stand-in simulator and an error that is at most
`εzkTarget q R` for every `q` and every `R`. -/
theorem zk_every_R [Inhabited D] [Inhabited Coins]
    (pOC : M.Weights → M.Input → Coins → OC Q D (P.Stmt × P.Receipt)) (qp : ℕ)
    (hrun : ∀ W H x c, (pOC W x c).run H = P.prove H W x c) (hbd : ∀ W x c, (pOC W x c).Bounded qp)
    (FM : M.Weights → FSModel Q D M.Input Coins (P.Stmt × P.Receipt))
    (hP : ∀ W H x c, P.prove H W x c = (FM W).prove H x c)
    (hHV : ∀ W x (v : Fin (FM W).k → D), (PMF.uniformOfFintype Coins).map (fun c => (FM W).out x c v)
      = (PMF.uniformOfFintype Coins).map
          (fun c => (FM W).out (standin P W (M.publicPart (M.forward W x), P.leak x)) c v))
    (Kf KUf : M.Weights → Q → ℕ) (Km KUm Wp Wpa Kc : M.Weights → ℕ)
    (hKm : ∀ W z, Kf W z ≤ Km W) (hKUm : ∀ W z, KUf W z ≤ KUm W)
    (hwb : ∀ W x c, WB (Kf W) (pOC W x c) (Wp W)) (hwba : ∀ W x c, WB (KUf W) (pOC W x c) (Wpa W))
    (hKw : ∀ W x (H : Q → D) z, (univ.filter (fun s : Coins × (Fin (FM W).k → D) =>
      ∃ i, (FM W).pts x s.1 H s.2 i = z)).card ≤ Kf W z)
    (hKc : ∀ W x (H : Q → D), (univ.filter (fun s : Coins × (Fin (FM W).k → D) =>
      ¬ Function.Injective ((FM W).pts x s.1 H s.2) ∨ ∃ i, (FM W).pts x s.1 H s.2 i ∈ (FM W).dep x s.1)).card
        ≤ Kc W)
    (hUw : ∀ W x (H : Q → D) (v : Fin (FM W).k → D) (Z : (P.Stmt × P.Receipt) → Finset Q) (Wt : ℕ),
      (∀ o, ∑ z ∈ Z o, KUf W z ≤ Wt) →
      (univ.filter (fun c => ∃ i, ¬ (FM W).vis v i ∧ (FM W).pts x c H v i ∈ Z ((FM W).out x c v))).card ≤ Wt)
    (δp ωp δh ωh εc : ℝ≥0∞)
    (hrδp : ∀ W, (Km W : ℝ≥0∞) / Fintype.card (Coins × (Fin (FM W).k → D)) ≤ δp)
    (hrωp : ∀ W, (Wp W : ℝ≥0∞) / Fintype.card (Coins × (Fin (FM W).k → D)) ≤ ωp)
    (hrεc : ∀ W, (Kc W : ℝ≥0∞) / Fintype.card (Coins × (Fin (FM W).k → D)) ≤ εc)
    (hrδh : ∀ W, (KUm W : ℝ≥0∞) / Fintype.card Coins ≤ δh)
    (hrωh : ∀ W, (Wpa W : ℝ≥0∞) / Fintype.card Coins ≤ ωh)
    (hδ : δp + δh ≤ (2⁻¹ : ℝ≥0∞) ^ 249) (hω : ωp + ωh ≤ (2⁻¹ : ℝ≥0∞) ^ 242) (hεc : εc ≤ (2⁻¹ : ℝ≥0∞) ^ 124) :
    ZeroKnowledge M P (fun q R => min (∑ j ∈ range R, wStep δp ωp δh ωh εc q R j) 1)
      ∧ ∀ q R, min (∑ j ∈ range R, wStep δp ωp δh ωh εc q R j) 1 ≤ εzkTarget q R := by
  refine ⟨zeroKnowledge_min_one (zeroKnowledge_of_oneStepW pOC qp hrun hbd Kf KUf Km KUm Wp Wpa hKm hKUm hwb hwba
    (fun W W₁ W₂ => (((2 * (W₁ + 2 * Kc W)) : ℕ) : ℝ≥0∞) / Fintype.card (Coins × (Fin (FM W).k → D))
      + (((2 * W₂) : ℕ) : ℝ≥0∞) / Fintype.card Coins)
    (fun W => oneStepW_of_fsModel P W (FM W) (hP W) (hHV W) (Kf W) (KUf W) (Kc W) (hKw W) (hKc W) (hUw W))
    (fun q R j => wStep δp ωp δh ωh εc q R j)
    (fun W q R j _ => fsStepW_le_wStep q R j (Km W) (Wp W) (Kc W) (KUm W) (Wpa W) _ _ δp ωp δh ωh εc
      (hrδp W) (hrωp W) (hrεc W) (hrδh W) (hrωh W))), ?_⟩
  exact wBudget_every_R δp ωp δh ωh εc hδ hω hεc

end Assembled

/-! ## A receipt's counts by hash kind -/

/-- **A receipt's counts by hash kind** (the code keys every hash by its role, D19 T-1: a query of one kind only meets
points of that kind). -/
structure ZKKinds where
  /-- the receipt's own transcript points after the public header -/
  chain : ℕ
  /-- the most transcript points of ONE receipt one query can meet at `2^-256` each (a squeeze names its counter; an
  absorb names its label and data, so only the absorbs of a fixed datum with that label count fully) -/
  mT : ℕ
  /-- the column points (one column digest per column), the salted leaves, the Merkle inner nodes -/
  cols : ℕ
  leaves : ℕ
  nodes : ℕ
  /-- the bits of min-entropy of a column point before the request (its pads), and of an unopened one given the
  receipt (the pads beyond the view's linear constraints) -/
  hcol : ℕ
  hcond : ℕ
  /-- the honest prover's queries per receipt by kind: transcript, column digests, leaves, nodes -/
  qpT : ℕ
  qpC : ℕ
  qpL : ℕ
  qpN : ℕ

namespace ZKKinds

/-- One query's worst chance before the request: a transcript query `mT·2^-256`, a column query `cols·2^-hcol`, a leaf
or node query `2^-512` per point (a salted leaf's column digest is itself a fresh point). -/
noncomputable def δp (Z : ZKKinds) : ℝ≥0∞ :=
  (Z.mT : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + (Z.cols : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ Z.hcol
    + ((Z.leaves + Z.nodes : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512

/-- One other receipt's prover, over all its queries, before the request. -/
noncomputable def ωp (Z : ZKKinds) : ℝ≥0∞ :=
  ((Z.qpT * Z.mT : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + ((Z.qpC * Z.cols : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ Z.hcol
    + ((Z.qpL * Z.leaves + Z.qpN * Z.nodes : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512

/-- One query's worst chance of meeting a hidden point after the request (an unopened column, an unopened leaf). -/
noncomputable def δh (Z : ZKKinds) : ℝ≥0∞ :=
  (Z.cols : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ Z.hcond + (Z.leaves : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512

/-- One later receipt's prover, over all its queries, after the request. -/
noncomputable def ωh (Z : ZKKinds) : ℝ≥0∞ :=
  ((Z.qpC * Z.cols : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ Z.hcond + ((Z.qpL * Z.leaves : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512

/-- Every programmed point. -/
def pts (Z : ZKKinds) : ℕ := Z.chain + Z.cols + Z.leaves + Z.nodes

/-- Two points collide (all pairs at `2^-256`, the weakest freshness when `hcol ≥ 256`). -/
noncomputable def εc (Z : ZKKinds) : ℝ≥0∞ := ((Z.pts * Z.pts : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256

/-- **A run's counts are the sum of its layers' counts** (one transcript end to end; every block's, stage's and
boundary commitment's columns, leaves and nodes; the prover's queries for all of them); a query meets at most the sum
of the layers' multiplicities, and the freshness is the weakest layer's. -/
def add (Z Z' : ZKKinds) : ZKKinds where
  chain := Z.chain + Z'.chain
  mT := Z.mT + Z'.mT
  cols := Z.cols + Z'.cols
  leaves := Z.leaves + Z'.leaves
  nodes := Z.nodes + Z'.nodes
  hcol := min Z.hcol Z'.hcol
  hcond := min Z.hcond Z'.hcond
  qpT := Z.qpT + Z'.qpT
  qpC := Z.qpC + Z'.qpC
  qpL := Z.qpL + Z'.qpL
  qpN := Z.qpN + Z'.qpN

/-- `a ≤ 2^x` and `x + y ≤ e` give `a·2^-e ≤ 2^-y`. -/
theorem term_le {a x e y : ℕ} (ha : a ≤ 2 ^ x) (hxy : x + y ≤ e) :
    (a : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ e ≤ (2⁻¹ : ℝ≥0∞) ^ y := by
  calc (a : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ e ≤ (a : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ (x + y) :=
        mul_le_mul_right (inv_pow_le_inv_pow hxy) _
    _ ≤ (2⁻¹ : ℝ≥0∞) ^ y := count_mul_inv_pow_le ha

/-- Five terms, each at most `2^-(e+3)`, add up to at most `2^-e`. -/
theorem five_le {a b c d f : ℝ≥0∞} {e : ℕ} (ha : a ≤ (2⁻¹ : ℝ≥0∞) ^ (e + 3)) (hb : b ≤ (2⁻¹ : ℝ≥0∞) ^ (e + 3))
    (hc : c ≤ (2⁻¹ : ℝ≥0∞) ^ (e + 3)) (hd : d ≤ (2⁻¹ : ℝ≥0∞) ^ (e + 3)) (hf : f ≤ (2⁻¹ : ℝ≥0∞) ^ (e + 3)) :
    a + b + c + (d + f) ≤ (2⁻¹ : ℝ≥0∞) ^ e := by
  set X := (2⁻¹ : ℝ≥0∞) ^ (e + 3) with hX
  calc a + b + c + (d + f) ≤ X + X + X + (X + X) := add_le_add (add_le_add (add_le_add ha hb) hc) (add_le_add hd hf)
    _ ≤ X + X + X + (X + X) + (X + X + X) := le_self_add
    _ = (2 : ℝ≥0∞) ^ 3 * (2⁻¹ : ℝ≥0∞) ^ (3 + e) := by rw [hX]; ring
    _ = (2⁻¹ : ℝ≥0∞) ^ e := two_pow_mul_inv_pow 3 e

/-- One term at most `2^-(e+1)` and four at most `2^-(e+3)` add up to at most `2^-e`. -/
theorem one_four_le {a b c d f : ℝ≥0∞} {e : ℕ} (ha : a ≤ (2⁻¹ : ℝ≥0∞) ^ (e + 1)) (hb : b ≤ (2⁻¹ : ℝ≥0∞) ^ (e + 3))
    (hc : c ≤ (2⁻¹ : ℝ≥0∞) ^ (e + 3)) (hd : d ≤ (2⁻¹ : ℝ≥0∞) ^ (e + 3)) (hf : f ≤ (2⁻¹ : ℝ≥0∞) ^ (e + 3)) :
    a + b + c + (d + f) ≤ (2⁻¹ : ℝ≥0∞) ^ e := by
  set A := (2⁻¹ : ℝ≥0∞) ^ (e + 1) with hA
  set X := (2⁻¹ : ℝ≥0∞) ^ (e + 3) with hX
  have h4 : X + X + (X + X) = A := by
    rw [hX, hA]
    calc (2⁻¹ : ℝ≥0∞) ^ (e + 3) + (2⁻¹ : ℝ≥0∞) ^ (e + 3) + ((2⁻¹ : ℝ≥0∞) ^ (e + 3) + (2⁻¹ : ℝ≥0∞) ^ (e + 3))
        = (2 : ℝ≥0∞) ^ 2 * (2⁻¹ : ℝ≥0∞) ^ (2 + (e + 1)) := by ring
      _ = (2⁻¹ : ℝ≥0∞) ^ (e + 1) := two_pow_mul_inv_pow 2 (e + 1)
  calc a + b + c + (d + f) ≤ A + X + X + (X + X) := add_le_add (add_le_add (add_le_add ha hb) hc) (add_le_add hd hf)
    _ = A + (X + X + (X + X)) := by ring
    _ = A + A := by rw [h4]
    _ = (2 : ℝ≥0∞) ^ 1 * (2⁻¹ : ℝ≥0∞) ^ (1 + e) := by rw [hA]; ring
    _ = (2⁻¹ : ℝ≥0∞) ^ e := two_pow_mul_inv_pow 1 e

/-- **The one-query rates of a receipt's kinds, general**: with `mT ≤ 2^a`, the column points and the leaves plus
nodes `≤ 2^c`, `a + e + 3 ≤ 256` and `c + e + 3` bits of column freshness (before and given the receipt),
`δp + δh ≤ 2^-e`. -/
theorem δ_le_gen (Z : ZKKinds) (c a e : ℕ) (hm : Z.mT ≤ 2 ^ a) (hC : Z.cols ≤ 2 ^ c)
    (hLN : Z.leaves + Z.nodes ≤ 2 ^ c) (hae : a + e + 3 ≤ 256) (hcol : c + e + 3 ≤ Z.hcol)
    (hcond : c + e + 3 ≤ Z.hcond) (h512 : c + e + 3 ≤ 512) :
    Z.δp + Z.δh ≤ (2⁻¹ : ℝ≥0∞) ^ e := by
  have hL : Z.leaves ≤ 2 ^ c := le_trans (Nat.le_add_right _ _) hLN
  unfold δp δh
  exact five_le (term_le hm (by omega)) (term_le hC (by omega)) (term_le hLN (by omega))
    (term_le hC (by omega)) (term_le hL (by omega))

/-- **The one-query rates of a receipt's kinds**: with `mT ≤ 2^4`, the column points, the leaves plus nodes `≤ 2^c`,
and `c + 252` bits of column freshness (before and given the receipt), `δp + δh ≤ 2^-249`. -/
theorem δ_le (Z : ZKKinds) (c : ℕ) (h4 : Z.mT ≤ 2 ^ 4) (hC : Z.cols ≤ 2 ^ c) (hLN : Z.leaves + Z.nodes ≤ 2 ^ c)
    (hcol : c + 252 ≤ Z.hcol) (hcond : c + 252 ≤ Z.hcond) (h512 : c + 252 ≤ 512) :
    Z.δp + Z.δh ≤ (2⁻¹ : ℝ≥0∞) ^ 249 :=
  δ_le_gen Z c 4 249 h4 hC hLN (by norm_num) (by omega) (by omega) (by omega)

/-- **The provers' per-receipt rates**: with `qpT·mT ≤ 2^b` (`13 ≤ b ≤ 255`), the provers' column, leaf and node
queries `≤ 2^c` each and `2c + 252` bits of column freshness, `ωp + ωh ≤ 2^-(255 − b)`. The transcript term
`qpT·mT·2^-256` is the only one that is not far below: each of the other receipts' transcript queries meets this
receipt's state at its own counter with chance `2^-256`. -/
theorem ω_le (Z : ZKKinds) (c b : ℕ) (hb : Z.qpT * Z.mT ≤ 2 ^ b) (hb13 : 13 ≤ b) (hb255 : b ≤ 255)
    (hC : Z.cols ≤ 2 ^ c) (hLN : Z.leaves + Z.nodes ≤ 2 ^ c)
    (hqC : Z.qpC ≤ 2 ^ c) (hqL : Z.qpL ≤ 2 ^ c) (hqN : Z.qpN ≤ 2 ^ c)
    (hcol : 2 * c + 252 ≤ Z.hcol) (hcond : 2 * c + 252 ≤ Z.hcond) (h512 : 2 * c + 252 ≤ 512) :
    Z.ωp + Z.ωh ≤ (2⁻¹ : ℝ≥0∞) ^ (255 - b) := by
  have h2c : (2 : ℕ) ^ c * 2 ^ c = 2 ^ (2 * c) := by rw [← pow_add, two_mul]
  have hL : Z.leaves ≤ 2 ^ c := le_trans (Nat.le_add_right _ _) hLN
  have hN : Z.nodes ≤ 2 ^ c := le_trans (Nat.le_add_left _ _) hLN
  have hCC : Z.qpC * Z.cols ≤ 2 ^ (2 * c) := (Nat.mul_le_mul hqC hC).trans_eq h2c
  have hLL : Z.qpL * Z.leaves ≤ 2 ^ (2 * c) := (Nat.mul_le_mul hqL hL).trans_eq h2c
  have hLN2 : Z.qpL * Z.leaves + Z.qpN * Z.nodes ≤ 2 ^ (2 * c) := by
    rw [← h2c]
    calc Z.qpL * Z.leaves + Z.qpN * Z.nodes ≤ 2 ^ c * Z.leaves + 2 ^ c * Z.nodes :=
          Nat.add_le_add (Nat.mul_le_mul_right _ hqL) (Nat.mul_le_mul_right _ hqN)
      _ = 2 ^ c * (Z.leaves + Z.nodes) := by ring
      _ ≤ 2 ^ c * 2 ^ c := Nat.mul_le_mul_left _ hLN
  have e1 : 255 - b + 1 = 256 - b := by omega
  unfold ωp ωh
  refine one_four_le (e := 255 - b) ?_ (term_le hCC (by omega)) (term_le hLN2 (by omega))
    (term_le hCC (by omega)) (term_le hLL (by omega))
  rw [e1]
  exact term_le hb (by omega)

/-- The collisions: `pts ≤ 2^p` with `2p + 124 ≤ 256` gives `εc ≤ 2^-124`. -/
theorem εc_le (Z : ZKKinds) (p : ℕ) (hp : Z.pts ≤ 2 ^ p) (hp' : 2 * p + 124 ≤ 256) :
    Z.εc ≤ (2⁻¹ : ℝ≥0∞) ^ 124 := by
  have hpp : Z.pts * Z.pts ≤ 2 ^ (2 * p) := by
    calc Z.pts * Z.pts ≤ 2 ^ p * 2 ^ p := Nat.mul_le_mul hp hp
      _ = 2 ^ (2 * p) := by rw [← pow_add, two_mul]
  exact term_le hpp hp'

/-- **The shape criterion for EVERY `R`** (finding L14-1's fix (a), at a shape): with `mT ≤ 2^4`,
`qpT·mT ≤ 2^13`, the column points, leaves plus nodes and the provers' column, leaf and node queries at most `2^c`,
`2c + 252` bits of column freshness, and `pts ≤ 2^p` with `2p + 124 ≤ 256`, the three conditions of
`wBudget_every_R` and `zk_every_R` hold. -/
theorem every_R (Z : ZKKinds) (c p : ℕ) (h4 : Z.mT ≤ 2 ^ 4) (h13 : Z.qpT * Z.mT ≤ 2 ^ 13)
    (hC : Z.cols ≤ 2 ^ c) (hLN : Z.leaves + Z.nodes ≤ 2 ^ c)
    (hqC : Z.qpC ≤ 2 ^ c) (hqL : Z.qpL ≤ 2 ^ c) (hqN : Z.qpN ≤ 2 ^ c)
    (hcol : 2 * c + 252 ≤ Z.hcol) (hcond : 2 * c + 252 ≤ Z.hcond) (h512 : 2 * c + 252 ≤ 512)
    (hp : Z.pts ≤ 2 ^ p) (hp' : 2 * p + 124 ≤ 256) :
    Z.δp + Z.δh ≤ (2⁻¹ : ℝ≥0∞) ^ 249 ∧ Z.ωp + Z.ωh ≤ (2⁻¹ : ℝ≥0∞) ^ 242 ∧ Z.εc ≤ (2⁻¹ : ℝ≥0∞) ^ 124 :=
  ⟨δ_le Z c h4 hC hLN (by omega) (by omega) (by omega),
    ω_le Z c 13 h13 le_rfl (by norm_num) hC hLN hqC hqL hqN hcol hcond h512, εc_le Z p hp hp'⟩

/-- **The cap when the transcript is long** (finding L19-2): with only `qpT·mT ≤ 2^b` (`b ≥ 13`) and `mT ≤ 2^a`, the
summed error is within `εzkTarget q R` for every `q` and every `R ≤ 2^r` with `r + b ≤ 133`, `a + r + 132 ≤ 256` and
`r ≤ 120`. -/
theorem cap_R (Z : ZKKinds) (c p a b r : ℕ) (hm : Z.mT ≤ 2 ^ a) (hb : Z.qpT * Z.mT ≤ 2 ^ b) (hb13 : 13 ≤ b)
    (hC : Z.cols ≤ 2 ^ c) (hLN : Z.leaves + Z.nodes ≤ 2 ^ c)
    (hqC : Z.qpC ≤ 2 ^ c) (hqL : Z.qpL ≤ 2 ^ c) (hqN : Z.qpN ≤ 2 ^ c)
    (hcol : 2 * c + 252 ≤ Z.hcol) (hcond : 2 * c + 252 ≤ Z.hcond) (h512 : 2 * c + 252 ≤ 512)
    (hp : Z.pts ≤ 2 ^ p) (hp' : 2 * p + 124 ≤ 256) (hrb : r + b ≤ 133) (har : a + r + 132 ≤ 256) (hr : r ≤ 120)
    (q R : ℕ) (hR : R ≤ 2 ^ r) :
    ∑ j ∈ range R, wStep Z.δp Z.ωp Z.δh Z.ωh Z.εc q R j ≤ εzkTarget q R := by
  have hδ := δ_le_gen Z c a (r + 129) hm hC hLN (by omega) (by omega) (by omega) (by omega)
  have hω := ω_le Z c b hb hb13 (by omega) hC hLN hqC hqL hqN hcol hcond h512
  have hε := εc_le Z p hp hp'
  refine wBudget_le q R r hR _ _ _ _ _ ?_ ?_
  · calc (2 : ℝ≥0∞) ^ (r + 1) * (Z.δp + Z.δh) ≤ 2 ^ (r + 1) * (2⁻¹ : ℝ≥0∞) ^ ((r + 1) + 128) :=
          mul_le_mul_right (hδ.trans_eq (by congr 1)) _
      _ = (2⁻¹ : ℝ≥0∞) ^ 128 := two_pow_mul_inv_pow (r + 1) 128
  · have h1 : (2 : ℝ≥0∞) ^ (r + 1) * (Z.ωp + Z.ωh) ≤ (2⁻¹ : ℝ≥0∞) ^ 121 :=
      calc (2 : ℝ≥0∞) ^ (r + 1) * (Z.ωp + Z.ωh) ≤ 2 ^ (r + 1) * (2⁻¹ : ℝ≥0∞) ^ ((r + 1) + (254 - b - r)) :=
            mul_le_mul_right (hω.trans_eq (by congr 1; omega)) _
        _ = (2⁻¹ : ℝ≥0∞) ^ (254 - b - r) := two_pow_mul_inv_pow (r + 1) (254 - b - r)
        _ ≤ (2⁻¹ : ℝ≥0∞) ^ 121 := inv_pow_le_inv_pow (by omega)
    have h2 : 4 * Z.εc ≤ (2⁻¹ : ℝ≥0∞) ^ 122 :=
      calc 4 * Z.εc ≤ 4 * (2⁻¹ : ℝ≥0∞) ^ 124 := mul_le_mul_right hε _
        _ = (2 : ℝ≥0∞) ^ 2 * (2⁻¹ : ℝ≥0∞) ^ (2 + 122) := by ring
        _ = (2⁻¹ : ℝ≥0∞) ^ 122 := two_pow_mul_inv_pow 2 122
    calc (2 : ℝ≥0∞) ^ (r + 1) * (Z.ωp + Z.ωh) + 4 * Z.εc ≤ (2⁻¹ : ℝ≥0∞) ^ 121 + (2⁻¹ : ℝ≥0∞) ^ 122 :=
          add_le_add h1 h2
      _ ≤ (2⁻¹ : ℝ≥0∞) ^ 121 + (2⁻¹ : ℝ≥0∞) ^ 121 := add_le_add le_rfl (inv_pow_le_inv_pow (by norm_num))
      _ = (2 : ℝ≥0∞) ^ 1 * (2⁻¹ : ℝ≥0∞) ^ (1 + 120) := by ring
      _ = (2⁻¹ : ℝ≥0∞) ^ 120 := two_pow_mul_inv_pow 1 120

end ZKKinds

/-! ## The instances [ESTIMATE: the counts by kind are read off L9's corpus and the code, not yet derived from a Lean
prover] -/

namespace W16R2K

/-- **W16R2's block by kind** (the development rung, L9's corpus; L14's `W16R2Z` split by kind). Transcript: at most
`4,096` points (`1,609` squeezes and about `420` absorbs), and at most `2` of them met by one query (a squeeze names its
counter; `pb-slot` names its slot; every other absorb carries masked data). Columns, leaves: `32,768 + 32,768 + 4,096`;
nodes one fewer per tree. Column freshness: `320` bits before the request (at least `5` padded rows of Goldilocks per
commitment), `300` given the receipt (the rows beyond the view's linear constraints). The prover: one query per
transcript point, column, leaf and node. -/
def kinds : ZKKinds where
  chain := 4096
  mT := 2
  cols := 69632
  leaves := 69632
  nodes := 69629
  hcol := 320
  hcond := 300
  qpT := 4096
  qpC := 69632
  qpL := 69632
  qpN := 69629

/-- **W16R2 meets the criterion for every `R`** (`c = 18`, `p = 18`). -/
theorem every_R :
    kinds.δp + kinds.δh ≤ (2⁻¹ : ℝ≥0∞) ^ 249 ∧ kinds.ωp + kinds.ωh ≤ (2⁻¹ : ℝ≥0∞) ^ 242
      ∧ kinds.εc ≤ (2⁻¹ : ℝ≥0∞) ^ 124 :=
  ZKKinds.every_R kinds 18 18 (by decide) (by decide) (by decide) (by decide) (by decide) (by decide) (by decide)
    (by decide) (by decide) (by decide) (by decide) (by decide)

end W16R2K

namespace R13K

/-- **One R13 block by kind** (rate 1/4: the encoded widths double at `log_cols` 14; the transcript as W16R2's). -/
def kinds : ZKKinds where
  chain := 4096
  mT := 2
  cols := 135168
  leaves := 135168
  nodes := 135165
  hcol := 320
  hcond := 300
  qpT := 4096
  qpC := 135168
  qpL := 135168
  qpN := 135165

/-- **One R13 block meets the criterion for every `R`** (`c = 19`, `p = 19`). -/
theorem every_R :
    kinds.δp + kinds.δh ≤ (2⁻¹ : ℝ≥0∞) ^ 249 ∧ kinds.ωp + kinds.ωh ≤ (2⁻¹ : ℝ≥0∞) ^ 242
      ∧ kinds.εc ≤ (2⁻¹ : ℝ≥0∞) ^ 124 :=
  ZKKinds.every_R kinds 19 19 (by decide) (by decide) (by decide) (by decide) (by decide) (by decide) (by decide)
    (by decide) (by decide) (by decide) (by decide) (by decide)

end R13K

namespace RunK

/-- **A whole Shieldstral classify run as ONE receipt** (26 R13 blocks, the IN and OUT stages, the boundary
commitments): at most `28·2,048` transcript points, about `28·135,168` columns and leaves; one query meets at most `32`
transcript points (a `pb-slot` absorb names its slot index but not its block, so the same slot's absorb in each of the
26 blocks counts). -/
def kinds : ZKKinds where
  chain := 57344
  mT := 32
  cols := 3784704
  leaves := 3784704
  nodes := 3784676
  hcol := 320
  hcond := 300
  qpT := 57344
  qpC := 3784704
  qpL := 3784704
  qpN := 3784676

/-- **Finding L19-2, the criterion's transcript conditions fail for the run**: `mT = 32 > 2^4` and
`qpT·mT = 1,835,008 > 2^13`. -/
theorem not_every : ¬ (kinds.mT ≤ 2 ^ 4) ∧ ¬ (kinds.qpT * kinds.mT ≤ 2 ^ 13) := by decide

/-- **The run is within the target for every `q` and every `R ≤ 2^112`** (`a = 5`, `b = 21`, `c = 23`, `p = 24`). -/
theorem cap_112 (q R : ℕ) (hR : R ≤ 2 ^ 112) :
    ∑ j ∈ range R, wStep kinds.δp kinds.ωp kinds.δh kinds.ωh kinds.εc q R j ≤ εzkTarget q R :=
  ZKKinds.cap_R kinds 23 24 5 21 112 (by decide) (by decide) (by norm_num) (by decide) (by decide) (by decide)
    (by decide) (by decide) (by decide) (by decide) (by decide) (by decide) (by norm_num) (by norm_num) (by norm_num)
    (by norm_num) q R hR

end RunK

end ZK60.ZKCount
