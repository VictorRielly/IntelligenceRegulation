/-
D63, step L4 (zero knowledge): the salted Merkle layer in the random-oracle model.

What the code computes (`zkp-core/src/pcs.rs` `commit_zk_owned_with` / `salt_leaf_keyed`, `zkp-core/src/merkle.rs`
`MerkleTree::build_keyed`; the same in `hashline/src/zk.rs` `mask_commit_tagged` for `M`):
* every column `j` of a hiding commitment gets 32 fresh random salt bytes `σ_j` (`rng.bytes32()`);
* its leaf is `leaf_j = H_leaf(H_col(column_j) ‖ σ_j)`; the tree hashes consecutive pairs with `H_node` up to the root
  (`MerkleTree::build`: `pair[0], pair[1]`);
* an opening reveals the root and, for each sampled column, the column, its salt and its authentication path.

Model (`Statements.lean`'s): the hash is ONE uniformly random function `H : Q → D` on a finite query space; the
adversary is a deterministic oracle computation `OC Q D _` making at most `q` queries on every path. The salted leaf
query is `enc(x_j, σ_j)` for an injective encoding `enc` of (leaf content, salt); `x_j` is the leaf content (the
column digest `H_col(column_j)`, which may itself be an oracle answer). The hypothesis `hx` asks that the contents
depend on `H` only OUTSIDE the salted-leaf query points: the column hash and the leaf hash are domain-separated. The
tagged profiles meet it (keyed BLAKE3, distinct column, leaf and node keys: D19 ruling T-1). The legacy untagged rule
meets it too unless a column is exactly 64 bytes (8 base-field rows): then a column input and a salted-leaf input
(digest ‖ salt) are both 64-byte unkeyed BLAKE3 inputs. The node hash needs no separation at all: the adversary
recomputes the tree, so node queries are ordinary queries (under the legacy rule a salted leaf and a node ARE the same
call, and that is still covered).

What is proved, in two steps (the simplification the task allowed, stated precisely):
1. **One level of salted leaf hashing** (`saltedLeaves_real_ideal`, `saltedLeaves_hiding`). The adversary gets ALL
   the leaf digests (more than any root or path shows) and the salts of the opened leaves `O`, and makes at most `q`
   queries. Its acceptance probability changes by at most `n·(n + q)/|S|` when the unopened leaves are replaced by
   fresh uniform digests; hence two content vectors that agree on the opened leaves are told apart with advantage at
   most `2·n·(n + q)/|S|`.
2. **The tree** (`saltedLeaves_view_hiding`, `merkle_hiding`). Anything computed from the leaf digests by a `t`-query
   oracle computation costs `t` more queries. The whole tree over `2^h` leaves (every level, hence the root and every
   authentication path; `merkleLevels`) takes `2^h − 1` node queries (`merkleLevels_bounded`). So roots and paths of two
   leaf vectors that agree on the opened leaves are told apart with advantage at most
   `2·N·(N + 2^h − 1 + q)/|S|`, `N = 2^h`.

The bound. `|S| = 2^s` for `s`-bit salts (`s = 256` in the code). The factor `n` is the number of leaves a single
query can hit: a query `enc(a, b)` hits leaf `j` exactly when `x_j = a` and `σ_j = b`, so when every leaf holds the same
content one query hits with probability about `n/|S|`, and an adversary guessing salts for that content does
distinguish at that rate: the factor cannot be removed in general. With distinct contents a query hits with probability
at most `1/|S|`. The `n²` term is the chance that two salts collide (equal contents and equal salts give equal leaves,
which the ideal world does not have). For `N ≤ 2^16` columns and `s = 256` the advantage is at most
`q·2^-239 + 2^-222`, far inside the proposed `εzk q R = q·2^-128 + R·2^-120`.

NOT covered: Fiat–Shamir (here the opened set `O` is FIXED; in the code it is derived from the root), the joint law
with the opened columns themselves (the opening lemmas; this lemma is the step that hides the UNOPENED columns once
the opened ones are fixed), an 8-row commitment under the legacy rule (above), and composition over commitments and
receipts.
-/
import ZK60Formal.Statements
import ZK60Formal.HidingRows

namespace ZK60

/-! ## Oracle computations: the queries of a run, and sequential composition -/

namespace OC

variable {I O α β : Type}

/-- The questions a computation asks when run against `f`, in order (`runLog`'s log without the answers). -/
def queries (f : I → O) (A : OC I O α) : List I := (A.runLog f).2.map Prod.fst

/-- The questions of a run: the first question, then those of the continuation. -/
theorem queries_ask (f : I → O) (i : I) (k : O → OC I O α) :
    queries f (.ask i k) = i :: queries f (k (f i)) := by
  simp [queries, runLog]

/-- **Identical until bad.** Two oracles that agree on every question the run against the first one asks give the
same result. -/
theorem run_eq_of_agree {f g : I → O} (A : OC I O α) (h : ∀ y ∈ queries f A, f y = g y) :
    A.run f = A.run g := by
  induction A with
  | ret a => rfl
  | ask i k ih =>
    rw [queries_ask] at h
    have hi : f i = g i := h i (by simp)
    simp only [run]
    rw [ih (f i) (fun y hy => h y (by simp [hy])), hi]

/-- A computation bounded by `q` asks at most `q` questions on the path it takes. -/
theorem length_queries_le (f : I → O) (A : OC I O α) (q : ℕ) (hA : A.Bounded q) :
    (queries f A).length ≤ q := by
  induction A generalizing q with
  | ret a => simp [queries, runLog]
  | ask i k ih =>
    cases q with
    | zero => simp [Bounded] at hA
    | succ q =>
      rw [queries_ask, List.length_cons]
      simp only [Bounded] at hA
      exact Nat.succ_le_succ (ih (f i) q (hA (f i)))

/-- Sequential composition: run `A`, then `k` on its result. -/
def bind : OC I O α → (α → OC I O β) → OC I O β
  | .ret a, k => k a
  | .ask i c, k => .ask i (fun o => OC.bind (c o) k)

/-- Running a composition runs the first computation, then the second on its result. -/
theorem run_bind (f : I → O) (A : OC I O α) (k : α → OC I O β) :
    (A.bind k).run f = (k (A.run f)).run f := by
  induction A with
  | ret a => rfl
  | ask i c ih =>
    simp only [OC.bind, run]
    exact ih (f i)

/-- A query budget can always be raised. -/
theorem Bounded.mono {A : OC I O α} {q q' : ℕ} (hA : A.Bounded q) (hq : q ≤ q') : A.Bounded q' := by
  induction A generalizing q q' with
  | ret a => simp [Bounded]
  | ask i k ih =>
    cases q with
    | zero => simp [Bounded] at hA
    | succ q =>
      obtain ⟨r, rfl⟩ : ∃ r, q' = r + 1 := ⟨q' - 1, by omega⟩
      simp only [Bounded] at hA ⊢
      exact fun o => ih o (hA o) (by omega)

/-- The query budgets of a composition add up. -/
theorem Bounded.bind {A : OC I O α} {k : α → OC I O β} {t q : ℕ} (hA : A.Bounded t)
    (hk : ∀ a, (k a).Bounded q) : (A.bind k).Bounded (t + q) := by
  induction A generalizing t with
  | ret a =>
    show (k a).Bounded (t + q)
    exact (hk a).mono (by omega)
  | ask i c ih =>
    cases t with
    | zero => simp [Bounded] at hA
    | succ t =>
      simp only [Bounded] at hA
      rw [show t + 1 + q = (t + q) + 1 by omega]
      simp only [OC.bind, Bounded]
      exact fun o => ih o (hA o)

end OC

namespace Hiding

open scoped ENNReal

/-! ## Uniform laws on finite products -/

/-- Pushing the uniform law through an equivalence gives the uniform law of the target. -/
theorem map_uniform_equiv {α β : Type} [Fintype α] [Nonempty α] [Fintype β] [Nonempty β] (e : α ≃ β) :
    (PMF.uniformOfFintype α).map e = PMF.uniformOfFintype β := by
  ext b
  rw [PMF.map_apply, tsum_eq_single (e.symm b)]
  · simp [PMF.uniformOfFintype_apply, Fintype.card_congr e]
  · intro a ha
    have : b ≠ e a := fun h => ha (by rw [h, Equiv.symm_apply_apply])
    simp [this]

/-- The first marginal of the uniform law on a product is uniform. -/
theorem map_fst_uniform {α β : Type} [Fintype α] [Nonempty α] [Fintype β] [Nonempty β] :
    (PMF.uniformOfFintype (α × β)).map Prod.fst = PMF.uniformOfFintype α := by
  classical
  apply eq_uniformOfFintype_of_const
  have key : ∀ a : α, (PMF.uniformOfFintype (α × β)).map Prod.fst a
      = ∑ _b : β, (Fintype.card (α × β) : ℝ≥0∞)⁻¹ := by
    intro a
    rw [PMF.map_apply, tsum_fintype, Fintype.sum_prod_type, Finset.sum_eq_single a]
    · simp [PMF.uniformOfFintype_apply]
    · intro a' _ ha'
      simp [Ne.symm ha']
    · simp
  intro a a'
  rw [key, key]

/-- An event about the first coordinate has the same probability on the product. -/
theorem prob_fst {α β : Type} [Fintype α] [Nonempty α] [Fintype β] [Nonempty β] (E : Set α) :
    (PMF.uniformOfFintype (α × β)).toOuterMeasure (Prod.fst ⁻¹' E)
      = (PMF.uniformOfFintype α).toOuterMeasure E := by
  rw [← PMF.toOuterMeasure_map_apply, map_fst_uniform]

/-- A bijection of a finite type preserves the uniform probability of every event. -/
theorem prob_preimage_bijective {α : Type} [Fintype α] [Nonempty α] (Ψ : α → α) (hΨ : Function.Bijective Ψ)
    (E : Set α) :
    (PMF.uniformOfFintype α).toOuterMeasure (Ψ ⁻¹' E) = (PMF.uniformOfFintype α).toOuterMeasure E := by
  rw [← PMF.toOuterMeasure_map_apply, map_uniform_of_bijective Ψ hΨ]

/-- A uniform first coordinate lands in a set of at most `m` values chosen from the second coordinate with
probability at most `m / |S|`. -/
theorem prob_fst_mem_le {S β : Type} [Fintype S] [Nonempty S] [Fintype β] [Nonempty β]
    (T : β → Finset S) (m : ℕ) (hcard : ∀ b, (T b).card ≤ m) :
    (PMF.uniformOfFintype (S × β)).toOuterMeasure {p | p.1 ∈ T p.2} ≤ (m : ℝ≥0∞) / Fintype.card S := by
  classical
  rw [PMF.toOuterMeasure_apply, tsum_fintype, Fintype.sum_prod_type_right]
  set c : ℝ≥0∞ := (Fintype.card (S × β) : ℝ≥0∞)⁻¹ with hc
  have hinner : ∀ b : β, ∑ s : S, Set.indicator {p : S × β | p.1 ∈ T p.2} (PMF.uniformOfFintype (S × β)) (s, b)
      = (T b).card * c := by
    intro b
    simp only [Set.indicator_apply, Set.mem_ofPred_eq, PMF.uniformOfFintype_apply]
    rw [← Finset.sum_filter, Finset.sum_const, nsmul_eq_mul]
    have : Finset.univ.filter (fun s => s ∈ T b) = T b := by
      ext s
      simp
    rw [this]
  simp only [hinner]
  have hS0 : (Fintype.card S : ℝ≥0∞) ≠ 0 := by simp
  have hβ0 : (Fintype.card β : ℝ≥0∞) ≠ 0 := by simp
  have hβt : (Fintype.card β : ℝ≥0∞) ≠ ∞ := ENNReal.natCast_ne_top _
  have hSt : (Fintype.card S : ℝ≥0∞) ≠ ∞ := ENNReal.natCast_ne_top _
  calc ∑ b : β, ((T b).card : ℝ≥0∞) * c ≤ ∑ _b : β, (m : ℝ≥0∞) * c := by
        refine Finset.sum_le_sum (fun b _ => ?_)
        gcongr
        exact_mod_cast hcard b
    _ = (Fintype.card β : ℝ≥0∞) * ((m : ℝ≥0∞) * c) := by
        rw [Finset.sum_const, Finset.card_univ, nsmul_eq_mul]
    _ = (m : ℝ≥0∞) / Fintype.card S := by
        rw [hc, Fintype.card_prod, Nat.cast_mul, ENNReal.mul_inv (Or.inl hS0) (Or.inl hSt), div_eq_mul_inv]
        calc (Fintype.card β : ℝ≥0∞) * ((m : ℝ≥0∞) * ((Fintype.card S : ℝ≥0∞)⁻¹ * (Fintype.card β : ℝ≥0∞)⁻¹))
            = (m : ℝ≥0∞) * (Fintype.card S : ℝ≥0∞)⁻¹ * ((Fintype.card β : ℝ≥0∞) * (Fintype.card β : ℝ≥0∞)⁻¹) := by
              ring
          _ = (m : ℝ≥0∞) * (Fintype.card S : ℝ≥0∞)⁻¹ := by
              rw [ENNReal.mul_inv_cancel hβ0 hβt, mul_one]

/-! ## One salt coordinate -/

section Salt

variable {S : Type} [Fintype S] [Nonempty S] [DecidableEq S]

/-- Splitting off salt `j`: the salts become (salt `j`, the salts with `j` reset to `s₀`). -/
def saltSplit {α γ : Type} {n : ℕ} (j : Fin n) (s₀ : S) :
    (α × (Fin n → S)) × γ ≃ S × ((α × {σ : Fin n → S // σ j = s₀}) × γ) where
  toFun ω := (ω.1.2 j, ((ω.1.1, ⟨Function.update ω.1.2 j s₀, Function.update_self j s₀ ω.1.2⟩), ω.2))
  invFun := fun p : S × ((α × {σ : Fin n → S // σ j = s₀}) × γ) =>
    ((p.2.1.1, Function.update p.2.1.2.1 j p.1), p.2.2)
  left_inv := by
    rintro ⟨⟨a, σ⟩, c⟩
    simp [Function.update_idem, Function.update_eq_self]
  right_inv := by
    rintro ⟨s, ⟨a, ⟨τ, hτ⟩⟩, c⟩
    refine Prod.ext (by simp) (Prod.ext (Prod.ext rfl (Subtype.ext ?_)) rfl)
    show Function.update (Function.update τ j s) j s₀ = τ
    rw [Function.update_idem, ← hτ, Function.update_eq_self]

/-- **One uniform salt lands in a small set with probability at most its size over `|S|`.** If the set `T ω` has at
most `m` elements and does not depend on salt `j` (changing salt `j` leaves it unchanged), then salt `j` lies in it
with probability at most `m / |S|`. This is the only place a salt's entropy is used. -/
theorem prob_salt_mem_le {α γ : Type} [Fintype α] [Nonempty α] [Fintype γ] [Nonempty γ] {n : ℕ}
    (j : Fin n) (m : ℕ) (T : (α × (Fin n → S)) × γ → Finset S)
    (hT : ∀ a σ c s, T ((a, Function.update σ j s), c) = T ((a, σ), c))
    (hcard : ∀ ω, (T ω).card ≤ m) :
    (PMF.uniformOfFintype ((α × (Fin n → S)) × γ)).toOuterMeasure {ω | ω.1.2 j ∈ T ω}
      ≤ (m : ℝ≥0∞) / Fintype.card S := by
  classical
  obtain ⟨s₀⟩ := ‹Nonempty S›
  have : Nonempty {σ : Fin n → S // σ j = s₀} := ⟨⟨fun _ => s₀, rfl⟩⟩
  have hmap := map_uniform_equiv (saltSplit (α := α) (γ := γ) j s₀).symm
  rw [← hmap, PMF.toOuterMeasure_map_apply]
  have hset : (saltSplit (α := α) (γ := γ) j s₀).symm ⁻¹' {ω | ω.1.2 j ∈ T ω}
      = {p | p.1 ∈ T ((p.2.1.1, p.2.1.2.1), p.2.2)} := by
    ext ⟨s, ⟨a, ⟨τ, hτ⟩⟩, c⟩
    simp only [Set.mem_preimage, Set.mem_ofPred_eq]
    show (Function.update τ j s) j ∈ T ((a, Function.update τ j s), c) ↔ s ∈ T ((a, τ), c)
    rw [Function.update_self, hT]
  rw [hset]
  exact prob_fst_mem_le (fun b : (α × {σ : Fin n → S // σ j = s₀}) × γ => T ((b.1.1, b.1.2.1), b.2)) m
    (fun _ => hcard _)

end Salt

/-! ## One level of salted leaf hashing -/

section SaltedLeaves

variable {Q D X S : Type} {n : ℕ}

/-- The salted leaf digests: `leaf_j = H(enc(x_j, σ_j))` (`salt_leaf_keyed(H_col(column_j), σ_j)`). -/
def saltedLeaves (enc : X → S → Q) (H : Q → D) (x : Fin n → X) (σ : Fin n → S) : Fin n → D :=
  fun j => H (enc (x j) (σ j))

/-- The salts an opening reveals: those of the opened leaves `O`. -/
def revealSalts (O : Finset (Fin n)) (σ : Fin n → S) : Fin n → Option S :=
  fun j => if j ∈ O then some (σ j) else none

/-- The ideal leaves: the opened ones as in the real world, the unopened ones replaced by fresh uniform digests `L`. -/
def idealLeaves (enc : X → S → Q) (O : Finset (Fin n)) (H : Q → D) (x : Fin n → X) (σ : Fin n → S)
    (L : Fin n → D) : Fin n → D :=
  fun j => if j ∈ O then H (enc (x j) (σ j)) else L j

/-- The real world: a uniform oracle and uniform salts; the adversary gets every leaf digest and the opened salts,
asks the oracle, and outputs a bit. -/
noncomputable def leafReal [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [Fintype S] [Nonempty S]
    (enc : X → S → Q) (O : Finset (Fin n)) (x : (Q → D) → Fin n → X)
    (A : (Fin n → D) → (Fin n → Option S) → OC Q D Bool) : ℝ≥0∞ :=
  (PMF.uniformOfFintype ((Q → D) × (Fin n → S))).toOuterMeasure
    {p | (A (saltedLeaves enc p.1 (x p.1) p.2) (revealSalts O p.2)).run p.1 = true}

/-- The ideal world: the unopened leaves are fresh uniform digests, independent of everything. It depends on the
contents only through the opened ones. -/
noncomputable def leafIdeal [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [Fintype S] [Nonempty S]
    (enc : X → S → Q) (O : Finset (Fin n)) (x : (Q → D) → Fin n → X)
    (A : (Fin n → D) → (Fin n → Option S) → OC Q D Bool) : ℝ≥0∞ :=
  (PMF.uniformOfFintype (((Q → D) × (Fin n → S)) × (Fin n → D))).toOuterMeasure
    {ω | (A (idealLeaves enc O ω.1.1 (x ω.1.1) ω.1.2 ω.2) (revealSalts O ω.1.2)).run ω.1.1 = true}

/-- The bound `n · (n + q) / |S|`. -/
noncomputable def leafBound (n q : ℕ) (S : Type) [Fintype S] : ℝ≥0∞ :=
  ((n * (n + q) : ℕ) : ℝ≥0∞) / Fintype.card S

/-! ### The coupling: reprogram the oracle at the unopened salted points -/

/-- The salted query points. -/
def leafPts (enc : X → S → Q) (x : (Q → D) → Fin n → X) (H : Q → D) (σ : Fin n → S) : Fin n → Q :=
  fun j => enc (x H j) (σ j)

/-- No unopened point coincides with any other point. -/
def LeafGood (O : Finset (Fin n)) (P : Fin n → Q) : Prop := ∀ j, j ∉ O → ∀ k, k ≠ j → P j ≠ P k

open Classical in
/-- The oracle `H` reprogrammed to answer `L j` at every unopened point `P j`. -/
noncomputable def reprog (O : Finset (Fin n)) (P : Fin n → Q) (H : Q → D) (L : Fin n → D) : Q → D :=
  fun y => if h : ∃ j, j ∉ O ∧ P j = y then L h.choose else H y

/-- At an unopened salted point the reprogrammed oracle answers the fresh digest `L j`. -/
theorem reprog_unopened {O : Finset (Fin n)} {P : Fin n → Q} (hG : LeafGood O P) (H : Q → D) (L : Fin n → D)
    (j : Fin n) (hj : j ∉ O) : reprog O P H L (P j) = L j := by
  have h : ∃ j', j' ∉ O ∧ P j' = P j := ⟨j, hj, rfl⟩
  simp only [reprog]
  rw [dite_eq_left h]
  obtain ⟨h1, h2⟩ := h.choose_spec
  have hc : h.choose = j := by
    by_contra hne
    exact hG h.choose h1 j (fun he => hne he.symm) h2
  exact congrArg L hc

/-- Away from the unopened salted points the reprogrammed oracle is the original one. -/
theorem reprog_off {O : Finset (Fin n)} {P : Fin n → Q} (H : Q → D) (L : Fin n → D) (y : Q)
    (hy : ∀ j, j ∉ O → P j ≠ y) : reprog O P H L y = H y := by
  simp only [reprog]
  refine dite_eq_right ?_
  rintro ⟨j, hj, he⟩
  exact hy j hj he

/-- At an opened salted point the reprogrammed oracle is the original one (no collision). -/
theorem reprog_opened {O : Finset (Fin n)} {P : Fin n → Q} (hG : LeafGood O P) (H : Q → D) (L : Fin n → D)
    (k : Fin n) (hk : k ∈ O) : reprog O P H L (P k) = H (P k) := by
  refine reprog_off H L (P k) (fun j hj => hG j hj k ?_)
  rintro rfl
  exact hj hk

/-- The contents do not move when the oracle is reprogrammed at salted points. -/
theorem x_reprog (enc : X → S → Q) (x : (Q → D) → Fin n → X)
    (hx : ∀ H H' : Q → D, (∀ y, (∀ a b, enc a b ≠ y) → H y = H' y) → x H = x H')
    (O : Finset (Fin n)) (H : Q → D) (σ : Fin n → S) (L : Fin n → D) :
    x (reprog O (leafPts enc x H σ) H L) = x H :=
  hx _ _ (fun y hy => reprog_off H L y (fun _ _ he => hy _ _ he))

open Classical in
/-- The coupling: when the salted points are good, swap the oracle's answers at the unopened points with the fresh
digests `L`. -/
noncomputable def leafSwap (enc : X → S → Q) (O : Finset (Fin n)) (x : (Q → D) → Fin n → X)
    (ω : ((Q → D) × (Fin n → S)) × (Fin n → D)) : ((Q → D) × (Fin n → S)) × (Fin n → D) :=
  if LeafGood O (leafPts enc x ω.1.1 ω.1.2) then
    ((reprog O (leafPts enc x ω.1.1 ω.1.2) ω.1.1 ω.2, ω.1.2),
      fun j => if j ∈ O then ω.2 j else ω.1.1 (leafPts enc x ω.1.1 ω.1.2 j))
  else ω

/-- The coupling, unfolded at good coins. -/
theorem leafSwap_good (enc : X → S → Q) (O : Finset (Fin n)) (x : (Q → D) → Fin n → X) (H : Q → D)
    (σ : Fin n → S) (L : Fin n → D) (hG : LeafGood O (leafPts enc x H σ)) :
    leafSwap enc O x ((H, σ), L)
      = ((reprog O (leafPts enc x H σ) H L, σ), fun j => if j ∈ O then L j else H (leafPts enc x H σ j)) := by
  simp only [leafSwap]
  exact ite_eq_left hG

/-- **The coupling is an involution**, hence a bijection of the coins: it preserves the uniform law. -/
theorem leafSwap_involutive (enc : X → S → Q) (O : Finset (Fin n)) (x : (Q → D) → Fin n → X)
    (hx : ∀ H H' : Q → D, (∀ y, (∀ a b, enc a b ≠ y) → H y = H' y) → x H = x H') :
    Function.Involutive (leafSwap enc O x) := by
  rintro ⟨⟨H, σ⟩, L⟩
  by_cases hG : LeafGood O (leafPts enc x H σ)
  · have hP' : leafPts enc x (reprog O (leafPts enc x H σ) H L) σ = leafPts enc x H σ := by
      funext j
      simp only [leafPts]
      rw [x_reprog enc x hx O H σ L]
    have hG' : LeafGood O (leafPts enc x (reprog O (leafPts enc x H σ) H L) σ) := by rw [hP']; exact hG
    rw [leafSwap_good enc O x H σ L hG, leafSwap_good enc O x _ σ _ hG', hP']
    refine Prod.ext (Prod.ext ?_ rfl) ?_
    · funext y
      dsimp only
      by_cases hy : ∃ j, j ∉ O ∧ leafPts enc x H σ j = y
      · obtain ⟨j, hj, rfl⟩ := hy
        rw [reprog_unopened hG _ _ j hj]
        simp [hj]
      · push Not at hy
        rw [reprog_off _ _ y hy, reprog_off _ _ y hy]
    · funext j
      dsimp only
      by_cases hj : j ∈ O
      · simp [hj]
      · simp only [hj, ite_false]
        exact reprog_unopened hG H L j hj
  · have h1 : leafSwap enc O x ((H, σ), L) = ((H, σ), L) := by
      simp only [leafSwap]
      exact ite_eq_right hG
    rw [h1, h1]

/-! ### The events -/

/-- The real event on the extended coins (the fresh digests are unused). -/
def realEv (enc : X → S → Q) (O : Finset (Fin n)) (x : (Q → D) → Fin n → X)
    (A : (Fin n → D) → (Fin n → Option S) → OC Q D Bool) (ω : ((Q → D) × (Fin n → S)) × (Fin n → D)) : Prop :=
  (A (saltedLeaves enc ω.1.1 (x ω.1.1) ω.1.2) (revealSalts O ω.1.2)).run ω.1.1 = true

/-- The ideal event. -/
def idealEv (enc : X → S → Q) (O : Finset (Fin n)) (x : (Q → D) → Fin n → X)
    (A : (Fin n → D) → (Fin n → Option S) → OC Q D Bool) (ω : ((Q → D) × (Fin n → S)) × (Fin n → D)) : Prop :=
  (A (idealLeaves enc O ω.1.1 (x ω.1.1) ω.1.2 ω.2) (revealSalts O ω.1.2)).run ω.1.1 = true

/-- The questions of the ideal run. -/
def idealQs (enc : X → S → Q) (O : Finset (Fin n)) (x : (Q → D) → Fin n → X)
    (A : (Fin n → D) → (Fin n → Option S) → OC Q D Bool) (ω : ((Q → D) × (Fin n → S)) × (Fin n → D)) : List Q :=
  OC.queries ω.1.1 (A (idealLeaves enc O ω.1.1 (x ω.1.1) ω.1.2 ω.2) (revealSalts O ω.1.2))

/-- The bad event: two salted points collide at an unopened leaf, or the ideal run asks an unopened salted point. -/
def badEv (enc : X → S → Q) (O : Finset (Fin n)) (x : (Q → D) → Fin n → X)
    (A : (Fin n → D) → (Fin n → Option S) → OC Q D Bool) (ω : ((Q → D) × (Fin n → S)) × (Fin n → D)) : Prop :=
  ¬ LeafGood O (leafPts enc x ω.1.1 ω.1.2)
    ∨ ∃ j, j ∉ O ∧ leafPts enc x ω.1.1 ω.1.2 j ∈ idealQs enc O x A ω

/-- **Outside the bad event, the swapped real world is the ideal world.** -/
theorem realEv_swap_iff (enc : X → S → Q) (O : Finset (Fin n)) (x : (Q → D) → Fin n → X)
    (hx : ∀ H H' : Q → D, (∀ y, (∀ a b, enc a b ≠ y) → H y = H' y) → x H = x H')
    (A : (Fin n → D) → (Fin n → Option S) → OC Q D Bool) (ω : ((Q → D) × (Fin n → S)) × (Fin n → D))
    (hb : ¬ badEv enc O x A ω) : realEv enc O x A (leafSwap enc O x ω) ↔ idealEv enc O x A ω := by
  obtain ⟨⟨H, σ⟩, L⟩ := ω
  simp only [badEv, not_or, not_not, not_exists, not_and] at hb
  obtain ⟨hG, hno⟩ := hb
  rw [leafSwap_good enc O x H σ L hG]
  simp only [realEv, idealEv]
  have hxe := x_reprog enc x hx O H σ L
  have hleaves : saltedLeaves enc (reprog O (leafPts enc x H σ) H L) (x (reprog O (leafPts enc x H σ) H L)) σ
      = idealLeaves enc O H (x H) σ L := by
    funext j
    simp only [saltedLeaves, idealLeaves, hxe]
    by_cases hj : j ∈ O
    · rw [ite_eq_left hj]
      exact reprog_opened hG H L j hj
    · rw [ite_eq_right hj]
      exact reprog_unopened hG H L j hj
  rw [hleaves]
  have hrun : (A (idealLeaves enc O H (x H) σ L) (revealSalts O σ)).run H
      = (A (idealLeaves enc O H (x H) σ L) (revealSalts O σ)).run (reprog O (leafPts enc x H σ) H L) := by
    refine OC.run_eq_of_agree _ (fun y hy => ?_)
    refine (reprog_off H L y (fun j hj he => ?_)).symm
    apply hno j hj
    rw [he]
    exact hy
  rw [← hrun]

/-! ### The bad event is unlikely -/

/-- The ideal leaves do not depend on the salt of an unopened leaf. -/
theorem idealLeaves_update (enc : X → S → Q) (O : Finset (Fin n)) (H : Q → D) (x : Fin n → X) (σ : Fin n → S)
    (L : Fin n → D) (j : Fin n) (hj : j ∉ O) (s : S) :
    idealLeaves enc O H x (Function.update σ j s) L = idealLeaves enc O H x σ L := by
  funext k
  simp only [idealLeaves]
  by_cases hk : k ∈ O
  · have : k ≠ j := fun h => hj (h ▸ hk)
    simp [hk, Function.update_of_ne this]
  · simp [hk]

/-- The revealed salts do not include the salt of an unopened leaf. -/
theorem revealSalts_update (O : Finset (Fin n)) (σ : Fin n → S) (j : Fin n) (hj : j ∉ O) (s : S) :
    revealSalts O (Function.update σ j s) = revealSalts O σ := by
  funext k
  simp only [revealSalts]
  by_cases hk : k ∈ O
  · have : k ≠ j := fun h => hj (h ▸ hk)
    simp [hk, Function.update_of_ne this]
  · simp [hk]

/-- The salts that make leaf `j` bad: another leaf's salt (a collision), or a salt the ideal run asks about at leaf
`j`'s content. Empty for an opened leaf. -/
noncomputable def badSalts [Fintype S] [DecidableEq S] [DecidableEq Q] (enc : X → S → Q) (O : Finset (Fin n))
    (x : (Q → D) → Fin n → X) (A : (Fin n → D) → (Fin n → Option S) → OC Q D Bool) (j : Fin n)
    (ω : ((Q → D) × (Fin n → S)) × (Fin n → D)) : Finset S :=
    if j ∈ O then ∅
    else (Finset.univ.filter (fun k => k ≠ j)).image ω.1.2
      ∪ Finset.univ.filter (fun s => enc (x ω.1.1 j) s ∈ idealQs enc O x A ω)

/-- **The bad event has probability at most `n·(n + q)/|S|`.** -/
theorem badEv_le [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [Fintype S] [Nonempty S]
    [DecidableEq S] (enc : X → S → Q) (henc : ∀ a b a' b', enc a b = enc a' b' → a = a' ∧ b = b')
    (O : Finset (Fin n)) (x : (Q → D) → Fin n → X) (q : ℕ)
    (A : (Fin n → D) → (Fin n → Option S) → OC Q D Bool) (hA : ∀ ℓ ρ, (A ℓ ρ).Bounded q) :
    (PMF.uniformOfFintype (((Q → D) × (Fin n → S)) × (Fin n → D))).toOuterMeasure {ω | badEv enc O x A ω}
      ≤ leafBound n q S := by
  classical
  set μ := (PMF.uniformOfFintype (((Q → D) × (Fin n → S)) × (Fin n → D))).toOuterMeasure
  have hsub : {ω | badEv enc O x A ω} ⊆ ⋃ j, {ω | ω.1.2 j ∈ badSalts enc O x A j ω} := by
    intro ω hω
    simp only [Set.mem_iUnion, Set.mem_ofPred_eq]
    rcases hω with hG | ⟨j, hj, hq⟩
    · simp only [LeafGood, not_forall, not_not, exists_prop] at hG
      obtain ⟨j, hj, k, hk, he⟩ := hG
      refine ⟨j, ?_⟩
      simp only [badSalts, hj, ite_false]
      apply Finset.mem_union_left
      refine Finset.mem_image.mpr ⟨k, by simp [hk], ?_⟩
      exact ((henc _ _ _ _ he).2).symm
    · refine ⟨j, ?_⟩
      simp only [badSalts, hj, ite_false]
      apply Finset.mem_union_right
      simpa [leafPts] using hq
  have hj_le : ∀ j, μ {ω | ω.1.2 j ∈ badSalts enc O x A j ω} ≤ ((n + q : ℕ) : ℝ≥0∞) / Fintype.card S := by
    intro j
    refine prob_salt_mem_le j (n + q) (badSalts enc O x A j) ?_ ?_
    · intro H σ L s
      by_cases hj : j ∈ O
      · simp [badSalts, hj]
      · have hq : idealQs enc O x A ((H, Function.update σ j s), L) = idealQs enc O x A ((H, σ), L) := by
          simp only [idealQs, idealLeaves_update enc O H (x H) σ L j hj s, revealSalts_update O σ j hj s]
        simp only [badSalts, hj, ite_false, hq]
        congr 1
        refine Finset.image_congr (fun k hk => ?_)
        have : k ≠ j := by simpa using hk
        exact Function.update_of_ne this s σ
    · intro ω
      by_cases hj : j ∈ O
      · simp [badSalts, hj]
      · simp only [badSalts, hj, ite_false]
        refine (Finset.card_union_le _ _).trans (Nat.add_le_add ?_ ?_)
        · exact Finset.card_image_le.trans ((Finset.card_filter_le _ _).trans (by simp))
        · have hinj : Set.InjOn (fun s => enc (x ω.1.1 j) s)
              (Finset.univ.filter (fun s => enc (x ω.1.1 j) s ∈ idealQs enc O x A ω) : Set S) :=
            fun a _ b _ hab => (henc _ _ _ _ hab).2
          have hmaps : Set.MapsTo (fun s => enc (x ω.1.1 j) s)
              (Finset.univ.filter (fun s => enc (x ω.1.1 j) s ∈ idealQs enc O x A ω) : Set S)
              ((idealQs enc O x A ω).toFinset : Set Q) := by
            intro s hs
            simpa using hs
          calc (Finset.univ.filter (fun s => enc (x ω.1.1 j) s ∈ idealQs enc O x A ω)).card
              ≤ (idealQs enc O x A ω).toFinset.card := Finset.card_le_card_of_injOn _ hmaps hinj
            _ ≤ (idealQs enc O x A ω).length := List.toFinset_card_le _
            _ ≤ q := OC.length_queries_le _ _ q (hA _ _)
  calc μ {ω | badEv enc O x A ω} ≤ μ (⋃ j, {ω | ω.1.2 j ∈ badSalts enc O x A j ω}) :=
        MeasureTheory.measure_mono hsub
    _ ≤ ∑ j, μ {ω | ω.1.2 j ∈ badSalts enc O x A j ω} := MeasureTheory.measure_iUnion_fintype_le μ _
    _ ≤ ∑ _j : Fin n, ((n + q : ℕ) : ℝ≥0∞) / Fintype.card S := Finset.sum_le_sum (fun j _ => hj_le j)
    _ = leafBound n q S := by
        rw [Finset.sum_const, Finset.card_univ, Fintype.card_fin, nsmul_eq_mul, leafBound, Nat.cast_mul,
          mul_div_assoc]

/-! ### The theorems -/

/-- **One level of salted leaf hashing, real against ideal.** In the random-oracle model, with uniform salts from `S`
and an injective encoding of (content, salt), an adversary that sees every leaf digest and the opened leaves' salts
and makes at most `q` oracle queries accepts with almost the same probability as when the unopened leaves are
replaced by fresh uniform digests: the two differ by at most `n·(n + q)/|S|`. For privacy: the salted leaves of the
unopened columns are, to a `q`-query adversary, indistinguishable from random strings. -/
theorem saltedLeaves_real_ideal [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [Fintype S] [Nonempty S]
    [DecidableEq S] (enc : X → S → Q) (henc : ∀ a b a' b', enc a b = enc a' b' → a = a' ∧ b = b')
    (O : Finset (Fin n)) (x : (Q → D) → Fin n → X)
    (hx : ∀ H H' : Q → D, (∀ y, (∀ a b, enc a b ≠ y) → H y = H' y) → x H = x H')
    (q : ℕ) (A : (Fin n → D) → (Fin n → Option S) → OC Q D Bool) (hA : ∀ ℓ ρ, (A ℓ ρ).Bounded q) :
    leafReal enc O x A ≤ leafIdeal enc O x A + leafBound n q S
      ∧ leafIdeal enc O x A ≤ leafReal enc O x A + leafBound n q S := by
  classical
  set μ := (PMF.uniformOfFintype (((Q → D) × (Fin n → S)) × (Fin n → D))).toOuterMeasure with hμ
  have hreal : leafReal enc O x A = μ {ω | realEv enc O x A ω} := by
    rw [hμ, leafReal]
    exact (prob_fst _).symm
  have hideal : leafIdeal enc O x A = μ {ω | idealEv enc O x A ω} := rfl
  have hΨ : μ (leafSwap enc O x ⁻¹' {ω | realEv enc O x A ω}) = μ {ω | realEv enc O x A ω} :=
    prob_preimage_bijective _ (leafSwap_involutive enc O x hx).bijective _
  have hB := badEv_le enc henc O x q A hA
  have h1 : leafSwap enc O x ⁻¹' {ω | realEv enc O x A ω}
      ⊆ {ω | idealEv enc O x A ω} ∪ {ω | badEv enc O x A ω} := by
    intro ω hω
    by_cases hb : badEv enc O x A ω
    · exact Or.inr hb
    · exact Or.inl ((realEv_swap_iff enc O x hx A ω hb).mp hω)
  have h2 : {ω | idealEv enc O x A ω}
      ⊆ leafSwap enc O x ⁻¹' {ω | realEv enc O x A ω} ∪ {ω | badEv enc O x A ω} := by
    intro ω hω
    by_cases hb : badEv enc O x A ω
    · exact Or.inr hb
    · exact Or.inl ((realEv_swap_iff enc O x hx A ω hb).mpr hω)
  constructor
  · calc leafReal enc O x A = μ (leafSwap enc O x ⁻¹' {ω | realEv enc O x A ω}) := by rw [hΨ, hreal]
      _ ≤ μ ({ω | idealEv enc O x A ω} ∪ {ω | badEv enc O x A ω}) := MeasureTheory.measure_mono h1
      _ ≤ μ {ω | idealEv enc O x A ω} + μ {ω | badEv enc O x A ω} := MeasureTheory.measure_union_le _ _
      _ ≤ leafIdeal enc O x A + leafBound n q S := by rw [hideal]; gcongr
  · calc leafIdeal enc O x A = μ {ω | idealEv enc O x A ω} := hideal
      _ ≤ μ (leafSwap enc O x ⁻¹' {ω | realEv enc O x A ω} ∪ {ω | badEv enc O x A ω}) :=
          MeasureTheory.measure_mono h2
      _ ≤ μ (leafSwap enc O x ⁻¹' {ω | realEv enc O x A ω}) + μ {ω | badEv enc O x A ω} :=
          MeasureTheory.measure_union_le _ _
      _ ≤ leafReal enc O x A + leafBound n q S := by rw [hΨ, ← hreal]; gcongr

/-- **One level of salted leaf hashing hides the unopened leaves.** Two content vectors that agree on the opened
leaves (for every oracle) are told apart by a `q`-query adversary that sees every leaf digest and the opened salts
with advantage at most `2·n·(n + q)/|S|`, in both directions. -/
theorem saltedLeaves_hiding [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [Fintype S] [Nonempty S]
    [DecidableEq S] (enc : X → S → Q) (henc : ∀ a b a' b', enc a b = enc a' b' → a = a' ∧ b = b')
    (O : Finset (Fin n)) (x x' : (Q → D) → Fin n → X)
    (hx : ∀ H H' : Q → D, (∀ y, (∀ a b, enc a b ≠ y) → H y = H' y) → x H = x H')
    (hx' : ∀ H H' : Q → D, (∀ y, (∀ a b, enc a b ≠ y) → H y = H' y) → x' H = x' H')
    (hxO : ∀ H j, j ∈ O → x H j = x' H j)
    (q : ℕ) (A : (Fin n → D) → (Fin n → Option S) → OC Q D Bool) (hA : ∀ ℓ ρ, (A ℓ ρ).Bounded q) :
    leafReal enc O x A ≤ leafReal enc O x' A + 2 * leafBound n q S
      ∧ leafReal enc O x' A ≤ leafReal enc O x A + 2 * leafBound n q S := by
  have hid : leafIdeal enc O x A = leafIdeal enc O x' A := by
    have hl : ∀ H σ L, idealLeaves enc O H (x H) σ L = idealLeaves enc O H (x' H) σ L := by
      intro H σ L
      funext j
      simp only [idealLeaves]
      by_cases hj : j ∈ O
      · rw [ite_eq_left hj, ite_eq_left hj, hxO H j hj]
      · rw [ite_eq_right hj, ite_eq_right hj]
    simp only [leafIdeal, hl]
  obtain ⟨a1, a2⟩ := saltedLeaves_real_ideal enc henc O x hx q A hA
  obtain ⟨b1, b2⟩ := saltedLeaves_real_ideal enc henc O x' hx' q A hA
  rw [two_mul]
  constructor
  · calc leafReal enc O x A ≤ leafIdeal enc O x A + leafBound n q S := a1
      _ = leafIdeal enc O x' A + leafBound n q S := by rw [hid]
      _ ≤ (leafReal enc O x' A + leafBound n q S) + leafBound n q S := by gcongr
      _ = leafReal enc O x' A + (leafBound n q S + leafBound n q S) := by rw [add_assoc]
  · calc leafReal enc O x' A ≤ leafIdeal enc O x' A + leafBound n q S := b1
      _ = leafIdeal enc O x A + leafBound n q S := by rw [hid]
      _ ≤ (leafReal enc O x A + leafBound n q S) + leafBound n q S := by gcongr
      _ = leafReal enc O x A + (leafBound n q S + leafBound n q S) := by rw [add_assoc]

/-! ## The tree -/

/-- The probability that a distinguisher `B` accepts a view computed from the salted leaves and the opened salts by
the oracle computation `T` (for example the root and the authentication paths). -/
noncomputable def viewReal {V : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]
    [Fintype S] [Nonempty S] (enc : X → S → Q) (O : Finset (Fin n)) (x : (Q → D) → Fin n → X)
    (T : (Fin n → D) → (Fin n → Option S) → OC Q D V) (B : V → OC Q D Bool) : ℝ≥0∞ :=
  (PMF.uniformOfFintype ((Q → D) × (Fin n → S))).toOuterMeasure
    {p | (B ((T (saltedLeaves enc p.1 (x p.1) p.2) (revealSalts O p.2)).run p.1)).run p.1 = true}

/-- **Anything computed from the salted leaves hides the unopened leaves.** If the view is computed from the leaf
digests and the opened salts with at most `t` oracle queries, a distinguisher making at most `q` queries tells two
content vectors that agree on the opened leaves apart with advantage at most `2·n·(n + t + q)/|S|`. -/
theorem saltedLeaves_view_hiding {V : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]
    [Fintype S] [Nonempty S] [DecidableEq S] (enc : X → S → Q)
    (henc : ∀ a b a' b', enc a b = enc a' b' → a = a' ∧ b = b')
    (O : Finset (Fin n)) (x x' : (Q → D) → Fin n → X)
    (hx : ∀ H H' : Q → D, (∀ y, (∀ a b, enc a b ≠ y) → H y = H' y) → x H = x H')
    (hx' : ∀ H H' : Q → D, (∀ y, (∀ a b, enc a b ≠ y) → H y = H' y) → x' H = x' H')
    (hxO : ∀ H j, j ∈ O → x H j = x' H j)
    (T : (Fin n → D) → (Fin n → Option S) → OC Q D V) (t : ℕ) (hT : ∀ ℓ ρ, (T ℓ ρ).Bounded t)
    (B : V → OC Q D Bool) (q : ℕ) (hB : ∀ v, (B v).Bounded q) :
    viewReal enc O x T B ≤ viewReal enc O x' T B + 2 * leafBound n (t + q) S
      ∧ viewReal enc O x' T B ≤ viewReal enc O x T B + 2 * leafBound n (t + q) S := by
  have hA : ∀ ℓ ρ, ((T ℓ ρ).bind B).Bounded (t + q) := fun ℓ ρ => (hT ℓ ρ).bind hB
  have hv : ∀ xx : (Q → D) → Fin n → X, viewReal enc O xx T B = leafReal enc O xx (fun ℓ ρ => (T ℓ ρ).bind B) := by
    intro xx
    simp only [viewReal, leafReal, OC.run_bind]
  rw [hv x, hv x']
  exact saltedLeaves_hiding enc henc O x x' hx hx' hxO (t + q) _ hA

/-- One level of the tree: hash consecutive pairs `(v_{2i}, v_{2i+1})` with the node encoding (`MerkleTree::build`:
`hash_pair(&pair[0], &pair[1])`). -/
def hashPairs (node : D → D → Q) : (m : ℕ) → (Fin (2 * m) → D) → OC Q D (Fin m → D)
  | 0, _ => .ret Fin.elim0
  | m + 1, v => .ask (node (v ⟨0, by omega⟩) (v ⟨1, by omega⟩))
      (fun h => (hashPairs node m (fun i => v ⟨(i : ℕ) + 2, by have := i.isLt; omega⟩)).bind
        (fun w => .ret (Fin.cons h w : Fin (m + 1) → D)))

/-- One tree level over `2m` digests costs `m` node queries. -/
theorem hashPairs_bounded (node : D → D → Q) (m : ℕ) (v : Fin (2 * m) → D) : (hashPairs node m v).Bounded m := by
  induction m with
  | zero => simp [hashPairs, OC.Bounded]
  | succ m ih =>
    simp only [hashPairs, OC.Bounded]
    intro h
    have := OC.Bounded.bind (ih (fun i => v ⟨(i : ℕ) + 2, by have := i.isLt; omega⟩))
      (fun w => (show (OC.ret (Fin.cons h w : Fin (m + 1) → D) : OC Q D (Fin (m + 1) → D)).Bounded 0 from trivial))
    simpa using this

/-- The whole Merkle tree over `2^h` leaves, every level from the leaves up to the root. The root is the last level's
only entry, and the authentication path of a leaf is its sibling on every level: both are read off this output. -/
def merkleLevels (node : D → D → Q) : (h : ℕ) → (Fin (2 ^ h) → D) → OC Q D (List (List D))
  | 0, v => .ret [List.ofFn v]
  | h + 1, v => (hashPairs node (2 ^ h) (fun i => v (Fin.cast (by ring) i))).bind
      (fun w => (merkleLevels node h w).bind (fun ls => .ret (List.ofFn v :: ls)))

/-- **The tree costs `2^h − 1` node queries.** -/
theorem merkleLevels_bounded (node : D → D → Q) (h : ℕ) (v : Fin (2 ^ h) → D) :
    (merkleLevels node h v).Bounded (2 ^ h - 1) := by
  induction h with
  | zero => simp [merkleLevels, OC.Bounded]
  | succ h ih =>
    simp only [merkleLevels]
    have hb := OC.Bounded.bind (hashPairs_bounded node (2 ^ h) (fun i => v (Fin.cast (by ring) i)))
      (fun w => OC.Bounded.bind (ih w)
        (fun ls => (show (OC.ret (List.ofFn v :: ls) : OC Q D (List (List D))).Bounded 0 from trivial)))
    refine hb.mono ?_
    have h1 : 1 ≤ 2 ^ h := Nat.one_le_two_pow
    rw [pow_succ]
    omega

/-- The real-world probability that a distinguisher accepts the whole tree (root, every level, hence every path) and
the opened salts. -/
noncomputable def merkleReal [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [Fintype S] [Nonempty S]
    (enc : X → S → Q) (node : D → D → Q) (h : ℕ) (O : Finset (Fin (2 ^ h)))
    (x : (Q → D) → Fin (2 ^ h) → X) (B : List (List D) × (Fin (2 ^ h) → Option S) → OC Q D Bool) : ℝ≥0∞ :=
  (PMF.uniformOfFintype ((Q → D) × (Fin (2 ^ h) → S))).toOuterMeasure
    {p | (B ((merkleLevels node h (saltedLeaves enc p.1 (x p.1) p.2)).run p.1, revealSalts O p.2)).run p.1 = true}

/-- **Salted Merkle hiding: roots and paths.** In the random-oracle model, for a salted Merkle tree over `N = 2^h`
leaves with uniform salts from `S`: a distinguisher that sees the whole tree (its root and every authentication path)
and the opened leaves' salts, and makes at most `q` oracle queries, tells two leaf-content vectors that agree on the
opened leaves apart with advantage at most `2·N·(N + (N − 1) + q)/|S|`, in both directions. The node encoding is
arbitrary (no domain separation from the leaves is needed). For privacy: with 256-bit salts the Merkle layer hides
the unopened columns up to `q·2^-239 + 2^-222` at `N ≤ 2^16`. -/
theorem merkle_hiding [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [Fintype S] [Nonempty S]
    [DecidableEq S] (enc : X → S → Q) (henc : ∀ a b a' b', enc a b = enc a' b' → a = a' ∧ b = b')
    (node : D → D → Q) (h : ℕ) (O : Finset (Fin (2 ^ h))) (x x' : (Q → D) → Fin (2 ^ h) → X)
    (hx : ∀ H H' : Q → D, (∀ y, (∀ a b, enc a b ≠ y) → H y = H' y) → x H = x H')
    (hx' : ∀ H H' : Q → D, (∀ y, (∀ a b, enc a b ≠ y) → H y = H' y) → x' H = x' H')
    (hxO : ∀ H j, j ∈ O → x H j = x' H j)
    (B : List (List D) × (Fin (2 ^ h) → Option S) → OC Q D Bool) (q : ℕ) (hB : ∀ v, (B v).Bounded q) :
    merkleReal enc node h O x B ≤ merkleReal enc node h O x' B + 2 * leafBound (2 ^ h) (2 ^ h - 1 + q) S
      ∧ merkleReal enc node h O x' B ≤ merkleReal enc node h O x B + 2 * leafBound (2 ^ h) (2 ^ h - 1 + q) S := by
  have hT : ∀ ℓ (ρ : Fin (2 ^ h) → Option S),
      ((merkleLevels node h ℓ).bind (fun ls => OC.ret (ls, ρ))).Bounded (2 ^ h - 1) := by
    intro ℓ ρ
    have := OC.Bounded.bind (merkleLevels_bounded node h ℓ)
      (fun ls => (show (OC.ret (ls, ρ) : OC Q D (List (List D) × (Fin (2 ^ h) → Option S))).Bounded 0 from trivial))
    simpa using this
  have hm : ∀ xx : (Q → D) → Fin (2 ^ h) → X, merkleReal enc node h O xx B
      = viewReal enc O xx (fun ℓ ρ => (merkleLevels node h ℓ).bind (fun ls => OC.ret (ls, ρ))) B := by
    intro xx
    simp only [merkleReal, viewReal, OC.run_bind]
    rfl
  rw [hm x, hm x']
  exact saltedLeaves_view_hiding enc henc O x x' hx hx' hxO _ (2 ^ h - 1) hT B q hB

end SaltedLeaves

end Hiding

end ZK60
