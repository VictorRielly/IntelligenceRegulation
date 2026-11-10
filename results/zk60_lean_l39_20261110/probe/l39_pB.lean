/- D63 lane L39 probe B (scratch): stage OUT-C's smallest definition, then its largest (DZC, two loops). -/
import ZK60Formal.StageVerifyExecOutC
import ZK60Formal.BlockInstRead

set_option autoImplicit false

open ZK60 ZK60.Exec ZK60.Exec.StageV

def pcntB (df : Block.SlotDef) : ℕ × ℕ × ℕ × ℕ :=
  (Block.cmCount .a df.tabs, Block.cmCount .h df.tabs, Block.cmCount .inp df.tabs, Block.cmCount .out df.tabs)

set_option profiler true in
theorem pB_ss (O : OutcPub) (G : OutcGeo) : (outcDefSS O G).map pcntB = .ok (1, 0, 0, 0) := rfl
