/-
D63 step L5 (the executable verifier), the foundation: the Merkle verifier of one opened column, executable, as
`merkle.rs` and `pcs.rs` run it, and proved to be `SoundMerkle.lean`'s `Opens` for EVERY hash function, so that
`merkle_binding` holds of the code's verifier.

What is mirrored (`ops/zkp-mvp/gpu-metal/zkp-core/src/merkle.rs`, `pcs.rs`, read 2026-11-06; nothing there is changed):
* the column digest `hash_column_keyed`: `H(column key; Fp::to_bytes of each entry)`;
* the salted leaf `salt_leaf_keyed`: `H(leaf key; digest ‖ salt)`;
* the inner node `hash_pair_keyed`: `H(node key; left ‖ right)`;
* `MerkleTree::verify_path_keyed`: from the leaf, for each sibling, `idx & 1 == 0` puts the running digest on the left,
  then `idx >>= 1`; the result must equal the root;
* `verify_zk_tagged`'s per-column checks: the path has exactly `log2(enc_cols)` entries (D19 ruling T-4, the first check),
  the column has `rows` entries, and the path verifies from the column's salted leaf. (The index check `j == want_j`
  compares with the transcript's `challenge_indices`, `ExecTranscript.lean`; the column-versus-clear-vector check is the
  per-profile opening, not this file.)
The legacy rule is the tag with no key anywhere (`MTag.legacy`), where a salted leaf and a node are the same call.

What is proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `merkleEnc`: the code's three encodings form a `MerkleEnc` (`SoundMerkle.lean`), with decoders (`decCol_colBytes`,
  `splitDig_append`). No separation between the three is used, so this holds under the legacy rule too;
* `foldPath_eq_climb` and **`verifyColumn_iff`**: for every hash function `H`, the executable check accepts exactly when
  `SoundMerkle.lean`'s `Opens` holds (and the column has `rows` entries);
