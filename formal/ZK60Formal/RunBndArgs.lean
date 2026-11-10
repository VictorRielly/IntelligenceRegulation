/-
D63 lane L56 (2026-11-10), part 7: **every table the slots' interface reads at block `k` is a function of the new slot
polynomial's arguments** (the repair of finding L54-1 is meetable: the premise `hsl_evB` asks nothing of `Fsl k` that
its type cannot see).

Lane L54's finding L54-1 was a TYPE obstruction: the data `SlotEval` reads at the two boundary slots (the boundary
tables) was not a function of the arguments `Fsl k : Cuts3 → RootsO → …` receives, so no `Fsl k` could meet the
premise for every adversary. Here, at every reading of block `k` on the run's transcript:

* `csArgs`, `msArgs`: the claims' and the functionals' semantics computed from the slot polynomial's arguments ONLY
  (the cut logs and roots of the block's `A`, `M`, `H`; the header's roots and cuts `hdrX`) and the openings' fixed
  code parameters;
* **`bnd_args_cs`**: `wrCsB` (the claims' semantics `hsl_evB` uses) IS `csArgs` of the arguments, when the block's `A`
  and `H` openings read their roots at `off (k + 1) + 5` and `+ 12` (L45's `rxDblk`: `rx_dblk_pos`);
* **`bnd_args_ms`**: `wrMs` IS `msArgs` of the arguments, when `M`'s root is at `off (k + 1) + 8` (`rxDblk`) and
  before the slot phase's end;
* **`bnd_slotEval_args`**: so `hsl_evB` at a reading follows from `SlotEval` over `csArgs`, `msArgs` of `Fsl k`'s own
  arguments: a property of `Fsl k` as a function, which the masked slot polynomial over those tables has by
  construction (the polynomial identity itself is lane L11 / L13's builder interface, at R13 ARGUED as for every slot).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunBndSem

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV incHeadDraws IncCtx)
open ZK60.Circuit (gP GF)

section Args

variable {K : Type} [Field K] [Algebra GF K]

/-- **The claims' semantics from the slot polynomial's arguments**: `A`'s claims on the matrix decoded from the `A` root
and its cut, `H`'s from the `H` root and its cut, the boundary claims on the header entries at `pi`, `po`; at the four
openings' code parameters `oA`, `oH`, `oI`, `oO`. -/
noncomputable def csArgs (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (oA oH oI oO : RtOpen K Lq)
    (c3 : Block.Cuts3 Lq) (rt : Block.RootsO) (hx : Block.HdrX Lq) (pi po : ℕ) : Block.Cm → Block.ZClaim → K
  | .a => bndOSem U tag Lq h64 oA (rt.1, c3.1)
  | .h => bndOSem U tag Lq h64 oH (rt.2.2, c3.2.2)
  | .inp => bndOSem U tag Lq h64 oI (hx pi)
  | .out => bndOSem U tag Lq h64 oO (hx po)

/-- **The functionals' semantics from the slot polynomial's arguments**: lane L28's `msOfTab` on `M`'s table extracted
from the `M` root and its cut. -/
noncomputable def msArgs (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (S : ℕ) (c3 : Block.Cuts3 Lq)
    (rt : Block.RootsO) : List (ℕ × List Fp2) → K :=
  msOfTab U S (Link.colsC tag Lq h64 c3.2.1 rt.2.1)

/-- **Block `k`'s positions in L45's parts' data** (`rxDblk`): `A`'s root at `off (k + 1) + 5`, `H`'s at `+ 12`, `M`'s at
`+ 8`. -/
theorem rx_dblk_pos (pf : RtProf) (k S kM rA rH nA nH : ℕ) :
    (rxDblk pf k S kM rA rH nA nH).gA.ipos = pf.off (k + 1) + 5
      ∧ (rxDblk pf k S kM rA rH nA nH).gH.ipos = pf.off (k + 1) + 5 + 7
      ∧ (rxDblk pf k S kM rA rH nA nH).mpos = pf.off (k + 1) + 5 + 3 := by
  exact ⟨rfl, show pf.off (k + 1) + (5 + 7) = pf.off (k + 1) + 5 + 7 by omega,
    show pf.off (k + 1) + (5 + 3) = pf.off (k + 1) + 5 + 3 by omega⟩

variable (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

/-- An opening's claim semantics at a window `a` is the boundary semantics of the root at `p < a` and its cut, when its
matrix is the cut-level one at `p`. -/
theorem wrOSem_cut (o : RtOpen K Lq) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) (a p : ℕ) (hpa : p < a)
    (hUx : ∀ hdr, o.Ux lg hdr = Link.UxC tag Lq h64 o.h o.rows
      (Block.cutO (Block.absOfC (chainEncB key domain hs Lq hL)) (Block.absAt hdr p) lg) (Block.absAt hdr p))
    (z : Block.ZClaim) :
    wrOSem U o lg (τ.take a) z = claimSem U o.rows o.lc o.Q (decodeRows (encGL (K := K) o.lc o.h o.Q) o.e
      (Link.UxC tag Lq h64 o.h o.rows (Block.cutO (Block.absOfC (chainEncB key domain hs Lq hL)) (Block.absAt τ p) lg)
        (Block.absAt τ p))) z := by
  unfold wrOSem
  rw [hUx (τ.take a), absAt_take, if_pos hpa]

/-- **`wrCsB` IS `csArgs` OF THE SLOT POLYNOMIAL'S ARGUMENTS** at a reading of block `k` (its core's roots the ones the
transcript shows after the header, `hrt`), when the block's `A` and `H` openings read their roots at `off (k + 1) + 5`
and `off (k + 1) + 12` (`hA`, `hH`: `rxDblk`'s, `rx_dblk_pos`). -/
theorem bnd_args_cs (rdx : List UInt8 → Option Dig) (pf : RtProf) (ps : ℕ → RkPart K Lq)
    (acc : ℕ → List (TItem × Dig) → Block.Acc) (lsc : ℕ → Block.ZClaim) (eL : ℕ) (lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) (k : ℕ) (core : Block.Core)
    (hA : (ps (k + 1)).gA.ipos = pf.off (k + 1) + 5) (hH : (ps (k + 1)).gH.ipos = pf.off (k + 1) + 5 + 7)
    (hrt : Block.rootsAt (pf.off (k + 1) + 5) τ = Block.rootsOf core) :
    wrCsB U tag Lq h64 (ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL) pf k lg τ
        (Block.hdrX (Block.absOfC (chainEncB key domain hs Lq hL)) lg (pf.off (k + 1) + 5) τ)
      = csArgs U tag Lq h64 ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opA (k + 1))
          ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opH (k + 1))
          ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opX (k + 1))
          ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opX (k + 1 + 1))
          (Block.cuts3 (Block.absOfC (chainEncB key domain hs Lq hL)) lg (Block.rootsOf core)) (Block.rootsOf core)
          (Block.hdrX (Block.absOfC (chainEncB key domain hs Lq hL)) lg (pf.off (k + 1) + 5) τ)
          (pf.off k + 2) (pf.off (k + 1) + 2) := by
  have eA : Block.absAt τ (pf.off (k + 1) + 5) = (Block.rootsOf core).1 := by rw [← hrt]; rfl
  have eH : Block.absAt τ (pf.off (k + 1) + 5 + 7) = (Block.rootsOf core).2.2 := by rw [← hrt]; rfl
  funext cm z
  cases cm with
  | a =>
    have hU : ∀ hdr, ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opA (k + 1)).Ux lg hdr = Link.UxC tag Lq h64 ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opA (k + 1)).h ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opA (k + 1)).rows
        (Block.cutO (Block.absOfC (chainEncB key domain hs Lq hL)) (Block.absAt hdr (pf.off (k + 1) + 5)) lg) (Block.absAt hdr (pf.off (k + 1) + 5)) := by
      intro hdr
      show Link.UxW tag Lq h64 key domain hs hL (ps (k + 1)).gA.h (ps (k + 1)).gA.ipos (ps (k + 1)).gA.rows lg hdr
        = _
      rw [UxW_eq_cut tag Lq h64 key domain hs hL, hA]
      rfl
    have hw := wrOSem_cut U tag Lq h64 key domain hs hL ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opA (k + 1)) lg τ (pf.off (k + 1) + (pf.part (k + 1)).oA)
      (pf.off (k + 1) + 5) (by simp only [RtPart.oA]; omega) hU z
    show wrOSem U _ lg (τ.take (pf.off (k + 1) + (pf.part (k + 1)).oA)) z = bndOSem U tag Lq h64 _ _ z
    rw [hw, eA]
    rfl
  | h =>
    have hU : ∀ hdr, ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opH (k + 1)).Ux lg hdr = Link.UxC tag Lq h64 ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opH (k + 1)).h ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opH (k + 1)).rows
        (Block.cutO (Block.absOfC (chainEncB key domain hs Lq hL)) (Block.absAt hdr (pf.off (k + 1) + 5 + 7)) lg) (Block.absAt hdr (pf.off (k + 1) + 5 + 7)) := by
      intro hdr
      show Link.UxW tag Lq h64 key domain hs hL (ps (k + 1)).gH.h (ps (k + 1)).gH.ipos (ps (k + 1)).gH.rows lg hdr
        = _
      rw [UxW_eq_cut tag Lq h64 key domain hs hL, hH]
      rfl
    have hw := wrOSem_cut U tag Lq h64 key domain hs hL ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opH (k + 1)) lg τ (pf.off (k + 1) + (pf.part (k + 1)).oH)
      (pf.off (k + 1) + 5 + 7) (by simp only [RtPart.oH, RtPart.oBA, RtPart.oA]; omega) hU z
    show wrOSem U _ lg (τ.take (pf.off (k + 1) + (pf.part (k + 1)).oH)) z = bndOSem U tag Lq h64 _ _ z
    rw [hw, eH]
    rfl
  | inp => rfl
  | out => rfl

