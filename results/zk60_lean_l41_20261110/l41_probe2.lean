import ZK60Formal.BlockDefineW16Rung
import ZK60Formal.BlockAlgShapes

open ZK60.Exec ZK60.Exec.Block ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build

def pa (off log m : ℕ) : TabS := .priv ⟨.a, [(off, false)], log, rhoC 0 log, m, 0⟩

def tabs2W : List TabS :=
  [.eq ((List.range 5).map (Sym.dr 2)) 0, .eq ((List.range 5).map (Sym.dr 0)) 0,
    .eq ((List.range 5).map (Sym.dr 1)) 0, pa 0 5 94, pa 16384 5 96]
  ++ (List.range 9).map (fun k => pa (98304 + 32 * k) 5 (98 + 2 * k))
  ++ [pa 32768 5 116, pa 49152 5 118]
  ++ (List.range 9).map (fun k => pa (114688 + 32 * k) 5 (120 + 2 * k))

example (ioIn ioOut : ℕ) : ((progW16 cfgRungW16 ioIn ioOut).getD 2 SlotS.empty).tabs = tabs2W := by
  rfl

example (ioIn ioOut : ℕ) : ((progW16 cfgRungW16 ioIn ioOut).getD 2 SlotS.empty).hosted
    = [(0, Sym.dr 2 11), (1, Sym.dr 2 12)] := by
  rfl

example (ioIn ioOut : ℕ) : ((progW16 cfgRungW16 ioIn ioOut).getD 2 SlotS.empty).ir
    = tzcIr cstS ⟨0, 1, 2, 3, 4, 14, 15, none⟩ 1 ((List.range 6).map (fun i => Sym.dr 2 (5 + i)))
      [Sym.dr 2 11, Sym.dr 2 12] (fun j => Sym.pow Sym.zero j) [] := by
  rfl

example : (cstS.map (Sym.eval ⟨Fp2.zero, Fp2.zero, Fp2.zero, []⟩ 2 [])) = cstW := rfl
