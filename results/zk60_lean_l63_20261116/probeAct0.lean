/-
D63 lane L63 leg 20 (2026-11-22): finding L68c-1. `BlockPublic.Valid` gains the field `act0 : P.act 0 2048 = 0`
(CircuitBlock.lean); Antigravity's premise `hAct0 : Pb.act 0 2048 = 0` (branch agy/lean-l68c,
HonestShieldBlockWitness.lean:661,685) is then `hPb.act0`, and the run-level form ("for every block b of the run,
b.pub.act 0 2048 = 0") follows from the run's per-block `Valid` premise. The two changed declarations of
RunShapeShield.lean (`zeroPub_valid`, and `shield_run_exists` through it) are audited here.
Run by `lake env lean` in a guarded job; not in the root.
-/
import ZK60Formal.RunShapeShield

open ZK60.Block ZK60.RunShape

namespace ZK60.L63Act0Probe

/-- Antigravity's `hAct0`, from `Valid`. -/
theorem hAct0_of_valid {S : BlockShape} (Pb : BlockPublic S) (hPb : Pb.Valid) : Pb.act 0 2048 = 0 :=
  hPb.act0

/-- The run-level form: every block of a run whose blocks' public data are `Valid`. -/
theorem hAct0_run {S0 : BlockShape} (bs : List (RunBlock S0)) (h : ∀ b ∈ bs, b.pub.Valid) :
    ∀ b ∈ bs, b.pub.act 0 2048 = 0 :=
  fun b hb => (h b hb).act0

/-- The same from `RunBlock.Valid`. -/
theorem hAct0_runV {S0 : BlockShape} (bs : List (RunBlock S0)) (h : ∀ b ∈ bs, b.Valid) :
    ∀ b ∈ bs, b.pub.act 0 2048 = 0 :=
  fun b hb => (h b hb).pub.act0

end ZK60.L63Act0Probe

#print axioms ZK60.L63Act0Probe.hAct0_of_valid
#print axioms ZK60.L63Act0Probe.hAct0_run
#print axioms ZK60.L63Act0Probe.hAct0_runV
#print axioms ZK60.RunShape.Shield.zeroPub_valid
#print axioms ZK60.RunShape.Shield.shield_run_exists
