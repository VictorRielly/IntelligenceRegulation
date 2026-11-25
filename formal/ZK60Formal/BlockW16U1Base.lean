/-
D63 W16R2 Shieldstral port, Item (5c) (`BlockW16U1Base.lean`):
**the W16R2 Shieldstral (`export_u1`) block's extracted planes (`xtU1`), cube encodings (`encU1`,
`encHtU1`), algebra data (`dtU1`), `W16Spec` (`hspecU1`), precision bridge (`precR_shieldU1`),
and `block_knowledge_join_w16r2_shieldU1`.**

Reuses the configuration-generic axis types (`CtR .. CfR`), plane readers (`plT .. plF, plL`),
bit-vector splits (`splitD .. splitF, splitHQ, splitGD`), layout predicate (`LayR`), public-table
predicate/builder (`PubR`, `Pub.pubsR13`, `Pub.pubR_of`), and precision predicate (`PrecR`) from
`BlockR13HostBase.lean` / `BlockR13HostPub.lean`.

Because `export_u1` is A29-uniform (`RunShapeShieldU1.shieldExportU1_uniform`), all 26 layers
share the exact same shape `shShieldW16U1`, axis widths `(7, 12, 3, 2, 7, 14)` (definitionally
identical to `RunShieldBlkInst.shdP_bitLay`), 56 pre-Tab `A` planes (with 1-limb `sr = [45]`,
`sg = [46]` for `wrho = 16`), 44 `H` planes, and offsets `aOff`/`hOff`. Only `(cnA, cnM)` vary
across layers in `cfgShieldU1 cnA cnM`.

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.BlockDefineW16Shield
import ZK60Formal.BlockR13HostPub

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16U1

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl piB piB_alg alg_piB aPl_base aPl_alg remR)
open ZK60.Exec.Block.Join.R13H (CtR CwR CgR CjR CdR CfR nD nH nQ nK nS nHt nF
  plT plD plQ plK plS plH plF plL splitD splitHQ splitGD splitQ splitK splitHt splitS splitF
  splitD_append splitHQ_append splitGD_append splitQ_append splitK_append splitHt_append splitS_append splitF_append
  LayR gT_oneR gQ_oneR gK_oneR gS_oneR gHt_oneR PubR PrecR perRow_ne_zero numSlot_fields)
open ZK60.Exec.Block.DefW16 (W16Cfg precShieldU1 cfgShieldU1)
open ZK60.Exec.Slot.W16R2 (segLn segOff segSum Dom ShapeW shShieldW16U1)
open ZK60.RunShape.Shield (ShieldLayer shieldShape)
open ZK60.RunShape.ShieldU1 (shieldExportU1 shieldExportU1_uniform famsLogUpW16U1 famsOK_shieldU1 shieldU1_shapes_w16Widths)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open scoped ENNReal

/-! ## 1. Configuration aliases, axes, and offsets (uniform across all 26 `export_u1` layers) -/

/-- The A29-uniform `export_u1` configuration parameterized by per-layer `(cnA, cnM)`. -/
abbrev cfgU1 (cnA cnM : ℕ) : W16Cfg := cfgShieldU1 cnA cnM

/-- Reference configuration at `(0, 0)` (every shape, offset, and plane-ID fact is definitionally
identical for any `(cnA, cnM)`). -/
abbrev c0 : W16Cfg := cfgShieldU1 0 0

/-- The `export_u1` shape (`lt=7, ld=12, lkv=3, lh=5, ldh=7, lf=14, nRange=13`). -/
abbrev shU1 : ShapeW := shShieldW16U1

abbrev CtU1 : Type := CtR c0
abbrev CwU1 : Type := CwR c0
abbrev CgU1 : Type := CgR c0
abbrev CjU1 : Type := CjR c0
abbrev CdU1 : Type := CdR c0
abbrev CfU1 : Type := CfR c0

/-- An `A` plane's offset at `export_u1` (identical across all `(cnA, cnM)`). -/
abbrev offU1 (q : ℕ) : ℕ := DefW16.aOff c0 q

/-- An `H` plane's `(re, im)` offsets at `export_u1` (identical across all `(cnA, cnM)`). -/
abbrev hOffU1 (hp : ℕ) : ℕ × ℕ := DefW16.hOff c0 hp

