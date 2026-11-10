import ZK60Formal.BlockJoinTzc

open ZK60.Exec ZK60.Exec.Block ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build

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

#eval slotS 5
#eval slotS 6
#eval slotS 7
#eval slotS 9
#eval slotS 16
#eval (lookupsN cfgRungW16 .Q).length
#eval (lookupsN cfgRungW16 .Kv).length
#eval ((lksS cfgRungW16 (fun q => 5 + (q - 27)) .Q).map fun l => (symS l.konst, l.terms.map fun t => (symS t.1, t.2)))
#eval ((lksS cfgRungW16 (fun q => 5 + (q - 33)) .Kv).map fun l => (symS l.konst, l.terms.map fun t => (symS t.1, t.2)))
#eval supp cfgRungW16 .Q
#eval supp cfgRungW16 .Kv
#eval cfgRungW16.sh.lkv
#eval cfgRungW16.sh.ldh

namespace ZK60.Exec.Block.Join.W16.Qkv

def drs (s off n : ℕ) : List Sym := (List.range n).map fun i => Sym.dr s (off + i)

def hT (re im log m : ℕ) : TabS := .priv ⟨.h, [(re, false), (im, true)], log, DefW16.rhoC 0 log, m, 0⟩

def flT (off log k m : ℕ) : TabS :=
  .priv ⟨.a, [(off, false)], log, (List.range log).map fun j => if j = k then CoordS.flip j else CoordS.rho j, m, 0⟩

def tabs15 : List TabS :=
  [.eq (drs 15 6 15) 0, .eq (drs 5 0 15) 0, .eq (drs 9 4 5 ++ drs 9 0 4 ++ drs 9 9 6) 0, .pub 0, .pub 0,
    paT 442368 15 210, paT 475136 15 212, paT 507904 15 214, paT 540672 15 216, paT 573440 15 218,
    paT 606208 15 220, flT 442368 15 9 222, hT 360448 393216 15 130, hT 425984 458752 15 132,
    hT 491520 524288 15 134]

theorem slot15_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 15 SlotS.empty
    = ⟨tabs15, qzcIr DefW16.cstS ⟨0, 1, 2, 3, 4, 5, 7, 9, 11, [8], [6], [10], 12, none⟩ ⟨7, 15, 12⟩
        (lksS cfgRungW16 (fun q => 5 + (q - 27)) .Q) (drs 15 0 4) (drs 15 4 2) (fun j => Sym.pow Sym.zero j) [],
      [(5, .dr 15 4), (9, .dr 15 5)], [.dr 15 4, .dr 15 5]⟩ := rfl

end ZK60.Exec.Block.Join.W16.Qkv
