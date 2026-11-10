import ZK60Formal.BlockHostBase
import ZK60Formal.BlockAlgR13
import ZK60Formal.BlockR13JoinForm
import ZK60Formal.BlockR13ProgOk
import ZK60Formal.BlockR13JoinTab
/- D63 lane L49, sub-agent pub: probe = the foundation (shS spelled out) + BlockR13HostPub + the checker. -/
/-
D63 lane L49 (2026-11-10), part 1: **the R13 block's extracted planes, layout facts, encodings, algebra data and
`R13Spec`, generic in the configuration** (the R13 counterpart of lane L41's `BlockJoinW16` / `BlockJoinDt` and lane
L44's `BlockHostBase`), for the R13 rung (`cfgRungR13`) and every layer of the Shieldstral T128 R13 block
(`cfgShieldR13 L`).

The two R13 configurations differ in their axis widths (rung: tokens `5`, width `9`, groups `3`, in-group `1`, head
dimension `6`, hidden `10`; Shieldstral: `7`, `12`, `3`, `2`, `7`, `14`), in the softmax remainders' byte limbs
(`limbs_sigma_s`: rung `3`, Shieldstral `2`) and in the precision; every statement here is generic in the
configuration `c`, with the facts it reads off `c` collected as `GeoR c ls` (decided at each configuration).

* `CtR c` … `CfR c`: the axes as bit vectors; `nD c` … `nF c`: the domains' widths;
* **`GeoR c ls`**, `geoRung`, `geoShield`: the configuration's geometry (every domain is a product of axes, most
  significant first; `h24`; `lsOf = ls + 1`);
* `plT` … `plF`, `plL`: a plane of each domain at an offset, the base projection of the committed `A` plane;
* **`xtR`**: the R13 block's `R13Data`, each field the base projection of its plane at `DefR13.aOff c q`, the plane
  ids `q` those of `AccuracyIds::new` at LowH24 (`idsR13 true (ls + 1)`, `ids_eq_rung`, `ids_eq_shield`);
* `LayR`, `gQ_oneR` …: the layout facts the hosts read, and the gates of the domains that do not pad;
* `splitD` … `splitF`, `splitHQ`, `splitGD` and their inverses; `tauLen`, **`encR`**, **`encHtR`**: the hosts'
  cube encodings;
* `mpadR` (`SC_DZC` 39 and `SC_FZC` 16 zero-rule planes, `mpadR_zeroPl_*`), `ShOkR c P`, **`algShapeR`**,
  `shOk_rung`, `shOk_shield`: the draw schedule's shape facts at R13;
* **`dtR`**, **`hspecR`**: the algebra data whose relation entries ARE `R13Rels`' relation tables of the extracted
  planes, and lane L36's `R13Spec` for it;
* **`PubR`**: the verifier's public tables, as the block's public data (one field per table the hosts read);
* **`PrecR c S`**, `precR_rung`, `precR_shield`: the integer model's shape constants are the configuration's
  precision (at the rung from `RungS`, at every Shieldstral layer by definition);