/-- **`wrMs` IS `msArgs` OF THE SLOT POLYNOMIAL'S ARGUMENTS** at a reading of block `k`, when `M`'s root is at
`off (k + 1) + 8` (`hM`: `rxDblk`'s) and before the slot phase's end (`hmp`: the block part's `pre` is
`15 + shapeLen`). -/
theorem bnd_args_ms (ps : ℕ → RkPart K Lq) (pf : RtProf) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) (k : ℕ)
    (core : Block.Core) (hM : (ps (k + 1)).mpos = pf.off (k + 1) + 5 + 3)
    (hmp : pf.off (k + 1) + 5 + 3 < pf.off (k + 1) + (pf.part (k + 1)).pre)
    (hrt : Block.rootsAt (pf.off (k + 1) + 5) τ = Block.rootsOf core) :
    wrMs U tag Lq h64 key domain hs hL ps pf (k + 1) lg τ
      = msArgs U tag Lq h64 (ps (k + 1)).S
          (Block.cuts3 (Block.absOfC (chainEncB key domain hs Lq hL)) lg (Block.rootsOf core)) (Block.rootsOf core) := by
  have eM : Block.absAt τ (pf.off (k + 1) + 5 + 3) = (Block.rootsOf core).2.1 := by rw [← hrt]; rfl
  unfold wrMs msArgs
  congr 1
  funext j
  simp only [rkColsM, Link.colsC]
  rw [colX_eq_cut tag Lq h64 key domain hs hL, hM, absAt_take, if_pos hmp, eM]
  rfl

