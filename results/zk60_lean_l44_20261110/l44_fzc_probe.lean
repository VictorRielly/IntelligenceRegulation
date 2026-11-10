import ZK60Formal.BlockJoinTzc

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

#eval slotS 11
#eval slotS 12
#eval (lookupsN cfgRungW16 .F).length
#eval (lksS cfgRungW16 (fun q => 3 + (q - 49)) .F).map fun l => (symS l.konst, l.terms.map fun t => (symS t.1, t.2))
#eval (zeroPl cfgRungW16 .F)
#eval [nHelp cfgRungW16 .F, fh cfgRungW16 6, fh cfgRungW16 7]
#eval (idsW cfgRungW16.p).f0
