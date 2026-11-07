/-
D63 lane L22 (2026-11-07), part 5: **the extraction failure at the block verifier's queries** (L16-8).

L16's `extract_fail_run` bounds, for ANY run `A.bind V` and any roots, the event "an opened column verifies against a
root the prover output, all its queries were asked, and it is not the column extracted from the prover's log cut at
that root's first absorption". Here it is instantiated at the block verifier:

* `ColV`, `merkleEncV`: ONE Merkle encoding of the code's commitments on `QB L` for columns of any length up to `L/8`
  words, so that `A`, `H` and `M` (different row counts) share one extraction event with `nr = 3` roots;
* `climbV_eq`, **`opensV_of_exec`**: an opened column the executable check accepts (`verifyPath` with the tree's
  depth) is `Opens` of this encoding;
* `colsV`, `blockV`, `blockV_bounded`: the verifier's Merkle work as an oracle computation: `checkAll` of the first
  `nc` opened columns of each opening (the shape's count), at most `nA·(dA + 2) + nH·(dH + 2) + nM·(dM + 2)` queries;
* `rootsV`, `EvXB`, **`extract_fail_block`**: the extraction failure at the block verifier's queries has probability at
  most `collBound T' + (2T'² + 4T')/|Dig|`, `T' = q + nA(dA + 2) + nH(dH + 2) + nM(dM + 2)`;
* **`opened_eq_extracted`**: outside that event, every opened column of an opening (among the first `nc`, fitting
  `L`) that the executable check accepts IS the extracted one;
* `rootAt`, `colX`, **`colX_stable`**: the extracted column at an index, with the root and the cut read off the chain
  (`absAt`, `cutO`): frozen once the chain's first entries are logged (L16's `cutO_stable`), so it is an admissible
  extraction for the chain theorems.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.LinkW16Parse

set_option autoImplicit false

namespace ZK60.Exec.Link

open ZK60.Sound
open ZK60.Exec
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## One Merkle encoding for every commitment of the block -/

