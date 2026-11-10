/- D63 lane L39 probe D (scratch): the geometry facts and the slot bounds. -/
import ZK60Formal.StageVerifyExec

set_option autoImplicit false

open ZK60 ZK60.Exec ZK60.Exec.StageV

set_option profiler true in
theorem pD_len (V : IncV) : V.geom.slots.length = 4 := rfl

set_option profiler true in
theorem pD_lenO (V : OutcV) : V.geom.slots.length = 8 := rfl

set_option profiler true in
theorem pD_gt (V : IncV) : V.geom.slots.length = V.geom.terms.length := rfl

set_option profiler true in
theorem pD_bnd (V : IncV) (cx : IncCtx) (j : ℕ) (hj : j < V.geom.slots.length) :
    1 ≤ (Block.slotShape (V.bp cx) j).2.2 ∧ (Block.slotShape (V.bp cx) j).2.2 ≤ 4
      ∧ Block.slotTerms (V.bp cx) j ≤ 3 := by
  have hj4 : j < 4 := lt_of_lt_of_eq hj (pD_len V)
  interval_cases j <;> exact ⟨Nat.le_of_ble_eq_true rfl, Nat.le_of_ble_eq_true rfl, Nat.le_of_ble_eq_true rfl⟩
