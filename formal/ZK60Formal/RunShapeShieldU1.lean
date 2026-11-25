/-
D63 W16R2 Shieldstral port, Item (4) (`RunShapeShieldU1.lean`):
**the installed W16R2 Shieldstral classifier export (`export_u1`, `PROFILE_SHA = 9464388091d8095f...`,
`W16R2_SHIELD_T128_H24`, `RUN_PROFILE_CLASSIFY_W16R2_SHIELD_T128_DEV`) as a per-block-shape run model
with uniform W16 range families and `CircuitIff`.**

### Provenance: Typed vs. Derived Values
1. **Typed from `export_u1` manifests** (`shieldExportU1` below, plus the uniform profile constants
   already defined in `RunShapeShield.lean`: `T = 128`, `d = 3072`, `f = 9216`, `H = 32`, `G = 8`,
   `half = 64`, `f_e = 9`, `f_p = 12`, `norm_ceps = 2439`, `norm_tn = 9`, `sh_qkv = 8`, `sh_o = 9`,
   `sh_g = 8`, `sh_u = 0`, `sh_rope = 7`, `LowH24`):
   - Per layer `k = 0..25`: `(sh_ao, sh_s, sh_h, sh_z, gate_shift, cn_a, cn_m, nG)` where `gate_shift`
     is the folded gate shift `max(max_g(sh_g + 10 + (e_in - base_e_in)), 17)` (`accuracy_groups.rs:48-50`).
   - **Independent check command** (rehashes `profile.json` against `9464388091d8095f...` and all 26
     `layer_{00..25}/manifest.json` files and verifies every typed tuple of `shieldExportU1` entry for entry):
     ```
     python3 -B formal/ZK60Formal/verify_export_u1.py /Users/victorrielly/zk60-artifacts/a29-uniform-calibration/export_u1 formal/ZK60Formal/RunShapeShieldU1.lean
     ```
2. **Derived inside Lean (not typed independently):**
   - `shieldPrec c`, `shieldCal c`, `shieldShape c`, `precShieldW16U1 c`: derived from `shieldExportU1`
     via `accuracy_precision::derive` (`shieldExportU1_derive`) and `RunShapeShield.shieldCal`.
   - `widthsW (precShieldW16U1 c) = [3, 4, 5, 6, 7, 12, 13, 15, 16]` (`widthsW_shieldU1`),
     `famsW ... 14 = [(3,1),(4,1),(5,1),(6,1),(7,1),(12,1),(13,1),(15,2),(16,4)]` (`famsW_shieldU1`),
     `nRange = 13` (`nRange_shieldU1`), `FamsOK` (`famsOK_shieldU1`), `W16Widths` (`shieldU1_shapes_w16Widths`),
     `BlockShape.Valid` (`shieldU1_shapes_valid`), `ShieldU1Run.Valid` (`shieldU1Run_valid`),
     `CircuitIff` (`shieldU1_circuitIff`, `shieldU1_circuitIff_policy`), and non-vacuity (`shieldU1_run_exists`).

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.RunShapeShield
import ZK60Formal.SlotW16BuildLayout

set_option autoImplicit false

namespace ZK60.RunShape.ShieldU1

open ZK60 ZK60.Model ZK60.Circuit ZK60.Block ZK60.Out ZK60.TokenRun ZK60.RunShape
open ZK60.RunShape.Shield (ShieldLayer shieldCal shieldS0 shieldShape shieldPrec LayerOk shapePart
  shieldShape_valid zeroPub zeroPub_valid)
open ZK60.Layout.R13.Shape (derive shieldBase)
open ZK60.Exec.Slot.Build.Lay (PrecW widthsW famsW famsOf foldShift w16Widths_of famsOK_famsOf)

/-! ## 1. Typed `export_u1` per-layer calibrations (layers 0 to 25) -/

