/-
D63, step L4 (zero knowledge): the refusal bit.

The private-block prover (`hashline/src/private_block.rs` `prove` → `protocol::prove_inner` → `prove_core`,
`argument::run_slot`, `protocol::check_opening`; the run prover `run.rs` `prove_run`) returns `Err(message)` and
publishes nothing when it refuses. Every refusal site in the code falls in one of five classes.

(A) PUBLIC: a function of the shape, layout, profile and public statement only. Examples: "witness shape",
    rulings CS-1/CS-4/CS-6/CS-7/CS-8 (shape, layout, block digests, run profile), "slot … differs from the declared
    schedule", "slot … table shape", `audit_claims`' structural failures ("a claim does not carry exactly its own
    reserved pair", "proximity pair placement", …), the opening-group count, the endpoint geometry and claim shape,
    the NTT ceiling, the trained door's `cap` refusal, the run statement's scale and context checks, the wire and file
    checks. A simulator reproduces them exactly from the public data.
(B) INPUT ADMISSIBILITY: a deterministic function of the hidden input, decided before any randomness is drawn.
    `witness::build` refuses an inadmissible input with "fixed oracle range refusal: <site>" (twelve reachable sites:
    Q, K, V, QR, KR, score, residual 1, FFN gate, up, product, down, residual 2, `refusals.rs`), and `prove_core`'s
    ruling CS-3 refuses a lookup miss naming the table FAMILY that missed (byte, exp, activation; the dictionary
    separately). `private_block::prove` returns that string to its caller.
(C) CHALLENGE-ONLY: a function of the verifier's challenges alone. "zero CFS mask challenge" (`c = 0`, per slot),
    "degenerate terminal mask challenge" (an extension challenge `e ∈ {0, 1}`), "zero batching challenge"
    (`argument.rs` `nonzero`), "zero terminal mask coefficient" (`audit_claims`: `cm = e·∏(1 − e')`, nonzero once the
    previous refusal passed), "zero group member coefficient" and "dependent proximity mask coefficients"
    (`check_opening_challenges`, replayed on a cloned transcript before `pcs::open_zk`, for `A`, `H` and the endpoints),
    the `assert!(!c.is_zero())` of `zk.rs` (unreachable from the private block: `run_slot` refuses first) and
    `pcs::assert_mask_sites` (pre-empted by `check_opening`). Also the OS entropy failure (independent of everything).
(D) STRUCTURAL ASSERTION: `zk::extension`'s "the extension round is not an identity (poly(ext) != 0)" panics only if a
    slot has a monomial with no public or `eq` factor. Every registered slot has one (the privacy gate's NL-1 S1,
    FR25-17), so it never fires: probability `0` for every input, a special case of (C).
(E) DATA-DEPENDENT: the LogUp zero denominators ("zero LogUp denominator"): the attempt is refused when `α` equals a
    compressed tuple whose denominator the prover inverts. For the PUBLIC tables (byte, exp, activation, the W16 range
    families, the R13 ACT tables) the prover inverts every table entry on every attempt (`S28-F1`), and after CS-3 every
    looked tuple IS a table tuple, so the event is "`α` is one of the public table values": class (C)
    (`logup_refusal_iff_table`). For the DD dictionary (D30) the table tuples contain private witness values (the row
    `Sum` and `P_dict`), and for the next-token stage IN (D34) only the prompt's own rows are inverted: there the event
    depends on the hidden data.

This file proves, at the honest-verifier level (challenges uniform and independent of the data, as in every other
L4 file):
* `attempt_law_eq`: a refusal of class (A), (C) or (D), composed with any view whose law at each challenge value is
  data-independent (the opening, sumcheck and `M` lemmas), gives a (served/refused, transcript) law that is the same for
  all data. Nothing about the refusal needs to be leaked.
* `attempt_prob_le`: if the refusal predicate itself depends on the data, every event's probability moves by at most
  the probability that the two predicates disagree.
* `logup_attempt_prob_le`: for class (E), with at most `N` and `N'` data-dependent inverted values in the two worlds,
  that is at most `(N + N')/|K|` per block; the public table entries cancel. Two data: `2N/|K|`, the form of D30 (4) and
  D34 (which also count the `768` public entries, not needed). Against a simulator that refuses on the public values
  only (`N' = 0`): `N/|K|`, with `N = |Dd|` for the dictionary.
* `refusal_output_must_be_leaked`: about the approved `ZeroKnowledge` of `Statements.lean`. If two inputs with the same
  public output part and the same declared leakage get two different deterministic refusals, NO simulator achieves
  `εzk 0 1 < 1/2`. So the declared leakage must determine the refusal OUTPUT of class (B), not only the bit.

