/-
D63, step L3 (soundness): Merkle binding in the random-oracle model.

What the code computes (`zkp-core/src/pcs.rs` `commit_zk_owned_with_tag`, `verify_zk_tagged`; `zkp-core/src/merkle.rs`
`MerkleTree::build_keyed`, `verify_path_keyed`; the same calls in `hashline/src/zk.rs` for the mask commitment `M`):
* a column `c` (its `rows` field elements, little-endian, `Fp::to_bytes` canonical) has the digest
  `x = H_col(bytes(c))`; its salted leaf is `ℓ = H_leaf(x ‖ σ)` with a 32-byte salt `σ`;
* an inner node is `H_node(left ‖ right)`; the tree is over `N = 2^h` leaves (`build_keyed` asserts a power of two;
  `enc_cols` is `2^log_cols · inv_rate`, so no padding ever occurs);
* an opening at position `j < N` reveals `(c, σ, path)` and verifies by climbing from `ℓ`: at each level the running
  digest is the left child when the current low bit of `j` is 0 (`idx & 1 == 0`), then `idx >>= 1`; the result must
  be the root. `verify_zk_tagged` also refuses a path whose length is not `h = log2 N` (D19 ruling T-4) and a column
  whose length is not `rows`.

Model. One random function `H : Q → D` (`Statements.lean`). The three kinds of input are maps `colQ`, `leafQ`, `nodeQ`
into `Q` (`MerkleEnc`), each with a left inverse (a decoder). Under the tagged profiles `Q` holds (key, bytes) and the
three keys differ (T-1); under the legacy rule there is no key and `leafQ = nodeQ` as functions of 64 bytes. NOTHING
here assumes the three are separated from each other: binding only uses that each one is injective, because both
openings have paths of the SAME length `h`, so the two climbs compare a column query with a column query, a leaf
query with a leaf query and a node query at level `t` with a node query at level `t`. The path-length check is what
makes that true; without it (the legacy `verify_zk`), binding needs the leaf and node inputs to be separated, which the
legacy rule does not do (D19's "depth confusion"; findings, Part 3).

What is proved:
* `opens_collision` (deterministic): two openings of one root at one position, with different columns, contain a
  collision of `H` among the verifier's `2(h + 2)` queries;
* `merkle_binding` (task 2): an adversary making at most `q` queries outputs a root, a position and two such openings
  with probability at most `collBound (q + 2(h + 2))`, i.e. `(q + 2h + 4)(q + 2h + 3)/2 / |D|`.
-/
import ZK60Formal.SoundRO

namespace ZK60.Sound

open scoped ENNReal

/-- The three kinds of hash input of a salted Merkle commitment, each with a left inverse: the column digest's input
`colQ c` (the column's bytes, under the column key), the salted leaf's input `leafQ x s` (`x ‖ s`, under the leaf key)
and the inner node's input `nodeQ l r` (`l ‖ r`, under the node key). Each map is injective (it has a decoder); no
separation BETWEEN the three is assumed. -/
structure MerkleEnc (Q D S Col : Type) where
  colQ : Col → Q
  leafQ : D → S → Q
  nodeQ : D → D → Q
  colDec : Q → Option Col
  leafDec : Q → Option (D × S)
  nodeDec : Q → Option (D × D)
  colDec_colQ : ∀ c, colDec (colQ c) = some c
  leafDec_leafQ : ∀ x s, leafDec (leafQ x s) = some (x, s)
  nodeDec_nodeQ : ∀ l r, nodeDec (nodeQ l r) = some (l, r)

/-- What an opening of one column reveals: the column, its salt and its authentication path (the sibling digests from
the leaf level up, `MerkleTree::path`). -/
structure MerkleOpening (D S Col : Type) where
  col : Col
  salt : S
  path : List D

namespace MerkleEnc

variable {Q D S Col : Type} (M : MerkleEnc Q D S Col)

/-- The column input is injective. -/
theorem colQ_inj {c c' : Col} (h : M.colQ c = M.colQ c') : c = c' := by
  have h1 := M.colDec_colQ c
  rw [h, M.colDec_colQ c'] at h1
  exact (Option.some_injective _ h1).symm

/-- The salted-leaf input is injective. -/
theorem leafQ_inj {x x' : D} {s s' : S} (h : M.leafQ x s = M.leafQ x' s') : x = x' ∧ s = s' := by
  have h1 := M.leafDec_leafQ x s
  rw [h, M.leafDec_leafQ x' s'] at h1
  simp only [Option.some.injEq, Prod.mk.injEq] at h1
  exact ⟨h1.1.symm, h1.2.symm⟩

/-- The node input is injective. -/
theorem nodeQ_inj {l r l' r' : D} (h : M.nodeQ l r = M.nodeQ l' r') : l = l' ∧ r = r' := by
  have h1 := M.nodeDec_nodeQ l r
  rw [h, M.nodeDec_nodeQ l' r'] at h1
  simp only [Option.some.injEq, Prod.mk.injEq] at h1
  exact ⟨h1.1.symm, h1.2.symm⟩

/-- The node query at one level (`verify_path_keyed`): the running digest `cur` is the LEFT child when the current low
bit of the position is 0 (`idx & 1 == 0`), the right child otherwise. -/
def stepQ (j : ℕ) (cur sib : D) : Q := if j % 2 = 0 then M.nodeQ cur sib else M.nodeQ sib cur

/-- One level's node query determines the running digest and the sibling. -/
theorem stepQ_inj {j : ℕ} {cur sib cur' sib' : D} (h : M.stepQ j cur sib = M.stepQ j cur' sib') :
    cur = cur' ∧ sib = sib' := by
  unfold stepQ at h
  split_ifs at h with hj
  · exact M.nodeQ_inj h
  · exact ⟨(M.nodeQ_inj h).2, (M.nodeQ_inj h).1⟩

/-- Decoding one level's node query gives (left, right) in the climb's order. -/
theorem nodeDec_stepQ (j : ℕ) (cur sib : D) :
    M.nodeDec (M.stepQ j cur sib) = some (if j % 2 = 0 then (cur, sib) else (sib, cur)) := by
  unfold stepQ
  split_ifs <;> simp [M.nodeDec_nodeQ]

/-- The climb from a digest along a path, bottom up (`verify_path_keyed`): hash with the sibling, then halve the
position. -/
def climb (H : Q → D) : ℕ → D → List D → D
  | _, cur, [] => cur
  | j, cur, sib :: rest => climb H (j / 2) (H (M.stepQ j cur sib)) rest

/-- The node queries of the climb, bottom up. -/
def climbQs (H : Q → D) : ℕ → D → List D → List Q
  | _, _, [] => []
  | j, cur, sib :: rest => M.stepQ j cur sib :: climbQs H (j / 2) (H (M.stepQ j cur sib)) rest

/-- The salted leaf of a column: `H_leaf(H_col(column) ‖ salt)` (`salt_leaf_keyed(&hash_column_keyed(col), salt)`). -/
def leafDigest (H : Q → D) (c : Col) (s : S) : D := H (M.leafQ (H (M.colQ c)) s)

/-- **An opening verifies** at position `j` against `root` (`pcs::verify_zk_tagged`): the path has exactly `h` entries,
the tree's depth (D19 ruling T-4), and the climb from the column's salted leaf reaches the root. -/
def Opens (H : Q → D) (h : ℕ) (root : D) (j : ℕ) (o : MerkleOpening D S Col) : Prop :=
  o.path.length = h ∧ M.climb H j (M.leafDigest H o.col o.salt) o.path = root

/-- The verifier's queries for one opening: the column digest's input, the salted leaf's input, then the node inputs
up the path. -/
def openQs (H : Q → D) (j : ℕ) (o : MerkleOpening D S Col) : List Q :=
  M.colQ o.col :: M.leafQ (H (M.colQ o.col)) o.salt :: M.climbQs H j (M.leafDigest H o.col o.salt) o.path

/-! ## The verifier's hashing as an oracle computation -/

/-- The climb as an oracle computation; it returns the digest it reaches. -/
def climbOC : ℕ → D → List D → OC Q D D
  | _, cur, [] => .ret cur
  | j, cur, sib :: rest => .ask (M.stepQ j cur sib) (fun nxt => climbOC (j / 2) nxt rest)

/-- The verifier's hashing for one opening; it returns the root it computes. -/
def openOC (j : ℕ) (o : MerkleOpening D S Col) : OC Q D D :=
  .ask (M.colQ o.col) (fun x => .ask (M.leafQ x o.salt) (fun ℓ => M.climbOC j ℓ o.path))

/-- The climb computation computes the climb. -/
theorem climbOC_run (H : Q → D) (j : ℕ) (cur : D) (p : List D) : (M.climbOC j cur p).run H = M.climb H j cur p := by
  induction p generalizing j cur with
  | nil => rfl
  | cons sib rest ih => exact ih (j / 2) (H (M.stepQ j cur sib))

/-- The climb computation asks the climb's node queries. -/
theorem climbOC_queries (H : Q → D) (j : ℕ) (cur : D) (p : List D) :
    OC.queries H (M.climbOC j cur p) = M.climbQs H j cur p := by
  induction p generalizing j cur with
  | nil => simp [climbOC, climbQs, OC.queries, OC.runLog]
  | cons sib rest ih =>
    rw [climbOC, climbQs, OC.queries_ask, ih]

/-- The climb costs one query per path entry. -/
theorem climbOC_bounded (j : ℕ) (cur : D) (p : List D) : (M.climbOC j cur p).Bounded p.length := by
  induction p generalizing j cur with
  | nil => simp [climbOC, OC.Bounded]
  | cons sib rest ih =>
    simp only [climbOC, List.length_cons, OC.Bounded]
    exact fun nxt => ih (j / 2) nxt

/-- The opening computation computes the climb from the column's salted leaf. -/
theorem openOC_run (H : Q → D) (j : ℕ) (o : MerkleOpening D S Col) :
    (M.openOC j o).run H = M.climb H j (M.leafDigest H o.col o.salt) o.path := by
  simp only [openOC, OC.run, leafDigest]
  exact M.climbOC_run H _ _ _

/-- The opening computation asks the verifier's queries. -/
theorem openOC_queries (H : Q → D) (j : ℕ) (o : MerkleOpening D S Col) :
    OC.queries H (M.openOC j o) = M.openQs H j o := by
  rw [openOC, OC.queries_ask, OC.queries_ask, M.climbOC_queries]
  rfl

/-- One opening costs `h + 2` queries for a path of `h` entries. -/
theorem openOC_bounded (j : ℕ) (o : MerkleOpening D S Col) : (M.openOC j o).Bounded (o.path.length + 2) := by
  show OC.Bounded (OC.ask _ _) (o.path.length + 1 + 1)
  intro x
  show OC.Bounded (OC.ask _ _) (o.path.length + 1)
  intro ℓ
  exact M.climbOC_bounded j ℓ o.path

/-- The verifier's hashing, refused without a query when the path does not have `h` entries (the length check comes
first, as in `verify_zk_tagged`). -/
def checkOC (h j : ℕ) (o : MerkleOpening D S Col) : OC Q D Unit :=
  if o.path.length = h then (M.openOC j o).bind (fun _ => .ret ()) else .ret ()

/-- The checked opening costs at most `h + 2` queries. -/
theorem checkOC_bounded (h j : ℕ) (o : MerkleOpening D S Col) : (M.checkOC h j o).Bounded (h + 2) := by
  unfold checkOC
  split_ifs with hl
  · have hb := (M.openOC_bounded j o).bind
      (fun _ => (show (OC.ret () : OC Q D Unit).Bounded 0 from trivial))
    rw [hl] at hb
    simpa using hb
  · exact trivial

/-- With a path of the right length, the checked opening asks the verifier's queries. -/
theorem checkOC_queries (H : Q → D) {h j : ℕ} {o : MerkleOpening D S Col} (hl : o.path.length = h) :
    OC.queries H (M.checkOC h j o) = M.openQs H j o := by
  unfold checkOC
  rw [ite_eq_left hl, OC.queries_bind, M.openOC_queries]
  simp [OC.queries, OC.runLog]

/-! ## Binding -/

/-- **Two climbs that reach one digest from different digests collide.** Along paths of equal length, at the same
position, the two climbs' node queries contain two different questions with the same answer. -/
theorem climb_collision (H : Q → D) (p₁ : List D) :
    ∀ (p₂ : List D) (j : ℕ) (x₁ x₂ : D), p₁.length = p₂.length → x₁ ≠ x₂ →
      M.climb H j x₁ p₁ = M.climb H j x₂ p₂ →
      ∃ a ∈ M.climbQs H j x₁ p₁, ∃ b ∈ M.climbQs H j x₂ p₂, a ≠ b ∧ H a = H b := by
  induction p₁ with
  | nil =>
    intro p₂ j x₁ x₂ hl hx h
    cases p₂ with
    | nil => exact absurd (by simpa [climb] using h) hx
    | cons _ _ => simp at hl
  | cons s₁ r₁ ih =>
    intro p₂ j x₁ x₂ hl hx h
    cases p₂ with
    | nil => simp at hl
    | cons s₂ r₂ =>
      by_cases hH : H (M.stepQ j x₁ s₁) = H (M.stepQ j x₂ s₂)
      · exact ⟨M.stepQ j x₁ s₁, List.mem_cons_self, M.stepQ j x₂ s₂, List.mem_cons_self,
          fun he => hx (M.stepQ_inj he).1, hH⟩
      · obtain ⟨a, ha, b, hb, hab, hHab⟩ := ih r₂ (j / 2) _ _ (by simpa using hl) hH h
        exact ⟨a, List.mem_cons_of_mem _ ha, b, List.mem_cons_of_mem _ hb, hab, hHab⟩

/-- **Two openings of one root to different columns collide (deterministic).** If two openings at the same position
both verify against the same root, with paths of the tree's depth, and reveal different columns, then among the
verifier's queries for the two there are two different questions with the same answer: in the node climb, or at the
salted leaf, or at the column digest. Only the injectivity of each input map is used. -/
theorem opens_collision (H : Q → D) {h : ℕ} {root : D} {j : ℕ} {o₁ o₂ : MerkleOpening D S Col}
    (hc : o₁.col ≠ o₂.col) (h₁ : M.Opens H h root j o₁) (h₂ : M.Opens H h root j o₂) :
    ∃ a ∈ M.openQs H j o₁, ∃ b ∈ M.openQs H j o₂, a ≠ b ∧ H a = H b := by
  by_cases hℓ : M.leafDigest H o₁.col o₁.salt = M.leafDigest H o₂.col o₂.salt
  · by_cases hq : M.leafQ (H (M.colQ o₁.col)) o₁.salt = M.leafQ (H (M.colQ o₂.col)) o₂.salt
    · exact ⟨M.colQ o₁.col, by simp [openQs], M.colQ o₂.col, by simp [openQs],
        fun he => hc (M.colQ_inj he), (M.leafQ_inj hq).1⟩
    · exact ⟨_, by simp [openQs], _, by simp [openQs], hq, hℓ⟩
  · obtain ⟨a, ha, b, hb, hab, hH⟩ :=
      M.climb_collision H o₁.path o₂.path j _ _ (h₁.1.trans h₂.1.symm) hℓ (h₁.2.trans h₂.2.symm)
    exact ⟨a, by simp [openQs, ha], b, by simp [openQs, hb], hab, hH⟩

/-- **Without the path-length check no encoding gives binding.** For EVERY oracle, every encoding (the leaf and node
inputs may be perfectly separated) and every two columns, a tree of mixed depth opens position 2 to both: the first
column's salted leaf `ℓ₁` sits at depth 1 with sibling `R`, and the second's `ℓ₂` at depth 2 under `R`, with any
sibling `X`. The climb from `ℓ₁` along `[R]` and the climb from `ℓ₂` along `[X, ℓ₁]` both reach `H(node(ℓ₁, R))`. No
collision is involved. So D19's path-length check (T-4) is what binding rests on; the keys alone do not give it. -/
theorem mixed_depth_opens (H : Q → D) (c₁ c₂ : Col) (s₁ s₂ : S) (X : D) :
    M.climb H 2 (M.leafDigest H c₁ s₁) [H (M.nodeQ (M.leafDigest H c₂ s₂) X)]
        = H (M.nodeQ (M.leafDigest H c₁ s₁) (H (M.nodeQ (M.leafDigest H c₂ s₂) X)))
      ∧ M.climb H 2 (M.leafDigest H c₂ s₂) [X, M.leafDigest H c₁ s₁]
        = H (M.nodeQ (M.leafDigest H c₁ s₁) (H (M.nodeQ (M.leafDigest H c₂ s₂) X))) := by
  simp [climb, stepQ]

variable [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]

/-- **Merkle binding in the random-oracle model (task 2).** An adversary making at most `q` hash queries outputs a
root, a position and two openings there, with different columns, that both verify (paths of the tree's depth `h`),
with probability at most `collBound (q + 2(h + 2)) D = (q + 2h + 4)(q + 2h + 3)/2 / |D|`: the collision bound for the
adversary's queries plus the verifier's. -/
theorem merkle_binding (h q : ℕ) (A : OC Q D (D × ℕ × MerkleOpening D S Col × MerkleOpening D S Col))
    (hA : A.Bounded q) :
    prH (fun H => (A.run H).2.2.1.col ≠ (A.run H).2.2.2.col
        ∧ M.Opens H h (A.run H).1 (A.run H).2.1 (A.run H).2.2.1
        ∧ M.Opens H h (A.run H).1 (A.run H).2.1 (A.run H).2.2.2)
      ≤ collBound (q + 2 * (h + 2)) D := by
  classical
  let B : OC Q D (D × ℕ × MerkleOpening D S Col × MerkleOpening D S Col) :=
    A.bind (fun o => (M.checkOC h o.2.1 o.2.2.1).bind
      (fun _ => (M.checkOC h o.2.1 o.2.2.2).bind (fun _ => .ret o)))
  have hB : B.Bounded (q + 2 * (h + 2)) := by
    have hb := hA.bind (fun o => (M.checkOC_bounded h o.2.1 o.2.2.1).bind
      (fun _ => (M.checkOC_bounded h o.2.1 o.2.2.2).bind
        (fun _ => (show (OC.ret o : OC Q D _).Bounded 0 from trivial))))
    exact hb.mono (by omega)
  refine le_trans (MeasureTheory.measure_mono ?_) (collision_prob_le B _ hB)
  rintro H ⟨hc, h₁, h₂⟩
  obtain ⟨a, ha, b, hb, hab, hH⟩ := M.opens_collision H hc h₁ h₂
  have hq : OC.queries H B = OC.queries H A
      ++ (M.openQs H (A.run H).2.1 (A.run H).2.2.1 ++ (M.openQs H (A.run H).2.1 (A.run H).2.2.2 ++ [])) := by
    simp only [B, OC.queries_bind, M.checkOC_queries H h₁.1, M.checkOC_queries H h₂.1]
    simp [OC.queries, OC.runLog]
  refine ⟨a, ?_, b, ?_, hab, hH⟩
  · rw [hq]
    simp [ha]
  · rw [hq]
    simp [hb]

end MerkleEnc

end ZK60.Sound
