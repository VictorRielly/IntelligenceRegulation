/- D63 lane L39 probe E (scratch): the verdict does not change OUT-C's layout (defeq through a structure update). -/
import ZK60Formal.StageVerifyExec

set_option autoImplicit false

open ZK60 ZK60.Exec ZK60.Exec.StageV

def pVerdict (O : OutcPub) (v : ℕ) : OutcPub := { O with verdict := v }

set_option profiler true in
theorem pE_lay (O : OutcPub) (b v : ℕ) : outcLay (pVerdict O v) b = outcLay O b := rfl

set_option profiler true in
theorem pE_draws (O : OutcPub) (v : ℕ) : outcDraws (pVerdict O v) = outcDraws O := rfl