/-- **`hsl_evB` AT A READING FOLLOWS FROM A PROPERTY OF THE SLOT POLYNOMIAL ALONE**: if `F` meets `SlotEval` over
`csArgs`, `msArgs` of its own arguments (the cut logs and roots of the block's commitments and the header's roots and
cuts), then it meets it over the run's `wrCsB`, `wrMs` at the reading (`bnd_args_cs`, `bnd_args_ms`). -/
theorem bnd_slotEval_args (rdx : List UInt8 → Option Dig) (pf : RtProf) (ps : ℕ → RkPart K Lq)
    (acc : ℕ → List (TItem × Dig) → Block.Acc) (lsc : ℕ → Block.ZClaim) (eL : ℕ) (lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) (k : ℕ) (core : Block.Core) (P : Block.BlockParams)
    (F : Block.Cuts3 Lq → Block.RootsO → Block.HdrX Lq → (j : ℕ) → Block.Seen →
      (Fin ((Block.slotShape P j).1 + (Block.slotShape P j).2.1) → K) → K)
    (hA : (ps (k + 1)).gA.ipos = pf.off (k + 1) + 5) (hH : (ps (k + 1)).gH.ipos = pf.off (k + 1) + 5 + 7)
    (hM : (ps (k + 1)).mpos = pf.off (k + 1) + 5 + 3)
    (hmp : pf.off (k + 1) + 5 + 3 < pf.off (k + 1) + (pf.part (k + 1)).pre)
    (hrt : Block.rootsAt (pf.off (k + 1) + 5) τ = Block.rootsOf core)
    (hF : ∀ (c3 : Block.Cuts3 Lq) (rt : Block.RootsO) (hx : Block.HdrX Lq),
      Block.SlotEval U P
        (csArgs U tag Lq h64 ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opA (k + 1))
          ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opH (k + 1))
          ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opX (k + 1))
          ((ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL).opX (k + 1 + 1)) c3 rt hx
          (pf.off k + 2) (pf.off (k + 1) + 2))
        (msArgs U tag Lq h64 (ps (k + 1)).S c3 rt) (fun j sn pt => F c3 rt hx j sn pt)) :
    Block.SlotEval U P
      (wrCsB U tag Lq h64 (ebData U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL) pf k lg τ
        (Block.hdrX (Block.absOfC (chainEncB key domain hs Lq hL)) lg (pf.off (k + 1) + 5) τ))
      (wrMs U tag Lq h64 key domain hs hL ps pf (k + 1) lg τ)
      (fun j sn pt => F (Block.cuts3 (Block.absOfC (chainEncB key domain hs Lq hL)) lg (Block.rootsOf core))
        (Block.rootsOf core) (Block.hdrX (Block.absOfC (chainEncB key domain hs Lq hL)) lg (pf.off (k + 1) + 5) τ)
        j sn pt) := by
  rw [bnd_args_cs U tag Lq h64 key domain hs hL rdx pf ps acc lsc eL lg τ k core hA hH hrt,
    bnd_args_ms U tag Lq h64 key domain hs hL ps pf lg τ k core hM hmp hrt]
  exact hF _ _ _

end Args

end ZK60.ProtocolClassify
