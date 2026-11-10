import ZK60Formal.BlockR13ProgOk

open ZK60.Exec ZK60.Exec.Block ZK60.Exec.Block.DefR13

def symS : Sym → String
  | .one => "1" | .negOne => "-1" | .zero => "0" | .base v => s!"b{v}" | .p16 k => s!"p16_{k}" | .p256 k => s!"p256_{k}"
  | .u64 n => s!"u{n}" | .alpha => "α" | .beta => "β" | .gtag t => s!"γ{t}" | .dr s i => s!"d{s}.{i}"
  | .add a b => s!"({symS a}+{symS b})" | .sub a b => s!"({symS a}-{symS b})" | .mul a b => s!"({symS a}*{symS b})"
  | .neg a => s!"-({symS a})" | .pow a j => s!"({symS a})^{j}"

def coordS : CoordS → String
  | .rho k => s!"r{k}" | .flip k => s!"f{k}" | .fixed v => s!"x[{symS v}]"

def cmS : Cm → String
  | .a => "A" | .h => "H" | .inp => "IN" | .out => "OUT"

def tabS : TabS → String
  | .eq pt st => s!"eq[{(pt.map symS)} @{st}]"
  | .pub i => s!"pub{i}"
  | .priv p => s!"priv[{cmS p.cm} {p.slices} log{p.log} {(p.coords.map coordS)} m{p.maskRow} e{p.extRound}]"

def slotStr (s : SlotS) : String :=
  s!"{s.tabs.length} tabs\n" ++ String.intercalate "\n" ((s.tabs.zipIdx).map fun q => s!"  {q.2}: {tabS q.1}")
    ++ s!"\n  hosted {(s.hosted.map fun h => (h.1, symS h.2))}\n  nonzero {(s.nonzero.map symS)}"

def shCfg (n : ℕ) : Option W16Cfg := (ZK60.RunShape.Shield.shieldExport[n]?).map cfgShieldR13

#eval slotStr (rawSlot cfgRungR13 19)
#eval (shCfg 0).map fun c => slotStr (rawSlot c 19)
#eval (shCfg 0).map fun c => [ZK60.Exec.Slot.W16R2.Dom.L, .D, .Q, .Kv, .S, .F, .Tab].map fun d => c.sh.logs d
#eval (shCfg 0).map fun c => ((ids c).t0, (ids c).mu8, (ids c).mexp, (ids c).mact, aOff c (ids c).t0, fh c 8, hOff c (fh c 8), logOf c (ids c).t0)
#eval ((ids cfgRungR13).t0, (ids cfgRungR13).mu8, aOff cfgRungR13 (ids cfgRungR13).t0, fh cfgRungR13 8, hOff cfgRungR13 (fh cfgRungR13 8))
#eval ZK60.Exec.Slot.R13.draws cfgRungR13.sh 19
#eval (shCfg 0).map fun c => ZK60.Exec.Slot.R13.draws c.sh 19
#eval (R13.rungDraws 19, R13.shieldDraws 19)
#eval (rawSlot cfgRungR13 19).ir.nodes.length
