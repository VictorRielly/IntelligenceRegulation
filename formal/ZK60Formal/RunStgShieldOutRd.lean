/-
D63 lane L63 (2026-11-20), L63 leg 14, part 94: **what one non-doomed OUT-C reading gives, at `τ`'s view** (the
assembly kit of `hdoutC`, items 6 and 7 of HANDOFF_20261119_3.md section 6, and the per-slot define vanishing).

`hdoutC`'s conclusion `StgDoomAtV … (OUT-C)` fails at an accepted run exactly when some OUT-C reading has none of the
three doom disjuncts. At such a reading:
* **`stg_outc_def_zero_tauA`**: (first disjunct false) a drawing slot's define polynomial vanishes at every draw at
  `τ`'s view (the twin of `stg_outc_def_zero_tauN`, from the slot's alive state instead of "no doomed entrant");
* **`shd_outc_zero_rdA`**: the same on the schedule `F b` (`vdWout F (τ.take n0) = F b`), in `stgΦB` form;
* **`shd_outc_bytes_rd`**: (second disjunct false) item 6, `AllBytes` of the limb plane and DZC's pairs at `τ`'s view
  (`stgLkOut_nil`; the `A_out` root sits below the head);
* **`bndPlanes_tau`**: item 7's plane identity at `τ`'s view: the extracted boundary plane `j` is `piB` of `bxUxV`'s
  R13 plane reader at `τ`'s view, when `off j + 2 < hdrLen + 4` (both read the same `decodeRows` of the same `UxC`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutMargin
import ZK60Formal.RunStgShieldOutAtN
import ZK60Formal.RunStgShieldEpxIO

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

section Zero

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  {Lq : ℕ}

/-- **A drawing slot's define polynomial vanishes at every draw at `τ`'s view, from its alive state at the reading.** -/
theorem stg_outc_def_zero_tauA (key : Option Dig) (domain : List UInt8) (absOf : QB Lq → Option (List UInt8))
    (tag : MTag) (h64 : 64 ≤ Lq) (P0 : Block.BlockParams) (F : ℕ → OutcV) (b n0 hdrLen lc h Q e rA rH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (hIOl : VwLoc (hdrLen + (7 + 2)) csIO)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain Lq (fun _ => (F b).bp) 2 hdrLen OutcV.bga G τ hdr core ch rs)
    (hP : StgSame P0 (F b).bp) (hgt : (F b).bp.geom.slots.length = (F b).bp.geom.terms.length)
    (hgeom : ∀ k, k < (F b).bp.geom.slots.length → 1 ≤ (Block.slotShape (F b).bp k).2.2)
    (k : ℕ) (hk : k ∈ stgDrawing P0)
    (hal : (stgDefSqV P0 2 hdrLen absOf (sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO) sshDgO k).St lg
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps (F b).bp core 2 ++ Block.fullOps (F b).bp 0 (core.slots.take k))) []) :
    ∀ y, sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO (stgVw absOf lg τ) k
        (ch, (rs.take k).map Block.SlotRec.draws) y = 0 := by
  intro y
  have hslen : core.slots.length = (F b).bp.geom.slots.length := hrd.2.2.2.1.1
  have hkl : k < core.slots.length := by
    rw [hslen, ← hP.2]
    exact List.mem_range.mp (List.mem_filter.mp hk).1
  have hz := stg_def_zero_of_alive key domain P0 (fun _ => (F b).bp) 2 hdrLen OutcV.bga absOf
    (sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO) sshDgO G lg τ hdr core ch rs hrd hP hgeom hgt k hkl.le
    hal y
  obtain ⟨q, hq⟩ : ∃ q, core.slots[k]? = some q := ⟨_, List.getElem?_eq_getElem hkl⟩
  obtain ⟨h1, -⟩ := stg_rd_def key domain (fun _ => (F b).bp) 2 hdrLen OutcV.bga G τ hdr core ch rs hrd hgt k q hq
  have hmv := vw_take absOf lg (hdrLen + (7 + 2)) (stgDefPos (F b).bp 2 hdrLen k) (by unfold stgDefPos; omega) _
    (vwLoc_sshΦO_any U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO hIOl k
      (ch, (rs.take k).map Block.SlotRec.draws) y) τ
  rw [← hmv, h1]
  exact hz

/-- **The same on the schedule `F b`, in `stgΦB` form.** -/
theorem shd_outc_zero_rdA (key : Option Dig) (domain : List UInt8) (absOf : QB Lq → Option (List UInt8))
    (tag : MTag) (h64 : 64 ≤ Lq) (P0 : Block.BlockParams) (F : ℕ → OutcV) (b n0 hdrLen lc h Q e rA rH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (hIOl : VwLoc (hdrLen + (7 + 2)) csIO)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain Lq (fun _ => (F b).bp) 2 hdrLen OutcV.bga G τ hdr core ch rs)
    (hP : StgSame P0 (F b).bp) (hgt : (F b).bp.geom.slots.length = (F b).bp.geom.terms.length)
    (hgeom : ∀ k, k < (F b).bp.geom.slots.length → 1 ≤ (Block.slotShape (F b).bp k).2.2)
    (hW : vdWout F (τ.take n0) = F b) (k : ℕ) (hk : k ∈ stgDrawing P0)
    (hal : (stgDefSqV P0 2 hdrLen absOf (sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO) sshDgO k).St lg
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps (F b).bp core 2 ++ Block.fullOps (F b).bp 0 (core.slots.take k))) []) :
    ∀ y : Fin (P0.draws k) → K, stgΦB U hbij P0 (F b).bp
      (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 2) csIO (stgVw absOf lg τ))
      (OutcV.bga ch) ((rs.take k).map Block.SlotRec.draws) k (stgWords U hbij y) = 0 := by
  intro y
  have hz0 := stg_outc_def_zero_tauA U hbij key domain absOf tag h64 P0 F b n0 hdrLen lc h Q e rA rH csIO hIOl G lg τ
    hdr core ch rs hrd hP hgt hgeom k hk hal y
  have h' : stgΦB U hbij P0 (vdWout F (τ.take n0)).bp
      (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 2) csIO (stgVw absOf lg τ))
      (OutcV.bga ch) ((rs.take k).map Block.SlotRec.draws) k (stgWords U hbij y) = 0 := hz0
  rw [hW] at h'
  exact h'

