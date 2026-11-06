/-
D63, obligation 3 (`Complete`), GENERIC: the honest prover of each sub-protocol model is accepted, and a composition
lemma in the form `Complete` asks for. Everything is stated over the existing models (`SoundSumcheck`,
`SoundZeroCheck`, `SoundLogUp`, `SoundLogUpBlock`, `SoundOpening`, `SoundMProduct`, `SoundMerkle`,
`HidingSumcheckJoint`), as the L3 and L4 lemmas are, not over the code's concrete layout.

(a) **The sumcheck** (`SoundSumcheck.lean`'s `Accepts`, `FSSumcheck.lean`'s `scAccept`).
* `honestProver`: round `j` sends the true round polynomial's values at `X = 0, …, d` (`honestMsg`), as
  `zkp_core::sumcheck::prove` does. Its interpolant IS the true round polynomial (`interpEval_honestMsg`, by Lagrange
  uniqueness at the `d + 1` distinct nodes), so the round check holds (`honestMsg_check`) and the next claim is again
  true.
* `sumcheck_complete`: for a TRUE claim `Σ f` and `f` of individual degree `≤ d` (`d < char F`), the verifier accepts
  at EVERY challenge vector; `sumcheck_complete_prob` (probability `1`); `sumcheck_complete_list` (the list verifier
  on the honest transcript, so under Fiat–Shamir at every oracle: the challenges never matter).
* `sumcheck_complete_masked` (the `--zk` sumcheck on `f + c·g` with the claim `S + c·G`, every mask `g`, every `c`)
  and `sumcheck_complete_extended` (the last-round extension).
* The CFS mask in the code's coefficient form (`HidingSumcheckJoint.lean`): `cfs_masked_chainDefect`, the masked rounds
  `s_j + c·g_j` have the chain defects `(S + c·G, the unmasked gaps, F + c·g(ρ))`; so an honest chain stays honest,
  with the scalar `S + c·G` and the terminal `F + c·g(ρ)` the verifier checks (`cfs_masked_honest`), for every mask,
  every `c` and every challenge. The prover's one refusal there, `c = 0`, has probability `1/|K|`
  (`cfs_refusal_prob`).
* `zerocheck_complete`: a relation that vanishes on the cube makes `Σ eq(τ, x)·R(x) = 0` true for EVERY `τ`, so the
  zero-check is accepted at every `(τ, ρ)`; batching keeps a zero vector zero (`batch_complete`).

(b) **LogUp** (`SoundLogUp.lean`, `SoundLogUpBlock.lean`).
* `TupleMass`: the honest multiplicities, any natural numbers whose mass per distinct table tuple is the number of
  lookups of that tuple (padded copies of an entry may share it). They exist when every looked-up tuple is in the
  table (`exists_tupleMass`) and they make the identity hold for EVERY fold and at EVERY point (`regroup`,
  `logup_identity_honest`; as rational functions, `logup_ratfunc_honest`), before any challenge is drawn.
* `honestHelpers`, `helperRel_honest`: off the poles the honest helpers `1/(α − a)`, `1/(α − a) + 1/(α − b)`,
  `m/(α − t)` pass every relation and the sum claim.
