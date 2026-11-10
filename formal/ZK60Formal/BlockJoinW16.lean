/-
D63 lane L41 (2026-11-10), part 4: **the W16R2 rung's extracted planes `xtE`, built from the committed `A` matrix**
(lane L35's "Not finished" item 2: `dt`, `xtE` from the planes).

The rung's padded axes are bit vectors (`shape.rs::natural_log`: every domain is a product of axes, most significant
first): tokens `5` bits, width `9`, key-value groups `3`, a head's index in its group `1`, head dimension `6`, hidden
`10`. A plane of domain `(t, i)` is read at the cube point `t ++ i` (`Fin.append`).

* `CtW`, `CwW`, `CgW`, `CjW`, `CdW`, `CfW`: the axes;
* `piB`: a base projection `K → GF` (`algebraMap`'s left inverse, `exists_base_proj`);
* `aPl off log b`: **the `A` plane at offset `off` of log size `log`**, read at the bit vector `b` (L41's `planeZ`, the
  claim functional at the Boolean point: the plane's entry);
* `offW`: the planes' offsets at the rung (`aOff cfgRungW16 q` for the plane ids of `idsW precRungW16`, **`offW_eq`**
  evaluated);
* **`xtW`**: the rung's `W16Data`, each field the base projection of its plane (the limb planes of the isqrt read
  on `Dom::L`'s `32`-entry sub-slices, as `SC_TZC` reads them);
* **`xtW_alg`**: every field is the `algebraMap` image of the committed plane's entry, i.e. the projection loses
  nothing (L41-1: the decoded `A` matrix is base-valued);
* `RungS S`: the integer model's shape constants are the rung's precision (`PREC` of `layout.txt`), a public-data
  fact.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockJoinHost
import ZK60Formal.BlockDefineW16Rung

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Circuit (gP GF)
open ZK60.Layout

/-! ## The axes -/

abbrev CtW : Type := Fin 5 → Bool
abbrev CwW : Type := Fin 9 → Bool
abbrev CgW : Type := Fin 3 → Bool
abbrev CjW : Type := Fin 1 → Bool
abbrev CdW : Type := Fin 6 → Bool
abbrev CfW : Type := Fin 10 → Bool

/-! ## A base projection -/

section Proj

variable {K : Type} [Field K] [Algebra GF K]

/-- **A base projection**: a `GF`-linear left inverse of `algebraMap GF K`. -/
noncomputable def piB (K : Type) [Field K] [Algebra GF K] : K →ₗ[GF] GF :=
  Classical.choose (exists_base_proj GF K)

theorem piB_alg (g : GF) : piB K (algebraMap GF K g) = g := Classical.choose_spec (exists_base_proj GF K) g

/-- On the base field's image, the projection loses nothing. -/
theorem alg_piB (v : K) (hv : v ∈ baseR K) : algebraMap GF K (piB K v) = v := by
  obtain ⟨g, rfl⟩ := hv
  rw [piB_alg]

end Proj

/-! ## The `A` planes -/

section Planes

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **The `A` plane at offset `off`, log size `log`, read at the bit vector `b`.** -/
noncomputable def aPl (P : BlockParams) (D : CmData K P) (off log : ℕ) (b : Fin log → Bool) : K :=
  planeZ U (rowLog P .a) (D.rows .a) (D.Q .a) (D.X .a) ⟨.a, [(off, Fp2.one)], log, [], 0, 0⟩ b

/-- **A plane of a base-valued `A` matrix is a base value.** -/
theorem aPl_base (P : BlockParams) (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (off log : ℕ)
    (b : Fin log → Bool) : aPl U P D off log b ∈ baseR K := by
  unfold aPl
  refine planeZ_base U _ _ _ _ hX ⟨.a, [(off, Fp2.one)], log, [], 0, 0⟩ (fun sc hsc => ?_) b
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hsc
  subst hsc
  rw [Fp2.toK_one]
  exact (baseR K).one_mem

/-- A private table of one `A` slice with coefficient `1` reads its plane: `planeZ` does not read the coordinates, the
reserved row or the extension round. -/
theorem planeZ_aPl (P : BlockParams) (D : CmData K P) (off log : ℕ) (cs : List Coord) (m er : ℕ)
    (b : Fin log → Bool) :
    planeZ U (rowLog P .a) (D.rows .a) (D.Q .a) (D.X .a) ⟨.a, [(off, Fp2.one)], log, cs, m, er⟩ b
      = aPl U P D off log b := rfl

end Planes

/-! ## The plane offsets at the rung -/

/-- The `A` plane ids at the rung, by name (`idsW precRungW16`). -/
def idsR : DefW16.IdsW := DefW16.idsW DefW16.precRungW16

/-- **The planes' first elements at the rung** (`a_off`), indexed by plane id `0 … 57`. -/
def offW (q : ℕ) : ℕ := DefW16.aOff DefW16.cfgRungW16 q

/-- The offsets evaluated: `T` planes `0 … 3` at `2^14·q`, `Ht` `4, 5`, `L` `6, 7`, `D` `8 … 26`, `Q` `27 … 32` (two
rows each), `Kv` `33 … 38`, `S` `39 … 48`, `F` `49 … 57` (two rows each). -/
theorem offW_eq : (List.range 58).map offW
    = [0, 16384, 32768, 49152, 65536, 81920, 98304, 114688, 131072, 147456, 163840, 180224, 196608, 212992, 229376,
       245760, 262144, 278528, 294912, 311296, 327680, 344064, 360448, 376832, 393216, 409600, 425984, 442368, 475136,
       507904, 540672, 573440, 606208, 638976, 655360, 671744, 688128, 704512, 720896, 737280, 753664, 770048, 786432,
       802816, 819200, 835584, 851968, 868352, 884736, 901120, 933888, 966656, 999424, 1032192, 1064960, 1097728,
       1130496, 1163264] := by
  decide +kernel

/-- The plane ids by name at the rung. -/
theorem idsR_eq : [idsR.d, idsR.dsq, idsR.dm, idsR.dsqm, idsR.mx, idsR.sum, idsR.limb, idsR.limbm, idsR.x, idsR.y,
    idsR.ao, idsR.x1, idsR.ym, idsR.z, idsR.x2, idsR.q, idsR.qr, idsR.o, idsR.k, idsR.v, idsR.kr, idsR.s, idsR.zsel,
    idsR.e, idsR.pp, idsR.g, idsR.a, idsR.u, idsR.h]
    = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 14, 17, 18, 23, 26, 27, 29, 31, 33, 35, 37, 39, 42, 43, 44, 49, 52, 53, 55] := by
  decide +kernel

theorem idsR_limbs : [idsR.nr, idsR.ns, idsR.ral, idsR.mr, idsR.ms, idsR.rdl, idsR.rql, idsR.rqrl, idsR.ro, idsR.rkl,
    idsR.rvl, idsR.rkrl, idsR.rsl, idsR.sr, idsR.sg, idsR.rgl, idsR.ru, idsR.ht, idsR.rh]
    = [[10, 11], [12, 13], [15, 16], [19, 20], [21, 22], [24, 25], [28], [30], [32], [34], [36], [38], [40, 41],
       [45, 46], [47, 48], [50, 51], [54], [56], [57]] := by
  decide +kernel

/-! ## The extracted planes -/

section Data

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)