end Zero

section Bytes

variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K] (U : K) (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- **Item 6: the LogUp state alive at the head gives `AllBytes` at `τ`'s view.** -/
theorem shd_outc_bytes_rd (key : Option Dig) (domain : List UInt8) (absOf : QB Lq → Option (List UInt8))
    (O : OutcPub) (hdrLen e : ℕ) (Pof : List Fp2 → Block.BlockParams) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain Lq Pof 2 hdrLen bgaOf G τ hdr core ch rs)
    (hlk : (stgLkSqV 2 hdrLen e absOf (shd_ΛO U tag h64 O hdrLen)).St lg
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core)) []) :
    AllBytes (shdOutcLimb U tag h64 O hdrLen (stgVw absOf lg τ))
      (fun kc : Fin 6 × (Fin 12 → Bool) => dLookB (shdOutcPl U tag h64 O hdrLen (stgVw absOf lg τ)) (pIdx1 kc.1) kc.2)
      (fun kc : Fin 6 × (Fin 12 → Bool) => dLookB (shdOutcPl U tag h64 O hdrLen (stgVw absOf lg τ)) (pIdx2 kc.1) kc.2) := by
  obtain ⟨h1, -⟩ := stg_rd_head key domain Pof 2 hdrLen bgaOf G τ hdr core ch rs hrd
  have hloc : ∀ off, stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 hdrLen off 12
      (stgVw absOf lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core)))
      = stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 hdrLen off 12 (stgVw absOf lg τ) := by
    intro off
    rw [← h1]
    exact vw_take absOf lg (hdrLen + 4) (hdrLen + 4) le_rfl _
      (vwLoc_stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 hdrLen off 12 (hdrLen + 4) (by omega)) τ
  have eL : shdOutcLimb U tag h64 O hdrLen
      (stgVw absOf lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core)))
      = shdOutcLimb U tag h64 O hdrLen (stgVw absOf lg τ) := hloc _
  have eP : shdOutcPl U tag h64 O hdrLen
      (stgVw absOf lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core)))
      = shdOutcPl U tag h64 O hdrLen (stgVw absOf lg τ) := by
    funext p
    exact hloc _
  have h := (stgLkOut_nil (shdOutcLimb U tag h64 O hdrLen) (shdOutcPl U tag h64 O hdrLen)
    (shdOutcMult U tag h64 O hdrLen) _).mp hlk
  rw [eL, eP] at h
  exact h

end Bytes

section Tie

variable {K : Type} [Field K] [Algebra GF K] {Lq : ℕ}

/-- **Item 7's plane identity at `τ`'s view**: the extracted boundary plane `j` is `piB` of `bxUxV`'s R13 plane reader
at the run's transcript view, at an OUT-C-like reading whose head lies past `off j + 2`. -/
theorem bndPlanes_tau (U : K) (tag : MTag) (h64 : 64 ≤ Lq)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
    (D : RtKData K Lq) (dPos0 : RunShape.Shield.shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (lg : List (QB Lq × Dig)) (o : α) (j : ℕ) (p : RunShape.Shield.shieldS0.Pos) (R : ℕ)
    (hg : (D.opX (j + 1)).h = 16 ∧ (D.opX (j + 1)).lc = 14 ∧ (D.opX (j + 1)).Q = 256
      ∧ (D.opX (j + 1)).e = 24448 ∧ (D.opX (j + 1)).rows = R)
    (G : QB Lq → Dig) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain Lq Pof m hdrLen bgaOf G (rtTr key domain Lq pf rd G o) hdr core ch rs)
    (hj : pf.off j + 2 < hdrLen + 4) :
    bndPlanes U tag Lq h64 key domain hs hL pf rd D dPos0 lg o j p
      = Exec.Block.Join.W16.piB K (Exec.Block.Join.planeZ U 14 R 256
          (bxUxV tag Lq h64 R (pf.off j + 2) (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg
            (rtTr key domain Lq pf rd G o)))
          ⟨.a, [(0, Fp2.one)], 19, [], 0, 0⟩ (Fin.append (dPos0 p).1 (dPos0 p).2)) := by
  rw [bndPlanes_head U tag h64 key domain hs hL pf rd D dPos0 lg o j p R hg G Pof m hdrLen bgaOf hdr core ch rs hrd hj]
  obtain ⟨h1, -⟩ := stg_rd_head key domain Pof m hdrLen bgaOf G _ hdr core ch rs hrd
  rw [← h1, vw_take (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg (hdrLen + 4) (hdrLen + 4) le_rfl _
    (vwLoc_bxUxV tag Lq h64 R (pf.off j + 2) (hdrLen + 4) hj) _]

end Tie

end ZK60.ProtocolClassify