* The refusal: the honest prover inverts every looked-up and every table denominator, so it refuses exactly when `α`
  is one of the folded table values (`logupRefuses_iff`, by `HidingRefusal.lean`'s `logup_refusal_iff_table`).
  `logup_block_complete_prob`: over uniform `β, γ, α`, the honest LogUp is served and passes, except with probability
  at most `M/|F|`, `M` the number of DISTINCT table tuples.

(c) **The opening** (`SoundOpening.lean`, `SoundMerkle.lean`).
* `opening_complete`: with codeword rows and a true claim, the honest group vector `Σ a_i·U_i` and proximity vector
  `Σ ρ_i·U_i` are codewords and pass at every `ρ` and every column draw (`opening_complete_prob`: probability `1`).
* `mproduct_complete`, `mopening_complete`: `M`'s product test and its proximity test (`SoundMProduct.lean`) pass at
  every `θ`, `r` and column sample for honest rows, the honest values, the product polynomial `q'` and a blinding row
  with zero sum over `G_m` (the honest `b_m = −b_0`).
* `treeRoot`, `treePath`, `climb_treePath`, `opens_honest`: the honestly built tree (`MerkleTree::build`, consecutive
  pairs) and its authentication paths verify at every position, with the depth check; `colCommit_opens_honest`, so
  the honest openings of a column-by-column commitment (`Assembly.lean`) open.

(d) **Composition** (`one_sub_le_prob`, `prob_forall_ge`, `complete_of_checks`, `arithComplete_of_checks`): `k` checks
with failure probabilities `εᵢ` pass together with probability at least `1 − Σ εᵢ`, in the form `Complete` and
`ArithComplete` ask for (`1 - εc ≤ prHC …`). `prHC_le_of_forall` (a bound for every coin is a bound on average) and
`fresh_point_prob_le` (under Fiat–Shamir, a challenge read at a point the honest computation has not asked is a fresh
uniform digest: it lands in a set of `m` values with probability `≤ m/|D|`) are the two steps from these per-challenge
bounds to the random-oracle challenges of a receipt.

Every premise is an explicit hypothesis; no `sorry`, axiom or `native_decide`. What stays per profile is listed in
`docs/zkmatrix-poc/ZK60_LEAN_ASSEMBLY_20261106.md` §6.
-/
import ZK60Formal.FSSumcheck
import ZK60Formal.SoundZeroCheck
import ZK60Formal.SoundLogUpBlock
import ZK60Formal.SoundOpening
import ZK60Formal.SoundMProduct
import ZK60Formal.HidingSumcheckJoint
import ZK60Formal.HidingRefusal
import ZK60Formal.Assembly

namespace ZK60.Complete

open scoped ENNReal
open Polynomial Finset
open ZK60.Sound

/-! ## Probability helpers -/

section Prob

/-- **A failure bound gives a success bound**: `Pr[¬E] ≤ ε` implies `1 − ε ≤ Pr[E]`. -/
theorem one_sub_le_prob {Ω : Type} (p : PMF Ω) (E : Ω → Prop) {ε : ℝ≥0∞}
    (h : p.toOuterMeasure {ω | ¬ E ω} ≤ ε) : 1 - ε ≤ p.toOuterMeasure {ω | E ω} := by
  have hsum : p.toOuterMeasure {ω | E ω} + p.toOuterMeasure {ω | ¬ E ω} = 1 := by
    rw [PMF.toOuterMeasure_apply, PMF.toOuterMeasure_apply, ← ENNReal.tsum_add, ← p.tsum_coe]
    refine tsum_congr (fun ω => ?_)
    by_cases hω : E ω
    · simp [Set.indicator, hω]
    · simp [Set.indicator, hω]
  have hne : p.toOuterMeasure {ω | ¬ E ω} ≠ ⊤ :=
    ne_top_of_le_ne_top ENNReal.one_ne_top (Hiding.toOuterMeasure_le_one _ _)
  calc 1 - ε ≤ 1 - p.toOuterMeasure {ω | ¬ E ω} := tsub_le_tsub_left h 1
    _ = p.toOuterMeasure {ω | E ω} := by rw [← hsum, ENNReal.add_sub_cancel_right hne]

/-- **Several checks together (the union bound)**: if check `i` fails with probability at most `ε i`, all pass with
probability at least `1 − Σ ε i`. -/
theorem prob_forall_ge {Ω ι : Type} [Fintype ι] (p : PMF Ω) (E : ι → Ω → Prop) (ε : ι → ℝ≥0∞)
    (h : ∀ i, p.toOuterMeasure {ω | ¬ E i ω} ≤ ε i) :
    1 - ∑ i, ε i ≤ p.toOuterMeasure {ω | ∀ i, E i ω} := by
  refine one_sub_le_prob p _ ?_
  have hsub : {ω | ¬ ∀ i, E i ω} ⊆ ⋃ i, {ω | ¬ E i ω} := by
    intro ω hω
    simp only [Set.mem_ofPred_eq, not_forall] at hω
    simpa using hω
  calc p.toOuterMeasure {ω | ¬ ∀ i, E i ω} ≤ p.toOuterMeasure (⋃ i, {ω | ¬ E i ω}) :=
        MeasureTheory.measure_mono hsub
    _ ≤ ∑ i, p.toOuterMeasure {ω | ¬ E i ω} := MeasureTheory.measure_iUnion_fintype_le _ _
    _ ≤ ∑ i, ε i := Finset.sum_le_sum (fun i _ => h i)

/-- A uniform SECOND coordinate lands in a set of at most `m` values chosen from the first coordinate with
probability at most `m / |S|` (`Hiding.prob_fst_mem_le` with the coordinates swapped). -/
theorem prob_snd_mem_le {β S : Type} [Fintype β] [Nonempty β] [Fintype S] [Nonempty S]
    (T : β → Finset S) (m : ℕ) (hcard : ∀ b, (T b).card ≤ m) :
    (PMF.uniformOfFintype (β × S)).toOuterMeasure {p | p.2 ∈ T p.1} ≤ (m : ℝ≥0∞) / Fintype.card S := by
  have hset : {p : β × S | p.2 ∈ T p.1} = (Equiv.prodComm β S) ⁻¹' {p : S × β | p.1 ∈ T p.2} := rfl
  rw [hset, ← PMF.toOuterMeasure_map_apply, Hiding.map_uniform_equiv]
  exact Hiding.prob_fst_mem_le T m hcard

variable {Q D Coins : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [Fintype Coins]
  [Nonempty Coins]

/-- **A bound at every coin is a bound on average**: if, for every prover coin `c`, an event has probability at most
`ε` over the oracle, it has probability at most `ε` over the oracle and the coin. -/
theorem prHC_le_of_forall (E : (Q → D) → Coins → Prop) {ε : ℝ≥0∞} (h : ∀ c, prH (fun H => E H c) ≤ ε) :
    prHC E ≤ ε := by
  classical
  unfold prHC
  rw [PMF.toOuterMeasure_apply_fintype, Fintype.sum_prod_type_right]
  have hc : ∀ c : Coins, ∑ H : Q → D, {p : (Q → D) × Coins | E p.1 p.2}.indicator
      (PMF.uniformOfFintype ((Q → D) × Coins)) (H, c) = (Fintype.card Coins : ℝ≥0∞)⁻¹ * prH (fun H => E H c) := by
    intro c
    unfold prH
    rw [PMF.toOuterMeasure_apply_fintype, Finset.mul_sum]
    refine Finset.sum_congr rfl (fun H _ => ?_)
    by_cases hE : E H c
    · have h1 : (H, c) ∈ {p : (Q → D) × Coins | E p.1 p.2} := hE
      have h2 : H ∈ {H : Q → D | E H c} := hE
      rw [Set.indicator_of_mem h1, Set.indicator_of_mem h2, PMF.uniformOfFintype_apply,
        PMF.uniformOfFintype_apply, Fintype.card_prod, Nat.cast_mul,
        ENNReal.mul_inv (Or.inr (ENNReal.natCast_ne_top _)) (Or.inl (ENNReal.natCast_ne_top _)), mul_comm]
    · have h1 : (H, c) ∉ {p : (Q → D) × Coins | E p.1 p.2} := hE
      have h2 : H ∉ {H : Q → D | E H c} := hE
      rw [Set.indicator_of_notMem h1, Set.indicator_of_notMem h2, mul_zero]
  simp only [hc]
  calc ∑ c : Coins, (Fintype.card Coins : ℝ≥0∞)⁻¹ * prH (fun H => E H c)
      ≤ ∑ _c : Coins, (Fintype.card Coins : ℝ≥0∞)⁻¹ * ε :=
        Finset.sum_le_sum (fun c _ => by gcongr; exact h c)
    _ = ε := by
        rw [Finset.sum_const, Finset.card_univ, nsmul_eq_mul, ← mul_assoc,
          ENNReal.mul_inv_cancel (by simp) (ENNReal.natCast_ne_top _), one_mul]

/-- **A challenge read at a fresh point is uniform** (the Fiat–Shamir step of completeness). An honest computation
`G` asks the oracle, then names a point `y` and data `b`; the bad set `T b` has at most `m` values. If `y` was not
asked by `G`, the answer `H y` lands in `T b` with probability at most `m/|D|`. (`SoundRO.lean`'s
`prob_fresh_mem_le`; the case `m = 1` is `preimage_out_prob_le`.) -/
theorem fresh_point_prob_le {β : Type} (G : OC Q D (Q × β)) (T : β → Finset D) (m : ℕ)
    (hT : ∀ b, (T b).card ≤ m) :
    prH (fun H => H (G.run H).1 ∈ T (G.run H).2 ∧ (G.run H).1 ∉ OC.queries H G)
      ≤ (m : ℝ≥0∞) / Fintype.card D := by
  classical
  have h := prob_fresh_mem_le (fun y H => (G.run H).1 = y ∧ y ∉ OC.queries H G)
    (fun _ H => T (G.run H).2) m
    (fun y y' H h1 h2 => h1.1.symm.trans h2.1)
    (fun y H d hG => by
      have hl := OC.runLog_eq_of_agree H (Function.update H y d) G (fun y' hy' =>
        Function.update_of_ne (fun hc => hG.2 (by rw [← hc]; exact hy')) d H)
      have hr : G.run (Function.update H y d) = G.run H := by
        rw [← OC.runLog_fst, hl, OC.runLog_fst]
      have hq : OC.queries (Function.update H y d) G = OC.queries H G := by
        simp only [OC.queries, hl]
      exact ⟨⟨by rw [hr]; exact hG.1, by rw [hq]; exact hG.2⟩, by rw [hr]⟩)
    (fun y H _ => hT _)
  refine le_trans (MeasureTheory.measure_mono ?_) h
  rintro H ⟨hH, hq⟩
  exact ⟨(G.run H).1, ⟨rfl, hq⟩, hH⟩

/-- The same with prover coins: for every coin the honest computation is `G c`. -/
theorem fresh_point_prob_le_coins {β : Type} (G : Coins → OC Q D (Q × β)) (T : β → Finset D) (m : ℕ)
    (hT : ∀ b, (T b).card ≤ m) :
    prHC (fun H c => H ((G c).run H).1 ∈ T ((G c).run H).2 ∧ ((G c).run H).1 ∉ OC.queries H (G c))
      ≤ (m : ℝ≥0∞) / Fintype.card D :=
  prHC_le_of_forall _ (fun c => fresh_point_prob_le (G c) T m hT)

end Prob

/-! ## (a) The sumcheck -/

section Sumcheck

variable {F : Type} [Field F]

/-- **The honest round message** of round 0 of the sumcheck of `f`: the true round polynomial's values at the nodes
`X = 0, …, d`, `s(i) = Σ_{x ∈ {0,1}^n} f(i, x)` (`zkp_core::sumcheck::prove`, the code's value form). -/
def honestMsg (d : ℕ) {n : ℕ} (f : (Fin (n + 1) → F) → F) : Fin (d + 1) → F :=
  fun i => cubeSum (fun x => f (Fin.cons (node d i) x))

/-- **The honest prover**: in each round the honest message of the restricted polynomial, and for every challenge
the honest prover of `f` with the first variable fixed to it. -/
def honestProver (d : ℕ) : (n : ℕ) → ((Fin n → F) → F) → Prover F d n
  | 0, _ => PUnit.unit
  | n + 1, f => (honestMsg d f, fun r => honestProver d n (fun x => f (Fin.cons r x)))

/-- **The honest message interpolates the true round polynomial**: the verifier's next claim `interpolate_eval(s, t)`
is the true round sum at `t`, for every `t`. The interpolant through the `d + 1` values is the round polynomial itself
(Lagrange uniqueness: both have degree `≤ d` and agree at `d + 1` distinct nodes). -/
theorem interpEval_honestMsg {n d : ℕ} (hd : d < ringChar F) {f : (Fin (n + 1) → F) → F} (hf : IndDegLE d f)
    (t : F) : interpEval (honestMsg d f) t = cubeSum (fun x => f (Fin.cons t x)) := by
  obtain ⟨p, hp, hpe⟩ := hf.roundSum
  have hs : honestMsg d f = fun i => p.eval (node d i) := by
    funext i
    exact hpe _
  have hrp : roundPoly (fun i : Fin (d + 1) => p.eval (node d i)) = p := by
    unfold roundPoly
    symm
    refine Lagrange.eq_interpolate_of_eval_eq (s := univ) (v := node d) (fun i => p.eval (node d i))
      ((node_injective hd).injOn) ?_ (fun i _ => rfl)
    rw [card_univ, Fintype.card_fin]
    exact (degree_le_of_natDegree_le hp).trans_lt (WithBot.coe_lt_coe.mpr (Nat.lt_succ_self d))
  rw [hs, interpEval_eq, hrp, hpe t]

/-- **The honest message passes the round check**: `s(0) + s(1) = Σ f`. -/
theorem honestMsg_check {n d : ℕ} (hd : d < ringChar F) {f : (Fin (n + 1) → F) → F} (hf : IndDegLE d f) :
    honestMsg d f 0 + honestMsg d f 1 = cubeSum f := by
  rw [msg_zero_add_one hd, ← interpEval_eq, ← interpEval_eq, interpEval_honestMsg hd hf,
    interpEval_honestMsg hd hf, cubeSum_succ]

/-- **Sumcheck completeness.** For a TRUE claim (`C = Σ_{x ∈ {0,1}^n} f(x)`) about `f` of individual degree `≤ d`,
`d < char F`, the honest prover is accepted at EVERY challenge vector, the terminal check included. -/
theorem sumcheck_complete {d : ℕ} (hd : d < ringChar F) :
    ∀ (n : ℕ) (f : (Fin n → F) → F), IndDegLE d f → ∀ r : Fin n → F,
      Accepts n f (cubeSum f) (honestProver d n f) r := by
  intro n
  induction n with
  | zero =>
    intro f _ r
    exact cubeSum_zero f
  | succ n ih =>
    intro f hf r
    simp only [Accepts, honestProver]
    refine ⟨honestMsg_check hd hf, ?_⟩
    rw [interpEval_honestMsg hd hf]
    exact ih _ (hf.cons (r 0)) _

/-- The same as a probability: the honest prover is accepted with probability `1` over uniform challenges. -/
theorem sumcheck_complete_prob [Fintype F] [DecidableEq F] {n d : ℕ} (hd : d < ringChar F)
    {f : (Fin n → F) → F} (hf : IndDegLE d f) :
    (PMF.uniformOfFintype (Fin n → F)).toOuterMeasure {r | Accepts n f (cubeSum f) (honestProver d n f) r} = 1 := by
  rw [PMF.toOuterMeasure_apply_eq_one_iff]
  intro r _
  exact sumcheck_complete hd n f hf r

/-- **On the transcript list** (`FSSumcheck.lean`'s `scAccept`, the verifier the Fiat–Shamir theorems use): the honest
transcript is accepted for every challenge vector. Under Fiat–Shamir the challenges are hash values, so the honest
sumcheck is accepted at EVERY oracle; it contributes nothing to `εc`. -/
theorem sumcheck_complete_list {n d : ℕ} (hd : d < ringChar F) {f : (Fin n → F) → F} (hf : IndDegLE d f)
    (r : Fin n → F) : scAccept (proverTr n (honestProver d n f) r) n f (cubeSum f) :=
  (scAccept_proverTr n f _ _ r).mpr (sumcheck_complete hd n f hf r)

/-- **The masked sumcheck (`--zk`).** The honest prover of `f + c·g` is accepted on the claim `S + c·G` with `S = Σ f`
and `G = Σ g`, for every mask `g` of individual degree `≤ d`, every `c` and every challenge vector. -/
theorem sumcheck_complete_masked {n d : ℕ} (hd : d < ringChar F) {f g : (Fin n → F) → F} (hf : IndDegLE d f)
    (hg : IndDegLE d g) (c : F) (r : Fin n → F) :
    Accepts n (fun x => f x + c * g x) (cubeSum f + c * cubeSum g) (honestProver d n (fun x => f x + c * g x)) r := by
  rw [← cubeSum_add_smul]
  exact sumcheck_complete hd n _ (hf.add_smul hg c) r

/-- **The last-round extension.** If `fe` restricts to `f` at `y = 0` and vanishes at `y = 1` on the cube (the code's
extension, `extension_halves`), the honest prover of `fe` is accepted on the claim `Σ f`, at every challenge vector. -/
theorem sumcheck_complete_extended {n d : ℕ} (hd : d < ringChar F) {fe : (Fin (n + 1) → F) → F}
    (hfe : IndDegLE d fe) (f : (Fin n → F) → F)
    (h0 : ∀ b : Fin n → Bool, fe (Fin.snoc (fun i => bit (b i)) 0) = f (fun i => bit (b i)))
    (h1 : ∀ b : Fin n → Bool, fe (Fin.snoc (fun i => bit (b i)) 1) = 0) (r : Fin (n + 1) → F) :
    Accepts (n + 1) fe (cubeSum f) (honestProver d (n + 1) fe) r := by
  have : cubeSum fe = cubeSum f := by
    rw [cubeSum_snoc]
    simp only [cubeSum, h0, h1, sum_const_zero, add_zero]
  rw [← this]
  exact sumcheck_complete hd _ fe hfe r

/-- **The zero-check.** If `R` (individual degree `≤ d`) vanishes on the whole cube, the claim
`Σ_x eq(τ, x)·R(x) = 0` is TRUE for every `τ`, so the honest prover of `eq(τ, ·)·R` (round degree `d + 1`) is accepted
at every `(τ, ρ)`. -/
theorem zerocheck_complete {n d : ℕ} (hd : d + 1 < ringChar F) {R : (Fin n → F) → F} (hR : IndDegLE d R)
    (hz : ∀ b : Fin n → Bool, R (fun i => bit (b i)) = 0) (τ ρ : Fin n → F) :
    Accepts n (fun x => eqPoly τ x * R x) 0 (honestProver (d + 1) n (fun x => eqPoly τ x * R x)) ρ := by
  have h0 : cubeSum (fun x => eqPoly τ x * R x) = 0 := by
    rw [cubeSum_eq_mul]
    simp [mleAt, hz]
  have h := sumcheck_complete hd n _ (hR.eq_mul τ) ρ
  rwa [h0] at h

/-- **Batching keeps a zero vector zero**: every batching coefficient vector `μ` passes when all relation values are
zero. -/
theorem batch_complete {K : Type} [Fintype K] (v : K → F) (hv : ∀ k, v k = 0) (μ : K → F) :
    ∑ k, μ k * v k = 0 := by
  simp [hv]

end Sumcheck

/-! ## (a′) The CFS mask in the code's coefficient form -/

section Cfs

open ZK60.Hiding

variable {K : Type} [Field K]

/-- **The masked rounds' chain defects.** The rounds the code sends, `s_j + c·g_j` (`g_j = CfsMask::round(j, prev)`),
have the defects `(S + c·G, the unmasked gaps, F + c·g(ρ))`, where `(S, gaps, F)` are the unmasked rounds' defects:
the mask is a consistent sumcheck of `g` (`cfsMask_roundSum_zero`, `cfsMask_roundSum_succ`, `cfsMask_terminal`). -/
theorem cfs_masked_chainDefect {n d : ℕ} (hd : 1 ≤ d) (h2 : (2 : K) ≠ 0) (s : Fin (n + 1) → Fin (d + 1) → K)
    (c : K) (r : Fin (n + 1) → K) (a : CfsCoeffs K n d) :
    chainDefect (fun j e => s j e + c * cfsMaskRound a r j e) r
      = ((chainDefect s r).1 + c * cfsTotal a, (chainDefect s r).2.1,
          (chainDefect s r).2.2 + c * cfsEval a r) := by
  have hadd : ∀ j x, peval (fun e => s j e + c * cfsMaskRound a r j e) x
      = peval (s j) x + c * peval (cfsMaskRound a r j) x := by
    intro j x
    have : (fun e => s j e + c * cfsMaskRound a r j e) = s j + (fun e => c * cfsMaskRound a r j e) := rfl
    rw [this, peval_add, peval_smul]
  have hrs : ∀ j, roundSum (fun e => s j e + c * cfsMaskRound a r j e)
      = roundSum (s j) + c * roundSum (cfsMaskRound a r j) := by
    intro j
    simp only [roundSum, hadd]
    ring
  simp only [chainDefect, hrs, hadd]
  refine Prod.ext ?_ (Prod.ext ?_ ?_)
  · simp only
    rw [cfsMask_roundSum_zero hd h2]
  · funext j
    simp only
    rw [cfsMask_roundSum_succ hd h2]
    ring
  · simp only
    rw [cfsMask_terminal hd]

/-- **CFS completeness.** If the unmasked rounds are an honest sumcheck chain of the sum `S` with terminal value `F`
(defects `(S, 0, F)`), the rounds the code sends are an honest chain of `S + c·G` with terminal `F + c·g(ρ)`, for
every mask, every `c` and every challenge vector: the verifier's round checks and its terminal check (`g(ρ)` is the
value `M` opens) all pass. -/
theorem cfs_masked_honest {n d : ℕ} (hd : 1 ≤ d) (h2 : (2 : K) ≠ 0) (s : Fin (n + 1) → Fin (d + 1) → K)
    (c : K) (r : Fin (n + 1) → K) (a : CfsCoeffs K n d) {S Fv : K} (hs : chainDefect s r = (S, 0, Fv)) :
    chainDefect (fun j e => s j e + c * cfsMaskRound a r j e) r = (S + c * cfsTotal a, 0, Fv + c * cfsEval a r) := by
  rw [cfs_masked_chainDefect hd h2, hs]

/-- **The CFS refusal**: the prover discards an attempt whose mask challenge is `c = 0` (`run_slot`, class (C) of
`HidingRefusal.lean`); that has probability exactly `1/|K|`. -/
theorem cfs_refusal_prob [Fintype K] [DecidableEq K] :
    (PMF.uniformOfFintype K).toOuterMeasure {c | c ∈ ({0} : Finset K)} = 1 / Fintype.card K := by
  rw [Hiding.prob_mem_finset, Finset.card_singleton, Nat.cast_one]

end Cfs

/-! ## (b) LogUp -/

section LogUp

/-- **The honest multiplicities**: natural numbers `μ` whose mass per distinct table tuple is the number of lookups of
that tuple (padded copies of an entry may split it in any way). -/
def TupleMass {L κ V : Type} [Fintype L] [Fintype κ] [DecidableEq V] (A : L → V) (T : κ → V) (μ : κ → ℕ) : Prop :=
  ∀ u, ∑ j ∈ univ.filter (fun j => T j = u), μ j = (univ.filter (fun l => A l = u)).card

/-- **Honest multiplicities exist** when every looked-up tuple is a table tuple: put each tuple's count on one of its
positions (`Function.invFun`) and zero on its padded copies. -/
theorem exists_tupleMass {L κ V : Type} [Fintype L] [Fintype κ] [DecidableEq V] (A : L → V) (T : κ → V)
    (hin : ∀ l, ∃ j, T j = A l) : ∃ μ : κ → ℕ, TupleMass A T μ := by
  classical
  rcases isEmpty_or_nonempty κ with hκ | hκ
  · have : IsEmpty L := ⟨fun l => (hin l).elim (fun j _ => hκ.elim j)⟩
    exact ⟨fun _ => 0, fun u => by simp⟩
  · let r : V → κ := Function.invFun T
    refine ⟨fun j => if r (T j) = j then (univ.filter (fun l => A l = T j)).card else 0, fun u => ?_⟩
    by_cases hu : ∃ j, T j = u
    · have hru : T (r u) = u := Function.invFun_eq hu
      rw [sum_congr rfl (g := fun j => if r u = j then (univ.filter (fun l => A l = u)).card else 0)
        (fun j hj => by dsimp only; rw [(mem_filter.mp hj).2]), sum_ite_eq,
        ite_eq_left (show r u ∈ univ.filter (fun j => T j = u) from mem_filter.mpr ⟨mem_univ _, hru⟩)]
    · have h1 : univ.filter (fun j => T j = u) = ∅ := filter_false_of_mem (fun j _ hj => hu ⟨j, hj⟩)
      have h2 : univ.filter (fun l => A l = u) = ∅ := filter_false_of_mem (fun l _ hl => by
        obtain ⟨j, hj⟩ := hin l
        exact hu ⟨j, hj.trans hl⟩)
      rw [h1, h2]
      simp

/-- **Regrouping by the honest multiplicities**: for EVERY function `f` of a tuple, `Σ_l f(A_l) = Σ_j μ_j·f(T_j)`.
(Both sides are `Σ_u (number of lookups of u)·f(u)` over the distinct table tuples.) -/
theorem regroup {L κ V R : Type} [Fintype L] [Fintype κ] [DecidableEq V] [Semiring R] {A : L → V} {T : κ → V}
    {μ : κ → ℕ} (hin : ∀ l, ∃ j, T j = A l) (hμ : TupleMass A T μ) (f : V → R) :
    ∑ l, f (A l) = ∑ j, (μ j : R) * f (T j) := by
  classical
  have hA : ∀ l ∈ (univ : Finset L), A l ∈ univ.image T := by
    intro l _
    obtain ⟨j, hj⟩ := hin l
    exact mem_image.mpr ⟨j, mem_univ _, hj⟩
  have hT : ∀ j ∈ (univ : Finset κ), T j ∈ univ.image T := fun j _ => mem_image_of_mem T (mem_univ j)
  rw [← sum_fiberwise_of_maps_to' hA f, ← sum_fiberwise_of_maps_to hT (fun j => (μ j : R) * f (T j))]
  refine sum_congr rfl (fun u _ => ?_)
  rw [sum_const, nsmul_eq_mul,
    sum_congr rfl (g := fun j => (μ j : R) * f u) (fun j hj => by rw [(mem_filter.mp hj).2]), ← sum_mul,
    ← Nat.cast_sum, hμ u]

variable {F : Type} [Field F] [DecidableEq F]

/-- **The honest LogUp identity holds at every fold and every point.** With honest multiplicities (committed in `A`
BEFORE `β, γ, α`), `Σ_l 1/(α − fold(A_l)) = Σ_j μ_j/(α − fold(T_j))` for EVERY `β, γ, α` (with the field's `0⁻¹ = 0`;
off the poles this is the identity the helpers sum to). -/
theorem logup_identity_honest {L κ : Type} [Fintype L] [Fintype κ] {A : L → Tup F} {T : κ → Tup F} {μ : κ → ℕ}
    (hin : ∀ l, ∃ j, T j = A l) (hμ : TupleMass A T μ) (β γ α : F) :
    logupLhsAt (fun l => Sound.fold β γ (A l)) α = logupRhsAt (fun j => Sound.fold β γ (T j)) (fun j => (μ j : F)) α :=
  regroup hin hμ (fun u => (α - Sound.fold β γ u)⁻¹)

/-- **The same as rational functions** (`SoundLogUp.lean`'s identity): `Σ_i 1/(X − a_i) = Σ_j μ_j/(X − t_j)` when every
looked-up value is a table value and `μ` are honest multiplicities. -/
theorem logup_ratfunc_honest {ι κ : Type} [Fintype ι] [Fintype κ] {a : ι → F} {t : κ → F} {μ : κ → ℕ}
    (hin : ∀ i, ∃ j, t j = a i) (hμ : TupleMass a t μ) :
    logupLhs a = logupRhs t (fun j => (μ j : F)) := by
  simp only [logupLhs, logupRhs, map_natCast]
  exact regroup hin hμ (fun u => (RatFunc.X - RatFunc.C u)⁻¹)

/-- **The honest helpers** at the challenge `α`: `1/(α − a)` per single, `1/(α − a) + 1/(α − b)` per pair,
`m/(α − t)` per table position (`argument::helper_sum`, the `SC_TAB` helper). -/
def honestHelpers {ι π κ : Type} (look : ι ⊕ (π ⊕ π) → F) (t m : κ → F) (α : F) : Helpers ι π κ F where
  single i := (α - look (.inl i))⁻¹
  pair k := (α - pairFst look k)⁻¹ + (α - pairSnd look k)⁻¹
  table j := m j * (α - t j)⁻¹

/-- **Off the poles the honest helpers pass every relation**, and the sum claim is the identity at `α`. -/
theorem helperRel_honest {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ] {look : ι ⊕ (π ⊕ π) → F}
    {t m : κ → F} {α : F} (hα : α ∉ poles look t) (hid : logupLhsAt look α = logupRhsAt t m α) :
    HelperRel look t m α (honestHelpers look t m α) := by
  have hne : ∀ v ∈ poles look t, α - v ≠ 0 := fun v hv => sub_ne_zero.mpr (fun h => hα (h ▸ hv))
  unfold HelperRel
  refine ⟨fun i => ?_, fun k => ?_, fun j => ?_, ?_⟩
  · exact inv_mul_cancel₀ (hne _ (mem_poles_left look t _))
  · have h1 : α - pairFst look k ≠ 0 := hne _ (mem_poles_left look t (.inr (.inl k)))
    have h2 : α - pairSnd look k ≠ 0 := hne _ (mem_poles_left look t (.inr (.inr k)))
    show ((α - pairFst look k)⁻¹ + (α - pairSnd look k)⁻¹) * ((α - pairFst look k) * (α - pairSnd look k))
      = (α - pairFst look k) + (α - pairSnd look k)
    rw [add_mul, inv_mul_cancel_left₀ h1, mul_comm (α - pairFst look k) (α - pairSnd look k),
      inv_mul_cancel_left₀ h2, add_comm]
  · show m j * (α - t j)⁻¹ * (α - t j) = m j
    rw [mul_assoc, inv_mul_cancel₀ (hne _ (mem_poles_right look t j)), mul_one]
  · show ∑ i, (α - look (.inl i))⁻¹ + ∑ k, ((α - pairFst look k)⁻¹ + (α - pairSnd look k)⁻¹)
        - ∑ j, m j * (α - t j)⁻¹ = 0
    simp only [logupLhsAt, logupRhsAt, Fintype.sum_sum_type] at hid
    rw [sum_add_distrib]
    unfold pairFst pairSnd
    linear_combination hid

/-- **The honest prover's refusal** (`zero LogUp denominator`): some denominator it inverts vanishes. It inverts every
looked-up value's `α − a` and every table entry's `α − t` (S28-F1). -/
def logupRefuses {L κ : Type} [Fintype L] [Fintype κ] (look : L → F) (t : κ → F) (α : F) : Prop :=
  (∃ w ∈ univ.image look, α - w = 0) ∨ ∃ v ∈ univ.image t, α - v = 0

/-- With every lookup in the table, the honest prover refuses exactly when `α` is a table value
(`HidingRefusal.lean`'s `logup_refusal_iff_table`). -/
theorem logupRefuses_iff {L κ : Type} [Fintype L] [Fintype κ] {look : L → F} {t : κ → F}
    (hin : ∀ l, ∃ j, t j = look l) (α : F) : logupRefuses look t α ↔ α ∈ univ.image t := by
  refine Hiding.logup_refusal_iff_table α _ _ (fun w hw => ?_)
  obtain ⟨l, -, rfl⟩ := mem_image.mp hw
  obtain ⟨j, hj⟩ := hin l
  exact mem_image.mpr ⟨j, mem_univ _, hj⟩

/-- An attempt the honest prover does not refuse has `α` off the poles. -/
theorem not_mem_poles_of_not_refuses {L κ : Type} [Fintype L] [Fintype κ] {look : L → F} {t : κ → F} {α : F}
    (h : ¬ logupRefuses look t α) : α ∉ poles look t := by
  intro hp
  apply h
  rcases mem_union.mp hp with hp | hp
  · exact Or.inl ⟨α, hp, sub_self α⟩
  · exact Or.inr ⟨α, hp, sub_self α⟩

/-- **LogUp completeness at fixed challenges**: every looked-up tuple in the table, honest multiplicities, and an
attempt that is not refused: the honest helpers pass every relation and the sum claim, at every `(β, γ, α)`. -/
theorem logup_block_complete {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ] {A : ι ⊕ (π ⊕ π) → Tup F}
    {T : κ → Tup F} {μ : κ → ℕ} (hin : ∀ l, ∃ j, T j = A l) (hμ : TupleMass A T μ) (β γ α : F)
    (hα : ¬ logupRefuses (fun l => Sound.fold β γ (A l)) (fun j => Sound.fold β γ (T j)) α) :
    HelperRel (fun l => Sound.fold β γ (A l)) (fun j => Sound.fold β γ (T j)) (fun j => (μ j : F)) α
      (honestHelpers (fun l => Sound.fold β γ (A l)) (fun j => Sound.fold β γ (T j)) (fun j => (μ j : F)) α) :=
  helperRel_honest (not_mem_poles_of_not_refuses hα) (logup_identity_honest hin hμ β γ α)

/-- **The refusal bound, generic in the earlier challenges `c`**: if every lookup is in the table at every `c`, the
table has at most `M` distinct values at every `c`, and every attempt that is not refused passes (`Good`), then over
uniform `(c, α)` the attempt is served and passes except with probability at most `M/|F|`. -/
theorem logup_complete_prob_gen [Fintype F] {C L κ : Type} [Fintype C] [Nonempty C] [Fintype L] [Fintype κ]
    (look : C → L → F) (t : C → κ → F) (M : ℕ) (hin : ∀ c l, ∃ j, t c j = look c l)
    (hM : ∀ c, (univ.image (t c)).card ≤ M) (Good : C → F → Prop)
    (hgood : ∀ c α, ¬ logupRefuses (look c) (t c) α → Good c α) :
    1 - (M : ℝ≥0∞) / Fintype.card F
      ≤ (PMF.uniformOfFintype (C × F)).toOuterMeasure {ω | ¬ logupRefuses (look ω.1) (t ω.1) ω.2 ∧ Good ω.1 ω.2} := by
  classical
  refine one_sub_le_prob _ _ ?_
  have hsub : {ω : C × F | ¬ (¬ logupRefuses (look ω.1) (t ω.1) ω.2 ∧ Good ω.1 ω.2)}
      ⊆ {ω | ω.2 ∈ univ.image (t ω.1)} := by
    intro ω hω
    by_cases hr : logupRefuses (look ω.1) (t ω.1) ω.2
    · exact (logupRefuses_iff (hin ω.1) ω.2).mp hr
    · exact absurd ⟨hr, hgood ω.1 ω.2 hr⟩ hω
  exact (MeasureTheory.measure_mono hsub).trans (prob_snd_mem_le (fun c => univ.image (t c)) M hM)

/-- **LogUp completeness, the probability.** Over uniform independent `β, γ, α`, the honest LogUp is served (not
refused) and passes every relation and the sum claim, except with probability at most `M/|F|`, `M` the number of
DISTINCT table tuples (the refusal is `α` among the at most `M` folded table values). With `M ≤ 2^16` table tuples and
`|Fp2| ≈ 2^128` that is `≈ 2^-112` per LogUp domain. -/
theorem logup_block_complete_prob [Fintype F] {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    {A : ι ⊕ (π ⊕ π) → Tup F} {T : κ → Tup F} {μ : κ → ℕ} (hin : ∀ l, ∃ j, T j = A l) (hμ : TupleMass A T μ) :
    1 - ((univ.image T).card : ℝ≥0∞) / Fintype.card F
      ≤ (PMF.uniformOfFintype ((F × F) × F)).toOuterMeasure
          {ω | ¬ logupRefuses (fun l => Sound.fold ω.1.1 ω.1.2 (A l)) (fun j => Sound.fold ω.1.1 ω.1.2 (T j)) ω.2
            ∧ HelperRel (fun l => Sound.fold ω.1.1 ω.1.2 (A l)) (fun j => Sound.fold ω.1.1 ω.1.2 (T j)) (fun j => (μ j : F)) ω.2
              (honestHelpers (fun l => Sound.fold ω.1.1 ω.1.2 (A l)) (fun j => Sound.fold ω.1.1 ω.1.2 (T j))
                (fun j => (μ j : F)) ω.2)} := by
  refine logup_complete_prob_gen (C := F × F) (fun p l => Sound.fold p.1 p.2 (A l))
    (fun p j => Sound.fold p.1 p.2 (T j)) (univ.image T).card (fun p l => ?_) (fun p => ?_)
    (fun p α => HelperRel (fun l => Sound.fold p.1 p.2 (A l)) (fun j => Sound.fold p.1 p.2 (T j))
      (fun j => (μ j : F)) α (honestHelpers (fun l => Sound.fold p.1 p.2 (A l)) (fun j => Sound.fold p.1 p.2 (T j))
        (fun j => (μ j : F)) α))
    (fun p α hr => logup_block_complete hin hμ p.1 p.2 α hr)
  · obtain ⟨j, hj⟩ := hin l
    exact ⟨j, by rw [hj]⟩
  · rw [show univ.image (fun j => Sound.fold p.1 p.2 (T j)) = (univ.image T).image (Sound.fold p.1 p.2) by
      rw [image_image]; rfl]
    exact card_image_le

end LogUp

/-! ## (c) The opening -/

section Opening

variable {E ι κ : Type} [Field E] [Fintype κ]

/-- **Opening completeness.** If the committed rows are codewords and the claim is true of `Σ a_i·U_i`, the honest
prover's group vector `Σ a_i·U_i` and proximity vector `Σ ρ_i·U_i` are codewords (the verifier re-encodes them) and pass
the claim check and both column checks at EVERY `ρ` and every column draw `J`. -/
theorem opening_complete {D : Submodule E (ι → E)} (U : κ → ι → E) (hU : ∀ i, U i ∈ D) (a : κ → E)
    (ok : (ι → E) → Prop) (hok : ok (comb U a)) {Q : ℕ} (ρ : κ → E) (J : Fin Q → ι) :
    OpeningAccepts U a ok (fun _ => comb U a) (fun ρ => comb U ρ) ρ J ∧ comb U a ∈ D ∧ comb U ρ ∈ D :=
  ⟨⟨hok, fun _ => rfl, fun _ => rfl⟩, D.sum_mem fun i _ => D.smul_mem _ (hU i),
    D.sum_mem fun i _ => D.smul_mem _ (hU i)⟩

/-- The same as a probability: `1` over uniform `ρ` and uniform column indices. -/
theorem opening_complete_prob [Fintype E] [DecidableEq E] [Fintype ι] [Nonempty ι] [DecidableEq ι] [DecidableEq κ]
    (U : κ → ι → E) (a : κ → E) (ok : (ι → E) → Prop) (hok : ok (comb U a)) (Q : ℕ) :
    (PMF.uniformOfFintype ((κ → E) × (Fin Q → ι))).toOuterMeasure
      {ω | OpeningAccepts U a ok (fun _ => comb U a) (fun ρ => comb U ρ) ω.1 ω.2} = 1 := by
  rw [PMF.toOuterMeasure_apply_eq_one_iff]
  intro ω _
  exact ⟨hok, fun _ => rfl, fun _ => rfl⟩

end Opening

section MOpening

variable {E ι σ κ : Type} [Field E] [Fintype σ]

/-- **`M`'s product test, honest** (`mask_verify_tagged`, the code's `o = 0`). With honest a-rows (degree `< m`), a
blinding row of degree `< 2m` whose sum over `G_m` is zero (the honest prover's `b_m = −b_0`, `mOff_eq`), the honest
values `value_i = tru_i` and `q'` the product polynomial, the sum check and every column check pass at EVERY `θ` and
every column sample. (`mproduct_offset_accepts` with offset `0`.) -/
theorem mproduct_complete {k m Q : ℕ} (hk : 0 < k) (hm : 0 < m) {ω : E} (hω : IsPrimitiveRoot ω m) (η : ι → E)
    (wt : Fin k → σ → Fin m → E) (Ah : σ → E[X]) (Bh : E[X]) (hAh : ∀ s, (Ah s).natDegree < m)
    (hB : Bh.natDegree < 2 * m) (hoff : mOff m ω Bh = 0) (θ : E) (J : Fin Q → ι) :
    MProdAccept η ω 0 wt (fun i => mTrue ω wt Ah i) (fun s j => (Ah s).eval (η j)) (fun j => Bh.eval (η j))
      (mProduct ω 0 wt Ah Bh) θ J := by
  have h := mproduct_offset_accepts hk hm hω η wt Ah Bh hAh hB θ J
  simpa [hoff] using h

/-- **`M`'s whole opening, honest** (`mask_verify_tagged` without the Merkle layer): committed rows that ARE the
evaluations of the decoded polynomials `Rh` (and `uh` for the proximity mask), the honest values, `q'` the product
polynomial and the honest proximity polynomial `uh + Σ_κ r_κ·Rh_κ`: the product test and the proximity column checks
pass at EVERY `θ`, `r` and column sample. -/
theorem mopening_complete [Fintype κ] {k m Q : ℕ} (hk : 0 < k) (hm : 0 < m) {ω : E} (hω : IsPrimitiveRoot ω m)
    (η : ι → E) (wt : Fin k → σ → Fin m → E) (Rh : κ → E[X]) (uh : E[X]) (La : σ → κ → E) (Lb : κ → E)
    (hA : ∀ s, (mDecA La Rh s).natDegree < m) (hB : (mDecB Lb Rh).natDegree < 2 * m)
    (hoff : mOff m ω (mDecB Lb Rh) = 0) (θ : E) (r : κ → E) (J : Fin Q → ι) :
    MAccept η ω 0 wt (fun i => mTrue ω wt (mDecA La Rh) i) (fun i j => (Rh i).eval (η j)) (fun j => uh.eval (η j))
      La Lb (mProduct ω 0 wt (mDecA La Rh) (mDecB Lb Rh)) (fun _ r' => uh + ∑ i, C (r' i) * Rh i) θ r J := by
  have hcomb : ∀ (L : κ → E) (j : ι),
      comb (fun i j => (Rh i).eval (η j)) L j = (∑ i, C (L i) * Rh i).eval (η j) := by
    intro L j
    rw [comb_apply, eval_finsetSum]
    simp only [eval_mul, eval_C]
  refine ⟨?_, fun t => ?_⟩
  · have h := mproduct_complete hk hm hω η wt (mDecA La Rh) (mDecB Lb Rh) hA hB hoff θ J
    have ha : (fun s => comb (fun i j => (Rh i).eval (η j)) (La s)) = fun s j => (mDecA La Rh s).eval (η j) := by
      funext s j
      exact hcomb _ _
    have hb : comb (fun i j => (Rh i).eval (η j)) Lb = fun j => (mDecB Lb Rh).eval (η j) := by
      funext j
      exact hcomb _ _
    rw [ha, hb]
    exact h
  · rw [hcomb, eval_add]

end MOpening

section Merkle

variable {Q D S Col : Type} (M : MerkleEnc Q D S Col)

/-- **The honest tree's root** over the digests `v 0, v 1, …, v (2^h − 1)`: hash consecutive pairs
(`MerkleTree::build`: `hash_pair(&pair[0], &pair[1])`) level by level. -/
def treeRoot (H : Q → D) : ℕ → (ℕ → D) → D
  | 0, v => v 0
  | h + 1, v => treeRoot H h (fun i => H (M.nodeQ (v (2 * i)) (v (2 * i + 1))))

/-- **The honest authentication path** of position `j` (`MerkleTree::path`): the sibling on every level, bottom up. -/
def treePath (H : Q → D) : ℕ → (ℕ → D) → ℕ → List D
  | 0, _, _ => []
  | h + 1, v, j => (if j % 2 = 0 then v (j + 1) else v (j - 1))
      :: treePath H h (fun i => H (M.nodeQ (v (2 * i)) (v (2 * i + 1)))) (j / 2)

/-- The honest path has exactly `h` entries (the verifier's depth check, D19 T-4). -/
theorem treePath_length (H : Q → D) : ∀ (h : ℕ) (v : ℕ → D) (j : ℕ), (treePath M H h v j).length = h
  | 0, _, _ => rfl
  | h + 1, v, j => by
    simp only [treePath, List.length_cons]
    rw [treePath_length H h]

/-- **The honest path climbs to the honest root** from every position `j < 2^h`. -/
theorem climb_treePath (H : Q → D) :
    ∀ (h : ℕ) (v : ℕ → D) (j : ℕ), j < 2 ^ h → M.climb H j (v j) (treePath M H h v j) = treeRoot M H h v
  | 0, v, j, hj => by
    have : j = 0 := by simpa using hj
    subst this
    rfl
  | h + 1, v, j, hj => by
    have hstep : H (M.stepQ j (v j) (if j % 2 = 0 then v (j + 1) else v (j - 1)))
        = H (M.nodeQ (v (2 * (j / 2))) (v (2 * (j / 2) + 1))) := by
      unfold MerkleEnc.stepQ
      by_cases hpar : j % 2 = 0
      · have e1 : 2 * (j / 2) = j := by omega
        rw [ite_eq_left hpar, ite_eq_left hpar, e1]
      · have e1 : 2 * (j / 2) = j - 1 := by omega
        have e2 : 2 * (j / 2) + 1 = j := by omega
        rw [ite_eq_right hpar, ite_eq_right hpar, e2, e1]
    have hj' : j / 2 < 2 ^ h := by
      rw [pow_succ] at hj
      omega
    simp only [treePath, treeRoot, MerkleEnc.climb]
    rw [hstep]
    exact climb_treePath H h (fun i => H (M.nodeQ (v (2 * i)) (v (2 * i + 1)))) (j / 2) hj'

/-- **An honest opening verifies** (`pcs::verify_zk_tagged`'s Merkle part): if the leaf at `j` is the salted leaf of
the column and salt, the honest path opens it against the honest root, depth check included. -/
theorem opens_honest (H : Q → D) (h : ℕ) (v : ℕ → D) (j : ℕ) (hj : j < 2 ^ h) (c : Col) (s : S)
    (hv : v j = M.leafDigest H c s) : M.Opens H h (treeRoot M H h v) j ⟨c, s, treePath M H h v j⟩ :=
  ⟨treePath_length M H h v j, by
    show M.climb H j (M.leafDigest H c s) (treePath M H h v j) = treeRoot M H h v
    rw [← hv]
    exact climb_treePath M H h v j hj⟩

end Merkle

section ColCommitHonest

open ZK60.Assembly

variable {Q D S Col St V Salt : Type}

/-- The honest leaves of a column-by-column commitment: the salted leaf of each column, and a filler digest beyond
the `N` positions (none when `N = 2^h`, the code's case). -/
def colLeaves (C : ColCommit Q D S Col St V Salt) (H : Q → D) (v : V) (r : Salt) (pad : D) : ℕ → D :=
  fun i => if hi : i < C.N then C.enc.leafDigest H (C.col v r ⟨i, hi⟩) (C.salt r ⟨i, hi⟩) else pad

/-- **The honest openings of a column-by-column commitment open** (`Assembly.lean`'s `ColCommit.Opens`): when the
statement's root is the honest tree's root and every path in the opening data is the honest path. This is the
`∃ r, opensIn …` and `∃ r, opensOut …` part of `Complete` for such a commitment. -/
theorem colCommit_opens_honest (C : ColCommit Q D S Col St V Salt) (H : Q → D) (s : St) (v : V) (r : Salt)
    (pad : D) (hN : C.N ≤ 2 ^ C.h) (hroot : C.root s = treeRoot C.enc H C.h (colLeaves C H v r pad))
    (hpath : ∀ j : Fin C.N, C.path r j = treePath C.enc H C.h (colLeaves C H v r pad) j) : C.Opens H s v r := by
  intro j
  rw [hroot, hpath j]
  refine opens_honest C.enc H C.h (colLeaves C H v r pad) j (lt_of_lt_of_le j.isLt hN) _ _ ?_
  simp [colLeaves]

end ColCommitHonest

/-! ## (d) Composition into `Complete` -/

section Compose

variable {Q D Coins : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [Fintype Coins]
  [Nonempty Coins]

/-- **Completeness from `k` sub-protocol checks.** If, for every admissible input, the conjunction of the checks
`E i` implies the completeness event (acceptance, the public output part, both openings), and check `i` fails with
probability at most `ε i` over the oracle and the prover's coins, then `Complete` holds with `εc = Σ ε i`. Per
profile, the checks are the sub-protocols of the receipt (each sumcheck, each LogUp with its refusal, each opening, `M`)
and the `ε i` their refusal terms (`logup_block_complete_prob`, `cfs_refusal_prob`, read through
`fresh_point_prob_le` under Fiat–Shamir). -/
theorem complete_of_checks {M : IntModel} (P : Protocol Q D Coins M) {ι : Type} [Fintype ι]
    (E : ι → M.Weights → M.Input → (Q → D) → Coins → Prop) (ε : ι → ℝ≥0∞)
    (himp : ∀ W x, M.admissible x → ∀ H c, (∀ i, E i W x H c) →
      P.verify H W (P.prove H W x c).1 (P.prove H W x c).2 = true
      ∧ P.ypub (P.prove H W x c).1 = M.publicPart (M.forward W x)
      ∧ (∃ r, P.opensIn H (P.prove H W x c).1 x r)
      ∧ (∃ r, P.opensOut H (P.prove H W x c).1 (M.hiddenPart (M.forward W x)) r))
    (hε : ∀ W x, M.admissible x → ∀ i, prHC (fun H c => ¬ E i W x H c) ≤ ε i) :
    Complete M P (∑ i, ε i) := by
  intro W x hx
  refine le_trans (prob_forall_ge _ (fun i (p : (Q → D) × Coins) => E i W x p.1 p.2) ε
    (fun i => hε W x hx i)) (MeasureTheory.measure_mono ?_)
  intro p hp
  exact himp W x hx p.1 p.2 hp

/-- The same at the constraint system's level (`Assembly.lean`'s `ArithComplete`), for every satisfiable input. -/
theorem arithComplete_of_checks {M : IntModel} (A : Arith M) (P : Protocol Q D Coins M) {ι : Type} [Fintype ι]
    (E : ι → M.Weights → M.Input → M.Output → A.Witness → (Q → D) → Coins → Prop) (ε : ι → ℝ≥0∞)
    (himp : ∀ W x y w, A.Satisfies W x y w → ∀ H c, (∀ i, E i W x y w H c) →
      P.verify H W (P.prove H W x c).1 (P.prove H W x c).2 = true
      ∧ P.ypub (P.prove H W x c).1 = M.publicPart y
      ∧ (∃ r, P.opensIn H (P.prove H W x c).1 x r)
      ∧ (∃ r, P.opensOut H (P.prove H W x c).1 (M.hiddenPart y) r))
    (hε : ∀ W x y w, A.Satisfies W x y w → ∀ i, prHC (fun H c => ¬ E i W x y w H c) ≤ ε i) :
    Assembly.ArithComplete M A P (∑ i, ε i) := by
  intro W x y w hw
  refine le_trans (prob_forall_ge _ (fun i (p : (Q → D) × Coins) => E i W x y w p.1 p.2) ε
    (fun i => hε W x y w hw i)) (MeasureTheory.measure_mono ?_)
  intro p hp
  exact himp W x y w hw p.1 p.2 hp

end Compose

end ZK60.Complete