* `dXof_base_r13`: the R13 committed `A` matrix is base-valued (L41-1 at R13's geometry);
* `progR13_slot`: the numbered program's slot `k` is the raw slot `k` numbered from some claim sites.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl piB piB_alg alg_piB aPl_base aPl_alg RungS)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.W16R2 (segLn segOff segSum Dom)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open ZK60.Layout.R13 (R13Data)

/-! ## The geometry -/

section Geo

variable (c : W16Cfg)

/-- The token axis. -/
abbrev CtR : Type := Fin c.sh.lt → Bool
/-- The width axis. -/
abbrev CwR : Type := Fin c.sh.ld → Bool
/-- The key-value group axis. -/
abbrev CgR : Type := Fin c.sh.lkv → Bool
/-- A query head's index in its group. -/
abbrev CjR : Type := Fin (c.sh.lh - c.sh.lkv) → Bool
/-- The head dimension. -/
abbrev CdR : Type := Fin c.sh.ldh → Bool
/-- The hidden axis. -/
abbrev CfR : Type := Fin c.sh.lf → Bool

/-- `Dom::D`'s width `t ++ i`. -/
abbrev nD : ℕ := c.sh.lt + c.sh.ld
/-- A head slot's width `g ++ j`. -/
abbrev nH : ℕ := c.sh.lkv + (c.sh.lh - c.sh.lkv)
/-- `Dom::Q`'s width `t ++ (g ++ j) ++ c`. -/
abbrev nQ : ℕ := c.sh.lt + (nH c + c.sh.ldh)
/-- `Dom::Kv`'s width `t ++ g ++ c`. -/
abbrev nK : ℕ := c.sh.lt + (c.sh.lkv + c.sh.ldh)
/-- `Dom::S`'s width `(g ++ j) ++ t ++ t'`. -/
abbrev nS : ℕ := nH c + (c.sh.lt + c.sh.lt)
/-- `Dom::Ht`'s width `(g ++ j) ++ t`. -/
abbrev nHt : ℕ := nH c + c.sh.lt
/-- `Dom::F`'s width `t ++ f`. -/
abbrev nF : ℕ := c.sh.lt + c.sh.lf

/-- **The configuration's geometry**: every domain is the product of its axes (`shape.rs::natural_log`, most
significant first), the matmuls' inner widths are the axes', the stack is LowH24, and the softmax remainders have
`ls + 1` byte limbs (`limbs_sigma_s`). Decided at each configuration (`geoRung`, `geoShield`). -/
structure GeoR (ls : ℕ) : Prop where
  logT : c.sh.logs .T = c.sh.lt
  logD : c.sh.logs .D = nD c
  logQ : c.sh.logs .Q = nQ c
  logK : c.sh.logs .Kv = nK c
  logS : c.sh.logs .S = nS c
  logHt : c.sh.logs .Ht = nHt c
  logF : c.sh.logs .F = nF c
  lq : c.sh.lq = nH c + c.sh.ldh
  lkvw : c.sh.lkvw = c.sh.lkv + c.sh.ldh
  lkv_le : c.sh.lkv ≤ c.sh.lh
  lt_pos : 0 < c.sh.lt
  ldh_pos : 0 < c.sh.ldh
  h24 : c.p.h24 = true
  ls : DefR13.lsOf c.p = ls + 1
  lc : c.logCols = 14

/-- **The R13 rung's geometry** (`5, 9, 3, 1, 6, 10`; three softmax limbs). -/
theorem geoRung : GeoR DefR13.cfgRungR13 2 := by
  constructor <;> decide

/-- The Shieldstral configuration's shape is `shShieldR13` at every layer. -/
theorem cfgShield_sh (L : ZK60.RunShape.Shield.ShieldLayer) :
    (DefR13.cfgShieldR13 L).sh = ZK60.Exec.Slot.R13.shShieldR13 := rfl

theorem cfgShield_h24 (L : ZK60.RunShape.Shield.ShieldLayer) : (DefR13.cfgShieldR13 L).p.h24 = true := rfl

theorem cfgShield_ls (L : ZK60.RunShape.Shield.ShieldLayer) : DefR13.lsOf (DefR13.cfgShieldR13 L).p = 2 := by
  show ((DefR13.cfgShieldR13 L).p.wrho + 7) / 8 = 2
  rw [show (DefR13.cfgShieldR13 L).p.wrho = 16 from rfl]


/-- **Every Shieldstral layer's geometry** (`7, 12, 3, 2, 7, 14`; two softmax limbs): the shape is the layer's own
and does not depend on its calibration. -/
theorem geoShield (L : ZK60.RunShape.Shield.ShieldLayer) : GeoR (DefR13.cfgShieldR13 L) 1 where
  logT := (by decide : ZK60.Exec.Slot.R13.shShieldR13.logs .T = ZK60.Exec.Slot.R13.shShieldR13.lt)
  logD := (by decide : ZK60.Exec.Slot.R13.shShieldR13.logs .D = ZK60.Exec.Slot.R13.shShieldR13.lt + ZK60.Exec.Slot.R13.shShieldR13.ld)
  logQ := (by decide : ZK60.Exec.Slot.R13.shShieldR13.logs .Q = ZK60.Exec.Slot.R13.shShieldR13.lt + ((ZK60.Exec.Slot.R13.shShieldR13.lkv + (ZK60.Exec.Slot.R13.shShieldR13.lh - ZK60.Exec.Slot.R13.shShieldR13.lkv)) + ZK60.Exec.Slot.R13.shShieldR13.ldh))
  logK := (by decide : ZK60.Exec.Slot.R13.shShieldR13.logs .Kv = ZK60.Exec.Slot.R13.shShieldR13.lt + (ZK60.Exec.Slot.R13.shShieldR13.lkv + ZK60.Exec.Slot.R13.shShieldR13.ldh))
  logS := (by decide : ZK60.Exec.Slot.R13.shShieldR13.logs .S = (ZK60.Exec.Slot.R13.shShieldR13.lkv + (ZK60.Exec.Slot.R13.shShieldR13.lh - ZK60.Exec.Slot.R13.shShieldR13.lkv)) + (ZK60.Exec.Slot.R13.shShieldR13.lt + ZK60.Exec.Slot.R13.shShieldR13.lt))
  logHt := (by decide : ZK60.Exec.Slot.R13.shShieldR13.logs .Ht = (ZK60.Exec.Slot.R13.shShieldR13.lkv + (ZK60.Exec.Slot.R13.shShieldR13.lh - ZK60.Exec.Slot.R13.shShieldR13.lkv)) + ZK60.Exec.Slot.R13.shShieldR13.lt)
  logF := (by decide : ZK60.Exec.Slot.R13.shShieldR13.logs .F = ZK60.Exec.Slot.R13.shShieldR13.lt + ZK60.Exec.Slot.R13.shShieldR13.lf)
  lq := (by decide : ZK60.Exec.Slot.R13.shShieldR13.lq = (ZK60.Exec.Slot.R13.shShieldR13.lkv + (ZK60.Exec.Slot.R13.shShieldR13.lh - ZK60.Exec.Slot.R13.shShieldR13.lkv)) + ZK60.Exec.Slot.R13.shShieldR13.ldh)
  lkvw := (by decide : ZK60.Exec.Slot.R13.shShieldR13.lkvw = ZK60.Exec.Slot.R13.shShieldR13.lkv + ZK60.Exec.Slot.R13.shShieldR13.ldh)
  lkv_le := (by decide : ZK60.Exec.Slot.R13.shShieldR13.lkv ≤ ZK60.Exec.Slot.R13.shShieldR13.lh)
  lt_pos := (by decide : 0 < ZK60.Exec.Slot.R13.shShieldR13.lt)
  ldh_pos := (by decide : 0 < ZK60.Exec.Slot.R13.shShieldR13.ldh)
  h24 := cfgShield_h24 L
  ls := cfgShield_ls L
  lc := rfl

/-- **The R13 rung's plane ids** are `AccuracyIds::new` at LowH24 with three softmax limbs. -/
theorem ids_eq_rung : DefR13.ids DefR13.cfgRungR13 = DefR13.idsR13 true 3 := rfl

/-- **Every Shieldstral layer's plane ids** are `AccuracyIds::new` at LowH24 with two softmax limbs. -/
theorem ids_eq_shield (L : ZK60.RunShape.Shield.ShieldLayer) :
    DefR13.ids (DefR13.cfgShieldR13 L) = DefR13.idsR13 true 2 := by
  show DefR13.idsR13 (DefR13.cfgShieldR13 L).p.h24 (DefR13.lsOf (DefR13.cfgShieldR13 L).p) = _
  rw [cfgShield_h24, cfgShield_ls]

end Geo

/-! ## The extracted planes -/

section Planes

variable {K : Type} [Field K] [Algebra GF K] (U : K) (c : W16Cfg) (P : BlockParams) (D : CmData K P)

/-- A plane of `Dom::T` at offset `off`. -/
noncomputable def plT (off : ℕ) (t : CtR c) : GF := piB K (aPl U P D off c.sh.lt t)

/-- A plane of `Dom::D` (`t ++ i`). -/
noncomputable def plD (off : ℕ) (x : CtR c × CwR c) : GF := piB K (aPl U P D off (nD c) (Fin.append x.1 x.2))

/-- A plane of `Dom::Q` (`t ++ (g ++ j) ++ c`). -/
noncomputable def plQ (off : ℕ) (x : CtR c × ((CgR c × CjR c) × CdR c)) : GF :=
  piB K (aPl U P D off (nQ c) (Fin.append x.1 (Fin.append (Fin.append x.2.1.1 x.2.1.2) x.2.2)))

/-- A plane of `Dom::Kv` (`t ++ g ++ c`). -/
noncomputable def plK (off : ℕ) (x : CtR c × (CgR c × CdR c)) : GF :=
  piB K (aPl U P D off (nK c) (Fin.append x.1 (Fin.append x.2.1 x.2.2)))

/-- A plane of `Dom::S` (`(g ++ j) ++ t ++ t'`). -/
noncomputable def plS (off : ℕ) (x : (CgR c × CjR c) × CtR c × CtR c) : GF :=
  piB K (aPl U P D off (nS c) (Fin.append (Fin.append x.1.1 x.1.2) (Fin.append x.2.1 x.2.2)))

/-- A plane of `Dom::Ht` (`(g ++ j) ++ t`). -/
noncomputable def plH (off : ℕ) (x : (CgR c × CjR c) × CtR c) : GF :=
  piB K (aPl U P D off (nHt c) (Fin.append (Fin.append x.1.1 x.1.2) x.2))

/-- A plane of `Dom::F` (`t ++ f`). -/
noncomputable def plF (off : ℕ) (x : CtR c × CfR c) : GF := piB K (aPl U P D off (nF c) (Fin.append x.1 x.2))

/-- An isqrt byte limb: sub-slice `3i + k` (`2^lt` entries) of the limb plane at `off` on `Dom::L` (`SC_TZC`'s tables,
`aOff c limb + k·2^lt`). -/
noncomputable def plL (off : ℕ) (i k : Fin 3) (t : CtR c) : GF :=
  piB K (aPl U P D (off + (3 * (i : ℕ) + k) * 2 ^ c.sh.lt) c.sh.lt t)

/-- A plane's offset. -/
abbrev offR (q : ℕ) : ℕ := DefR13.aOff c q

/-- **The R13 block's extracted planes**, each field the base projection of its committed plane at the plane's offset
`DefR13.aOff c q`; the plane ids are `AccuracyIds::new`'s at LowH24 with `ls + 1` softmax limbs (`idsR13 true
(ls + 1)`: the words and their limbs on `Dom::D` `8 … 46`, `Dom::Q` `47 … 60`, `Dom::Kv` `61 … 74`, `Dom::S` from
`75`, `Dom::F` from `86 + 2·ls`). -/
noncomputable def xtR (ls : ℕ) : R13Data (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c) ls where
  dA := plT U c P D (offR c 0)
  dsqA := plT U c P D (offR c 1)
  dM := plT U c P D (offR c 2)
  dsqM := plT U c P D (offR c 3)
  la := plL U c P D (offR c 6)
  lm := plL U c P D (offR c 7)
  X := plD U c P D (offR c 8)
  Y := plD U c P D (offR c 11)
  AO := plD U c P D (offR c 20)
  X1 := plD U c P D (offR c 26)
  YM := plD U c P D (offR c 29)
  Z := plD U c P D (offR c 38)
  X2 := plD U c P D (offR c 44)
  xl k := plD U c P D (offR c (9 + k))
  yl k := plD U c P D (offR c (12 + k))
  aol k := plD U c P D (offR c (21 + k))
  x1l k := plD U c P D (offR c (27 + k))
  yml k := plD U c P D (offR c (30 + k))
  zl k := plD U c P D (offR c (39 + k))
  x2l k := plD U c P D (offR c (45 + k))
  nr k := plD U c P D (offR c (14 + k))
  ns k := plD U c P D (offR c (17 + k))
  mr k := plD U c P D (offR c (32 + k))
  ms k := plD U c P D (offR c (35 + k))
  ral k := plD U c P D (offR c (23 + k))
  rdl k := plD U c P D (offR c (41 + k))
  Q := plQ U c P D (offR c 47)
  QR := plQ U c P D (offR c 52)
  O := plQ U c P D (offR c 56)
  ql k := plQ U c P D (offR c (48 + k))
  qrl k := plQ U c P D (offR c (53 + k))
  ol k := plQ U c P D (offR c (57 + k))
  rql k := plQ U c P D (offR c (50 + k))
  rqrl k := plQ U c P D (offR c (55 + k))
  ro k := plQ U c P D (offR c (59 + k))
  K := plK U c P D (offR c 61)
  KR := plK U c P D (offR c 71)
  V := plK U c P D (offR c 66)
  kl k := plK U c P D (offR c (62 + k))
  krl k := plK U c P D (offR c (72 + k))
  vl k := plK U c P D (offR c (67 + k))
  rkl k := plK U c P D (offR c (64 + k))
  rkrl k := plK U c P D (offR c (74 + k))
  rvl k := plK U c P D (offR c (69 + k))
  S8 := plS U c P D (offR c 75)
  ZSEL := plS U c P D (offR c 79)
  E := plS U c P D (offR c 80)
  PP := plS U c P D (offR c 81)
  rsl k := plS U c P D (offR c (76 + k))
  pl k := plS U c P D (offR c (82 + k))
  sr k := plS U c P D (offR c (84 + k))
  sg k := plS U c P D (offR c (84 + (ls + 1) + k))
  MX := plH U c P D (offR c 4)
  SUM := plH U c P D (offR c 5)
  G := plF U c P D (offR c (86 + 2 * ls))
  A := plF U c P D (offR c (86 + 2 * ls + 4))
  U := plF U c P D (offR c (86 + 2 * ls + 5))
  H := plF U c P D (offR c (86 + 2 * ls + 10))
  rgl k := plF U c P D (offR c (86 + 2 * ls + 1 + k))
  ul k := plF U c P D (offR c (86 + 2 * ls + 6 + k))
  ru k := plF U c P D (offR c (86 + 2 * ls + 8 + k))
  hl k := plF U c P D (offR c (86 + 2 * ls + 11 + k))
  rh k := plF U c P D (offR c (86 + 2 * ls + 14 + k))

end Planes

/-- **`xtR`'s plane ids are the code's** (`AccuracyIds::new` at LowH24, `idsR13 true (ls + 1)`), role by role: the words,
the limb groups' first ids, the domains' first planes. -/
theorem xtR_ids (ls : ℕ) (hls : ls = 2 ∨ ls = 1) :
    let I := DefR13.idsR13 true (ls + 1)
    [I.d, I.dsq, I.dm, I.dsqm, I.mx, I.sum, I.limb, I.limbm, I.x, I.y, I.ao, I.x1, I.ym, I.z, I.x2, I.q, I.qr, I.o, I.k,
        I.v, I.kr, I.s, I.zsel, I.e, I.p, I.g, I.a, I.u, I.h]
      = [0, 1, 2, 3, 4, 5, 6, 7, 8, 11, 20, 26, 29, 38, 44, 47, 52, 56, 61, 66, 71, 75, 79, 80, 81, 86 + 2 * ls,
          86 + 2 * ls + 4, 86 + 2 * ls + 5, 86 + 2 * ls + 10]
    ∧ [I.xl, I.yl, I.nr, I.ns, I.al, I.ral, I.x1l, I.yml, I.mr, I.ms, I.zl, I.rdl, I.x2l, I.ql, I.rql, I.qrl, I.rqrl,
        I.ol, I.ro, I.kl, I.rkl, I.vl, I.rvl, I.krl, I.rkrl, I.rsl, I.pl]
      = [[9, 10], [12, 13], [14, 15, 16], [17, 18, 19], [21, 22], [23, 24, 25], [27, 28], [30, 31], [32, 33, 34],
          [35, 36, 37], [39, 40], [41, 42, 43], [45, 46], [48, 49], [50, 51], [53, 54], [55], [57, 58], [59, 60],
          [62, 63], [64, 65], [67, 68], [69, 70], [72, 73], [74], [76, 77, 78], [82, 83]]
    ∧ I.sr = List.range' 84 (ls + 1) ∧ I.sg = List.range' (84 + (ls + 1)) (ls + 1)
    ∧ I.rgl = [86 + 2 * ls + 1, 86 + 2 * ls + 2, 86 + 2 * ls + 3] ∧ I.ul = [86 + 2 * ls + 6, 86 + 2 * ls + 7]
    ∧ I.ru = [86 + 2 * ls + 8, 86 + 2 * ls + 9] ∧ I.hl = [86 + 2 * ls + 11, 86 + 2 * ls + 12, 86 + 2 * ls + 13]
    ∧ I.rh = [86 + 2 * ls + 14, 86 + 2 * ls + 15] ∧ I.t0 = 86 + 2 * ls + 16 := by
  rcases hls with rfl | rfl <;> decide

/-! ## The splits of a domain's bit vector -/

section Splits

variable (c : W16Cfg)

/-- `Dom::D`'s point `t ++ i`. -/
def splitD (b : Fin (nD c) → Bool) : CtR c × CwR c :=
  (fun i => b (Fin.castAdd c.sh.ld i), fun i => b (Fin.natAdd c.sh.lt i))

/-- A head slot and head dimension `(g ++ j) ++ c`. -/
def splitHQ (y : Fin (nH c + c.sh.ldh) → Bool) : (CgR c × CjR c) × CdR c :=
  ((fun i => y (Fin.castAdd c.sh.ldh (Fin.castAdd (c.sh.lh - c.sh.lkv) i)),
      fun i => y (Fin.castAdd c.sh.ldh (Fin.natAdd c.sh.lkv i))),
    fun i => y (Fin.natAdd (nH c) i))

/-- A group and head dimension `g ++ c`. -/
def splitGD (y : Fin (c.sh.lkv + c.sh.ldh) → Bool) : CgR c × CdR c :=
  (fun i => y (Fin.castAdd c.sh.ldh i), fun i => y (Fin.natAdd c.sh.lkv i))

/-- `Dom::Q`'s point `t ++ (g ++ j) ++ c`. -/
def splitQ (b : Fin (nQ c) → Bool) : CtR c × ((CgR c × CjR c) × CdR c) :=
  (fun i => b (Fin.castAdd (nH c + c.sh.ldh) i), splitHQ c (fun i => b (Fin.natAdd c.sh.lt i)))

/-- `Dom::Kv`'s point `t ++ g ++ c`. -/
def splitK (b : Fin (nK c) → Bool) : CtR c × (CgR c × CdR c) :=
  (fun i => b (Fin.castAdd (c.sh.lkv + c.sh.ldh) i), splitGD c (fun i => b (Fin.natAdd c.sh.lt i)))

/-- `Dom::Ht`'s point `(g ++ j) ++ t`. -/
def splitHt (b : Fin (nHt c) → Bool) : (CgR c × CjR c) × CtR c :=
  ((fun i => b (Fin.castAdd c.sh.lt (Fin.castAdd (c.sh.lh - c.sh.lkv) i)),
      fun i => b (Fin.castAdd c.sh.lt (Fin.natAdd c.sh.lkv i))),
    fun i => b (Fin.natAdd (nH c) i))

/-- `Dom::S`'s point `(g ++ j) ++ t ++ t'`. -/
def splitS (b : Fin (nS c) → Bool) : (CgR c × CjR c) × CtR c × CtR c :=
  ((fun i => b (Fin.castAdd (c.sh.lt + c.sh.lt) (Fin.castAdd (c.sh.lh - c.sh.lkv) i)),
      fun i => b (Fin.castAdd (c.sh.lt + c.sh.lt) (Fin.natAdd c.sh.lkv i))),
    fun i => b (Fin.natAdd (nH c) (Fin.castAdd c.sh.lt i)), fun i => b (Fin.natAdd (nH c) (Fin.natAdd c.sh.lt i)))

/-- `Dom::F`'s point `t ++ f`. -/
def splitF (b : Fin (nF c) → Bool) : CtR c × CfR c :=
  (fun i => b (Fin.castAdd c.sh.lf i), fun i => b (Fin.natAdd c.sh.lt i))

theorem splitD_append (x : CtR c × CwR c) : splitD c (Fin.append x.1 x.2) = x := by
  obtain ⟨t, w⟩ := x
  simp only [splitD, Fin.append_left, Fin.append_right]

theorem splitHQ_append (x : (CgR c × CjR c) × CdR c) :
    splitHQ c (Fin.append (Fin.append x.1.1 x.1.2) x.2) = x := by
  obtain ⟨⟨g, j⟩, d⟩ := x
  simp only [splitHQ, Fin.append_left, Fin.append_right]

theorem splitGD_append (x : CgR c × CdR c) : splitGD c (Fin.append x.1 x.2) = x := by
  obtain ⟨g, d⟩ := x
  simp only [splitGD, Fin.append_left, Fin.append_right]

theorem splitQ_append (x : CtR c × ((CgR c × CjR c) × CdR c)) :
    splitQ c (Fin.append x.1 (Fin.append (Fin.append x.2.1.1 x.2.1.2) x.2.2)) = x := by
  obtain ⟨t, ⟨g, j⟩, d⟩ := x
  simp only [splitQ, splitHQ, Fin.append_left, Fin.append_right]

theorem splitK_append (x : CtR c × (CgR c × CdR c)) : splitK c (Fin.append x.1 (Fin.append x.2.1 x.2.2)) = x := by
  obtain ⟨t, g, d⟩ := x
  simp only [splitK, splitGD, Fin.append_left, Fin.append_right]

theorem splitHt_append (x : (CgR c × CjR c) × CtR c) : splitHt c (Fin.append (Fin.append x.1.1 x.1.2) x.2) = x := by
  obtain ⟨⟨g, j⟩, t⟩ := x
  simp only [splitHt, Fin.append_left, Fin.append_right]

theorem splitS_append (x : (CgR c × CjR c) × CtR c × CtR c) :
    splitS c (Fin.append (Fin.append x.1.1 x.1.2) (Fin.append x.2.1 x.2.2)) = x := by
  obtain ⟨⟨g, j⟩, t, t'⟩ := x
  simp only [splitS, Fin.append_left, Fin.append_right]

theorem splitF_append (x : CtR c × CfR c) : splitF c (Fin.append x.1 x.2) = x := by
  obtain ⟨t, f⟩ := x
  simp only [splitF, Fin.append_left, Fin.append_right]

/-- A cast of a bit vector, undone. -/
theorem castB_castB {m n : ℕ} (h : m = n) (x : Fin n → Bool) : castB h (castB h.symm x) = x := by
  funext i
  simp [castB]

end Splits

/-! ## The layout facts and the gates -/

/-- **The layout facts the hosts read** (public data of the configuration's layout): the token, head-dimension,
head-slot and group axes do not pad, and the RoPE flip is the head dimension's top bit (`Coord::Flip` at the head
dimension's first variable). -/
structure LayR {S : ZK60.Block.BlockShape} {c : W16Cfg}
    (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) : Prop where
  tok : Function.Surjective Lay.tok.emb
  hd : Function.Surjective Lay.hd.emb
  slot : Function.Surjective Lay.slot
  grp : Function.Surjective Lay.grp.emb
  flip : ∀ (h0 : 0 < c.sh.ldh) (d : CdR c), Lay.flip d = Function.update d ⟨0, h0⟩ (!d ⟨0, h0⟩)

section Gates

variable {S : ZK60.Block.BlockShape} {c : W16Cfg} {Pb : ZK60.Block.BlockPublic S}
  {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : W16Pub S Pb Lay) (hL : LayR Lay)

include hL

/-- `Dom::T` does not pad. -/
theorem gT_oneR (t : CtR c) : B.gT t = 1 := by
  obtain ⟨t0, rfl⟩ := hL.tok t
  exact B.gT_one t0

/-- `Dom::Q` does not pad. -/
theorem gQ_oneR (x : CtR c × ((CgR c × CjR c) × CdR c)) : B.gQ x = 1 := by
  obtain ⟨t, h, d⟩ := x
  obtain ⟨t0, rfl⟩ := hL.tok t
  obtain ⟨h0, rfl⟩ := hL.slot h
  obtain ⟨d0, rfl⟩ := hL.hd d
  exact B.gQ_one (t0, (h0, d0))

/-- `Dom::Kv` does not pad. -/
theorem gK_oneR (x : CtR c × (CgR c × CdR c)) : B.gK x = 1 := by
  obtain ⟨t, g, d⟩ := x
  obtain ⟨t0, rfl⟩ := hL.tok t
  obtain ⟨g0, rfl⟩ := hL.grp g
  obtain ⟨d0, rfl⟩ := hL.hd d
  exact B.gK_one (t0, (g0, d0))

/-- `Dom::S` does not pad. -/
theorem gS_oneR (x : (CgR c × CjR c) × CtR c × CtR c) : B.gS x = 1 := by
  obtain ⟨h, t, j⟩ := x
  obtain ⟨h0, rfl⟩ := hL.slot h
  obtain ⟨t0, rfl⟩ := hL.tok t
  obtain ⟨j0, rfl⟩ := hL.tok j
  exact B.gS_one (h0, t0, j0)

/-- `Dom::Ht` does not pad. -/
theorem gHt_oneR (x : (CgR c × CjR c) × CtR c) : B.gHt x = 1 := by
  obtain ⟨h, t⟩ := x
  obtain ⟨h0, rfl⟩ := hL.slot h
  obtain ⟨t0, rfl⟩ := hL.tok t
  exact B.gHt_one (h0, t0)

end Gates

/-! ## The hosts' cube encodings -/

section Enc

variable (c : W16Cfg)

/-- A host's cube width in its draw list (`τ`'s length). -/
abbrev tauLen (k : ℕ) : ℕ := segLn (ZK60.Exec.Slot.R13.draws c.sh k) .tau

theorem tau2 : tauLen c 2 = c.sh.lt := rfl
theorem tau14 : tauLen c 14 = c.sh.logs .D := rfl
theorem tau15 : tauLen c 15 = c.sh.logs .Q := rfl
theorem tau16 : tauLen c 16 = c.sh.logs .Kv := rfl
theorem tau17 : tauLen c 17 = c.sh.logs .S := rfl
theorem tau18 : tauLen c 18 = c.sh.logs .F := rfl

variable {c} {ls : ℕ} (G : GeoR c ls)

/-- **The hosts' cube encodings**: a host's cube point as its product cube's position. -/
def encR : (k : ℕ) → (Fin (tauLen c k) → Bool) → W16Pos (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)
  | 2, b => .t (castB (tau2 c) b)
  | 14, b => .d (splitD c (castB ((tau14 c).trans G.logD) b))
  | 15, b => .q (splitQ c (castB ((tau15 c).trans G.logQ) b))
  | 16, b => .kv (splitK c (castB ((tau16 c).trans G.logK) b))
  | 17, b => .s (splitS c (castB ((tau17 c).trans G.logS) b))
  | 18, b => .f (splitF c (castB ((tau18 c).trans G.logF) b))
  | _, _ => .t (fun _ => false)

/-- **`Dom::Ht`'s cube encoding.** -/
def encHtR (b : Fin (c.sh.logs .Ht) → Bool) : W16Pos (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c) :=
  .ht (splitHt c (castB G.logHt b))

end Enc

/-! ## The shape facts -/

section Shape

/-- **The hosts' pad plane counts at R13**: the zero-rule planes of the padded domains (`DefR13.zeroPl`): `Dom::D`'s
39 planes at `SC_DZC`, `Dom::F`'s 16 at `SC_FZC` (both configurations); the other hosts' domains do not pad. -/
def mpadR (k : ℕ) : ℕ := if k = 14 then 39 else if k = 18 then 16 else 0

theorem mpadR_le78 : ∀ k ∈ algHosts, mpadR k ≤ 78 := by decide

theorem mpadR_zeroPl_rung : [mpadR 14, mpadR 18]
    = [(DefR13.zeroPl DefR13.cfgRungR13 .D).length, (DefR13.zeroPl DefR13.cfgRungR13 .F).length]
      ∧ DefR13.zeroPl DefR13.cfgRungR13 .T = [] ∧ DefR13.zeroPl DefR13.cfgRungR13 .Q = []
      ∧ DefR13.zeroPl DefR13.cfgRungR13 .Kv = [] ∧ DefR13.zeroPl DefR13.cfgRungR13 .S = []
      ∧ DefR13.zeroPl DefR13.cfgRungR13 .Ht = [] := by
  decide +kernel

theorem mpadR_zeroPl_shield : ∀ L ∈ ZK60.RunShape.Shield.shieldExport, [mpadR 14, mpadR 18]
    = [(DefR13.zeroPl (DefR13.cfgShieldR13 L) .D).length, (DefR13.zeroPl (DefR13.cfgShieldR13 L) .F).length]
      ∧ DefR13.zeroPl (DefR13.cfgShieldR13 L) .T = [] ∧ DefR13.zeroPl (DefR13.cfgShieldR13 L) .Q = []
      ∧ DefR13.zeroPl (DefR13.cfgShieldR13 L) .Kv = [] ∧ DefR13.zeroPl (DefR13.cfgShieldR13 L) .S = []
      ∧ DefR13.zeroPl (DefR13.cfgShieldR13 L) .Ht = [] := by
  decide +kernel

/-- **The draw schedule's shape facts at a configuration's shape `sh`** (every hypothesis of `algShapeStd` at R13's
draws, plus the room for the named clauses): decided at each profile (`shOk_rung`, `shOk_shield`). -/
structure ShOkR (sh : ZK60.Exec.Slot.W16R2.ShapeW) (P : BlockParams) : Prop where
  hsum : ∀ k ∈ algHosts, segSum (ZK60.Exec.Slot.R13.draws sh k) = P.draws k
  hm0 : ∀ k ∈ algHosts, segLn (ZK60.Exec.Slot.R13.draws sh k) .zeta = 0 → mpadR k = 0
  hle : ∀ k ∈ algHosts, ∀ i : Fin 2, ¬ (k = 16 ∨ (k = 18 ∧ i = 1)) → ¬ (k = 17 ∧ i = 0) →
    segLn (ZK60.Exec.Slot.R13.draws sh k) .tau ≤ P.draws (hostedOf k i)
      ∧ (k = 15 ∧ i = 1 → sh.lt + sh.lh ≤ P.draws (hostedOf k i))
  hp16 : ∀ i : Fin 2, segLn (ZK60.Exec.Slot.R13.draws sh 16) .tau = sh.lt + P.draws (hostedOf 16 i)
  hp18 : segLn (ZK60.Exec.Slot.R13.draws sh 18) .tau = sh.lt + P.draws (hostedOf 18 1)
  hq5 : sh.lt + sh.lq = P.draws 5
  hq11 : sh.lt + sh.lf = P.draws 11
  hb6 : P.draws 6 ≤ sh.lq
  hb7 : P.draws 7 ≤ sh.lq
  hb12 : P.draws 12 ≤ sh.lf
  hrs : sh.logs .Ht + 1 = P.draws 4
  hS17 : segLn (ZK60.Exec.Slot.R13.draws sh 17) .tau = sh.logs .Ht + sh.lt
  room : ∀ k ∈ algHosts, r13Count k ≤ segLn (ZK60.Exec.Slot.R13.draws sh k) .mu
    - segLn (ZK60.Exec.Slot.R13.draws sh k) .zeta

/-- **The R13 block's shape facts at a configuration** (`lt`, `lh`, `lq`, `lf`, `Dom::Ht`'s log, `Dom::S`'s column
log `lt`; the pad plane counts `mpadR`). -/
def algShapeR (c : W16Cfg) (P : BlockParams) (hc : ShOkR c.sh P) : AlgShape P :=
  algShapeStd P (ZK60.Exec.Slot.R13.draws c.sh) mpadR c.sh.lt c.sh.lh c.sh.lq c.sh.lf (c.sh.logs .Ht) c.sh.lt
    hc.hsum (hostLay_r13 c.sh) hc.hm0 mpadR_le78 hc.hle hc.hp16 hc.hp18 hc.hq5 hc.hq11 hc.hb6 hc.hb7 hc.hb12 hc.hrs
    hc.hS17

