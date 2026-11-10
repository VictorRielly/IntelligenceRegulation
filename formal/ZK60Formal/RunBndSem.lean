/-
D63 lane L56 (2026-11-10), part 3: **the boundary data the block slots' polynomials now see IS the data the run's
closing openings check** (the repair of finding L54-1: the premise left in place of the slots' alive premise can be
met at the two boundary slots).

At block `k` (part `k + 1`), lane L54's run-level semantics `wrCs` reads the block's incoming claims on part `k + 1`'s
closing opening (the matrix extracted for the root the run's transcript absorbs at that opening's `gX.ipos`) and its
outgoing claims on part `k + 2`'s. The code absorbs those two roots in the frames of parts `k` and `k + 1`, at the
third absorb of each frame (`pb-run-stage`, `pb-run-block`, then `absorb_root(B)`: classify_run.rs:424-428 for a
block, stage_in_c.rs:422-424 for stage IN-C; CHECKED on a real receipt by `lean_l56_export_tests.rs`), i.e. at the run
positions `off k + 2` and `off (k + 1) + 2`, both inside the block's header (before `off (k + 1) + 5`). So:

* `bndOSem`: a claim's value on an opening's matrix decoded from a root and the log cut at it (lane L54's `wrOSem`
  with the matrix read from a header entry `hdrX … i`); `bndTab`: that decoded matrix (the boundary table);
* `wrCsB`: the claims' semantics of block `k` with the boundary claims read from the HEADER's roots and cuts at
  `off k + 2` and `off (k + 1) + 2` (the arguments the new slot polynomials receive);
* `colX_eq_cut`, `UxW_eq_cut`: an extracted column / matrix is the cut-level one at the root the header shows (by
  definition); `rxPs_gX`: the classify run's parts keep `base`'s closing geometry;
* **`wrCs_eq_B`**: when the closing openings of parts `1 … Lb + 1` read their roots at the code's positions
  (`(base (k + 1)).gX.ipos = off k + 2`), `wrCs` of block `k` IS `wrCsB` at the run's header data: PROVED;
* **`wr_termB`**: lane L54's `wr_term` for the new schedule (`RaTermAtB` from the claims' truth and the slot
  polynomials' interface `SlotEval`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunBndHal
import ZK60Formal.RunWireTerm

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV incHeadDraws IncCtx)
open ZK60.Circuit (gP GF)

/-! ## The extracted matrix at a header's root is the cut-level one -/

section Cut

variable (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)

/-- **The column extracted for the root the header absorbs at `i` is the one extracted from that root and the log cut
at it** (lane L22's `colX`, lane L28's `colXc`: by definition). -/
theorem colX_eq_cut (d i : ℕ) (log : List (QB L × Dig)) (hdr : List (TItem × Dig)) (j : ℕ) :
    Link.colX tag L h64 key domain hs hL d i log hdr j
      = Link.colXc tag L h64 d (Block.cutO (Block.absOfC (chainEncB key domain hs L hL)) (Block.absAt hdr i) log)
          (Block.absAt hdr i) j := by
  unfold Link.colX Link.colXc
  rfl

/-- **The matrix extracted for the root the header absorbs at `i` is the cut-level one** (`UxW` is `UxC` at the root
and the cut). -/
theorem UxW_eq_cut {K : Type} [Field K] [Algebra GF K] (d i rows : ℕ) {N : ℕ} (log : List (QB L × Dig))
    (hdr : List (TItem × Dig)) :
    (Link.UxW tag L h64 key domain hs hL d i rows log hdr : Fin rows → Fin N → K)
      = Link.UxC tag L h64 d rows (Block.cutO (Block.absOfC (chainEncB key domain hs L hL)) (Block.absAt hdr i) log)
          (Block.absAt hdr i) := by
  funext r j
  simp only [Link.UxW, Link.UxC]
  rw [colX_eq_cut tag L h64 key domain hs hL d i log hdr j]

end Cut

/-! ## The boundary claims' semantics from the header's roots and cuts -/

section Bnd

variable {K : Type} [Field K] [Algebra GF K]

