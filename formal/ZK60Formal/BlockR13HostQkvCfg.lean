/-
D63 lane L49 (2026-11-10), sub-agent `qkv`, part 6: **`QkvCfg` at the R13 rung and at every Shieldstral layer**, by
evaluation of the six raw slots (never the whole program, L47-6), one fact per declaration.

* **`qkvCfg_rung`**: `QkvCfg DefR13.cfgRungR13 2`;
* **`qkvCfg_shield`**: `QkvCfg (DefR13.cfgShieldR13 L) 1` for every layer `L` (the six slots read only the layer's
  shape and its fixed shifts, not its calibration); `qkvCfg_shieldExport`: at the 26 layers of the export.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostQkvBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Qkv

section Rung

theorem raw15_rung : DefR13.rawSlot DefR13.cfgRungR13 15 = rawQ DefR13.cfgRungR13 := rfl
theorem raw16_rung : DefR13.rawSlot DefR13.cfgRungR13 16 = rawKv DefR13.cfgRungR13 := rfl
theorem raw5_rung : DefR13.rawSlot DefR13.cfgRungR13 5 = rawMm DefR13.cfgRungR13 := rfl
theorem raw6_rung : DefR13.rawSlot DefR13.cfgRungR13 6 = rawMm DefR13.cfgRungR13 := rfl
theorem raw7_rung : DefR13.rawSlot DefR13.cfgRungR13 7 = rawMm DefR13.cfgRungR13 := rfl
theorem raw9_rung : DefR13.rawSlot DefR13.cfgRungR13 9 = rawPv DefR13.cfgRungR13 := rfl
theorem dQ_rung : ZK60.Exec.Slot.R13.draws DefR13.cfgRungR13.sh 15
    = [(.mu, 11), (.nu, 2), (.zeta, 0), (.tau, DefR13.cfgRungR13.sh.logs .Q)] := rfl
theorem dK_rung : ZK60.Exec.Slot.R13.draws DefR13.cfgRungR13.sh 16
    = [(.mu, 11), (.nu, 2), (.zeta, 0), (.tau, DefR13.cfgRungR13.sh.logs .Kv)] := rfl
theorem lkQ_rung : (DefR13.lookups DefR13.cfgRungR13 .Q).length = 14 := rfl
theorem lkK_rung : (DefR13.lookups DefR13.cfgRungR13 .Kv).length = 14 := rfl

/-- **The R13 rung meets `QkvCfg`.** -/
theorem qkvCfg_rung : QkvCfg DefR13.cfgRungR13 2 :=
  ⟨raw15_rung, raw16_rung, raw5_rung, raw6_rung, raw7_rung, raw9_rung, dQ_rung, dK_rung, lkQ_rung, lkK_rung,
    by decide, by decide, by decide, by decide, by decide⟩

end Rung

section Shield

variable (L : ZK60.RunShape.Shield.ShieldLayer)

theorem raw5_shield : DefR13.rawSlot (DefR13.cfgShieldR13 L) 5 = rawMm (DefR13.cfgShieldR13 L) := rfl
theorem raw6_shield : DefR13.rawSlot (DefR13.cfgShieldR13 L) 6 = rawMm (DefR13.cfgShieldR13 L) := rfl
theorem raw7_shield : DefR13.rawSlot (DefR13.cfgShieldR13 L) 7 = rawMm (DefR13.cfgShieldR13 L) := rfl
theorem dQ_shield : ZK60.Exec.Slot.R13.draws (DefR13.cfgShieldR13 L).sh 15
    = [(.mu, 11), (.nu, 2), (.zeta, 0), (.tau, (DefR13.cfgShieldR13 L).sh.logs .Q)] := rfl
theorem dK_shield : ZK60.Exec.Slot.R13.draws (DefR13.cfgShieldR13 L).sh 16
    = [(.mu, 11), (.nu, 2), (.zeta, 0), (.tau, (DefR13.cfgShieldR13 L).sh.logs .Kv)] := rfl
theorem lkQ_shield : (DefR13.lookups (DefR13.cfgShieldR13 L) .Q).length = 14 := rfl
theorem lkK_shield : (DefR13.lookups (DefR13.cfgShieldR13 L) .Kv).length = 14 := rfl