theorem aOff_cfgU1 (cnA cnM q : ℕ) : DefW16.aOff (cfgU1 cnA cnM) q = offU1 q := rfl
theorem hOff_cfgU1 (cnA cnM hp : ℕ) : DefW16.hOff (cfgU1 cnA cnM) hp = hOffU1 hp := rfl
theorem aDataRows_cfgU1 (cnA cnM : ℕ) : DefW16.aDataRows (cfgU1 cnA cnM) = 2280 :=
  (DefW16.dataRows_shieldU1 cnA cnM).1
theorem hDataRows_cfgU1 (cnA cnM : ℕ) : DefW16.hDataRows (cfgU1 cnA cnM) = 2516 :=
  (DefW16.dataRows_shieldU1 cnA cnM).2
theorem logupSumW16_cfgU1 (cnA cnM : ℕ) : DefW16.logupSumW16 (cfgU1 cnA cnM) = DefW16.logupSumW16 c0 := rfl

/-- All 56 pre-Tab plane IDs of `idsW (precShieldU1 0 0)` verified by `decide`. -/
theorem xtU1_ids :
    let I := DefW16.idsW (precShieldU1 0 0)
    [I.d, I.dsq, I.dm, I.dsqm, I.mx, I.sum, I.limb, I.limbm,
      I.x, I.y, I.ao, I.x1, I.ym, I.z, I.x2,
      I.q, I.qr, I.o, I.k, I.v, I.kr,
      I.s, I.zsel, I.e, I.pp,
      I.g, I.a, I.u, I.h]
      = [0, 1, 2, 3, 4, 5, 6, 7,
         8, 9, 14, 17, 18, 23, 26,
         27, 29, 31, 33, 35, 37,
         39, 42, 43, 44,
         47, 50, 51, 53]
    ∧ [I.nr, I.ns, I.ral, I.mr, I.ms, I.rdl,
       I.rql, I.rqrl, I.ro, I.rkl, I.rvl, I.rkrl,
       I.rsl, I.sr, I.sg,
       I.rgl, I.ru, I.ht, I.rh]
      = [[10, 11], [12, 13], [15, 16], [19, 20], [21, 22], [24, 25],
         [28], [30], [32], [34], [36], [38],
         [40, 41], [45], [46],
         [48, 49], [52], [54], [55]]
    ∧ I.q0 = 27 ∧ I.k0 = 33 ∧ I.s0 = 39 ∧ I.f0 = 47 ∧ I.t0 = 56 := by
  decide

/-! ## 2. Extracted planes `xtU1` -/

section Planes

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)

/-- **The W16R2 Shieldstral (`export_u1`) extracted planes**: each field is the base projection of
its committed `A` plane at `offU1 q` (`idsW (precShieldU1 0 0)`). Note `sr = [45]` and `sg = [46]`
are single-limb remainders (`wrho = 16`). -/
noncomputable def xtU1 : W16Data CtU1 CwU1 CgU1 CjU1 CdU1 CfU1 where
  dA := plT U c0 P D (offU1 0)
  dsqA := plT U c0 P D (offU1 1)
  dM := plT U c0 P D (offU1 2)
  dsqM := plT U c0 P D (offU1 3)
  la := plL U c0 P D (offU1 6)
  lm := plL U c0 P D (offU1 7)
  X := plD U c0 P D (offU1 8)
  Y := plD U c0 P D (offU1 9)
  AO := plD U c0 P D (offU1 14)
  X1 := plD U c0 P D (offU1 17)
  YM := plD U c0 P D (offU1 18)
  Z := plD U c0 P D (offU1 23)
  X2 := plD U c0 P D (offU1 26)
  nr := remR (plD U c0 P D) [offU1 10, offU1 11]
  ns := remR (plD U c0 P D) [offU1 12, offU1 13]
  mr := remR (plD U c0 P D) [offU1 19, offU1 20]
  ms := remR (plD U c0 P D) [offU1 21, offU1 22]
  rao := remR (plD U c0 P D) [offU1 15, offU1 16]
  rd := remR (plD U c0 P D) [offU1 24, offU1 25]
  Q := plQ U c0 P D (offU1 27)
  QR := plQ U c0 P D (offU1 29)
  O := plQ U c0 P D (offU1 31)
  rq := remR (plQ U c0 P D) [offU1 28]
  rqr := remR (plQ U c0 P D) [offU1 30]
  ro := remR (plQ U c0 P D) [offU1 32]
  K := plK U c0 P D (offU1 33)
  KR := plK U c0 P D (offU1 37)
  V := plK U c0 P D (offU1 35)
  rk := remR (plK U c0 P D) [offU1 34]
  rkr := remR (plK U c0 P D) [offU1 38]
  rv := remR (plK U c0 P D) [offU1 36]
  S8 := plS U c0 P D (offU1 39)
  ZSEL := plS U c0 P D (offU1 42)
  E := plS U c0 P D (offU1 43)
  PP := plS U c0 P D (offU1 44)
  rs := remR (plS U c0 P D) [offU1 40, offU1 41]
  sr := remR (plS U c0 P D) [offU1 45]
  sg := remR (plS U c0 P D) [offU1 46]
  MX := plH U c0 P D (offU1 4)
  SUM := plH U c0 P D (offU1 5)
  G := plF U c0 P D (offU1 47)
  A := plF U c0 P D (offU1 50)
  U := plF U c0 P D (offU1 51)
  H := plF U c0 P D (offU1 53)
  Htop := plF U c0 P D (offU1 54)
  rg := remR (plF U c0 P D) [offU1 48, offU1 49]
  ru := remR (plF U c0 P D) [offU1 52]
  rh := remR (plF U c0 P D) [offU1 55]

