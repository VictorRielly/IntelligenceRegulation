/-
D63 lane L58 (2026-11-10), part 2: **part `0`'s closing opening's facts WITH the checked extraction** (the brief's
deliverable 2: `hBal`'s extraction step at the checked extractor).

L52's `RhOpWM` (the closing opening's acceptance facts, its matrix read with the UNCHECKED `colXM`) says that every
sampled column that verifies is the column `colXM` extracts. The column test's matrix and column set are now read from
the CHECKED extractor (`exUx`, `exXx`, RunEpXExt.lean), so `hBal` also needs the sampled columns to be the checked
extractor's:

* `RhXOkC`: every sampled column of `zo` that verifies against `root` at depth `g.h` with `g.rows` values is the column
  the checked extractor returns (`epxHn`, at the root the header's message at `g.ipos` reads as under `rdx`), as soon as
  the opening's words are canonical (the code's receipt readers refuse any other word: L52-5);
* `RhOpWC`: a witness of `RhOpWM` whose own opening and root meet `RhXOkC` (the witness is EXPOSED: the checked fact
  must speak of the opening the acceptance facts speak of).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunEpXExt

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Exec.StageV ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)

section XOkC

variable (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

/-- **An opening's CHECKED extraction under a reader** (L52's `RhXOkM` for the checked extractor): when the opening's
words are canonical, every sampled column of `zo` that verifies against `root` at depth `g.h`, with `g.rows` values, is
the column the checked extractor returns for the root the header's message at `g.ipos` reads as under `rdx`. -/
def RhXOkC (rdx : List UInt8 → Option Dig) (g : RkGeo) (P : List (QB Lq × Dig)) (G : QB Lq → Dig)
    (hdr : List (TItem × Dig)) (zo : Block.OpeningZk) (root : Dig) : Prop :=
  Block.HidingCanon zo →
  ∀ (k : ℕ), k < g.Q → k < zo.columns.length →
    ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.2.length = g.h →
    verifyPath (liftH G) tag root ((toOZ zo).columns.getD k (0, [], zeroDig, [])).1
      (saltLeaf (liftH G) tag (colDigest (liftH G) tag ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1)
        ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.1) ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.2.2
      = true →
    ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1.length = g.rows →
    (epxHn tag Lq h64 key domain hs hL rdx g.h g.ipos g.rows P hdr
      ((toOZ zo).columns.getD k (0, [], zeroDig, [])).1).map (fun o => o.col.1)
      = some ((toOZ zo).columns.getD k (0, [], zeroDig, [])).2.1

end XOkC

section OpWC

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig)
  (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

/-- **Part `0`'s closing opening's acceptance facts with the checked extraction**: a witness of L52's `RhOpWM` whose
own opening (`w.zo`) and root (`w.root`) meet `RhXOkC` at the opening's window. -/
def RhOpWC (rdx : List UInt8 → Option Dig) (W : UInt64 → ℕ) (g : RkGeo) (nC : ℕ)
    (clr : List (TItem × Dig) → List Block.ZClaim) (aO aB vpos : ℕ) (P : List (QB Lq × Dig)) (G : QB Lq → Dig)
    (τ : List (TItem × Dig)) : Prop :=
  ∃ w : RhOpWM U tag Lq h64 key domain hs hL rdx W g nC clr aO aB vpos P G τ,
    RhXOkC tag Lq h64 key domain hs hL rdx g P G (τ.take aO) w.zo w.root

end OpWC

end ZK60.ProtocolClassify
