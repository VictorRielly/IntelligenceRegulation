import ZK60Formal.BlockAlgShapes
import ZK60Formal.BlockDefineW16Rung

open ZK60.Exec ZK60.Exec.Block ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.W16R2 (segLn segOff segSum shRungW16)

example (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (mpad : ℕ → ℕ)
    (hm0 : ∀ k ∈ algHosts, segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .zeta = 0 → mpad k = 0)
    (hm78 : ∀ k ∈ algHosts, mpad k ≤ 78)
    (b : Fin (segLn ((algShapeW16Rung P hdr mpad hm0 hm78).dl 2) .tau) → Bool) : Fin 5 → Bool := b

example (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (mpad : ℕ → ℕ)
    (hm0 : ∀ k ∈ algHosts, segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .zeta = 0 → mpad k = 0)
    (hm78 : ∀ k ∈ algHosts, mpad k ≤ 78)
    (b : Fin (segLn ((algShapeW16Rung P hdr mpad hm0 hm78).dl 14) .tau) → Bool) : Fin 14 → Bool := b

example (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (mpad : ℕ → ℕ)
    (hm0 : ∀ k ∈ algHosts, segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .zeta = 0 → mpad k = 0)
    (hm78 : ∀ k ∈ algHosts, mpad k ≤ 78) :
    segOff ((algShapeW16Rung P hdr mpad hm0 hm78).dl 2) .mu = 5 ∧
    segLn ((algShapeW16Rung P hdr mpad hm0 hm78).dl 2) .mu = 6 ∧
    segOff ((algShapeW16Rung P hdr mpad hm0 hm78).dl 2) .nu = 11 := by
  decide

example (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (mpad : ℕ → ℕ)
    (hm0 : ∀ k ∈ algHosts, segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .zeta = 0 → mpad k = 0)
    (hm78 : ∀ k ∈ algHosts, mpad k ≤ 78) (t : ℕ) :
    (algShapeW16Rung P hdr mpad hm0 hm78).ip 2 0 t = t := rfl

example (P : BlockParams) (hsl : P.geom.slots = W16R2.rungSlots) : slotShape P 2 = (5, 1, 3) := by
  simp only [slotShape, hsl]
  decide