end Planes

/-! ## 3. Cube encodings, pad counts, `algShapeU1`, `dtU1`, and `hspecU1` -/

/-- Host cube width in `W16R2.draws shU1 k`. -/
abbrev tauU1 (k : ℕ) : ℕ := segLn (ZK60.Exec.Slot.W16R2.draws shU1 k) .tau

/-- **The hosts' cube encodings at `export_u1`** (`tauU1` equals `7, 19, 19, 17, 19, 21`
definitionally on `2, 14, 15, 16, 17, 18`). -/
def encU1 : (k : ℕ) → (Fin (tauU1 k) → Bool) → W16Pos CtU1 CwU1 CgU1 CjU1 CdU1 CfU1
  | 2, b => .t b
  | 14, b => .d (splitD c0 b)
  | 15, b => .q (splitQ c0 b)
  | 16, b => .kv (splitK c0 b)
  | 17, b => .s (splitS c0 b)
  | 18, b => .f (splitF c0 b)
  | _, _ => .t (fun _ => false)

/-- **`Dom::Ht`'s cube encoding at `export_u1`** (`nHt c0 = 12`). -/
def encHtU1 (b : Fin 12 → Bool) : W16Pos CtU1 CwU1 CgU1 CjU1 CdU1 CfU1 := .ht (splitHt c0 b)

/-- **The hosts' pad plane counts at `export_u1`**: `Dom::D` has 19 zero-rule planes (`SC_DZC`),
`Dom::F` has 9 (`SC_FZC`); the other host domains do not pad. -/
def mpadU1 (k : ℕ) : ℕ := if k = 14 then 19 else if k = 18 then 9 else 0

theorem mpadU1_zeroPl : [mpadU1 14, mpadU1 18]
    = [(DefW16.zeroPl c0 .D).length, (DefW16.zeroPl c0 .F).length]
      ∧ DefW16.zeroPl c0 .T = [] ∧ DefW16.zeroPl c0 .Q = []
      ∧ DefW16.zeroPl c0 .Kv = [] ∧ DefW16.zeroPl c0 .S = []
      ∧ DefW16.zeroPl c0 .Ht = [] := by
  decide +kernel

theorem mpadU1_hm0 : ∀ k ∈ algHosts, segLn (ZK60.Exec.Slot.W16R2.draws shU1 k) .zeta = 0 → mpadU1 k = 0 := by
  decide

theorem mpadU1_hm78 : ∀ k ∈ algHosts, mpadU1 k ≤ 78 := by decide

