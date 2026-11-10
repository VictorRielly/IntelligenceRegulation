import ZK60Formal.BlockR13ProgOk

open ZK60.Exec ZK60.Exec.Block ZK60.Exec.Block.DefR13

def shieldL0 : ZK60.RunShape.Shield.ShieldLayer := ZK60.RunShape.Shield.shieldExport.headD default

#eval [ZK60.Exec.Slot.W16R2.Dom.L, .D, .Q, .Kv, .S, .F, .Tab].map fun d => (cfgRungR13.sh.logs d)
#eval [ZK60.Exec.Slot.W16R2.Dom.L, .D, .Q, .Kv, .S, .F, .Tab].map fun d => ((cfgShieldR13 shieldL0).sh.logs d)
#eval ((ids cfgRungR13).mu8, (ids cfgRungR13).mexp, (ids cfgRungR13).mact, aOff cfgRungR13 (ids cfgRungR13).mu8,
  aOff cfgRungR13 (ids cfgRungR13).mexp, aOff cfgRungR13 (ids cfgRungR13).mact)
#eval (aOff (cfgShieldR13 shieldL0) (ids (cfgShieldR13 shieldL0)).mu8, logOf (cfgShieldR13 shieldL0) (ids (cfgShieldR13 shieldL0)).mu8)
#eval (DefR13.hOff cfgRungR13 (DefR13.fh cfgRungR13 8), DefR13.hOff (cfgShieldR13 shieldL0) (DefR13.fh (cfgShieldR13 shieldL0) 8))
#eval ZK60.RunShape.Shield.shieldExport.map fun L => (aOff (cfgShieldR13 L) (ids (cfgShieldR13 L)).mu8, DefR13.fh (cfgShieldR13 L) 8)
#eval (DefR13.fh cfgRungR13 8, DefR13.hIdsN cfgRungR13)
#eval (DefR13.fh (cfgShieldR13 shieldL0) 8, DefR13.hIdsN (cfgShieldR13 shieldL0))
#eval ((DefR13.zeroPl cfgRungR13 .Tab), DefW16.supp cfgRungR13 .Tab, (DefR13.zeroPl (cfgShieldR13 shieldL0) .Tab), DefW16.supp (cfgShieldR13 shieldL0) .Tab)
#eval ZK60.Exec.Slot.R13.draws cfgRungR13.sh 19
#eval ZK60.Exec.Slot.R13.draws (cfgShieldR13 shieldL0).sh 19
#eval ((progR13 cfgRungR13 0 1).getD 19 SlotS.empty).tabs.length
#eval ((progR13 cfgRungR13 0 1).getD 3 SlotS.empty).tabs.length
#eval (DefR13.lookupsN cfgRungR13 .L).length
#eval ZK60.RunShape.Shield.shieldExport.length
