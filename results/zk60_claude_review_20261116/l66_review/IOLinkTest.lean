/-
D63 lane L63 (2026-11-17), part 30: **the stages' IO claims semantics over the view** (`csIOI`, `csIOO` made concrete;
the "csIO link" lane L65's `stgCsIODeg_of_claimSem` consumes).

A stage's claim on an IO commitment (the input endpoint, `B_in`, `B_out`, the output endpoint) is read as `stgCsv` reads
`A` and `H` (RunStgAlgPoly.lean:405-411): the claim's functional (`Link.claimSem`) on the message rows decoded at radius
`e` (`decodeRows (encGL lc h Q) e`) from the matrix extracted (`UxC`) for the root the stage's header absorbs at view
position `i`, from the log cut there. One geometry per commitment role: `.inp` at `(lcI, hI, QI, eI, rI, iI)`, `.out` at
`(lcO, hO, QO, eO, rO, iO)`.

* `stgCsIOv`: that semantics; `stgCsIOv_value` (it reads the claim's functional only: the top theorems' `hIOI`/`hIOO`),
  `vwLoc_stgCsIOv` (it reads the view below `n` when both roots sit below `n`: `hIOlI`/`hIOlO`);
* **`stgCsIOv_claimSem`**: the form `stgCsIODeg_of_claimSem` (RunStgShieldToK.lean:1350) consumes, by definition;
* `stgCsIODeg_mono`; **`ssh_hIO0`**, **`ssh_hIO1`**, **`ssh_hIOO`**: lane L65's `hIO0`, `hIO1` (stage IN-C) and `hIO`
  (stage OUT-C) at this semantics, when the role's message width `lc` is at least the slot model's row width (the
  input endpoint `epLogN`, `B_in`/`B_out` at `bLogN`): `min p.log eLog ≤ lc`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldDg

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Exec.StageV (IncV OutcV)
open ZK60.Circuit (gP GF)

section Sem

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) {L : ℕ} (h64 : 64 ≤ L)

/-- The message rows decoded from the matrix extracted for the root at view position `i` (`stgCsv`'s reading). -/
noncomputable def stgIOX (lc h Q e r i : ℕ) (v : StgVw L) : Fin r → Fin (2 ^ lc + Q) → K :=
  decodeRows (encGL (K := K) lc h Q) e (UxC tag L h64 h r (v.1 i) (Block.absAt v.2 i))

/-- **THE STAGES' IO CLAIMS SEMANTICS OVER THE VIEW**: a claim on `.inp` (on `.out`) is its functional on the rows
decoded from the matrix extracted for the root at view position `iI` (`iO`); `0` on `A`, `H` (read by `stgCsv`). -/
noncomputable def stgCsIOv (lcI hI QI eI rI iI lcO hO QO eO rO iO : ℕ) :
    StgVw L → Block.Cm → Block.ZClaim → K :=
  fun v cm z =>
    match cm with
    | .inp => claimSem U rI lcI QI (stgIOX tag h64 lcI hI QI eI rI iI v) z
    | .out => claimSem U rO lcO QO (stgIOX tag h64 lcO hO QO eO rO iO v) z
    | _ => 0

/-- The role's row count, message width, pad count and matrix (`.out`'s for `.out`, `.inp`'s otherwise). -/
def ioR (rI rO : ℕ) : Block.Cm → ℕ
  | .out => rO
  | _ => rI

def ioLc (lcI lcO : ℕ) : Block.Cm → ℕ
  | .out => lcO
  | _ => lcI

def ioQ (QI QO : ℕ) : Block.Cm → ℕ
  | .out => QO
  | _ => QI

noncomputable def ioX (lcI hI QI eI rI iI lcO hO QO eO rO iO : ℕ) (v : StgVw L) :
    (cm : Block.Cm) → Fin (ioR rI rO cm) → Fin (2 ^ ioLc lcI lcO cm + ioQ QI QO cm) → K
  | .a => stgIOX tag h64 lcI hI QI eI rI iI v
  | .h => stgIOX tag h64 lcI hI QI eI rI iI v
  | .inp => stgIOX tag h64 lcI hI QI eI rI iI v
  | .out => stgIOX tag h64 lcO hO QO eO rO iO v

/-- **THE csIO LINK IN `stgCsIODeg_of_claimSem`'s FORM**: on `.inp` and `.out`, `stgCsIOv` is `claimSem` over the role's
decoded matrix (by definition). -/
theorem stgCsIOv_claimSem (lcI hI QI eI rI iI lcO hO QO eO rO iO : ℕ) :
    ∀ v cm z, (cm = .inp ∨ cm = .out) →
      stgCsIOv U tag h64 lcI hI QI eI rI iI lcO hO QO eO rO iO v cm z
        = claimSem U (ioR rI rO cm) (ioLc lcI lcO cm) (ioQ QI QO cm)
            (ioX tag h64 lcI hI QI eI rI iI lcO hO QO eO rO iO v cm) z := by
  intro v cm z h
  rcases h with rfl | rfl <;> rfl

/-- It reads a claim's functional only (the top theorems' `hIOI` / `hIOO`). -/
theorem stgCsIOv_value (lcI hI QI eI rI iI lcO hO QO eO rO iO : ℕ) :
    ∀ v (cm : Block.Cm) (z : Block.ZClaim) (a : Fp2),
      stgCsIOv U tag h64 lcI hI QI eI rI iI lcO hO QO eO rO iO v cm { z with value := a }
        = stgCsIOv U tag h64 lcI hI QI eI rI iI lcO hO QO eO rO iO v cm z := by
  intro v cm z a
  cases cm <;> rfl

