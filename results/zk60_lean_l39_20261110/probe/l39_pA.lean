/- D63 lane L39 probe A (scratch): does `rfl` evaluate stage IN-C's smallest definitions' claim counts cheaply? -/
import ZK60Formal.StageVerifyExecInC
import ZK60Formal.BlockInstRead

set_option autoImplicit false

open ZK60 ZK60.Exec ZK60.Exec.StageV

def pcnt (df : Block.SlotDef) : ℕ × ℕ × ℕ × ℕ :=
  (Block.cmCount .a df.tabs, Block.cmCount .h df.tabs, Block.cmCount .inp df.tabs, Block.cmCount .out df.tabs)

set_option profiler true in
theorem pA_zs (I : IncPub) (G : IncGeo) : (incDefZS I G).map pcnt = .ok (0, 1, 0, 0) := rfl

set_option profiler true in
theorem pA_io (I : IncPub) (G : IncGeo) (dr : List Fp2) : (incDefIO I G dr).map pcnt = .ok (1, 0, 1, 0) := rfl