/-- A plane of `Dom::T` (`5` bits) at offset `off`. -/
noncomputable def plT (off : ℕ) (t : CtW) : GF := piB K (aPl U P D off 5 t)

/-- A plane of `Dom::D` (`t ++ i`, `14` bits). -/
noncomputable def plD (off : ℕ) (x : CtW × CwW) : GF := piB K (aPl U P D off 14 (Fin.append x.1 x.2))

/-- A plane of `Dom::Q` (`t ++ (g ++ j) ++ c`, `15` bits). -/
noncomputable def plQ (off : ℕ) (x : CtW × ((CgW × CjW) × CdW)) : GF :=
  piB K (aPl U P D off 15 (Fin.append x.1 (Fin.append (Fin.append x.2.1.1 x.2.1.2) x.2.2)))

/-- A plane of `Dom::Kv` (`t ++ g ++ c`, `14` bits). -/
noncomputable def plK (off : ℕ) (x : CtW × (CgW × CdW)) : GF :=
  piB K (aPl U P D off 14 (Fin.append x.1 (Fin.append x.2.1 x.2.2)))

/-- A plane of `Dom::S` (`(g ++ j) ++ t ++ t'`, `14` bits). -/
noncomputable def plS (off : ℕ) (x : (CgW × CjW) × CtW × CtW) : GF :=
  piB K (aPl U P D off 14 (Fin.append (Fin.append x.1.1 x.1.2) (Fin.append x.2.1 x.2.2)))

/-- A plane of `Dom::Ht` (`(g ++ j) ++ t`, `9` bits). -/
noncomputable def plH (off : ℕ) (x : (CgW × CjW) × CtW) : GF :=
  piB K (aPl U P D off 9 (Fin.append (Fin.append x.1.1 x.1.2) x.2))