/-- **A Shieldstral layer meets `QkvCfg`** once its three larger raw slots (`15`, `16`, `9`) are the explicit ones
(each checked by evaluation at every layer of the export below, one declaration per slot and layer). -/
theorem qkvCfg_shield_of
    (h15 : DefR13.rawSlot (DefR13.cfgShieldR13 L) 15 = rawQ (DefR13.cfgShieldR13 L))
    (h16 : DefR13.rawSlot (DefR13.cfgShieldR13 L) 16 = rawKv (DefR13.cfgShieldR13 L))
    (h9 : DefR13.rawSlot (DefR13.cfgShieldR13 L) 9 = rawPv (DefR13.cfgShieldR13 L)) :
    QkvCfg (DefR13.cfgShieldR13 L) 1 :=
  ⟨h15, h16, raw5_shield L, raw6_shield L, raw7_shield L, h9, dQ_shield L, dK_shield L, lkQ_shield L, lkK_shield L,
    (by decide : 0 < ZK60.Exec.Slot.R13.shShieldR13.lkv), (by decide : 15 < 63), (by decide : 12 < 63),
    (by decide : 15 < 63), (by decide : 16 < 63)⟩

end Shield


/-! ## The three larger raw slots at each layer of the export (by evaluation, one declaration each) -/

