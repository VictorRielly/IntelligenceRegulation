/-
D63, step L3 (soundness): one opening of the polynomial commitment under Fiat–Shamir, on the code's chain, with the
matrix EXTRACTED from the prover's log cut at the root's absorption (round-by-round knowledge soundness).

`SoundGroups.lean`'s `groups_sound_extracted` is the interactive bound: uniform `(λ, ρ)` and `J`, drawn after the
root, `A/|E| + col + collBound + extGuess`. Here the challenges are hashes of the chain, as `pcs::verify_zk_tagged`
draws them (`zkp-core/src/pcs.rs` of the `gpu-metal` tree):
* the root is absorbed first (`absorb_root(A)`, `protocol.rs:2003`);
* `zk_rhos` (`pcs.rs:952-973`) draws every group's `λ` (`challenge_fp2_vec(members.len())`, group after group) and
  then `ρ` (`challenge_fp2_vec(rows)`), with no absorb between: ONE wide challenge of `#claims + rows` squeezes;
* the group vectors and the proximity vector are absorbed (`"pcs-vec"`, `"pcs-prox"`, `pcs.rs:1220-1226`);
* `J = challenge_indices(Q, N)` (`pcs.rs:1227`): `⌈Q/4⌉` squeezes, four little-endian 8-byte chunks each, masked by
  `N − 1`; the opened column `j` must equal `J k` (`pcs.rs:1251`), its path must be the tree's depth.

**The protocol** (`FSWideRbr.lean`): round 0 has no message and width `w0` (the `(λ, ρ)` squeezes); round 1's message is
the clear vectors `(v, w)`, width `w1` (the index squeezes); the final message is the `Q` Merkle openings.

