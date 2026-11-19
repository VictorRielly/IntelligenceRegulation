/-
D63 lane L63 (2026-11-18), part 78: **stage OUT-C's define polynomial vanishing over `τ`'s view** (step (i) of
`hLO_stg`, HANDOFF_20261118_5.md section 5; the OUT-C analogue of `stg_inc_def_zero`, RunStgShieldIncJoin.lean):

* **`vwLoc_sshΦO`**: OUT-C's real define polynomial `sshΦO` reads the view below `hdrLen + 9` (its claims through
  `vwLoc_stgCsv`, its schedule through the verdict window `vdWout F (v.2.take n0)`, `n0 ≤ hdrLen + 9`);
* **`stg_outc_def_zero_tau`**: no doomed `rtKR0` entrant ⇒ at every OUT-C reading each drawing slot's `sshΦO`
  vanishes at every draw at `τ`'s view (`stg_outc_def_zero` at the view before the draw, moved by `stg_rd_def` and
  `vw_take`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutNum

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
open ZK60.RunShape.Shield (shieldS0)

section LocOut

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- **`sshΦO` reads the view below `hdrLen + 9`** (OUT-C's `m = 2`). -/
theorem vwLoc_sshΦO (P0 : Block.BlockParams) (F : ℕ → OutcV) (n0 hdrLen lc h Q e rA rH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (hIOl : VwLoc (hdrLen + (7 + 2)) csIO)
    (hn0 : n0 ≤ hdrLen + (7 + 2)) (k : ℕ) (hh : List Fp2 × List (List Fp2)) (y : Fin (P0.draws k) → K) :
    VwLoc (hdrLen + (7 + 2)) (fun v => sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO v k hh y) := by
  intro v v' h1 h2
  have hc := vwLoc_stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 2) _ (by omega) (by omega) csIO hIOl
    v v' h1 h2
  have hw : v.2.take n0 = v'.2.take n0 := by
    have h3 := congrArg (fun l => l.take n0) h2
    simp only [List.take_take, Nat.min_eq_left hn0] at h3
    exact h3
  show stgΦR U hbij P0 (fun v _ => (vdWout F (v.2.take n0)).bp) OutcV.bga
      (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 2) csIO) v k hh y
    = stgΦR U hbij P0 (fun v _ => (vdWout F (v.2.take n0)).bp) OutcV.bga
      (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 2) csIO) v' k hh y
  unfold stgΦR
  beta_reduce
  rw [hc, hw]

end LocOut

section ZeroOutT

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)

/-- **NO DOOMED R0 ENTRANT: STAGE OUT-C'S DEFINE POLYNOMIAL AT A DRAWING SLOT VANISHES AT EVERY DRAW, AT `τ`'S
VIEW** (the OUT-C analogue of `stg_inc_def_zero`). -/
theorem stg_outc_def_zero_tau (n Lb : ℕ) (hi : Lb + 1 < pf.parts.length) (hin : Lb + 1 < n) (tag : MTag)
    (h64 : 64 ≤ Lq) (P0 : Block.BlockParams) (F : ℕ → OutcV) (b n0 hdrLen lc h Q e rA rH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (hIOl : VwLoc (hdrLen + (7 + 2)) csIO)
    (hn0 : n0 ≤ hdrLen + (7 + 2))
    (hR : D.r0 (Lb + 1) = stgDefsV P0 2 hdrLen (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO) sshDgO)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hno : ¬ (rtKR0 key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ)
    (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain Lq (fun _ => (F b).bp) 2 hdrLen OutcV.bga G τ hdr core ch rs)
    (hP : StgSame P0 (F b).bp) (hgt : (F b).bp.geom.slots.length = (F b).bp.geom.terms.length)
    (hgeom : ∀ k, k < (F b).bp.geom.slots.length → 1 ≤ (Block.slotShape (F b).bp k).2.2)
    (k : ℕ) (hk : k ∈ stgDrawing P0) :
    ∀ y, sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO
        (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ) k
        (ch, (rs.take k).map Block.SlotRec.draws) y = 0 := by
  intro y
  have hz := stg_outc_def_zero key domain hs Lq hL pf rd hL64 hv U hbij D hD n Lb hi hin tag h64 P0 F b n0 hdrLen
    lc h Q e rA rH csIO hR G lg τ hno hdr core ch rs hrd hP hgt hgeom k hk y
  have hslen : core.slots.length = (F b).bp.geom.slots.length := hrd.2.2.2.1.1
  have hkl : k < core.slots.length := by
    rw [hslen, ← hP.2]
    exact List.mem_range.mp (List.mem_filter.mp hk).1
  obtain ⟨q, hq⟩ : ∃ q, core.slots[k]? = some q := ⟨_, List.getElem?_eq_getElem hkl⟩
  obtain ⟨h1, -⟩ := stg_rd_def key domain (fun _ => (F b).bp) 2 hdrLen OutcV.bga G τ hdr core ch rs hrd hgt k q hq
  have hmv := vw_take (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg (hdrLen + (7 + 2))
    (stgDefPos (F b).bp 2 hdrLen k) (by unfold stgDefPos; omega) _
    (vwLoc_sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO hIOl hn0 k
      (ch, (rs.take k).map Block.SlotRec.draws) y) τ
  rw [← hmv, h1]
  exact hz

end ZeroOutT

end ZK60.ProtocolClassify
