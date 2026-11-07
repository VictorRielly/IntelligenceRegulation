/-
D63 step L14 (Statement 2, zero knowledge), part 6: the zero-knowledge budget GENERIC in the receipt's shape, so that
W16R2 is one instance and R13 (L17) or a whole classify run (L18) another.

Nothing in `ZKW16Prog`, `ZKW16Step`, `ZKW16View` or `ZKW16Hyb` depends on W16R2: the receipt model (`FSModel`), the
simulator (`standinSim`), the one-receipt step (`fs_step`, `OneStep`) and the hybrid (`zeroKnowledge_of_oneStep`) are
generic in the protocol; the slot composition (`block_view_law_eq_slots_M`) is generic in the slot list, the kinds and
the shapes (the plane list and the range families enter only through the slots and the tables); the rate and `Q` enter
the openings' law (`openingView_law_eq` needs the opened columns within the pads) and the counts below. What the budget
needs from a profile is four numbers, `ZKShape`:
* `leaves`: the salted leaves of the receipt's commitments (the sum of their encoded widths: `2^log_cols / rate`,
  plus `M`'s `2^MASK_LOG_DOM`, plus any boundary or endpoint commitment of a run);
* `nodes`: their Merkle trees' inner nodes;
* `chain`: the receipt's own transcript points after the public header (absorbs and squeezes);
* `qp`: the honest prover's hash queries per receipt.

* `ZKShape.δprog`, `δhid`, `εcoll`, `ZKShape.rates_le`: the per-query rates and the collision term of a shape, and
  their bounds from `chain + 2·leaves + nodes ≤ 2^a` and `leaves + nodes + chain ≤ 2^c`;
* `ZKShape.add`: a run's shape is the sum of its blocks' and stages' shapes (one transcript, every commitment's leaves);
* `zkStep`, **`zkBudget_le`**: the summed per-step error is within `εzkTarget q R` for every `q` and every `R ≤ 2^r`
  whenever `r + b + 123 ≤ t`, with the rates `≤ 2^-t` and `qp ≤ 2^b`;
* **`zk_within_target_of_shape`**: the assembled statement with the shape as the parameter: the instance obligations
  (an `FSModel` per weight set whose counts are within the shape's rates, its view's law, the prover as a `qp`-query
  computation) give `ZeroKnowledge` with an error within `εzkTarget` for every `q` and every `R ≤ 2^r`, where
  `r + b + 123 + a ≤ 256`; so the receipt cap is `R ≤ 2^(133 − a − b)`;
* `W16R2Z.shape`, `W16R2Z.shape_fits`: W16R2's block is the instance `a = 19`, `b = 18`, `c = 18`, `r = 96`.

Every premise is an explicit hypothesis; no `sorry`, axiom or `native_decide`.
-/
import ZK60Formal.ZKW16Hyb

namespace ZK60.ZKW16

open scoped ENNReal
open Finset
open ZK60.ZKHybrid

/-! ## The shape of a receipt -/

/-- **The counts of one Fiat–Shamir receipt that drive its zero-knowledge budget** (a block, a token stage, or a whole
run). -/
structure ZKShape where
  /-- the salted leaves of every commitment of the receipt -/
  leaves : ℕ
  /-- the inner nodes of their Merkle trees -/
  nodes : ℕ
  /-- the receipt's own transcript points after the public header -/
  chain : ℕ
  /-- the honest prover's hash queries per receipt -/
  qp : ℕ

namespace ZKShape

/-- Every programmed point. -/
def pts (Z : ZKShape) : ℕ := Z.leaves + Z.nodes + Z.chain