/-- **The boundary table**: an opening's matrix decoded from a header entry (a root and the log cut at it), at the
opening's own code and radius. -/
noncomputable def bndTab (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (o : RtOpen K Lq)
    (x : Option (List UInt8) × List (QB Lq × Dig)) : Fin o.rows → Fin (2 ^ o.lc + o.Q) → K :=
  decodeRows (encGL (K := K) o.lc o.h o.Q) o.e (Link.UxC tag Lq h64 o.h o.rows x.2 x.1)

/-- **A claim's value on the boundary table** (lane L28's `claimSem`). -/
noncomputable def bndOSem (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (o : RtOpen K Lq)
    (x : Option (List UInt8) × List (QB Lq × Dig)) (z : Block.ZClaim) : K :=
  claimSem U o.rows o.lc o.Q (bndTab tag Lq h64 o x) z

/-- **Block `k`'s claims' semantics with its boundary claims read from the header's roots and cuts** `hx` (the run
positions `off k + 2`, `off (k + 1) + 2`, where the code absorbs the input and output boundary roots); `A`'s and `H`'s as
lane L54's `wrCs`. -/
noncomputable def wrCsB (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (D : RtKData K Lq) (pf : RtProf) (k : ℕ)
    (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) (hx : Block.HdrX Lq) : Block.Cm → Block.ZClaim → K
  | .a => wrCs U D pf (k + 1) lg τ .a
  | .h => wrCs U D pf (k + 1) lg τ .h
  | .inp => bndOSem U tag Lq h64 (D.opX (k + 1)) (hx (pf.off k + 2))
  | .out => bndOSem U tag Lq h64 (D.opX (k + 1 + 1)) (hx (pf.off (k + 1) + 2))

omit [Field K] [Algebra GF K] in
/-- The classify run's parts keep `base`'s closing geometry. -/
theorem rxPs_gX {Lq : ℕ} (base : ℕ → RkPart K Lq) (Lb : ℕ) (din : RxMAH) (dblk : ℕ → RxMAH) (dout : RxMAH) (i : ℕ) :
    (rxPs base Lb din dblk dout i).gX = (base i).gX := by
  rcases i with _ | i
  · rfl
  · show (if i < Lb then rxSet (base (i + 1)) (dblk i) else rxSet (base (i + 1)) dout).gX = _
    split_ifs <;> rfl

variable (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

/-- **A later part's closing opening's matrix is the cut-level one at its root's position.** -/
theorem eb_opX_Ux_cut (rdx : List UInt8 → Option Dig) (pf : RtProf) (ps : ℕ → RkPart K Lq)
    (acc : ℕ → List (TItem × Dig) → Block.Acc) (lsc : ℕ → Block.ZClaim) (eL i : ℕ) (P : List (QB Lq × Dig))
    (hdr : List (TItem × Dig)) :
    ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opX (i + 1)).Ux P hdr
      = Link.UxC tag Lq h64 (ps (i + 1)).gX.h (ps (i + 1)).gX.rows
          (Block.cutO (Block.absOfC (chainEncB key domain hs Lq hL)) (Block.absAt hdr (ps (i + 1)).gX.ipos) P)
          (Block.absAt hdr (ps (i + 1)).gX.ipos) := by
  show Link.UxW tag Lq h64 key domain hs hL (ps (i + 1)).gX.h (ps (i + 1)).gX.ipos (ps (i + 1)).gX.rows P hdr = _
  exact UxW_eq_cut tag Lq h64 key domain hs hL _ _ _ P hdr

/-- **One boundary claim's semantics**: a later part `i + 1`'s closing opening, whose root position `p` is before its
window `a` and before the block's header end `hdrLen`, reads its claims on the boundary table of the header entry at
`p`. -/
theorem eb_wrOSem_bnd (rdx : List UInt8 → Option Dig) (pf : RtProf) (ps : ℕ → RkPart K Lq)
    (acc : ℕ → List (TItem × Dig) → Block.Acc) (lsc : ℕ → Block.ZClaim) (eL i : ℕ) (lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) (a hdrLen p : ℕ) (hp : (ps (i + 1)).gX.ipos = p) (hpa : p < a) (hph : p < hdrLen)
    (z : Block.ZClaim) :
    wrOSem U ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opX (i + 1)) lg (τ.take a) z
      = bndOSem U tag Lq h64 ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opX (i + 1))
          (Block.hdrX (Block.absOfC (chainEncB key domain hs Lq hL)) lg hdrLen τ p) z := by
  have e2 : Block.hdrX (Block.absOfC (chainEncB key domain hs Lq hL)) lg hdrLen τ p
      = (Block.absAt τ p, Block.cutO (Block.absOfC (chainEncB key domain hs Lq hL)) (Block.absAt τ p) lg) := by
    simp only [Block.hdrX, ite_eq_left hph]
  rw [e2]
  unfold wrOSem bndOSem bndTab
  rw [eb_opX_Ux_cut U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL i lg (τ.take a), hp, absAt_take,
    ite_eq_left hpa]
  rfl