/-- **The W16R2 Shieldstral (`export_u1`) shape facts** (`lt = 7`, `lh = 5`, `lq = 12`, `lf = 14`,
`Dom::Ht` 12, `Dom::S` 12 + 7). -/
def algShapeU1 (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws) : AlgShape P :=
  algShapeStd P (ZK60.Exec.Slot.W16R2.draws shU1) mpadU1 7 5 12 14 12 7
    (by rw [hdr]; decide) (hostLay_w16 shU1) mpadU1_hm0 mpadU1_hm78
    (by rw [hdr]; decide) (by rw [hdr]; decide) (by rw [hdr]; decide)
    (by rw [hdr]; decide) (by rw [hdr]; decide) (by rw [hdr]; decide) (by rw [hdr]; decide) (by rw [hdr]; decide)
    (by rw [hdr]; decide) (by decide)

theorem relCount_room_u1 : ∀ k ∈ algHosts,
    relCount k ≤ segLn (ZK60.Exec.Slot.W16R2.draws shU1 k) .mu
      - segLn (ZK60.Exec.Slot.W16R2.draws shU1 k) .zeta := by
  decide

section Dt

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
  (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws)
  (E : Cuts3 L → RootsO → W16Data CtU1 CwU1 CgU1 CjU1 CdU1 CfU1)

/-- **The algebra data at `export_u1`**: named `W16Rels` tables of `E` through `encU1`/`encHtU1`,
helper/extra entries `xc`, pad planes `pwc`, and `rsScale = 128` (`per_row = 2^7`). -/
noncomputable def dtU1
    (xc : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → ℕ → (Fin (tauU1 k) → Bool) → K)
    (pwc : (k : ℕ) → Cuts3 L → RootsO → Fin (mpadU1 k) → (Fin (tauU1 k) → Bool) → K) :
    AlgData K L (algShapeU1 P hdr) where
  cl k cu rt bga κ b :=
    if (κ : ℕ) < relCount k then algebraMap GF K (relCl Pb Lay B (E cu rt) k κ (encU1 k b))
    else xc k cu rt bga κ b
  pw k cu rt j b := pwc k cu rt j b
  gh k cu rt i b := algebraMap GF K (relGh Pb Lay B (E cu rt) k i (encU1 k b))
  mm k cu rt i b := algebraMap GF K (relMm Pb Lay B (E cu rt) k i (encU1 k b))
  rsA cu rt b := algebraMap GF K (relRsA Pb Lay B (E cu rt) (encHtU1 b))
  rsB cu rt b := algebraMap GF K (relRsB Pb Lay B (E cu rt) (encHtU1 b))
  rsScale := (128 : K)
  hsc := perRow_ne_zero 128 (by norm_num [gP]) (by norm_num)

/-- **`W16Spec` for `dtU1`, `encU1`, `encHtU1`**, for every choice of `xc` and `pwc`. -/
theorem hspecU1
    (xc : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → ℕ → (Fin (tauU1 k) → Bool) → K)
    (pwc : (k : ℕ) → Cuts3 L → RootsO → Fin (mpadU1 k) → (Fin (tauU1 k) → Bool) → K) :
    W16Spec (algShapeU1 P hdr) (dtU1 Pb Lay B P hdr E xc pwc) Pb Lay B E encU1 encHtU1 where
  cl k hk j hj := by
    refine ⟨⟨j, lt_of_lt_of_le hj (relCount_room_u1 k hk)⟩, fun cu rt bga b => ?_⟩
    show (if j < relCount k then _ else _) = _
    rw [ite_eq_left hj]
  gh _ _ _ _ _ _ _ := rfl
  mm _ _ _ _ _ _ _ := rfl
  rsA _ _ _ := rfl
  rsB _ _ _ := rfl
  st x := ⟨x, rfl⟩
  sd x := ⟨Fin.append x.1 x.2, by show W16Pos.d (splitD c0 _) = _; rw [splitD_append]⟩
  sq x := ⟨Fin.append x.1 (Fin.append (Fin.append x.2.1.1 x.2.1.2) x.2.2),
    by show W16Pos.q (splitQ c0 _) = _; rw [splitQ_append]⟩
  sk x := ⟨Fin.append x.1 (Fin.append x.2.1 x.2.2), by show W16Pos.kv (splitK c0 _) = _; rw [splitK_append]⟩
  ss x := ⟨Fin.append (Fin.append x.1.1 x.1.2) (Fin.append x.2.1 x.2.2),
    by show W16Pos.s (splitS c0 _) = _; rw [splitS_append]⟩
  sf x := ⟨Fin.append x.1 x.2, by show W16Pos.f (splitF c0 _) = _; rw [splitF_append]⟩
  sht x := ⟨Fin.append (Fin.append x.1.1 x.1.2) x.2, by show W16Pos.ht (splitHt c0 _) = _; rw [splitHt_append]⟩