section Layers
theorem raw15_sh0 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩) := rfl
theorem raw16_sh0 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩) := rfl
theorem raw9_sh0 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩) := rfl
theorem raw15_sh1 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 8, 14, 8, 19, 2600, 1471, 3⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨8, 8, 14, 8, 19, 2600, 1471, 3⟩) := rfl
theorem raw16_sh1 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 8, 14, 8, 19, 2600, 1471, 3⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨8, 8, 14, 8, 19, 2600, 1471, 3⟩) := rfl
theorem raw9_sh1 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 8, 14, 8, 19, 2600, 1471, 3⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨8, 8, 14, 8, 19, 2600, 1471, 3⟩) := rfl
theorem raw15_sh2 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 8, 16, 6, 18, 2727, 1196, 4⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨8, 8, 16, 6, 18, 2727, 1196, 4⟩) := rfl
theorem raw16_sh2 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 8, 16, 6, 18, 2727, 1196, 4⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨8, 8, 16, 6, 18, 2727, 1196, 4⟩) := rfl
theorem raw9_sh2 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 8, 16, 6, 18, 2727, 1196, 4⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨8, 8, 16, 6, 18, 2727, 1196, 4⟩) := rfl
theorem raw15_sh3 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 8, 15, 8, 20, 2899, 1448, 3⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨8, 8, 15, 8, 20, 2899, 1448, 3⟩) := rfl
theorem raw16_sh3 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 8, 15, 8, 20, 2899, 1448, 3⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨8, 8, 15, 8, 20, 2899, 1448, 3⟩) := rfl
theorem raw9_sh3 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 8, 15, 8, 20, 2899, 1448, 3⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨8, 8, 15, 8, 20, 2899, 1448, 3⟩) := rfl
theorem raw15_sh4 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 6, 15, 8, 20, 2304, 1289, 3⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨8, 6, 15, 8, 20, 2304, 1289, 3⟩) := rfl
theorem raw16_sh4 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 6, 15, 8, 20, 2304, 1289, 3⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨8, 6, 15, 8, 20, 2304, 1289, 3⟩) := rfl
theorem raw9_sh4 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 6, 15, 8, 20, 2304, 1289, 3⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨8, 6, 15, 8, 20, 2304, 1289, 3⟩) := rfl
theorem raw15_sh5 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 7, 15, 8, 20, 2277, 1539, 3⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨8, 7, 15, 8, 20, 2277, 1539, 3⟩) := rfl
theorem raw16_sh5 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 7, 15, 8, 20, 2277, 1539, 3⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨8, 7, 15, 8, 20, 2277, 1539, 3⟩) := rfl
theorem raw9_sh5 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 7, 15, 8, 20, 2277, 1539, 3⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨8, 7, 15, 8, 20, 2277, 1539, 3⟩) := rfl
theorem raw15_sh6 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 15, 8, 20, 2190, 1370, 3⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨7, 7, 15, 8, 20, 2190, 1370, 3⟩) := rfl
theorem raw16_sh6 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 15, 8, 20, 2190, 1370, 3⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨7, 7, 15, 8, 20, 2190, 1370, 3⟩) := rfl
theorem raw9_sh6 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 15, 8, 20, 2190, 1370, 3⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨7, 7, 15, 8, 20, 2190, 1370, 3⟩) := rfl
theorem raw15_sh7 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 6, 15, 8, 20, 2212, 1424, 3⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨8, 6, 15, 8, 20, 2212, 1424, 3⟩) := rfl
theorem raw16_sh7 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 6, 15, 8, 20, 2212, 1424, 3⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨8, 6, 15, 8, 20, 2212, 1424, 3⟩) := rfl
theorem raw9_sh7 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 6, 15, 8, 20, 2212, 1424, 3⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨8, 6, 15, 8, 20, 2212, 1424, 3⟩) := rfl
theorem raw15_sh8 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 6, 15, 8, 20, 2248, 1479, 3⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨8, 6, 15, 8, 20, 2248, 1479, 3⟩) := rfl
theorem raw16_sh8 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 6, 15, 8, 20, 2248, 1479, 3⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨8, 6, 15, 8, 20, 2248, 1479, 3⟩) := rfl
theorem raw9_sh8 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨8, 6, 15, 8, 20, 2248, 1479, 3⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨8, 6, 15, 8, 20, 2248, 1479, 3⟩) := rfl
theorem raw15_sh9 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 14, 8, 20, 2267, 1302, 4⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨7, 7, 14, 8, 20, 2267, 1302, 4⟩) := rfl
theorem raw16_sh9 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 14, 8, 20, 2267, 1302, 4⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨7, 7, 14, 8, 20, 2267, 1302, 4⟩) := rfl
theorem raw9_sh9 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 14, 8, 20, 2267, 1302, 4⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨7, 7, 14, 8, 20, 2267, 1302, 4⟩) := rfl
theorem raw15_sh10 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 6, 16, 8, 19, 2218, 1539, 3⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨7, 6, 16, 8, 19, 2218, 1539, 3⟩) := rfl
theorem raw16_sh10 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 6, 16, 8, 19, 2218, 1539, 3⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨7, 6, 16, 8, 19, 2218, 1539, 3⟩) := rfl
theorem raw9_sh10 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 6, 16, 8, 19, 2218, 1539, 3⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨7, 6, 16, 8, 19, 2218, 1539, 3⟩) := rfl
theorem raw15_sh11 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 15, 8, 20, 2233, 1533, 4⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨7, 7, 15, 8, 20, 2233, 1533, 4⟩) := rfl
theorem raw16_sh11 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 15, 8, 20, 2233, 1533, 4⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨7, 7, 15, 8, 20, 2233, 1533, 4⟩) := rfl
theorem raw9_sh11 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 15, 8, 20, 2233, 1533, 4⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨7, 7, 15, 8, 20, 2233, 1533, 4⟩) := rfl
theorem raw15_sh12 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 6, 14, 8, 20, 2208, 1246, 4⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨7, 6, 14, 8, 20, 2208, 1246, 4⟩) := rfl
theorem raw16_sh12 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 6, 14, 8, 20, 2208, 1246, 4⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨7, 6, 14, 8, 20, 2208, 1246, 4⟩) := rfl
theorem raw9_sh12 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 6, 14, 8, 20, 2208, 1246, 4⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨7, 6, 14, 8, 20, 2208, 1246, 4⟩) := rfl
theorem raw15_sh13 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 13, 8, 20, 2185, 999, 4⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨7, 7, 13, 8, 20, 2185, 999, 4⟩) := rfl
theorem raw16_sh13 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 13, 8, 20, 2185, 999, 4⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨7, 7, 13, 8, 20, 2185, 999, 4⟩) := rfl
theorem raw9_sh13 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 13, 8, 20, 2185, 999, 4⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨7, 7, 13, 8, 20, 2185, 999, 4⟩) := rfl
theorem raw15_sh14 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 13, 8, 19, 2118, 1052, 3⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨7, 7, 13, 8, 19, 2118, 1052, 3⟩) := rfl
theorem raw16_sh14 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 13, 8, 19, 2118, 1052, 3⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨7, 7, 13, 8, 19, 2118, 1052, 3⟩) := rfl
theorem raw9_sh14 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 13, 8, 19, 2118, 1052, 3⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨7, 7, 13, 8, 19, 2118, 1052, 3⟩) := rfl
theorem raw15_sh15 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 13, 8, 20, 2015, 1182, 4⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨7, 7, 13, 8, 20, 2015, 1182, 4⟩) := rfl
theorem raw16_sh15 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 13, 8, 20, 2015, 1182, 4⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨7, 7, 13, 8, 20, 2015, 1182, 4⟩) := rfl
theorem raw9_sh15 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 13, 8, 20, 2015, 1182, 4⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨7, 7, 13, 8, 20, 2015, 1182, 4⟩) := rfl
theorem raw15_sh16 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨6, 6, 14, 8, 20, 2174, 1481, 4⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨6, 6, 14, 8, 20, 2174, 1481, 4⟩) := rfl
theorem raw16_sh16 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨6, 6, 14, 8, 20, 2174, 1481, 4⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨6, 6, 14, 8, 20, 2174, 1481, 4⟩) := rfl
theorem raw9_sh16 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨6, 6, 14, 8, 20, 2174, 1481, 4⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨6, 6, 14, 8, 20, 2174, 1481, 4⟩) := rfl
theorem raw15_sh17 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 14, 8, 20, 2430, 1435, 4⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨7, 7, 14, 8, 20, 2430, 1435, 4⟩) := rfl
theorem raw16_sh17 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 14, 8, 20, 2430, 1435, 4⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨7, 7, 14, 8, 20, 2430, 1435, 4⟩) := rfl
theorem raw9_sh17 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 14, 8, 20, 2430, 1435, 4⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨7, 7, 14, 8, 20, 2430, 1435, 4⟩) := rfl
theorem raw15_sh18 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨6, 7, 15, 8, 20, 2448, 1607, 4⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨6, 7, 15, 8, 20, 2448, 1607, 4⟩) := rfl
theorem raw16_sh18 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨6, 7, 15, 8, 20, 2448, 1607, 4⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨6, 7, 15, 8, 20, 2448, 1607, 4⟩) := rfl
theorem raw9_sh18 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨6, 7, 15, 8, 20, 2448, 1607, 4⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨6, 7, 15, 8, 20, 2448, 1607, 4⟩) := rfl
theorem raw15_sh19 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 15, 8, 20, 2599, 1835, 4⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨7, 7, 15, 8, 20, 2599, 1835, 4⟩) := rfl
theorem raw16_sh19 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 15, 8, 20, 2599, 1835, 4⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨7, 7, 15, 8, 20, 2599, 1835, 4⟩) := rfl
theorem raw9_sh19 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 15, 8, 20, 2599, 1835, 4⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨7, 7, 15, 8, 20, 2599, 1835, 4⟩) := rfl
theorem raw15_sh20 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨6, 7, 16, 8, 20, 2273, 1926, 4⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨6, 7, 16, 8, 20, 2273, 1926, 4⟩) := rfl
theorem raw16_sh20 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨6, 7, 16, 8, 20, 2273, 1926, 4⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨6, 7, 16, 8, 20, 2273, 1926, 4⟩) := rfl
theorem raw9_sh20 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨6, 7, 16, 8, 20, 2273, 1926, 4⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨6, 7, 16, 8, 20, 2273, 1926, 4⟩) := rfl
theorem raw15_sh21 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 14, 8, 20, 2343, 2091, 3⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨7, 7, 14, 8, 20, 2343, 2091, 3⟩) := rfl
theorem raw16_sh21 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 14, 8, 20, 2343, 2091, 3⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨7, 7, 14, 8, 20, 2343, 2091, 3⟩) := rfl
theorem raw9_sh21 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 7, 14, 8, 20, 2343, 2091, 3⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨7, 7, 14, 8, 20, 2343, 2091, 3⟩) := rfl
theorem raw15_sh22 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨6, 7, 15, 8, 20, 2753, 2455, 3⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨6, 7, 15, 8, 20, 2753, 2455, 3⟩) := rfl
theorem raw16_sh22 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨6, 7, 15, 8, 20, 2753, 2455, 3⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨6, 7, 15, 8, 20, 2753, 2455, 3⟩) := rfl
theorem raw9_sh22 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨6, 7, 15, 8, 20, 2753, 2455, 3⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨6, 7, 15, 8, 20, 2753, 2455, 3⟩) := rfl
theorem raw15_sh23 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 8, 16, 8, 19, 3854, 2062, 4⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨7, 8, 16, 8, 19, 3854, 2062, 4⟩) := rfl
theorem raw16_sh23 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 8, 16, 8, 19, 3854, 2062, 4⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨7, 8, 16, 8, 19, 3854, 2062, 4⟩) := rfl
theorem raw9_sh23 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 8, 16, 8, 19, 3854, 2062, 4⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨7, 8, 16, 8, 19, 3854, 2062, 4⟩) := rfl
theorem raw15_sh24 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 8, 15, 8, 19, 4532, 2467, 4⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨7, 8, 15, 8, 19, 4532, 2467, 4⟩) := rfl
theorem raw16_sh24 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 8, 15, 8, 19, 4532, 2467, 4⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨7, 8, 15, 8, 19, 4532, 2467, 4⟩) := rfl
theorem raw9_sh24 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 8, 15, 8, 19, 4532, 2467, 4⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨7, 8, 15, 8, 19, 4532, 2467, 4⟩) := rfl
theorem raw15_sh25 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 8, 15, 5, 19, 3047, 3106, 4⟩) 15 = rawQ (DefR13.cfgShieldR13 ⟨7, 8, 15, 5, 19, 3047, 3106, 4⟩) := rfl
theorem raw16_sh25 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 8, 15, 5, 19, 3047, 3106, 4⟩) 16 = rawKv (DefR13.cfgShieldR13 ⟨7, 8, 15, 5, 19, 3047, 3106, 4⟩) := rfl
theorem raw9_sh25 : DefR13.rawSlot (DefR13.cfgShieldR13 ⟨7, 8, 15, 5, 19, 3047, 3106, 4⟩) 9 = rawPv (DefR13.cfgShieldR13 ⟨7, 8, 15, 5, 19, 3047, 3106, 4⟩) := rfl