* **`exec_merkle_binding`**: in the random-oracle model over the finite set of inputs of at most `L` bytes (`QB L`; the
  code's inputs are at most `max(64, 8·rows)` bytes), an adversary making `q` queries outputs one root, one position and
  two different columns that BOTH pass the executable verifier with probability at most `collBound (q + 2(h + 2))`:
  `merkle_binding`, now about the program, not about a model of it.
-/
import Mathlib.Data.FinEnum
import Mathlib.Data.Fintype.Vector
import Mathlib.Data.Set.Finite.List
import ZK60Formal.ExecTranscript
import ZK60Formal.SoundMerkle

namespace ZK60.Exec

open ZK60.Sound

/-- The commitment's keys of one profile's hash tag (`HashTag::column_key`, `leaf_key`, `node_key`); `none` everywhere
is the legacy rule. -/
structure MTag where
  col : Option Dig
  leaf : Option Dig
  node : Option Dig

def MTag.legacy : MTag := ⟨none, none, none⟩

/-- A column's bytes: `Fp::to_bytes` of each entry, in order. -/
def colBytes (col : List Fp) : List UInt8 := col.flatMap Fp.toBytes

section Verify

variable (H : HIn → Dig) (tag : MTag)

/-- `hash_column_keyed`. -/
def colDigest (col : List Fp) : Dig := H ⟨tag.col, colBytes col⟩

/-- `salt_leaf_keyed`. -/
def saltLeaf (x s : Dig) : Dig := H ⟨tag.leaf, x.toList ++ s.toList⟩

/-- `hash_pair_keyed`. -/
def hashPair (a b : Dig) : Dig := H ⟨tag.node, a.toList ++ b.toList⟩

/-- `verify_path_keyed`'s loop. -/
def foldPath : Dig → ℕ → List Dig → Dig
  | cur, _, [] => cur
  | cur, idx, sib :: rest =>
    foldPath (if idx &&& 1 = 0 then hashPair H tag cur sib else hashPair H tag sib cur) (idx >>> 1) rest

/-- `MerkleTree::verify_path_keyed`. -/
def verifyPath (root : Dig) (idx : ℕ) (leaf : Dig) (path : List Dig) : Bool := decide (foldPath H tag leaf idx path = root)

/-- **One opened column as `verify_zk_tagged` checks it**: the path length (the tree's depth), the column length, and
the path from the column's salted leaf. -/
def verifyColumn (depth rows : ℕ) (root : Dig) (j : ℕ) (col : List Fp) (salt : Dig) (path : List Dig) : Bool :=
  decide (path.length = depth) && decide (col.length = rows)
    && verifyPath H tag root j (saltLeaf H tag (colDigest H tag col) salt) path

/-- `MerkleTree::build_keyed`'s levels, bottom up (for the honest paths of a test; `2^h` leaves). -/
def buildLevels : ℕ → List Dig → List (List Dig)
  | 0, lv => [lv]
  | n + 1, lv =>
    if lv.length ≤ 1 then [lv]
    else lv :: buildLevels n ((List.range (lv.length / 2)).map (fun i =>
      hashPair H tag (lv.getD (2 * i) (List.Vector.replicate 32 0)) (lv.getD (2 * i + 1) (List.Vector.replicate 32 0))))

end Verify

/-! ## The decoders -/

/-- Split bytes into 8-byte words (`fuel ≥` the word count bounds the recursion). -/
def decColAux : ℕ → List UInt8 → List Fp
  | 0, _ => []
  | n + 1, l => if l = [] then [] else ⟨ofLE64 (l.take 8)⟩ :: decColAux n (l.drop 8)

def decCol (l : List UInt8) : List Fp := decColAux l.length l

theorem colBytes_cons (a : Fp) (c : List Fp) : colBytes (a :: c) = le64 a.v ++ colBytes c := rfl

theorem colBytes_length (c : List Fp) : (colBytes c).length = 8 * c.length := by
  induction c with
  | nil => rfl
  | cons a c ih => rw [colBytes_cons, List.length_append, le64_length, ih, List.length_cons]; ring

theorem decColAux_colBytes (c : List Fp) : ∀ n, c.length ≤ n → decColAux n (colBytes c) = c := by
  induction c with
  | nil => intro n _; cases n <;> rfl
  | cons a c ih =>
    intro n hn
    cases n with
    | zero => simp at hn
    | succ n =>
      have hne : colBytes (a :: c) ≠ [] := by
        intro h
        have := congrArg List.length h
        rw [colBytes_length] at this
        simp at this
      simp only [decColAux, hne, ↓reduceIte]
      rw [colBytes_cons, List.take_left' (le64_length _), List.drop_left' (le64_length _), ofLE64_le64,
        ih n (by simpa using hn)]

theorem decCol_colBytes (c : List Fp) : decCol (colBytes c) = c :=
  decColAux_colBytes c _ (by rw [colBytes_length]; omega)

/-- Split 64 bytes into two digests. -/
def splitDig (l : List UInt8) : Option (Dig × Dig) :=
  if h : l.length = 64 then
    some (⟨l.take 32, by simp [h]⟩, ⟨l.drop 32, by simp [h]⟩)
  else none

theorem splitDig_append (x s : Dig) : splitDig (x.toList ++ s.toList) = some (x, s) := by
  obtain ⟨x, hx⟩ := x
  obtain ⟨s, hs⟩ := s
  show splitDig (x ++ s) = some (⟨x, hx⟩, ⟨s, hs⟩)
  have hl : (x ++ s).length = 64 := by simp [hx, hs]
  unfold splitDig
  simp only [hl, ↓reduceDIte, Option.some.injEq]
  exact Prod.ext (Subtype.ext (List.take_left' hx)) (Subtype.ext (List.drop_left' hx))

/-- **The code's commitment encodings as a `MerkleEnc`** (`SoundMerkle.lean`). -/
def merkleEnc (tag : MTag) : MerkleEnc HIn Dig Dig (List Fp) where
  colQ c := ⟨tag.col, colBytes c⟩
  leafQ x s := ⟨tag.leaf, x.toList ++ s.toList⟩
  nodeQ l r := ⟨tag.node, l.toList ++ r.toList⟩
  colDec q := some (decCol q.msg)
  leafDec q := splitDig q.msg
  nodeDec q := splitDig q.msg
  colDec_colQ c := by simp [decCol_colBytes]
  leafDec_leafQ x s := splitDig_append x s
  nodeDec_nodeQ l r := splitDig_append l r

/-! ## The executable check is `Opens` -/

theorem and_one_eq_zero_iff (n : ℕ) : n &&& 1 = 0 ↔ n % 2 = 0 := by rw [Nat.and_one_is_mod]

theorem foldPath_eq_climb (H : HIn → Dig) (tag : MTag) :
    ∀ (path : List Dig) (cur : Dig) (idx : ℕ), foldPath H tag cur idx path = (merkleEnc tag).climb H idx cur path
  | [], _, _ => rfl
  | sib :: rest, cur, idx => by
    rw [foldPath, MerkleEnc.climb, foldPath_eq_climb H tag rest, Nat.shiftRight_eq_div_pow, pow_one]
    congr 1
    unfold MerkleEnc.stepQ
    by_cases h : idx % 2 = 0
    · have h' : idx &&& 1 = 0 := (and_one_eq_zero_iff idx).mpr h
      simp only [h, h', ↓reduceIte]
      rfl
    · have h' : ¬ idx &&& 1 = 0 := fun h' => h ((and_one_eq_zero_iff idx).mp h')
      simp only [h, h', ↓reduceIte]
      rfl

/-- **The executable column check is `SoundMerkle.lean`'s `Opens`**, for every hash function. -/
theorem verifyColumn_iff (H : HIn → Dig) (tag : MTag) (depth rows : ℕ) (root : Dig) (j : ℕ) (col : List Fp)
    (salt : Dig) (path : List Dig) :
    verifyColumn H tag depth rows root j col salt path = true
      ↔ (merkleEnc tag).Opens H depth root j ⟨col, salt, path⟩ ∧ col.length = rows := by
  unfold verifyColumn verifyPath MerkleEnc.Opens
  rw [foldPath_eq_climb]
  simp only [Bool.and_eq_true, decide_eq_true_eq]
  constructor
  · rintro ⟨⟨h1, h2⟩, h3⟩; exact ⟨⟨h1, h3⟩, h2⟩
  · rintro ⟨⟨h1, h3⟩, h2⟩; exact ⟨⟨h1, h2⟩, h3⟩

/-! ## Binding of the executable verifier in the random-oracle model -/

/-- The hash inputs of at most `L` bytes: the oracle's (finite) domain. -/
abbrev QB (L : ℕ) := Option Dig × {l : List UInt8 // l.length ≤ L}

noncomputable instance (L : ℕ) : Fintype {l : List UInt8 // l.length ≤ L} :=
  (List.finite_length_le UInt8 L).fintype

/-- A zero digest. -/
def zeroDig : Dig := List.Vector.replicate 32 0

/-- An oracle on `QB L` as a hash function on all inputs (longer inputs, which the verifier never asks, get `0`). -/
def liftH {L : ℕ} (G : QB L → Dig) (q : HIn) : Dig := if h : q.msg.length ≤ L then G (q.key, ⟨q.msg, h⟩) else zeroDig

/-- A column of `rows` entries. -/
abbrev ColR (rows : ℕ) := {c : List Fp // c.length = rows}

theorem digPair_length (x s : Dig) : (x.toList ++ s.toList).length = 64 := by simp

/-- **The code's encodings into `QB L`**, for `L ≥ 64` and `L ≥ 8·rows`. -/
def merkleEncB (tag : MTag) (L rows : ℕ) (h64 : 64 ≤ L) (hr : 8 * rows ≤ L) : MerkleEnc (QB L) Dig Dig (ColR rows) where
  colQ c := (tag.col, ⟨colBytes c.1, by rw [colBytes_length, c.2]; exact hr⟩)
  leafQ x s := (tag.leaf, ⟨x.toList ++ s.toList, by rw [digPair_length]; exact h64⟩)
  nodeQ l r := (tag.node, ⟨l.toList ++ r.toList, by rw [digPair_length]; exact h64⟩)
  colDec q := if h : (decCol q.2.1).length = rows then some ⟨decCol q.2.1, h⟩ else none
  leafDec q := splitDig q.2.1
  nodeDec q := splitDig q.2.1
  colDec_colQ c := by
    obtain ⟨c, hc⟩ := c
    simp only [decCol_colBytes, hc, ↓reduceDIte]
  leafDec_leafQ x s := splitDig_append x s
  nodeDec_nodeQ l r := splitDig_append l r

theorem liftH_eq {L : ℕ} (G : QB L → Dig) (k : Option Dig) (m : List UInt8) (h : m.length ≤ L) :
    liftH G ⟨k, m⟩ = G (k, ⟨m, h⟩) := by
  unfold liftH
  simp only [h, ↓reduceDIte]

theorem climbB_eq (tag : MTag) (L rows : ℕ) (h64 : 64 ≤ L) (hr : 8 * rows ≤ L) (G : QB L → Dig) :
    ∀ (path : List Dig) (cur : Dig) (idx : ℕ),
      (merkleEncB tag L rows h64 hr).climb G idx cur path = (merkleEnc tag).climb (liftH G) idx cur path
  | [], _, _ => rfl
  | sib :: rest, cur, idx => by
    rw [MerkleEnc.climb, MerkleEnc.climb, climbB_eq tag L rows h64 hr G rest]
    congr 1
    unfold MerkleEnc.stepQ
    split_ifs
    · exact (liftH_eq G _ _ _).symm
    · exact (liftH_eq G _ _ _).symm

/-- On columns of `rows` entries, the bounded encoding's `Opens` is the executable verifier's verdict under `liftH G`. -/
theorem opensB_iff (tag : MTag) (L rows : ℕ) (h64 : 64 ≤ L) (hr : 8 * rows ≤ L) (G : QB L → Dig) (depth : ℕ)
    (root : Dig) (j : ℕ) (o : MerkleOpening Dig Dig (ColR rows)) :
    (merkleEncB tag L rows h64 hr).Opens G depth root j o
      ↔ verifyColumn (liftH G) tag depth rows root j o.col.1 o.salt o.path = true := by
  rw [verifyColumn_iff]
  unfold MerkleEnc.Opens MerkleEnc.leafDigest
  rw [climbB_eq]
  have e1 : liftH G ⟨tag.col, colBytes o.col.1⟩ = G (tag.col, ⟨colBytes o.col.1, _⟩) :=
    liftH_eq G _ _ (by rw [colBytes_length, o.col.2]; exact hr)
  have e2 : ∀ d : Dig, liftH G ⟨tag.leaf, d.toList ++ o.salt.toList⟩
      = G (tag.leaf, ⟨d.toList ++ o.salt.toList, by rw [digPair_length]; exact h64⟩) :=
    fun d => liftH_eq G _ _ _
  have hleaf : G ((merkleEncB tag L rows h64 hr).leafQ (G ((merkleEncB tag L rows h64 hr).colQ o.col)) o.salt)
      = (liftH G) ((merkleEnc tag).leafQ ((liftH G) ((merkleEnc tag).colQ o.col.1)) o.salt) := by
    show _ = liftH G ⟨tag.leaf, (liftH G ⟨tag.col, colBytes o.col.1⟩).toList ++ o.salt.toList⟩
    rw [e1, e2]
    rfl
  rw [hleaf]
  exact ⟨fun h => ⟨h, o.col.2⟩, fun h => h.1⟩

/-- **Binding of the executable Merkle verifier** (`merkle_binding` applied to the code's encodings). In the random-oracle
model on the inputs of at most `L` bytes, an adversary making at most `q` queries outputs a root, a position and two
openings with different columns that both pass `verifyColumn` (with the tree's depth `h`) with probability at most
`collBound (q + 2(h + 2))`. -/
theorem exec_merkle_binding (tag : MTag) (L rows : ℕ) (h64 : 64 ≤ L) (hr : 8 * rows ≤ L) (h q : ℕ)
    (A : OC (QB L) Dig (Dig × ℕ × MerkleOpening Dig Dig (ColR rows) × MerkleOpening Dig Dig (ColR rows)))
    (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => (A.run G).2.2.1.col ≠ (A.run G).2.2.2.col
        ∧ verifyColumn (liftH G) tag h rows (A.run G).1 (A.run G).2.1 (A.run G).2.2.1.col.1 (A.run G).2.2.1.salt
            (A.run G).2.2.1.path = true
        ∧ verifyColumn (liftH G) tag h rows (A.run G).1 (A.run G).2.1 (A.run G).2.2.2.col.1 (A.run G).2.2.2.salt
            (A.run G).2.2.2.path = true)
      ≤ collBound (q + 2 * (h + 2)) Dig := by
  classical
  refine le_trans (MeasureTheory.measure_mono ?_) ((merkleEncB tag L rows h64 hr).merkle_binding h q A hA)
  rintro G ⟨hc, h1, h2⟩
  exact ⟨hc, (opensB_iff tag L rows h64 hr G h _ _ _).mpr h1, (opensB_iff tag L rows h64 hr G h _ _ _).mpr h2⟩

end ZK60.Exec