end Dt

/-! ## 4. Precision bridge, base-valued `A` matrix, and slot numbering -/

/-- **Every `export_u1` layer's `shieldShape Ly` satisfies `PrecR (cfgU1 Ly.cnA Ly.cnM)`.** -/
theorem precR_shieldU1 (Ly : ShieldLayer) (hLy : Ly ∈ shieldExportU1) :
    PrecR (cfgU1 Ly.cnA Ly.cnM) (shieldShape Ly) := by
  obtain ⟨hao, hs, hz, hgate, -⟩ := shieldExportU1_uniform Ly hLy
  exact ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl,
    by show Ly.s + 12 = 19; omega,
    rfl,
    by show Ly.ao + 14 = 21; omega,
    by show Ly.gate = 20; exact hgate,
    rfl, rfl,
    by show Ly.z + 14 = 22; omega,
    rfl, rfl, rfl, rfl, rfl⟩

/-- **The W16R2 Shieldstral committed `A` matrix is base-valued** at `(15, 280, 8052, 2504, 2606)`. -/
theorem dXof_base_w16U1 {K : Type} [Field K] [Algebra GF K] {L : ℕ} (tag : MTag) (hL20 : 2 ^ 20 ≤ L)
    (P : BlockParams) (hlc : P.logCols = 14) (rE QE : Cm → ℕ)
    (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (cu : Cuts3 L) (rt : RootsO) :
    ∀ i t, (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt).X .a i t ∈ baseR K := by
  intro i t
  obtain ⟨g, hg⟩ := xAof_base_w16 (K := K) tag L (Link.le64_of_le20 hL20) 2504 cu rt i (colCast P hlc 280 t)
  exact ⟨g, hg.symm⟩

/-- **Slot `k` of `progW16 c ioIn ioOut`, numbered**: equals `rawSlot c k` numbered from some
claim sites `(ak, hk')` (cube evaluation never reads the reserved mask rows). -/
theorem progW16_slot (c : W16Cfg) (ioIn ioOut k : ℕ) (hk : k < 23) : ∃ ak hk',
    (DefW16.progW16 c ioIn ioOut).getD k SlotS.empty
      = DefW16.numSlot (DefW16.aDataRows c) (DefW16.hDataRows c) ioIn ioOut ak hk' (DefW16.rawSlot c k) := by
  have hlen : k < (DefW16.rawProg c).length := by
    unfold DefW16.rawProg
    rw [List.length_map, List.length_range]
    exact hk
  obtain ⟨a, h, e⟩ := R13T.numProg_getD (DefW16.aDataRows c) (DefW16.hDataRows c) ioIn ioOut (DefW16.rawProg c) k 0 0 hlen
  refine ⟨a, h, ?_⟩
  show (DefW16.numProg (DefW16.aDataRows c) (DefW16.hDataRows c) ioIn ioOut 0 0 (DefW16.rawProg c)).getD k
    SlotS.empty = _
  rw [e]
  congr 1
  unfold DefW16.rawProg
  rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range hk]
  rfl

/-- Helper: `remVal` for width `≤ 16` is the low limb alone (`wrho = 16`!). -/
theorem remVal_le16 (b : ℕ) (hb : b ≤ 16) (lo hi : GF) : remVal b lo hi = lo := by
  unfold remVal
  exact ite_eq_left hb

/-- A single-limb remainder's plane. -/
theorem remR_lo1 {C : Type} (pl : ℕ → C → GF) (a : ℕ) (x : C) : (remR pl [a]).lo x = pl a x := rfl

/-! ## 5. Joined single-block statement at `export_u1` (`xtU1`, `algShapeU1`, `dtU1`, `hspecU1`) -/