/-- **The installed W16R2 Shieldstral-1.0-3B T128 uniform export (`export_u1`), layers 0 to 25**
(`PROFILE_SHA = 9464388091d8095f8491f2990fde54e3b1f2b06f2a5c6ad1e72eff09cd4ce20a`).
Checked entry-for-entry against `export_u1/layer_{00..25}/manifest.json` by `verify_export_u1.py`. -/
def shieldExportU1 : List ShieldLayer :=
  [⟨7, 7, 16, 8, 20, 848, 1716, 3⟩,
   ⟨7, 7, 15, 8, 20, 2600, 1471, 3⟩,
   ⟨7, 7, 16, 8, 20, 2727, 1196, 4⟩,
   ⟨7, 7, 15, 8, 20, 2899, 1448, 3⟩,
   ⟨7, 7, 15, 8, 20, 2304, 1289, 3⟩,
   ⟨7, 7, 15, 8, 20, 2277, 1539, 3⟩,
   ⟨7, 7, 15, 8, 20, 2190, 1370, 3⟩,
   ⟨7, 7, 15, 8, 20, 2212, 1424, 3⟩,
   ⟨7, 7, 15, 8, 20, 2248, 1479, 3⟩,
   ⟨7, 7, 14, 8, 20, 2267, 1302, 4⟩,
   ⟨7, 7, 16, 8, 20, 2218, 1539, 3⟩,
   ⟨7, 7, 15, 8, 20, 2233, 1533, 4⟩,
   ⟨7, 7, 14, 8, 20, 2208, 1246, 4⟩,
   ⟨7, 7, 13, 8, 20, 2185, 999, 4⟩,
   ⟨7, 7, 14, 8, 20, 2118, 1052, 3⟩,
   ⟨7, 7, 13, 8, 20, 2015, 1182, 4⟩,
   ⟨7, 7, 14, 8, 20, 2174, 1481, 4⟩,
   ⟨7, 7, 14, 8, 20, 2430, 1435, 4⟩,
   ⟨7, 7, 15, 8, 20, 2448, 1607, 4⟩,
   ⟨7, 7, 15, 8, 20, 2599, 1835, 4⟩,
   ⟨7, 7, 16, 8, 20, 2273, 1926, 4⟩,
   ⟨7, 7, 14, 8, 20, 2343, 2091, 3⟩,
   ⟨7, 7, 15, 8, 20, 2753, 2455, 3⟩,
   ⟨7, 7, 16, 8, 20, 3854, 2062, 4⟩,
   ⟨7, 7, 15, 8, 20, 4532, 2467, 4⟩,
   ⟨7, 7, 14, 8, 20, 3047, 3106, 4⟩]

theorem shieldExportU1_length : shieldExportU1.length = 26 := by decide

/-- **A29 uniformity**: every one of the 26 layers of `export_u1` shares identical requantization
shifts `(sh_ao=7, sh_s=7, sh_z=8)` and folded gate shift `20` (with `sh_h ∈ [13, 16]` and `nG ∈ {3, 4}`). -/
theorem shieldExportU1_uniform :
    ∀ c ∈ shieldExportU1,
      c.ao = 7 ∧ c.s = 7 ∧ c.z = 8 ∧ c.gate = 20 ∧ 13 ≤ c.h ∧ c.h ≤ 16 ∧ 3 ≤ c.nG ∧ c.nG ≤ 4 := by
  decide

/-- Every layer of `export_u1` passes `accuracy_precision::derive` at LowH24 with `shieldPrec c`. -/
theorem shieldExportU1_derive :
    ∀ c ∈ shieldExportU1, derive true (shieldBase (c.ao, c.s, c.h, c.z, c.gate)) = some (shieldPrec c) := by
  decide

theorem shieldExportU1_layers_ok : ∀ c ∈ shieldExportU1, LayerOk c := by decide

/-- **All 26 `export_u1` layer shapes are `BlockShape.Valid`.** -/
theorem shieldU1_shapes_valid : ∀ c ∈ shieldExportU1, (shieldShape c).Valid :=
  fun c hc => shieldShape_valid c (shieldExportU1_layers_ok c hc)

