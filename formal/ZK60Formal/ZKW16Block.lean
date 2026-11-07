/-
D63 step L14 (Statement 2, zero knowledge), part 4: the W16R2 block profile. Its declared leakage, its simulator, the
refusal, the `R`-receipt hybrid with a per-step error that may depend on `R`, and the error budget against the approved
`εzkTarget`.

* **The leakage** (`Leak16`, `leak16`): the registered profile string (the model, the shapes, the slot schedule, the
  D55 fork plan; the receipt length `Geom.forkLen` is a function of it), the token count `T`, and the served bit. The
  public output part (nothing, or the classifier's verdict, D58/D61) is `IntModel.publicPart`, which `Statements.lean`
  carries separately.
* **D65(2)'s constant refusal** (`ConstRefusal`): every refusal that leaves the prover is one fixed output. With the
  served bit in the leakage, two inputs with the same leakage are both served or both refused, and two refused inputs
  give the SAME output, so the premise `o ≠ o'` of `HidingRefusal.refusal_output_must_be_leaked` never holds: `leak`
  determines the refusal output, as that theorem demands (`constRefusal_meets_leak_condition`). Conversely, a prover
  returning the refusal SITE breaks `ZeroKnowledge` at every error below `1/2` (`site_refusal_breaks_zk`).
* **The simulator** (`standin`, `standinSim`, `standinSimulator`): the honest prover run on a STAND-IN input with the
  same public output part and the same leakage, against the current oracle, programming nothing (finding A6's
  simulator). It is a `ProgSim` with an empty table, hence a `Simulator` of `Statements.lean` (`ProgSim.toSim`); its
  receipts are the honest prover's (L9's `Core` for a block), so they decode and verify like real ones. Why this one:
  its hybrid steps are honest-versus-honest against the real oracle, the hybrid's table stays empty, and the
  Fiat–Shamir programming is a proof device inside each step (`ZKW16Step.fs_step`, used in both directions), not a
  property the simulator must have; the price is a factor 2 in the per-step error.
