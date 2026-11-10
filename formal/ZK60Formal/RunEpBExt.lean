/-
D63 lane L52 (2026-11-10), part 7: **an extractor of whole Merkle openings (column, salt, path) whose every output the
verifier accepts** (L30-5; finding L52-1; the brief's deliverable 3, the first step of `hops`).

The top theorem's endpoint extractor `ops` must return, for each column, a full opening, and `hops` asks that every
opening it returns opens against the root for EVERY oracle and adversary. L22's descent `extractCol` decodes a found
preimage whatever its domain tag (finding L52-1), so collecting its siblings and salt would not do. Here, for any
Merkle encoding `M`:

* `ebDescP`, **`ebOpenX`**: the TAG-CHECKED descent and extraction: a found preimage is accepted only if it re-encodes
  to itself (`nodeQ l r = y`, `leafQ x s = y`, `colQ c = z`); the siblings are collected bottom up (the path's order,
  `MerkleOpening.path`), the salt is the leaf's;
* **`ebDescP_climb`**, **`ebOpenX_opens`**: on a log consistent with the oracle (`e.2 = H e.1`, as every oracle run's log
  is), every opening `ebOpenX` returns OPENS against the root (`Opens`: the path has the depth, the climb reaches the
  root): deterministically, no event;
* `ebDescP_descend`, **`ebOpenX_col`**: where the checked extraction returns an opening, L22's `extractCol` returns its
  column (the two agree wherever the checked one succeeds);
* `ebOps`, `ebOps_some`, **`eb_hops`**, **`eb_hcan`**: the endpoint's checked extractor at a plane commitment (the top
  theorem's `ops` shape; it also drops columns with a non-canonical entry) and the top theorem's `hops` and `hcan` for
  it, PROVED for every adversary and oracle.

What remains of `hops`, `hread` (NOT done here): the event that the checked extraction misses a column the verifier
accepts, with its bound, and the endpoint's `ops`, `Ux`, `Xx` read from it (the lane doc, §5.3).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunEpBInc

set_option autoImplicit false

namespace ZK60.Sound

namespace MerkleEnc

variable {Q D S Col : Type} (M : MerkleEnc Q D S Col) [DecidableEq Q] [DecidableEq D]

/-- **A found node, checked**: the first logged question whose answer is `t`, decoded as a node `(l, r)`, accepted
only if it IS the node query `nodeQ l r`. -/
def ebNode (L : List (Q × D)) (t : D) : Option (D × D) :=
  (findPre L t).bind fun y => (M.nodeDec y).bind fun lr => if M.nodeQ lr.1 lr.2 = y then some lr else none

/-- **The checked descent with its path**: from a digest `t` at height `h`, the leaf-level digest at position `j` and
the siblings met, bottom up. -/
def ebDescP (L : List (Q × D)) : ℕ → ℕ → D → Option (D × List D)
  | 0, _, t => some (t, [])
  | h + 1, j, t =>
    match M.ebNode L t with
    | some lr =>
      (ebDescP L h j (if (j / 2 ^ h) % 2 = 0 then lr.1 else lr.2)).map
        (fun r => (r.1, r.2 ++ [if (j / 2 ^ h) % 2 = 0 then lr.2 else lr.1]))
    | none => none

/-- **THE TAG-CHECKED EXTRACTION OF AN OPENING** at position `j` of a tree of height `h` with this root: the checked
descent to the salted leaf, its logged preimage checked as `leafQ x s`, the logged preimage of `x` checked as
`colQ c`; the opening `(c, s, path)`. -/
def ebOpenX (L : List (Q × D)) (h j : ℕ) (root : D) : Option (MerkleOpening D S Col) :=
  (M.ebDescP L h j root).bind fun lp =>
    ((findPre L lp.1).bind fun y => (M.leafDec y).bind fun xs => if M.leafQ xs.1 xs.2 = y then some xs else none).bind
      fun xs => ((findPre L xs.1).bind fun z => (M.colDec z).bind fun c => if M.colQ c = z then some c else none).map
        fun c => ⟨c, xs.2, lp.2⟩

omit [DecidableEq Q] in
/-- A found question's oracle answer, on a consistent log. -/
theorem eb_findPre_H (H : Q → D) (L : List (Q × D)) (hL : ∀ e ∈ L, e.2 = H e.1) {t : D} {y : Q}
    (hy : findPre L t = some y) : H y = t := by
  obtain ⟨e, he, he1, he2⟩ := findPre_some hy
  rw [← he1, ← hL e he, he2]

/-- **THE CHECKED DESCENT FOLLOWS A CLIMB**: on a log consistent with the oracle, if the checked descent from `t` at
height `h` returns the leaf-level digest `ℓ` and the path `p`, then `p` has `h` entries and the climb from `ℓ` along
`p` at position `j` reaches `t`. -/
theorem ebDescP_climb (H : Q → D) (L : List (Q × D)) (hL : ∀ e ∈ L, e.2 = H e.1) (j : ℕ) :
    ∀ (h : ℕ) (t ℓ : D) (p : List D), M.ebDescP L h j t = some (ℓ, p) → p.length = h ∧ M.climb H j ℓ p = t
  | 0, t, ℓ, p, hd => by
    simp only [ebDescP, Option.some.injEq, Prod.mk.injEq] at hd
    rw [← hd.1, ← hd.2]
    exact ⟨rfl, rfl⟩
  | h + 1, t, ℓ, p, hd => by
    rcases hn : M.ebNode L t with _ | lr
    · simp only [ebDescP, hn, reduceCtorEq] at hd
    · obtain ⟨y, hy, hy2⟩ := Option.bind_eq_some_iff.mp hn
      obtain ⟨lr', -, hif⟩ := Option.bind_eq_some_iff.mp hy2
      by_cases hq : M.nodeQ lr'.1 lr'.2 = y
      · rw [ite_eq_left hq] at hif
        have hlr : lr' = lr := Option.some.inj hif
        rw [hlr] at hq
        simp only [ebDescP, hn] at hd
        obtain ⟨⟨ℓ', p'⟩, hd', heq⟩ := Option.map_eq_some_iff.mp hd
        simp only [Prod.mk.injEq] at heq
        rw [← heq.1, ← heq.2]
        obtain ⟨hlen, hcl⟩ := ebDescP_climb H L hL j h _ ℓ' p' hd'
        have hst : M.stepQ (j / 2 ^ h) (if (j / 2 ^ h) % 2 = 0 then lr.1 else lr.2)
            (if (j / 2 ^ h) % 2 = 0 then lr.2 else lr.1) = y := by
          unfold stepQ
          by_cases hb : (j / 2 ^ h) % 2 = 0
          · simp only [hb, ↓reduceIte]
            exact hq
          · simp only [hb, ↓reduceIte]
            exact hq
        refine ⟨by simp [hlen], ?_⟩
        rw [M.climb_append, hlen, hcl, hst, eb_findPre_H H L hL hy]
      · rw [ite_eq_right hq] at hif
        cases hif

/-- **EVERY OPENING THE CHECKED EXTRACTION RETURNS OPENS** (the route to `hops`): on a log consistent with the oracle,
an opening `ebOpenX` returns at position `j` of a tree of height `h` verifies against the root. No event: the checks
make it deterministic. -/
theorem ebOpenX_opens (H : Q → D) (L : List (Q × D)) (hL : ∀ e ∈ L, e.2 = H e.1) (h j : ℕ) (root : D)
    (o : MerkleOpening D S Col) (hx : M.ebOpenX L h j root = some o) : M.Opens H h root j o := by
  unfold ebOpenX at hx
  obtain ⟨⟨ℓ, p⟩, hd, hrest⟩ := Option.bind_eq_some_iff.mp hx
  obtain ⟨xs, hxs, hc⟩ := Option.bind_eq_some_iff.mp hrest
  obtain ⟨c, hcol, hco⟩ := Option.map_eq_some_iff.mp hc
  obtain ⟨y, hy, hy2⟩ := Option.bind_eq_some_iff.mp hxs
  obtain ⟨xs', -, hif⟩ := Option.bind_eq_some_iff.mp hy2
  obtain ⟨z, hz, hz2⟩ := Option.bind_eq_some_iff.mp hcol
  obtain ⟨c', -, hif2⟩ := Option.bind_eq_some_iff.mp hz2
  by_cases hq : M.leafQ xs'.1 xs'.2 = y
  · rw [ite_eq_left hq] at hif
    have hxs' : xs' = xs := Option.some.inj hif
    rw [hxs'] at hq
    by_cases hq2 : M.colQ c' = z
    · rw [ite_eq_left hq2] at hif2
      have hcc : c' = c := Option.some.inj hif2
      rw [hcc] at hq2
      obtain ⟨hlen, hcl⟩ := M.ebDescP_climb H L hL j h root ℓ p hd
      rw [← hco]
      refine ⟨hlen, ?_⟩
      show M.climb H j (H (M.leafQ (H (M.colQ c)) xs.2)) p = root
      rw [hq2, eb_findPre_H H L hL hz, hq, eb_findPre_H H L hL hy, hcl]
    · rw [ite_eq_right hq2] at hif2
      cases hif2
  · rw [ite_eq_right hq] at hif
    cases hif

/-- **Where the checked descent succeeds, L22's descent reaches the same leaf** (it reads the same found preimages). -/
theorem ebDescP_descend (L : List (Q × D)) (j : ℕ) :
    ∀ (h : ℕ) (t ℓ : D) (p : List D), M.ebDescP L h j t = some (ℓ, p) → M.descend L h j t = some ℓ
  | 0, t, ℓ, p, hd => by
    simp only [ebDescP, Option.some.injEq, Prod.mk.injEq] at hd
    rw [← hd.1]
    rfl
  | h + 1, t, ℓ, p, hd => by
    rcases hn : M.ebNode L t with _ | lr
    · simp only [ebDescP, hn, reduceCtorEq] at hd
    · obtain ⟨y, hy, hy2⟩ := Option.bind_eq_some_iff.mp hn
      obtain ⟨lr', hdec, hif⟩ := Option.bind_eq_some_iff.mp hy2
      by_cases hq : M.nodeQ lr'.1 lr'.2 = y
      · rw [ite_eq_left hq] at hif
        have hlr : lr' = lr := Option.some.inj hif
        rw [hlr] at hdec
        simp only [ebDescP, hn] at hd
        obtain ⟨⟨ℓ', p'⟩, hd', heq⟩ := Option.map_eq_some_iff.mp hd
        simp only [Prod.mk.injEq] at heq
        rw [← heq.1]
        have hb : (findPre L t).bind M.nodeDec = some lr := by rw [hy, Option.bind_some, hdec]
        rw [descend, hb]
        exact ebDescP_descend L j h _ ℓ' p' hd'
      · rw [ite_eq_right hq] at hif
        cases hif

/-- **Where the checked extraction returns an opening, L22's `extractCol` returns its column.** -/
theorem ebOpenX_col (L : List (Q × D)) (h j : ℕ) (root : D) (o : MerkleOpening D S Col)
    (hx : M.ebOpenX L h j root = some o) : M.extractCol L h j root = some o.col := by
  unfold ebOpenX at hx
  obtain ⟨⟨ℓ, p⟩, hd, hrest⟩ := Option.bind_eq_some_iff.mp hx
  obtain ⟨xs, hxs, hc⟩ := Option.bind_eq_some_iff.mp hrest
  obtain ⟨c, hcol, hco⟩ := Option.map_eq_some_iff.mp hc
  obtain ⟨y, hy, hy2⟩ := Option.bind_eq_some_iff.mp hxs
  obtain ⟨xs', hldec, hif⟩ := Option.bind_eq_some_iff.mp hy2
  obtain ⟨z, hz, hz2⟩ := Option.bind_eq_some_iff.mp hcol
  obtain ⟨c', hcdec, hif2⟩ := Option.bind_eq_some_iff.mp hz2
  by_cases hq : M.leafQ xs'.1 xs'.2 = y
  · rw [ite_eq_left hq] at hif
    have hxs' : xs' = xs := Option.some.inj hif
    rw [hxs'] at hldec
    by_cases hq2 : M.colQ c' = z
    · rw [ite_eq_left hq2] at hif2
      have hcc : c' = c := Option.some.inj hif2
      rw [hcc] at hcdec
      rw [← hco]
      unfold extractCol
      simp only [M.ebDescP_descend L j h root ℓ p hd, Option.bind_some, hy, hldec, hz, hcdec]
    · rw [ite_eq_right hq2] at hif2
      cases hif2
  · rw [ite_eq_right hq] at hif
    cases hif

end MerkleEnc

end ZK60.Sound

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX

section Ops

variable {Hdr V Salt : Type} (Cin : PlaneCommit V (ClsStmt Hdr) Salt) (Lq : ℕ) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)

/-- **The endpoint's checked extractor** (an `ops` of the top theorem): column `j`'s opening, tag-checked, read out of
the prover's log for the root the statement names, at the commitment's tree depth, kept only if its entries are
canonical. -/
noncomputable def ebOps (lg : List (QB Lq × Dig)) (s : ClsStmt Hdr) (j : Fin Cin.N) :
    Option (MerkleOpening Dig Dig (ColR Cin.R)) :=
  ((merkleEncB Cin.tag Lq Cin.R h64 hr).ebOpenX lg Cin.depth j.val (Cin.root s)).bind fun o =>
    if ∀ a ∈ o.col.1, a.Canon then some o else none

/-- What the checked extractor returns: a checked opening with canonical entries. -/
theorem ebOps_some (lg : List (QB Lq × Dig)) (s : ClsStmt Hdr) (j : Fin Cin.N)
    (o : MerkleOpening Dig Dig (ColR Cin.R)) (h : ebOps Cin Lq h64 hr lg s j = some o) :
    (merkleEncB Cin.tag Lq Cin.R h64 hr).ebOpenX lg Cin.depth j.val (Cin.root s) = some o ∧ ∀ a ∈ o.col.1, a.Canon := by
  obtain ⟨o', ho', hif⟩ := Option.bind_eq_some_iff.mp h
  by_cases hc : ∀ a ∈ o'.col.1, a.Canon
  · rw [ite_eq_left hc] at hif
    obtain rfl : o' = o := Option.some.inj hif
    exact ⟨ho', hc⟩
  · rw [ite_eq_right hc] at hif
    cases hif

/-- **`hops` FOR THE CHECKED EXTRACTOR** (the top theorem's premise, in its form): every opening it returns on the
prover's log opens against the statement's root, for every adversary and oracle (`ebOpenX_opens`; the log answers
the oracle: `OC.runLog_answer`). -/
theorem eb_hops : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) (j : Fin Cin.N)
    (o : MerkleOpening Dig Dig (ColR Cin.R)),
    ebOps Cin Lq h64 hr (A.runLog G).2 (A.runLog G).1.1 j = some o →
      (merkleEncB Cin.tag Lq Cin.R h64 hr).Opens G Cin.depth (Cin.root (A.runLog G).1.1) j.val o :=
  fun A G j o h => (merkleEncB Cin.tag Lq Cin.R h64 hr).ebOpenX_opens G _ (OC.runLog_answer G A) _ _ _ o
    (ebOps_some Cin Lq h64 hr _ _ j o h).1

/-- **`hcan` FOR THE CHECKED EXTRACTOR**: every entry of every opening it returns is canonical. -/
theorem eb_hcan : ∀ (lg : List (QB Lq × Dig)) (s : ClsStmt Hdr) (j : Fin Cin.N) (o : MerkleOpening Dig Dig (ColR Cin.R)),
    ebOps Cin Lq h64 hr lg s j = some o → ∀ a ∈ o.col.1, a.Canon :=
  fun lg s j o h => (ebOps_some Cin Lq h64 hr lg s j o h).2

end Ops

end ZK60.ProtocolClassify
