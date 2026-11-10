import ZK60Formal.BlockDefineW16Rung
import ZK60Formal.BlockAlgShapes

open ZK60.Exec ZK60.Exec.Block ZK60.Exec.Block.DefW16

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

def slotS (k : ℕ) : String :=
  let s := (progW16 cfgRungW16 0 1).getD k SlotS.empty
  s!"slot {k}: {s.tabs.length} tabs\n" ++ String.intercalate "\n" ((s.tabs.zipIdx).map fun q => s!"  {q.2}: {tabS q.1}")
    ++ s!"\n  hosted {(s.hosted.map fun h => (h.1, symS h.2))}\n  nonzero {(s.nonzero.map symS)}"

#eval (idsW cfgRungW16.p).q0
#eval [(idsW cfgRungW16.p).k0, (idsW cfgRungW16.p).s0, (idsW cfgRungW16.p).f0, (idsW cfgRungW16.p).t0]
#eval (List.range 60).map fun q => (q, aOff cfgRungW16 q, logOf cfgRungW16 q)
#eval [aDataRows cfgRungW16, hDataRows cfgRungW16]
#eval (List.range 23).map fun k => (k, ZK60.Exec.Slot.W16R2.draws cfgRungW16.sh k)
#eval [ZK60.Exec.Slot.W16R2.Dom.T, .Ht, .L, .D, .Q, .Kv, .S, .F, .Tab].map fun d => (zeroPl cfgRungW16 d)
#eval W16R2.rungSlots
#eval slotS 0
#eval slotS 1
#eval slotS 2
#eval slotS 4
#eval slotS 5
#eval slotS 10
#eval slotS 14
#eval slotS 15
#eval slotS 16
#eval slotS 17
#eval slotS 18