/-- **The verifier's per-slot draw counts and schedule are the configuration's** (L17's R13 draw formula `drawLen`,
`Shape::slots`' formula `sched`): decided at each profile (`profR_rung`, `profR_shield`). -/
structure ProfR (sh : ZK60.Exec.Slot.W16R2.ShapeW) (P : BlockParams) : Prop where
  draws : ∀ k, k < 23 → P.draws k = ZK60.Exec.Slot.R13.drawLen sh k
  slots : ∀ k, k < 23 → slotShape P k = ZK60.Exec.Slot.W16R2.sched sh k

/-- An `IsRungR13`-shaped verifier's draws and schedule are the R13 rung configuration's. -/
theorem profR_rung (P : BlockParams) (hdr : P.draws = ZK60.Exec.Block.R13.rungDraws)
    (hsl : P.geom.slots = ZK60.Exec.Block.R13.rungSlots) : ProfR DefR13.cfgRungR13.sh P := by
  refine ⟨fun k hk => ?_, fun k hk => ?_⟩
  · rw [hdr]
    revert k
    decide
  · unfold slotShape
    rw [hsl]
    revert k
    decide

/-- An `IsShieldR13`-shaped verifier's draws and schedule are the Shieldstral shape's. -/
theorem profR_sh_shield (P : BlockParams) (hdr : P.draws = ZK60.Exec.Block.R13.shieldDraws)
    (hsl : P.geom.slots = ZK60.Exec.Block.R13.shieldSlots) : ProfR ZK60.Exec.Slot.R13.shShieldR13 P := by
  refine ⟨fun k hk => ?_, fun k hk => ?_⟩
  · rw [hdr]
    revert k
    decide
  · unfold slotShape
    rw [hsl]
    revert k
    decide

/-- An `IsShieldR13`-shaped verifier's draws and schedule are every Shieldstral layer configuration's. -/
theorem profR_shield (L : ZK60.RunShape.Shield.ShieldLayer) (P : BlockParams)
    (hdr : P.draws = ZK60.Exec.Block.R13.shieldDraws) (hsl : P.geom.slots = ZK60.Exec.Block.R13.shieldSlots) :
    ProfR (DefR13.cfgShieldR13 L).sh P :=
  profR_sh_shield P hdr hsl

/-- The R13 rung's shape facts, at a verifier with the rung's draws. -/
theorem shOk_rung (P : BlockParams) (hdr : P.draws = ZK60.Exec.Block.R13.rungDraws) :
    ShOkR DefR13.cfgRungR13.sh P := by
  constructor <;> (try simp only [hdr]) <;> decide

/-- The Shieldstral shape's facts, at a verifier with the block's draws. -/
theorem shOk_sh_shield (P : BlockParams) (hdr : P.draws = ZK60.Exec.Block.R13.shieldDraws) :
    ShOkR ZK60.Exec.Slot.R13.shShieldR13 P := by
  constructor <;> (try simp only [hdr]) <;> decide

/-- Every Shieldstral layer's shape facts, at a verifier with the block's draws. -/
theorem shOk_shield (L : ZK60.RunShape.Shield.ShieldLayer) (P : BlockParams)
    (hdr : P.draws = ZK60.Exec.Block.R13.shieldDraws) : ShOkR (DefR13.cfgShieldR13 L).sh P :=
  shOk_sh_shield P hdr

end Shape

/-! ## The algebra data and `R13Spec` -/

section Dt

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)
  (P : BlockParams) (hc : ShOkR c.sh P)
  (E : Cuts3 L → RootsO → R13Data (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c) ls)

/-- **Which named relation the IR batches at `μ_κ`**: the code's batch order. Every host batches `R13Rels`' clauses in
`r13Cl`'s order except `SC_DZC`, whose IR (`r13DzcIr`, `batchB … [4, 5, 7, 9, 11, 13, 14, 15, 16, 18, 20, 22, 23]`,
slot_ir_accuracy.rs `c0 … c12`) interleaves the word decompositions: `d0, d1, wX, wY, wAO, wX1, d2, d3, d4, wYM, wZ,
wX2, d5`, i.e. `r13Cl 14` indices `0, 1, 6, 7, 8, 9, 2, 3, 4, 10, 11, 12, 5`. -/
def clIx (k κ : ℕ) : ℕ := if k = 14 then [0, 1, 6, 7, 8, 9, 2, 3, 4, 10, 11, 12, 5].getD κ κ else κ

