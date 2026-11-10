import ZK60Formal.BlockDefineW16Rung
import ZK60Formal.BlockAlgShapes
import ZK60Formal.BlockJoinDt

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

#eval slotS 4
#eval slotS 8
#eval (lookupsN cfgRungW16 .S).length
#eval ((lksS cfgRungW16 (fun q => 4 + (q - 39)) .S).map fun l => (symS l.konst, l.terms.map fun t => (symS t.1, t.2)))
#eval (idsW cfgRungW16.p).s0
#eval ZK60.Exec.Slot.W16R2.shRungW16.perRow
#eval ZK60.Exec.Slot.W16R2.shRungW16.lkv

def drs (s a n : ℕ) : List Sym := (List.range n).map fun i => Sym.dr s (a + i)

def aS (off log m : ℕ) : TabS := .priv ⟨.a, [(off, false)], log, DefW16.rhoC 0 log, m, 0⟩
def hS (re im m : ℕ) : TabS := .priv ⟨.h, [(re, false), (im, true)], 14, DefW16.rhoC 0 14, m, 0⟩

def tabs17 : List TabS :=
  [.eq (drs 17 0 14) 0, .eq (drs 4 0 9) 0, .eq (drs 8 0 14) 0, .pub 0,
   aS 737280 14 238, aS 753664 14 240, aS 770048 14 242, aS 786432 14 244, aS 802816 14 246,
   aS 819200 14 248, aS 835584 14 250, aS 851968 14 252, aS 868352 14 254, aS 884736 14 256,
   aS 65536 9 258, aS 81920 9 260,
   hS 655360 671744 142, hS 688128 704512 144, hS 720896 737280 146, hS 753664 770048 148,
   hS 786432 802816 150, hS 819200 835584 152]

def RSz : ZK60.Exec.Slot.Build.SzcR := ⟨0, 1, 2, 3, 4, 7, 8, 9, [10, 11], [12, 13], [5, 6], 14, 15, 16, 21, none, none⟩
def KSz : ZK60.Exec.Slot.Build.SzcK := ⟨127, 12, 18⟩

example (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 17 SlotS.empty
    = ⟨tabs17, ZK60.Exec.Slot.Build.szcIr cstS RSz KSz (lksS cfgRungW16 (fun q => 4 + (q - 39)) .S) (drs 17 14 10)
        [.dr 17 24, .dr 17 25] (.sub .alpha (.gtag 129)) (.neg .beta) (.dr 4 9) (fun j => Sym.pow Sym.zero j) [],
      [(4, .mul (.dr 17 24) (.base 32)), (8, .dr 17 25)], [.dr 17 24, .dr 17 25]⟩ := rfl

example (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 4 SlotS.empty
    = ⟨[.eq (drs 4 0 9) 0, .pub 0, aS 802816 14 142, aS 786432 14 144],
      ZK60.Exec.Slot.Build.rsIr cstS 0 1 2 3 none (.dr 4 9), [], []⟩ := rfl

open ZK60.Exec.Block.Join in
example {K : Type} [Field K] [Algebra ZK60.Circuit.GF K] (U : K) (ev : Sym → Fp2) (g : Fin 3 → Bool) (c : Fin 6 → Bool) :
    (fun a : Fin 15 => ptK U (xrK 9 (cpt (K := K) 9 2 (Fin.append g c)))
      (((drs 8 4 5).map CoordS.fixed ++ DefW16.rhoC 0 3 ++ (drs 8 3 1).map CoordS.fixed ++ DefW16.rhoC 3 9).map
        (CoordS.eval ev)) a)
    = Fin.append (fun i : Fin 5 => (ev (.dr 8 (4 + i))).toK U)
        (Fin.append (Fin.append (fun i : Fin 3 => (ZK60.Sound.bit (g i) : K)) (fun _ : Fin 1 => (ev (.dr 8 3)).toK U))
          (fun i : Fin 6 => (ZK60.Sound.bit (c i) : K))) := by
  funext a
  fin_cases a <;> rfl

open ZK60.Exec.Block.Join.W16 in
example (b : Fin 14 → Bool) :
    Fin.append (Fin.append (splitS b).1.1 (splitS b).1.2) (Fin.append (splitS b).2.1 (splitS b).2.2) = b := by
  funext i
  fin_cases i <;> rfl

example : (List.replicate 4 (0:ℤ) ++ [1, 2, 3, 4, 5] ++ [6]).getD 7 0 = 4 := by
  simp only [List.replicate_succ, List.replicate_zero, List.cons_append, List.nil_append, List.getD_cons_succ,
    List.getD_cons_zero]
