/-
D63 lane L63 (2026-11-17), part 39: **part `0`'s closing opening (the input endpoint) makes the claims it checks true of
its decoded unchecked matrix, and that matrix read on a view is the run's** (step (c2), first pieces).

* **`ssh_ebOpen_sem`**: lane L46's `wr_rkOpen_sem` for repair B's opening `ebOpen` (part `0`'s closing opening: the
  input endpoint read under `abRdIn`): no doomed first-half entrant at its window makes every claim it checks true of
  `decodeRows` of its extracted matrix (`wr_opA_good`, `groupsGood_claimSem`).
* **`ssh_ebUxW_view`**: the unchecked matrix read from the log cut at a header's position `i` equals the one read from
  the whole log at any header with the same message at `i` (`ab_cut_coarse`): a view and the run's transcript prefix
  read the same matrix.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldEpBridge

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

section Sem

/-- **REPAIR B'S OPENING WHOSE FIRST HALF DID NOT ENTER DOOMED MAKES EVERY CLAIM IT CHECKS TRUE** of its decoded extracted
matrix (`wr_rkOpen_sem` for `ebOpen`). -/
theorem ssh_ebOpen_sem {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) (rdx : List UInt8 → Option Dig) (g : RkGeo) (nC : ℕ)
    (clr : List (TItem × Dig) → List Block.ZClaim) (vpos : ℕ) (W : UInt64 → ℕ) (aO : ℕ) (lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig))
    (hnd : ¬ EntD W ((ebOpen U tag Lq h64 key domain hs hL rdx g nC clr vpos).opA U hbij aO lg) τ)
    (hle : aO ≤ τ.length) (hpre : tRem W (τ.take aO) = some 0) (hcnt : (clr (τ.take aO)).length = nC) :
    ∀ z ∈ clr (τ.take aO),
      wrOSem U (ebOpen U tag Lq h64 key domain hs hL rdx g nC clr vpos) lg (τ.take aO) z = z.value.toK U :=
  groupsGood_claimSem U g.rows g.lc g.Q (encGL (K := K) g.lc g.h g.Q) g.e _ (clr (τ.take aO)) nC hcnt
    (wr_opA_good U hbij _ W aO lg τ hnd hle hpre)

end Sem

section View

variable {K : Type} [Field K] [Algebra GF K] (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig)
  (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)

/-- **The unchecked matrix read on a view is the run's**: from the log cut at the message a header shows at position `i`,
at that header, it is the matrix read from the whole log at any header showing the same message there. -/
theorem ssh_ebUxW_view (rd : List UInt8 → Option Dig) (d i rows N : ℕ) (Lg : List (QB L × Dig))
    (hdr hdr' : List (TItem × Dig)) (x : List UInt8) (r : Dig) (hx : Block.absAt hdr i = some x)
    (hx' : Block.absAt hdr' i = some x) (hr : rd x = some r) :
    ebUxW (K := K) tag L h64 key domain hs hL rd d i rows (N := N)
        (Block.cutO (Exec.Block.absOfC (chainEncB key domain hs L hL)) (Block.absAt hdr i) Lg) hdr
      = ebUxW (K := K) tag L h64 key domain hs hL rd d i rows (N := N) Lg hdr' := by
  have hfg : ∀ y, Block.absOfC (chainEncB key domain hs L hL) y = some x → absMOf L key domain hs hL rd y = some r :=
    fun y hy => by rw [absMOf, hy, Option.bind_some, hr]
  funext row j
  unfold ebUxW colXM
  rw [hx, hx', Option.bind_some, hr]
  simp only [Block.cutO]
  rw [ab_cut_coarse _ _ x r hfg Lg]

end View

end ZK60.ProtocolClassify