/-- A column of at most `L/8` words. -/
abbrev ColV (L : ℕ) := {c : List Fp // 8 * c.length ≤ L}

/-- **The code's commitment encodings on `QB L`, for columns of any length up to `L/8` words.** -/
def merkleEncV (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) : MerkleEnc (QB L) Dig Dig (ColV L) where
  colQ c := (tag.col, ⟨colBytes c.1, by rw [colBytes_length]; exact c.2⟩)
  leafQ x s := (tag.leaf, ⟨x.toList ++ s.toList, by rw [digPair_length]; exact h64⟩)
  nodeQ l r := (tag.node, ⟨l.toList ++ r.toList, by rw [digPair_length]; exact h64⟩)
  colDec q := if h : 8 * (decCol q.2.1).length ≤ L then some ⟨decCol q.2.1, h⟩ else none
  leafDec q := splitDig q.2.1
  nodeDec q := splitDig q.2.1
  colDec_colQ c := by
    obtain ⟨c, hc⟩ := c
    simp only [decCol_colBytes, hc, ↓reduceDIte]
  leafDec_leafQ x s := splitDig_append x s
  nodeDec_nodeQ l r := splitDig_append l r

theorem climbV_eq (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (G : QB L → Dig) :
    ∀ (path : List Dig) (cur : Dig) (idx : ℕ),
      (merkleEncV tag L h64).climb G idx cur path = (merkleEnc tag).climb (liftH G) idx cur path
  | [], _, _ => rfl
  | sib :: rest, cur, idx => by
    rw [MerkleEnc.climb, MerkleEnc.climb, climbV_eq tag L h64 G rest]
    congr 1
    unfold MerkleEnc.stepQ
    split_ifs
    · exact (liftH_eq G _ _ _).symm
    · exact (liftH_eq G _ _ _).symm

/-- **An opened column the executable check accepts is `Opens`** of the encoding. -/
theorem opensV_of_exec (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (G : QB L → Dig) (depth : ℕ) (root : Dig) (j : ℕ)
    (col : List Fp) (hcol : 8 * col.length ≤ L) (salt : Dig) (path : List Dig) (hl : path.length = depth)
    (hv : verifyPath (liftH G) tag root j (saltLeaf (liftH G) tag (colDigest (liftH G) tag col) salt) path = true) :
    (merkleEncV tag L h64).Opens G depth root j ⟨⟨col, hcol⟩, salt, path⟩ := by
  have e1 : G ((merkleEncV tag L h64).colQ ⟨col, hcol⟩) = liftH G ⟨tag.col, colBytes col⟩ :=
    (liftH_eq G _ _ _).symm
  have e2 : G ((merkleEncV tag L h64).leafQ (G ((merkleEncV tag L h64).colQ ⟨col, hcol⟩)) salt)
      = saltLeaf (liftH G) tag (colDigest (liftH G) tag col) salt := by
    rw [e1]
    exact (liftH_eq G _ _ _).symm
  refine ⟨hl, ?_⟩
  show (merkleEncV tag L h64).climb G j
    (G ((merkleEncV tag L h64).leafQ (G ((merkleEncV tag L h64).colQ ⟨col, hcol⟩)) salt)) path = root
  rw [climbV_eq, e2, ← foldPath_eq_climb]
  simpa [verifyPath] using hv

/-! ## The verifier's Merkle work as an oracle computation -/

section Run

variable (tag : MTag) (L : ℕ) (h64 : 64 ≤ L)

/-- The first `nc` opened columns that fit `L`, as openings of the encoding. -/
noncomputable def colsV (nc : ℕ) (cs : List Block.Column) : List (ℕ × MerkleOpening Dig Dig (ColV L)) :=
  (cs.take nc).filterMap (fun c =>
    haveI := Classical.propDecidable (8 * c.col.length ≤ L)
    if h : 8 * c.col.length ≤ L then some (c.j, ⟨⟨c.col, h⟩, c.salt, c.path⟩) else none)

theorem colsV_length (nc : ℕ) (cs : List Block.Column) : (colsV L nc cs).length ≤ nc :=
  (List.length_filterMap_le _ _).trans (List.length_take_le _ _)

theorem mem_colsV (nc : ℕ) (cs : List Block.Column) (k : ℕ) (hk : k < nc) (hkl : k < cs.length)
    (hfit : 8 * (cs.getD k ⟨0, [], zeroDig, []⟩).col.length ≤ L) :
    ((cs.getD k ⟨0, [], zeroDig, []⟩).j,
      (⟨⟨(cs.getD k ⟨0, [], zeroDig, []⟩).col, hfit⟩, (cs.getD k ⟨0, [], zeroDig, []⟩).salt,
        (cs.getD k ⟨0, [], zeroDig, []⟩).path⟩ : MerkleOpening Dig Dig (ColV L))) ∈ colsV L nc cs := by
  unfold colsV
  refine List.mem_filterMap.mpr ⟨cs.getD k ⟨0, [], zeroDig, []⟩, ?_, ?_⟩
  · rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hkl, Option.getD_some]
    exact List.mem_iff_getElem.mpr ⟨k, by rw [List.length_take]; omega, by rw [List.getElem_take]⟩
  · have hfit' := hfit
    simp only [List.getD_eq_getElem?_getD] at hfit'
    simp [hfit']

/-- **The block verifier's Merkle work**: `checkAll` of the first `nA`, `nH`, `nM` opened columns of `A`, `H`, `M`, at
their trees' depths. -/
noncomputable def blockV (nA nH nM dA dH dM : ℕ) (out : List Op × Block.Core) : OC (QB L) Dig Unit :=
  ((merkleEncV tag L h64).checkAll dA (colsV L nA out.2.aOpen.columns)).bind (fun _ =>
    ((merkleEncV tag L h64).checkAll dH (colsV L nH out.2.hOpen.columns)).bind (fun _ =>
      (merkleEncV tag L h64).checkAll dM (colsV L nM out.2.maskOpen.columns)))

theorem blockV_bounded (nA nH nM dA dH dM : ℕ) (out : List Op × Block.Core) :
    (blockV tag L h64 nA nH nM dA dH dM out).Bounded (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) := by
  unfold blockV
  refine OC.Bounded.bind (((merkleEncV tag L h64).checkAll_bounded dA _).mono
    (Nat.mul_le_mul_right _ (colsV_length L nA _))) (fun _ => ?_)
  exact OC.Bounded.bind (((merkleEncV tag L h64).checkAll_bounded dH _).mono
    (Nat.mul_le_mul_right _ (colsV_length L nH _))) (fun _ => ((merkleEncV tag L h64).checkAll_bounded dM _).mono
      (Nat.mul_le_mul_right _ (colsV_length L nM _)))

/-- The block's three roots, as the prover output them. -/
def rootsV (out : List Op × Block.Core) : List Dig := [out.2.aRoot, out.2.hRoot, out.2.maskRoot]

variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
  (hL : (startMsg domain).length ≤ L)

/-- **The extraction failure at the block verifier's queries** (L16-8): an opened column verifies against one of the
block's roots, all its queries were asked by the prover or by the verifier's Merkle work, and it is not the column
extracted from the prover's log cut at that root's first absorption. -/
def EvXB (nA nH nM dA dH dM : ℕ) (A : OC (QB L) Dig (List Op × Block.Core)) (G : QB L → Dig) : Prop :=
  ∃ r ∈ rootsV (A.run G), ∃ (h j : ℕ) (o : MerkleOpening Dig Dig (ColV L)), (merkleEncV tag L h64).Opens G h r j o
    ∧ (∀ v ∈ (merkleEncV tag L h64).openQs G j o,
        v ∈ OC.queries G (A.bind (blockV tag L h64 nA nH nM dA dH dM)))
    ∧ (merkleEncV tag L h64).extractCol (cutAt (absD (chainEncB key domain hs L hL)) r (A.runLog G).2) h j r
      ≠ some o.col

/-- **The extraction failure at the block verifier's queries is rare** (`extract_fail_run` at `V = blockV`, three
roots): at most `collBound T' + (2T'² + 4T')/|Dig|` for `T' = q + nA(dA + 2) + nH(dH + 2) + nM(dM + 2)`. -/
theorem extract_fail_block (nA nH nM dA dH dM q : ℕ) (A : OC (QB L) Dig (List Op × Block.Core)) (hA : A.Bounded q) :
    prH (EvXB tag L h64 key domain hs hL nA nH nM dA dH dM A)
      ≤ collBound (q + (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2)))) Dig
        + ((2 * (q + (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))))
            * (q + (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))))
          + (1 + 3) * (q + (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2)))) : ℕ) : ℝ≥0∞) / Fintype.card Dig := by
  classical
  exact extract_fail_run (merkleEncV tag L h64) (absD (chainEncB key domain hs L hL)) A rootsV 3
    (fun _ => le_rfl) (blockV tag L h64 nA nH nM dA dH dM) _ (OC.Bounded.bind hA (blockV_bounded tag L h64 nA nH nM dA dH dM))

