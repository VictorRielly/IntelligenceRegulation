import ZK60Formal.BlockJoinFinal
import ZK60Formal.BlockJoinBatch

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.DzcProbe

open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build (dzcIr mmIr DzcR DzcK)

def drS (s off n : ℕ) : List Sym := (List.range n).map fun i => Sym.dr s (off + i)

def hT (re im log m : ℕ) : TabS := .priv ⟨.h, [(re, false), (im, true)], log, DefW16.rhoC 0 log, m, 0⟩

def tabs14 : List TabS :=
  [.eq (drS 14 20 14) 0, .eq (drS 10 0 14) 0, .eq (drS 13 0 14) 0, .pub 0, .pub 1,
    paT 131072 14 168, paT 147456 14 170, paT 163840 14 172, paT 180224 14 174, paT 196608 14 176,
    paT 212992 14 178, paT 229376 14 180, paT 245760 14 182, paT 262144 14 184, paT 278528 14 186,
    paT 294912 14 188, paT 311296 14 190, paT 327680 14 192, paT 344064 14 194, paT 360448 14 196,
    paT 376832 14 198, paT 393216 14 200, paT 409600 14 202, paT 425984 14 204,
    paT 0 5 206, paT 32768 5 208,
    hT 32768 49152 14 110, hT 65536 81920 14 112, hT 98304 114688 14 114, hT 131072 147456 14 116,
    hT 163840 180224 14 118, hT 196608 212992 14 120, hT 229376 245760 14 122, hT 262144 278528 14 124,
    hT 294912 311296 14 126, hT 327680 344064 14 128, .pub 2]

def R14 : DzcR := ⟨0, 1, 2, 3, 4, 5, 6, 11, 14, 15, 20, 23, [7, 8], [9, 10], [16, 17], [18, 19], [12, 13], [21, 22],
  24, 25, 26, some 36⟩

def K14 : DzcK := ⟨8000, 8000, 4, 8, 21, 20⟩

def shD : ℕ → ℕ := fun q => 5 + (q - 8)

theorem slot14_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 14 SlotS.empty
    = ⟨tabs14, dzcIr DefW16.cstS R14 K14 (lksS cfgRungW16 shD .D) (drS 14 0 17) (drS 14 17 2)
        (fun j => Sym.pow (Sym.dr 14 19) j) (padGroup cfgRungW16 .D 36 shD),
      [(10, .dr 14 17), (13, .dr 14 18)], [.dr 14 17, .dr 14 18, .dr 14 19]⟩ := rfl

theorem slot10_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 10 SlotS.empty
    = ⟨[.priv ⟨.a, [(573440, false)], 15, (drS 10 0 5).map CoordS.fixed ++ DefW16.rhoC 0 10, 160, 0⟩, .pub 0],
        mmIr DefW16.cstS 0 1, [], []⟩ := rfl

theorem slot13_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 13 SlotS.empty
    = ⟨[.priv ⟨.a, [(1097728, false)], 15, (drS 13 0 5).map CoordS.fixed ++ DefW16.rhoC 0 10, 166, 0⟩, .pub 0],
        mmIr DefW16.cstS 0 1, [], []⟩ := rfl

theorem padGroup_dzc : padGroup cfgRungW16 .D 36 shD = [(36, List.range' 5 19)] := by decide

theorem lksD_len : (lksS cfgRungW16 shD .D).length = 19 := by decide

#eval (lksS cfgRungW16 shD .D).map fun l => l.terms.map Prod.snd

end ZK60.Exec.Block.Join.W16.DzcProbe