Answer to the question of the D63 statement: "whether the request was served" IS needed, because class (B) is a
deterministic function of the hidden input (inadmissibility). For admissible inputs every refusal of classes (A), (C)
and (D) is data-independent, and class (E) is data-dependent only at the DD and next-token profiles, by at most
`N/|Fp2|` per block (or token stage) against a simulator that refuses on the public values only, which belongs in
`εzk`, not in the leakage. And the bit is NOT enough as the code stands: class (B) returns the site or the table
family, which `refusal_output_must_be_leaked` shows the leakage would have to contain.
-/
import ZK60Formal.HidingMerkle

namespace ZK60.Hiding

open scoped ENNReal

/-! ## One proof attempt: refused, or served with a transcript -/

section Attempt

variable {Ch Co V : Type}

/-- One proof attempt at challenges `ch` and coins `c`: `none` when the prover refuses (it publishes nothing), else the
challenges and the view. -/
def attempt (refuse : Ch → Prop) [DecidablePred refuse] (view : Ch → Co → V) (p : Ch × Co) : Option (Ch × V) :=
  if refuse p.1 then none else some (p.1, view p.1 p.2)

/-- The uniform law on a product is a uniform first coordinate followed by an independent uniform second one. -/
theorem uniform_prod_eq_bind [Fintype Ch] [Nonempty Ch] [Fintype Co] [Nonempty Co] :
    PMF.uniformOfFintype (Ch × Co)
      = (PMF.uniformOfFintype Ch).bind (fun a => (PMF.uniformOfFintype Co).map (fun b => (a, b))) := by
  classical
  ext ⟨a, b⟩
  rw [PMF.bind_apply, tsum_eq_single a]
  · rw [PMF.map_apply, tsum_eq_single b]
    · simp only [PMF.uniformOfFintype_apply, Fintype.card_prod, Nat.cast_mul, ite_true]
      exact ENNReal.mul_inv (Or.inr (ENNReal.natCast_ne_top _)) (Or.inr (by simp))
    · intro b' hb'
      have : (a, b) ≠ (a, b') := fun h => hb' (Prod.mk.inj h).2.symm
      simp [this]
  · intro a' ha'
    have : ∀ b' : Co, (a, b) ≠ (a', b') := fun b' h => ha' (Prod.mk.inj h).1.symm
    simp [PMF.map_apply, this]

/-- The law of an attempt: a uniform challenge, then either the refusal or the view's law at that challenge. -/
theorem map_attempt [Fintype Ch] [Nonempty Ch] [Fintype Co] [Nonempty Co] (refuse : Ch → Prop)
    [DecidablePred refuse] (view : Ch → Co → V) :
    (PMF.uniformOfFintype (Ch × Co)).map (attempt refuse view)
      = (PMF.uniformOfFintype Ch).bind (fun a => if refuse a then PMF.pure none
          else ((PMF.uniformOfFintype Co).map (view a)).map (fun v => some (a, v))) := by
  rw [uniform_prod_eq_bind, PMF.map_bind]
  congr 1
  funext a
  rw [PMF.map_comp]
  by_cases ha : refuse a
  · have : attempt refuse view ∘ (fun b => (a, b)) = Function.const Co none := by
      funext b
      simp [attempt, ha]
    rw [this, PMF.map_const]
    simp [ha]
  · rw [PMF.map_comp]
    simp only [ha, ite_false]
    congr 1
    funext b
    simp [attempt, ha]

/-- **A refusal that is a function of the challenges alone leaks nothing.** If, at every challenge value, the view has
the same law for two data (the hiding lemmas of the openings, the sumchecks and `M`), then the law of the whole attempt
(whether it is refused, the challenges, and the view when served) is the same for both. This covers every refusal of
classes (A), (C) and (D). -/
theorem attempt_law_eq [Fintype Ch] [Nonempty Ch] [Fintype Co] [Nonempty Co] (refuse : Ch → Prop)
    [DecidablePred refuse] (view view' : Ch → Co → V)
    (h : ∀ ch, (PMF.uniformOfFintype Co).map (view ch) = (PMF.uniformOfFintype Co).map (view' ch)) :
    (PMF.uniformOfFintype (Ch × Co)).map (attempt refuse view)
      = (PMF.uniformOfFintype (Ch × Co)).map (attempt refuse view') := by
  rw [map_attempt, map_attempt]
  congr 1
  funext a
  rw [h a]

/-- A probability is at most one. -/
theorem toOuterMeasure_le_one {α : Type} (p : PMF α) (s : Set α) : p.toOuterMeasure s ≤ 1 := by
  calc p.toOuterMeasure s ≤ p.toOuterMeasure Set.univ := MeasureTheory.measure_mono (Set.subset_univ s)
    _ = 1 := (PMF.toOuterMeasure_apply_eq_one_iff p Set.univ).mpr (Set.subset_univ _)

/-- **A data-dependent refusal moves every probability by at most the chance that the refusals differ.** For two
refusal predicates (two data) and views with the same law at every challenge value, every event of the attempt has
probability within `Pr_ch[refuse ch ≠ refuse' ch]`. -/
theorem attempt_prob_le [Fintype Ch] [Nonempty Ch] [Fintype Co] [Nonempty Co] (refuse refuse' : Ch → Prop)
    [DecidablePred refuse] [DecidablePred refuse'] (view view' : Ch → Co → V)
    (h : ∀ ch, (PMF.uniformOfFintype Co).map (view ch) = (PMF.uniformOfFintype Co).map (view' ch))
    (E : Set (Option (Ch × V))) :
    ((PMF.uniformOfFintype (Ch × Co)).map (attempt refuse view)).toOuterMeasure E
      ≤ ((PMF.uniformOfFintype (Ch × Co)).map (attempt refuse' view')).toOuterMeasure E
        + (PMF.uniformOfFintype Ch).toOuterMeasure {ch | ¬ (refuse ch ↔ refuse' ch)} := by
  classical
  rw [map_attempt, map_attempt, PMF.toOuterMeasure_bind_apply, PMF.toOuterMeasure_bind_apply,
    PMF.toOuterMeasure_apply (PMF.uniformOfFintype Ch), ← ENNReal.tsum_add]
  refine ENNReal.tsum_le_tsum (fun a => ?_)
  set p := PMF.uniformOfFintype Ch
  by_cases hd : refuse a ↔ refuse' a
  · have hind : Set.indicator {ch | ¬ (refuse ch ↔ refuse' ch)} p a = 0 :=
      Set.indicator_of_notMem (by simpa using hd) _
    rw [hind, add_zero]
    by_cases ha : refuse a
    · simp [ha, hd.mp ha]
    · have ha' : ¬ refuse' a := fun h' => ha (hd.mpr h')
      simp only [ha, ha', ite_false, h a]
      exact le_rfl
  · have hind : Set.indicator {ch | ¬ (refuse ch ↔ refuse' ch)} p a = p a :=
      Set.indicator_of_mem (by simpa using hd) _
    rw [hind]
    calc p a * (if refuse a then PMF.pure none
            else ((PMF.uniformOfFintype Co).map (view a)).map (fun v => some (a, v))).toOuterMeasure E
        ≤ p a * 1 := by gcongr; exact toOuterMeasure_le_one _ _
      _ = p a := mul_one _
      _ ≤ _ := le_add_self

end Attempt

/-! ## Class (C): challenge refusals; class (E): LogUp denominators -/

section LogUp

variable {K : Type}

/-- A uniform challenge lands in a fixed set `S` with probability exactly `|S|/|K|` (e.g. `c = 0`: `1/|K|`; an
extension challenge in `{0, 1}`: `2/|K|`; `α` among the public table values: `#table/|K|`). -/
theorem prob_mem_finset [Fintype K] [Nonempty K] (S : Finset K) :
    (PMF.uniformOfFintype K).toOuterMeasure {a | a ∈ S} = (S.card : ℝ≥0∞) / Fintype.card K := by
  classical
  have : ({a | a ∈ S} : Set K) = ↑S := by ext; simp
  rw [this, PMF.toOuterMeasure_apply_finset]
  simp [PMF.uniformOfFintype_apply, Finset.sum_const, nsmul_eq_mul, div_eq_mul_inv]

/-- **A lookup whose looked tuples are table tuples refuses exactly when `α` is a table value.** The prover inverts the
witness's denominators `α − w` and every table entry's `α − t` (S28-F1); when every `w` is a `t` (no miss: CS-3 refused
misses earlier), the refusal event "some inverted denominator is zero" is "`α ∈ T`". For a public table this is a
function of the challenges alone (class (C)). -/
theorem logup_refusal_iff_table [AddGroup K] (α : K) (Wd T : Finset K) (hsub : Wd ⊆ T) :
    ((∃ w ∈ Wd, α - w = 0) ∨ ∃ t ∈ T, α - t = 0) ↔ α ∈ T := by
  constructor
  · rintro (⟨w, hw, h⟩ | ⟨t, ht, h⟩)
    · rw [sub_eq_zero] at h
      rw [h]
      exact hsub hw
    · rw [sub_eq_zero] at h
      rw [h]
      exact ht
  · intro h
    exact Or.inr ⟨α, h, sub_self α⟩

/-- **Class (E): the two-world distance of a data-dependent LogUp refusal.** The challenges are `(α, rest)`; the refusal
is "`α` is one of the inverted values `A rest ∪ B rest`" in one world and "`α ∈ A rest ∪ B' rest`" in the other, where
`A` is the public part (the public tables) and `B`, `B'` the data-dependent parts (the dictionary's tuples, or the
prompt's rows), at most `N` and `N'` values. If the view has the same law at every challenge value in both worlds, every
event of the attempt moves by at most `(N + N')/|K|`. Two data: `2N/|K|`; the real prover against a simulator that
refuses on the public values only (`B' = ∅`, `N' = 0`): `N/|K|`. -/
theorem logup_attempt_prob_le [DecidableEq K] [Fintype K] [Nonempty K] {Ch' Co V : Type} [Fintype Ch'] [Nonempty Ch']
    [Fintype Co] [Nonempty Co] (A B B' : Ch' → Finset K) (N N' : ℕ) (hB : ∀ c, (B c).card ≤ N)
    (hB' : ∀ c, (B' c).card ≤ N') (view view' : K × Ch' → Co → V)
    (h : ∀ ch, (PMF.uniformOfFintype Co).map (view ch) = (PMF.uniformOfFintype Co).map (view' ch))
    (E : Set (Option ((K × Ch') × V))) :
    ((PMF.uniformOfFintype ((K × Ch') × Co)).map
        (attempt (fun ch : K × Ch' => ch.1 ∈ A ch.2 ∪ B ch.2) view)).toOuterMeasure E
      ≤ ((PMF.uniformOfFintype ((K × Ch') × Co)).map
          (attempt (fun ch : K × Ch' => ch.1 ∈ A ch.2 ∪ B' ch.2) view')).toOuterMeasure E
        + ((N + N' : ℕ) : ℝ≥0∞) / Fintype.card K := by
  refine (attempt_prob_le (fun ch : K × Ch' => ch.1 ∈ A ch.2 ∪ B ch.2) (fun ch : K × Ch' => ch.1 ∈ A ch.2 ∪ B' ch.2)
    view view' h E).trans (add_le_add le_rfl ?_)
  have hsub : {ch : K × Ch' | ¬ (ch.1 ∈ A ch.2 ∪ B ch.2 ↔ ch.1 ∈ A ch.2 ∪ B' ch.2)}
      ⊆ {ch : K × Ch' | ch.1 ∈ B ch.2 ∪ B' ch.2} := by
    intro ch hch
    simp only [Set.mem_ofPred_eq, Finset.mem_union] at hch ⊢
    tauto
  have hcard : ∀ c, (B c ∪ B' c).card ≤ N + N' := fun c =>
    (Finset.card_union_le _ _).trans (Nat.add_le_add (hB c) (hB' c))
  calc (PMF.uniformOfFintype (K × Ch')).toOuterMeasure
        {ch : K × Ch' | ¬ (ch.1 ∈ A ch.2 ∪ B ch.2 ↔ ch.1 ∈ A ch.2 ∪ B' ch.2)}
      ≤ (PMF.uniformOfFintype (K × Ch')).toOuterMeasure {ch : K × Ch' | ch.1 ∈ B ch.2 ∪ B' ch.2} :=
        MeasureTheory.measure_mono hsub
    _ ≤ ((N + N' : ℕ) : ℝ≥0∞) / Fintype.card K := prob_fst_mem_le (fun c => B c ∪ B' c) (N + N') hcard

end LogUp

/-! ## Class (B): a deterministic refusal must be in the declared leakage -/

section Leak

variable {Q D Coins : Type}

open Classical in
/-- The one-request distinguisher: ask for a receipt on `x`, output whether the answer is `o`. -/
noncomputable def askIs {M : IntModel} (P : Protocol Q D Coins M) (x : M.Input) (o : P.Stmt × P.Receipt) :
    OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool :=
  .ask (.inr x) (fun a => .ret (decide (a = .inr o)))

/-- `askIs` makes no hash query and one proof request. -/
theorem askIs_within {M : IntModel} (P : Protocol Q D Coins M) (x : M.Input) (o : P.Stmt × P.Receipt) :
    (askIs P x o).Within 0 1 := by
  intro a
  trivial

variable [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [Fintype Coins] [Nonempty Coins] [Inhabited Coins]

/-- Two disjoint events have total probability at most one. -/
theorem toOuterMeasure_add_le_one {α : Type} (p : PMF α) (A B : Set α) (h : Disjoint A B) :
    p.toOuterMeasure A + p.toOuterMeasure B ≤ 1 := by
  rw [PMF.toOuterMeasure_apply, PMF.toOuterMeasure_apply, ← ENNReal.tsum_add, ← p.tsum_coe]
  refine ENNReal.tsum_le_tsum (fun a => ?_)
  calc A.indicator p a + B.indicator p a = (A ∪ B).indicator p a := by
        rw [Set.indicator_union_of_disjoint h]
    _ ≤ p a := Set.indicator_le_self _ _ a

/-- **A deterministic refusal output must be determined by the declared leakage** (about `ZeroKnowledge` of
`Statements.lean`, as approved). Suppose the prover answers `x` with the fixed output `o` and `x'` with a different
fixed output `o'`, whatever the oracle and the coins (a refusal before any randomness is drawn, class (B): the site of
"fixed oracle range refusal" or the family of a CS-3 lookup miss), while `x` and `x'` have the same public output part
and the same declared leakage. Then no simulator achieves an advantage below `1/2` against one proof request with no
hash query. So for the code as it stands, `P.leak` must contain the refusal message, not only whether the request was
served, or the prover must return one constant refusal. -/
theorem refusal_output_must_be_leaked {M : IntModel} (P : Protocol Q D Coins M) (W : M.Weights) (x x' : M.Input)
    (o o' : P.Stmt × P.Receipt) (ho : ∀ H c, P.prove H W x c = o) (ho' : ∀ H c, P.prove H W x' c = o')
    (hne : o ≠ o') (hpub : M.publicPart (M.forward W x) = M.publicPart (M.forward W x'))
    (hleak : P.leak x = P.leak x') (εzk : ℕ → ℕ → ℝ≥0∞) (hzk : ZeroKnowledge M P εzk) :
    (2⁻¹ : ℝ≥0∞) ≤ εzk 0 1 := by
  classical
  obtain ⟨S, hS⟩ := hzk
  have hreal : ∀ (z : M.Input) (oz : P.Stmt × P.Receipt), (∀ H c, P.prove H W z c = oz) →
      realProb M P W (0 + 1) (askIs P z oz) = 1 := by
    intro z oz hz
    unfold realProb
    rw [PMF.toOuterMeasure_apply_eq_one_iff]
    intro p _
    simp [askIs, OC.runState, hz]
  have h1 := (hS W 0 1 (askIs P x o) (askIs_within P x o)).1
  have h2 := (hS W 0 1 (askIs P x' o') (askIs_within P x' o')).1
  rw [hreal x o ho] at h1
  rw [hreal x' o' ho'] at h2
  have hsum : idealProb M P S W (0 + 1) (askIs P x o) + idealProb M P S W (0 + 1) (askIs P x' o') ≤ 1 := by
    unfold idealProb
    apply toOuterMeasure_add_le_one
    rw [Set.disjoint_left]
    intro sc hx hx'
    simp only [Set.mem_ofPred_eq, askIs, OC.runState] at hx hx'
    have e1 := of_decide_eq_true hx
    have e2 := of_decide_eq_true hx'
    simp only [Sum.map_inr] at e1 e2
    rw [← hpub, ← hleak, e1] at e2
    exact hne (Sum.inr_injective e2)
  set a := idealProb M P S W (0 + 1) (askIs P x o)
  set b := idealProb M P S W (0 + 1) (askIs P x' o')
  set ε := εzk 0 1
  have h3 : (1 : ℝ≥0∞) + 1 ≤ 1 + 2 * ε := by
    calc (1 : ℝ≥0∞) + 1 ≤ (a + ε) + (b + ε) := add_le_add h1 h2
      _ = (a + b) + 2 * ε := by ring
      _ ≤ 1 + 2 * ε := add_le_add hsum le_rfl
  have h4 : (1 : ℝ≥0∞) ≤ 2 * ε := (ENNReal.add_le_add_iff_left ENNReal.one_ne_top).mp h3
  calc (2⁻¹ : ℝ≥0∞) = 2⁻¹ * 1 := (mul_one _).symm
    _ ≤ 2⁻¹ * (2 * ε) := by gcongr
    _ = ε := by
      rw [← mul_assoc, ENNReal.inv_mul_cancel (by norm_num) ENNReal.ofNat_ne_top, one_mul]

end Leak

end ZK60.Hiding