/-! ## 2. Derived W16R2 precision, range widths, families, `FamsOK`, and `W16Widths` -/

/-- The derived `PrecW` of an `export_u1` layer (`ao=21, score=19, down=22, gate=20, wrho=16`;
only `cnA` and `cnM` vary across the 26 layers). -/
def precShieldW16U1 (c : ShieldLayer) : PrecW where
  h24 := true
  tn := 1
  cnA := c.cnA
  cnM := c.cnM
  ceps := 2439
  q := 15
  k := 15
  v := 16
  score := c.s + 12
  pv := 12
  ao := c.ao + 14
  gate := c.gate
  up := 12
  prodbits := 24
  down := c.z + 14
  fp := 12
  wrho := 16
  rope := 7
  fold := 16

/-- The single uniform range-width list of all 26 `export_u1` layers (`range16::widths`). -/
def widthsShieldW16U1 : List ℕ := [3, 4, 5, 6, 7, 12, 13, 15, 16]

/-- The single uniform `(width, sub-planes)` family list of all 26 `export_u1` layers at `log_cols = 14`. -/
def famsShieldW16U1 : List (ℕ × ℕ) :=
  [(3, 1), (4, 1), (5, 1), (6, 1), (7, 1), (12, 1), (13, 1), (15, 2), (16, 4)]

/-- The LogUp `(tag, width)` family list for `CircuitRopeAct.CodeTable` (`U8` plus `widthsShieldW16U1`). -/
def famsLogUpW16U1 : List (ℕ × ℕ) := famsOf widthsShieldW16U1

/-- Every `export_u1` layer derives the exact same `widthsW` (`[3,4,5,6,7,12,13,15,16]`). -/
theorem widthsW_shieldU1 : ∀ c ∈ shieldExportU1, widthsW (precShieldW16U1 c) = widthsShieldW16U1 := by
  intro c hc
  obtain ⟨hao, hs, hz, hgate, -⟩ := shieldExportU1_uniform c hc
  unfold precShieldW16U1 widthsW ZK60.Exec.Slot.Build.Lay.widthsRaw
  simp only [hao, hs, hz, hgate]
  have h1 : (List.filter (fun x => decide (x ≠ 8))
      ([16] ++ ZK60.Exec.Slot.Build.Lay.remW 24 ++ ZK60.Exec.Slot.Build.Lay.remW (7 + 14)
        ++ ZK60.Exec.Slot.Build.Lay.remW (8 + 14) ++ ZK60.Exec.Slot.Build.Lay.remW 15
        ++ ZK60.Exec.Slot.Build.Lay.remW 7 ++ ZK60.Exec.Slot.Build.Lay.remW 12
        ++ ZK60.Exec.Slot.Build.Lay.remW 15 ++ ZK60.Exec.Slot.Build.Lay.remW 16
        ++ ZK60.Exec.Slot.Build.Lay.remW 7 ++ ZK60.Exec.Slot.Build.Lay.remW 20
        ++ ZK60.Exec.Slot.Build.Lay.remW 12 ++ ZK60.Exec.Slot.Build.Lay.remW (ZK60.Exec.Slot.Build.Lay.rhWidth true)
        ++ ZK60.Exec.Slot.Build.Lay.remW (7 + 12) ++ ZK60.Exec.Slot.Build.Lay.remW (12 + 1)
        ++ ZK60.Exec.Slot.Build.Lay.remW 16)).dedup
      = [5, 6, 15, 7, 4, 12, 3, 13, 16] := by
    decide
  rw [h1]
  simp [widthsShieldW16U1, List.mergeSort]

/-- Every `export_u1` layer derives the exact same `famsW ... 14` (`13` range sub-planes in `Dom::Tab`). -/
theorem famsW_shieldU1 : ∀ c ∈ shieldExportU1, famsW (widthsW (precShieldW16U1 c)) 14 = famsShieldW16U1 := by
  intro c hc
  rw [widthsW_shieldU1 c hc]
  decide