**The two rounds** (from `groups_sound`'s proof, split at the message):
* `opening_round0`: if the matrix is far, or close with some claim false of its decoded message, uniform `(λ, ρ)`
  keep it alive (`Alive1`: close and every group's `λ`-combined claim true, or far with `Σ ρ_i U_i` close) with
  probability at most `A/|E|` (`batch_prob`'s `1/|E|`, `comb_close_prob`'s `A/|E|`);
* `opening_round1`: from a dead `(λ, ρ)`, whatever vectors the prover sends, uniform `J` pass every check with
  probability at most `((N − (e + 1))/N)^Q` (the column test).
`opening_rbrWide` is the protocol at the level of digests, for ANY derivations `chalLR`, `chalJ` whose bias is bounded
(`hLR`, `hJ`); `lrCode_prob_le` and `idxCode_prob_le` prove those bounds for the code's derivations: `(1 + p/2^128)^(2·w0)`
for `challenge_fp2_vec`, and EXACTLY `1` for `challenge_indices` (`chunkEquiv`, `idxCode_spec`: index `k` is chunk
`k mod 4` of squeeze `⌊k/4⌋`, masked).

**The extraction.** `cutLog` cuts a log at the first query that absorbs the root (`rootAbs`: a link of a statement item
carrying it), or keeps it whole; `proverLog` recovers the prover's own log from any longer log by replaying the
prover (`OC.replay`); `xtU` extracts the matrix (`extractU`) from the prover's log so cut. The extractor reads ONLY
the prover's log and the receipt (the root), as `KnowledgeSound` requires. Once the root's absorption is logged,
longer logs extract the same matrix (`cut_proverLog_stable`): that is the stability `fs_chain_wide_flip` needs.

**What is proved.**
* `opening_extract_fail`: in the whole run (the prover, the verifier's chain, the verifier's Merkle checks), an opened
  column that verifies but is not the extracted column has probability at most `collBound T' D + 2T'²/|D|`,
  `T' = q + (ℓW + 1) + Q(h + 2)`: a collision, or a first-time query whose answer is a digest the log before it names
  (a Merkle child or leaf content, or a root that a logged query absorbs or the replayed prover outputs).
* `fs_opening_knowledge`: **the opening's round-by-round knowledge soundness under Fiat–Shamir.** The chain verifier
  accepts while some claim is false of the message decoded from the EXTRACTED matrix with probability at most
  `T·ε + collBound T D + collBound (T + 1) D + collBound T' D + 2T'²/|D|`, `T = q + ℓW + 1`,
  `ε = max(A/|E| · βLR, col · βJ)`.
* `fs_opening_knowledge_code`: the same with the code's derivations: `ε = max(A/|E| · (1 + p/2^128)^(2·w0), col)`.

**What this does not cover.** The statement (the root and the claims) is one item; in the code the root is absorbed
before the slots that fix the claims (a weaker prover, so the model is conservative; the composition with the
slots is `FSComposeBlock.lean`'s, with the hand-offs as premises). A message absorbed as several items (`"pcs-vec"` per group, then `"pcs-prox"`) is one item
here: the same chain with more links. `M`'s opening (`zk::mask_verify_tagged`) is not run here.
-/
import ZK60Formal.FSWideRbr
import ZK60Formal.SoundGroups

set_option autoImplicit false

namespace ZK60.Sound

open scoped ENNReal
open Finset Prob Code

/-! ## The opening's two interactive rounds -/

section Rounds

variable {E ι κ μ G Cl : Type} [Field E] [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] [Nonempty ι]
  [Fintype κ] [DecidableEq κ] [Fintype μ] [Fintype Cl] [DecidableEq Cl] [DecidableEq G]

/-- **The opening after `(λ, ρ)`, not yet doomed**: the matrix is close and every group's `λ`-combined claim holds of
its decoded message, or it is far and `Σ_i ρ_i U_i` is close. -/
def Alive1 (enc : (μ → E) →ₗ[E] (ι → E)) (e : ℕ) (U : κ → ι → E) (rw : Cl → κ → E) (cw : G → μ → E)
    (grp : Cl → G) (val : Cl → E) (lam : Cl → E) (ρ : κ → E) : Prop :=
  (Close (LinearMap.range enc) e U ∧ ∀ g ∈ Set.range grp,
      ∑ t, (∑ i, groupWeights rw grp lam g i • decodeRows enc e U i) t * cw g t = groupWant val grp lam g)
    ∨ (¬ Close (LinearMap.range enc) e U ∧ Close (LinearMap.range enc) e (fun _ : Unit => comb U ρ))

omit [DecidableEq ι] [Nonempty ι] in
/-- **Round 0, the batching and proximity weights.** If some claim is false of the decoded message (or the matrix is
far), uniform `(λ, ρ)` keep the opening alive with probability at most `A/|E|`. -/
theorem opening_round0 (enc : (μ → E) →ₗ[E] (ι → E)) {d e A : ℕ}
    (hd : MinDist (LinearMap.range enc) d) (h2 : 2 * e < d) (hA : e + 1 ≤ A)
    (hca : CAOn Unit (LinearMap.range enc) e A)
    (U : κ → ι → E) (rw : Cl → κ → E) (cw : G → μ → E) (grp : Cl → G) (val : Cl → E)
    (hng : ¬ GroupsGood enc e U rw cw grp val) :
    (PMF.uniformOfFintype ((Cl → E) × (κ → E))).toOuterMeasure
        {y | Alive1 enc e U rw cw grp val y.1 y.2} ≤ (A : ℝ≥0∞) / Fintype.card E := by
  classical
  set D := LinearMap.range enc with hD
  by_cases hc : Close D e U
  · have hall : ¬ ∀ c, claimValue rw cw grp (decodeRows enc e U) c = val c := fun h => hng ⟨hc, h⟩
    push Not at hall
    obtain ⟨c₀, hc₀⟩ := hall
    let δ : Cl → E := fun c =>
      if grp c = grp c₀ then claimValue rw cw grp (decodeRows enc e U) c - val c else 0
    have hδ : ∃ c, δ c ≠ 0 := ⟨c₀, by simp only [δ, ↓reduceIte]; exact sub_ne_zero.mpr hc₀⟩
    have hsub : {y : (Cl → E) × (κ → E) | Alive1 enc e U rw cw grp val y.1 y.2}
        ⊆ {y | ∑ c, y.1 c * δ c = 0} := by
      rintro y (⟨-, hy⟩ | ⟨hnc, -⟩)
      · have hb := batch_identity rw cw grp val (decodeRows enc e U) y.1 (grp c₀)
        show ∑ c, y.1 c * δ c = 0
        rw [show (fun c => y.1 c * δ c) = fun c => y.1 c * (if grp c = grp c₀ then
            claimValue rw cw grp (decodeRows enc e U) c - val c else 0) from rfl, hb, hy _ ⟨c₀, rfl⟩, sub_self]
      · exact absurd hc hnc
    refine le_trans (MeasureTheory.measure_mono hsub) ?_
    refine le_trans ?_ (ENNReal.div_le_div_right (show (1 : ℝ≥0∞) ≤ A by exact_mod_cast (by omega : 1 ≤ A)) _)
    refine prob_prod_le_of_forall_snd (fun y : (Cl → E) × (κ → E) => ∑ c, y.1 c * δ c = 0) _ (fun _ => ?_)
    exact batch_prob δ hδ
  · have hsub : {y : (Cl → E) × (κ → E) | Alive1 enc e U rw cw grp val y.1 y.2}
        ⊆ {y | Close D e (fun _ : Unit => comb U y.2)} := by
      rintro y (⟨hc', -⟩ | ⟨-, hy⟩)
      · exact absurd hc' hc
      · exact hy
    refine le_trans (MeasureTheory.measure_mono hsub) ?_
    refine prob_prod_le_of_forall_fst (fun y : (Cl → E) × (κ → E) => Close D e (fun _ : Unit => comb U y.2)) _
      (fun _ => ?_)
    exact comb_close_prob hd h2 hA hca U hc

omit [Fintype E] [DecidableEq κ] [DecidableEq Cl] in
/-- **Round 1, the column indices.** From a doomed `(λ, ρ)`, whatever clear vectors the prover sends, uniform indices
pass every check with probability at most `((N − (e + 1))/N)^Q`. -/
theorem opening_round1 (enc : (μ → E) →ₗ[E] (ι → E)) (henc : Function.Injective enc) {d e : ℕ}
    (hd : MinDist (LinearMap.range enc) d) (h2 : 2 * e < d)
    (U : κ → ι → E) (rw : Cl → κ → E) (cw : G → μ → E) (grp : Cl → G) (val : Cl → E) (lam : Cl → E) (ρ : κ → E)
    (hal : ¬ Alive1 enc e U rw cw grp val lam ρ) (v : G → μ → E) (w : μ → E) (nQ : ℕ) :
    (PMF.uniformOfFintype (Fin nQ → ι)).toOuterMeasure
        {J | GroupsAccept enc U rw cw grp val (fun g _ _ => v g) (fun _ _ => w) lam ρ J}
      ≤ (((Fintype.card ι - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ nQ := by
  classical
  set D := LinearMap.range enc with hD
  by_cases hc : Close D e U
  · obtain ⟨hV, S, hS, hUV⟩ := closeTable_spec hc
    have hX : ∀ i, enc (decodeRows enc e U i) = closeTable D e U i := fun i => enc_decodeWord enc (hV i)
    have hex : ∃ g ∈ Set.range grp,
        ∑ t, (∑ i, groupWeights rw grp lam g i • decodeRows enc e U i) t * cw g t ≠ groupWant val grp lam g := by
      by_contra hno
      push Not at hno
      exact hal (Or.inl ⟨hc, hno⟩)
    obtain ⟨g, hg, hne⟩ := hex
    by_cases hv : ∑ t, v g t * cw g t = groupWant val grp lam g
    · have hvne : v g ≠ ∑ i, groupWeights rw grp lam g i • decodeRows enc e U i := by
        intro heq
        apply hne
        rw [← heq]
        exact hv
      have hXc : enc (∑ i, groupWeights rw grp lam g i • decodeRows enc e U i)
          = comb (closeTable D e U) (groupWeights rw grp lam g) := by
        simp only [comb, map_sum, map_smul, hX]
      have hagree : ∀ j ∈ S, comb U (groupWeights rw grp lam g) j
          = comb (closeTable D e U) (groupWeights rw grp lam g) j := by
        intro j hj
        rw [comb_apply, comb_apply]
        exact sum_congr rfl fun i _ => by rw [hUV j hj i]
      have hdist := le_card_ne_add hd (LinearMap.mem_range_self enc (v g))
        (hXc ▸ LinearMap.mem_range_self enc _) (fun h => hvne (henc (h.trans hXc.symm))) hS hagree
      have ht : e + 1 ≤ (univ.filter (fun j => enc (v g) j ≠ comb U (groupWeights rw grp lam g) j)).card := by
        omega
      refine le_trans (MeasureTheory.measure_mono (fun J hJ => ?_)) (column_test_sound _ _ ht nQ)
      exact hJ.2.1 g hg
    · exact prob_le_of_forall_not (fun J hJ => hv (hJ.1 g hg)) _
  · have hρ : ¬ Close D e (fun _ : Unit => comb U ρ) := fun h => hal (Or.inr ⟨hc, h⟩)
    have ht : e + 1 ≤ (univ.filter (fun j => enc w j ≠ comb U ρ j)).card := by
      by_contra hlt
      exact hρ (close_of_card_ne_le (LinearMap.mem_range_self enc w) (by omega))
    exact le_trans (MeasureTheory.measure_mono (fun J hJ => hJ.2.2)) (column_test_sound _ _ ht nQ)

end Rounds

/-! ## The opening as a protocol on digests -/

section Digests

variable {E κ μ G Cl : Type} [Field E] [Fintype E] [DecidableEq E]
  [Fintype κ] [DecidableEq κ] [Fintype μ] [Fintype Cl] [DecidableEq Cl] [DecidableEq G]
variable {D X : Type} [Fintype D] [Nonempty D]

/-- The claims of one opening: row weights, the groups' column weights, the groups, the claimed values. -/
structure OClaims (Cl G κ μ E : Type) where
  rw : Cl → κ → E
  cw : G → μ → E
  grp : Cl → G
  val : Cl → E

/-- Round 1's message: a clear vector per group and the clear proximity vector. -/
abbrev OMsg (G μ E : Type) : Type := (G → μ → E) × (μ → E)

/-- Read a list of digests as a vector (a default digest past its end). -/
def vecOf (d₀ : D) (k : ℕ) (ds : List D) : Fin k → D := fun j => ds.getD j d₀

omit [Fintype D] [Nonempty D] in
/-- Reading a vector's list gives the vector back. -/
theorem vecOf_ofFn (d₀ : D) {k : ℕ} (b : Fin k → D) : vecOf d₀ k (List.ofFn b) = b := by
  funext j
  simp [vecOf, List.getD_eq_getElem?_getD]

/-- The opening's round widths: `w0` squeezes for `(λ, ρ)`, then `w1` for the indices. -/
def opW (w0 w1 : ℕ) : ℕ → ℕ := fun i => if i = 0 then w0 else w1

/-- Both rounds squeeze at least once. -/
theorem opW_pos {w0 w1 : ℕ} (h0 : 0 < w0) (h1 : 0 < w1) : ∀ i, 0 < opW w0 w1 i := by
  intro i
  unfold opW
  split_ifs <;> assumption

/-- Round 0 has no message, round 1 has the clear vectors. -/
def opMsg : ℕ → Bool := fun i => i == 1

variable {h : ℕ}

/-- **The opening's state on digest transcripts**, for the matrix `U`: good (every claim true of the decoded message,
`U` close); then `Alive1` at the `(λ, ρ)` the digests derive; then the verifier's checks at the indices the next
digests derive. -/
def opSt (enc : (μ → E) →ₗ[E] (Fin (2 ^ h) → E)) (e : ℕ) (clOf : X → OClaims Cl G κ μ E) (d₀ : D) (w0 w1 : ℕ)
    {nQ : ℕ} (chalLR : (Fin w0 → D) → (Cl → E) × (κ → E)) (chalJ : (Fin w1 → D) → (Fin nQ → Fin (2 ^ h)))
    (U : κ → Fin (2 ^ h) → E) (x : X) : List (OMsg G μ E × List D) → Prop
  | [] => GroupsGood enc e U (clOf x).rw (clOf x).cw (clOf x).grp (clOf x).val
  | [(_, ds)] => Alive1 enc e U (clOf x).rw (clOf x).cw (clOf x).grp (clOf x).val
      (chalLR (vecOf d₀ w0 ds)).1 (chalLR (vecOf d₀ w0 ds)).2
  | [(_, ds), (mv, ds')] => GroupsAccept enc U (clOf x).rw (clOf x).cw (clOf x).grp (clOf x).val
      (fun g _ _ => mv.1 g) (fun _ _ => mv.2) (chalLR (vecOf d₀ w0 ds)).1 (chalLR (vecOf d₀ w0 ds)).2
      (chalJ (vecOf d₀ w1 ds'))
  | _ => GroupsGood enc e U (clOf x).rw (clOf x).cw (clOf x).grp (clOf x).val

/-- **The opening is round-by-round sound with vector challenges**, for every matrix and any derivations with bounded
bias: per-round error `max(A/|E|·βLR, col·βJ)`. -/
theorem opening_rbrWide (enc : (μ → E) →ₗ[E] (Fin (2 ^ h) → E)) (henc : Function.Injective enc) {d e A : ℕ}
    (hd : MinDist (LinearMap.range enc) d) (h2 : 2 * e < d) (hA : e + 1 ≤ A)
    (hca : CAOn Unit (LinearMap.range enc) e A) (clOf : X → OClaims Cl G κ μ E) (d₀ : D) (w0 w1 : ℕ) {nQ : ℕ}
    (chalLR : (Fin w0 → D) → (Cl → E) × (κ → E)) (chalJ : (Fin w1 → D) → (Fin nQ → Fin (2 ^ h)))
    (βLR βJ : ℝ≥0∞)
    (hLR : ∀ Ev : (Cl → E) × (κ → E) → Prop, (PMF.uniformOfFintype (Fin w0 → D)).toOuterMeasure {b | Ev (chalLR b)}
      ≤ (PMF.uniformOfFintype ((Cl → E) × (κ → E))).toOuterMeasure {y | Ev y} * βLR)
    (hJ : ∀ Ev : (Fin nQ → Fin (2 ^ h)) → Prop, (PMF.uniformOfFintype (Fin w1 → D)).toOuterMeasure {b | Ev (chalJ b)}
      ≤ (PMF.uniformOfFintype (Fin nQ → Fin (2 ^ h))).toOuterMeasure {J | Ev J} * βJ)
    (Ux : X → κ → Fin (2 ^ h) → E) :
    RbrWide 2 (opW w0 w1) (fun x => opSt enc e clOf d₀ w0 w1 chalLR chalJ (Ux x) x)
      (max ((A : ℝ≥0∞) / Fintype.card E * βLR)
        ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ)) where
  round x τ m hτ hns := by
    rcases τ with _ | ⟨⟨u, ds⟩, _ | ⟨e2, τ⟩⟩
    · rw [prob_ofFn_congr (show opW w0 w1 ([] : List (OMsg G μ E × List D)).length = w0 from rfl)
        (fun ds => opSt enc e clOf d₀ w0 w1 chalLR chalJ (Ux x) x ([] ++ [(m, ds)]))]
      have hset : {b : Fin w0 → D | opSt enc e clOf d₀ w0 w1 chalLR chalJ (Ux x) x ([] ++ [(m, List.ofFn b)])}
          = {b | (fun y : (Cl → E) × (κ → E) => Alive1 enc e (Ux x) (clOf x).rw (clOf x).cw (clOf x).grp
              (clOf x).val y.1 y.2) (chalLR b)} := by
        ext b
        simp only [Set.mem_ofPred_eq, List.nil_append, opSt, vecOf_ofFn]
      rw [hset]
      refine (hLR (fun y : (Cl → E) × (κ → E) => Alive1 enc e (Ux x) (clOf x).rw (clOf x).cw (clOf x).grp
        (clOf x).val y.1 y.2)).trans (le_trans ?_ (le_max_left _ _))
      exact mul_le_mul' (opening_round0 enc hd h2 hA hca (Ux x) _ _ _ _ hns) le_rfl
    · rw [prob_ofFn_congr (show opW w0 w1 ([(u, ds)] : List (OMsg G μ E × List D)).length = w1 from rfl)
        (fun ds' => opSt enc e clOf d₀ w0 w1 chalLR chalJ (Ux x) x ([(u, ds)] ++ [(m, ds')]))]
      have hset : {b : Fin w1 → D | opSt enc e clOf d₀ w0 w1 chalLR chalJ (Ux x) x ([(u, ds)] ++ [(m, List.ofFn b)])}
          = {b | (fun J : Fin nQ → Fin (2 ^ h) => GroupsAccept enc (Ux x) (clOf x).rw (clOf x).cw (clOf x).grp
              (clOf x).val (fun g _ _ => m.1 g) (fun _ _ => m.2) (chalLR (vecOf d₀ w0 ds)).1
              (chalLR (vecOf d₀ w0 ds)).2 J) (chalJ b)} := by
        ext b
        simp only [Set.mem_ofPred_eq, List.cons_append, List.nil_append, opSt, vecOf_ofFn]
      rw [hset]
      refine (hJ (fun J : Fin nQ → Fin (2 ^ h) => GroupsAccept enc (Ux x) (clOf x).rw (clOf x).cw (clOf x).grp
        (clOf x).val (fun g _ _ => m.1 g) (fun _ _ => m.2) (chalLR (vecOf d₀ w0 ds)).1
        (chalLR (vecOf d₀ w0 ds)).2 J)).trans (le_trans ?_ (le_max_right _ _))
      exact mul_le_mul' (opening_round1 enc henc hd h2 (Ux x) _ _ _ _ _ _ hns m.1 m.2 nQ) le_rfl
    · simp at hτ

end Digests

/-! ## Replaying the prover, and the log cut at the root's absorption -/

section Replay

variable {I O α : Type}

/-- A replay that succeeds on a log succeeds the same way on any longer log. -/
theorem _root_.ZK60.OC.replay_append_of_some : ∀ (A : OC I O α) (P R : List (I × O)) (r : α × ℕ),
    A.replay P = some r → A.replay (P ++ R) = some r
  | .ret a, P, R, r, h => by simpa [OC.replay] using h
  | .ask i k, [], R, r, h => by simp [OC.replay] at h
  | .ask i k, e :: P, R, r, h => by
    simp only [OC.replay, List.cons_append, Option.map_eq_some_iff] at h ⊢
    obtain ⟨r', hr', rfl⟩ := h
    exact ⟨r', ZK60.OC.replay_append_of_some (k e.2) P R r' hr', rfl⟩

/-- A successful replay uses at most the log's entries. -/
theorem _root_.ZK60.OC.replay_le_length : ∀ (A : OC I O α) (P : List (I × O)) (r : α × ℕ),
    A.replay P = some r → r.2 ≤ P.length
  | .ret a, P, r, h => by
    simp only [OC.replay, Option.some.injEq] at h
    rw [← h]
    exact Nat.zero_le _
  | .ask i k, [], r, h => by simp [OC.replay] at h
  | .ask i k, e :: P, r, h => by
    simp only [OC.replay, Option.map_eq_some_iff] at h
    obtain ⟨r', hr', rfl⟩ := h
    have := ZK60.OC.replay_le_length (k e.2) P r' hr'
    simp only [List.length_cons]
    omega

/-- If a replay fails on a log and succeeds on a longer one, it uses more entries than the first log has. -/
theorem _root_.ZK60.OC.replay_none_lt : ∀ (A : OC I O α) (P R : List (I × O)) (r : α × ℕ),
    A.replay P = none → A.replay (P ++ R) = some r → P.length < r.2
  | .ret a, P, R, r, h, _ => by simp [OC.replay] at h
  | .ask i k, [], R, r, _, h2 => by
    cases R with
    | nil => simp [OC.replay] at h2
    | cons e R =>
      simp only [List.nil_append, OC.replay, Option.map_eq_some_iff] at h2
      obtain ⟨r', -, rfl⟩ := h2
      simp
  | .ask i k, e :: P, R, r, h1, h2 => by
    simp only [OC.replay, List.cons_append, Option.map_eq_some_iff, Option.map_eq_none_iff] at h1 h2
    obtain ⟨r', hr', rfl⟩ := h2
    have := ZK60.OC.replay_none_lt (k e.2) P R r' h1 hr'
    simp only [List.length_cons]
    omega

end Replay

section Cut

variable {X Msg Q D : Type} [DecidableEq D]

/-- The root a query absorbs, if it links a statement item. -/
def rootAbs (C : ChainEnc (PItem X Msg) Q D) (rootOf : X → D) (y : Q) : Option D :=
  match C.ldec y with
  | some (_, .stmt x') => some (rootOf x')
  | _ => none

omit [DecidableEq D] in
/-- The statement's link absorbs the statement's root. -/
theorem rootAbs_link (C : ChainEnc (PItem X Msg) Q D) (rootOf : X → D) (d : D) (x : X) :
    rootAbs C rootOf (C.link d (.stmt x)) = some (rootOf x) := by
  simp [rootAbs, C.ldec_link]

/-- Whether a log entry absorbs the root `r`. -/
def isRootAbs (C : ChainEnc (PItem X Msg) Q D) (rootOf : X → D) (r : D) (e : Q × D) : Bool :=
  decide (rootAbs C rootOf e.1 = some r)

/-- **The log cut at the root's absorption**: the entries before the first one that absorbs `r` (all of them if none
does). -/
def cutLog (C : ChainEnc (PItem X Msg) Q D) (rootOf : X → D) (r : D) (L : List (Q × D)) : List (Q × D) :=
  L.take (L.findIdx (isRootAbs C rootOf r))

/-- Once the log contains an absorption of `r`, extending it does not move the cut. -/
theorem cutLog_append (C : ChainEnc (PItem X Msg) Q D) (rootOf : X → D) (r : D) (L R : List (Q × D))
    (h : ∃ e ∈ L, rootAbs C rootOf e.1 = some r) : cutLog C rootOf r (L ++ R) = cutLog C rootOf r L := by
  have hlt : L.findIdx (isRootAbs C rootOf r) < L.length := by
    obtain ⟨e, he, h⟩ := h
    exact List.findIdx_lt_length_of_exists ⟨e, he, by simp [isRootAbs, h]⟩
  rw [cutLog, cutLog, List.findIdx_append, ite_eq_left hlt, List.take_append_of_le_length hlt.le]

/-- The prover's own log, recovered from a log of the whole run by replaying the prover. -/
def proverLog {β : Type} (A : OC Q D β) (P : List (Q × D)) : List (Q × D) :=
  match A.replay P with
  | some r => P.take r.2
  | none => P

omit [DecidableEq D] in
/-- On the whole run's log, `proverLog` is exactly the prover's log. -/
theorem proverLog_runLog {β : Type} (A : OC Q D β) (H : Q → D) (R : List (Q × D)) :
    proverLog A ((A.runLog H).2 ++ R) = (A.runLog H).2 := by
  simp only [proverLog, OC.replay_runLog_append]
  exact List.take_left' rfl

/-- **The extraction is frozen at the root's absorption**: once a log contains an absorption of `r`, every longer log
cuts the prover's log at the same place. -/
theorem cut_proverLog_stable {β : Type} (A : OC Q D β) (C : ChainEnc (PItem X Msg) Q D) (rootOf : X → D)
    (r : D) (P P' : List (Q × D)) (hpre : P <+: P') (h : ∃ e ∈ P, rootAbs C rootOf e.1 = some r) :
    cutLog C rootOf r (proverLog A P') = cutLog C rootOf r (proverLog A P) := by
  obtain ⟨R, rfl⟩ := hpre
  rcases hr : A.replay P with _ | r0
  · have hP : proverLog A P = P := by simp [proverLog, hr]
    rw [hP]
    rcases hr' : A.replay (P ++ R) with _ | r'
    · have : proverLog A (P ++ R) = P ++ R := by simp [proverLog, hr']
      rw [this, cutLog_append C rootOf r P R h]
    · have hlt := ZK60.OC.replay_none_lt A P R r' hr hr'
      have : proverLog A (P ++ R) = P ++ R.take (r'.2 - P.length) := by
        simp only [proverLog, hr']
        rw [List.take_append, List.take_of_length_le hlt.le]
      rw [this, cutLog_append C rootOf r P _ h]
  · have h1 := ZK60.OC.replay_append_of_some A P R r0 hr
    have : proverLog A (P ++ R) = proverLog A P := by
      simp only [proverLog, h1, hr]
      exact List.take_append_of_le_length (ZK60.OC.replay_le_length A P r0 hr)
    rw [this]

end Cut

/-! ## The opening's knowledge soundness on the chain -/

section Knowledge

variable {E κ μ G Cl : Type} [Field E] [Fintype E] [DecidableEq E]
  [Fintype κ] [DecidableEq κ] [Fintype μ] [Fintype Cl] [DecidableEq Cl] [DecidableEq G]
variable {X Q D S Col : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D]
variable {h : ℕ}

/-- **The extracted matrix**: `extractU` of the prover's log cut at the root's absorption. -/
def xtU (M : MerkleEnc Q D S Col) (colVal : Col → κ → E) (c₀ : Col) (h : ℕ) {Msg : Type}
    (C : ChainEnc (PItem X Msg) Q D) (rootOf : X → D) {β : Type} (A : OC Q D β) (P : List (Q × D)) (x : X) :
    κ → Fin (2 ^ h) → E :=
  extractU M colVal c₀ (cutLog C rootOf (rootOf x) (proverLog A P)) h (rootOf x)

/-- **The opening's final check** at the digests of the two rounds: every group's claim check, and at each derived
index the opening verifies against the root (a path of the tree's depth) and its column agrees with every re-encoded
group vector and the re-encoded proximity vector. -/
def opFinal (M : MerkleEnc Q D S Col) (colVal : Col → κ → E) (enc : (μ → E) →ₗ[E] (Fin (2 ^ h) → E))
    (clOf : X → OClaims Cl G κ μ E) (rootOf : X → D) (d₀ : D) (w0 w1 : ℕ) {nQ : ℕ}
    (chalLR : (Fin w0 → D) → (Cl → E) × (κ → E)) (chalJ : (Fin w1 → D) → (Fin nQ → Fin (2 ^ h)))
    (H : Q → D) (x : X) (ptr : List (OMsg G μ E × List D)) (ops : Fin nQ → MerkleOpening D S Col) : Prop :=
  match ptr with
  | [(_, ds), (mv, ds')] =>
      (∀ g ∈ Set.range (clOf x).grp,
        ∑ t, mv.1 g t * (clOf x).cw g t = groupWant (clOf x).val (clOf x).grp (chalLR (vecOf d₀ w0 ds)).1 g)
      ∧ ∀ k, M.Opens H h (rootOf x) (chalJ (vecOf d₀ w1 ds') k) (ops k)
        ∧ (∀ g ∈ Set.range (clOf x).grp, enc (mv.1 g) (chalJ (vecOf d₀ w1 ds') k)
            = ∑ i, groupWeights (clOf x).rw (clOf x).grp (chalLR (vecOf d₀ w0 ds)).1 g i * colVal (ops k).col i)
        ∧ enc mv.2 (chalJ (vecOf d₀ w1 ds') k) = ∑ i, (chalLR (vecOf d₀ w0 ds)).2 i * colVal (ops k).col i
  | _ => False

/-- **The opening's chain verifier**: two messages; the chain of the verifier's items reads as a transcript of two
rounds, and the final check passes. -/
def opAccepts (M : MerkleEnc Q D S Col) (colVal : Col → κ → E) (enc : (μ → E) →ₗ[E] (Fin (2 ^ h) → E))
    (clOf : X → OClaims Cl G κ μ E) (rootOf : X → D) (d₀ : D) (m₀ : OMsg G μ E) {w0 w1 : ℕ} (h0 : 0 < w0)
    (h1 : 0 < w1) {nQ : ℕ} (chalLR : (Fin w0 → D) → (Cl → E) × (κ → E))
    (chalJ : (Fin w1 → D) → (Fin nQ → Fin (2 ^ h))) (C : ChainEnc (PItem X (OMsg G μ E)) Q D) (H : Q → D)
    (x : X) (ms : List (OMsg G μ E)) (ops : Fin nQ → MerkleOpening D S Col) : Prop :=
  ms.length = 2 ∧ ∃ ptr, rDecodeW 2 (opW w0 w1) opMsg m₀ ((C.chainFrom H []
      ((pHeadsW 2 (opW w0 w1) opMsg x ms).flatMap (pSteps 2 (opW w0 w1) (opW_pos h0 h1)).items)).drop 1)
      = some (ptr, none, []) ∧ opFinal M colVal enc clOf rootOf d₀ w0 w1 chalLR chalJ H x ptr ops

omit [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D] in
/-- The verifier's hashing computes the chain. -/
theorem ChainEnc.chainOCFrom_run {It : Type} (C : ChainEnc It Q D) (H : Q → D) :
    ∀ (τ : List (It × D)) (its : List It), (C.chainOCFrom (H C.start) τ its).run H = C.chainFrom H τ its
  | _, [] => rfl
  | _, _ :: its => ChainEnc.chainOCFrom_run C H _ its

omit [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D] in
/-- The verifier's hashing from the start query computes the chain. -/
theorem ChainEnc.chainOC_run {It : Type} (C : ChainEnc It Q D) (H : Q → D) (its : List It) :
    (C.chainOC its).run H = C.chainFrom H [] its :=
  C.chainOCFrom_run H [] its

/-- **The digests a log names for the extractor**: every Merkle child or leaf content of a logged question, every root
a logged question (or the query itself) absorbs, and the root the replayed prover outputs. -/
def extNamed {Msg : Type} (M : MerkleEnc Q D S Col) (C : ChainEnc (PItem X Msg) Q D) (rootOf : X → D)
    {β : Type} (A : OC Q D β) (rootB : β → D) (P : List (Q × D)) (y : Q) : Finset D :=
  (P.map Prod.fst).toFinset.biUnion (fun y' => M.nodeKids y' ∪ M.leafKid y' ∪ (rootAbs C rootOf y').toFinset)
    ∪ (rootAbs C rootOf y).toFinset ∪ ((A.replay P).map (fun r => rootB r.1)).toFinset

omit [Fintype Q] [Fintype D] [Nonempty D] in
/-- At most `4|P| + 2` digests. -/
theorem extNamed_card {Msg : Type} (M : MerkleEnc Q D S Col) (C : ChainEnc (PItem X Msg) Q D) (rootOf : X → D)
    {β : Type} (A : OC Q D β) (rootB : β → D) (P : List (Q × D)) (y : Q) :
    (extNamed M C rootOf A rootB P y).card ≤ 4 * P.length + 2 := by
  unfold extNamed
  have hk : ∀ y', (M.nodeKids y' ∪ M.leafKid y' ∪ (rootAbs C rootOf y').toFinset).card ≤ 4 := by
    intro y'
    have h1 : (M.nodeKids y').card ≤ 2 := by
      unfold MerkleEnc.nodeKids
      split
      · exact card_le_two
      · simp
    have h2 : (M.leafKid y').card ≤ 1 := by
      unfold MerkleEnc.leafKid
      split
      · simp
      · simp
    have h3 := ChainEnc.option_card_toFinset_le (rootAbs C rootOf y')
    refine (card_union_le _ _).trans ?_
    have := card_union_le (M.nodeKids y') (M.leafKid y')
    omega
  have hb : ((P.map Prod.fst).toFinset.biUnion
      (fun y' => M.nodeKids y' ∪ M.leafKid y' ∪ (rootAbs C rootOf y').toFinset)).card ≤ 4 * P.length := by
    refine card_biUnion_le.trans ?_
    calc ∑ y' ∈ (P.map Prod.fst).toFinset, (M.nodeKids y' ∪ M.leafKid y' ∪ (rootAbs C rootOf y').toFinset).card
        ≤ ∑ _y' ∈ (P.map Prod.fst).toFinset, 4 := sum_le_sum (fun y' _ => hk y')
      _ = 4 * (P.map Prod.fst).toFinset.card := by rw [sum_const, smul_eq_mul, mul_comm]
      _ ≤ 4 * P.length := Nat.mul_le_mul_left _ ((List.toFinset_card_le _).trans (by simp))
  have h4 := ChainEnc.option_card_toFinset_le (rootAbs C rootOf y)
  have h5 := ChainEnc.option_card_toFinset_le ((A.replay P).map (fun r => rootB r.1))
  refine (card_union_le _ _).trans ?_
  have := card_union_le ((P.map Prod.fst).toFinset.biUnion
      (fun y' => M.nodeKids y' ∪ M.leafKid y' ∪ (rootAbs C rootOf y').toFinset)) (rootAbs C rootOf y).toFinset
  omega

/-- `Σ_{t < n} (4t + 2) = 2n²`. -/
theorem sum_range_four_mul_add_two : ∀ n : ℕ, ∑ t ∈ range n, (4 * t + 2) = 2 * n * n
  | 0 => rfl
  | n + 1 => by
    rw [sum_range_succ, sum_range_four_mul_add_two n]
    ring

/-- The verifier's items for the prover's output. -/
noncomputable def opItems {β : Type} (w0 w1 : ℕ) (h0 : 0 < w0) (h1 : 0 < w1) (o : X × List (OMsg G μ E) × β) :
    List (PItem X (OMsg G μ E)) :=
  (pHeadsW 2 (opW w0 w1) opMsg o.1 o.2.1).flatMap (pSteps 2 (opW w0 w1) (opW_pos h0 h1)).items

/-- The indices a chain derives (from round 1's digests). -/
def opJ (d₀ : D) (m₀ : OMsg G μ E) (w0 w1 : ℕ) {nQ : ℕ} (chalJ : (Fin w1 → D) → (Fin nQ → Fin (2 ^ h)))
    (τ : List (PItem X (OMsg G μ E) × D)) : Fin nQ → Fin (2 ^ h) :=
  match rDecodeW 2 (opW w0 w1) opMsg m₀ (τ.drop 1) with
  | some ([(_, _), (_, ds')], _, _) => chalJ (vecOf d₀ w1 ds')
  | _ => fun _ => ⟨0, Nat.two_pow_pos h⟩

omit [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D] [Field E] [Fintype E] [DecidableEq E]
  [Fintype μ] [DecidableEq G] in
/-- On a chain that reads as two rounds, the derived indices are round 1's. -/
theorem opJ_eq (d₀ : D) (m₀ : OMsg G μ E) (w0 w1 : ℕ) {nQ : ℕ} (chalJ : (Fin w1 → D) → (Fin nQ → Fin (2 ^ h)))
    (τ : List (PItem X (OMsg G μ E) × D)) (u mv : OMsg G μ E) (ds ds' : List D) (pm : Option (OMsg G μ E))
    (dl : List D) (hdec : rDecodeW 2 (opW w0 w1) opMsg m₀ (τ.drop 1) = some ([(u, ds), (mv, ds')], pm, dl)) :
    opJ d₀ m₀ w0 w1 chalJ τ = chalJ (vecOf d₀ w1 ds') := by
  unfold opJ
  rw [hdec]

/-- **The whole run**: the prover, the verifier's chain, and the verifier's Merkle checks at the derived indices. -/
noncomputable def opRun (M : MerkleEnc Q D S Col) (C : ChainEnc (PItem X (OMsg G μ E)) Q D) (d₀ : D) (m₀ : OMsg G μ E)
    {w0 w1 : ℕ} (h0 : 0 < w0) (h1 : 0 < w1) {nQ : ℕ} (chalJ : (Fin w1 → D) → (Fin nQ → Fin (2 ^ h)))
    (Pv : OC Q D (X × List (OMsg G μ E) × (Fin nQ → MerkleOpening D S Col))) : OC Q D Unit :=
  Pv.bind (fun o => (C.chainOC (opItems w0 w1 h0 h1 o)).bind
    (fun τ => M.checkAll h (List.ofFn (fun k => ((opJ d₀ m₀ w0 w1 chalJ τ k : ℕ), o.2.2 k)))))

omit [Field E] [Fintype E] [DecidableEq E] [Fintype μ] [DecidableEq G] in
/-- **The extraction fails rarely.** In the whole run, an opened column that verifies against the root at its derived
index but is not the column extracted from the prover's log cut at the root's absorption has probability at most
`collBound T' D + 2T'²/|D|`. -/
theorem opening_extract_fail (M : MerkleEnc Q D S Col) (C : ChainEnc (PItem X (OMsg G μ E)) Q D)
    (rootOf : X → D) (d₀ : D) (m₀ : OMsg G μ E) {w0 w1 : ℕ} (h0 : 0 < w0) (h1 : 0 < w1) {nQ : ℕ}
    (chalJ : (Fin w1 → D) → (Fin nQ → Fin (2 ^ h))) (q : ℕ)
    (Pv : OC Q D (X × List (OMsg G μ E) × (Fin nQ → MerkleOpening D S Col))) (hPv : Pv.Bounded q) :
    prH (fun H => ∃ u ds mv ds', rDecodeW 2 (opW w0 w1) opMsg m₀
          ((C.chainFrom H [] (opItems w0 w1 h0 h1 (Pv.run H))).drop 1) = some ([(u, ds), (mv, ds')], none, [])
        ∧ ∃ k, M.Opens H h (rootOf (Pv.run H).1) (chalJ (vecOf d₀ w1 ds') k) ((Pv.run H).2.2 k)
          ∧ M.extractCol (cutLog C rootOf (rootOf (Pv.run H).1) (Pv.runLog H).2) h (chalJ (vecOf d₀ w1 ds') k)
              (rootOf (Pv.run H).1) ≠ some ((Pv.run H).2.2 k).col)
      ≤ collBound (q + (ℓW 2 (opW w0 w1) + 1) + nQ * (h + 2)) D
        + ((2 * (q + (ℓW 2 (opW w0 w1) + 1) + nQ * (h + 2)) * (q + (ℓW 2 (opW w0 w1) + 1) + nQ * (h + 2)) : ℕ)
          : ℝ≥0∞) / Fintype.card D := by
  classical
  set T' := q + (ℓW 2 (opW w0 w1) + 1) + nQ * (h + 2) with hT'
  set Cm := opRun (h := h) M C d₀ m₀ h0 h1 chalJ Pv with hCmdef
  have hk : ∀ o : X × List (OMsg G μ E) × (Fin nQ → MerkleOpening D S Col),
      ((C.chainOC (opItems w0 w1 h0 h1 o)).bind (fun τ => M.checkAll h
        (List.ofFn (fun k => ((opJ d₀ m₀ w0 w1 chalJ τ k : ℕ), o.2.2 k))))).Bounded
        ((ℓW 2 (opW w0 w1) + 1) + nQ * (h + 2)) := by
    intro o
    refine ((C.chainOC_bounded _).mono (Nat.add_le_add_right
      (pHeadsW_length_le (opW_pos h0 h1) o.1 o.2.1) 1)).bind (fun τ => ?_)
    have := M.checkAll_bounded h (List.ofFn (fun k => ((opJ d₀ m₀ w0 w1 chalJ τ k : ℕ), o.2.2 k)))
    simpa using this
  have hCm : Cm.Bounded T' := (hPv.bind hk).mono (by omega)
  set FX : List (Q × D) → Q → Finset D := extNamed M C rootOf Pv (fun o => rootOf o.1) with hFX
  have hcoll := collision_prob_le Cm T' hCm
  have hfr := freshHitQ_prob_le_gen Cm T' hCm FX (fun t => 4 * t + 2)
    (fun P y => extNamed_card M C rootOf Pv _ P y)
  rw [sum_range_four_mul_add_two] at hfr
  refine le_trans (MeasureTheory.measure_mono ?_) ((MeasureTheory.measure_union_le _ _).trans
    (add_le_add hcoll hfr))
  rintro H ⟨u, ds, mv, ds', hdec, k, hop, hne⟩
  set o := Pv.run H with ho
  set Lp := (Pv.runLog H).2 with hLp
  set r := rootOf o.1 with hr
  set Lc := cutLog C rootOf r Lp with hLcdef
  have hrun : (C.chainOC (opItems w0 w1 h0 h1 o)).run H = C.chainFrom H [] (opItems w0 w1 h0 h1 o) :=
    C.chainOC_run H _
  have hj := opJ_eq d₀ m₀ w0 w1 chalJ (C.chainFrom H [] (opItems w0 w1 h0 h1 o)) u mv ds ds' none [] hdec
  have hqCm : OC.queries H Cm = Lp.map Prod.fst ++ (OC.queries H (C.chainOC (opItems w0 w1 h0 h1 o))
      ++ OC.queries H (M.checkAll h (List.ofFn (fun k => ((chalJ (vecOf d₀ w1 ds') k : ℕ), o.2.2 k))))) := by
    rw [hCmdef, opRun, OC.queries_bind, OC.queries_bind, hrun, hj]
    rfl
  have hv : ∀ v ∈ M.openQs H (chalJ (vecOf d₀ w1 ds') k) (o.2.2 k), v ∈ OC.queries H Cm := by
    intro v hv
    rw [hqCm]
    refine List.mem_append_right _ (List.mem_append_right _ ?_)
    exact M.checkAll_queries H h _ ((chalJ (vecOf d₀ w1 ds') k : ℕ), o.2.2 k) (List.mem_ofFn.mpr ⟨k, rfl⟩)
      hop.1 v hv
  have hLpQ : ∀ y ∈ Lp.map Prod.fst, y ∈ OC.queries H Cm := by
    intro y hy
    rw [hqCm]
    exact List.mem_append_left _ hy
  have hLcA : ∀ e ∈ Lc, e.2 = H e.1 := fun e he => OC.runLog_answer H Pv e (List.mem_of_mem_take he)
  rcases M.extract_of_opens H Lc hLcA r hop with hext | ⟨v, hvq, hb⟩
  · exact absurd hext hne
  rcases hb with ⟨y, hy, hyv, hHy⟩ | ⟨hvL, hvT⟩
  · left
    have hyLp : y ∈ Lp.map Prod.fst := by
      obtain ⟨e', he', rfl⟩ := List.mem_map.mp hy
      exact List.mem_map_of_mem (List.mem_of_mem_take he')
    exact ⟨y, hLpQ y hyLp, v, hv v hvq, hyv, hHy⟩
  · right
    have hvC : v ∈ (Cm.runLog H).2.map Prod.fst := hv v hvq
    refine freshHitQ_of_first H (OC.runLog_answer H Cm) FX hvC (fun t e ht he hfirst => ?_)
    obtain ⟨Lr, hLr⟩ : ∃ Lr, (Cm.runLog H).2 = Lp ++ Lr := ⟨_, OC.runLog_bind H Pv _⟩
    set c := Lp.findIdx (isRootAbs C rootOf r) with hc
    have hLc : Lc = Lp.take c := rfl
    have hsplit : (Cm.runLog H).2 = Lc ++ (Lp.drop c ++ Lr) := by
      rw [hLr, hLc, ← List.append_assoc, List.take_append_drop]
    have htc : Lc.length ≤ t := first_after_prefix hvL (by rw [← hsplit]; exact ht) he
    have hpre : Lc <+: (Cm.runLog H).2.take t := by
      rw [hsplit, List.take_append, List.take_of_length_le htc]
      exact List.prefix_append _ _
    rw [MerkleEnc.targets, Finset.mem_insert] at hvT
    rcases hvT with hvr | hvb
    · rw [hvr]
      by_cases hcl : c < Lp.length
      · have hpc : isRootAbs C rootOf r (Lp[c]'hcl) = true := List.findIdx_getElem
        have hra : rootAbs C rootOf (Lp[c]'hcl).1 = some r := by simpa [isRootAbs] using hpc
        have hLclen : Lc.length = c := by rw [hLc, List.length_take, min_eq_left hcl.le]
        have hLc_c : (Cm.runLog H).2[c]? = some (Lp[c]'hcl) := by
          rw [hLr, List.getElem?_append_left hcl, List.getElem?_eq_getElem hcl]
        rcases Nat.lt_or_ge c t with hlt | hge
        · have hmem : (Lp[c]'hcl).1 ∈ ((Cm.runLog H).2.take t).map Prod.fst := mem_take_of_getElem? hLc_c hlt
          refine mem_union_left _ (mem_union_left _ (mem_biUnion.mpr ⟨_, List.mem_toFinset.mpr hmem, ?_⟩))
          refine mem_union_right _ ?_
          rw [hra]
          simp
        · have htc' : t = c := le_antisymm hge (hLclen ▸ htc)
          rw [htc'] at ht
          have hee : e = Lp[c]'hcl := Option.some.inj (ht.symm.trans hLc_c)
          refine mem_union_left _ (mem_union_right _ ?_)
          rw [← he, hee, hra]
          simp
      · have hcl' : c = Lp.length := le_antisymm List.findIdx_le_length (not_lt.mp hcl)
        have hLcLp : Lc = Lp := by rw [hLc, hcl', List.take_length]
        have htLp : Lp.length ≤ t := hLcLp ▸ htc
        have hrep : Pv.replay ((Cm.runLog H).2.take t) = some (Pv.run H, Lp.length) := by
          rw [hLr, List.take_append, List.take_of_length_le htLp]
          exact OC.replay_runLog_append H Pv _
        refine mem_union_right _ ?_
        rw [hrep]
        simp [hr, ho]
    · obtain ⟨y', hy', hvy'⟩ := mem_biUnion.mp hvb
      have hy'P : y' ∈ ((Cm.runLog H).2.take t).map Prod.fst := by
        obtain ⟨e', he', rfl⟩ := List.mem_map.mp (List.mem_toFinset.mp hy')
        exact List.mem_map_of_mem (hpre.subset he')
      exact mem_union_left _ (mem_union_left _ (mem_biUnion.mpr ⟨y', List.mem_toFinset.mpr hy'P,
        mem_union_left _ hvy'⟩))

/-- **One opening under Fiat–Shamir, with the matrix extracted from the prover's log (round-by-round knowledge
soundness).** A prover making at most `q` hash queries makes the chain verifier accept while some claim is false of
the message decoded from the extracted matrix with probability at most `T·ε + collBound T D + collBound (T + 1) D +
collBound T' D + 2T'²/|D|`, `ε = max(A/|E|·βLR, col·βJ)`. -/
theorem fs_opening_knowledge (M : MerkleEnc Q D S Col) (colVal : Col → κ → E) (c₀ : Col)
    (enc : (μ → E) →ₗ[E] (Fin (2 ^ h) → E)) (henc : Function.Injective enc) {d e A : ℕ}
    (hd : MinDist (LinearMap.range enc) d) (h2 : 2 * e < d) (hA : e + 1 ≤ A)
    (hca : CAOn Unit (LinearMap.range enc) e A) (C : ChainEnc (PItem X (OMsg G μ E)) Q D)
    (clOf : X → OClaims Cl G κ μ E) (rootOf : X → D) (d₀ : D) (m₀ : OMsg G μ E) {w0 w1 : ℕ} (h0 : 0 < w0)
    (h1 : 0 < w1) {nQ : ℕ} (chalLR : (Fin w0 → D) → (Cl → E) × (κ → E))
    (chalJ : (Fin w1 → D) → (Fin nQ → Fin (2 ^ h))) (βLR βJ : ℝ≥0∞)
    (hLR : ∀ Ev : (Cl → E) × (κ → E) → Prop, (PMF.uniformOfFintype (Fin w0 → D)).toOuterMeasure {b | Ev (chalLR b)}
      ≤ (PMF.uniformOfFintype ((Cl → E) × (κ → E))).toOuterMeasure {y | Ev y} * βLR)
    (hJ : ∀ Ev : (Fin nQ → Fin (2 ^ h)) → Prop, (PMF.uniformOfFintype (Fin w1 → D)).toOuterMeasure {b | Ev (chalJ b)}
      ≤ (PMF.uniformOfFintype (Fin nQ → Fin (2 ^ h))).toOuterMeasure {J | Ev J} * βJ)
    (q : ℕ) (Pv : OC Q D (X × List (OMsg G μ E) × (Fin nQ → MerkleOpening D S Col))) (hPv : Pv.Bounded q) :
    prH (fun H => opAccepts M colVal enc clOf rootOf d₀ m₀ h0 h1 chalLR chalJ C H (Pv.run H).1 (Pv.run H).2.1
          (Pv.run H).2.2
        ∧ ¬ GroupsGood enc e (extractU M colVal c₀ (cutLog C rootOf (rootOf (Pv.run H).1) (Pv.runLog H).2) h
            (rootOf (Pv.run H).1)) (clOf (Pv.run H).1).rw (clOf (Pv.run H).1).cw (clOf (Pv.run H).1).grp
            (clOf (Pv.run H).1).val)
      ≤ ((q + ℓW 2 (opW w0 w1) + 1 : ℕ) : ℝ≥0∞)
          * max ((A : ℝ≥0∞) / Fintype.card E * βLR)
            ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ)
        + collBound (q + ℓW 2 (opW w0 w1) + 1) D + collBound (q + ℓW 2 (opW w0 w1) + 1 + 1) D
        + (collBound (q + (ℓW 2 (opW w0 w1) + 1) + nQ * (h + 2)) D
          + ((2 * (q + (ℓW 2 (opW w0 w1) + 1) + nQ * (h + 2)) * (q + (ℓW 2 (opW w0 w1) + 1) + nQ * (h + 2)) : ℕ)
            : ℝ≥0∞) / Fintype.card D) := by
  classical
  let St : List (Q × D) → X → List (OMsg G μ E × List D) → Prop := fun P x τ =>
    opSt enc e clOf d₀ w0 w1 chalLR chalJ (xtU M colVal c₀ h C rootOf Pv P x) x τ
  have hR : ∀ P, RbrWide 2 (opW w0 w1) (St P)
      (max ((A : ℝ≥0∞) / Fintype.card E * βLR)
        ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ)) :=
    fun P => opening_rbrWide enc henc hd h2 hA hca clOf d₀ w0 w1 chalLR chalJ βLR βJ hLR hJ
      (fun x => xtU M colVal c₀ h C rootOf Pv P x)
  have hstab : ∀ (H : Q → D) (P P' : List (Q × D)) (x : X) (τ : List (OMsg G μ E × List D)),
      C.start ∈ P.map Prod.fst → C.link (H C.start) (PItem.stmt x) ∈ P.map Prod.fst → P <+: P' →
        (∀ e ∈ P', e.2 = H e.1) → (St P x τ ↔ St P' x τ) := by
    intro H P P' x τ _ hl hpre _
    have hcut := cut_proverLog_stable Pv C rootOf (rootOf x) P P' hpre (by
      obtain ⟨e', he', he'1⟩ := List.mem_map.mp hl
      exact ⟨e', he', by rw [he'1]; exact rootAbs_link C rootOf _ x⟩)
    simp only [St, xtU, hcut]
  have hflip := fs_chain_wide_flip (hasMsg := opMsg) (m₀ := m₀) (opW_pos h0 h1) C St _ hR hstab q Pv hPv
  have hext := opening_extract_fail (h := h) M C rootOf d₀ m₀ h0 h1 chalJ q Pv hPv
  refine le_trans (MeasureTheory.measure_mono ?_) ((MeasureTheory.measure_union_le _ _).trans
    (add_le_add hflip hext))
  rintro H ⟨⟨hlen, ptr, hdec, hfin⟩, hng⟩
  unfold opFinal at hfin
  split at hfin
  · rename_i u ds mv ds'
    set x := (Pv.run H).1 with hx
    set r := rootOf x with hr
    set Lc := cutLog C rootOf r (Pv.runLog H).2 with hLc
    by_cases hall : ∀ k, M.extractCol Lc h (chalJ (vecOf d₀ w1 ds') k) r = some ((Pv.run H).2.2 k).col
    · left
      have hxt : xtU M colVal c₀ h C rootOf Pv ((C.stepRun (pSteps 2 (opW w0 w1) (opW_pos h0 h1))
          (fun o => pHeadsW 2 (opW w0 w1) opMsg o.1 o.2.1) Pv).runLog H).2 x
          = extractU M colVal c₀ Lc h r := by
        unfold xtU
        rw [ChainEnc.stepRun, OC.runLog_bind, proverLog_runLog]
      refine ⟨?_, [(u, ds), (mv, ds')], none, hdec, ?_⟩
      · show ¬ opSt enc e clOf d₀ w0 w1 chalLR chalJ _ x []
        rw [hxt]
        exact hng
      · show opSt enc e clOf d₀ w0 w1 chalLR chalJ _ x [(u, ds), (mv, ds')]
        rw [hxt]
        have hU : ∀ k i, extractU M colVal c₀ Lc h r i (chalJ (vecOf d₀ w1 ds') k)
            = colVal ((Pv.run H).2.2 k).col i := by
          intro k i
          show colVal ((M.extractCol Lc h (chalJ (vecOf d₀ w1 ds') k) r).getD c₀) i = _
          rw [hall k]
          rfl
        refine ⟨hfin.1, fun g hg k => ?_, fun k => ?_⟩
        · rw [comb_apply]
          refine ((hfin.2 k).2.1 g hg).trans (sum_congr rfl (fun i _ => ?_))
          rw [hU k i]
        · rw [comb_apply]
          refine (hfin.2 k).2.2.trans (sum_congr rfl (fun i _ => ?_))
          rw [hU k i]
    · right
      push Not at hall
      obtain ⟨k, hk⟩ := hall
      exact ⟨u, ds, mv, ds', hdec, k, (hfin.2 k).1, hk⟩
  · exact absurd hfin id

end Knowledge

/-! ## The code's derivations -/

section Code

variable {E κ Cl : Type} [Field E] [Fintype E] [Nonempty E] [DecidableEq E] [Fintype κ] [DecidableEq κ] [Fintype Cl]
  [DecidableEq Cl]

/-- Repack a vector of `w0` field elements as `(λ, ρ)` in the code's draw order. -/
def lrEquiv {w0 : ℕ} (eLR : Fin w0 ≃ Cl ⊕ κ) : (Fin w0 → E) ≃ (Cl → E) × (κ → E) :=
  (Equiv.arrowCongr eLR (Equiv.refl E)).trans (Equiv.sumArrowEquivProdArrow Cl κ E)

/-- **The code's `(λ, ρ)`**: each squeeze read by `challenge_fp2`, in the draw order `eLR`. -/
def lrCode (p : ℕ) (eF : ZMod p × ZMod p ≃ E) {w0 : ℕ} (eLR : Fin w0 ≃ Cl ⊕ κ) (b : Fin w0 → Dg) :
    (Cl → E) × (κ → E) :=
  (fun c => fp2Field p (2 ^ 128) eF (b (eLR.symm (.inl c))), fun i => fp2Field p (2 ^ 128) eF (b (eLR.symm (.inr i))))

omit [Field E] in
/-- The code's `(λ, ρ)` has the uniform probability times `(1 + p/2^128)^(2·w0)`. -/
theorem lrCode_prob_le (p : ℕ) [NeZero p] (eF : ZMod p × ZMod p ≃ E) {w0 : ℕ} (eLR : Fin w0 ≃ Cl ⊕ κ)
    (S : (Cl → E) × (κ → E) → Prop) :
    (PMF.uniformOfFintype (Fin w0 → Dg)).toOuterMeasure {b | S (lrCode p eF eLR b)}
      ≤ (PMF.uniformOfFintype ((Cl → E) × (κ → E))).toOuterMeasure {y | S y}
        * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0) := by
  calc (PMF.uniformOfFintype (Fin w0 → Dg)).toOuterMeasure {b | S (lrCode p eF eLR b)}
      = (PMF.uniformOfFintype (Fin w0 → Dg)).toOuterMeasure
          {b | (fun c => S (lrEquiv eLR c)) (fun j => fp2Field p (2 ^ 128) eF (b j))} := rfl
    _ ≤ (PMF.uniformOfFintype (Fin w0 → E)).toOuterMeasure {c | S (lrEquiv eLR c)}
          * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0) :=
        prob_fp2_vec_le p eF w0 (fun c => S (lrEquiv eLR c))
    _ = _ := by rw [prob_equiv_comp (lrEquiv eLR) S]

end Code

section Indices

/-- The first `k` coordinates of a uniform vector are uniform. -/
theorem prob_restrict_eq {C : Type} [Fintype C] [Nonempty C] {k M : ℕ} (hle : k ≤ M) (T : (Fin k → C) → Prop) :
    (PMF.uniformOfFintype (Fin M → C)).toOuterMeasure {c | T (fun j => c (Fin.castLE hle j))}
      = (PMF.uniformOfFintype (Fin k → C)).toOuterMeasure {c | T c} := by
  have hM : M = k + (M - k) := by omega
  let eSplit : (Fin M → C) ≃ (Fin k → C) × (Fin (M - k) → C) :=
    (Equiv.arrowCongr (finCongr hM) (Equiv.refl C)).trans
      ((Equiv.arrowCongr finSumFinEquiv.symm (Equiv.refl C)).trans (Equiv.sumArrowEquivProdArrow _ _ _))
  have hfst : ∀ c : Fin M → C, (eSplit c).1 = fun j => c (Fin.castLE hle j) := by
    intro c
    funext j
    simp only [eSplit, Equiv.trans_apply, Equiv.arrowCongr_apply, Equiv.sumArrowEquivProdArrow_apply_fst,
      Function.comp_apply, Equiv.symm_symm, finSumFinEquiv_apply_left, Equiv.refl_apply]
    congr 1
  calc (PMF.uniformOfFintype (Fin M → C)).toOuterMeasure {c | T (fun j => c (Fin.castLE hle j))}
      = (PMF.uniformOfFintype (Fin M → C)).toOuterMeasure {c | (fun p : (Fin k → C) × (Fin (M - k) → C) => T p.1)
          (eSplit c)} := by
        congr 1
    _ = (PMF.uniformOfFintype ((Fin k → C) × (Fin (M - k) → C))).toOuterMeasure {p | T p.1} :=
        prob_equiv_comp eSplit (fun p => T p.1)
    _ = _ := Hiding.prob_fst {c | T c}

/-- **The four 8-byte chunks of a 32-byte digest** `(lo, hi)`: `lo mod 2^64`, `lo / 2^64`, `hi mod 2^64`, `hi / 2^64`
(bytes 0–7, 8–15, 16–23, 24–31, little-endian), a bijection. -/
def chunkEquiv : Dg ≃ (Fin 4 → Fin (2 ^ 64)) :=
  ((Equiv.prodCongr (finCongr (show 2 ^ 128 = 2 ^ 64 * 2 ^ 64 by norm_num))
      (finCongr (show 2 ^ 128 = 2 ^ 64 * 2 ^ 64 by norm_num))).trans
    (Equiv.prodCongr finProdFinEquiv.symm finProdFinEquiv.symm)).trans
  { toFun := fun v => ![v.1.2, v.1.1, v.2.2, v.2.1]
    invFun := fun c => ((c 1, c 0), (c 3, c 2))
    left_inv := fun v => by simp
    right_inv := fun c => by
      funext j
      fin_cases j <;> rfl }

/-- The chunks are the code's `u64::from_le_bytes` of the digest's 8-byte pieces. -/
theorem chunkEquiv_spec (v : Dg) :
    ((chunkEquiv v 0 : ℕ) = (v.1 : ℕ) % 2 ^ 64) ∧ ((chunkEquiv v 1 : ℕ) = (v.1 : ℕ) / 2 ^ 64)
      ∧ ((chunkEquiv v 2 : ℕ) = (v.2 : ℕ) % 2 ^ 64) ∧ ((chunkEquiv v 3 : ℕ) = (v.2 : ℕ) / 2 ^ 64) := by
  refine ⟨rfl, rfl, rfl, rfl⟩

/-- **The code's `challenge_indices(Q, 2^h)`**: index `k` is chunk `k mod 4` of squeeze `⌊k/4⌋`, masked by `2^h − 1`
(`idxChal`). -/
def idxCode (h : ℕ) {m nQ : ℕ} (hnQ : nQ ≤ m * 4) (b : Fin m → Dg) : Fin nQ → Fin (2 ^ h) :=
  fun k => idxChal h (chunkEquiv (b (Fin.castLE hnQ k).divNat) (Fin.castLE hnQ k).modNat)

/-- Index `k`, as a number. -/
theorem idxCode_spec (h : ℕ) {m nQ : ℕ} (hnQ : nQ ≤ m * 4) (b : Fin m → Dg) (k : Fin nQ) :
    ((idxCode h hnQ b k : ℕ) = (chunkEquiv (b ⟨k / 4, by have := k.isLt; omega⟩) ⟨k % 4, by omega⟩ : ℕ) % 2 ^ h) := by
  rw [idxCode, idxChal_eq]
  rfl

/-- **The code's indices are exactly uniform** (for `h ≤ 64`): bias `1`. -/
theorem idxCode_prob_le {h : ℕ} (hh : h ≤ 64) {m nQ : ℕ} (hnQ : nQ ≤ m * 4) (S : (Fin nQ → Fin (2 ^ h)) → Prop) :
    (PMF.uniformOfFintype (Fin m → Dg)).toOuterMeasure {b | S (idxCode h hnQ b)}
      ≤ (PMF.uniformOfFintype (Fin nQ → Fin (2 ^ h))).toOuterMeasure {J | S J} * 1 := by
  classical
  let allChunks : (Fin m → Dg) ≃ (Fin (m * 4) → Fin (2 ^ 64)) :=
    ((Equiv.arrowCongr (Equiv.refl (Fin m)) chunkEquiv).trans (Equiv.curry (Fin m) (Fin 4) (Fin (2 ^ 64))).symm).trans
      (Equiv.arrowCongr finProdFinEquiv (Equiv.refl _))
  have hall : ∀ b, idxCode h hnQ b = fun k => idxChal h (allChunks b (Fin.castLE hnQ k)) := by
    intro b
    funext k
    rfl
  calc (PMF.uniformOfFintype (Fin m → Dg)).toOuterMeasure {b | S (idxCode h hnQ b)}
      = (PMF.uniformOfFintype (Fin m → Dg)).toOuterMeasure
          {b | (fun c : Fin (m * 4) → Fin (2 ^ 64) => S (fun k => idxChal h (c (Fin.castLE hnQ k))))
            (allChunks b)} := by
        congr 1
    _ = (PMF.uniformOfFintype (Fin (m * 4) → Fin (2 ^ 64))).toOuterMeasure
          {c | S (fun k => idxChal h (c (Fin.castLE hnQ k)))} :=
        prob_equiv_comp allChunks (fun c => S (fun k => idxChal h (c (Fin.castLE hnQ k))))
    _ = (PMF.uniformOfFintype (Fin nQ → Fin (2 ^ 64))).toOuterMeasure {c | S (fun k => idxChal h (c k))} :=
        prob_restrict_eq hnQ (fun c => S (fun k => idxChal h (c k)))
    _ ≤ (PMF.uniformOfFintype (Fin nQ → Fin (2 ^ h))).toOuterMeasure {J | S J}
          * biasFactor (2 ^ 64 / 2 ^ h) (Fin (2 ^ h)) (Fin (2 ^ 64)) ^ nQ :=
        prob_vec_comap_le (idxChal h) (2 ^ 64 / 2 ^ h) (card_idxChal_fiber_le hh) nQ S
    _ = _ := by rw [biasFactor_idx_eq_one hh, one_pow]

end Indices

section CodeOpening

variable {F κ μ G Cl : Type} [Field F] [Fintype F] [DecidableEq F]
  [Fintype κ] [DecidableEq κ] [Fintype μ] [Fintype Cl] [DecidableEq Cl] [DecidableEq G]
variable {X Q S Col : Type} [Fintype Q] [DecidableEq Q]
variable {h : ℕ}

/-- **One opening under Fiat–Shamir with the code's derivations**: `ε = max(A/|E| · (1 + p/2^128)^(2·w0), ((N − (e +
1))/N)^Q)`. -/
theorem fs_opening_knowledge_code (p : ℕ) [NeZero p] (eF : ZMod p × ZMod p ≃ F) (hh : h ≤ 64)
    (M : MerkleEnc Q Dg S Col) (colVal : Col → κ → F) (c₀ : Col)
    (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (henc : Function.Injective enc) {d e A : ℕ}
    (hd : MinDist (LinearMap.range enc) d) (h2 : 2 * e < d) (hA : e + 1 ≤ A)
    (hca : CAOn Unit (LinearMap.range enc) e A) (C : ChainEnc (PItem X (OMsg G μ F)) Q Dg)
    (clOf : X → OClaims Cl G κ μ F) (rootOf : X → Dg) (d₀ : Dg) (m₀ : OMsg G μ F) {w0 m : ℕ} (h0 : 0 < w0)
    (hm : 0 < m) {nQ : ℕ} (hnQ : nQ ≤ m * 4) (eLR : Fin w0 ≃ Cl ⊕ κ)
    (q : ℕ) (Pv : OC Q Dg (X × List (OMsg G μ F) × (Fin nQ → MerkleOpening Dg S Col))) (hPv : Pv.Bounded q) :
    prH (fun H => opAccepts M colVal enc clOf rootOf d₀ m₀ h0 hm (lrCode p eF eLR) (idxCode h hnQ) C H
          (Pv.run H).1 (Pv.run H).2.1 (Pv.run H).2.2
        ∧ ¬ GroupsGood enc e (extractU M colVal c₀ (cutLog C rootOf (rootOf (Pv.run H).1) (Pv.runLog H).2) h
            (rootOf (Pv.run H).1)) (clOf (Pv.run H).1).rw (clOf (Pv.run H).1).cw (clOf (Pv.run H).1).grp
            (clOf (Pv.run H).1).val)
      ≤ ((q + ℓW 2 (opW w0 m) + 1 : ℕ) : ℝ≥0∞)
          * max ((A : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0))
            ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * 1)
        + collBound (q + ℓW 2 (opW w0 m) + 1) Dg + collBound (q + ℓW 2 (opW w0 m) + 1 + 1) Dg
        + (collBound (q + (ℓW 2 (opW w0 m) + 1) + nQ * (h + 2)) Dg
          + ((2 * (q + (ℓW 2 (opW w0 m) + 1) + nQ * (h + 2)) * (q + (ℓW 2 (opW w0 m) + 1) + nQ * (h + 2)) : ℕ)
            : ℝ≥0∞) / Fintype.card Dg) := by
  have : Nonempty F := ⟨eF 0⟩
  exact fs_opening_knowledge M colVal c₀ enc henc hd h2 hA hca C clOf rootOf d₀ m₀ h0 hm (lrCode p eF eLR)
    (idxCode h hnQ) _ 1 (lrCode_prob_le p eF eLR) (idxCode_prob_le hh hnQ) q Pv hPv

end CodeOpening

end ZK60.Sound
