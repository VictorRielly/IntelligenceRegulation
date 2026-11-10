import ZK60Formal.BlockLookBase

open ZK60.Exec ZK60.Exec.Block ZK60.Exec.Block.DefW16 ZK60.Exec.Block.Join ZK60.Exec.Block.Join.W16
open ZK60.Exec.Slot.W16R2 (Seg)

#eval [2, 14, 15, 16, 17, 18].map fun k =>
  (k, segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .tau, segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .mu,
    segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .zeta, relCount k)
#eval (algShapeW16Rung).name
#check @algShapeW16Rung
#print relCount
example : segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 14) .tau = 14 := rfl
example (f : (Fin 14 → Bool) → ℕ) (b : Fin (segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 14) .tau) → Bool) : ℕ := f b
example (f : (Fin 15 → Bool) → ℕ) (b : Fin (segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 15) .tau) → Bool) : ℕ := f b
#eval (logupSumW16 cfgRungW16).parts.map fun p => (p.offset / 2 ^ 14, p.logSize, p.point.length)
#eval (List.range 46).map fun hp => cfgRungW16.sh.logs ((hDoms cfgRungW16).getD hp .Tab)
#eval (lookupsN cfgRungW16 .L).map fun l => l.terms
