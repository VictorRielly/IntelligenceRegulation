/-
D63 lane L63 (2026-11-17), part 31: **the stages' IO claims semantics on given message matrices, and the input
endpoint's matrix decoded from the checked extractor** (the csIO link in the form `hdzW` and the stage IO claims need).

`RunStgShieldIOLink.lean`'s `stgCsIOv` reads the unchecked extraction (`UxC`). The run's input endpoint is read by L58's
CHECKED extractor (`epxH` at the header, `epxOps` at the statement's input root) and decoded by the input commitment's
`decodeIn`; here the semantics takes the role matrices as parameters, and the input endpoint's matrix is that decoding:

* `stgCsIOm XI XO`: a claim on `.inp` (`.out`) is its functional (`claimSem`) on the matrix `XI v` (`XO v`);
  `stgCsIOm_claimSem` (`stgCsIODeg_of_claimSem`'s `hcs`, by definition), `stgCsIOm_value` (`hIOI`), `vwLoc_stgCsIOm`
  (`hIOlI`, from the matrices' locality), `stgCsIOm_deg`, **`ssh_hIO0m`**, **`ssh_hIO1m`**, **`ssh_hIOOm`** (lane L65's
  `hIO0`, `hIO1`, `hIO`);
* `epDecX dec rd d i`: the matrix `dec` decodes from the checked extractor's openings at the root the view's header shows
  at position `i` (read from the log cut there), message columns then pads, embedded in `K`; `vwLoc_epDecX`;
* **`epDecX_run`**: at a header whose position `i` reads as the root `r`, the view's openings are the checked extractor's
  at `r` on the WHOLE log (`ab_cut_coarse`): with `r` the statement's input root they are the top theorem's
  `epxOps … Lg s`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIOLink
import ZK60Formal.RunEpXExt

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Exec.StageV (IncV OutcV)
open ZK60.Circuit (gP GF)

section Sem

variable {K : Type} [Field K] [Algebra GF K] (U : K) {L : ℕ}

/-- **THE STAGES' IO CLAIMS SEMANTICS ON GIVEN MATRICES**: a claim on `.inp` (`.out`) is its functional on `XI v`
(`XO v`); `0` on `A`, `H` (read by `stgCsv`). -/
noncomputable def stgCsIOm (rI lcI QI rO lcO QO : ℕ) (XI : StgVw L → Fin rI → Fin (2 ^ lcI + QI) → K)
    (XO : StgVw L → Fin rO → Fin (2 ^ lcO + QO) → K) : StgVw L → Block.Cm → Block.ZClaim → K :=
  fun v cm z =>
    match cm with
    | .inp => claimSem U rI lcI QI (XI v) z
    | .out => claimSem U rO lcO QO (XO v) z
    | _ => 0

/-- The role matrices as one family over `Cm` (`.out`'s for `.out`, `.inp`'s otherwise). -/
def ioXm (rI lcI QI rO lcO QO : ℕ) (XI : StgVw L → Fin rI → Fin (2 ^ lcI + QI) → K)
    (XO : StgVw L → Fin rO → Fin (2 ^ lcO + QO) → K) (v : StgVw L) :
    (cm : Block.Cm) → Fin (ioR rI rO cm) → Fin (2 ^ ioLc lcI lcO cm + ioQ QI QO cm) → K
  | .a => XI v
  | .h => XI v
  | .inp => XI v
  | .out => XO v

/-- **The csIO link in `stgCsIODeg_of_claimSem`'s form** (by definition). -/
theorem stgCsIOm_claimSem (rI lcI QI rO lcO QO : ℕ) (XI : StgVw L → Fin rI → Fin (2 ^ lcI + QI) → K)
    (XO : StgVw L → Fin rO → Fin (2 ^ lcO + QO) → K) :
    ∀ v cm z, (cm = .inp ∨ cm = .out) →
      stgCsIOm U rI lcI QI rO lcO QO XI XO v cm z
        = claimSem U (ioR rI rO cm) (ioLc lcI lcO cm) (ioQ QI QO cm) (ioXm rI lcI QI rO lcO QO XI XO v cm) z := by
  intro v cm z h
  rcases h with rfl | rfl <;> rfl

/-- It reads a claim's functional only (`hIOI` / `hIOO`). -/
theorem stgCsIOm_value (rI lcI QI rO lcO QO : ℕ) (XI : StgVw L → Fin rI → Fin (2 ^ lcI + QI) → K)
    (XO : StgVw L → Fin rO → Fin (2 ^ lcO + QO) → K) :
    ∀ v (cm : Block.Cm) (z : Block.ZClaim) (a : Fp2),
      stgCsIOm U rI lcI QI rO lcO QO XI XO v cm { z with value := a } = stgCsIOm U rI lcI QI rO lcO QO XI XO v cm z := by
  intro v cm z a
  cases cm <;> rfl

/-- It reads the view below `n` when its matrices do (`hIOlI` / `hIOlO`). -/
theorem vwLoc_stgCsIOm (rI lcI QI rO lcO QO n : ℕ) (XI : StgVw L → Fin rI → Fin (2 ^ lcI + QI) → K)
    (XO : StgVw L → Fin rO → Fin (2 ^ lcO + QO) → K) (hI' : VwLoc n XI) (hO' : VwLoc n XO) :
    VwLoc n (stgCsIOm U rI lcI QI rO lcO QO XI XO) := by
  intro v v' h1 h2
  funext cm z
  cases cm with
  | a => rfl
  | h => rfl
  | inp =>
    show claimSem U rI lcI QI (XI v) z = claimSem U rI lcI QI (XI v') z
    rw [hI' v v' h1 h2]
  | out =>
    show claimSem U rO lcO QO (XO v) z = claimSem U rO lcO QO (XO v') z
    rw [hO' v v' h1 h2]

end Sem

section Deg

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) {L : ℕ}

theorem stgCsIOm_deg (hU : U ^ 2 = algebraMap GF K 7) (rI lcI QI rO lcO QO : ℕ)
    (XI : StgVw L → Fin rI → Fin (2 ^ lcI + QI) → K) (XO : StgVw L → Fin rO → Fin (2 ^ lcO + QO) → K) (eLog : ℕ)
    (pOk : Block.Priv → Prop) (hw : ∀ p, pOk p → min p.log eLog ≤ ioLc lcI lcO p.cm) :
    StgCsIODeg U hbij eLog pOk (stgCsIOm U rI lcI QI rO lcO QO XI XO) :=
  stgCsIODeg_mono U hbij eLog _ pOk _ hw
    (stgCsIODeg_of_claimSem (U := U) (hbij := hbij) hU eLog (ioR rI rO) (ioLc lcI lcO) (ioQ QI QO)
      (ioXm rI lcI QI rO lcO QO XI XO) _ (stgCsIOm_claimSem U rI lcI QI rO lcO QO XI XO))

/-- **Stage IN-C's `hIO0`** at the matrix semantics (the input endpoint's message width `lcI ≥ epLogN`). -/
theorem ssh_hIO0m (hU : U ^ 2 = algebraMap GF K 7) (Vi : IncV) (rI lcI QI rO lcO QO : ℕ)
    (XI : StgVw L → Fin rI → Fin (2 ^ lcI + QI) → K) (XO : StgVw L → Fin rO → Fin (2 ^ lcO + QO) → K)
    (hle : Vi.pub.epLogN ≤ lcI) :
    StgCsIODeg U hbij Vi.pub.epLogN (IncPrivIO0 Vi.pub) (stgCsIOm U rI lcI QI rO lcO QO XI XO) :=
  stgCsIOm_deg U hbij hU rI lcI QI rO lcO QO XI XO _ _ (fun p hp => by
    obtain ⟨hcm, -⟩ := hp
    rw [hcm]
    exact le_trans (min_le_right _ _) hle)

/-- **Stage IN-C's `hIO1`** at the matrix semantics (`B_in`'s message width `lcO ≥ bLogN`). -/
theorem ssh_hIO1m (hU : U ^ 2 = algebraMap GF K 7) (Vi : IncV) (rI lcI QI rO lcO QO : ℕ)
    (XI : StgVw L → Fin rI → Fin (2 ^ lcI + QI) → K) (XO : StgVw L → Fin rO → Fin (2 ^ lcO + QO) → K)
    (hle : Vi.geo.bLogN ≤ lcO) :
    StgCsIODeg U hbij Vi.geo.bLogN (IncPrivIO1 Vi.pub) (stgCsIOm U rI lcI QI rO lcO QO XI XO) :=
  stgCsIOm_deg U hbij hU rI lcI QI rO lcO QO XI XO _ _ (fun p hp => by
    obtain ⟨hcm, -⟩ := hp
    rw [hcm]
    exact le_trans (min_le_right _ _) hle)

/-- **Stage OUT-C's `hIO`** at the matrix semantics (`B_out`, on `.inp`, of message width `lcI ≥` every `bLogN`). -/
theorem ssh_hIOOm (hU : U ^ 2 = algebraMap GF K 7) (F : ℕ → OutcV) (rI lcI QI rO lcO QO : ℕ)
    (XI : StgVw L → Fin rI → Fin (2 ^ lcI + QI) → K) (XO : StgVw L → Fin rO → Fin (2 ^ lcO + QO) → K)
    (hle : ∀ b, (F b).geo.bLogN ≤ lcI) :
    ∀ b, StgCsIODeg U hbij (F b).geo.bLogN (OutcPrivIO (F b).pub) (stgCsIOm U rI lcI QI rO lcO QO XI XO) :=
  fun b => stgCsIOm_deg U hbij hU rI lcI QI rO lcO QO XI XO _ _ (fun p hp => by
    obtain ⟨hcm, -⟩ := hp
    rw [hcm]
    exact le_trans (min_le_right _ _) (hle b))

end Deg

section Dec

variable {K : Type} [Field K] [Algebra GF K] (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig)
  (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)

/-- **The input endpoint's matrix over the view**: `dec` (the commitment's decoder) applied to the checked extractor's
openings at the root the header shows at position `i` (read from the log cut there), message columns then pads,
embedded in `K`. -/
noncomputable def epDecX (rd : List UInt8 → Option Dig) (d i R lc Q N : ℕ)
    (dec : (Fin N → Option (MerkleOpening Dig Dig (ColR R))) → (Fin R → Fin (2 ^ lc) → GF) × (Fin R → Fin Q → GF))
    (v : StgVw L) : Fin R → Fin (2 ^ lc + Q) → K :=
  fun r t =>
    if h : t.val < 2 ^ lc then
      algebraMap GF K ((dec (epxH tag L h64 key domain hs hL rd d i R (N := N) (v.1 i) v.2)).1 r ⟨t.val, h⟩)
    else
      algebraMap GF K ((dec (epxH tag L h64 key domain hs hL rd d i R (N := N) (v.1 i) v.2)).2 r
        ⟨t.val - 2 ^ lc, by omega⟩)

