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
import ZK60Formal.BlockHostBase
import ZK60Formal.BlockAlgR13
import ZK60Formal.BlockR13JoinForm
import ZK60Formal.BlockR13ProgOk

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

/-- The Shieldstral shape, by a short name. -/
abbrev shShieldR : ZK60.Exec.Slot.W16R2.ShapeW := ZK60.Exec.Slot.R13.shShieldR13

/-- **Every Shieldstral layer's geometry** (`7, 12, 3, 2, 7, 14`; two softmax limbs): the shape is the layer's own
and does not depend on its calibration. -/
theorem geoShield (L : ZK60.RunShape.Shield.ShieldLayer) : GeoR (DefR13.cfgShieldR13 L) 1 where
  logT := (by decide : shShieldR.logs .T = shShieldR.lt)
  logD := (by decide : shShieldR.logs .D = shShieldR.lt + shShieldR.ld)
  logQ := (by decide : shShieldR.logs .Q
    = shShieldR.lt + ((shShieldR.lkv + (shShieldR.lh - shShieldR.lkv)) + shShieldR.ldh))
  logK := (by decide : shShieldR.logs .Kv = shShieldR.lt + (shShieldR.lkv + shShieldR.ldh))
  logS := (by decide : shShieldR.logs .S
    = (shShieldR.lkv + (shShieldR.lh - shShieldR.lkv)) + (shShieldR.lt + shShieldR.lt))
  logHt := (by decide : shShieldR.logs .Ht = (shShieldR.lkv + (shShieldR.lh - shShieldR.lkv)) + shShieldR.lt)
  logF := (by decide : shShieldR.logs .F = shShieldR.lt + shShieldR.lf)
  lq := (by decide : shShieldR.lq = (shShieldR.lkv + (shShieldR.lh - shShieldR.lkv)) + shShieldR.ldh)
  lkvw := (by decide : shShieldR.lkvw = shShieldR.lkv + shShieldR.ldh)
  lkv_le := (by decide : shShieldR.lkv ≤ shShieldR.lh)
  lt_pos := (by decide : 0 < shShieldR.lt)
  ldh_pos := (by decide : 0 < shShieldR.ldh)
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