* `zeroKnowledge_of_hybrid_R`: `ZKHybrid.zeroKnowledge_of_hybrid` with a per-step error that may depend on `R` (a
  receipt's later context holds the honest provers of the later requests, whose queries count against it).
* **The budget** (`w16Step`, `w16Budget_le`, `w16r2_rates`, `w16r2_rate_gt`): with the W16R2 counts (`W16R2Z`), the sum
  of the per-step errors of `fs_step` is at most `εzkTarget q R` for EVERY `q` and every `R ≤ 2^96`; the per-query,
  per-receipt rate of this proof is about `2^-237`, above the `2^-248` that `zeroKnowledge_target_of_hybrid` asks
  (finding L14-1: A5 confirmed at W16R2, with the numbers).

Every premise is an explicit hypothesis; no `sorry`, axiom or `native_decide`.
-/
import ZK60Formal.ZKW16Step
import ZK60Formal.ZKW16View
import ZK60Formal.ExecBlockFS

namespace ZK60.ZKW16

open scoped ENNReal
open Finset
open ZK60.ZKHybrid

/-! ## The declared leakage -/

/-- **The declared leakage of one W16R2 request** (D63 Statement 2's list): the registered profile (the model, the
shapes and slot schedule, the D55 fork plan; the receipt's length is a function of it), the token count `T`, and
whether the request is served. -/
structure Leak16 where
  profile : List UInt8
  tokens : ℕ
  served : Bool
  deriving DecidableEq

/-- The leakage function of a profile: its string, the input's token count and its served bit. -/
def leak16 {Inp : Type} (profile : List UInt8) (tokens : Inp → ℕ) (served : Inp → Bool) (x : Inp) : Leak16 :=
  ⟨profile, tokens x, served x⟩

/-- Two inputs with the same leakage are both served or both refused. -/
theorem leak16_served {Inp : Type} {profile : List UInt8} {tokens : Inp → ℕ} {served : Inp → Bool} {x x' : Inp}
    (h : leak16 profile tokens served x = leak16 profile tokens served x') : served x = served x' := by
  simp only [leak16, Leak16.mk.injEq] at h
  exact h.2.2

/-! ## D65(2): the constant refusal -/

section Refusal

variable {Q D Coins : Type} {M : IntModel}

/-- **D65(2): one constant external refusal.** Whatever the site, the table family or the dictionary detail, a refused
request gets the one output `o₀` (the details go to the owner's private log only). -/
def ConstRefusal (P : Protocol Q D Coins M) (served : M.Input → Bool) (o₀ : P.Stmt × P.Receipt) : Prop :=
  ∀ H W x c, served x = false → P.prove H W x c = o₀

/-- **The leakage determines the refusal output** (the condition `HidingRefusal.refusal_output_must_be_leaked` puts on
`leak`). With the served bit read off the leakage (`servedOf`; for `Leak16` it is `Leak16.served`) and D65(2)'s constant
refusal, two inputs with the same leakage that are
answered deterministically, one of them refused, get the SAME output: the premise `o ≠ o'` of that theorem cannot
hold. -/
theorem constRefusal_meets_leak_condition [Nonempty D] [Nonempty Coins] (P : Protocol Q D Coins M)
    (served : M.Input → Bool) (servedOf : P.Leak → Bool) (hleak : ∀ x, servedOf (P.leak x) = served x)
    (o₀ : P.Stmt × P.Receipt) (h : ConstRefusal P served o₀) (W : M.Weights) (x x' : M.Input)
    (o o' : P.Stmt × P.Receipt) (ho : ∀ H c, P.prove H W x c = o) (ho' : ∀ H c, P.prove H W x' c = o')
    (hl : P.leak x = P.leak x') (hx : served x = false) : o = o' := by
  have hx' : served x' = false := by
    rw [← hleak x', ← hl, hleak x]
    exact hx
  obtain ⟨d⟩ := ‹Nonempty D›
  obtain ⟨c⟩ := ‹Nonempty Coins›
  rw [← ho (fun _ => d) c, ← ho' (fun _ => d) c, h _ W x c hx, h _ W x' c hx']

/-- **A refusal that names its site breaks zero knowledge.** If two inputs with the same public part and leakage are
refused deterministically with DIFFERENT outputs (the code before D65(2): the site of a "fixed oracle range refusal",
the family of a CS-3 lookup miss), no simulator reaches an error below `1/2` (`refusal_output_must_be_leaked`). -/
theorem site_refusal_breaks_zk [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [Fintype Coins]
    [Nonempty Coins] [Inhabited Coins] (P : Protocol Q D Coins M) (W : M.Weights) (x x' : M.Input)
    (o o' : P.Stmt × P.Receipt) (ho : ∀ H c, P.prove H W x c = o) (ho' : ∀ H c, P.prove H W x' c = o')
    (hne : o ≠ o') (hpub : M.publicPart (M.forward W x) = M.publicPart (M.forward W x'))
    (hleak : P.leak x = P.leak x') (εzk : ℕ → ℕ → ℝ≥0∞) (hlt : εzk 0 1 < 2⁻¹) : ¬ ZeroKnowledge M P εzk :=
  fun hzk => absurd (Hiding.refusal_output_must_be_leaked P W x x' o o' ho ho' hne hpub hleak εzk hzk) (not_le.mpr hlt)

end Refusal

/-! ## The simulator: the honest prover on a stand-in -/

section Simulator

variable {Q D Coins : Type} {M : IntModel}

open Classical in
/-- **The stand-in input**: an input with the requested public output part and leakage (one exists for every pair a
real request presents; any default otherwise). -/
noncomputable def standin (P : Protocol Q D Coins M) [Inhabited M.Input] (W : M.Weights)
    (z : M.PubOut × P.Leak) : M.Input :=
  if h : ∃ x, (M.publicPart (M.forward W x), P.leak x) = z then h.choose else default

/-- The stand-in of a real request's public data has that public data. -/
theorem standin_spec (P : Protocol Q D Coins M) [Inhabited M.Input] (W : M.Weights) (x : M.Input) :
    (M.publicPart (M.forward W (standin P W (M.publicPart (M.forward W x), P.leak x))),
      P.leak (standin P W (M.publicPart (M.forward W x), P.leak x)))
      = (M.publicPart (M.forward W x), P.leak x) := by
  classical
  have h : ∃ x', (M.publicPart (M.forward W x'), P.leak x') = (M.publicPart (M.forward W x), P.leak x) := ⟨x, rfl⟩
  unfold standin
  rw [dite_eq_left h]
  exact h.choose_spec

/-- **The simulator** (finding A6): one receipt is the honest prover's on the stand-in, against the current oracle,
with the simulator's own coin; nothing is programmed. -/
noncomputable def standinSim (P : Protocol Q D Coins M) [Inhabited M.Input] : ProgSim M P Coins :=
  ⟨fun W H z c => (P.prove H W (standin P W z) c, [])⟩

/-- **It is a `Simulator` of `Statements.lean`.** -/
noncomputable def standinSimulator [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [Inhabited D]
    [Fintype Coins] [Nonempty Coins] [Inhabited Coins] (P : Protocol Q D Coins M) [Inhabited M.Input] :
    Simulator M P :=
  (standinSim P).toSim

/-- In every hybrid the stand-in simulator leaves the table empty: a simulated request answers with the honest
prover on the stand-in, against the base oracle. -/
theorem standin_hybStep [DecidableEq Q] (P : Protocol Q D Coins M) [Inhabited M.Input] (W : M.Weights)
    (H : Q → D) (j cnt : ℕ) (x : M.Input) (c : Coins × Coins) :
    hybStep (standinSim P) W H j (cnt, []) (.inr x) c
      = if cnt < j then (.inr (P.prove H W (standin P W (M.publicPart (M.forward W x), P.leak x)) c.2), (cnt + 1, []))
        else (.inr (P.prove H W x c.1), (cnt + 1, [])) := by
  unfold hybStep standinSim
  simp [ovr]

end Simulator

/-! ## The hybrid with an `R`-dependent step -/

section HybridR

variable {Q D Coins SC : Type} [DecidableEq Q] {M : IntModel} {P : Protocol Q D Coins M}
  [Fintype Q] [Fintype D] [Nonempty D] [Fintype SC] [Nonempty SC] [Inhabited SC]
  [Fintype Coins] [Nonempty Coins] [Inhabited Coins]

/-- **The `R`-receipt hybrid, the step error depending on `R` too.** If, for every distinguisher with at most `q` hash
queries and `R` proof requests, each step `j < R` moves the hybrid's probability by at most `ε q R j` both ways, then
`ZeroKnowledge M P (fun q R => Σ_{j<R} ε q R j)` with the simulator `PS.toSim`. -/
theorem zeroKnowledge_of_hybrid_R (PS : ProgSim M P SC) (ε : ℕ → ℕ → ℕ → ℝ≥0∞)
    (hstep : ∀ (W : M.Weights) (q R : ℕ) (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool),
      Dist.Within q R → ∀ j < R,
        hybProb PS W (q + R) Dist j ≤ hybProb PS W (q + R) Dist (j + 1) + ε q R j
        ∧ hybProb PS W (q + R) Dist (j + 1) ≤ hybProb PS W (q + R) Dist j + ε q R j) :
    ZeroKnowledge M P (fun q R => ∑ j ∈ range R, ε q R j) := by
  have _inst : Inhabited D := ⟨Classical.arbitrary D⟩
  refine ⟨PS.toSim, fun W q R Dist hD => ?_⟩
  rw [← hybProb_zero PS W (q + R) Dist, ← hybProb_ge PS W q R Dist hD R le_rfl]
  exact ⟨telescope_le (p := fun j => hybProb PS W (q + R) Dist j) (e := fun j => ε q R j) R
      (fun j hj => (hstep W q R Dist hD j hj).1),
    telescope_ge (p := fun j => hybProb PS W (q + R) Dist j) (e := fun j => ε q R j) R
      (fun j hj => (hstep W q R Dist hD j hj).2)⟩

end HybridR

/-! ## W16R2's counts (the development rung, L9's corpus) -/

namespace W16R2Z

/-- The encoded columns of `A` and of `H` (`enc_cols 32768`: `log_cols` 14 at rate 1/2), each one salted leaf. -/
def aCols : ℕ := 32768
def hCols : ℕ := 32768
/-- `M`'s columns, `2^MASK_LOG_DOM` (`ExecBlockFS.W16R2.maskDom`). -/
def mCols : ℕ := 4096
/-- Every salted leaf of the block's three commitments. -/
def leaves : ℕ := aCols + hCols + mCols
/-- Every inner node of the three Merkle trees. -/
def nodes : ℕ := (aCols - 1) + (hCols - 1) + (mCols - 1)
/-- The block's own transcript points (its absorbs and squeezes after the header): `1,609` squeezes (the corpus's end
counter) and about `420` absorbs, at most `2^12` in all. The header's points are public, not programmed. -/
def chainMax : ℕ := 4096
/-- The prover's hash queries per receipt: a column hash and a salted leaf per column, every node, every transcript
point. -/
def proverQueries : ℕ := leaves + leaves + nodes + chainMax

theorem leaves_eq : leaves = 69632 := rfl
theorem nodes_eq : nodes = 69629 := rfl
theorem proverQueries_le : proverQueries ≤ 2 ^ 18 := by decide

/-- The programmed points' per-query rate before the request: one query hits a transcript point only by naming its
fresh state (`2^-256` each), a leaf only by naming its salt (`2^-256`), a node only by naming both children (`2^-512`). -/
noncomputable def δprog : ℝ≥0∞ :=
  ((chainMax + leaves : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + (nodes : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512

/-- The hidden points' per-query rate after the request: a query hits an unopened leaf only by naming its salt. -/
noncomputable def δhid : ℝ≥0∞ := (leaves : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256

/-- Two of the at most `2^18` points collide: at most `2^36` pairs, `2^-256` each (query-free). -/
noncomputable def εcoll : ℝ≥0∞ := ((2 ^ 36 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256

end W16R2Z

/-! ## Powers of one half -/

/-- `2^a · 2^-(a+b) = 2^-b`. -/
theorem two_pow_mul_inv_pow (a b : ℕ) : (2 : ℝ≥0∞) ^ a * (2⁻¹ : ℝ≥0∞) ^ (a + b) = (2⁻¹ : ℝ≥0∞) ^ b := by
  rw [pow_add, ← mul_assoc, ← mul_pow, ENNReal.mul_inv_cancel two_ne_zero ENNReal.ofNat_ne_top, one_pow, one_mul]

/-- Smaller powers of one half are larger. -/
theorem inv_pow_le_inv_pow {a b : ℕ} (h : a ≤ b) : (2⁻¹ : ℝ≥0∞) ^ b ≤ (2⁻¹ : ℝ≥0∞) ^ a := by
  obtain ⟨c, rfl⟩ := Nat.exists_eq_add_of_le h
  rw [pow_add]
  calc (2⁻¹ : ℝ≥0∞) ^ a * (2⁻¹ : ℝ≥0∞) ^ c ≤ (2⁻¹ : ℝ≥0∞) ^ a * 1 :=
        mul_le_mul_right (pow_le_one₀ zero_le (ENNReal.inv_le_one.mpr one_le_two)) _
    _ = (2⁻¹ : ℝ≥0∞) ^ a := mul_one _

/-- A count below `2^a` times `2^-(a+b)` is below `2^-b`. -/
theorem count_mul_inv_pow_le {N a b : ℕ} (hN : N ≤ 2 ^ a) :
    (N : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ (a + b) ≤ (2⁻¹ : ℝ≥0∞) ^ b := by
  calc (N : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ (a + b) ≤ (2 : ℝ≥0∞) ^ a * (2⁻¹ : ℝ≥0∞) ^ (a + b) :=
        mul_le_mul_left (by exact_mod_cast hN) _
    _ = (2⁻¹ : ℝ≥0∞) ^ b := two_pow_mul_inv_pow a b

/-! ## The budget -/

/-- **The per-step error of `fs_step` at a hybrid's step `j`** (`R` requests, `q` hash queries, `qp` prover queries per
receipt): before the request at most `q + j·qp` queries (the distinguisher's and the earlier stand-in provers'), after it
at most `q + R·qp`; per-query rates `δp` (programmed points) and `δh` (hidden points), and the collisions `εc`. -/
noncomputable def w16Step (δp δh εc : ℝ≥0∞) (qp q R j : ℕ) : ℝ≥0∞ :=
  2 * (((q + j * qp : ℕ) : ℝ≥0∞) * δp) + 4 * εc + 2 * (((q + R * qp : ℕ) : ℝ≥0∞) * δh)

/-- **The budget meets the approved target for every `q` and every `R ≤ 2^96`**, given per-query rates
`δp + δh ≤ 2^-237`, collisions `εc ≤ 2^-124` and at most `2^18` prover queries per receipt:
`Σ_{j<R} w16Step ≤ q·2^-128 + R·2^-120`. -/
theorem w16Budget_le (q R qp : ℕ) (hR : R ≤ 2 ^ 96) (hqp : qp ≤ 2 ^ 18) (δp δh εc : ℝ≥0∞)
    (hδ : δp + δh ≤ (2⁻¹ : ℝ≥0∞) ^ 237) (hεc : εc ≤ (2⁻¹ : ℝ≥0∞) ^ 124) :
    ∑ j ∈ range R, w16Step δp δh εc qp q R j ≤ εzkTarget q R := by
  have hR' : (R : ℝ≥0∞) ≤ 2 ^ 96 := by exact_mod_cast hR
  have hqp' : (qp : ℝ≥0∞) ≤ 2 ^ 18 := by exact_mod_cast hqp
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
  -- the q-part: 2·R·(δp + δh) ≤ 2^97·2^-237 ≤ 2^-128
  have hA : 2 * (R : ℝ≥0∞) * (δp + δh) ≤ (2⁻¹ : ℝ≥0∞) ^ 128 := by
    calc 2 * (R : ℝ≥0∞) * (δp + δh) ≤ 2 * 2 ^ 96 * (2⁻¹ : ℝ≥0∞) ^ 237 := mul_le_mul' (mul_le_mul_right hR' _) hδ
      _ = (2 : ℝ≥0∞) ^ 97 * (2⁻¹ : ℝ≥0∞) ^ (97 + 140) := by ring
      _ = (2⁻¹ : ℝ≥0∞) ^ 140 := two_pow_mul_inv_pow 97 140
      _ ≤ (2⁻¹ : ℝ≥0∞) ^ 128 := inv_pow_le_inv_pow (by norm_num)
  -- the R-part: 2·R·qp·(δp + δh) + 4·εc ≤ 2^-122 + 2^-122 ≤ 2^-120
  have hB : 2 * ((R : ℝ≥0∞) * qp) * (δp + δh) + 4 * εc ≤ (2⁻¹ : ℝ≥0∞) ^ 120 := by
    have hB1 : 2 * ((R : ℝ≥0∞) * qp) * (δp + δh) ≤ (2⁻¹ : ℝ≥0∞) ^ 122 := by
      calc 2 * ((R : ℝ≥0∞) * qp) * (δp + δh) ≤ 2 * (2 ^ 96 * 2 ^ 18) * (2⁻¹ : ℝ≥0∞) ^ 237 :=
            mul_le_mul' (mul_le_mul_right (mul_le_mul' hR' hqp') _) hδ
        _ = (2 : ℝ≥0∞) ^ 115 * (2⁻¹ : ℝ≥0∞) ^ (115 + 122) := by ring
        _ = (2⁻¹ : ℝ≥0∞) ^ 122 := two_pow_mul_inv_pow 115 122
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

/-- **W16R2's rates**: the programmed and hidden points' per-query rates add up to at most `2^-237`, the collisions to
at most `2^-124`, and the prover's queries per receipt to at most `2^18`. -/
theorem w16r2_rates : W16R2Z.δprog + W16R2Z.δhid ≤ (2⁻¹ : ℝ≥0∞) ^ 237 ∧ W16R2Z.εcoll ≤ (2⁻¹ : ℝ≥0∞) ^ 124
    ∧ W16R2Z.proverQueries ≤ 2 ^ 18 := by
  refine ⟨?_, ?_, W16R2Z.proverQueries_le⟩
  · have h512 : (2⁻¹ : ℝ≥0∞) ^ 512 ≤ (2⁻¹ : ℝ≥0∞) ^ 256 := inv_pow_le_inv_pow (by norm_num)
    have hsum : W16R2Z.δprog + W16R2Z.δhid
        ≤ ((W16R2Z.chainMax + W16R2Z.leaves + W16R2Z.nodes + W16R2Z.leaves : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := by
      unfold W16R2Z.δprog W16R2Z.δhid
      calc ((W16R2Z.chainMax + W16R2Z.leaves : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256
            + (W16R2Z.nodes : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 512 + (W16R2Z.leaves : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256
          ≤ ((W16R2Z.chainMax + W16R2Z.leaves : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256
            + (W16R2Z.nodes : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 + (W16R2Z.leaves : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 :=
            add_le_add_left (add_le_add_right (mul_le_mul_right h512 _) _) _
        _ = _ := by push_cast; ring
    refine hsum.trans ?_
    exact count_mul_inv_pow_le (a := 19) (b := 237) (by decide)
  · exact count_mul_inv_pow_le (a := 132) (b := 124) (by decide)

/-- **Finding L14-1 (A5 at W16R2), the rate.** The per-query, per-receipt rate of this proof, `2·(δp + δh)`, is above
the `2^-248` that `ZKHybrid.zeroKnowledge_target_of_hybrid` asks: the hidden leaves alone give
`2·69,632·2^-256 ≈ 2^-238.9`. -/
theorem w16r2_rate_gt : (2⁻¹ : ℝ≥0∞) ^ 248 < 2 * (W16R2Z.δprog + W16R2Z.δhid) := by
  have h256 : (2⁻¹ : ℝ≥0∞) ^ 248 = ((2 ^ 8 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := by
    rw [show (256 : ℕ) = 8 + 248 by norm_num, Nat.cast_pow, Nat.cast_ofNat, two_pow_mul_inv_pow]
  have hne0 : (2⁻¹ : ℝ≥0∞) ^ 256 ≠ 0 := pow_ne_zero _ (ENNReal.inv_ne_zero.mpr ENNReal.ofNat_ne_top)
  have hnet : (2⁻¹ : ℝ≥0∞) ^ 256 ≠ ∞ := ENNReal.pow_ne_top (ENNReal.inv_ne_top.mpr two_ne_zero)
  calc (2⁻¹ : ℝ≥0∞) ^ 248 = ((2 ^ 8 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := h256
    _ < ((2 * W16R2Z.leaves : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 256 := by
        rw [mul_comm _ ((2⁻¹ : ℝ≥0∞) ^ 256), mul_comm _ ((2⁻¹ : ℝ≥0∞) ^ 256)]
        exact ENNReal.mul_lt_mul_right hne0 hnet (by exact_mod_cast (show 2 ^ 8 < 2 * W16R2Z.leaves by decide))
    _ = 2 * W16R2Z.δhid := by unfold W16R2Z.δhid; push_cast; ring
    _ ≤ 2 * (W16R2Z.δprog + W16R2Z.δhid) := mul_le_mul_right le_add_self _

/-! ## W16R2: zero knowledge from the per-step bound -/

section W16

variable {Q D Coins : Type} [DecidableEq Q] {M : IntModel} {P : Protocol Q D Coins M}
  [Fintype Q] [Fintype D] [Nonempty D] [Fintype Coins] [Nonempty Coins] [Inhabited Coins] [Inhabited M.Input]

/-- **Zero knowledge of a W16R2-shaped protocol from its per-step bound.** If every hybrid step of the stand-in
simulator moves the probability by at most `w16Step` (the bound `ZKW16Step.fs_step` gives, with the rates and
counts of the profile), then the protocol is zero knowledge with error `min (Σ_{j<R} w16Step) 1`, and that error is at
most the approved `εzkTarget q R` for every `q` and every `R ≤ 2^96` (`w16Budget_le`). -/
theorem w16r2_zeroKnowledge (δp δh εc : ℝ≥0∞) (qp : ℕ)
    (hstep : ∀ (W : M.Weights) (q R : ℕ) (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool),
      Dist.Within q R → ∀ j < R,
        hybProb (standinSim P) W (q + R) Dist j
            ≤ hybProb (standinSim P) W (q + R) Dist (j + 1) + w16Step δp δh εc qp q R j
        ∧ hybProb (standinSim P) W (q + R) Dist (j + 1)
            ≤ hybProb (standinSim P) W (q + R) Dist j + w16Step δp δh εc qp q R j) :
    ZeroKnowledge M P (fun q R => min (∑ j ∈ range R, w16Step δp δh εc qp q R j) 1) :=
  zeroKnowledge_min_one (zeroKnowledge_of_hybrid_R (standinSim P) (fun q R j => w16Step δp δh εc qp q R j) hstep)

/-- The W16R2 error is within the approved target for every `q` and every `R ≤ 2^96`. -/
theorem w16r2_error_le_target (q R : ℕ) (hR : R ≤ 2 ^ 96) :
    min (∑ j ∈ range R, w16Step W16R2Z.δprog W16R2Z.δhid W16R2Z.εcoll W16R2Z.proverQueries q R j) 1
      ≤ εzkTarget q R :=
  (min_le_left _ _).trans (w16Budget_le q R _ hR w16r2_rates.2.2 _ _ _ w16r2_rates.1 w16r2_rates.2.1)

end W16

end ZK60.ZKW16
