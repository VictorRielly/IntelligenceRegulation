/-
D63 lane L51 (2026-11-10), part 3: **the extraction of a root the transcript absorbs INSIDE a longer message**: the
general version of L22's `colX` that the code's header needs if the code is left as it is (finding L51-1, repair B).

The code's run header absorbs the input root only as the last 32 bytes of `expected-IO` (`RunAbsHdr.lean`). L22's run
extraction `colX` reads a root only from a 32-byte absorb (`rootAt`), and the run's extraction failure `EvXR` (L27) cuts
the prover's log at the first EXACT absorption of the root (`absD`). Neither sees the input root. Here, for any reader
`rd` of a root out of an absorbed message:

* `ab_cutAt_cons`, **`ab_cut_coarse`**: the log cut at a message's first absorption fixes the cut at the first
  absorption of anything the message reads as (a list fact);
* `absMOf`, **`colXM`**: the extraction at the root the header's message at position `i` reads as, from the prover's
  log cut at that root's first absorption under `rd`; **`colXM_digOf`**: at the 32-byte reader `digOf?` it IS L22's
  `colX` (so this is a generalization); **`colXM_cutEq`**, `colXM_cutReads`: it is a cut reader (L30's `CutReads`)
  for EVERY reader, so the stability L30 proved for `colX` carries;
* `abRdIn`, **`abRdIn_expMsg`**: the input root's reader, `expected-IO`'s last 32 bytes after its tag;
* `EvXM`, **`extract_fail_xm`**, **`extract_fail_xm_u126`**: the extraction failure at the run's queries for roots read
  by `rd`, and its bound by L16's `extract_fail_run` (which is generic in the reader): at most
  `(q + 1)·(2^16 + 2^18)/2^126` for one more root list of at most `2^100` roots, with the run verifier's Merkle work;
* **`ab_xok_in`**: outside `EvXM`, every sampled column that verifies against a root the header shows under `rd` is the
  extracted one (`rx_xok` for `colXM`).

What repair B still needs (NOT done here): an opening kind of the run whose extracted matrix is `colXM` (L43's
`rkOpen` reads `colX`), `rh_opB_alive` for it, `rkData` with part `0`'s closing opening of that kind, and the top
theorem with `EvXM` added to its extraction event and `u126 q (2^16 + 2^18)` to its bound.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunAbsHdr

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound

/-! ## Cuts at a message and at what it reads as -/

section Cut

variable {Q D β γ : Type} [DecidableEq β] [DecidableEq γ]

theorem ab_cutAt_cons (f : Q → Option β) (m : β) (e : Q × D) (P : List (Q × D)) :
    cutAt f m (e :: P) = if f e.1 = some m then [] else e :: cutAt f m P := by
  unfold cutAt
  rw [List.findIdx_cons]
  by_cases h : f e.1 = some m
  · simp [isAbsAt, h]
  · simp [isAbsAt, h]

/-- **THE CUT AT A MESSAGE FIXES THE CUT AT WHAT IT READS AS**: if every query that absorbs `m` reads as `r`, the log
cut at the first query reading as `r` is the cut of the log cut at the first absorption of `m`. -/
theorem ab_cut_coarse (f : Q → Option β) (g : Q → Option γ) (m : β) (r : γ)
    (hfg : ∀ y, f y = some m → g y = some r) : ∀ P : List (Q × D), cutAt g r P = cutAt g r (cutAt f m P)
  | [] => by simp [cutAt]
  | e :: P => by
    rw [ab_cutAt_cons f m e P]
    by_cases hf : f e.1 = some m
    · rw [ite_eq_left hf, ab_cutAt_cons g r e P, ite_eq_left (hfg _ hf)]
      simp [cutAt]
    · rw [ite_eq_right hf, ab_cutAt_cons g r e P, ab_cutAt_cons g r e (cutAt f m P)]
      by_cases hg : g e.1 = some r
      · rw [ite_eq_left hg, ite_eq_left hg]
      · rw [ite_eq_right hg, ite_eq_right hg, ab_cut_coarse f g m r hfg P]

/-- Two logs with the same cut at `m` have the same cut at `r`. -/
theorem ab_cut_coarse_eq (f : Q → Option β) (g : Q → Option γ) (m : β) (r : γ)
    (hfg : ∀ y, f y = some m → g y = some r) (P P' : List (Q × D)) (h : cutAt f m P = cutAt f m P') :
    cutAt g r P = cutAt g r P' := by
  rw [ab_cut_coarse f g m r hfg P, ab_cut_coarse f g m r hfg P', h]

end Cut

/-! ## The extraction at a root read out of a message -/

section ColXM

variable (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)

/-- **The root a query absorbs, under a reader `rd`**: its absorbed message, read by `rd`. -/
def absMOf (rd : List UInt8 → Option Dig) (y : QB L) : Option Dig :=
  (Block.absOfC (chainEncB key domain hs L hL) y).bind rd

/-- **The column extracted at index `j`** for the root the header's message at position `i` reads as (under `rd`): the
prover's log cut at that root's first absorption under `rd`, the encoding's straight-line extraction at depth `d`. -/
noncomputable def colXM (rd : List UInt8 → Option Dig) (d i : ℕ) (log : List (QB L × Dig)) (hdr : List (TItem × Dig))
    (j : ℕ) : Option (ColV L) :=
  match (Block.absAt hdr i).bind rd with
  | some r => (merkleEncV tag L h64).extractCol (cutAt (absMOf L key domain hs hL rd) r log) d j r
  | none => none

/-- **At the 32-byte reader it is L22's `colX`.** -/
theorem colXM_digOf (d i : ℕ) (log : List (QB L × Dig)) (hdr : List (TItem × Dig)) (j : ℕ) :
    colXM tag L h64 key domain hs hL digOf? d i log hdr j = colX tag L h64 key domain hs hL d i log hdr j := by
  have hr : rootAt hdr i = (Block.absAt hdr i).bind digOf? := rfl
  unfold colXM colX
  rw [hr]
  rcases h : (Block.absAt hdr i).bind digOf? with _ | r
  · rfl
  · have hx : Block.absAt hdr i = some r.toList := (bind_digOf_eq_iff _ r).mp h
    have e : cutAt (absMOf L key domain hs hL digOf?) r log
        = cutAt (Block.absOfC (chainEncB key domain hs L hL)) r.toList log :=
      cutAt_absD (chainEncB key domain hs L hL) r log
    simp only
    rw [e, hx]
    rfl

/-- **`colXM` is a cut reader** (for every reader `rd`): two logs with the same cuts at the messages the header shows
extract the same column. -/
theorem colXM_cutEq (rd : List UInt8 → Option Dig) (d i : ℕ) (hdr : List (TItem × Dig)) (P P' : List (QB L × Dig))
    (h : CutEq (Block.absOfC (chainEncB key domain hs L hL)) hdr P P') (j : ℕ) :
    colXM tag L h64 key domain hs hL rd d i P hdr j = colXM tag L h64 key domain hs hL rd d i P' hdr j := by
  unfold colXM
  rcases hx : Block.absAt hdr i with _ | x
  · rfl
  · simp only [Option.bind_some]
    rcases hr : rd x with _ | r
    · rfl
    · simp only
      have hc := h i
      rw [hx] at hc
      have hfg : ∀ y, Block.absOfC (chainEncB key domain hs L hL) y = some x → absMOf L key domain hs hL rd y = some r :=
        fun y hy => by rw [absMOf, hy, Option.bind_some, hr]
      rw [ab_cut_coarse_eq _ _ x r hfg P P' hc]

/-- **The extracted matrix of a reader is a cut reader** (L30's `CutReads`). -/
theorem colXM_cutReads (rd : List UInt8 → Option Dig) (d i : ℕ) :
    CutReads (Block.absOfC (chainEncB key domain hs L hL))
      (fun P hdr => fun j => colXM tag L h64 key domain hs hL rd d i P hdr j) := by
  intro P P' hdr h
  funext j
  exact colXM_cutEq tag L h64 key domain hs hL rd d i hdr P P' h j

end ColXM

/-! ## The input root's reader -/

/-- **`expected-IO`'s root**: after the 20-byte tag and the 32-byte input endpoint spec digest, the last 32 bytes. -/
def abRdIn (x : List UInt8) : Option Dig := if x.take 20 = abExpTag then digOf? ((x.drop 20).drop 32) else none

theorem abRdIn_expMsg (d r : Dig) : abRdIn (abExpMsg d r) = some r := by
  have ht : abExpTag.length = 20 := rfl
  have hd : d.toList.length = 32 := d.2
  have e1 : (abExpMsg d r).take 20 = abExpTag := by
    rw [abExpMsg]
    exact List.take_left' ht
  have e2 : ((abExpMsg d r).drop 20).drop 32 = r.toList := by
    rw [abExpMsg, List.drop_left' ht, List.drop_left' hd]
  rw [abRdIn, ite_eq_left e1, e2, digOf?_toList]

/-- **At the code's header the reader reads the statement's input root at position `1`.** -/
theorem ab_rdIn_at1 {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
    (hw : Hdr → ClsHdrW) (R : RtRun V key domain Lq) (hR : ∀ s, R.hdr s = clsHdrOf hw s)
    (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ())
    (n : ℕ) (hn : 1 < n) :
    (Block.absAt ((R.tr G (s, segs)).take n) 1).bind abRdIn = some s.inRoot := by
  rw [ab_inAbs hw R hR G s segs hE n hn, Option.bind_some, abRdIn_expMsg]

/-! ## The extraction failure under a reader, and its bound -/

section Fail

variable (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) {α : Type}

/-- **The extraction failure under a reader** (`EvXR` with the cut at the first absorption under `rd`): an opened
column verifies against one of the roots `rx`, all its queries were asked by the prover or by the run verifier's Merkle
work, and it is not the column extracted from the prover's log cut at that root's first absorption under `rd`. -/
def EvXM (rd : List UInt8 → Option Dig) (nA nH nM dA dH dM n : ℕ) (coreOf : α → ℕ → List Op × Block.Core)
    (Vx : α → OC (QB L) Dig Unit) (rx : α → List Dig) (A : OC (QB L) Dig α) (G : QB L → Dig) : Prop :=
  ∃ r ∈ rx (A.run G), ∃ (h j : ℕ) (o : MerkleOpening Dig Dig (ColV L)),
    (merkleEncV tag L h64).Opens G h r j o
    ∧ (∀ v ∈ (merkleEncV tag L h64).openQs G j o,
        v ∈ OC.queries G (A.bind (runV tag L h64 nA nH nM dA dH dM n coreOf Vx)))
    ∧ (merkleEncV tag L h64).extractCol (cutAt (absMOf L key domain hs hL rd) r (A.runLog G).2) h j r ≠ some o.col

/-- **The extraction failure under a reader is rare** (L16's `extract_fail_run`, generic in the reader). -/
theorem extract_fail_xm (rd : List UInt8 → Option Dig) (nA nH nM dA dH dM n : ℕ)
    (coreOf : α → ℕ → List Op × Block.Core) (Vx : α → OC (QB L) Dig Unit) (nx : ℕ) (hVx : ∀ o, (Vx o).Bounded nx)
    (rx : α → List Dig) (nrx : ℕ) (hrx : ∀ o, (rx o).length ≤ nrx) (q : ℕ) (A : OC (QB L) Dig α)
    (hA : A.Bounded q) :
    prH (EvXM tag L h64 key domain hs hL rd nA nH nM dA dH dM n coreOf Vx rx A)
      ≤ collBound (q + (n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) + nx)) Dig
        + ((2 * (q + (n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) + nx))
            * (q + (n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) + nx))
          + (1 + nrx) * (q + (n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) + nx)) : ℕ) : ℝ≥0∞)
          / Fintype.card Dig := by
  classical
  exact extract_fail_run (merkleEncV tag L h64) (absMOf L key domain hs hL rd) A rx nrx hrx
    (runV tag L h64 nA nH nM dA dH dM n coreOf Vx) _
    (OC.Bounded.bind hA (runV_bounded tag L h64 nA nH nM dA dH dM n coreOf Vx nx hVx))

/-- **The extraction failure under a reader in the target's units**: for `q + 1 ≤ 2^102`, the run verifier's Merkle
work within `2^22` queries and at most `2^100` roots, at most `(q + 1)·(2^16 + 2^18)/2^126`: the same as `EvXR`'s, so
repair B adds `u126 q (2^16 + 2^18)` to the run's count. -/
theorem extract_fail_xm_u126 (rd : List UInt8 → Option Dig) (nA nH nM dA dH dM n : ℕ)
    (coreOf : α → ℕ → List Op × Block.Core) (Vx : α → OC (QB L) Dig Unit) (nx : ℕ) (hVx : ∀ o, (Vx o).Bounded nx)
    (rx : α → List Dig) (nrx : ℕ) (hrx : ∀ o, (rx o).length ≤ nrx)
    (hT : n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) + nx ≤ 2 ^ 22) (hnr : nrx ≤ 2 ^ 100)
    (q : ℕ) (hq : q + 1 ≤ 2 ^ 102) (A : OC (QB L) Dig α) (hA : A.Bounded q) :
    prH (EvXM tag L h64 key domain hs hL rd nA nH nM dA dH dM n coreOf Vx rx A) ≤ u126 q (2 ^ 16 + 2 ^ 18) :=
  (extract_fail_xm tag L h64 key domain hs hL rd nA nH nM dA dH dM n coreOf Vx nx hVx rx nrx hrx q A hA).trans
    (xfail_le_u126_102 q _ _ hq (by
      have h := hT
      generalize n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) + nx = X at h ⊢
      omega) hnr)

/-- **OUTSIDE THE FAILURE, THE OPENED COLUMN IS THE EXTRACTED ONE** (`rx_xok` for `colXM`): if `EvXM` did not happen,
the header's message at `i` reads (under `rd`) as a root of `rx`, the rows fit `L`, and the run verifier's Merkle work
checks the sampled columns, then every sampled column that verifies against that root is the column `colXM` extracts. -/
theorem ab_xok_in (rd : List UInt8 → Option Dig) (coreOf : α → ℕ → List Op × Block.Core)
    (Vx : α → OC (QB L) Dig Unit) (rx : α → List Dig) (A : OC (QB L) Dig α) (G : QB L → Dig)
    (hX : ¬ EvXM tag L h64 key domain hs hL rd 256 256 256 16 16 12 26 coreOf Vx rx A G)
    (d i rows Q : ℕ) (hdr : List (TItem × Dig)) (zo : Block.OpeningZk) (root : Dig)
    (hroot : root ∈ rx (A.run G)) (habs : (Block.absAt hdr i).bind rd = some root) (hfit : 8 * rows ≤ L)
    (hq : ∀ k, k < Q → k < zo.columns.length → (zo.columns.getD k ⟨0, [], zeroDig, []⟩).path.length = d →
      ∀ (hf : 8 * (zo.columns.getD k ⟨0, [], zeroDig, []⟩).col.length ≤ L),
      ∀ v ∈ (merkleEncV tag L h64).openQs G (zo.columns.getD k ⟨0, [], zeroDig, []⟩).j
        ⟨⟨(zo.columns.getD k ⟨0, [], zeroDig, []⟩).col, hf⟩, (zo.columns.getD k ⟨0, [], zeroDig, []⟩).salt,
          (zo.columns.getD k ⟨0, [], zeroDig, []⟩).path⟩,
      v ∈ OC.queries G (A.bind (runV tag L h64 256 256 256 16 16 12 26 coreOf Vx))) :
    ∀ (k : ℕ), k < Q → k < zo.columns.length →
      ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.2.length = d →
      verifyPath (liftH G) tag root ((toOZ zo).columns.getD k (0, [], zeroDig, [])).1
        (saltLeaf (liftH G) tag (colDigest (liftH G) tag ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1)
          ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.1) ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.2
        = true →
      ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1.length = rows →
      (colXM tag L h64 key domain hs hL rd d i (A.runLog G).2 hdr
        ((toOZ zo).columns.getD k (0, [], zeroDig, [])).1).map Subtype.val
        = some ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1 := by
  intro k hkQ hkl hpath hver hlen
  rw [rx_toOZ_getD] at hpath hver hlen ⊢
  set c := zo.columns.getD k ⟨0, [], zeroDig, []⟩ with hcdef
  have hpath' : c.path.length = d := hpath
  have hver' : verifyPath (liftH G) tag root c.j (saltLeaf (liftH G) tag (colDigest (liftH G) tag c.col) c.salt) c.path
      = true := hver
  have hlen' : c.col.length = rows := hlen
  have hf : 8 * c.col.length ≤ L := by rw [hlen']; exact hfit
  have hop := opensV_of_exec tag L h64 G d root c.j c.col hf c.salt c.path hpath' hver'
  have hext : (merkleEncV tag L h64).extractCol (cutAt (absMOf L key domain hs hL rd) root (A.runLog G).2) d c.j root
      = some ⟨c.col, hf⟩ := by
    by_contra hne
    exact hX ⟨root, hroot, d, c.j, ⟨⟨c.col, hf⟩, c.salt, c.path⟩, hop, hq k hkQ hkl hpath' hf, hne⟩
  show (colXM tag L h64 key domain hs hL rd d i (A.runLog G).2 hdr c.j).map Subtype.val = some c.col
  unfold colXM
  rw [habs]
  simp only
  rw [hext]
  rfl

end Fail

end ZK60.ProtocolClassify