/-- The programmed points' per-query rate before the request (a transcript point or a leaf is hit by naming one fresh
256-bit value, a node by naming two). -/
noncomputable def δprog (Z : ZKShape) : ℝ≥0∞ :=
  ((Z.chain + Z.leaves : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + (Z.nodes : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512

/-- The hidden points' per-query rate after the request (an unopened leaf is hit by naming its salt). -/
noncomputable def δhid (Z : ZKShape) : ℝ≥0∞ := (Z.leaves : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256

/-- Two points collide: at most `pts²` pairs, `2^-256` each. -/
noncomputable def εcoll (Z : ZKShape) : ℝ≥0∞ := ((Z.pts * Z.pts : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256

/-- **A run's shape is the sum of its parts'**: one transcript end to end, every commitment's leaves and nodes, every
prover's queries. -/
def add (Z Z' : ZKShape) : ZKShape := ⟨Z.leaves + Z'.leaves, Z.nodes + Z'.nodes, Z.chain + Z'.chain, Z.qp + Z'.qp⟩

/-- `2^a · 2^-e = 2^-(e − a)` for `a ≤ e`. -/
theorem pow2_mul_inv_pow {a e : ℕ} (h : a ≤ e) : (2 : ℝ≥0∞) ^ a * (2⁻¹ : ℝ≥0∞) ^ e = (2⁻¹ : ℝ≥0∞) ^ (e - a) := by
  obtain ⟨c, rfl⟩ := Nat.exists_eq_add_of_le h
  rw [Nat.add_sub_cancel_left]
  exact two_pow_mul_inv_pow a c

/-- A count below `2^a` times `2^-e` is below `2^-(e − a)`. -/
theorem count_le {N a e : ℕ} (hN : N ≤ 2 ^ a) (hae : a ≤ e) :
    (N : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ e ≤ (2⁻¹ : ℝ≥0∞) ^ (e - a) := by
  obtain ⟨c, rfl⟩ := Nat.exists_eq_add_of_le hae
  rw [Nat.add_sub_cancel_left]
  exact count_mul_inv_pow_le hN

/-- **A shape's rates**: with `chain + 2·leaves + nodes ≤ 2^a` the per-query rates add up to at most `2^-(256 − a)`;
with `pts ≤ 2^c` the collisions are at most `2^-(256 − 2c)`. -/
theorem rates_le (Z : ZKShape) (a c : ℕ) (ha : Z.chain + 2 * Z.leaves + Z.nodes ≤ 2 ^ a) (ha' : a ≤ 256)
    (hc : Z.pts ≤ 2 ^ c) (hc' : 2 * c ≤ 256) :
    Z.δprog + Z.δhid ≤ (2⁻¹ : ℝ≥0∞) ^ (256 - a) ∧ Z.εcoll ≤ (2⁻¹ : ℝ≥0∞) ^ (256 - 2 * c) := by
  constructor
  · have h512 : (2⁻¹ : ℝ≥0∞) ^ 512 ≤ (2⁻¹ : ℝ≥0∞) ^ 256 := inv_pow_le_inv_pow (by norm_num)
    have hsum : Z.δprog + Z.δhid ≤ ((Z.chain + 2 * Z.leaves + Z.nodes : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := by
      unfold δprog δhid
      calc ((Z.chain + Z.leaves : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + (Z.nodes : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512
            + (Z.leaves : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256
          ≤ ((Z.chain + Z.leaves : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + (Z.nodes : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256
            + (Z.leaves : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 :=
            add_le_add_left (add_le_add_right (mul_le_mul_right h512 _) _) _
        _ = _ := by push_cast; ring
    exact hsum.trans (count_le ha ha')
  · have hp : Z.pts * Z.pts ≤ 2 ^ (2 * c) := by
      calc Z.pts * Z.pts ≤ 2 ^ c * 2 ^ c := Nat.mul_le_mul hc hc
        _ = 2 ^ (2 * c) := by rw [← pow_add, two_mul]
    exact count_le hp hc'

end ZKShape

/-! ## The budget, generic in the shape -/

/-- **The per-step error of a receipt of shape `Z`** at a hybrid's step `j` (`w16Step` at the shape's rates). -/
noncomputable def zkStep (Z : ZKShape) (q R j : ℕ) : ℝ≥0∞ := w16Step Z.δprog Z.δhid Z.εcoll Z.qp q R j

/-- **The budget meets the approved target for every `q` and every `R ≤ 2^r`**, given per-query rates
`δp + δh ≤ 2^-t`, collisions `εc ≤ 2^-124`, `qp ≤ 2^b` prover queries, `b ≥ 6` and `r + b + 123 ≤ t`. -/
theorem zkBudget_le (q R qp r b t : ℕ) (hR : R ≤ 2 ^ r) (hqp : qp ≤ 2 ^ b) (hb : 6 ≤ b) (ht : r + b + 123 ≤ t)
    (δp δh εc : ℝ≥0∞) (hδ : δp + δh ≤ (2⁻¹ : ℝ≥0∞) ^ t) (hεc : εc ≤ (2⁻¹ : ℝ≥0∞) ^ 124) :
    ∑ j ∈ range R, w16Step δp δh εc qp q R j ≤ εzkTarget q R := by
  have hR' : (R : ℝ≥0∞) ≤ 2 ^ r := by exact_mod_cast hR
  have hqp' : (qp : ℝ≥0∞) ≤ 2 ^ b := by exact_mod_cast hqp
  have hterm : ∀ j ∈ range R, w16Step δp δh εc qp q R j
      ≤ 2 * (((q : ℝ≥0∞) + R * qp) * (δp + δh)) + 4 * εc := by
    intro j hj
    have hjR : j ≤ R := (mem_range.mp hj).le
    have h1 : ((q + j * qp : ℕ) : ℝ≥0∞) ≤ (q : ℝ≥0∞) + R * qp := by
      push_cast
      exact add_le_add_right (mul_le_mul_left ((Nat.cast_le (α := ℝ≥0∞)).mpr hjR) _) _
    have h2 : ((q + R * qp : ℕ) : ℝ≥0∞) = (q : ℝ≥0∞) + R * qp := by push_cast; ring
    unfold w16Step
    calc 2 * (((q + j * qp : ℕ) : ℝ≥0∞) * δp) + 4 * εc + 2 * (((q + R * qp : ℕ) : ℝ≥0∞) * δh)
        ≤ 2 * (((q : ℝ≥0∞) + R * qp) * δp) + 4 * εc + 2 * (((q : ℝ≥0∞) + R * qp) * δh) := by
          rw [h2]
          exact add_le_add_left (add_le_add_left (mul_le_mul_right (mul_le_mul_left h1 _) _) _) _
      _ = 2 * (((q : ℝ≥0∞) + R * qp) * (δp + δh)) + 4 * εc := by ring
  have hA : 2 * (R : ℝ≥0∞) * (δp + δh) ≤ (2⁻¹ : ℝ≥0∞) ^ 128 := by
    calc 2 * (R : ℝ≥0∞) * (δp + δh) ≤ 2 * 2 ^ r * (2⁻¹ : ℝ≥0∞) ^ t := mul_le_mul' (mul_le_mul_right hR' _) hδ
      _ = (2 : ℝ≥0∞) ^ (r + 1) * (2⁻¹ : ℝ≥0∞) ^ t := by ring
      _ = (2⁻¹ : ℝ≥0∞) ^ (t - (r + 1)) := ZKShape.pow2_mul_inv_pow (by omega)
      _ ≤ (2⁻¹ : ℝ≥0∞) ^ 128 := inv_pow_le_inv_pow (by omega)
  have hB : 2 * ((R : ℝ≥0∞) * qp) * (δp + δh) + 4 * εc ≤ (2⁻¹ : ℝ≥0∞) ^ 120 := by
    have hB1 : 2 * ((R : ℝ≥0∞) * qp) * (δp + δh) ≤ (2⁻¹ : ℝ≥0∞) ^ 122 := by
      calc 2 * ((R : ℝ≥0∞) * qp) * (δp + δh) ≤ 2 * (2 ^ r * 2 ^ b) * (2⁻¹ : ℝ≥0∞) ^ t :=
            mul_le_mul' (mul_le_mul_right (mul_le_mul' hR' hqp') _) hδ
        _ = (2 : ℝ≥0∞) ^ (r + b + 1) * (2⁻¹ : ℝ≥0∞) ^ t := by ring
        _ = (2⁻¹ : ℝ≥0∞) ^ (t - (r + b + 1)) := ZKShape.pow2_mul_inv_pow (by omega)
        _ ≤ (2⁻¹ : ℝ≥0∞) ^ 122 := inv_pow_le_inv_pow (by omega)
    have hB2 : 4 * εc ≤ (2⁻¹ : ℝ≥0∞) ^ 122 := by
      calc 4 * εc ≤ 4 * (2⁻¹ : ℝ≥0∞) ^ 124 := mul_le_mul_right hεc _
        _ = (2 : ℝ≥0∞) ^ 2 * (2⁻¹ : ℝ≥0∞) ^ (2 + 122) := by ring
        _ = (2⁻¹ : ℝ≥0∞) ^ 122 := two_pow_mul_inv_pow 2 122
    calc 2 * ((R : ℝ≥0∞) * qp) * (δp + δh) + 4 * εc ≤ (2⁻¹ : ℝ≥0∞) ^ 122 + (2⁻¹ : ℝ≥0∞) ^ 122 :=
          add_le_add hB1 hB2
      _ = (2 : ℝ≥0∞) ^ 1 * (2⁻¹ : ℝ≥0∞) ^ (1 + 121) := by ring
      _ = (2⁻¹ : ℝ≥0∞) ^ 121 := two_pow_mul_inv_pow 1 121
      _ ≤ (2⁻¹ : ℝ≥0∞) ^ 120 := inv_pow_le_inv_pow (by norm_num)
  calc ∑ j ∈ range R, w16Step δp δh εc qp q R j
      ≤ ∑ _j ∈ range R, (2 * (((q : ℝ≥0∞) + R * qp) * (δp + δh)) + 4 * εc) := sum_le_sum hterm
    _ = (R : ℝ≥0∞) * (2 * (((q : ℝ≥0∞) + R * qp) * (δp + δh)) + 4 * εc) := by
        rw [sum_const, card_range, nsmul_eq_mul]
    _ = (q : ℝ≥0∞) * (2 * (R : ℝ≥0∞) * (δp + δh))
          + (R : ℝ≥0∞) * (2 * ((R : ℝ≥0∞) * qp) * (δp + δh) + 4 * εc) := by ring
    _ ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 128 + (R : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 120 :=
        add_le_add (mul_le_mul_right hA _) (mul_le_mul_right hB _)
    _ = εzkTarget q R := rfl

/-- **A shape's budget within the target**: with `chain + 2·leaves + nodes ≤ 2^a`, `qp ≤ 2^b` (`b ≥ 6`),
`pts ≤ 2^c` (`2c ≤ 132`) and `r + b + 123 + a ≤ 256`, the summed per-step error is within `εzkTarget q R` for every `q`
and every `R ≤ 2^r`. -/
theorem zkStep_within_target (Z : ZKShape) (a b c r : ℕ) (ha : Z.chain + 2 * Z.leaves + Z.nodes ≤ 2 ^ a)
    (hb : Z.qp ≤ 2 ^ b) (hb6 : 6 ≤ b) (hc : Z.pts ≤ 2 ^ c) (hc' : 2 * c ≤ 132) (hr : r + b + 123 + a ≤ 256)
    (q R : ℕ) (hR : R ≤ 2 ^ r) : ∑ j ∈ range R, zkStep Z q R j ≤ εzkTarget q R := by
  obtain ⟨h1, h2⟩ := Z.rates_le a c ha (by omega) hc (by omega)
  exact zkBudget_le q R Z.qp r b (256 - a) hR hb hb6 (by omega) _ _ _ h1
    (h2.trans (inv_pow_le_inv_pow (by omega)))

/-! ## The assembled statement, the shape as the parameter -/

section Assembled

variable {Q D Coins : Type} [DecidableEq Q] {M : IntModel} {P : Protocol Q D Coins M} [Inhabited M.Input]
  [Fintype Q] [Fintype D] [Nonempty D] [Fintype Coins] [Nonempty Coins]

open Classical in
/-- **Zero knowledge with the receipt's shape as the parameter** (the form L17 and L18 instantiate). For every weight
set, let the protocol's prover be the honest prover of a Fiat–Shamir receipt model (`hP`), given as a query-bounded
computation of at most `Z.qp` queries (`pOC`, `hrun`, `hbd`), with the honest-verifier law on an input and its stand-in
(`hHV`) and its counts within the shape's rates (`hK` … `hrKU`). If the shape fits (`a`, `b`, `c`, `r` as in
`zkStep_within_target`), the protocol is zero knowledge with the stand-in simulator and error `Σ_{j<R} zkStep Z q R j`,
which is at most `εzkTarget q R` for every `q` and every `R ≤ 2^r`. -/
theorem zk_within_target_of_shape [Inhabited D] [Inhabited Coins] (Z : ZKShape)
    (pOC : M.Weights → M.Input → Coins → OC Q D (P.Stmt × P.Receipt))
    (hrun : ∀ W H x c, (pOC W x c).run H = P.prove H W x c) (hbd : ∀ W x c, (pOC W x c).Bounded Z.qp)
    (FM : M.Weights → FSModel Q D M.Input Coins (P.Stmt × P.Receipt))
    (hP : ∀ W H x c, P.prove H W x c = (FM W).prove H x c)
    (hHV : ∀ W x (v : Fin (FM W).k → D), (PMF.uniformOfFintype Coins).map (fun c => (FM W).out x c v)
      = (PMF.uniformOfFintype Coins).map
          (fun c => (FM W).out (standin P W (M.publicPart (M.forward W x), P.leak x)) c v))
    (K Kc KU : M.Weights → ℕ)
    (hK : ∀ W x (H : Q → D) z, (univ.filter (fun s : Coins × (Fin (FM W).k → D) =>
      ∃ i, (FM W).pts x s.1 H s.2 i = z)).card ≤ K W)
    (hKc : ∀ W x (H : Q → D), (univ.filter (fun s : Coins × (Fin (FM W).k → D) =>
      ¬ Function.Injective ((FM W).pts x s.1 H s.2) ∨ ∃ i, (FM W).pts x s.1 H s.2 i ∈ (FM W).dep x s.1)).card
        ≤ Kc W)
    (hU : ∀ W (q₂ : ℕ) x (H : Q → D) (v : Fin (FM W).k → D) (Z' : (P.Stmt × P.Receipt) → Finset Q),
      (∀ o, (Z' o).card ≤ q₂) →
      (univ.filter (fun c => ∃ i, ¬ (FM W).vis v i ∧ (FM W).pts x c H v i ∈ Z' ((FM W).out x c v))).card
        ≤ q₂ * KU W)
    (hrK : ∀ W, (K W : ℝ≥0∞) / Fintype.card (Coins × (Fin (FM W).k → D)) ≤ Z.δprog)
    (hrKc : ∀ W, (Kc W : ℝ≥0∞) / Fintype.card (Coins × (Fin (FM W).k → D)) ≤ Z.εcoll)
    (hrKU : ∀ W, (KU W : ℝ≥0∞) / Fintype.card Coins ≤ Z.δhid)
    (a b c r : ℕ) (ha : Z.chain + 2 * Z.leaves + Z.nodes ≤ 2 ^ a) (hb : Z.qp ≤ 2 ^ b) (hb6 : 6 ≤ b)
    (hc : Z.pts ≤ 2 ^ c) (hc' : 2 * c ≤ 132) (hr : r + b + 123 + a ≤ 256) :
    ZeroKnowledge M P (fun q R => ∑ j ∈ range R, zkStep Z q R j)
      ∧ ∀ q R, R ≤ 2 ^ r → ∑ j ∈ range R, zkStep Z q R j ≤ εzkTarget q R :=
  ⟨w16r2_zeroKnowledge_of_fsModel pOC Z.qp hrun hbd FM hP hHV K Kc KU hK hKc hU _ _ _ hrK hrKc hrKU,
    fun q R hR => zkStep_within_target Z a b c r ha hb hb6 hc hc' hr q R hR⟩

end Assembled

/-! ## W16R2 as one instance -/

namespace W16R2Z

/-- **The W16R2 block's shape** (the development rung's geometry). -/
def shape : ZKShape := ⟨leaves, nodes, chainMax, proverQueries⟩

/-- **W16R2 fits with `a = 19`, `b = 18`, `c = 18`, `r = 96`**: its receipts are within the target up to `2^96` per
weight set. -/
theorem shape_fits : shape.chain + 2 * shape.leaves + shape.nodes ≤ 2 ^ 19 ∧ shape.qp ≤ 2 ^ 18 ∧ 6 ≤ 18
    ∧ shape.pts ≤ 2 ^ 18 ∧ 2 * 18 ≤ 132 ∧ 96 + 18 + 123 + 19 ≤ 256 := by
  decide

/-- The shape's rates are the ones of `ZKW16Block` (`δprog`, `δhid`; the collision term is the shape's own). -/
theorem shape_rates : shape.δprog = δprog ∧ shape.δhid = δhid := ⟨rfl, rfl⟩

end W16R2Z

end ZK60.ZKW16