/-- It reads the view below `n` when `i < n`. -/
theorem vwLoc_epDecX (rd : List UInt8 → Option Dig) (d i R lc Q N n : ℕ) (hi : i < n)
    (dec : (Fin N → Option (MerkleOpening Dig Dig (ColR R))) → (Fin R → Fin (2 ^ lc) → GF) × (Fin R → Fin Q → GF)) :
    VwLoc n (epDecX (K := K) tag L h64 key domain hs hL rd d i R lc Q N dec) := by
  intro v v' h1 h2
  have e : epxH tag L h64 key domain hs hL rd d i R (N := N) (v.1 i) v.2
      = epxH tag L h64 key domain hs hL rd d i R (N := N) (v'.1 i) v'.2 := by
    funext j
    show epxHn tag L h64 key domain hs hL rd d i R (v.1 i) v.2 j.val = epxHn tag L h64 key domain hs hL rd d i R (v'.1 i) v'.2 j.val
    unfold epxHn
    rw [h1 i hi, ssh_absAt_eq v.2 v'.2 n i hi h2]
  funext r t
  unfold epDecX
  rw [e]

/-- **At a header whose position `i` reads as the root `r`, the view's openings are the checked extractor's at `r` on
the whole log** (the view's cut there is coarser than the extractor's own cut, `ab_cut_coarse`). -/
theorem epDecX_ops_run (rd : List UInt8 → Option Dig) (d i R N : ℕ) (Lg : List (QB L × Dig))
    (hdr : List (TItem × Dig)) (x : List UInt8) (r : Dig) (hx : Block.absAt hdr i = some x) (hr : rd x = some r) :
    epxH tag L h64 key domain hs hL rd d i R (N := N)
        ((stgVw (Exec.Block.absOfC (chainEncB key domain hs L hL)) Lg hdr).1 i)
        (stgVw (Exec.Block.absOfC (chainEncB key domain hs L hL)) Lg hdr).2
      = fun j => epxAt tag L h64 key domain hs hL rd d R r Lg j.val := by
  funext j
  show epxHn tag L h64 key domain hs hL rd d i R (Block.cutO (Exec.Block.absOfC (chainEncB key domain hs L hL))
      (Block.absAt hdr i) Lg) hdr j.val = _
  unfold epxHn
  rw [hx, Option.bind_some, hr]
  dsimp only
  unfold epxAt
  have hfg : ∀ y, Block.absOfC (chainEncB key domain hs L hL) y = some x → absMOf L key domain hs hL rd y = some r :=
    fun y hy => by rw [absMOf, hy, Option.bind_some, hr]
  show ((merkleEncV tag L h64).ebOpenX (cutAt (absMOf L key domain hs hL rd) r
      (cutAt (Exec.Block.absOfC (chainEncB key domain hs L hL)) x Lg)) d j.val r).bind _ = _
  rw [← ab_cut_coarse _ _ x r hfg Lg]

end Dec

end ZK60.ProtocolClassify
