import ZK60Formal.BlockHostFinal

open ZK60.Exec ZK60.Exec.Block ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build.Lay (LkW)

def lkS (l : LkW) : String :=
  s!"⟨{l.terms.map fun t => (t.1, aOff cfgRungW16 t.1, t.2)}, {l.cst}, {l.tag}⟩"

#eval [ZK60.Exec.Slot.W16R2.Dom.L, .D, .Q, .Kv, .S, .F].map fun d => ((lookupsN cfgRungW16 d).length, (lookupsN cfgRungW16 d).map lkS)
#eval hIdsN cfgRungW16
#eval (List.range 46).map fun hp => (hp, hOff cfgRungW16 hp, (hDoms cfgRungW16).getD hp .Tab)
#eval subW cfgRungW16
#eval (cfgRungW16.fams.flatMap fun f => List.range f.2)
#eval (List.range 17).map fun k => (58 + k, aOff cfgRungW16 (58 + k), logOf cfgRungW16 (58 + k))
#eval (idsW cfgRungW16.p).t0
#eval (List.range (nRange cfgRungW16)).filter fun j => !(ZK60.Exec.Slot.Build.Lay.fullW ((subW cfgRungW16).getD j 0) cfgRungW16.logCols)
#eval aDataRows cfgRungW16
#eval hDataRows cfgRungW16
#eval ZK60.Exec.Slot.W16R2.draws cfgRungW16.sh 19
#eval W16R2.rungDraws 19
#eval (logupSumW16 cfgRungW16).parts.length
#eval ((logupSumW16 cfgRungW16).parts.map fun p => (p.offset, p.logSize)).take 6
#eval ZK60.Exec.Slot.W16R2.relCount 15