/-- A plane of `Dom::F` (`t ++ f`, `15` bits). -/
noncomputable def plF (off : ℕ) (x : CtW × CfW) : GF := piB K (aPl U P D off 15 (Fin.append x.1 x.2))

/-- An isqrt byte limb: sub-slice `3i + k` (`32` entries) of the limb plane at `off` on `Dom::L`. -/
noncomputable def plL (off : ℕ) (i k : Fin 3) (t : CtW) : GF :=
  piB K (aPl U P D (off + 32 * (3 * (i : ℕ) + k)) 5 t)

/-- A remainder of one or two 16-bit limb planes. -/
noncomputable def remR {C : Type} (pl : ℕ → C → GF) (qs : List ℕ) : RemP C :=
  ⟨pl (qs.getD 0 0), if 2 ≤ qs.length then pl (qs.getD 1 0) else fun _ => 0⟩

/-- **The W16R2 rung's extracted planes**, each field the base projection of its committed plane, at the plane's
offset `offW q` (`offW_eq`; the plane ids `q` by name in `idsR_eq`, `idsR_limbs`). -/
noncomputable def xtW : W16Data CtW CwW CgW CjW CdW CfW where
  dA := plT U P D 0
  dsqA := plT U P D 16384
  dM := plT U P D 32768
  dsqM := plT U P D 49152
  la := plL U P D 98304
  lm := plL U P D 114688
  X := plD U P D 131072
  Y := plD U P D 147456
  AO := plD U P D 229376
  X1 := plD U P D 278528
  YM := plD U P D 294912
  Z := plD U P D 376832
  X2 := plD U P D 425984
  nr := remR (plD U P D) [163840, 180224]
  ns := remR (plD U P D) [196608, 212992]
  mr := remR (plD U P D) [311296, 327680]
  ms := remR (plD U P D) [344064, 360448]
  rao := remR (plD U P D) [245760, 262144]
  rd := remR (plD U P D) [393216, 409600]
  Q := plQ U P D 442368
  QR := plQ U P D 507904
  O := plQ U P D 573440
  rq := remR (plQ U P D) [475136]
  rqr := remR (plQ U P D) [540672]
  ro := remR (plQ U P D) [606208]
  K := plK U P D 638976
  KR := plK U P D 704512
  V := plK U P D 671744
  rk := remR (plK U P D) [655360]
  rkr := remR (plK U P D) [720896]
  rv := remR (plK U P D) [688128]
  S8 := plS U P D 737280
  ZSEL := plS U P D 786432
  E := plS U P D 802816
  PP := plS U P D 819200
  rs := remR (plS U P D) [753664, 770048]
  sr := remR (plS U P D) [835584, 851968]
  sg := remR (plS U P D) [868352, 884736]
  MX := plH U P D 65536
  SUM := plH U P D 81920
  G := plF U P D 901120
  A := plF U P D 999424
  U := plF U P D 1032192
  H := plF U P D 1097728
  Htop := plF U P D 1130496
  rg := remR (plF U P D) [933888, 966656]
  ru := remR (plF U P D) [1064960]
  rh := remR (plF U P D) [1163264]

/-- **The projection loses nothing**: on a base-valued `A` matrix, `algebraMap` of a projected plane IS the plane. -/
theorem aPl_alg (hX : ∀ i t, D.X .a i t ∈ baseR K) (off log : ℕ) (b : Fin log → Bool) :
    algebraMap GF K (piB K (aPl U P D off log b)) = aPl U P D off log b :=
  alg_piB _ (aPl_base U P D hX off log b)

end Data

/-! ## The shape's constants at the rung -/

/-- **The integer model's shape constants are the rung's precision** (`layout.txt`, `W16R2_RUNG_H24`, `PREC`: the
`ceps`, the norm numerators, `tn`, and every requantization shift), and its stack is LowH24. A public-data fact. -/
structure RungS (S : ZK60.Block.BlockShape) : Prop where
  ceps : S.ceps = 1
  cnA : S.cnA = 4000
  cnM : S.cnM = 4000
  tn : S.tn = 2
  sq : S.sq = 15
  sk : S.sk = 15
  sv : S.sv = 16
  ss : S.ss = 18
  spv : S.spv = 12
  sao : S.sao = 21
  sgate : S.sgate = 19
  sup : S.sup = 12
  sprod : S.sprod = 16
  sdown : S.sdown = 20
  fp : S.fp = 12
  wrho : S.wrho = 17
  h24 : S.h24 = true

end ZK60.Exec.Block.Join.W16
