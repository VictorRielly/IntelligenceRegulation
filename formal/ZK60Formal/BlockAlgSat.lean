/-
D63 lane L36 (2026-11-09), part 7: **facts that this lane's premises can be met at the registered shapes** (the
audit asked by the coordinator: a premise that no real block can meet makes a statement vacuous, finding L31-1's
pattern). Decided on the code's recorded draw lists and lookup counts:

* `w16r2_batch_room`, `r13_batch_room_rung`, `r13_batch_room_shield`: each host's batch (`μ` less its pad weight)
  has room for the named clauses `W16Spec` / `R13Spec` place in it (`relCount`, `r13Count`): a necessary condition for
  `W16Spec.cl` / `R13Spec.cl` at the code's batches;
* `shield_he26_room`: at the Shieldstral T128 R13 block, the code's lookups (`64,258,048`) plus twice the table
  positions (three columns of `2^14`) are within `2^26`: the repaired `he` can be met by a lookup list of the code's
  size and a table enumeration of at most the table domain's positions (finding L36-1);
* `w16r2_he_room`, `r13_rung_he_room`: the same at the two rungs against the original `35,153,256`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockAlgLkFinal
import ZK60Formal.BlockAlgShapes

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Exec.Slot.W16R2 (Seg segLn shRungW16)

/-- **Each W16R2 rung host's batch has room for `W16Spec`'s clauses** (`6, 6, 1, 1, 4, 1`). -/
theorem w16r2_batch_room : ∀ k ∈ algHosts,
    relCount k ≤ segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .mu
      - segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .zeta := by
  decide

/-- **Each R13 rung host's batch has room for `R13Spec`'s clauses** (`6, 13, 4, 4, 5, 3`). -/
theorem r13_batch_room_rung : ∀ k ∈ algHosts,
    r13Count k ≤ segLn (ZK60.Exec.Slot.R13.draws ZK60.Exec.Slot.R13.shRungR13 k) .mu
      - segLn (ZK60.Exec.Slot.R13.draws ZK60.Exec.Slot.R13.shRungR13 k) .zeta := by
  decide

/-- **Each Shieldstral T128 R13 host's batch has room for `R13Spec`'s clauses.** -/
theorem r13_batch_room_shield : ∀ k ∈ algHosts,
    r13Count k ≤ segLn (ZK60.Exec.Slot.R13.draws ZK60.Exec.Slot.R13.shShieldR13 k) .mu
      - segLn (ZK60.Exec.Slot.R13.draws ZK60.Exec.Slot.R13.shShieldR13 k) .zeta := by
  decide

/-- **The repaired lookup bound can be met at the Shieldstral T128 R13 block**: the code's lookups over the padded
cubes plus twice the table domain's positions (the u8, exp and ACT columns of `SC_TAB`, and no range sub-plane at R13,
each of `2^14` rows) are within `2^26`. -/
theorem shield_he26_room :
    lkCount ZK60.Exec.Slot.R13.shShieldR13 perR13Shield
        + 2 * ((3 + ZK60.Exec.Slot.R13.shShieldR13.nRange) * 2 ^ ZK60.Exec.Slot.R13.shShieldR13.logs .Tab)
      ≤ 2 ^ 26 := by
  rw [lkCount_r13_shield]
  decide

/-- The original lookup bound can be met at the W16R2 rung (the table's three columns and its range sub-planes). -/
theorem w16r2_he_room :
    lkCount shRungW16 perW16Rung + 2 * ((3 + shRungW16.nRange) * 2 ^ shRungW16.logs .Tab) ≤ 35153256 := by
  rw [lkCount_w16r2_rung]
  decide

/-- The original lookup bound can be met at the R13 rung. -/
theorem r13_rung_he_room :
    lkCount ZK60.Exec.Slot.R13.shRungR13 perR13Rung
        + 2 * ((3 + ZK60.Exec.Slot.R13.shRungR13.nRange) * 2 ^ ZK60.Exec.Slot.R13.shRungR13.logs .Tab)
      ≤ 35153256 := by
  rw [lkCount_r13_rung]
  decide

end ZK60.Exec.Block