theorem nRange_shieldU1 : (famsShieldW16U1.map Prod.snd).sum = 13 := by decide

/-- **`FamsOK`** holds for `export_u1`'s LogUp family list. -/
theorem famsOK_shieldU1 : FamsOK famsLogUpW16U1 :=
  famsOK_famsOf widthsShieldW16U1 (by decide)

/-- **Every one of the 26 `export_u1` layer shapes satisfies `W16Widths`** over the single uniform
family list `famsLogUpW16U1` (the layout premise of `LayoutW16.blockSat_of_slots`). -/
theorem shieldU1_shapes_w16Widths : ∀ c ∈ shieldExportU1, ZK60.Layout.W16Widths (shieldShape c) famsLogUpW16U1 := by
  intro c hc
  have h1 := w16Widths_of (precShieldW16U1 c) (shieldShape c) rfl rfl rfl rfl rfl rfl rfl rfl rfl rfl rfl rfl rfl
    (by show 12 < 16; norm_num)
  rwa [widthsW_shieldU1 c hc] at h1

/-! ## 3. Per-block distinctness, `ShieldU1Run`, `CircuitIff`, and non-vacuity -/

/-- All 26 layers of `export_u1` have pairwise distinct norm calibrations (`cnA`, `cnM`). -/
theorem shieldU1_cals_distinct : (shieldExportU1.map shapePart).dedup.length = 26 := by decide

/-- No single `BlockShape` is the shape of all 26 `export_u1` blocks (`cnA` differs: 848 vs 2600). -/
theorem shieldU1_not_one_shape : ¬ ∃ S : BlockShape, ∀ c ∈ shieldExportU1, shieldShape c = S := by
  rintro ⟨S, hS⟩
  have h0 := hS ⟨7, 7, 16, 8, 20, 848, 1716, 3⟩ (by decide)
  have h1 := hS ⟨7, 7, 15, 8, 20, 2600, 1471, 3⟩ (by decide)
  have h := congrArg BlockShape.cnA (h0.trans h1.symm)
  change ((848 : ℕ) : ℤ) = ((2600 : ℕ) : ℤ) at h
  omega

/-- **The installed W16R2 Shieldstral classifier run (`export_u1`), one shape per block**:
26 blocks whose calibrations are `shieldExportU1` in order. -/
def ShieldU1Run (R : ClassifyRunPublicP shieldS0) : Prop :=
  R.blks.map RunBlock.cal = shieldExportU1.map shieldCal

/-- **`ShieldU1Run` is `Valid`** given stage IN-C's, stage OUT-C's, and every block's public data classes. -/
theorem shieldU1Run_valid (R : ClassifyRunPublicP shieldS0) (hR : ShieldU1Run R) (hin : R.inp.Valid)
    (hout : R.out.Valid) (hpub : ∀ b ∈ R.blks, b.pub.Valid) : R.Valid where
  d_le := by show 3072 ≤ 4096; norm_num
  inp := hin
  blks := by
    intro b hb
    have hc : b.cal ∈ shieldExportU1.map shieldCal := by
      rw [← hR]
      exact List.mem_map_of_mem (f := RunBlock.cal) hb
    obtain ⟨c, hc, hcb⟩ := List.mem_map.mp hc
    refine ⟨?_, hpub b hb⟩
    rw [← hcb]
    exact shieldU1_shapes_valid c hc
  out := hout

/-- **`CircuitIff` for the installed W16R2 Shieldstral classifier model (`export_u1`).** -/
theorem shieldU1_circuitIff (R : ClassifyRunPublicP shieldS0) (hR : ShieldU1Run R) (hin : R.inp.Valid)
    (hout : R.out.Valid) (hpub : ∀ b ∈ R.blks, b.pub.Valid) :
    CircuitIff (classifyModelP R) (classifyArithP R) :=
  classifyRunP_circuitIff R (shieldU1Run_valid R hR hin hout hpub)

