/-
D63 lane L40 (2026-11-10), part 2: **the media app's real classifier IS an instance of the per-block-shape run model**
(the evidence the gap audit's GB-2 asks for).

The data (CHECKED by `results/zk60_lean_l40_20261110/l40_shield_export.py` against the app's own verifier export,
`results/zk60_shieldstral_export_20261026/native_low_h24_t128-verifier`, whose `profile.json` hashes to the app's
`PROFILE_SHA`; every layer manifest and table file hash-pinned):
* the geometry (shape.rs:229, `R13_SHIELD_T128_H24`): `T = 128`, `d = 3072`, 32 query heads of 128 (`half = 64`) over 8
  key-value heads (head `h` reads key-value head `h / 4`, witness_accuracy.rs:717), hidden `f = 9216`;
* the profile constants: `f_e = 9`, so `wrho_s = clog2(128) + 9 = 16`; `f_p = 12`; `norm_ceps = 2439`; `norm_tn = 9`, so
  the accuracy stack's `tn = 9 − 8 = 1` (accuracy_precision.rs:69); `sh_qkv 8`, `sh_o 9`, `sh_g 8`, `sh_u 0`; LowH24;
* per layer (`shieldExport`): `sh_ao`, `sh_s`, `sh_h`, `sh_z`, the gate fold's common shift (accuracy_groups.rs:48-50),
  the two norm constants `cn_a`, `cn_m`, and the ACT group count.
A block's shifts are `accuracy_precision::derive`'s (L17's `derive`): `q = k = 15`, `v = 16`, `score = sh_s + 12`,
`pv = 12`, `ao = sh_ao + 14`, `up = 12`, `down = sh_z + 14`, `f_p = 12`, `tn = 1`; the gate's is the fold's; the product's
is the aligned scaling's `16` at LowH24 (accuracy_aligned.rs:27).

What is proved (only `propext`, `Classical.choice`, `Quot.sound`; the list facts by `decide`):
* `shieldExport_l17`: the export's shifts and gates are L17's `shieldLayers` (A25's census), entry for entry;
* `shield_derive`: every layer's base calibration passes `derive` at LowH24 with exactly the shifts the shape uses;
* **`shield_shapes_valid`**: all 26 layer shapes are `BlockShape.Valid`; **`shield_shapes_r13`**: all 26 meet
  `R13Windows … 1` (two softmax limbs, the code's `limbs_sigma_s = ⌈16/8⌉`), the hypothesis of L17's
  `blockSat_of_slots_r13`; `shield_not_r13Windows2` (finding L40-2: `R13Windows … 2`, which L17's docstring names, fails);
* `shield_cals_distinct`: the 26 calibrations are pairwise distinct (26 distinct, not only the 17 shift sets: the norm
  constants differ in every layer); **`shield_not_one_shape`**: no single `BlockShape` is the shape of all 26 blocks,
  so the app's model is not L2's one-shape `classifyModel S R` for any `S` (GB-2, PROVED);
* `ShieldRun`, **`shieldRun_valid`**: a per-block run whose 26 blocks carry the export's calibrations in order is
  `Valid` given only stage IN-C's, stage OUT-C's and the blocks' PUBLIC DATA classes;
* **`shield_circuitIff`**: `CircuitIff` for the app's classifier model with those premises; **`shield_circuitIff_policy`**:
  with stage IN-C's data L15's registered category policy and stage OUT-C's data in L15's checked classes, the only
  premises left are every block's `BlockPublic.Valid` and the embedding's int16 class;
* **`shield_run_exists`**: a run with the real 26 shapes whose every premise holds (zero public data): the premises
  above are satisfiable at the real shapes.

What is NOT proved here, by name: `hpub` (each block's `BlockPublic.Valid`). Its non-weight half (gains, multipliers,
the folded gate multipliers, RoPE, exp, the scaled ACT words, the group ids) is CHECKED on the real export by
`l40_shield_export.py` (log `l40_shield_export.log`); its weight half (`wq … wd` symmetric int8) cannot be checked here:
the weights are pinned by hash in the export's manifests but not in the repository (D62).
-/
import ZK60Formal.RunShape
import ZK60Formal.ShapeR13
import ZK60Formal.StageCheckValid

set_option autoImplicit false

namespace ZK60.RunShape.Shield

open ZK60 ZK60.Model ZK60.Circuit ZK60.Block ZK60.Out ZK60.TokenRun ZK60.RunShape
open ZK60.Layout.R13 (R13Windows)
open ZK60.Layout.R13.Shape (Base Prec derive shieldLayers shieldBase)

/-! ## The export's per-layer calibrations -/

/-- One layer's calibration as the app's verifier export carries it: `sh_ao`, `sh_s`, `sh_h`, `sh_z`, the gate fold's
common shift, the norm constants `cn_a`, `cn_m` (all positive in the export), and the number of ACT groups. -/
structure ShieldLayer where
  ao : ℕ
  s : ℕ
  h : ℕ
  z : ℕ
  gate : ℕ
  cnA : ℕ
  cnM : ℕ
  nG : ℕ
  deriving DecidableEq, Repr

/-- **The app's Shieldstral-1.0-3B T128 export, layers 0 to 25** (CHECKED against the export's manifests by
`l40_shield_export.py`). -/
def shieldExport : List ShieldLayer :=
  [⟨8, 7, 16, 8, 19, 848, 1716, 3⟩, ⟨8, 8, 14, 8, 19, 2600, 1471, 3⟩, ⟨8, 8, 16, 6, 18, 2727, 1196, 4⟩,
    ⟨8, 8, 15, 8, 20, 2899, 1448, 3⟩, ⟨8, 6, 15, 8, 20, 2304, 1289, 3⟩, ⟨8, 7, 15, 8, 20, 2277, 1539, 3⟩,
    ⟨7, 7, 15, 8, 20, 2190, 1370, 3⟩, ⟨8, 6, 15, 8, 20, 2212, 1424, 3⟩, ⟨8, 6, 15, 8, 20, 2248, 1479, 3⟩,
    ⟨7, 7, 14, 8, 20, 2267, 1302, 4⟩, ⟨7, 6, 16, 8, 19, 2218, 1539, 3⟩, ⟨7, 7, 15, 8, 20, 2233, 1533, 4⟩,
    ⟨7, 6, 14, 8, 20, 2208, 1246, 4⟩, ⟨7, 7, 13, 8, 20, 2185, 999, 4⟩, ⟨7, 7, 13, 8, 19, 2118, 1052, 3⟩,
    ⟨7, 7, 13, 8, 20, 2015, 1182, 4⟩, ⟨6, 6, 14, 8, 20, 2174, 1481, 4⟩, ⟨7, 7, 14, 8, 20, 2430, 1435, 4⟩,
    ⟨6, 7, 15, 8, 20, 2448, 1607, 4⟩, ⟨7, 7, 15, 8, 20, 2599, 1835, 4⟩, ⟨6, 7, 16, 8, 20, 2273, 1926, 4⟩,
    ⟨7, 7, 14, 8, 20, 2343, 2091, 3⟩, ⟨6, 7, 15, 8, 20, 2753, 2455, 3⟩, ⟨7, 8, 16, 8, 19, 3854, 2062, 4⟩,
    ⟨7, 8, 15, 8, 19, 4532, 2467, 4⟩, ⟨7, 8, 15, 5, 19, 3047, 3106, 4⟩]

/-- The export's shifts and gates are L17's `shieldLayers` (A25's census), entry for entry. -/
theorem shieldExport_l17 : shieldExport.length = 26 ∧
    shieldExport.map (fun c => (c.ao, c.s, c.h, c.z, c.gate)) = shieldLayers := by
  decide

/-! ## A layer's block shape -/

/-- Shieldstral-1.0-3B's key-value group of a query head: 32 query heads over 8 key-value heads, head `h` reads
key-value head `h / 4` (witness_accuracy.rs:717, `kv = h / g.group`). -/
def shieldGrp (h : Fin 32) : Fin 8 := ⟨h.val / 4, by omega⟩

/-- **A layer's calibration** at Shieldstral T128's geometry and profile constants: the shifts `derive` gives at
LowH24, the gate fold's shift, the aligned product shift `16`, the layer's norm constants and ACT group count. -/
def shieldCal (c : ShieldLayer) : BlockCal where
  H := 32
  G := 8
  half := 64
  f := 9216
  grp := shieldGrp
  ceps := 2439
  cnA := c.cnA
  cnM := c.cnM
  tn := 1
  sq := 15
  sk := 15
  sv := 16
  ss := c.s + 12
  spv := 12
  sao := c.ao + 14
  sgate := c.gate
  sup := 12
  sprod := 16
  sdown := c.z + 14
  fp := 12
  fe := 9
  wrho := 16
  nG := c.nG
  h24 := true

/-- The run's carrier: `T = 128`, `d = 3072`. -/
abbrev shieldS0 : BlockShape := carrier 128 3072

/-- A layer's block shape. -/
abbrev shieldShape (c : ShieldLayer) : BlockShape := (shieldCal c).over shieldS0

/-- The precision `derive` gives a layer at LowH24 (the shifts the shape uses, and the product's pre-fold shift). -/
def shieldPrec (c : ShieldLayer) : Prec := ⟨1, 15, 15, 16, c.s + 12, 12, c.ao + 14, 18, 12, c.h - 8, c.z + 14, 12⟩

/-- **Every layer's base calibration passes `derive` at LowH24** (L17's model of `accuracy_precision::derive`), with
exactly the shifts of `shieldCal`. -/
theorem shield_derive : ∀ c ∈ shieldExport, derive true (shieldBase (c.ao, c.s, c.h, c.z, c.gate)) = some (shieldPrec c) := by
  decide

/-- The shape's shifts are the derived precision's (by definition). -/
theorem shieldCal_prec (c : ShieldLayer) :
    (shieldShape c).sq = (shieldPrec c).q ∧ (shieldShape c).sk = (shieldPrec c).k ∧ (shieldShape c).sv = (shieldPrec c).v
      ∧ (shieldShape c).ss = (shieldPrec c).score ∧ (shieldShape c).spv = (shieldPrec c).pv
      ∧ (shieldShape c).sao = (shieldPrec c).ao ∧ (shieldShape c).sup = (shieldPrec c).up
      ∧ (shieldShape c).sdown = (shieldPrec c).down ∧ (shieldShape c).fp = (shieldPrec c).fp
      ∧ (shieldShape c).tn = (shieldPrec c).tn :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

/-- The finite facts of the export a layer's validity needs. -/
abbrev LayerOk (c : ShieldLayer) : Prop :=
  c.ao ≤ 8 ∧ 6 ≤ c.ao ∧ c.s ≤ 8 ∧ 5 ≤ c.s ∧ c.z ≤ 8 ∧ 3 ≤ c.z ∧ 17 ≤ c.gate ∧ c.gate ≤ 24 ∧ c.cnA ≤ 2 ^ 24 ∧
    c.cnM ≤ 2 ^ 24 ∧ c.nG ≤ 4 ∧ 1 ≤ c.nG

theorem shield_layers_ok : ∀ c ∈ shieldExport, LayerOk c := by decide

/-- **A layer's shape is in the code's class** when its calibration has the export's ranges. -/
theorem shieldShape_valid (c : ShieldLayer) (h : LayerOk c) : (shieldShape c).Valid := by
  obtain ⟨h1, -, h3, -, h5, -, -, h8, h9, h10, h11, -⟩ := h
  have hA : |((c.cnA : ℕ) : ℤ)| ≤ 2 ^ 24 := by
    rw [abs_of_nonneg (by positivity)]
    exact_mod_cast h9
  have hM : |((c.cnM : ℕ) : ℤ)| ≤ 2 ^ 24 := by
    rw [abs_of_nonneg (by positivity)]
    exact_mod_cast h10
  exact
    { d_le := by show 3072 ≤ 4096; norm_num
      qw_le := by show 32 * (2 * 64) ≤ 4096; norm_num
      hd_le := by show 2 * 64 ≤ 4096; norm_num
      f_le := by show 9216 ≤ 16384; norm_num
      T_le := by show 128 ≤ 2 ^ 24; norm_num
      window := by show ((128 : ℕ) : ℤ) * 2 ^ 9 ≤ 2 ^ 16; norm_num
      wrho_le := by show 16 ≤ 24; norm_num
      fp_le := by show 12 ≤ 12; norm_num
      ceps1 := by show (1 : ℤ) ≤ 2439; norm_num
      ceps2 := by show (2439 : ℤ) ≤ 2 ^ 24; norm_num
      cnA := hA
      cnM := hM
      tn_le := by show 1 ≤ 16; norm_num
      sq_le := by show 15 ≤ 24; norm_num
      sk_le := by show 15 ≤ 24; norm_num
      sv_le := by show 16 ≤ 24; norm_num
      ss_le := by show c.s + 12 ≤ 24; omega
      spv_le := by show 12 ≤ 24; norm_num
      sao_le := by show c.ao + 14 ≤ 24; omega
      sgate_le := h8
      sup_le := by show 12 ≤ 24; norm_num
      sprod_le := by show 16 ≤ 24; norm_num
      sdown_le := by show c.z + 14 ≤ 24; omega
      nG_le := h11 }

/-- **All 26 real layer shapes are `BlockShape.Valid`.** -/
theorem shield_shapes_valid : ∀ c ∈ shieldExport, (shieldShape c).Valid :=
  fun c hc => shieldShape_valid c (shield_layers_ok c hc)

/-- **A layer's shape meets R13's windows at two softmax limbs** (`R13Windows … 1`: `ls + 1 = 2` limbs, the code's
`limbs_sigma_s = ⌈wrho_s/8⌉ = 2`). -/
theorem shieldShape_r13 (c : ShieldLayer) (h : LayerOk c) : R13Windows (shieldShape c) 1 := by
  obtain ⟨h1, h2, h3, h4, h5, h6, h7, h8, -⟩ := h
  exact
    { ao := ⟨by show 16 < c.ao + 14; omega, by show c.ao + 14 ≤ 24; omega⟩
      down := ⟨by show 16 < c.z + 14; omega, by show c.z + 14 ≤ 24; omega⟩
      q := ⟨by show 8 < 15; norm_num, by show 15 ≤ 16; norm_num⟩
      pv := ⟨by show 8 < 12; norm_num, by show 12 ≤ 16; norm_num⟩
      k := ⟨by show 8 < 15; norm_num, by show 15 ≤ 16; norm_num⟩
      v := ⟨by show 8 < 16; norm_num, by show 16 ≤ 16; norm_num⟩
      ss := ⟨by show 16 < c.s + 12; omega, by show c.s + 12 ≤ 24; omega⟩
      gate := ⟨by show 16 < c.gate; omega, h8⟩
      up := ⟨by show 8 < 12; norm_num, by show 12 ≤ 16; norm_num⟩
      fp := ⟨by show 8 < 12 + 1; norm_num, by show 12 + 1 ≤ 16; norm_num⟩
      wrho := ⟨by show 8 * 1 < 16; norm_num, by show 16 ≤ 8 * (1 + 1); norm_num⟩
      wrho24 := by show 16 ≤ 24; norm_num
      prod := rfl }

/-- **All 26 real layer shapes meet `R13Windows … 1`**, the hypothesis of L17's `blockSat_of_slots_r13`. -/
theorem shield_shapes_r13 : ∀ c ∈ shieldExport, R13Windows (shieldShape c) 1 :=
  fun c hc => shieldShape_r13 c (shield_layers_ok c hc)

/-- **Finding L40-2**: `R13Windows … 2` (three softmax limbs) fails at every layer (`wrho_s = 16` is not above `16`); L17's
docstring of `shield_layers_accepted` names `ls = 2`, which is the PLANE count's convention (`aPlanes true 2`, the
limb count), not `R13Windows`'s (the limb count minus one). -/
theorem shield_not_r13Windows2 (c : ShieldLayer) : ¬ R13Windows (shieldShape c) 2 := by
  intro h
  have h1 := h.wrho.1
  change 8 * 2 < 16 at h1
  omega

/-! ## GB-2: the 26 calibrations are not one shape -/

/-- The shape-carried part of a layer's calibration: every field but `sh_h` (which enters the ACT table's scaling, not
the shape). -/
def shapePart (c : ShieldLayer) : ShieldLayer := { c with h := 0 }

/-- **The 26 layers carry 26 distinct shapes' calibrations** (the norm constants differ in every layer; the shifts and
gates alone give L17's 17 sets). -/
theorem shield_cals_distinct : (shieldExport.map shapePart).dedup.length = 26 := by
  decide

/-- **No single `BlockShape` is the shape of all 26 real blocks** (GB-2, PROVED): layers 0 and 1 already differ in
`cn_a` (848 and 2600). So the app's model is not L2's one-shape `classifyModel S R` for any `S`. -/
theorem shield_not_one_shape : ¬ ∃ S : BlockShape, ∀ c ∈ shieldExport, shieldShape c = S := by
  rintro ⟨S, hS⟩
  have h0 := hS ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩ (by decide)
  have h1 := hS ⟨8, 8, 14, 8, 19, 2600, 1471, 3⟩ (by decide)
  have h := congrArg BlockShape.cnA (h0.trans h1.symm)
  change ((848 : ℕ) : ℤ) = ((2600 : ℕ) : ℤ) at h
  omega

/-! ## The app's run in the per-block model -/

/-- **The app's classifier run, one shape per block**: 26 blocks whose calibrations are the export's, in order. -/
def ShieldRun (R : ClassifyRunPublicP shieldS0) : Prop := R.blks.map RunBlock.cal = shieldExport.map shieldCal

/-- **The app's run is `Valid`** given stage IN-C's and stage OUT-C's classes and every block's PUBLIC DATA class
(`hpub`); every block's SHAPE validity is proved (`shield_shapes_valid`). -/
theorem shieldRun_valid (R : ClassifyRunPublicP shieldS0) (hR : ShieldRun R) (hin : R.inp.Valid) (hout : R.out.Valid)
    (hpub : ∀ b ∈ R.blks, b.pub.Valid) : R.Valid where
  d_le := by show 3072 ≤ 4096; norm_num
  inp := hin
  blks := by
    intro b hb
    have hc : b.cal ∈ shieldExport.map shieldCal := by
      rw [← hR]
      exact List.mem_map_of_mem (f := RunBlock.cal) hb
    obtain ⟨c, hc, hcb⟩ := List.mem_map.mp hc
    refine ⟨?_, hpub b hb⟩
    rw [← hcb]
    exact shield_shapes_valid c hc
  out := hout

/-- **`CircuitIff` for the app's classifier model, one shape per block**, with the stages' and the blocks' public data
in their classes. -/
theorem shield_circuitIff (R : ClassifyRunPublicP shieldS0) (hR : ShieldRun R) (hin : R.inp.Valid)
    (hout : R.out.Valid) (hpub : ∀ b ∈ R.blks, b.pub.Valid) :
    CircuitIff (classifyModelP R) (classifyArithP R) :=
  classifyRunP_circuitIff R (shieldRun_valid R hR hin hout hpub)

/-- **`CircuitIff` for the app's classifier at a registered category policy** (L15's stage data): stage IN-C's data is
L15's `shieldIn` for one of the three registered policies, any content length and an int16 embedding; stage OUT-C's is
a margin vector in `[−32767, 32767]` with a final norm in the door's classes (L15's `shield_outc_valid`). The only
premises left are the blocks' public data (`hpub`) and the stage tensors' classes. -/
theorem shield_circuitIff_policy (q : List ℕ)
    (hq : q = StageX.Valid.qSexual ∨ q = StageX.Valid.qViolence ∨ q = StageX.Valid.qHate) (n : ℕ)
    (emb : ℕ → Fin 3072 → ℤ) (hemb : ∀ v i, i16 (emb v i)) (wΔ : Fin 3072 → ℤ) (hw : ∀ i, |wΔ i| ≤ 32767)
    (g0 cn ceps : ℤ) (tn : ℕ) (hg0 : 1 ≤ g0 ∧ g0 ≤ 127) (hcn : 1 ≤ cn ∧ cn ≤ 2 ^ 20) (hceps : 1 ≤ ceps ∧ ceps ≤ 2 ^ 40)
    (htn : tn ≤ 16) (bs : List (RunBlock shieldS0)) (hbs : bs.map RunBlock.cal = shieldExport.map shieldCal)
    (hpub : ∀ b ∈ bs, b.pub.Valid) (row : Fin 128) :
    CircuitIff (classifyModelP (⟨StageX.Valid.shieldIn shieldS0 q n emb, bs, ⟨wΔ, 0, g0, cn, ceps, tn, 5⟩, row⟩ :
      ClassifyRunPublicP shieldS0))
      (classifyArithP (⟨StageX.Valid.shieldIn shieldS0 q n emb, bs, ⟨wΔ, 0, g0, cn, ceps, tn, 5⟩, row⟩ :
      ClassifyRunPublicP shieldS0)) :=
  shield_circuitIff _ hbs (StageX.Valid.shield_in_valid shieldS0 q hq n emb hemb)
    (StageX.Valid.shield_outc_valid wΔ hw g0 cn ceps tn hg0 hcn hceps htn) hpub

/-! ## Non-vacuity: the premises hold together at the real shapes -/

/-- Zero public data at a shape (the premises' non-vacuity, not the real data). -/
def zeroPub (S : BlockShape) : BlockPublic S :=
  ⟨0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, fun _ => 0, fun _ _ => 0, fun _ => 0⟩

theorem zeroPub_valid (S : BlockShape) (hn : 1 ≤ S.nG) : (zeroPub S).Valid where
  gA _ := by simp [zeroPub]
  gM _ := by simp [zeroPub]
  wq _ _ := by simp [zeroPub]
  wk _ _ := by simp [zeroPub]
  wv _ _ := by simp [zeroPub]
  wo _ _ := by simp [zeroPub]
  wg _ _ := by simp [zeroPub]
  wu _ _ := by simp [zeroPub]
  wd _ _ := by simp [zeroPub]
  mq _ := by simp [zeroPub]
  mK _ := by simp [zeroPub]
  mv _ := by simp [zeroPub]
  mo _ := by simp [zeroPub]
  mg _ := by simp [zeroPub]
  mu _ := by simp [zeroPub]
  md _ := by simp [zeroPub]
  cos _ _ := by simp [zeroPub]
  sin _ _ := by simp [zeroPub]
  exp0 _ := by simp [zeroPub]
  exp1 _ := by show (0 : ℤ) ≤ 2 ^ S.fe; positivity
  act _ _ := by simp [zeroPub]
  grpF _ := by show 0 < S.nG; omega

/-- The 26 real blocks with zero public data. -/
def shieldZeroBlocks : List (RunBlock shieldS0) := shieldExport.map fun c => ⟨shieldCal c, zeroPub _⟩

theorem shieldZeroBlocks_cal : shieldZeroBlocks.map RunBlock.cal = shieldExport.map shieldCal := by
  simp only [shieldZeroBlocks, List.map_map]
  rfl

/-- **The premises are satisfiable at the real shapes**: a run with the export's 26 calibrations, L15's sexual-content
policy stage, a valid OUT-C stage and zero block data is `ShieldRun` and `Valid`. -/
theorem shield_run_exists : ∃ R : ClassifyRunPublicP shieldS0, ShieldRun R ∧ R.Valid := by
  refine ⟨⟨StageX.Valid.shieldIn shieldS0 StageX.Valid.qSexual 0 (fun _ _ => 0), shieldZeroBlocks,
    ⟨fun _ => 0, 0, 1, 1, 1, 0, 5⟩, ⟨0, by show 0 < 128; norm_num⟩⟩, ?_, ?_⟩
  · exact shieldZeroBlocks_cal
  · refine shieldRun_valid _ shieldZeroBlocks_cal
      (StageX.Valid.shield_in_valid shieldS0 StageX.Valid.qSexual (Or.inl rfl) 0 (fun _ _ => 0)
        (fun _ _ => by unfold i16; norm_num))
      (StageX.Valid.shield_outc_valid (fun _ => 0) (fun _ => by norm_num) 1 1 1 0 (by norm_num) (by norm_num)
        (by norm_num) (by norm_num)) ?_
    intro b hb
    obtain ⟨c, hc, rfl⟩ := List.mem_map.mp hb
    exact zeroPub_valid _ (shield_layers_ok c hc).2.2.2.2.2.2.2.2.2.2.2

end ZK60.RunShape.Shield