/-- The batch position of named relation `j` (`clIx`'s inverse). -/
def clInv (k j : ℕ) : ℕ := if k = 14 then [0, 1, 6, 7, 8, 12, 2, 3, 4, 5, 9, 10, 11].getD j j else j

theorem clInv_lt : ∀ k ∈ algHosts, ∀ j, j < r13Count k → clInv k j < r13Count k := by decide

theorem clIx_clInv : ∀ k ∈ algHosts, ∀ j, j < r13Count k → clIx k (clInv k j) = j := by decide

/-- `SC_RS`'s scale `per_row` is not `0` in an extension of the Goldilocks field (it is a power of two below `2^64`). -/
theorem perRow_ne_zero (n : ℕ) (hn : n < gP) (h0 : 0 < n) : (n : K) ≠ 0 := by
  intro h
  have h1 : algebraMap GF K (n : GF) = 0 := by rw [map_natCast]; exact h
  have h2 : (n : GF) = 0 := (algebraMap GF K).injective (h1.trans (map_zero _).symm)
  rw [ZMod.natCast_eq_zero_iff] at h2
  exact absurd (Nat.le_of_dvd h0 h2) (by omega)

/-- **The algebra data at R13**: the named relations' tables of the extracted planes `E` through the encodings, in the
IR's batch order (`clIx`); the batch entries past the named clauses `xc` and the pad planes `pwc` given; `SC_RS`'s
scale `per_row`. -/
noncomputable def dtR (hpr : 0 < c.sh.perRow ∧ c.sh.perRow < gP)
    (xc : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → ℕ → (Fin (tauLen c k) → Bool) → K)
    (pwc : (k : ℕ) → Cuts3 L → RootsO → Fin (mpadR k) → (Fin (tauLen c k) → Bool) → K) :
    AlgData K L (algShapeR c P hc) where
  cl k cu rt bga κ b :=
    if (κ : ℕ) < r13Count k then
      algebraMap GF K (ZK60.Exec.Block.r13Cl Pb Lay B (E cu rt) k (clIx k κ) (encR G k b))
    else xc k cu rt bga κ b
  pw k cu rt j b := pwc k cu rt j b
  gh k cu rt i b := algebraMap GF K (ZK60.Exec.Block.r13Gh Pb Lay B (E cu rt) k i (encR G k b))
  mm k cu rt i b := algebraMap GF K (ZK60.Exec.Block.r13Mm Pb Lay B (E cu rt) k i (encR G k b))
  rsA cu rt b := algebraMap GF K (ZK60.Exec.Block.r13RsA Pb Lay B (E cu rt) (encHtR G b))
  rsB cu rt b := algebraMap GF K (ZK60.Exec.Block.r13RsB Pb Lay B (E cu rt) (encHtR G b))
  rsScale := (c.sh.perRow : K)
  hsc := perRow_ne_zero c.sh.perRow hpr.2 hpr.1

/-- **Lane L36's `hspec` at R13** (`R13Spec`): the algebra data `dtR` IS `R13Rels`' relation tables of `E` through onto
encodings, for every choice of the batch's other entries and the pad planes. -/
theorem hspecR (hpr : 0 < c.sh.perRow ∧ c.sh.perRow < gP)
    (xc : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → ℕ → (Fin (tauLen c k) → Bool) → K)
    (pwc : (k : ℕ) → Cuts3 L → RootsO → Fin (mpadR k) → (Fin (tauLen c k) → Bool) → K) :
    R13Spec (algShapeR c P hc) (dtR G Pb Lay B P hc E hpr xc pwc) Pb Lay B E (encR G) (encHtR G) where
  cl k hk j hj := by
    refine ⟨⟨clInv k j, lt_of_lt_of_le (clInv_lt k hk j hj) (hc.room k hk)⟩, fun cu rt bga b => ?_⟩
    show (if clInv k j < r13Count k then _ else _) = _
    rw [ite_eq_left (clInv_lt k hk j hj), clIx_clInv k hk j hj]
  gh _ _ _ _ _ _ _ := rfl
  mm _ _ _ _ _ _ _ := rfl
  rsA _ _ _ := rfl
  rsB _ _ _ := rfl
  st x := ⟨castB (tau2 c).symm x, by show W16Pos.t (castB _ (castB _ x)) = _; rw [castB_castB]⟩
  sd x := ⟨castB ((tau14 c).trans G.logD).symm (Fin.append x.1 x.2), by
    show W16Pos.d (splitD c (castB _ (castB _ _))) = _
    rw [castB_castB, splitD_append]⟩
  sq x := ⟨castB ((tau15 c).trans G.logQ).symm (Fin.append x.1 (Fin.append (Fin.append x.2.1.1 x.2.1.2) x.2.2)), by
    show W16Pos.q (splitQ c (castB _ (castB _ _))) = _
    rw [castB_castB, splitQ_append]⟩
  sk x := ⟨castB ((tau16 c).trans G.logK).symm (Fin.append x.1 (Fin.append x.2.1 x.2.2)), by
    show W16Pos.kv (splitK c (castB _ (castB _ _))) = _
    rw [castB_castB, splitK_append]⟩
  ss x := ⟨castB ((tau17 c).trans G.logS).symm (Fin.append (Fin.append x.1.1 x.1.2) (Fin.append x.2.1 x.2.2)), by
    show W16Pos.s (splitS c (castB _ (castB _ _))) = _
    rw [castB_castB, splitS_append]⟩
  sf x := ⟨castB ((tau18 c).trans G.logF).symm (Fin.append x.1 x.2), by
    show W16Pos.f (splitF c (castB _ (castB _ _))) = _
    rw [castB_castB, splitF_append]⟩
  sht x := ⟨castB G.logHt.symm (Fin.append (Fin.append x.1.1 x.1.2) x.2), by
    show W16Pos.ht (splitHt c (castB _ (castB _ _))) = _
    rw [castB_castB, splitHt_append]⟩

end Dt

/-! ## The public tables -/

section Pub

variable {K : Type} [Field K] [Algebra GF K]

/-- **The verifier's public tables at an R13 configuration, as the block's public data.** Table `i` of slot `s`, read
at the slot's cube point `b` (`msbIndex`), is the public value there: the support gates, the norms' `γ`, RoPE's `cos`
and `sin`, the causal mask, the activation's group column; for the seven matmuls the weights folded by `eq` of the
slot's output draws (`fold_rows_i8`, `W̃(c) = Σ_j eq(r_out, j)·W(c, j)`). One field per table the hosts read (the R13
counterpart of lane L44's `PubW16`; the slots, tables and draws are R13's, which are W16R2's for these slots). -/
structure PubR (U : K) (c : W16Cfg) (pubs : PubTabs) {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay) : Prop where
  /-- `SC_SS`, `SC_SSM`: `supp(D)` -/
  ssGate : ∀ s, s = 0 ∨ s = 1 → ∀ hist dr (t : CtR c) (w : CwR c),
    ((pubs s hist dr 0).getD (msbIndex (nD c) (Fin.append t w)) Fp2.zero).toK U = algebraMap GF K (B.gD (t, w))
  /-- `SC_RS`: the causal mask on `Dom::S` -/
  rsMask : ∀ hist dr (b : Fin (nS c) → Bool),
    ((pubs 4 hist dr 0).getD (msbIndex (nS c) b) Fp2.zero).toK U = algebraMap GF K (B.mask (splitS c b))
  /-- `SC_QMM`: `W_q` folded by `eq(r_j)` (draws `lt …`) -/
  wq : ∀ hist dr, (∀ x ∈ dr, x.Canon) → ∀ w : CwR c,
    ((pubs 5 hist dr 0).getD (msbIndex c.sh.ld w) Fp2.zero).toK U
      = ∑ y : Fin (nH c + c.sh.ldh) → Bool, W16.eqDr U dr c.sh.lt (nH c + c.sh.ldh) y
        * algebraMap GF K (B.Wq w (splitHQ c y))
  /-- `SC_KMM`: `W_k` folded by `eq(r_j)` (draws `0 …`) -/
  wk : ∀ hist dr, (∀ x ∈ dr, x.Canon) → ∀ w : CwR c,
    ((pubs 6 hist dr 0).getD (msbIndex c.sh.ld w) Fp2.zero).toK U
      = ∑ y : Fin (c.sh.lkv + c.sh.ldh) → Bool, W16.eqDr U dr 0 (c.sh.lkv + c.sh.ldh) y
        * algebraMap GF K (B.Wk w (splitGD c y))
  /-- `SC_VMM`: `W_v` folded by `eq(r_j)` (draws `0 …`) -/
  wv : ∀ hist dr, (∀ x ∈ dr, x.Canon) → ∀ w : CwR c,
    ((pubs 7 hist dr 0).getD (msbIndex c.sh.ld w) Fp2.zero).toK U
      = ∑ y : Fin (c.sh.lkv + c.sh.ldh) → Bool, W16.eqDr U dr 0 (c.sh.lkv + c.sh.ldh) y
        * algebraMap GF K (B.Wv w (splitGD c y))
  /-- `SC_WO`: `W_o` folded by `eq(r_j)` (draws `lt …`) -/
  wo : ∀ hist dr, (∀ x ∈ dr, x.Canon) → ∀ q : Fin (nH c + c.sh.ldh) → Bool,
    ((pubs 10 hist dr 0).getD (msbIndex (nH c + c.sh.ldh) q) Fp2.zero).toK U
      = ∑ y : CwR c, W16.eqDr U dr c.sh.lt c.sh.ld y * algebraMap GF K (B.Wo (splitHQ c q) y)
  /-- `SC_GMM`: `W_g` folded by `eq(r_j)` (draws `lt …`) -/
  wg : ∀ hist dr, (∀ x ∈ dr, x.Canon) → ∀ w : CwR c,
    ((pubs 11 hist dr 0).getD (msbIndex c.sh.ld w) Fp2.zero).toK U
      = ∑ y : CfR c, W16.eqDr U dr c.sh.lt c.sh.lf y * algebraMap GF K (B.Wg w y)
  /-- `SC_UMM`: `W_u` folded by `eq(r_j)` (draws `0 …`) -/
  wu : ∀ hist dr, (∀ x ∈ dr, x.Canon) → ∀ w : CwR c,
    ((pubs 12 hist dr 0).getD (msbIndex c.sh.ld w) Fp2.zero).toK U
      = ∑ y : CfR c, W16.eqDr U dr 0 c.sh.lf y * algebraMap GF K (B.Wu w y)
  /-- `SC_DMM`: `W_d` folded by `eq(r_j)` (draws `lt …`) -/
  wd : ∀ hist dr, (∀ x ∈ dr, x.Canon) → ∀ f : CfR c,
    ((pubs 13 hist dr 0).getD (msbIndex c.sh.lf f) Fp2.zero).toK U
      = ∑ y : CwR c, W16.eqDr U dr c.sh.lt c.sh.ld y * algebraMap GF K (B.Wd f y)
  /-- `SC_DZC`: `γ_a`, `γ_m`, `supp(D)` -/
  dzcGamA : ∀ hist dr (b : Fin (nD c) → Bool),
    ((pubs 14 hist dr 0).getD (msbIndex (nD c) b) Fp2.zero).toK U = algebraMap GF K (B.gamA (splitD c b))
  dzcGamM : ∀ hist dr (b : Fin (nD c) → Bool),
    ((pubs 14 hist dr 1).getD (msbIndex (nD c) b) Fp2.zero).toK U = algebraMap GF K (B.gamM (splitD c b))
  dzcGate : ∀ hist dr (b : Fin (nD c) → Bool),
    ((pubs 14 hist dr 2).getD (msbIndex (nD c) b) Fp2.zero).toK U = algebraMap GF K (B.gD (splitD c b))
  /-- `SC_QZC`: RoPE's `cos`, signed `sin` on `Dom::Q` -/
  qzcCos : ∀ hist dr (b : Fin (nQ c) → Bool),
    ((pubs 15 hist dr 0).getD (msbIndex (nQ c) b) Fp2.zero).toK U = algebraMap GF K (B.cosT (splitQ c b))
  qzcSin : ∀ hist dr (b : Fin (nQ c) → Bool),
    ((pubs 15 hist dr 1).getD (msbIndex (nQ c) b) Fp2.zero).toK U = algebraMap GF K (B.sinT (splitQ c b))
  /-- `SC_KVZC`: RoPE's `cos`, signed `sin` on `Dom::Kv` -/
  kvCos : ∀ hist dr (b : Fin (nK c) → Bool),
    ((pubs 16 hist dr 0).getD (msbIndex (nK c) b) Fp2.zero).toK U = algebraMap GF K (B.cosK (splitK c b))
  kvSin : ∀ hist dr (b : Fin (nK c) → Bool),
    ((pubs 16 hist dr 1).getD (msbIndex (nK c) b) Fp2.zero).toK U = algebraMap GF K (B.sinK (splitK c b))
  /-- `SC_SZC`: the causal mask on `Dom::S` -/
  szcMask : ∀ hist dr (b : Fin (nS c) → Bool),
    ((pubs 17 hist dr 0).getD (msbIndex (nS c) b) Fp2.zero).toK U = algebraMap GF K (B.mask (splitS c b))
  /-- `SC_FZC`: the activation's group column, `supp(F)` -/
  fzcGrp : ∀ hist dr (b : Fin (nF c) → Bool),
    ((pubs 18 hist dr 0).getD (msbIndex (nF c) b) Fp2.zero).toK U = algebraMap GF K (B.grpCol (splitF c b))
  fzcGate : ∀ hist dr (b : Fin (nF c) → Bool),
    ((pubs 18 hist dr 1).getD (msbIndex (nF c) b) Fp2.zero).toK U = algebraMap GF K (B.gF (splitF c b))

end Pub

/-! ## The integer model's precision -/

/-- **The integer model's shape constants are the configuration's precision** (the IRs' constants): the norms'
`ceps`, `cn`, `tn`, every requantization shift, the product fold (`sprod` is the code's `fold`), `f_p`, `wrho`, the
stack; the code's RoPE shift `7` and product word width `24`. A public-data fact. -/
structure PrecR (c : W16Cfg) (S : ZK60.Block.BlockShape) : Prop where
  ceps : S.ceps = c.p.ceps
  cnA : S.cnA = c.p.cnA
  cnM : S.cnM = c.p.cnM
  tn : S.tn = c.p.tn
  sq : S.sq = c.p.q
  sk : S.sk = c.p.k
  sv : S.sv = c.p.v
  ss : S.ss = c.p.score
  spv : S.spv = c.p.pv
  sao : S.sao = c.p.ao
  sgate : S.sgate = c.p.gate
  sup : S.sup = c.p.up
  sprod : S.sprod = c.p.fold
  sdown : S.sdown = c.p.down
  fp : S.fp = c.p.fp
  wrho : S.wrho = c.p.wrho
  h24 : S.h24 = true
  rope : c.p.rope = 7
  pb : c.p.prodbits = 24

/-- At the R13 rung (whose precision is the W16R2 rung's, `precRungW16`), `RungS` gives `PrecR`. -/
theorem precR_rung {S : ZK60.Block.BlockShape} (hS : RungS S) : PrecR DefR13.cfgRungR13 S where
  ceps := hS.ceps
  cnA := hS.cnA
  cnM := hS.cnM
  tn := hS.tn
  sq := hS.sq
  sk := hS.sk
  sv := hS.sv
  ss := hS.ss
  spv := hS.spv
  sao := hS.sao
  sgate := hS.sgate
  sup := hS.sup
  sprod := hS.sprod
  sdown := hS.sdown
  fp := hS.fp
  wrho := hS.wrho
  h24 := hS.h24
  rope := rfl
  pb := rfl

/-- **At every Shieldstral layer, the layer's own shape `shieldShape L` (lane L40) has the layer's precision**, by
definition: the shifts `sh_s + 12`, `sh_ao + 14`, `sh_z + 14`, the gate fold's shift, the layer's `cn_a`, `cn_m`. -/
theorem precR_shield (L : ZK60.RunShape.Shield.ShieldLayer) :
    PrecR (DefR13.cfgShieldR13 L) (ZK60.RunShape.Shield.shieldShape L) :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

/-! ## The committed matrix is base-valued -/

section Base

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **R13's committed `A` matrix is base-valued** (finding L41-1, at R13's `(16, 256, 24448)`; any row count). -/
theorem dXof_base_r13 (tag : MTag) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (hlc : P.logCols = 14) (rA rH : ℕ)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (cu : Cuts3 L) (rt : RootsO) :
    ∀ i t, (dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE cu rt).X .a i t ∈ baseR K := by
  intro i t
  obtain ⟨g, hg⟩ := xAof_base_r13 (K := K) tag L (Link.le64_of_le20 hL20) rA cu rt i (colCast P hlc 256 t)
  exact ⟨g, hg.symm⟩

end Base

/-! ## The numbered program's slots -/

/-- **R13's slot `k`, numbered**: the raw slot `k` numbered from some claim sites (the reserved mask rows depend on
the earlier slots; a table's value on the cube never reads them). -/
theorem progR13_slot (c : W16Cfg) (ioIn ioOut k : ℕ) (hk : k < 23) : ∃ ak hk',
    (DefR13.progR13 c ioIn ioOut).getD k SlotS.empty
      = DefW16.numSlot (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut ak hk' (DefR13.rawSlot c k) := by
  have hlen : k < (DefR13.rawProg c).length := by
    unfold DefR13.rawProg
    rw [List.length_map, List.length_range]
    exact hk
  obtain ⟨a, h, e⟩ := R13T.numProg_getD (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut (DefR13.rawProg c) k 0 0
    hlen
  refine ⟨a, h, ?_⟩
  show (DefW16.numProg (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut 0 0 (DefR13.rawProg c)).getD k
    SlotS.empty = _
  rw [e]
  congr 1
  unfold DefR13.rawProg
  rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range hk]
  rfl

/-- The numbering keeps a slot's IR, hosted list and nonzero list. -/
theorem numSlot_fields (aB hB ioIn ioOut ak hk : ℕ) (s : SlotS) :
    (DefW16.numSlot aB hB ioIn ioOut ak hk s).ir = s.ir ∧ (DefW16.numSlot aB hB ioIn ioOut ak hk s).hosted = s.hosted
      ∧ (DefW16.numSlot aB hB ioIn ioOut ak hk s).nonzero = s.nonzero := ⟨rfl, rfl, rfl⟩

end ZK60.Exec.Block.Join.R13H

/-
D63 lane L49 (2026-11-10), sub-agent `pub`: **the verifier's public tables at an R13 configuration, from the block's
public data, generic in the configuration** (the R13 counterpart of lane L44's `BlockHostPub.lean`, `pubsW16` and
`pubW16_of`), for the R13 rung (`cfgRungR13`) and every layer of the Shieldstral T128 R13 block (`cfgShieldR13 L`).

The code (`ops/zkp-mvp/gpu-metal/hashline/src/private_block/`, read 2026-11-10; nothing there is changed): the shared
arms of `argument.rs::define` (`SC_SS`, `SC_SSM`, `SC_LZC`, `SC_RS`, the seven matmuls: `r_q` / `r_tf` / `r_row` of
`lt` draws first where the slot draws one, then `r_j` of `lg(outer)` draws, `eq_table_msb(r_j)`, `accuracy_fold::fold`
with the multipliers) and R13's `argument_accuracy.rs` (`dzc`: `γ_a`, `γ_m`, `supp(D)`; `qzc`: `cos`, `sin`; `szc`:
the causal mask; `fzc`: the group column, `supp(F)`); a gate is `B::supp`, `pad::indicator_table` laid over the cube.

* **`pubsR13 c Pb Lay B rest`**: every public table the R13 hosts read, built from `B` in the code's arithmetic
  (`cubeTab`, `foldTab` of L44), at the configuration's widths (`nD c`, `nQ c`, `nK c`, `nS c`, `nF c`, `c.sh.ld`,
  `c.sh.lf`, the head slot `nH c + c.sh.ldh`) and draw offsets (`c.sh.lt` or `0`); the lookup side's slots `3`, `19`,
  `20` from `rest` (`pubsR13_rest`);
* **`pubR_of`**: `PubR U c (pubsR13 c Pb Lay B rest) Pb Lay B`, for every `c` and every `rest` (no fact about `c`);
* `SC_LZC`'s public table (slot `3`, `DefR13.rawSlot c 3`): **`gateLS sh`**, `supp(Dom::L)` (`x / 2^lt < 9`: the
  token axis, which does not pad at R13, and the `3·LIMBS_ISQRT = 9` limb rows); lane L47's `restR13` does NOT carry
  it (`restR13_three`: its slot `3` is `[]`), so **`restR13L c exp act nG`** extends it at slot `3`
  (`restR13L_three`, `restR13L_ne`, `rest3R13L_getD`); `gateLS_rung`: at the rung it IS L47's W16R2 `gateLW`;
* **`PubCfg c`** (`Dom::L` pads under the pad rule), `pubCfg_rung`, `pubCfg_shield`; `zeroPl_L`, `lzc_gate`,
  **`rawSlot3_tabs`**: R13's raw slot `3` reads exactly one public table, its last;
* `pubsR13L`, `pubR_of_L`: the tables with `restR13L` at a block's public data.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Pub

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H
open ZK60.Exec.Block.Join.W16 (wordGF toK_wordGF cubeTab cubeTab_getD drSeg foldTab fold_eqDr)
open ZK60.Exec.Block.Join.R13T (restR13)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.W16R2 (ShapeW)
open ZK60.Circuit (gP GF)
open ZK60.Layout

/-! ## The host slots' public tables -/

section Pubs

variable (c : W16Cfg) {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)

/-- **The verifier's public tables at an R13 configuration `c`, from the public data `B`**: table `i` of slot `s` at
the history and the slot's draws `dr`; the supports, the norms' gains, the causal mask, RoPE's `cos` / `sin`, the
activation's group column on their domains' cubes, and the seven matmuls' weights folded by `eq` of the slot's output
draws (`r_j` after `lt` row draws at `SC_QMM`, `SC_WO`, `SC_GMM`, `SC_DMM`; from draw `0` at `SC_KMM`, `SC_VMM`,
`SC_UMM`); the lookup side's tables (`SC_LZC`, `SC_TAB`, `SC_ZS`, slots `3`, `19`, `20`) from `rest`. -/
def pubsR13 (rest : PubTabs) : PubTabs := fun s hist dr i =>
  if s = 0 ∨ s = 1 then (if i = 0 then cubeTab (nD c) (fun b => B.gD (splitD c b)) else [])
  else if s = 4 then (if i = 0 then cubeTab (nS c) (fun b => B.mask (splitS c b)) else [])
  else if s = 5 then
    (if i = 0 then foldTab c.sh.ld (nH c + c.sh.ldh) (fun w y => B.Wq w (splitHQ c y))
      (drSeg dr c.sh.lt (nH c + c.sh.ldh)) else [])
  else if s = 6 then
    (if i = 0 then foldTab c.sh.ld (c.sh.lkv + c.sh.ldh) (fun w y => B.Wk w (splitGD c y))
      (drSeg dr 0 (c.sh.lkv + c.sh.ldh)) else [])
  else if s = 7 then
    (if i = 0 then foldTab c.sh.ld (c.sh.lkv + c.sh.ldh) (fun w y => B.Wv w (splitGD c y))
      (drSeg dr 0 (c.sh.lkv + c.sh.ldh)) else [])
  else if s = 10 then
    (if i = 0 then foldTab (nH c + c.sh.ldh) c.sh.ld (fun q y => B.Wo (splitHQ c q) y) (drSeg dr c.sh.lt c.sh.ld)
      else [])
  else if s = 11 then
    (if i = 0 then foldTab c.sh.ld c.sh.lf (fun w y => B.Wg w y) (drSeg dr c.sh.lt c.sh.lf) else [])
  else if s = 12 then (if i = 0 then foldTab c.sh.ld c.sh.lf (fun w y => B.Wu w y) (drSeg dr 0 c.sh.lf) else [])
  else if s = 13 then
    (if i = 0 then foldTab c.sh.lf c.sh.ld (fun f y => B.Wd f y) (drSeg dr c.sh.lt c.sh.ld) else [])
  else if s = 14 then
    (if i = 0 then cubeTab (nD c) (fun b => B.gamA (splitD c b))
      else if i = 1 then cubeTab (nD c) (fun b => B.gamM (splitD c b))
      else if i = 2 then cubeTab (nD c) (fun b => B.gD (splitD c b)) else [])
  else if s = 15 then
    (if i = 0 then cubeTab (nQ c) (fun b => B.cosT (splitQ c b))
      else if i = 1 then cubeTab (nQ c) (fun b => B.sinT (splitQ c b)) else [])
  else if s = 16 then
    (if i = 0 then cubeTab (nK c) (fun b => B.cosK (splitK c b))
      else if i = 1 then cubeTab (nK c) (fun b => B.sinK (splitK c b)) else [])
  else if s = 17 then (if i = 0 then cubeTab (nS c) (fun b => B.mask (splitS c b)) else [])
  else if s = 18 then
    (if i = 0 then cubeTab (nF c) (fun b => B.grpCol (splitF c b))
      else if i = 1 then cubeTab (nF c) (fun b => B.gF (splitF c b)) else [])
  else rest s hist dr i

/-- **The lookup side's slots read `rest`.** -/
theorem pubsR13_rest (rest : PubTabs) (s : ℕ) (hs : s = 3 ∨ s = 19 ∨ s = 20) (hist : Hist) (dr : List Fp2)
    (i : ℕ) : pubsR13 c Pb Lay B rest s hist dr i = rest s hist dr i := by
  rcases hs with rfl | rfl | rfl <;> rfl

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **The concrete public tables meet `PubR`**, at every configuration `c`, for every `rest`. -/
theorem pubR_of (rest : PubTabs) : PubR U c (pubsR13 c Pb Lay B rest) Pb Lay B where
  ssGate s hs hist dr t w := by
    have h : pubsR13 c Pb Lay B rest s hist dr 0 = cubeTab (nD c) (fun b => B.gD (splitD c b)) := by
      unfold pubsR13; rw [ite_eq_left hs, ite_eq_left rfl]
    rw [h, cubeTab_getD, toK_wordGF, show splitD c (Fin.append t w) = (t, w) from splitD_append c (t, w)]
  rsMask hist dr b := by
    show ((cubeTab (nS c) (fun b => B.mask (splitS c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  wq hist dr hdr w := fold_eqDr U hU c.sh.ld (nH c + c.sh.ldh) (fun w y => B.Wq w (splitHQ c y)) dr hdr c.sh.lt w
  wk hist dr hdr w := fold_eqDr U hU c.sh.ld (c.sh.lkv + c.sh.ldh) (fun w y => B.Wk w (splitGD c y)) dr hdr 0 w
  wv hist dr hdr w := fold_eqDr U hU c.sh.ld (c.sh.lkv + c.sh.ldh) (fun w y => B.Wv w (splitGD c y)) dr hdr 0 w
  wo hist dr hdr q := fold_eqDr U hU (nH c + c.sh.ldh) c.sh.ld (fun q y => B.Wo (splitHQ c q) y) dr hdr c.sh.lt q
  wg hist dr hdr w := fold_eqDr U hU c.sh.ld c.sh.lf (fun w y => B.Wg w y) dr hdr c.sh.lt w
  wu hist dr hdr w := fold_eqDr U hU c.sh.ld c.sh.lf (fun w y => B.Wu w y) dr hdr 0 w
  wd hist dr hdr f := fold_eqDr U hU c.sh.lf c.sh.ld (fun f y => B.Wd f y) dr hdr c.sh.lt f
  dzcGamA hist dr b := by
    show ((cubeTab (nD c) (fun b => B.gamA (splitD c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  dzcGamM hist dr b := by
    show ((cubeTab (nD c) (fun b => B.gamM (splitD c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  dzcGate hist dr b := by
    show ((cubeTab (nD c) (fun b => B.gD (splitD c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  qzcCos hist dr b := by
    show ((cubeTab (nQ c) (fun b => B.cosT (splitQ c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  qzcSin hist dr b := by
    show ((cubeTab (nQ c) (fun b => B.sinT (splitQ c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  kvCos hist dr b := by
    show ((cubeTab (nK c) (fun b => B.cosK (splitK c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  kvSin hist dr b := by
    show ((cubeTab (nK c) (fun b => B.sinK (splitK c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  szcMask hist dr b := by
    show ((cubeTab (nS c) (fun b => B.mask (splitS c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  fzcGrp hist dr b := by
    show ((cubeTab (nF c) (fun b => B.grpCol (splitF c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  fzcGate hist dr b := by
    show ((cubeTab (nF c) (fun b => B.gF (splitF c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]

end Pubs

/-! ## `SC_LZC`'s public table: `supp(Dom::L)` -/

section Lzc

/-- **`supp(Dom::L)` at a shape** (`pad.rs::support_indicator`, the builder's support `lix(k, t) = k·t_pad + t` for
`k < 3·LIMBS_ISQRT = 9`, `t < tokens`; at R13 `tokens = t_pad = 2^lt`, CHECKED by the export): `x / 2^lt < 9`. -/
def gateLS (sh : ShapeW) (b : Fin (sh.logs .L) → Bool) : GF := if msbIndex (sh.logs .L) b / 2 ^ sh.lt < 9 then 1 else 0

/-- **At the R13 rung, `supp(Dom::L)` is L47's W16R2 `gateLW`** (the same `14`-variable cube, the same `32` tokens). -/
theorem gateLS_rung : gateLS ZK60.Exec.Slot.R13.shRungR13 = ZK60.Exec.Block.Join.W16.Tab.gateLW := rfl

/-- **L47's `restR13` does not carry `SC_LZC`'s table** (its slot `3` is empty), which R13's raw slot `3` reads
(`rawSlot3_tabs`). -/
theorem restR13_three (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) (hist : Hist) (dr : List Fp2) (i : ℕ) :
    restR13 exp act nG 3 hist dr i = [] := rfl

/-- **R13's lookup-side public tables, with `SC_LZC`'s**: `supp(Dom::L)` at slot `3` (table `0`), L47's `restR13`
(`SC_TAB`'s three value columns and two gates, `SC_ZS`'s all-ones table) elsewhere. -/
def restR13L (c : W16Cfg) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) : PubTabs := fun s hist dr i =>
  if s = 3 then (if i = 0 then cubeTab (c.sh.logs .L) (gateLS c.sh) else []) else restR13 exp act nG s hist dr i

variable (c : W16Cfg) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ)

theorem restR13L_three (hist : Hist) (dr : List Fp2) (i : ℕ) :
    restR13L c exp act nG 3 hist dr i = if i = 0 then cubeTab (c.sh.logs .L) (gateLS c.sh) else [] := rfl

/-- Outside slot `3`, `restR13L` is L47's `restR13` (so L47's `rest19R13_getD`, `rest19R13_gate_getD`,
`rest20R13_getD` read it). -/
theorem restR13L_ne (s : ℕ) (hs : s ≠ 3) (hist : Hist) (dr : List Fp2) (i : ℕ) :
    restR13L c exp act nG s hist dr i = restR13 exp act nG s hist dr i := by
  show (if s = 3 then _ else _) = _
  rw [ite_eq_right hs]

/-- **`SC_LZC`'s table, read in the field**: `supp(Dom::L)`. -/
theorem rest3R13L_getD {K : Type} [Field K] [Algebra GF K] (U : K) (hist : Hist) (dr : List Fp2)
    (b : Fin (c.sh.logs .L) → Bool) :
    ((restR13L c exp act nG 3 hist dr 0).getD (msbIndex (c.sh.logs .L) b) Fp2.zero).toK U
      = algebraMap GF K (gateLS c.sh b) := by
  show ((cubeTab (c.sh.logs .L) (gateLS c.sh)).getD _ _).toK U = _
  rw [cubeTab_getD, toK_wordGF]

end Lzc

/-! ## R13's raw slot `3` reads one public table -/

section Raw

/-- **The facts about a configuration this file reads**: the pad rule is on and `Dom::L` pads. PROVED at the rung and
at every Shieldstral layer (`pubCfg_rung`, `pubCfg_shield`). -/
structure PubCfg (c : W16Cfg) : Prop where
  padRule : c.sh.padRule = true
  padsL : c.sh.pads .L = true

theorem pubCfg_rung : PubCfg DefR13.cfgRungR13 := ⟨rfl, rfl⟩

theorem pubCfg_shield (L : ZK60.RunShape.Shield.ShieldLayer) : PubCfg (DefR13.cfgShieldR13 L) := ⟨rfl, rfl⟩

/-- `A_E`'s id is `77 + nrd` (`AccuracyIds::new`). -/
theorem idsR13_e (h24 : Bool) (ls : ℕ) : (DefR13.idsR13 h24 ls).e = 77 + (if h24 then 3 else 2) := by
  cases h24 <;> rfl

/-- **`Dom::L`'s zero-rule planes are its two limb planes** (`A_LIMB`, `A_LIMBM`; `A_E` is not on `Dom::L`). -/
theorem zeroPl_L (c : W16Cfg) (hc : PubCfg c) : DefR13.zeroPl c .L = [6, 7] := by
  have he : 79 ≤ (DefR13.ids c).e := by
    show 79 ≤ (DefR13.idsR13 c.p.h24 (DefR13.lsOf c.p)).e
    rw [idsR13_e]
    split <;> omega
  have h6 : (6 == (DefR13.ids c).e) = false := beq_eq_false_iff_ne.mpr (by omega)
  have h7 : (7 == (DefR13.ids c).e) = false := beq_eq_false_iff_ne.mpr (by omega)
  unfold DefR13.zeroPl
  rw [hc.padRule, hc.padsL]
  show List.filter (fun i => !(i == (DefR13.ids c).e)) [6, 7] = [6, 7]
  simp [List.filter, h6, h7]

/-- **R13's `SC_LZC` reads `supp(Dom::L)`**: the gate of its raw slot is on. -/
theorem lzc_gate (c : W16Cfg) (hc : PubCfg c) :
    (ZK60.Exec.Block.DefW16.supp c .L && !(DefR13.zeroPl c .L).isEmpty) = true := by
  rw [zeroPl_L c hc]
  show (c.sh.padRule && c.sh.pads .L && !([6, 7] : List ℕ).isEmpty) = true
  rw [hc.padRule, hc.padsL]
  rfl

/-- **R13's raw slot `3` (`SC_LZC`)**: the `τ` table, the two limb planes, the helper, and ONE public table, its last
(the numbering makes it public table `0`). -/
theorem rawSlot3_tabs (c : W16Cfg) (hc : PubCfg c) :
    (DefR13.rawSlot c 3).tabs = [TabS.eq (DefR13.seg c 3 0) 0, DefR13.aPlane c (DefR13.ids c).limb,
      DefR13.aPlane c (DefR13.ids c).limbm, DefR13.hTab c (DefR13.fh c 0), TabS.pub 0] := by
  show [TabS.eq (DefR13.seg c 3 0) 0, DefR13.aPlane c (DefR13.ids c).limb, DefR13.aPlane c (DefR13.ids c).limbm,
      DefR13.hTab c (DefR13.fh c 0)]
      ++ (if (ZK60.Exec.Block.DefW16.supp c .L && !(DefR13.zeroPl c .L).isEmpty) = true then [TabS.pub 0] else []) = _
  rw [lzc_gate c hc]
  rfl

end Raw

/-! ## The tables at a block's public data -/

section Final

variable (c : W16Cfg) {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay) (nG : ℕ)

/-- **Every public table R13's program reads**: the hosts' from `B`, the lookup side's from the public data (`SC_LZC`'s
support, `SC_TAB`'s value columns and gates at the exp table and the scaled ACT tables, `SC_ZS`'s ones). -/
def pubsR13L : PubTabs := pubsR13 c Pb Lay B (restR13L c Pb.exp Pb.act nG)

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

include hU in
theorem pubR_of_L : PubR U c (pubsR13L c Pb Lay B nG) Pb Lay B := pubR_of c Pb Lay B U hU _

/-- `SC_LZC`'s table of `pubsR13L`, read in the field: `supp(Dom::L)`. -/
theorem pubsR13L_three_getD (hist : Hist) (dr : List Fp2) (b : Fin (c.sh.logs .L) → Bool) :
    ((pubsR13L c Pb Lay B nG 3 hist dr 0).getD (msbIndex (c.sh.logs .L) b) Fp2.zero).toK U
      = algebraMap GF K (gateLS c.sh b) :=
  rest3R13L_getD c Pb.exp Pb.act nG U hist dr b

/-- `SC_TAB`'s and `SC_ZS`'s tables of `pubsR13L` are L47's `restR13`'s. -/
theorem pubsR13L_tab (s : ℕ) (hs : s = 19 ∨ s = 20) (hist : Hist) (dr : List Fp2) (i : ℕ) :
    pubsR13L c Pb Lay B nG s hist dr i = restR13 Pb.exp Pb.act nG s hist dr i := by
  rcases hs with rfl | rfl <;> rfl

end Final

end ZK60.Exec.Block.Join.R13H.Pub

/-
D63 lane L49 (2026-11-10), sub-agent `pub`: **the R13 host public tables `pubsR13` and `SC_LZC`'s `restR13L` against
the code, by VALUE** (the R13 counterpart of lane L47's `BlockHostExportCheck.lean`, which closed finding L44-E2 at the
W16R2 rung): the supports, the norms' gains, the causal mask, the seven folded weights at the receipt's own draws,
RoPE's `cos` / `sin`, the activation's group column and its gate (slots 0, 1, 4, 5, 6, 7, 10–18), and `SC_LZC`'s
`supp(Dom::L)` (slot 3) on the R13 rung receipt and at the Shieldstral T128 R13 shape.

Run (through the zk60 resource guard; a `run` line of `results/zk60_lean_l49_20261110/iter.sh`):
  lake -d formal env lean --run formal/ZK60Formal/BlockR13HostExportCheck.lean <corpus> [neg]

The corpus is written by the test-only `ops/zkp-mvp/gpu-metal/hashline/src/lean_l49_export_tests.rs`
(`lean_l49_export_the_r13_host_tables`) on a REAL R13 rung block receipt (`shape::R13_RUNG_H24`; the production
`prove_core` with `w16r2_tests`' seeded recipe, accepted by `verify_core`; the production `define` and `run_slot` on the
real transcript): the shape's numbers and head slots, the public data AS THE CODE STORES IT (`gamma_a`, `gamma_m`,
`rope_cos`, `rope_sin`, the ACT group ids, the folding multipliers, the seven weight matrices in the FULL corpus), every
slot's draws and table counts, every public table of every slot but 19 and 20 (length, two fingerprints
`Σ_i v_i·ρ^i`, the first and last 64 entries, every entry in the FULL corpus), and the Shieldstral T128 R13 shape's
`pad::indicator_table(Dom::L)`.

**How a table is built here: with this lane's own recipe, generic in the configuration.** `pubsRF c F rest` is
`pubsR13`'s body over a record `F` of the seventeen fields it reads, and **`pubsR13_pubsRF`** proves
`pubsR13 c Pb Lay B rest = pubsRF c (ofBR B) rest` by `rfl`, for EVERY `c` and `B`; `pubsRFast` replaces `foldTab` by
`foldTabR` (the same sum with the `eq` table computed once) and **`pubsRFast_eq`** proves it equal to `pubsRF`. Each
table compared is `pubsR13 cfgRungR13 Pb Lay B (restR13L cfgRungR13 exp act nG) s hist dr i` for every `B` whose fields
are the record `natF` built here, at the slot's own draws `dr` (slot 3's table does not read `exp`, `act`, `nG`:
`restR13L_three`). The record `natF c` reads the code's stored arrays at the NATURAL embedding of the logical axes into
the cubes of `c` (a token `t`, a width column `i`, a hidden channel `f`, a key-value group `g`, a head dimension `i` at
`msbIndex`; a head slot `s = 2^(lh − lkv)·g + j`), the code's padded positions as the code fills them. A pass shows
the recipe, the split maps, the configuration's widths and draw offsets and that embedding agree with the code's flat
tables; a failure is a finding about one of them. The Shieldstral `supp(Dom::L)` is compared with
`cubeTab (shShieldR13.logs .L) (gateLS shShieldR13)`, which IS `restR13L (cfgShieldR13 L)`'s slot-3 table at every
layer `L` (`(cfgShieldR13 L).sh = shShieldR13`, `rfl`).

It also checks, on the stored data, the pad facts `W16Pub` asks of any `B` at that embedding (`Wq_pad` … `Wd_pad`),
that the corpus's paddings are the configuration's (`t_pad = 2^lt`, …; `tokens = t_pad`, which `gateLS` reads), and
that every slot's count of tables and of public tables is the program's (`DefR13.progR13 cfgRungR13`).

With the argument `neg` it then runs the negative controls: one change to one entry of every table compared, and one
change to every public array (a weight of each matrix, a gain of each norm, a `cos` and a `sin` entry, a group id, a
folding multiplier, a head slot's truth, a draw of a fold, the token count), each of which must be caught. Not imported
by the library root (it defines `main`).
-/

namespace ZK60.Exec.Block.Join.R13H.Pub.Chk

open ZK60.Exec ZK60.Exec.Block ZK60.Exec.Block.Join.R13H ZK60.Exec.Block.Join.R13H.Pub
open ZK60.Exec.Block.Join.W16 (wordGF cubeTab drSeg foldTab wsumF)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Circuit (GF)

/-! ## `pubsR13`'s body over a record of its fields -/

/-- The seventeen fields of `W16Pub` that `pubsR13` reads, at the configuration `c`. -/
structure PubFR (c : W16Cfg) where
  gD : CtR c × CwR c → GF
  mask : (CgR c × CjR c) × CtR c × CtR c → GF
  Wq : CwR c → (CgR c × CjR c) × CdR c → GF
  Wk : CwR c → CgR c × CdR c → GF
  Wv : CwR c → CgR c × CdR c → GF
  Wo : (CgR c × CjR c) × CdR c → CwR c → GF
  Wg : CwR c → CfR c → GF
  Wu : CwR c → CfR c → GF
  Wd : CfR c → CwR c → GF
  gamA : CtR c × CwR c → GF
  gamM : CtR c × CwR c → GF
  cosT : CtR c × ((CgR c × CjR c) × CdR c) → GF
  sinT : CtR c × ((CgR c × CjR c) × CdR c) → GF
  cosK : CtR c × (CgR c × CdR c) → GF
  sinK : CtR c × (CgR c × CdR c) → GF
  grpCol : CtR c × CfR c → GF
  gF : CtR c × CfR c → GF

/-- A `W16Pub`'s fields. -/
def ofBR {c : W16Cfg} {S : ZK60.Block.BlockShape} {Pb : ZK60.Block.BlockPublic S}
    {Lay : ZK60.Layout.W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : ZK60.Layout.W16Pub S Pb Lay) :
    PubFR c :=
  ⟨B.gD, B.mask, B.Wq, B.Wk, B.Wv, B.Wo, B.Wg, B.Wu, B.Wd, B.gamA, B.gamM, B.cosT, B.sinT, B.cosK, B.sinK, B.grpCol,
    B.gF⟩

/-- **`pubsR13`'s body**, word for word, over the record. -/
def pubsRF (c : W16Cfg) (F : PubFR c) (rest : PubTabs) : PubTabs := fun s hist dr i =>
  if s = 0 ∨ s = 1 then (if i = 0 then cubeTab (nD c) (fun b => F.gD (splitD c b)) else [])
  else if s = 4 then (if i = 0 then cubeTab (nS c) (fun b => F.mask (splitS c b)) else [])
  else if s = 5 then
    (if i = 0 then foldTab c.sh.ld (nH c + c.sh.ldh) (fun w y => F.Wq w (splitHQ c y))
      (drSeg dr c.sh.lt (nH c + c.sh.ldh)) else [])
  else if s = 6 then
    (if i = 0 then foldTab c.sh.ld (c.sh.lkv + c.sh.ldh) (fun w y => F.Wk w (splitGD c y))
      (drSeg dr 0 (c.sh.lkv + c.sh.ldh)) else [])
  else if s = 7 then
    (if i = 0 then foldTab c.sh.ld (c.sh.lkv + c.sh.ldh) (fun w y => F.Wv w (splitGD c y))
      (drSeg dr 0 (c.sh.lkv + c.sh.ldh)) else [])
  else if s = 10 then
    (if i = 0 then foldTab (nH c + c.sh.ldh) c.sh.ld (fun q y => F.Wo (splitHQ c q) y) (drSeg dr c.sh.lt c.sh.ld)
      else [])
  else if s = 11 then
    (if i = 0 then foldTab c.sh.ld c.sh.lf (fun w y => F.Wg w y) (drSeg dr c.sh.lt c.sh.lf) else [])
  else if s = 12 then (if i = 0 then foldTab c.sh.ld c.sh.lf (fun w y => F.Wu w y) (drSeg dr 0 c.sh.lf) else [])
  else if s = 13 then
    (if i = 0 then foldTab c.sh.lf c.sh.ld (fun f y => F.Wd f y) (drSeg dr c.sh.lt c.sh.ld) else [])
  else if s = 14 then
    (if i = 0 then cubeTab (nD c) (fun b => F.gamA (splitD c b))
      else if i = 1 then cubeTab (nD c) (fun b => F.gamM (splitD c b))
      else if i = 2 then cubeTab (nD c) (fun b => F.gD (splitD c b)) else [])
  else if s = 15 then
    (if i = 0 then cubeTab (nQ c) (fun b => F.cosT (splitQ c b))
      else if i = 1 then cubeTab (nQ c) (fun b => F.sinT (splitQ c b)) else [])
  else if s = 16 then
    (if i = 0 then cubeTab (nK c) (fun b => F.cosK (splitK c b))
      else if i = 1 then cubeTab (nK c) (fun b => F.sinK (splitK c b)) else [])
  else if s = 17 then (if i = 0 then cubeTab (nS c) (fun b => F.mask (splitS c b)) else [])
  else if s = 18 then
    (if i = 0 then cubeTab (nF c) (fun b => F.grpCol (splitF c b))
      else if i = 1 then cubeTab (nF c) (fun b => F.gF (splitF c b)) else [])
  else rest s hist dr i

/-- **The tables compared ARE `pubsR13`'s**, for every configuration and every `B` (by `rfl`). -/
theorem pubsR13_pubsRF (c : W16Cfg) {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : ZK60.Layout.W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : ZK60.Layout.W16Pub S Pb Lay)
    (rest : PubTabs) : pubsR13 c Pb Lay B rest = pubsRF c (ofBR B) rest := rfl

/-- `foldTab` with its `eq` table computed once (the same sum). -/
def foldTabR (m n : ℕ) (W : (Fin m → Bool) → (Fin n → Bool) → GF) (r : List Fp2) : List Fp2 :=
  let e := (eqTableMsb r).toArray
  (List.range (2 ^ m)).map fun idx =>
    wsumF ((List.range (2 ^ n)).map fun j =>
      (e[j]?.getD Fp2.zero).mul (wordGF (W (msbBits m idx) (msbBits n j))))

theorem foldTabR_eq (m n : ℕ) (W : (Fin m → Bool) → (Fin n → Bool) → GF) (r : List Fp2) :
    foldTabR m n W r = foldTab m n W r := by
  unfold foldTabR foldTab
  simp only [List.getElem?_toArray, List.getD_eq_getElem?_getD]

/-- `pubsRF` with `foldTabR`. -/
def pubsRFast (c : W16Cfg) (F : PubFR c) (rest : PubTabs) : PubTabs := fun s hist dr i =>
  if s = 0 ∨ s = 1 then (if i = 0 then cubeTab (nD c) (fun b => F.gD (splitD c b)) else [])
  else if s = 4 then (if i = 0 then cubeTab (nS c) (fun b => F.mask (splitS c b)) else [])
  else if s = 5 then
    (if i = 0 then foldTabR c.sh.ld (nH c + c.sh.ldh) (fun w y => F.Wq w (splitHQ c y))
      (drSeg dr c.sh.lt (nH c + c.sh.ldh)) else [])
  else if s = 6 then
    (if i = 0 then foldTabR c.sh.ld (c.sh.lkv + c.sh.ldh) (fun w y => F.Wk w (splitGD c y))
      (drSeg dr 0 (c.sh.lkv + c.sh.ldh)) else [])
  else if s = 7 then
    (if i = 0 then foldTabR c.sh.ld (c.sh.lkv + c.sh.ldh) (fun w y => F.Wv w (splitGD c y))
      (drSeg dr 0 (c.sh.lkv + c.sh.ldh)) else [])
  else if s = 10 then
    (if i = 0 then foldTabR (nH c + c.sh.ldh) c.sh.ld (fun q y => F.Wo (splitHQ c q) y) (drSeg dr c.sh.lt c.sh.ld)
      else [])
  else if s = 11 then
    (if i = 0 then foldTabR c.sh.ld c.sh.lf (fun w y => F.Wg w y) (drSeg dr c.sh.lt c.sh.lf) else [])
  else if s = 12 then (if i = 0 then foldTabR c.sh.ld c.sh.lf (fun w y => F.Wu w y) (drSeg dr 0 c.sh.lf) else [])
  else if s = 13 then
    (if i = 0 then foldTabR c.sh.lf c.sh.ld (fun f y => F.Wd f y) (drSeg dr c.sh.lt c.sh.ld) else [])
  else if s = 14 then
    (if i = 0 then cubeTab (nD c) (fun b => F.gamA (splitD c b))
      else if i = 1 then cubeTab (nD c) (fun b => F.gamM (splitD c b))
      else if i = 2 then cubeTab (nD c) (fun b => F.gD (splitD c b)) else [])
  else if s = 15 then
    (if i = 0 then cubeTab (nQ c) (fun b => F.cosT (splitQ c b))
      else if i = 1 then cubeTab (nQ c) (fun b => F.sinT (splitQ c b)) else [])
  else if s = 16 then
    (if i = 0 then cubeTab (nK c) (fun b => F.cosK (splitK c b))
      else if i = 1 then cubeTab (nK c) (fun b => F.sinK (splitK c b)) else [])
  else if s = 17 then (if i = 0 then cubeTab (nS c) (fun b => F.mask (splitS c b)) else [])
  else if s = 18 then
    (if i = 0 then cubeTab (nF c) (fun b => F.grpCol (splitF c b))
      else if i = 1 then cubeTab (nF c) (fun b => F.gF (splitF c b)) else [])
  else rest s hist dr i

theorem pubsRFast_eq (c : W16Cfg) (F : PubFR c) (rest : PubTabs) : pubsRFast c F rest = pubsRF c F rest := by
  unfold pubsRFast pubsRF
  simp only [foldTabR_eq]

/-! ## Parsing -/

def parseCsvNat (s : String) : Option (List ℕ) := if s = "-" then some [] else (s.splitOn ",").mapM String.toNat?

def parseCsvInt (s : String) : Option (List ℤ) := if s = "-" then some [] else (s.splitOn ",").mapM String.toInt?

def f2 (a b : ℕ) : Fp2 := ⟨⟨UInt64.ofNat a⟩, ⟨UInt64.ofNat b⟩⟩

def pairUp : List ℕ → Option (List Fp2)
  | [] => some []
  | [_] => none
  | a :: b :: r => (pairUp r).map (f2 a b :: ·)

def pF2s (s : String) : Option (List Fp2) := parseCsvNat s >>= pairUp

def pF2 (s : String) : Option Fp2 :=
  match pF2s s with
  | some [x] => some x
  | _ => none

def w2 (x : Fp2) : String := s!"{x.c0.v.toNat},{x.c1.v.toNat}"

/-- **The fingerprint `Σ_i v_i·ρ^i`** in the code's word arithmetic (Horner from the last entry, as the export). -/
def fprint (v : List Fp2) (ρ : Fp2) : Fp2 := v.foldr (fun x acc => Fp2.add (Fp2.mul acc ρ) x) Fp2.zero

/-- One table's summary line (`PUB s i n FP … HEAD … TAIL …`, or `SHIELDL n FP …`). -/
structure PubRec where
  s : ℕ
  i : ℕ
  n : ℕ
  fp1 : Fp2
  fp2 : Fp2
  head : List Fp2
  tail : List Fp2

structure Corp where
  name : String := ""
  nSlots : ℕ := 0
  logCols : ℕ := 0
  rho1 : Fp2 := Fp2.zero
  rho2 : Fp2 := Fp2.zero
  shape : List ℕ := []
  lSize : ℕ := 0
  headSlot : Array ℕ := #[]
  trueSlot : Array ℕ := #[]
  gamA : Array ℤ := #[]
  gamM : Array ℤ := #[]
  ropeCos : Array ℤ := #[]
  ropeSin : Array ℤ := #[]
  groupIds : Array ℤ := #[]
  coef : List (String × Array ℤ) := []
  weight : List (String × Array ℤ) := []
  beta : Fp2 := Fp2.zero
  gamma : Fp2 := Fp2.zero
  alpha : Fp2 := Fp2.zero
  slots : List (ℕ × ℕ × ℕ) := []
  draws : List (ℕ × List Fp2) := []
  pubs : Array PubRec := #[]
  full : Array (ℕ × ℕ × Array Fp2) := #[]
  shieldShape : List String := []
  shieldL : Option PubRec := none
  shieldFull : Option (Array Fp2) := none
  done : Option (ℕ × ℕ) := none
  bad : List String := []

def Corp.err (c : Corp) (l : String) : Corp := { c with bad := c.bad ++ [s!"{l.take 160}"] }

def between (ws : List String) (a b : String) : List String :=
  ((ws.dropWhile (· != a)).drop 1).takeWhile (· != b)

/-- An array line `NAME n v0,v1,…`. -/
def arr (c : Corp) (l n vs : String) (k : Array ℤ → Corp) : Corp :=
  match n.toNat?, parseCsvInt vs with
  | some m, some v => if v.length = m then k v.toArray else c.err l
  | _, _ => c.err l

/-- A table's summary from its words after the key (`n FP a b HEAD … TAIL …`). -/
def sumRec (si ii : ℕ) (ws : List String) (n a b : String) : Option PubRec :=
  match n.toNat?, pF2 a, pF2 b, pF2s ((between ws "HEAD" "TAIL").headD ""), pF2s ((between ws "TAIL" "").headD "") with
  | some k, some x, some y, some h, some t => some ⟨si, ii, k, x, y, h, t⟩
  | _, _, _, _, _ => none

def parseLine (c : Corp) (l : String) : Corp :=
  let ws := (l.splitOn " ").filter (· ≠ "")
  match ws with
  | ["L49H", nm, ns, lc] =>
    match ns.toNat?, lc.toNat? with
    | some a, some b => { c with name := nm, nSlots := a, logCols := b }
    | _, _ => c.err l
  | ["RHO", a, b] =>
    match pF2 a, pF2 b with
    | some x, some y => { c with rho1 := x, rho2 := y }
    | _, _ => c.err l
  | "SHAPE" :: rest =>
    match rest.mapM String.toNat? with
    | some v => if v.length = 11 then { c with shape := v } else c.err l
    | none => c.err l
  | ["LSIZE", n] =>
    match n.toNat? with
    | some v => { c with lSize := v }
    | none => c.err l
  | ["HEADSLOT", v] =>
    match parseCsvNat v with
    | some x => { c with headSlot := x.toArray }
    | none => c.err l
  | ["TRUESLOT", v] =>
    match parseCsvNat v with
    | some x => { c with trueSlot := x.toArray }
    | none => c.err l
  | ["GAMA", n, vs] => arr c l n vs fun a => { c with gamA := a }
  | ["GAMM", n, vs] => arr c l n vs fun a => { c with gamM := a }
  | ["ROPECOS", n, vs] => arr c l n vs fun a => { c with ropeCos := a }
  | ["ROPESIN", n, vs] => arr c l n vs fun a => { c with ropeSin := a }
  | ["GROUPIDS", n, vs] => arr c l n vs fun a => { c with groupIds := a }
  | ["COEF", nm, n, vs] => arr c l n vs fun a => { c with coef := c.coef ++ [(nm, a)] }
  | ["WEIGHT", nm, n, vs] => arr c l n vs fun a => { c with weight := c.weight ++ [(nm, a)] }
  | ["LOGUP", a, b, g] =>
    match pF2 a, pF2 b, pF2 g with
    | some x, some y, some z => { c with beta := x, gamma := y, alpha := z }
    | _, _, _ => c.err l
  | ["SLOT", s, nt, np] =>
    match s.toNat?, nt.toNat?, np.toNat? with
    | some a, some b, some d => { c with slots := c.slots ++ [(a, b, d)] }
    | _, _, _ => c.err l
  | ["DRAWS", s, v] =>
    match s.toNat?, pF2s v with
    | some a, some d => { c with draws := c.draws ++ [(a, d)] }
    | _, _ => c.err l
  | "PUB" :: s :: i :: n :: "FP" :: a :: b :: _ =>
    match s.toNat?, i.toNat?, sumRec 0 0 ws n a b with
    | some si, some ii, some r => { c with pubs := c.pubs.push { r with s := si, i := ii } }
    | _, _, _ => c.err l
  | ["FULL", s, i, n, vs] =>
    match s.toNat?, i.toNat?, n.toNat?, pF2s vs with
    | some si, some ii, some k, some v =>
      if v.length = k then { c with full := c.full.push (si, ii, v.toArray) } else c.err l
    | _, _, _, _ => c.err l
  | "SHIELDSHAPE" :: rest => { c with shieldShape := rest }
  | "SHIELDL" :: n :: "FP" :: a :: b :: _ =>
    match sumRec 0 0 ws n a b with
    | some r => { c with shieldL := some r }
    | none => c.err l
  | ["FULLSHIELDL", n, vs] =>
    match n.toNat?, pF2s vs with
    | some k, some v => if v.length = k then { c with shieldFull := some v.toArray } else c.err l
    | _, _ => c.err l
  | ["DONE", a, b] =>
    match a.toNat?, b.toNat? with
    | some x, some y => { c with done := some (x, y) }
    | _, _ => c.err l
  | [] => c
  | _ => c.err l

/-! ## The record read off the code's stored data at the natural embedding of a configuration's cubes -/

def Corp.sh (c : Corp) (k : ℕ) : ℕ := c.shape.getD k 0
def Corp.tokens (c : Corp) : ℕ := c.sh 0
def Corp.width (c : Corp) : ℕ := c.sh 1
def Corp.hidden (c : Corp) : ℕ := c.sh 2
def Corp.qHeads (c : Corp) : ℕ := c.sh 3
def Corp.headDim (c : Corp) : ℕ := c.sh 4
def Corp.kvHeads (c : Corp) : ℕ := c.sh 5
def Corp.tPad (c : Corp) : ℕ := c.sh 6
def Corp.dPad (c : Corp) : ℕ := c.sh 7
def Corp.fPad (c : Corp) : ℕ := c.sh 8
def Corp.hPad (c : Corp) : ℕ := c.sh 9
def Corp.qPad (c : Corp) : ℕ := c.sh 10

def Corp.coefOf (c : Corp) (nm : String) : Array ℤ := ((c.coef.find? (·.1 == nm)).map (·.2)).getD #[]
def Corp.weightOf (c : Corp) (nm : String) : Array ℤ := ((c.weight.find? (·.1 == nm)).map (·.2)).getD #[]

/-- The index of a cube point (`eq_table_msb`'s order). -/
abbrev ix (n : ℕ) (b : Fin n → Bool) : ℕ := msbIndex n b

/-- A head slot from its group and its index in the group (`(g ++ j)`: the padded slots are the last of each group). -/
def slotOf (c : W16Cfg) (g : CgR c) (j : CjR c) : ℕ :=
  ix c.sh.lkv g * 2 ^ (c.sh.lh - c.sh.lkv) + ix (c.sh.lh - c.sh.lkv) j

def zint (a : Array ℤ) (k : ℕ) : GF := ((a.getD k 0 : ℤ) : GF)

/-- RoPE at `(t, i)` of a domain whose head index is live: `cos[t·half + i mod half]`, and `∓ sin` by the half. -/
def ropeC (k : Corp) (live : Bool) (t i : ℕ) : GF :=
  if live then zint k.ropeCos (t * (k.headDim / 2) + i % (k.headDim / 2)) else 0

def ropeS (k : Corp) (live : Bool) (t i : ℕ) : GF :=
  if live then
    (if i < k.headDim / 2 then -zint k.ropeSin (t * (k.headDim / 2) + i % (k.headDim / 2))
      else zint k.ropeSin (t * (k.headDim / 2) + i % (k.headDim / 2)))
  else 0

/-- **The record of the code's stored public data at the natural embedding of `c`'s cubes.** -/
def natF (c : W16Cfg) (k : Corp) : PubFR c where
  gD p := if ix c.sh.lt p.1 < k.tokens ∧ ix c.sh.ld p.2 < k.width then 1 else 0
  mask p := if ix c.sh.lt p.2.2 ≤ ix c.sh.lt p.2.1 then 1 else 0
  Wq x y := let row := slotOf c y.1.1 y.1.2 * k.headDim + ix c.sh.ldh y.2
    zint (k.weightOf "Q") (row * k.dPad + ix c.sh.ld x) * zint (k.coefOf "Q") row
  Wk x y := let row := ix c.sh.lkv y.1 * k.headDim + ix c.sh.ldh y.2
    zint (k.weightOf "K") (row * k.dPad + ix c.sh.ld x) * zint (k.coefOf "K") row
  Wv x y := let row := ix c.sh.lkv y.1 * k.headDim + ix c.sh.ldh y.2
    zint (k.weightOf "V") (row * k.dPad + ix c.sh.ld x) * zint (k.coefOf "V") row
  Wo x y := let col := slotOf c x.1.1 x.1.2 * k.headDim + ix c.sh.ldh x.2
    zint (k.weightOf "O") (ix c.sh.ld y * k.qPad + col) * zint (k.coefOf "O") (ix c.sh.ld y)
  Wg x f := zint (k.weightOf "G") (ix c.sh.ld x * k.fPad + ix c.sh.lf f) * zint (k.coefOf "G") (ix c.sh.lf f)
  Wu x f := zint (k.weightOf "U") (ix c.sh.ld x * k.fPad + ix c.sh.lf f) * zint (k.coefOf "U") (ix c.sh.lf f)
  Wd f y := zint (k.weightOf "D") (ix c.sh.lf f * k.dPad + ix c.sh.ld y) * zint (k.coefOf "D") (ix c.sh.ld y)
  gamA p := zint k.gamA (ix c.sh.ld p.2)
  gamM p := zint k.gamM (ix c.sh.ld p.2)
  cosT p := ropeC k (decide (ix c.sh.lt p.1 < k.tokens) && k.trueSlot.getD (slotOf c p.2.1.1 p.2.1.2) 0 == 1)
    (ix c.sh.lt p.1) (ix c.sh.ldh p.2.2)
  sinT p := ropeS k (decide (ix c.sh.lt p.1 < k.tokens) && k.trueSlot.getD (slotOf c p.2.1.1 p.2.1.2) 0 == 1)
    (ix c.sh.lt p.1) (ix c.sh.ldh p.2.2)
  cosK p := ropeC k (decide (ix c.sh.lt p.1 < k.tokens)) (ix c.sh.lt p.1) (ix c.sh.ldh p.2.2)
  sinK p := ropeS k (decide (ix c.sh.lt p.1 < k.tokens)) (ix c.sh.lt p.1) (ix c.sh.ldh p.2.2)
  grpCol p := if ix c.sh.lt p.1 < k.tokens ∧ ix c.sh.lf p.2 < k.hidden then zint k.groupIds (ix c.sh.lf p.2) else 0
  gF p := if ix c.sh.lt p.1 < k.tokens ∧ ix c.sh.lf p.2 < k.hidden then 1 else 0

/-- The configuration checked: the R13 rung. -/
abbrev cR : W16Cfg := DefR13.cfgRungR13

/-- The public tables compared: the host slots' and `SC_LZC`'s. -/
def keys : List (ℕ × ℕ) :=
  [(0, 0), (1, 0), (3, 0), (4, 0), (5, 0), (6, 0), (7, 0), (10, 0), (11, 0), (12, 0), (13, 0), (14, 0), (14, 1),
    (14, 2), (15, 0), (15, 1), (16, 0), (16, 1), (17, 0), (18, 0), (18, 1)]

def isFold (k : ℕ × ℕ) : Bool := [5, 6, 7, 10, 11, 12, 13].contains k.1

def histC (c : Corp) : Hist := ⟨c.beta, c.gamma, c.alpha, []⟩

def drawsOf (c : Corp) (s : ℕ) : List Fp2 := ((c.draws.find? (·.1 == s)).map (·.2)).getD []

structure LTab where
  key : ℕ × ℕ
  vals : Array Fp2
  fp1 : Fp2
  fp2 : Fp2

/-- One Lean table: `pubsR13 cR … (restR13L cR …)`'s (through `pubsRFast_eq`, `pubsR13_pubsRF`) at `natF` and the
slot's draws (slot 3's table reads none of `exp`, `act`, `nG`: `restR13L_three`). -/
def leanTab (k : Corp) (key : ℕ × ℕ) : LTab :=
  let v := pubsRFast cR (natF cR k) (restR13L cR (fun _ => 0) (fun _ _ => 0) 0) key.1 (histC k) (drawsOf k key.1) key.2
  ⟨key, v.toArray, fprint v k.rho1, fprint v k.rho2⟩

/-- The Shieldstral T128 R13 shape's `supp(Dom::L)`: `restR13L (cfgShieldR13 L)`'s slot-3 table at every layer. -/
def shieldTab (k : Corp) : LTab :=
  let v := cubeTab (ZK60.Exec.Slot.R13.shShieldR13.logs .L) (gateLS ZK60.Exec.Slot.R13.shShieldR13)
  ⟨(3, 0), v.toArray, fprint v k.rho1, fprint v k.rho2⟩

/-- The Shieldstral table compared IS `restR13L (cfgShieldR13 L)`'s slot-3 table, at every layer. -/
theorem shieldTab_eq (L : ZK60.RunShape.Shield.ShieldLayer) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) (hist : Hist)
    (dr : List Fp2) :
    restR13L (DefR13.cfgShieldR13 L) exp act nG 3 hist dr 0
      = cubeTab (ZK60.Exec.Slot.R13.shShieldR13.logs .L) (gateLS ZK60.Exec.Slot.R13.shShieldR13) := rfl

/-! ## The checks -/

structure St where
  ok : ℕ := 0
  fail : ℕ := 0
  skipped : ℕ := 0
  msgs : Array String := #[]
  kinds : List (String × ℕ) := []

def bump : List (String × ℕ) → String → List (String × ℕ)
  | [], k => [(k, 1)]
  | (k', n) :: rest, k => if k' = k then (k', n + 1) :: rest else (k', n) :: bump rest k

def St.check (s : St) (kind : String) (b : Bool) (msg : String) : St :=
  let s := { s with kinds := bump s.kinds kind }
  if b then { s with ok := s.ok + 1 }
  else { s with fail := s.fail + 1, msgs := if s.msgs.size < 60 then s.msgs.push s!"[{kind}] {msg.take 400}" else s.msgs }

def firstDiff (a b : Array Fp2) : Option ℕ :=
  if a.size ≠ b.size then some (min a.size b.size)
  else (List.range a.size).find? fun i => a.getD i Fp2.zero != b.getD i Fp2.zero

/-- Every entry of a stored weight matrix that reads a padded input is zero. -/
def padZero (a : Array ℤ) (rows cols : ℕ) (live : ℕ → ℕ → Bool) : Bool :=
  (List.range rows).all fun r => (List.range cols).all fun q => live r q || a.getD (r * cols + q) 0 == 0

def hasWeights (c : Corp) : Bool := c.weight.length == 7

/-- One table against its summary and (when present) its full entries. -/
def tabChecks (st : St) (tag : String) (r : PubRec) (full : Option (Array Fp2)) (t : LTab) : St := Id.run do
  let mut st := st
  st := st.check "length" (r.n == t.vals.size) s!"{tag}: code {r.n}, Lean {t.vals.size}"
  st := st.check "fingerprint" (r.fp1 == t.fp1) s!"{tag}: rho1 code {w2 r.fp1}, Lean {w2 t.fp1}"
  st := st.check "fingerprint" (r.fp2 == t.fp2) s!"{tag}: rho2 code {w2 r.fp2}, Lean {w2 t.fp2}"
  let e := min 64 t.vals.size
  st := st.check "ends" (r.head == (t.vals.toList.take e)) s!"{tag}: head"
  st := st.check "ends" (r.tail == (t.vals.toList.drop (t.vals.size - e))) s!"{tag}: tail"
  match full with
  | none => pure ()
  | some v =>
    match firstDiff v t.vals with
    | none => st := st.check "entries" true ""
    | some i =>
      st := st.check "entries" false
        s!"{tag}: first difference at {i}: code {w2 (v.getD i Fp2.zero)}, Lean {w2 (t.vals.getD i Fp2.zero)}"
  return st

def checkAll (c : Corp) (lt : List LTab) (sl : LTab) : St := Id.run do
  let mut st : St := {}
  let sh := cR.sh
  st := st.check "parse" c.bad.isEmpty s!"unparsed lines: {c.bad}"
  st := st.check "header" (c.nSlots == ZK60.Exec.Slot.W16R2.nSlots ∧ c.logCols == cR.logCols ∧ c.name == "R13_RUNG_H24")
    s!"{c.name}: slots {c.nSlots}, log_cols {c.logCols}"
  st := st.check "shape" (c.shape == [32, 384, 768, 16, 64, 8, 32, 512, 1024, 16, 1024]) s!"shape {c.shape}"
  -- the corpus's paddings are the configuration's widths, and the token axis does not pad (what `gateLS` reads)
  st := st.check "widths" (c.tPad == 2 ^ sh.lt ∧ c.dPad == 2 ^ sh.ld ∧ c.fPad == 2 ^ sh.lf ∧ c.hPad == 2 ^ sh.lh
      ∧ c.qPad == 2 ^ sh.lq ∧ c.headDim == 2 ^ sh.ldh ∧ c.kvHeads == 2 ^ sh.lkv ∧ c.tokens == c.tPad
      ∧ c.lSize == 2 ^ sh.logs .L)
    s!"shape {c.shape}, L size {c.lSize} against the configuration's widths"
  st := st.check "data" (c.gamA.size == c.dPad ∧ c.gamM.size == c.dPad ∧ c.groupIds.size == c.hidden
      ∧ c.ropeCos.size == c.tokens * (c.headDim / 2) ∧ c.ropeSin.size == c.tokens * (c.headDim / 2)
      ∧ c.trueSlot.size == c.hPad ∧ c.coef.length == 7)
    "the public arrays' lengths"
  -- every slot's count of tables and of public tables is the program's
  let prog := DefR13.progR13 cR 0 0
  for s in List.range c.nSlots do
    let sl := prog.getD s SlotS.empty
    let np := (sl.tabs.filter fun t => match t with | .pub _ => true | _ => false).length
    let code := (c.slots.find? fun q => q.1 == s).getD (0, 0, 0)
    st := st.check "slots" (code.2.1 == sl.tabs.length ∧ code.2.2 == np)
      s!"slot {s}: code {code.2.1} tables / {code.2.2} public, Lean {sl.tabs.length} / {np}"
  -- the pad facts `W16Pub` asks of the weights at the natural embedding
  if hasWeights c then
    let (w, d, f, q) := (c.width, c.dPad, c.fPad, c.qPad)
    st := st.check "pad" (padZero (c.weightOf "Q") q d fun _ col => decide (col < w)) "Wq_pad"
    st := st.check "pad" (padZero (c.weightOf "K") (c.kvHeads * c.headDim) d fun _ col => decide (col < w)) "Wk_pad"
    st := st.check "pad" (padZero (c.weightOf "V") (c.kvHeads * c.headDim) d fun _ col => decide (col < w)) "Wv_pad"
    st := st.check "pad" (padZero (c.weightOf "G") d f fun row _ => decide (row < w)) "Wg_pad"
    st := st.check "pad" (padZero (c.weightOf "U") d f fun row _ => decide (row < w)) "Wu_pad"
    st := st.check "pad" (padZero (c.weightOf "D") f d fun row _ => decide (row < c.hidden)) "Wd_pad"
    st := st.check "pad" (padZero (c.weightOf "O") d q fun _ col => c.trueSlot.getD (col / c.headDim) 0 == 1) "Wo_pad"
  -- the public tables
  st := st.check "tables" (c.pubs.size == keys.length) s!"public tables {c.pubs.size} vs {keys.length}"
  for t in lt do
    if isFold t.key && !hasWeights c then
      st := { st with skipped := st.skipped + 1 }
    else
      match c.pubs.find? (fun r => r.s == t.key.1 ∧ r.i == t.key.2) with
      | none => st := st.check "tables" false s!"slot {t.key.1} table {t.key.2}: not in the corpus"
      | some r =>
        let full := (c.full.find? (fun q => q.1 == t.key.1 ∧ q.2.1 == t.key.2)).map (·.2.2)
        st := tabChecks st s!"slot {t.key.1} table {t.key.2}" r full t
  -- the Shieldstral T128 R13 shape's `supp(Dom::L)`
  st := st.check "shield" (c.shieldShape.drop 1 == ["128", "128", "16384"]) s!"Shieldstral shape {c.shieldShape}"
  match c.shieldL with
  | none => st := st.check "shield" false "no Shieldstral supp(Dom::L) in the corpus"
  | some r => st := tabChecks st "Shieldstral supp(Dom::L)" r c.shieldFull sl
  st := st.check "done" (c.done.map (·.1) == some keys.length) s!"done {c.done}"
  return st

/-! ## The negative controls -/

def setFull (c : Corp) (s i idx : ℕ) : Corp :=
  { c with full := c.full.map fun r =>
      if r.1 == s ∧ r.2.1 == i then (r.1, r.2.1, r.2.2.modify idx (fun x => Fp2.add x Fp2.one)) else r }

def setPubFp (c : Corp) (s i : ℕ) : Corp :=
  { c with pubs := c.pubs.map fun r => if r.s == s ∧ r.i == i then { r with fp1 := Fp2.add r.fp1 Fp2.one } else r }

def modW (c : Corp) (nm : String) (k : ℕ) : Corp :=
  { c with weight := c.weight.map fun q => if q.1 == nm then (q.1, q.2.modify k (· + 1)) else q }

def modC (c : Corp) (nm : String) (k : ℕ) : Corp :=
  { c with coef := c.coef.map fun q => if q.1 == nm then (q.1, q.2.modify k (· + 1)) else q }

/-- One change: its name, the tables it concerns, whether the Lean side's inputs change (those tables recomputed),
the changed corpus. -/
def muts (c : Corp) : List (String × List (ℕ × ℕ) × Bool × Corp) :=
  let full := !c.full.isEmpty
  let tabMut (k : ℕ × ℕ) : Corp :=
    if full then setFull c k.1 k.2 (if isFold k then 7 else 1000) else setPubFp c k.1 k.2
  (keys.map fun k => (s!"the code's table {k}, one entry", [k], false, tabMut k))
  ++ [("the Shieldstral supp(Dom::L), one entry", [], false,
        match c.shieldFull with
        | some v => { c with shieldFull := some (v.modify 1000 (fun x => Fp2.add x Fp2.one)) }
        | none => { c with shieldL := c.shieldL.map fun r => { r with fp1 := Fp2.add r.fp1 Fp2.one } }),
      ("the Shieldstral supp(Dom::L), a head entry", [], false,
        { c with shieldL := c.shieldL.map fun r =>
            { r with head := r.head.mapIdx fun j x => if j = 3 then Fp2.add x Fp2.one else x } }),
      ("a weight of Wq (row 3, column 5)", [(5, 0)], true, modW c "Q" (3 * c.dPad + 5)),
      ("a weight of Wk (row 3, column 5)", [(6, 0)], true, modW c "K" (3 * c.dPad + 5)),
      ("a weight of Wv (row 3, column 5)", [(7, 0)], true, modW c "V" (3 * c.dPad + 5)),
      ("a weight of Wo (row 3, column 5)", [(10, 0)], true, modW c "O" (3 * c.qPad + 5)),
      ("a weight of Wg (input 5, output 3)", [(11, 0)], true, modW c "G" (5 * c.fPad + 3)),
      ("a weight of Wu (input 5, output 3)", [(12, 0)], true, modW c "U" (5 * c.fPad + 3)),
      ("a weight of Wd (input 5, output 3)", [(13, 0)], true, modW c "D" (5 * c.dPad + 3)),
      ("a folding multiplier of Q (row 10)", [(5, 0)], true, modC c "Q" 10),
      ("a folding multiplier of the gate (channel 10)", [(11, 0)], true, modC c "G" 10),
      ("gamma_a[5]", [(14, 0)], true, { c with gamA := c.gamA.modify 5 (· + 1) }),
      ("gamma_m[7]", [(14, 1)], true, { c with gamM := c.gamM.modify 7 (· + 1) }),
      ("rope_cos[3]", [(15, 0), (16, 0)], true, { c with ropeCos := c.ropeCos.modify 3 (· + 1) }),
      ("rope_sin[9]", [(15, 1), (16, 1)], true, { c with ropeSin := c.ropeSin.modify 9 (· + 1) }),
      ("a group id (channel 4)", [(18, 0)], true, { c with groupIds := c.groupIds.modify 4 (· + 1) }),
      ("head slot 1 not a true head", [(15, 0), (15, 1)], true, { c with trueSlot := c.trueSlot.set! 1 0 }),
      ("a draw of SC_QMM's fold (draw 7)", [(5, 0)], true,
        { c with draws := c.draws.map fun q => if q.1 == 5 then (q.1, q.2.modify 7 (fun x => Fp2.add x Fp2.one)) else q }),
      ("a draw of SC_WO's fold (draw 5, the first output draw)", [(10, 0)], true,
        { c with draws := c.draws.map fun q => if q.1 == 10 then (q.1, q.2.modify 5 (fun x => Fp2.add x Fp2.one)) else q }),
      ("one token fewer (tokens < t_pad)", [(0, 0), (1, 0), (14, 2), (18, 0), (18, 1)], true,
        { c with shape := c.shape.set 0 (c.tokens - 1) }),
      ("slot 3's count of public tables", [], false,
        { c with slots := c.slots.map fun q => if q.1 == 3 then (q.1, q.2.1, q.2.2 + 1) else q }),
      ("slot 14's count of public tables", [], false,
        { c with slots := c.slots.map fun q => if q.1 == 14 then (q.1, q.2.1, q.2.2 + 1) else q })]

def report (st : St) : IO Unit := do
  for (k, n) in st.kinds do
    IO.println s!"  {k}: {n}"
  for m in st.msgs do
    IO.println s!"  FAIL {m}"

end ZK60.Exec.Block.Join.R13H.Pub.Chk

open ZK60.Exec.Block.Join.R13H.Pub.Chk in
def main (args : List String) : IO UInt32 := do
  let path := args.headD ""
  let txt ← IO.FS.readFile path
  let c := (txt.splitOn "\n").foldl parseLine {}
  IO.println s!"corpus {path}: {c.name}, {c.pubs.size} tables, {c.full.size} in full, weights {hasWeights c}"
  let lt := keys.map fun k =>
    if isFold k && !hasWeights c then (⟨k, #[], ZK60.Exec.Fp2.zero, ZK60.Exec.Fp2.zero⟩ : LTab) else leanTab c k
  let sl := shieldTab c
  let st := checkAll c lt sl
  IO.println s!"checks: {st.ok} passed, {st.fail} failed, {st.skipped} fold tables skipped (no weights in this corpus)"
  report st
  let mut rc : UInt32 := if st.fail = 0 then 0 else 1
  if args.contains "neg" then
    let ms := (muts c).filter fun m => hasWeights c || !(m.2.1.any isFold)
    let mut caught := 0
    for (nm, ks, recompute, c') in ms do
      let lt' := lt.map fun t => if recompute && ks.contains t.key then leanTab c' t.key else t
      let st' := checkAll c' lt' sl
      if st'.fail > 0 then
        caught := caught + 1
        IO.println s!"negative control CAUGHT ({st'.fail} failed): {nm}"
      else
        IO.println s!"negative control MISSED: {nm}"
    IO.println s!"negative controls: {caught} of {ms.length} caught"
    if caught ≠ ms.length then rc := 1
  return rc