/-- It reads the view below `n` when both roots sit below `n` (the top theorems' `hIOlI` / `hIOlO`). -/
theorem vwLoc_stgCsIOv (lcI hI QI eI rI iI lcO hO QO eO rO iO n : ℕ) (hI' : iI < n) (hO' : iO < n) :
    VwLoc n (stgCsIOv U tag h64 lcI hI QI eI rI iI lcO hO QO eO rO iO) := by
  intro v v' h1 h2
  funext cm z
  cases cm with
  | a => rfl
  | h => rfl
  | inp =>
    show claimSem U rI lcI QI (stgIOX tag h64 lcI hI QI eI rI iI v) z = claimSem U rI lcI QI (stgIOX tag h64 lcI hI QI eI rI iI v') z
    unfold stgIOX
    rw [h1 iI hI', ssh_absAt_eq v.2 v'.2 n iI hI' h2]
  | out =>
    show claimSem U rO lcO QO (stgIOX tag h64 lcO hO QO eO rO iO v) z = claimSem U rO lcO QO (stgIOX tag h64 lcO hO QO eO rO iO v') z
    unfold stgIOX
    rw [h1 iO hO', ssh_absAt_eq v.2 v'.2 n iO hO' h2]

end Sem

section Deg

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {L : ℕ} (h64 : 64 ≤ L)

/-- `StgCsIODeg` is antitone in its admissibility predicate. -/
theorem stgCsIODeg_mono (eLog : ℕ) (pOk pOk' : Block.Priv → Prop) (csIO : StgVw L → Block.Cm → Block.ZClaim → K)
    (hw : ∀ p, pOk' p → pOk p) (H : StgCsIODeg U hbij eLog pOk csIO) : StgCsIODeg U hbij eLog pOk' csIO :=
  by
  intro v P hP N n e hN p hcm hp hsl hv hc
  exact H v P hP n e hN p hcm (hw p hp) hsl hv hc

/-- `StgCsIODeg` at the view semantics, for any predicate under which the claim's width fits the role's message width. -/
theorem stgCsIOv_deg (hU : U ^ 2 = algebraMap GF K 7) (lcI hI QI eI rI iI lcO hO QO eO rO iO eLog : ℕ)
    (pOk : Block.Priv → Prop) (hw : ∀ p, pOk p → min p.log eLog ≤ ioLc lcI lcO p.cm) :
    StgCsIODeg U hbij eLog pOk (stgCsIOv U tag h64 lcI hI QI eI rI iI lcO hO QO eO rO iO) :=
  stgCsIODeg_mono U hbij eLog _ pOk _ hw
    (stgCsIODeg_of_claimSem (U := U) (hbij := hbij) hU eLog (ioR rI rO) (ioLc lcI lcO) (ioQ QI QO)
      (ioX tag h64 lcI hI QI eI rI iI lcO hO QO eO rO iO) _ (stgCsIOv_claimSem U tag h64 lcI hI QI eI rI iI lcO hO QO eO rO iO))

/-- **Stage IN-C's `hIO0`** (INC-00's input-endpoint claim) at the view semantics, when the input endpoint's message width
is at least `epLogN` (equal at the code: `2^8`, token_io.rs:190). -/
theorem ssh_hIO0 (hU : U ^ 2 = algebraMap GF K 7) (Vi : IncV) (lcI hI QI eI rI iI lcO hO QO eO rO iO : ℕ)
    (hle : Vi.pub.epLogN ≤ lcI) :
    StgCsIODeg U hbij Vi.pub.epLogN (IncPrivIO0 Vi.pub) (stgCsIOv U tag h64 lcI hI QI eI rI iI lcO hO QO eO rO iO) :=
  stgCsIOv_deg U hbij tag h64 hU lcI hI QI eI rI iI lcO hO QO eO rO iO _ _ (fun p hp => by
    obtain ⟨hcm, -⟩ := hp
    rw [hcm]
    exact le_trans (min_le_right _ _) hle)

/-- **Stage IN-C's `hIO1`** (INC-01's `B_in` claim) at the view semantics, when `B_in`'s message width is at least
`bLogN` (equal at the code: the block geometry, `2^14`). -/
theorem ssh_hIO1 (hU : U ^ 2 = algebraMap GF K 7) (Vi : IncV) (lcI hI QI eI rI iI lcO hO QO eO rO iO : ℕ)
    (hle : Vi.geo.bLogN ≤ lcO) :
    StgCsIODeg U hbij Vi.geo.bLogN (IncPrivIO1 Vi.pub) (stgCsIOv U tag h64 lcI hI QI eI rI iI lcO hO QO eO rO iO) :=
  stgCsIOv_deg U hbij tag h64 hU lcI hI QI eI rI iI lcO hO QO eO rO iO _ _ (fun p hp => by
    obtain ⟨hcm, -⟩ := hp
    rw [hcm]
    exact le_trans (min_le_right _ _) hle)

/-- **Stage OUT-C's `hIO`** (its `B_out` claim, on `.inp`) at the view semantics, when `B_out`'s message width is at least
every verdict's `bLogN`. -/
theorem ssh_hIOO (hU : U ^ 2 = algebraMap GF K 7) (F : ℕ → OutcV) (lcI hI QI eI rI iI lcO hO QO eO rO iO : ℕ)
    (hle : ∀ b, (F b).geo.bLogN ≤ lcI) :
    ∀ b, StgCsIODeg U hbij (F b).geo.bLogN (OutcPrivIO (F b).pub)
      (stgCsIOv U tag h64 lcI hI QI eI rI iI lcO hO QO eO rO iO) :=
  fun b => stgCsIOv_deg U hbij tag h64 hU lcI hI QI eI rI iI lcO hO QO eO rO iO _ _ (fun p hp => by
    obtain ⟨hcm, -⟩ := hp
    rw [hcm]
    exact le_trans (min_le_right _ _) (hle b))

end Deg

end ZK60.ProtocolClassify


namespace ZK60.ProtocolClassify
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Exec.StageV (IncV OutcV)
open ZK60.Circuit (gP GF)

-- REVIEW TEST (reviewer-generated). The three conjuncts of hCsIO are copied verbatim from
-- RunBlkPinsHd.lean:3385-3387, with csIOI := csIOO := stgCsIOv ... . The branch theorems are applied with their own
-- extra hypotheses (hU, and the width hypotheses hle) left as explicit assumptions.
example {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (tag : MTag) {L : ℕ} (h64 : 64 ≤ L) (hU : U ^ 2 = algebraMap GF K 7) (Vi : IncV) (F : ℕ → OutcV)
    (lcI hI QI eI rI iI lcO hO QO eO rO iO : ℕ)
    (hle0 : Vi.pub.epLogN ≤ lcI) (hle1 : Vi.geo.bLogN ≤ lcO) (hleO : ∀ b, (F b).geo.bLogN ≤ lcI) :
    let csIOI : StgVw L → Block.Cm → Block.ZClaim → K := stgCsIOv U tag h64 lcI hI QI eI rI iI lcO hO QO eO rO iO
    let csIOO : StgVw L → Block.Cm → Block.ZClaim → K := stgCsIOv U tag h64 lcI hI QI eI rI iI lcO hO QO eO rO iO
    ZK60.ProtocolClassify.StgCsIODeg U hbij Vi.pub.epLogN (ZK60.ProtocolClassify.IncPrivIO0 Vi.pub) csIOI
      ∧ ZK60.ProtocolClassify.StgCsIODeg U hbij Vi.geo.bLogN (ZK60.ProtocolClassify.IncPrivIO1 Vi.pub) csIOI
      ∧ ∀ b, ZK60.ProtocolClassify.StgCsIODeg U hbij (F b).geo.bLogN (ZK60.ProtocolClassify.OutcPrivIO (F b).pub) csIOO :=
  ⟨ssh_hIO0 U hbij tag h64 hU Vi lcI hI QI eI rI iI lcO hO QO eO rO iO hle0,
   ssh_hIO1 U hbij tag h64 hU Vi lcI hI QI eI rI iI lcO hO QO eO rO iO hle1,
   ssh_hIOO U hbij tag h64 hU F lcI hI QI eI rI iI lcO hO QO eO rO iO hleO⟩

end ZK60.ProtocolClassify