section JoinStmt

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **One W16R2 Shieldstral (`export_u1`) block's knowledge statement with extraction `xtU1`,
`algShapeU1`, `dtU1`, `hspecU1`, and `famsLogUpW16U1` wired in**, for any layer `Ly ∈ shieldExportU1`. -/
theorem block_knowledge_join_w16r2_shieldU1 [Fintype K] [DecidableEq K] (Ly : ShieldLayer)
    (hLy : Ly ∈ shieldExportU1) (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hK2 : Module.finrank GF K = 2)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsShieldW16 P tag rowsOf)
    (ioIn ioOut : ℕ) (pubs : PubTabs)
    (hdef : P.define = defineS (DefW16.progW16 (cfgU1 Ly.cnA Ly.cnM) ioIn ioOut) pubs)
    (hlc : P.logCols = 14) (hep : 0 < P.endpointLogN)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (hcsE : ∀ (cu : Cuts3 L) (rt : RootsO) (cm : Cm) (z : ZClaim), (cm = .inp ∨ cm = .out) →
      csE cu rt cm z = Link.claimSem U (rE cm) (rowLog P cm) (QE cm) (XE cu rt cm) z)
    (Pb : ZK60.Block.BlockPublic (shieldShape Ly))
    (Lay : W16Layout (shieldShape Ly) CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub (shieldShape Ly) Pb Lay)
    (hLay : LayR Lay)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csShieldW16 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    -- the six hosts' extra batch entries, pad planes, and FormAt
    (xc : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → ℕ → (Fin (tauU1 k) → Bool) → K)
    (pwc : (k : ℕ) → Cuts3 L → RootsO → Fin (mpadU1 k) → (Fin (tauU1 k) → Bool) → K)
    (hform : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen
      (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
        (DefW16.progW16 (cfgU1 Ly.cnA Ly.cnM) ioIn ioOut) pubs))
      (Link.csShieldW16 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ algHosts, FormAt U P
        ((polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
          (DefW16.progW16 (cfgU1 Ly.cnA Ly.cnM) ioIn ioOut) pubs)
          (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (algSp U (algShapeU1 P hP.hdr)
          (dtU1 Pb Lay B P hP.hdr (fun cu rt => xtU1 U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt))
            xc pwc)
          (card_K_gt K) 0 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ)
        bga rs k)
    -- the helper layer and LogUp
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hformH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen
      (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
        (DefW16.progW16 (cfgU1 Ly.cnA Ly.cnM) ioIn ioOut) pubs))
      (Link.csShieldW16 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ w16r2RelKs 0, FormAt U P
        ((polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
          (DefW16.progW16 (cfgU1 Ly.cnA Ly.cnM) ioIn ioOut) pubs)
          (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (spH (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ) bga rs k)
    (hgdH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen
      (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
        (DefW16.progW16 (cfgU1 Ly.cnA Ly.cnM) ioIn ioOut) pubs))
      (Link.csShieldW16 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      SchedGd (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 2 ^ 26)
    (hTtab : ∀ j, ∃ t0, ZK60.Circuit.CodeTable famsLogUpW16U1 Pb.exp Pb.act (shieldShape Ly).nG t0 ∧ T j = tupK t0)
    (hcov : ∀ G q, W16Query Pb Lay B (xtU1 U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))) q →
      ∃ l, Alk (cutsOf key domain hs hL A G).1 l = tupK q)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen
      (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
        (DefW16.progW16 (cfgU1 Ly.cnA Ly.cnM) ioIn ioOut) pubs))
      (Link.csShieldW16 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtU1 U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2))).X (Lay.dPos p))
          (fun p => (xtU1 U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2))).X2 (Lay.dPos p))
          (toWit Lay (xtU1 U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2)))))
      ≤ εsTarget q + εend :=
  block_knowledge_define_alg_w16r2_shieldU1 U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP
    Ly.cnA Ly.cnM ioIn ioOut pubs hdef hlc hep hdrLen hdrSq hh hq csE rE QE XE hcsE
    Pb Lay B famsLogUpW16U1 famsOK_shieldU1 (shieldU1_shapes_w16Widths Ly hLy) rfl
    (fun cu rt => xtU1 U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt))
    q A hA εend hEnd
    (algShapeU1 P hP.hdr)
    (dtU1 Pb Lay B P hP.hdr (fun cu rt => xtU1 U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt))
      xc pwc)
    hform encU1 encHtU1
    (hspecU1 Pb Lay B P hP.hdr (fun cu rt => xtU1 U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt))
      xc pwc)
    hLay.tok hLay.hd HGd spH hdgH hformH hgdH Alk T mlk hN he hTtab hcov hhr

end JoinStmt

end ZK60.Exec.Block.Join.W16U1