/-- **Outside the extraction failure, an accepted opened column IS the extracted one** (for an opening whose
columns the verifier's Merkle work checks: the first `nc` of `A`, `H` or `M`). -/
theorem opened_eq_extracted (nA nH nM dA dH dM : ℕ) (A : OC (QB L) Dig (List Op × Block.Core)) (G : QB L → Dig)
    (hX : ¬ EvXB tag L h64 key domain hs hL nA nH nM dA dH dM A G) (r : Dig) (hr : r ∈ rootsV (A.run G)) (d j : ℕ)
    (o : MerkleOpening Dig Dig (ColV L)) (hop : (merkleEncV tag L h64).Opens G d r j o)
    (hq : ∀ v ∈ (merkleEncV tag L h64).openQs G j o,
      v ∈ OC.queries G (A.bind (blockV tag L h64 nA nH nM dA dH dM))) :
    (merkleEncV tag L h64).extractCol (cutAt (absD (chainEncB key domain hs L hL)) r (A.runLog G).2) d j r
      = some o.col := by
  by_contra hne
  exact hX ⟨r, hr, d, j, o, hop, hq, hne⟩

/-- The verifier's Merkle work asks every checked column's queries (`A`'s; `H`'s and `M`'s alike). -/
theorem blockV_queries_A (nA nH nM dA dH dM : ℕ) (A : OC (QB L) Dig (List Op × Block.Core)) (G : QB L → Dig)
    (jo : ℕ × MerkleOpening Dig Dig (ColV L)) (hjo : jo ∈ colsV L nA (A.run G).2.aOpen.columns)
    (hl : jo.2.path.length = dA) :
    ∀ v ∈ (merkleEncV tag L h64).openQs G jo.1 jo.2, v ∈ OC.queries G (A.bind (blockV tag L h64 nA nH nM dA dH dM)) := by
  intro v hv
  have h1 := (merkleEncV tag L h64).checkAll_queries G dA _ jo hjo hl v hv
  simp only [blockV, OC.queries_bind, List.mem_append]
  exact Or.inr (Or.inl h1)

theorem blockV_queries_H (nA nH nM dA dH dM : ℕ) (A : OC (QB L) Dig (List Op × Block.Core)) (G : QB L → Dig)
    (jo : ℕ × MerkleOpening Dig Dig (ColV L)) (hjo : jo ∈ colsV L nH (A.run G).2.hOpen.columns)
    (hl : jo.2.path.length = dH) :
    ∀ v ∈ (merkleEncV tag L h64).openQs G jo.1 jo.2, v ∈ OC.queries G (A.bind (blockV tag L h64 nA nH nM dA dH dM)) := by
  intro v hv
  have h1 := (merkleEncV tag L h64).checkAll_queries G dH _ jo hjo hl v hv
  simp only [blockV, OC.queries_bind, List.mem_append]
  exact Or.inr (Or.inr (Or.inl h1))

theorem blockV_queries_M (nA nH nM dA dH dM : ℕ) (A : OC (QB L) Dig (List Op × Block.Core)) (G : QB L → Dig)
    (jo : ℕ × MerkleOpening Dig Dig (ColV L)) (hjo : jo ∈ colsV L nM (A.run G).2.maskOpen.columns)
    (hl : jo.2.path.length = dM) :
    ∀ v ∈ (merkleEncV tag L h64).openQs G jo.1 jo.2, v ∈ OC.queries G (A.bind (blockV tag L h64 nA nH nM dA dH dM)) := by
  intro v hv
  have h1 := (merkleEncV tag L h64).checkAll_queries G dM _ jo hjo hl v hv
  simp only [blockV, OC.queries_bind, List.mem_append]
  exact Or.inr (Or.inr (Or.inr h1))

end Run

/-! ## The extracted columns, read off the chain -/

section Read

variable (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)

/-- The root a chain prefix absorbs at position `i`, as a digest. -/
def rootAt (hdr : List (TItem × Dig)) (i : ℕ) : Option Dig := (Block.absAt hdr i).bind digOf?

/-- **The column extracted at index `j`** for the root the header absorbs at position `i`: the prover's log cut at that
root's first absorption (`cutO`), the encoding's straight-line extraction at depth `d`. -/
noncomputable def colX (d i : ℕ) (log : List (QB L × Dig)) (hdr : List (TItem × Dig)) (j : ℕ) : Option (ColV L) :=
  match rootAt hdr i with
  | some r => (merkleEncV tag L h64).extractCol (Block.cutO (Block.absOfC (chainEncB key domain hs L hL))
      (Block.absAt hdr i) log) d j r
  | none => none

/-- On a header absorbing the root `r` at position `i`, the extracted column is the one the extraction failure speaks
of (the cut at `r`'s first absorption, `cutAt_absD`). -/
theorem colX_root (d i : ℕ) (log : List (QB L × Dig)) (hdr : List (TItem × Dig)) (r : Dig)
    (hr : Block.absAt hdr i = some r.toList) (j : ℕ) :
    colX tag L h64 key domain hs hL d i log hdr j
      = (merkleEncV tag L h64).extractCol (cutAt (absD (chainEncB key domain hs L hL)) r log) d j r := by
  have hroot : rootAt hdr i = some r := by
    rw [rootAt, hr]
    exact digOf?_toList r
  unfold colX
  rw [hroot]
  simp only
  rw [hr, cutAt_absD]
  rfl

/-- **The extracted column is frozen once the chain's first `s` entries are logged** (`s > i`): any longer log of the
prover, and any continuation of the chain, give the same column (L16's `cutO_stable`). -/
theorem colX_stable (d i s : ℕ) (hi : i < s) (G : QB L → Dig) (τ : List (ItB L × Dig)) (qs : List (QB L))
    (hc : (chainEncB key domain hs L hL).Chain G τ qs) (hτ : τ.length = s) (P P' : List (QB L × Dig))
    (hq : ∀ y ∈ qs, y ∈ P.map Prod.fst) (hpre : P <+: P') {γ : Type} (A : OC (QB L) Dig γ)
    (ext : List (TItem × Dig)) (a : ℕ) (ha : s ≤ a) (j : ℕ) :
    colX tag L h64 key domain hs hL d i (proverLog A P) ((τ.map (toTE (fun it : ItB L => it.1)) ++ ext).take a) j
      = colX tag L h64 key domain hs hL d i (proverLog A P') ((τ.map (toTE (fun it : ItB L => it.1)) ++ ext).take a) j := by
  have habs : Block.absAt ((τ.map (toTE (fun it : ItB L => it.1)) ++ ext).take a) i = Block.absAt (τ.map entB) i := by
    unfold Block.absAt
    have hl : i < (τ.map (toTE (fun it : ItB L => it.1))).length := by rw [List.length_map]; omega
    rw [List.getElem?_take_of_lt (by omega), List.getElem?_append_left hl]
    rfl
  unfold colX rootAt
  rw [habs, Block.cutO_stable (chainEncB key domain hs L hL) G τ qs hc P P' hq hpre A i]

end Read

/-! ## The numbers -/

/-- The verifier's Merkle queries at W16R2 (`A`, `H`: 280 columns, trees of depth 15; `M`: 256 columns, depth 12):
`13,104`, within `2^22·(q + 1)`. -/
theorem xfail_T_w16r2 (q : ℕ) : q + (280 * (15 + 2) + (280 * (15 + 2) + 256 * (12 + 2))) ≤ 2 ^ 22 * (q + 1) := by
  omega

/-- At R13 (`A`, `H`: 256 columns, depth 16; `M` as at W16R2): `12,800`. -/
theorem xfail_T_r13 (q : ℕ) : q + (256 * (16 + 2) + (256 * (16 + 2) + 256 * (12 + 2))) ≤ 2 ^ 22 * (q + 1) := by
  omega

/-- **The extraction failure at the block verifier's queries, at W16R2, against the target's units**: at most
`(q + 1)·(2^14 + 2^16)/2^126` for `q < 2^100` (L20's `xfail_le_u126`; L20's budget already counts it). -/
theorem extract_fail_block_w16r2 (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) (q : ℕ) (hq : q < 2 ^ 100)
    (A : OC (QB L) Dig (List Op × Block.Core)) (hA : A.Bounded q) :
    prH (EvXB tag L h64 key domain hs hL 280 280 256 15 15 12 A) ≤ u126 q (2 ^ 14 + 2 ^ 16) :=
  (extract_fail_block tag L h64 key domain hs hL 280 280 256 15 15 12 q A hA).trans
    (xfail_le_u126 q _ 3 hq (xfail_T_w16r2 q) le_rfl)

/-- The same at R13's opening geometry (256 columns of depth 16). -/
theorem extract_fail_block_r13 (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) (q : ℕ) (hq : q < 2 ^ 100)
    (A : OC (QB L) Dig (List Op × Block.Core)) (hA : A.Bounded q) :
    prH (EvXB tag L h64 key domain hs hL 256 256 256 16 16 12 A) ≤ u126 q (2 ^ 14 + 2 ^ 16) :=
  (extract_fail_block tag L h64 key domain hs hL 256 256 256 16 16 12 q A hA).trans
    (xfail_le_u126 q _ 3 hq (xfail_T_r13 q) le_rfl)

end ZK60.Exec.Link