/-- **`wrCs` OF BLOCK `k` IS `wrCsB` AT THE RUN'S HEADER DATA** when the closing openings of parts `k + 1` and `k + 2`
read their roots at the code's positions `off k + 2`, `off (k + 1) + 2` (`hgXB`): the block's boundary claims are about
the tables the new slot polynomials receive. -/
theorem wrCs_eq_B (rdx : List UInt8 → Option Dig) (pf : RtProf) (base : ℕ → RkPart K Lq) (Lb : ℕ) (din : RxMAH)
    (dblk : ℕ → RxMAH) (dout : RxMAH) (acc : ℕ → List (TItem × Dig) → Block.Acc) (lsc : ℕ → Block.ZClaim) (eL : ℕ)
    (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) (k : ℕ)
    (hgXB : ∀ j, j ≤ Lb → (base (j + 1)).gX.ipos = pf.off j + 2) (hk : k < Lb) :
    wrCs U (ebData U tag Lq h64 key domain hs hL rdx pf (rxPs base Lb din dblk dout) acc lsc eL) pf (k + 1) lg τ
      = wrCsB U tag Lq h64 (ebData U tag Lq h64 key domain hs hL rdx pf (rxPs base Lb din dblk dout) acc lsc eL) pf k
          lg τ (Block.hdrX (Block.absOfC (chainEncB key domain hs Lq hL)) lg (pf.off (k + 1) + 5) τ) := by
  have h1 := pf.off_le k
  have h2 := pf.off_le (k + 1)
  funext cm z
  cases cm with
  | a => rfl
  | h => rfl
  | inp =>
    show wrOSem U _ lg (τ.take (pf.off (k + 1) + (pf.part (k + 1)).oX)) z = bndOSem U tag Lq h64 _ _ z
    refine eb_wrOSem_bnd U tag Lq h64 key domain hs hL rdx pf _ acc lsc eL k lg τ _ _ _ ?_ ?_ ?_ z
    · rw [rxPs_gX]
      exact hgXB k (by omega)
    · simp only [RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
      omega
    · omega
  | out =>
    show wrOSem U _ lg (τ.take (pf.off (k + 1 + 1) + (pf.part (k + 1 + 1)).oX)) z = bndOSem U tag Lq h64 _ _ z
    refine eb_wrOSem_bnd U tag Lq h64 key domain hs hL rdx pf _ acc lsc eL (k + 1) lg τ _ _ _ ?_ ?_ ?_ z
    · rw [rxPs_gX]
      exact hgXB (k + 1) (by omega)
    · simp only [RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
      omega
    · omega

end Bnd

/-! ## `RaTermAtB` from the claims' truth and the slot polynomials' interface -/

/-- **`RaTermAtB` FROM THE CLAIMS' TRUTH AND THE SLOT POLYNOMIALS' INTERFACE** (lane L54's `wr_term` for the new
schedule). At every reading of block `P` (at `hdrLen`) on the transcript `τ`: if the reading's accumulator has every
claim true of `cs` and every functional true of `ms` (`hsem`), the polynomial `F` at the reading's roots and the
header's roots and cuts meets `SlotEval` over `cs`, `ms` (`hEv`), and `define`'s polynomials return canonical words
(`hpolyC`), then every slot's final value is `F` at its point (lane L16's `blockSlots_terminal`). -/
theorem wr_termB {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig)
    (domain : List UInt8) {L : ℕ} (P : Block.BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Block.Cuts3 L → Block.RootsO → Block.HdrX L → (j : ℕ) → Block.Seen →
      (Fin ((Block.slotShape P j).1 + (Block.slotShape P j).2.1) → K) → K)
    (G : QB L → Dig) (lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (cs : Block.Cm → Block.ZClaim → K) (ms : List (ℕ × List Fp2) → K)
    (hd : ∀ j, j < P.geom.slots.length → 1 ≤ (Block.slotShape P j).2.2)
    (hpolyC : ∀ (j : ℕ) (hist : Block.Hist) (dr : List Fp2) (df : Block.SlotDef), P.define j hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hsem : ∀ (hdr : List Op) (core : Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec)
      (acc : Block.Acc) (T : List Op), Block.SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc →
      τ = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Block.allOps P (hdr, core) ++ T) →
      Block.ClaimsTrue U cs acc.claims ∧ Block.MTrue U ms (acc.fs ++ acc.hostFs))
    (hEv : ∀ (hdr : List Op) (core : Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec)
      (acc : Block.Acc) (T : List Op), Block.SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc →
      τ = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Block.allOps P (hdr, core) ++ T) →
      Block.SlotEval U P cs ms (fun j sn pt => F (Block.cuts3 absOf lg (Block.rootsOf core)) (Block.rootsOf core)
        (Block.hdrX absOf lg hdrLen τ) j sn pt)) :
    RaTermAtB U key domain P hdrLen absOf F G lg τ := by
  intro hdr core bga rs acc T hsa _ htr j r hr
  obtain ⟨hcl, hm⟩ := hsem hdr core bga rs acc T hsa htr
  have hev := hEv hdr core bga rs acc T hsa htr
  obtain ⟨-, -, hcan, hsh, t', hbs⟩ := hsa
  exact Block.blockSlots_terminal U hU (liftH G) P core _ bga rs acc t' hbs cs ms hcl
    (fun mf h => hm mf (List.mem_append_left _ h)) hpolyC
    (Block.blockSlots_fin_canon (liftH G) P core _ bga rs acc t' hbs hcan hsh hd) _ hev j r hr

end ZK60.ProtocolClassify
