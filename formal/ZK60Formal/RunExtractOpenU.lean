/-
D63 lane L24 (2026-11-07), part 5: **the input commitment's opening at the unique-decoding radius**, the deterministic
core of the fix finding L24-1 proposes.

L10's `PlaneCommit.Opens` (the classify instance's `opensIn`) asks EVERY one of the `N` columns to verify against the
statement's root. The verifier opens `Q` of them. A prover that puts one unusable leaf in the tree is accepted unless
that column is drawn, and then no value opens the root in that sense, so the extraction premise O11d (and
`KnowledgeSound` at this instance) cannot hold (L24-1). The opening that an extractor can meet asks all but at most `e`
columns, with `2e + n + Q ≤ N`: the commitment still pins the value down, by the row code's distance.

* `word_eq_of_column_eq`, **`eq_of_columns_agree`**: two admissible values whose columns agree on at least `n + Q`
  positions are equal (the code-distance form of `column_inj`: each data row is a polynomial of degree `< n + Q`);
* `OpensU`, `opensU_of_opens`: the opening at radius `e`; a full opening is one (the honest prover's, for `Complete`);
* **`opensU_diff`**: two different admissible values opening one root at radius `e` have a position where BOTH open and
  their columns differ, so the tree has two different openings there (the step `PlaneCommit.binding` takes to
  `merkle_binding`).

What is left for `Binding` at the radius is the reduction that finds that position (it must check the openings, i.e.
query the tree), and then `KnowledgeSound` through the opening's knowledge (L20's `opening_knowledge_chain_pos`).
Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BindingW16

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Sound
open Polynomial

namespace PlaneCommit

variable {V St Salt : Type} (C : PlaneCommit V St Salt)

/-- Equal columns at a position give equal row words there, row by row. -/
theorem word_eq_of_column_eq {v v' : V} {r r' : Salt} {j : Fin C.N} (h : C.column v r j = C.column v' r' j)
    (i : Fin C.R) : C.word v r i j = C.word v' r' i j := by
  have h1 := congrArg Subtype.val h
  have h2 := congrFun (List.ofFn_injective h1) i
  have h3 := congrArg Fp.toGF h2
  simp only [Fp.toGF_ofGF] at h3
  exact h3

/-- **The code-distance form of `column_inj`**: two admissible values whose columns agree on at least `n + Q`
positions are equal (each data row's word is a polynomial of degree `< n + Q` at distinct points). -/
theorem eq_of_columns_agree {v v' : V} {r r' : Salt} (hv : C.ok v) (hv' : C.ok v') (J : Finset (Fin C.N))
    (hJ : C.n + C.Q ≤ J.card) (h : ∀ j ∈ J, C.column v r j = C.column v' r' j) : v = v' := by
  apply C.plane_inj v v' hv hv'
  funext k
  have hpoly : encPoly C.form (C.msg v r (C.place k)) (C.pad r (C.place k))
      = encPoly C.form (C.msg v' r' (C.place k)) (C.pad r' (C.place k)) := by
    refine eq_of_natDegree_lt_card_of_eval_eq _ _ (f := fun j : J => C.pts j.1)
      (fun a b hab => Subtype.ext (C.hpts hab)) (fun j => ?_) ?_
    · exact C.word_eq_of_column_eq (h j.1 j.2) (C.place k)
    · rw [Fintype.card_coe]
      exact max_lt (lt_of_lt_of_le (encPoly_natDegree_lt C.form C.hn _ _) hJ)
        (lt_of_lt_of_le (encPoly_natDegree_lt C.form C.hn _ _) hJ)
  have hm := (encPoly_inj C.form C.hn hpoly).1
  rwa [C.msg_place, C.msg_place] at hm

/-- **The opening at the unique-decoding radius `e`**: `v` is admissible and all but at most `e` of the `N` columns
verify against the statement's root. -/
def OpensU (L : ℕ) (h64 : 64 ≤ L) (hr : 8 * C.R ≤ L) (e : ℕ) (G : QB L → Dig) (s : St) (v : V) (r : Salt) : Prop :=
  C.ok v ∧ ∃ J : Finset (Fin C.N), C.N ≤ J.card + e ∧ ∀ j ∈ J,
    (merkleEncB C.tag L C.R h64 hr).Opens G C.depth (C.root s) j.val ⟨C.column v r j, C.salt r j, C.path r j⟩

/-- A full opening is an opening at every radius (the honest prover's, for `Complete`). -/
theorem opensU_of_opens (L : ℕ) (h64 : 64 ≤ L) (hr : 8 * C.R ≤ L) (e : ℕ) (G : QB L → Dig) (s : St) (v : V)
    (r : Salt) (h : C.Opens L h64 hr G s v r) : C.OpensU L h64 hr e G s v r :=
  ⟨h.1, Finset.univ, by rw [Finset.card_univ, Fintype.card_fin]; omega, fun j _ => h.2 j⟩

/-- **The deterministic core of `Binding` at the radius**: two different admissible values that open one root at the
radius `e`, `2e + n + Q ≤ N`, have a position where BOTH open and their columns DIFFER: two different openings of one
position of the tree, which `merkle_binding` turns into a collision. -/
theorem opensU_diff (L : ℕ) (h64 : 64 ≤ L) (hr : 8 * C.R ≤ L) (e : ℕ) (he : 2 * e + (C.n + C.Q) ≤ C.N)
    (G : QB L → Dig) (s : St) {v v' : V} {r r' : Salt} (hne : v ≠ v') (h : C.OpensU L h64 hr e G s v r)
    (h' : C.OpensU L h64 hr e G s v' r') :
    ∃ j : Fin C.N, C.column v r j ≠ C.column v' r' j
      ∧ (merkleEncB C.tag L C.R h64 hr).Opens G C.depth (C.root s) j.val ⟨C.column v r j, C.salt r j, C.path r j⟩
      ∧ (merkleEncB C.tag L C.R h64 hr).Opens G C.depth (C.root s) j.val
          ⟨C.column v' r' j, C.salt r' j, C.path r' j⟩ := by
  classical
  obtain ⟨hv, J, hJ, hop⟩ := h
  obtain ⟨hv', J', hJ', hop'⟩ := h'
  by_contra hno
  apply hne
  have h1 := Finset.card_union_add_card_inter J J'
  have h2 : (J ∪ J').card ≤ C.N := by simpa using Finset.card_le_univ (J ∪ J')
  have hcard : C.n + C.Q ≤ (J ∩ J').card := by omega
  refine C.eq_of_columns_agree (r := r) (r' := r') hv hv' (J ∩ J') hcard (fun j hj => ?_)
  rw [Finset.mem_inter] at hj
  by_contra hd
  exact hno ⟨j, hd, hop j hj.1, hop' j hj.2⟩

end PlaneCommit

end ZK60.Exec