end Layers

/-- **Every layer of the app's Shieldstral export meets `QkvCfg`** (the 26 layers of `shieldExport`). -/
theorem qkvCfg_shieldExport : ∀ L ∈ ZK60.RunShape.Shield.shieldExport, QkvCfg (DefR13.cfgShieldR13 L) 1 := by
  intro L hL
  simp only [ZK60.RunShape.Shield.shieldExport, List.mem_cons, List.not_mem_nil, or_false] at hL
  rcases hL with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  · exact qkvCfg_shield_of _ raw15_sh0 raw16_sh0 raw9_sh0
  · exact qkvCfg_shield_of _ raw15_sh1 raw16_sh1 raw9_sh1
  · exact qkvCfg_shield_of _ raw15_sh2 raw16_sh2 raw9_sh2
  · exact qkvCfg_shield_of _ raw15_sh3 raw16_sh3 raw9_sh3
  · exact qkvCfg_shield_of _ raw15_sh4 raw16_sh4 raw9_sh4
  · exact qkvCfg_shield_of _ raw15_sh5 raw16_sh5 raw9_sh5
  · exact qkvCfg_shield_of _ raw15_sh6 raw16_sh6 raw9_sh6
  · exact qkvCfg_shield_of _ raw15_sh7 raw16_sh7 raw9_sh7
  · exact qkvCfg_shield_of _ raw15_sh8 raw16_sh8 raw9_sh8
  · exact qkvCfg_shield_of _ raw15_sh9 raw16_sh9 raw9_sh9
  · exact qkvCfg_shield_of _ raw15_sh10 raw16_sh10 raw9_sh10
  · exact qkvCfg_shield_of _ raw15_sh11 raw16_sh11 raw9_sh11
  · exact qkvCfg_shield_of _ raw15_sh12 raw16_sh12 raw9_sh12
  · exact qkvCfg_shield_of _ raw15_sh13 raw16_sh13 raw9_sh13
  · exact qkvCfg_shield_of _ raw15_sh14 raw16_sh14 raw9_sh14
  · exact qkvCfg_shield_of _ raw15_sh15 raw16_sh15 raw9_sh15
  · exact qkvCfg_shield_of _ raw15_sh16 raw16_sh16 raw9_sh16
  · exact qkvCfg_shield_of _ raw15_sh17 raw16_sh17 raw9_sh17
  · exact qkvCfg_shield_of _ raw15_sh18 raw16_sh18 raw9_sh18
  · exact qkvCfg_shield_of _ raw15_sh19 raw16_sh19 raw9_sh19
  · exact qkvCfg_shield_of _ raw15_sh20 raw16_sh20 raw9_sh20
  · exact qkvCfg_shield_of _ raw15_sh21 raw16_sh21 raw9_sh21
  · exact qkvCfg_shield_of _ raw15_sh22 raw16_sh22 raw9_sh22
  · exact qkvCfg_shield_of _ raw15_sh23 raw16_sh23 raw9_sh23
  · exact qkvCfg_shield_of _ raw15_sh24 raw16_sh24 raw9_sh24
  · exact qkvCfg_shield_of _ raw15_sh25 raw16_sh25 raw9_sh25

end ZK60.Exec.Block.Join.R13H.Qkv
