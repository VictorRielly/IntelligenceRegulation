import ZK60Formal.BlockLookBase

open ZK60.Exec ZK60.Exec.Block ZK60.Exec.Block.DefW16
open ZK60.Exec.Block.Join.W16.Look

example : (lookupsN cfgRungW16 LkDom.D.dom).getD 18 ⟨[], 0, 0⟩ = ⟨[(26, 1)], 32768, 16⟩ := rfl
example : (lookupsN cfgRungW16 LkDom.F.dom).getD 4 ⟨[], 0, 0⟩ = ⟨[(55, 1), (56, -65536)], 0, 16⟩ := rfl
example : (lookupsN cfgRungW16 LkDom.S.dom).getD 1 ⟨[], 0, 0⟩ = ⟨[(39, -1)], 127, 8⟩ := rfl
example : aOff cfgRungW16 26 = 425984 := rfl
example : aOff cfgRungW16 56 = 1130496 := by decide
example : (lookupsN cfgRungW16 LkDom.D.dom).length = 19 := by decide