/-- **`CircuitIff` for `export_u1` at a registered category policy.** -/
theorem shieldU1_circuitIff_policy (q : List ℕ)
    (hq : q = StageX.Valid.qSexual ∨ q = StageX.Valid.qViolence ∨ q = StageX.Valid.qHate) (n : ℕ)
    (emb : ℕ → Fin 3072 → ℤ) (hemb : ∀ v i, i16 (emb v i)) (wΔ : Fin 3072 → ℤ) (hw : ∀ i, |wΔ i| ≤ 32767)
    (g0 cn ceps : ℤ) (tn : ℕ) (hg0 : 1 ≤ g0 ∧ g0 ≤ 127) (hcn : 1 ≤ cn ∧ cn ≤ 2 ^ 20) (hceps : 1 ≤ ceps ∧ ceps ≤ 2 ^ 40)
    (htn : tn ≤ 16) (bs : List (RunBlock shieldS0)) (hbs : bs.map RunBlock.cal = shieldExportU1.map shieldCal)
    (hpub : ∀ b ∈ bs, b.pub.Valid) (row : Fin 128) :
    CircuitIff (classifyModelP (⟨StageX.Valid.shieldIn shieldS0 q n emb, bs, ⟨wΔ, 0, g0, cn, ceps, tn, 5⟩, row⟩ :
      ClassifyRunPublicP shieldS0))
      (classifyArithP (⟨StageX.Valid.shieldIn shieldS0 q n emb, bs, ⟨wΔ, 0, g0, cn, ceps, tn, 5⟩, row⟩ :
      ClassifyRunPublicP shieldS0)) :=
  shieldU1_circuitIff _ hbs (StageX.Valid.shield_in_valid shieldS0 q hq n emb hemb)
    (StageX.Valid.shield_outc_valid wΔ hw g0 cn ceps tn hg0 hcn hceps htn) hpub

/-- Non-vacuity: the 26 `export_u1` blocks with zero public data satisfy `ShieldU1Run` and `R.Valid`. -/
def shieldU1ZeroBlocks : List (RunBlock shieldS0) := shieldExportU1.map fun c => ⟨shieldCal c, zeroPub _⟩

theorem shieldU1ZeroBlocks_cal : shieldU1ZeroBlocks.map RunBlock.cal = shieldExportU1.map shieldCal := by
  simp only [shieldU1ZeroBlocks, List.map_map]
  rfl

theorem shieldU1_run_exists : ∃ R : ClassifyRunPublicP shieldS0, ShieldU1Run R ∧ R.Valid := by
  refine ⟨⟨StageX.Valid.shieldIn shieldS0 StageX.Valid.qSexual 0 (fun _ _ => 0), shieldU1ZeroBlocks,
    ⟨fun _ => 0, 0, 1, 1, 1, 0, 5⟩, ⟨0, by show 0 < 128; norm_num⟩⟩, ?_, ?_⟩
  · exact shieldU1ZeroBlocks_cal
  · refine shieldU1Run_valid _ shieldU1ZeroBlocks_cal
      (StageX.Valid.shield_in_valid shieldS0 StageX.Valid.qSexual (Or.inl rfl) 0 (fun _ _ => 0)
        (fun _ _ => by unfold i16; norm_num))
      (StageX.Valid.shield_outc_valid (fun _ => 0) (fun _ => by norm_num) 1 1 1 0 (by norm_num) (by norm_num)
        (by norm_num) (by norm_num)) ?_
    intro b hb
    obtain ⟨c, hc, rfl⟩ := List.mem_map.mp hb
    exact zeroPub_valid _ (shieldExportU1_layers_ok c hc).2.2.2.2.2.2.2.2.2.2.2

end ZK60.RunShape.ShieldU1
