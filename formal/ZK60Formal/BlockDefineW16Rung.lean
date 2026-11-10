/-
D63 lane L35 (2026-11-09), part 8: **the W16R2 rung's slot program, evaluated**.

* `privOKb_congr`, `tabOKb_fun`, **`progOKb_congr`**: the program's check reads the commitments' row logs only through
  their positivity;
* `precRungW16`, `famsRungW16`, **`cfgRungW16`**: the rung's configuration (L13's export `layout.txt`, block
  `W16R2_RUNG_H24`: `PREC`, `FAMS`, `log_cols = 14`; the shape is L23's `shRungW16`);
* **`progW16_rung_ok`**: the rung's program passes its check against the rung's schedule `W16R2.rungSlots`: every private
  table's coordinates read each challenge at most once, and every slot IR's degree in its tables is at most the slot's
  degree (evaluated);
* **`progW16_rung_cntA`**, **`progW16_rung_cntH`**: its private tables per slot in `A` and in `H` are L31's
  `aCntW16Rung` and `hCntW16Rung` (evaluated: this confirms L31's derived per-slot `A` split at the rung);
* `progW16_rung_okP`: the check at any `BlockParams` with the rung's schedule and positive row logs.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockDefineW16
import ZK60Formal.BlockInstProf

set_option autoImplicit false

namespace ZK60.Exec.Block

/-- The check reads a row log only through its positivity. -/
theorem privOKb_congr (rl rl' : Cm → ℕ) (h : ∀ cm, 0 < rl cm ↔ 0 < rl' cm) (p : PrivS) :
    privOKb rl p = privOKb rl' p := by
  have e : decide (0 < rl p.cm) = decide (0 < rl' p.cm) := decide_eq_decide.mpr (h p.cm)
  simp only [privOKb, e]

theorem tabOKb_fun (rl rl' : Cm → ℕ) (h : ∀ cm, 0 < rl cm ↔ 0 < rl' cm) : tabOKb rl = tabOKb rl' := by
  funext t
  cases t with
  | priv p => exact privOKb_congr rl rl' h p
  | eq _ _ => rfl
  | pub _ => rfl

/-- **The program's check depends on the row logs only through their positivity.** -/
theorem progOKb_congr (rl rl' : Cm → ℕ) (h : ∀ cm, 0 < rl cm ↔ 0 < rl' cm) :
    ∀ (ss : List SlotS) (slots : List (ℕ × ℕ × ℕ)), progOKb rl ss slots = progOKb rl' ss slots
  | [], [] => rfl
  | [], _ :: _ => rfl
  | _ :: _, [] => rfl
  | s :: ss, d :: ds => by
    show (slotOKb rl d.2.2 s && progOKb rl ss ds) = (slotOKb rl' d.2.2 s && progOKb rl' ss ds)
    rw [progOKb_congr rl rl' h ss ds]
    unfold slotOKb
    rw [tabOKb_fun rl rl' h]

end ZK60.Exec.Block

namespace ZK60.Exec.Block.DefW16

open ZK60.Exec.Slot.Build.Lay (PrecW)

/-- The rung's precision (`layout.txt`, `W16R2_RUNG_H24`, line `PREC`). -/
def precRungW16 : PrecW :=
  { h24 := true, tn := 2, cnA := 4000, cnM := 4000, ceps := 1, q := 15, k := 15, v := 16, score := 18, pv := 12,
    ao := 21, gate := 19, up := 12, prodbits := 24, down := 20, fp := 12, wrho := 17, rope := 7, fold := 16 }

/-- The rung's range families `(width, sub-planes)` (`layout.txt`, line `FAMS`). -/
def famsRungW16 : List (ℕ × ℕ) := [(1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (7, 1), (12, 1), (13, 1), (15, 2), (16, 4)]

/-- **The W16R2 rung's configuration.** -/
def cfgRungW16 : W16Cfg := ⟨ZK60.Exec.Slot.W16R2.shRungW16, precRungW16, famsRungW16, 14⟩

/-- **The rung's program passes its check** (row logs positive). -/
theorem rawProg_rung_ok : progOKb (fun _ => 1) (rawProg cfgRungW16) W16R2.rungSlots = true := by
  decide +kernel

theorem progW16_rung_ok (ioIn ioOut : ℕ) :
    progOKb (fun _ => 1) (progW16 cfgRungW16 ioIn ioOut) W16R2.rungSlots = true := by
  unfold progW16
  rw [numProg_ok]
  exact rawProg_rung_ok

/-- **The rung's private tables in `A` per slot are L31's `aCntW16Rung`.** -/
theorem progW16_rung_cntA (ioIn ioOut : ℕ) :
    (progW16 cfgRungW16 ioIn ioOut).map (fun s => cmCountS .a s.tabs) = Link.aCntW16Rung := by
  unfold progW16
  rw [numProg_cm]
  decide +kernel

/-- **The rung's private tables in `H` per slot are L31's `hCntW16Rung`.** -/
theorem progW16_rung_cntH (ioIn ioOut : ℕ) :
    (progW16 cfgRungW16 ioIn ioOut).map (fun s => cmCountS .h s.tabs) = Link.hCntW16Rung := by
  unfold progW16
  rw [numProg_cm]
  decide +kernel

/-- The check at a block verifier with the rung's schedule and positive row logs. -/
theorem progW16_rung_okP (P : BlockParams) (hsl : P.geom.slots = W16R2.rungSlots) (hlc : 0 < P.logCols)
    (hep : 0 < P.endpointLogN) (ioIn ioOut : ℕ) :
    progOKb (rowLog P) (progW16 cfgRungW16 ioIn ioOut) P.geom.slots = true := by
  rw [hsl, progOKb_congr (rowLog P) (fun _ => 1) (fun cm => by cases cm <;> simp [rowLog, hlc, hep])]
  exact progW16_rung_ok ioIn ioOut

end ZK60.Exec.Block.DefW16
