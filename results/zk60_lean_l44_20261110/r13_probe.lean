import ZK60Formal.BlockR13Prog
import ZK60Formal.RunShapeShield

open ZK60.Exec ZK60.Exec.Block ZK60.Exec.Block.DefR13

#eval (rawProg cfgRungR13).map (fun s => cmCountS .a s.tabs)
#eval (rawProg cfgRungR13).map (fun s => cmCountS .h s.tabs)
#eval ((rawProg cfgRungR13).map (fun s => cmCountS .a s.tabs) == Link.aCntR13Rung,
  (rawProg cfgRungR13).map (fun s => cmCountS .h s.tabs) == Link.hCntR13Rung)
#eval (rawProg cfgRungR13).map (fun s => s.tabs.length)
#eval [ZK60.Exec.Slot.W16R2.Dom.L, .D, .Q, .Kv, .S, .F].map (nHelp cfgRungR13)
#eval [aDataRows cfgRungR13, hDataRows cfgRungR13]
#eval (rawProg cfgRungR13).map (fun s => (s.ir.nodes.length, s.ir.terms.length))
#eval progOKb (fun _ => 1) (rawProg cfgRungR13) R13.rungSlots
#eval ZK60.RunShape.Shield.shieldExport.map fun L =>
  ((rawProg (cfgShieldR13 L)).map (fun s => cmCountS .a s.tabs) == Link.aCntR13Shield,
   (rawProg (cfgShieldR13 L)).map (fun s => cmCountS .h s.tabs) == Link.hCntR13Shield,
   progOKb (fun _ => 1) (rawProg (cfgShieldR13 L)) R13.shieldSlots)
#eval (rawProg (cfgShieldR13 ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩)).map (fun s => cmCountS .a s.tabs)
#eval (rawProg (cfgShieldR13 ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩)).map (fun s => cmCountS .h s.tabs)
