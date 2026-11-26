/-
D63 W16R2 Shieldstral port (`BlockW16U1HostDzc.lean`):
**`SC_DZC`'s named identity (`FormAt`) at host `14` for the installed W16R2 Shieldstral export
`export_u1` (`W16R2_SHIELD_T128_H24`), with its hosted matmuls `SC_WO` (slot `10`) and `SC_DMM`
(slot `13`), parametric in per-layer `(cnA, cnM)`.**

Exact `export_u1` geometry (`cfgU1 cnA cnM`, `c0 = cfgShieldU1 0 0`):
* Cube width `19` (`Fin 19 → Bool`), `lt = 7`, `ld = 12`, `lq = 12`, `lf = 14`;
* Precision `tn = 1`, `sao = 21`, `sdown = 22`, parametric `(cnA, cnM)` (`cnA, cnM < 2 ^ 63`,
  satisfied by every layer of `shieldExportU1` via `shieldExportU1_cn_lt`);
* 19 `D`-planes `8..26`, 2 `T`-planes (`d = 0`, `dm = 2` at tables `24`, `25`), 10 LogUp helpers
  (`H` planes `1..10`, `fh c0 1 = 1`, 19 lookups = 9 pairs + 1 single), support gate at table `36`;
* Hosted slots: `SC_WO` (slot `10`, plane `O = 31`, inner `lq = 12`), `SC_DMM` (slot `13`,
  plane `H = 53`, inner `lf = 14`);
* 16 batch entries (`0..5` named clauses, `6..15` LogUp helper relations `xcDzcU1`), 19 pad planes
  (`pwDzcU1`), 39 draws (`[(.mu, 17), (.nu, 2), (.zeta, 1), (.tau, 19)]`).

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.BlockW16U1Base
import ZK60Formal.BlockHostDzc

set_option autoImplicit false
-- Broad simp sets on the 37-table value list and 6 clauses (as in `BlockHostDzc.lean`). Style warnings only.
set_option linter.unusedSimpArgs false
set_option linter.unreachableTactic false
set_option linter.unusedTactic false
set_option linter.unnecessarySeqFocus false

namespace ZK60.Exec.Block.Join.W16U1.Dzc

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly hostPhi batched SlotPoly segAt mle2)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl aPl_alg hPl cstK cstS_map cstK_base tabK_pa_cpt tabK_paHead_cpt
  eqT_eval pubT_eval hTab_eval tabK_ph_cpt aFx_eval mm_cube mm_fold eqDr lkRels_congr padPls_congr toK_zpowW
  lksS_eval formAt_two remR)
open ZK60.Exec.Block.Join.W16.Dzc (drS drS_length drS_getD drS_getDK R14 pos_map getD3 remVal_gt remR_lo2
  remR_hi2 cK_base cK_p16 muK_getD)
open ZK60.Exec.Block.Join.R13H (CtR CwR CgR CjR CdR CfR nD nH nQ nF plT plD plQ plF splitD splitHQ splitHQ_append
  LayR PubR PrecR)
open ZK60.Exec.Block.Join.W16U1
open ZK60.Exec.Block.DefW16 (W16Cfg cstS rhoC lksS padGroup lookupsN)
open ZK60.Exec.Slot.W16R2 (segLn segOff segSum)
open ZK60.Exec.Slot.Build (Cst cstW hostTerms gV gV_some L16 batchV dzcIr DzcR DzcK dzcClauses dzcIr_eval reqV
  logupSem padSem LkD mmIr mmIr_eval)
open ZK60.Exec.Slot.Compose (dzcIr_map mmIr_map cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-! ## The raw slots `SC_DZC`, `SC_WO`, `SC_DMM` at `export_u1` -/

/-- The plane-to-table map of `Dom::D` (`5 + (q − 8)`). -/
abbrev shD : ℕ → ℕ := W16.Dzc.shD

/-- An `A` plane of `Dom::D` on its own `19` coordinates, before numbering. -/
def aPD_u1 (q : ℕ) : TabS := .priv ⟨.a, [(offU1 q, false)], 19, rhoC 0 19, 0, 0⟩

/-- An `A` plane of `Dom::T` on the first `7` coordinates, before numbering. -/
def aPT_u1 (q : ℕ) : TabS := .priv ⟨.a, [(offU1 q, false)], 7, rhoC 0 7, 0, 0⟩

/-- `Dom::D`'s LogUp helper `j` (`H` plane `1 + j`, `fh c0 1 = 1`), before numbering. -/
def hPD_u1 (j : ℕ) : TabS :=
  .priv ⟨.h, [((hOffU1 (1 + j)).1, false), ((hOffU1 (1 + j)).2, true)], 19, rhoC 0 19, 0, 0⟩

/-- **`SC_DZC`'s 37 tables at `export_u1` before numbering**: `eq(τ)`, `eq` of `SC_WO`'s and
`SC_DMM`'s claim points, `γ_a`, `γ_m`, the 19 planes `8..26` of `Dom::D`, `D` (`0`) and `DM` (`2`)
on `Dom::T`, the 10 LogUp helpers (`H` planes `1..10`), and `supp(D)`. -/
def tabs14_u1 : List TabS :=
  [.eq (drS 14 20 19) 0, .eq (drS 10 0 19) 0, .eq (drS 13 0 19) 0, .pub 0, .pub 0,
    aPD_u1 8, aPD_u1 9, aPD_u1 10, aPD_u1 11, aPD_u1 12, aPD_u1 13, aPD_u1 14, aPD_u1 15, aPD_u1 16,
    aPD_u1 17, aPD_u1 18, aPD_u1 19, aPD_u1 20, aPD_u1 21, aPD_u1 22, aPD_u1 23, aPD_u1 24, aPD_u1 25,
    aPD_u1 26,
    aPT_u1 0, aPT_u1 2,
    hPD_u1 0, hPD_u1 1, hPD_u1 2, hPD_u1 3, hPD_u1 4, hPD_u1 5, hPD_u1 6, hPD_u1 7, hPD_u1 8, hPD_u1 9,
    .pub 0]

/-- `SC_DZC`'s constants at `export_u1`: `2·cn_a`, `2·cn_m`, `2^1 = 2`, `2^2 = 4`, `sao = 21`, `sdown = 22`. -/
def K14_u1 (cnA cnM : ℕ) : DzcK := ⟨2 * (cnA : ℤ), 2 * (cnM : ℤ), 2, 4, 21, 22⟩

/-- `Dom::D`'s 19 lookups at `export_u1` (identical across all `(cnA, cnM)`). -/
def lks14_u1 : List (LkD Sym) := lksS c0 shD .D

/-- `Dom::D`'s pad group at `export_u1` (gate at table `36`, 19 zero-rule planes `5..23`). -/
def grp14_u1 : List (ℕ × List ℕ) := padGroup c0 .D 36 shD

/-- **`SC_DZC`'s IR at `export_u1`** for per-layer `(cnA, cnM)`. -/
def ir14_u1 (cnA cnM : ℕ) : ZK60.Exec.Slot.Ir Sym :=
  dzcIr cstS R14 (K14_u1 cnA cnM) lks14_u1 (drS 14 0 17) (drS 14 17 2) (fun j => Sym.pow (Sym.dr 14 19) j) grp14_u1

/-- **`export_u1`'s raw `SC_DZC` slot (slot `14`).** -/
def rawDz_u1 (cnA cnM : ℕ) : SlotS :=
  ⟨tabs14_u1, ir14_u1 cnA cnM, [(10, .dr 14 17), (13, .dr 14 18)], [.dr 14 17, .dr 14 18, .dr 14 19]⟩

/-- **`export_u1`'s raw `SC_WO` slot (slot `10`)**: plane `O` (`31`) on fixed `r_q` (`7` draws)
then `12` inner coordinates (`lq = 12`), and folded `W_o`. -/
def rawWo_u1 : SlotS :=
  ⟨[.priv ⟨.a, [(offU1 31, false)], 19, (drS 10 0 7).map CoordS.fixed ++ rhoC 0 12, 0, 0⟩, .pub 0],
    mmIr cstS 0 1, [], []⟩

/-- **`export_u1`'s raw `SC_DMM` slot (slot `13`)**: plane `H` (`53`) on fixed `r_row` (`7` draws)
then `14` inner coordinates (`lf = 14`), and folded `W_d`. -/
def rawDmm_u1 : SlotS :=
  ⟨[.priv ⟨.a, [(offU1 53, false)], 21, (drS 13 0 7).map CoordS.fixed ++ rhoC 0 14, 0, 0⟩, .pub 0],
    mmIr cstS 0 1, [], []⟩

theorem rawSlot14_u1 (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 14 = rawDz_u1 cnA cnM := by
  rw [DefW16.rawSlot_shieldU1_14_eq cnA cnM]
  rfl

theorem rawSlot10_u1 (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 10 = rawWo_u1 := rfl

theorem rawSlot13_u1 (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 13 = rawDmm_u1 := rfl

theorem grp14_u1_eq : grp14_u1 = [(36, List.range' 5 19)] := by decide

theorem lks14_u1_length : lks14_u1.length = 19 := by decide

/-- Every lookup term of `Dom::D` at `export_u1` reads a table at position `≥ 5`. -/
theorem lks14_u1_pos : ∀ l ∈ lks14_u1, ∀ t ∈ l.terms, 5 ≤ t.2 := by
  intro l hl t ht
  unfold lks14_u1 lksS at hl
  obtain ⟨l0, -, rfl⟩ := List.mem_map.mp hl
  obtain ⟨t0, -, rfl⟩ := List.mem_map.mp ht
  show 5 ≤ 5 + (t0.1 - 8)
  omega

/-- Every `export_u1` layer's norm calibrations satisfy `cnA < 2 ^ 63` and `cnM < 2 ^ 63`. -/
theorem shieldExportU1_cn_lt (Ly : ZK60.RunShape.Shield.ShieldLayer)
    (hLy : Ly ∈ ZK60.RunShape.ShieldU1.shieldExportU1) :
    Ly.cnA < 2 ^ 63 ∧ Ly.cnM < 2 ^ 63 := by
  obtain ⟨-, -, -, -, -, -, -, -, hA, hM, -, -⟩ :=
    ZK60.RunShape.ShieldU1.shieldExportU1_layers_ok Ly hLy
  exact ⟨by omega, by omega⟩

/-! ## Numbering, table by table -/

section Num

theorem numTabs_nil (aB hB ioIn ioOut ak hk pk : ℕ) : DefW16.numTabs aB hB ioIn ioOut ak hk pk [] = [] := rfl

theorem numTabs_eqc (aB hB ioIn ioOut ak hk pk : ℕ) (pt : List Sym) (st : ℕ) (ts : List TabS) :
    DefW16.numTabs aB hB ioIn ioOut ak hk pk (.eq pt st :: ts)
      = .eq pt st :: DefW16.numTabs aB hB ioIn ioOut ak hk pk ts := rfl

theorem numTabs_pubc (aB hB ioIn ioOut ak hk pk i : ℕ) (ts : List TabS) :
    DefW16.numTabs aB hB ioIn ioOut ak hk pk (.pub i :: ts)
      = .pub pk :: DefW16.numTabs aB hB ioIn ioOut ak hk (pk + 1) ts := rfl

theorem numTabs_ac (aB hB ioIn ioOut ak hk pk : ℕ) (sl : List (ℕ × Bool)) (log : ℕ) (co : List CoordS) (m ex : ℕ)
    (ts : List TabS) :
    DefW16.numTabs aB hB ioIn ioOut ak hk pk (.priv ⟨.a, sl, log, co, m, ex⟩ :: ts)
      = .priv ⟨.a, sl, log, co, aB + 2 * ak, ex⟩ :: DefW16.numTabs aB hB ioIn ioOut (ak + 1) hk pk ts := rfl

theorem numTabs_hc (aB hB ioIn ioOut ak hk pk : ℕ) (sl : List (ℕ × Bool)) (log : ℕ) (co : List CoordS) (m ex : ℕ)
    (ts : List TabS) :
    DefW16.numTabs aB hB ioIn ioOut ak hk pk (.priv ⟨.h, sl, log, co, m, ex⟩ :: ts)
      = .priv ⟨.h, sl, log, co, hB + 2 * hk, ex⟩ :: DefW16.numTabs aB hB ioIn ioOut ak (hk + 1) pk ts := rfl

end Num

/-! ## The value list at a cube point, `valsXD_u1`, `xcDzcU1`, `pwDzcU1` -/

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)

/-- An `A` plane of `Dom::D` on `export_u1`, read at a cube point. -/
noncomputable def pDzU1 (q : ℕ) (b : Fin 19 → Bool) : K := aPl U P D (offU1 q) 19 b

/-- `Dom::D`'s LogUp helper `j` (`H` plane `1 + j`) on `export_u1`, read at a cube point. -/
noncomputable def hDzU1 (j : ℕ) (b : Fin 19 → Bool) : K :=
  hPl U P D (hOffU1 (1 + j)).1 (hOffU1 (1 + j)).2 19 b

/-- The real value list of `SC_DZC` at a point (generic in claim sites and extension). -/
noncomputable def valsF_u1 (aB hB ioIn ioOut ak hk : ℕ) (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2)
    (e : ℕ) (x : Fin (19 + e) → K) : List K :=
  ((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs14_u1).map (TabS.eval (Sym.eval hist 14 dr) pub)).map
    (tabK U P D 19 e x)

variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

/-- **`SC_DZC`'s values past its three `eq` tables at a cube point for `export_u1`** (positions `3..36`). -/
noncomputable def tailD_u1 (b : Fin 19 → Bool) : List K :=
  [algebraMap GF K (B.gamA (splitD c0 b)), algebraMap GF K (B.gamM (splitD c0 b)),
    pDzU1 U P D 8 b, pDzU1 U P D 9 b, pDzU1 U P D 10 b, pDzU1 U P D 11 b, pDzU1 U P D 12 b,
    pDzU1 U P D 13 b, pDzU1 U P D 14 b, pDzU1 U P D 15 b, pDzU1 U P D 16 b, pDzU1 U P D 17 b,
    pDzU1 U P D 18 b, pDzU1 U P D 19 b, pDzU1 U P D 20 b, pDzU1 U P D 21 b, pDzU1 U P D 22 b,
    pDzU1 U P D 23 b, pDzU1 U P D 24 b, pDzU1 U P D 25 b, pDzU1 U P D 26 b,
    aPl U P D (offU1 0) 7 (splitD c0 b).1, aPl U P D (offU1 2) 7 (splitD c0 b).1,
    hDzU1 U P D 0 b, hDzU1 U P D 1 b, hDzU1 U P D 2 b, hDzU1 U P D 3 b, hDzU1 U P D 4 b,
    hDzU1 U P D 5 b, hDzU1 U P D 6 b, hDzU1 U P D 7 b, hDzU1 U P D 8 b, hDzU1 U P D 9 b,
    algebraMap GF K (B.gD (splitD c0 b))]

/-- **The value list without the draws** (the `eq` entries `0`), for `SC_DZC` at `export_u1`. -/
noncomputable def valsXD_u1 (b : Fin 19 → Bool) : List K := 0 :: 0 :: 0 :: tailD_u1 U P D Pb Lay B b

/-- The lookups' expressions at `(β, γ, α)` with no draws (`export_u1`). -/
noncomputable def lksX_u1 (bga : Fp2 × Fp2 × Fp2) : List (LkD K) :=
  (lks14_u1.map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 14 []))).map
    (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U))

/-- **`SC_DZC`'s batch entry `κ` past its six named clauses at `export_u1`** (`6 ≤ κ < 16`):
LogUp's helper relation `κ − 6` of `Dom::D` at the cube point `b`, read on the planes, `α`, and
`γ` only (9 pair helpers `6..14` and 1 single helper `15`). -/
noncomputable def xcDzcU1 (bga : Fp2 × Fp2 × Fp2) (κ : ℕ) (b : Fin 19 → Bool) : K :=
  (lkRels (cstK U) (valsXD_u1 U P D Pb Lay B b) 26 0 (lksX_u1 U bga)).getD (κ - 6) 0

/-- **`SC_DZC`'s pad plane `j` at `export_u1`** (`j : Fin 19`): `(1 − supp_D(b))·plane_j(b)`
over the 19 zero-rule planes `8..26` of `Dom::D`. -/
noncomputable def pwDzcU1 (j : Fin 19) (b : Fin 19 → Bool) : K :=
  (padPls (valsXD_u1 U P D Pb Lay B b) grp14_u1).getD j 0

/-- Every lookup term of `Dom::D` reads the corresponding committed `A` plane from `valsXD_u1`. -/
theorem valsXD_u1_plane (b : Fin 19 → Bool) : ∀ l ∈ lookupsN c0 .D, ∀ t ∈ l.terms,
    (valsXD_u1 U P D Pb Lay B b).getD (shD t.1) 0 = aPl U P D (offU1 t.1) 19 b := by
  have hnum : ∀ l ∈ lookupsN c0 .D, ∀ t ∈ l.terms, 8 ≤ t.1 ∧ t.1 ≤ 26 := by decide +kernel
  intro l hl t ht
  obtain ⟨h1, h2⟩ := hnum l hl t ht
  generalize t.1 = q at h1 h2 ⊢
  interval_cases q <;> rfl

/-- Helper entry `26 + j` (`j < 10`) of `valsXD_u1` is `H` plane `1 + j` on `Dom::D`. -/
theorem valsXD_u1_help (b : Fin 19 → Bool) (j : ℕ) (hj : j < 10) :
    (valsXD_u1 U P D Pb Lay B b).getD (26 + 0 + j) 0
      = hPl U P D (hOffU1 (1 + j)).1 (hOffU1 (1 + j)).2 19 b := by
  interval_cases j <;> rfl

/-- An `A` plane of `Dom::T` on the first `7` variables of `Dom::D`'s `19`-bit cube. -/
theorem tabK_head19 (hrl : 0 < rowLog P .a) (e : ℕ) (b : Fin 19 → Bool) (off m ext : ℕ) :
    tabK U P D 19 e (cpt 19 e b) (.priv ⟨.a, [(off, Fp2.one)], 7, rhoAll 7, m, ext⟩)
      = aPl U P D off 7 (splitD c0 b).1 := by
  rw [tabK_paHead_cpt U P D hrl 19 e b 7 (by norm_num) (by norm_num)]
  rfl

/-- **`SC_DZC`'s value list at a cube point with the zero extension** (`export_u1`, any claim sites). -/
theorem dzcU1_vals (hrl : 0 < rowLog P .a) (aB hB ioIn ioOut ak hk e : ℕ) (b : Fin 19 → Bool)
    (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2)
    (hp0 : ((pub 0).getD (msbIndex 19 b) Fp2.zero).toK U = algebraMap GF K (B.gamA (splitD c0 b)))
    (hp1 : ((pub 1).getD (msbIndex 19 b) Fp2.zero).toK U = algebraMap GF K (B.gamM (splitD c0 b)))
    (hp2 : ((pub 2).getD (msbIndex 19 b) Fp2.zero).toK U = algebraMap GF K (B.gD (splitD c0 b))) :
    valsF_u1 U P D aB hB ioIn ioOut ak hk hist dr pub e (cpt 19 e b)
      = eqPoly (fun a : Fin 19 => (((drS 14 20 19).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U)
            (fun a => bit (b a))
        :: eqPoly (fun a : Fin 19 => (((drS 10 0 19).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U)
            (fun a => bit (b a))
        :: eqPoly (fun a : Fin 19 => (((drS 13 0 19).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U)
            (fun a => bit (b a))
        :: tailD_u1 U P D Pb Lay B b := by
  unfold valsF_u1
  simp only [tabs14_u1, aPD_u1, aPT_u1, hPD_u1, numTabs_eqc, numTabs_pubc, numTabs_ac, numTabs_hc, numTabs_nil,
    List.map_cons, List.map_nil, eqT_eval, pubT_eval, aTab_eval, hTab_eval]
  rw [tabK_eqFull_cpt U P D 19 e b _ (drS_length 14 20 19 _),
    tabK_eqFull_cpt U P D 19 e b _ (drS_length 10 0 19 _),
    tabK_eqFull_cpt U P D 19 e b _ (drS_length 13 0 19 _)]
  simp only [tabK_pa_cpt U P D hrl 19 e b 19 (by norm_num) rfl, castB_rfl, tabK_head19 U P D hrl e b,
    tabK_ph_cpt U P D hrl 19 e b 19 (by norm_num) rfl, tabK_pub_cpt, hp0, hp1, hp2, tailD_u1, pDzU1, hDzU1]

/-- Off the zero extension, `SC_DZC`'s three `eq` tables vanish. -/
theorem dzcU1_off (aB hB ioIn ioOut ak hk e : ℕ) (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2)
    (b : Fin 19 → Bool) (y : Fin e → Bool) (hy : y ≠ fun _ => false) :
    (valsF_u1 U P D aB hB ioIn ioOut ak hk hist dr pub e (bpt 19 e b y)).getD 0 0 = 0
      ∧ (valsF_u1 U P D aB hB ioIn ioOut ak hk hist dr pub e (bpt 19 e b y)).getD 1 0 = 0
      ∧ (valsF_u1 U P D aB hB ioIn ioOut ak hk hist dr pub e (bpt 19 e b y)).getD 2 0 = 0 := by
  refine ⟨?_, ?_, ?_⟩
  · show tabK U P D 19 e (bpt 19 e b y) (.eq ((drS 14 20 19).map (Sym.eval hist 14 dr)) 0) = 0
    exact tabK_eq_off U P D 19 e b y hy _ _
  · show tabK U P D 19 e (bpt 19 e b y) (.eq ((drS 10 0 19).map (Sym.eval hist 14 dr)) 0) = 0
    exact tabK_eq_off U P D 19 e b y hy _ _
  · show tabK U P D 19 e (bpt 19 e b y) (.eq ((drS 13 0 19).map (Sym.eval hist 14 dr)) 0) = 0
    exact tabK_eq_off U P D 19 e b y hy _ _

end Vals

/-! ## The named relations, embedded -/

section Rels

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

theorem append_splitD_u1 (t : Fin 19 → Bool) : Fin.append (splitD c0 t).1 (splitD c0 t).2 = t := by
  funext i
  refine Fin.addCases (m := 7) (n := 12) (fun i7 => ?_) (fun i12 => ?_) i
  · exact Fin.append_left (splitD c0 t).1 (splitD c0 t).2 i7
  · exact Fin.append_right (splitD c0 t).1 (splitD c0 t).2 i12

theorem append_splitHQ_u1 (q : Fin 12 → Bool) :
    Fin.append (Fin.append (splitHQ c0 q).1.1 (splitHQ c0 q).1.2) (splitHQ c0 q).2 = q := by
  funext i
  refine Fin.addCases (m := 5) (n := 7) (fun i5 => ?_) (fun i7 => ?_) i
  · refine (Fin.append_left (Fin.append (splitHQ c0 q).1.1 (splitHQ c0 q).1.2) (splitHQ c0 q).2 i5).trans ?_
    refine Fin.addCases (m := 3) (n := 2) (fun i3 => ?_) (fun i2 => ?_) i5
    · exact Fin.append_left (splitHQ c0 q).1.1 (splitHQ c0 q).1.2 i3
    · exact Fin.append_right (splitHQ c0 q).1.1 (splitHQ c0 q).1.2 i2
  · exact Fin.append_right (Fin.append (splitHQ c0 q).1.1 (splitHQ c0 q).1.2) (splitHQ c0 q).2 i7

include hX

theorem alg_plT_u1 (off : ℕ) (t : CtU1) : algebraMap GF K (plT U c0 P D off t) = aPl U P D off 7 t :=
  aPl_alg U P D hX off 7 t

theorem alg_plD_u1 (off : ℕ) (t : Fin 19 → Bool) :
    algebraMap GF K (plD U c0 P D off (splitD c0 t)) = aPl U P D off 19 t := by
  unfold plD
  rw [aPl_alg U P D hX]
  show aPl U P D off 19 (Fin.append (splitD c0 t).1 (splitD c0 t).2) = aPl U P D off 19 t
  rw [append_splitD_u1]

/-- **`SC_DZC`'s six relations at `export_u1`, embedded**, in the planes at cube point `t`
(parametric in `(cnA, cnM)`, `tn = 1`). -/
theorem relClD_u1_alg (cnA cnM : ℕ) (hS : PrecR (cfgU1 cnA cnM) S) (t : Fin 19 → Bool) :
    algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 14 0 (.d (splitD c0 t)))
        = algebraMap GF K (B.gD (splitD c0 t)) * (algebraMap GF K (B.gamA (splitD c0 t)) * pDzU1 U P D 8 t * (2 * (cnA : K))
          + aPl U P D (offU1 0) 7 (splitD c0 t).1 * 2 - 4 * aPl U P D (offU1 0) 7 (splitD c0 t).1 * pDzU1 U P D 9 t
          - (pDzU1 U P D 10 t + 65536 * pDzU1 U P D 11 t))
    ∧ algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 14 1 (.d (splitD c0 t)))
        = algebraMap GF K (B.gD (splitD c0 t)) * (pDzU1 U P D 10 t + 65536 * pDzU1 U P D 11 t
          + (pDzU1 U P D 12 t + 65536 * pDzU1 U P D 13 t) + 1 - 4 * aPl U P D (offU1 0) 7 (splitD c0 t).1)
    ∧ algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 14 2 (.d (splitD c0 t)))
        = algebraMap GF K (B.gD (splitD c0 t)) * (pDzU1 U P D 17 t - pDzU1 U P D 8 t - pDzU1 U P D 14 t)
    ∧ algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 14 3 (.d (splitD c0 t)))
        = algebraMap GF K (B.gD (splitD c0 t)) * (algebraMap GF K (B.gamM (splitD c0 t)) * pDzU1 U P D 17 t * (2 * (cnM : K))
          + aPl U P D (offU1 2) 7 (splitD c0 t).1 * 2 - 4 * aPl U P D (offU1 2) 7 (splitD c0 t).1 * pDzU1 U P D 18 t
          - (pDzU1 U P D 19 t + 65536 * pDzU1 U P D 20 t))
    ∧ algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 14 4 (.d (splitD c0 t)))
        = algebraMap GF K (B.gD (splitD c0 t)) * (pDzU1 U P D 19 t + 65536 * pDzU1 U P D 20 t
          + (pDzU1 U P D 21 t + 65536 * pDzU1 U P D 22 t) + 1 - 4 * aPl U P D (offU1 2) 7 (splitD c0 t).1)
    ∧ algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 14 5 (.d (splitD c0 t)))
        = algebraMap GF K (B.gD (splitD c0 t)) * (pDzU1 U P D 26 t - pDzU1 U P D 17 t - pDzU1 U P D 23 t) := by
  have hcnA' : S.cnA = (cnA : ℤ) := hS.cnA
  have hcnM' : S.cnM = (cnM : ℤ) := hS.cnM
  have htn' : S.tn = 1 := hS.tn
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
  all_goals (simp only [relCl, xtU1, remR_lo2, remR_hi2, remVal_gt 24 (by norm_num), map_sub, map_mul, map_add,
    map_pow, map_ofNat, map_intCast, map_one, alg_plT_u1 U P D hX, alg_plD_u1 U P D hX, pDzU1, hcnA', hcnM',
    htn'] <;> push_cast <;> ring)

/-- **`SC_DZC`'s two hosted relations at `export_u1`, embedded** (`sao = 21`, `sdown = 22`). -/
theorem relGhD_u1_alg (cnA cnM : ℕ) (hS : PrecR (cfgU1 cnA cnM) S) (t : Fin 19 → Bool) :
    algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 14 0 (.d (splitD c0 t)))
        = algebraMap GF K (B.gD (splitD c0 t)) * (2097152 * pDzU1 U P D 14 t
          + (pDzU1 U P D 15 t + 65536 * pDzU1 U P D 16 t) - 1048576)
    ∧ algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 14 1 (.d (splitD c0 t)))
        = algebraMap GF K (B.gD (splitD c0 t)) * (4194304 * pDzU1 U P D 23 t
          + (pDzU1 U P D 24 t + 65536 * pDzU1 U P D 25 t) - 2097152) := by
  have hsao : S.sao = 21 := hS.sao
  have hsdown : S.sdown = 22 := hS.sdown
  refine ⟨?_, ?_⟩
  all_goals (simp only [relGh, xtU1, remR_lo2, remR_hi2, hsao, hsdown, remVal_gt 21 (by norm_num),
    remVal_gt 22 (by norm_num), map_sub, map_mul, map_add, map_pow, map_ofNat, map_intCast, map_one,
    alg_plD_u1 U P D hX, pDzU1] <;> push_cast <;> ring)

end Rels

/-! ## The IR on the cube -/

section Ir

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem cK_two_nat (n : ℕ) (hn : n < 2 ^ 63) : (cstK U).base (2 * (n : ℤ)) = 2 * (n : K) := by
  rw [cK_base U (2 * (n : ℤ)) (by omega) (by omega)]
  simp only [Int.cast_mul, Int.cast_ofNat, Int.cast_natCast]

/-- **`SC_DZC`'s zero-check term at `export_u1`**: LogUp's helper relations, the pad term, and the
gated clauses. -/
noncomputable def zD_u1 (cnA cnM : ℕ) (hist : Hist) (dr : List Fp2) (v : List K) : K :=
  logupSem (cstK U) v 26 (fun k => (((drS 14 0 17).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD (6 + k) 0) 0
      ((lks14_u1.map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 14 dr))).map
        (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U)))
    + padSem (cstK U) v ((((drS 14 0 17).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD 16 0)
        (Fp2.toK U ∘ (Sym.eval hist 14 dr ∘ fun j => Sym.pow (Sym.dr 14 19) j)) 0 grp14_u1
    + gV v (some 36) * batchV (((drS 14 0 17).map (Sym.eval hist 14 dr)).map (Fp2.toK U))
        (dzcClauses (cstK U) R14 (K14_u1 cnA cnM) v)

/-- **`SC_DZC`'s IR read in the field at `export_u1`** (`dzcIr_eval`). -/
theorem dzcU1_irEval (cnA cnM : ℕ) (hist : Hist) (dr : List Fp2) (v : List K) :
    irEval (((ir14_u1 cnA cnM).map (Sym.eval hist 14 dr)).map (Fp2.toK U)) v
      = hostTerms v 0 1 2 (some 36) (some 36) (((drS 14 17 2).map (Sym.eval hist 14 dr)).map (Fp2.toK U))
          (zD_u1 U cnA cnM hist dr v) (reqV (cstK U) v 21 11 [12, 13]) (reqV (cstK U) v 22 20 [21, 22]) := by
  unfold ir14_u1
  rw [dzcIr_map, dzcIr_map, cstS_map, dzcIr_eval _ (cstW_map_std U)]
  rw [List.length_map, List.length_map, lks14_u1_length]
  rfl

end Ir

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

/-- **`SC_DZC`'s cube sum at `export_u1`** (`n = 19` main variables, any claim sites). -/
theorem dzcU1_cube (hrl : 0 < rowLog P .a) (cnA cnM aB hB ioIn ioOut ak hk n e : ℕ) (hn : n = 19)
    (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2)
    (hp0 : ∀ b, ((pub 0).getD (msbIndex 19 b) Fp2.zero).toK U = algebraMap GF K (B.gamA (splitD c0 b)))
    (hp1 : ∀ b, ((pub 1).getD (msbIndex 19 b) Fp2.zero).toK U = algebraMap GF K (B.gamM (splitD c0 b)))
    (hp2 : ∀ b, ((pub 2).getD (msbIndex 19 b) Fp2.zero).toK U = algebraMap GF K (B.gD (splitD c0 b)))
    (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((ir14_u1 cnA cnM).map (Sym.eval hist 14 dr)).map (Fp2.toK U))
      (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs14_u1).map (TabS.eval (Sym.eval hist 14 dr) pub)).map
        (tabK U P D n e x))) :
    cubeSum f = ∑ b : Fin 19 → Bool, hostPoly
      (fun a : Fin 19 => (((drS 14 20 19).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U)
      (fun b => zD_u1 U cnA cnM hist dr (valsF_u1 U P D aB hB ioIn ioOut ak hk hist dr pub e (cpt 19 e b)))
      ![(((drS 14 17 2).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD 0 0,
        (((drS 14 17 2).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD 1 0]
      ![fun a : Fin 19 => (((drS 10 0 19).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U,
        fun a : Fin 19 => (((drS 13 0 19).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U]
      (fun _ => 1)
      (fun i b => if i = 0
        then gV (valsF_u1 U P D aB hB ioIn ioOut ak hk hist dr pub e (cpt 19 e b)) (some 36)
          * reqV (cstK U) (valsF_u1 U P D aB hB ioIn ioOut ak hk hist dr pub e (cpt 19 e b)) 21 11 [12, 13]
        else gV (valsF_u1 U P D aB hB ioIn ioOut ak hk hist dr pub e (cpt 19 e b)) (some 36)
          * reqV (cstK U) (valsF_u1 U P D aB hB ioIn ioOut ak hk hist dr pub e (cpt 19 e b)) 22 20 [21, 22]) b := by
  subst hn
  have hv := fun b => dzcU1_vals U P D Pb Lay B hrl aB hB ioIn ioOut ak hk e b hist dr pub (hp0 b) (hp1 b) (hp2 b)
  rw [cubeSum_host 19 e (valsF_u1 U P D aB hB ioIn ioOut ak hk hist dr pub e) 0 1 2 (some 36) (some 36)
    (((drS 14 17 2).map (Sym.eval hist 14 dr)).map (Fp2.toK U)) (zD_u1 U cnA cnM hist dr)
    (fun v => reqV (cstK U) v 21 11 [12, 13]) (fun v => reqV (cstK U) v 22 20 [21, 22]) f
    (fun x => by rw [hf x, dzcU1_irEval U cnA cnM hist dr]; rfl)
    (fun b y hy => dzcU1_off U P D aB hB ioIn ioOut ak hk e hist dr pub b y hy)
    (fun a : Fin 19 => (((drS 14 20 19).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U)
    ![fun a : Fin 19 => (((drS 10 0 19).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U,
      fun a : Fin 19 => (((drS 13 0 19).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U]
    (fun b => by rw [hv b]; rfl) (fun b => by rw [hv b]; rfl) (fun b => by rw [hv b]; rfl)]

end Cube

/-! ## The batched relation is the IR's zero-check term -/

section Z

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7) (P : BlockParams)
  (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

include hX in
/-- **The gated clauses at `export_u1`**: the gate times the IR's batch of `dzc_w16`'s six clauses
is the weighted sum of the embedded `W16Rels` clauses. -/
theorem dzcU1_cls (cnA cnM : ℕ) (hcnA : cnA < 2 ^ 63) (hcnM : cnM < 2 ^ 63)
    (hS : PrecR (cfgU1 cnA cnM) S) (hist : Hist) (dr : List Fp2) (t : Fin 19 → Bool) (e0 e1 e2 : K) :
    gV (e0 :: e1 :: e2 :: tailD_u1 U P D Pb Lay B t) (some 36)
        * batchV (((drS 14 0 17).map (Sym.eval hist 14 dr)).map (Fp2.toK U))
          (dzcClauses (cstK U) R14 (K14_u1 cnA cnM) (e0 :: e1 :: e2 :: tailD_u1 U P D Pb Lay B t))
      = ∑ i : Fin 6, (dr.getD i Fp2.zero).toK U
          * algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 14 i (.d (splitD c0 t))) := by
  rw [Fin.sum_univ_eq_sum_range (fun i => (dr.getD i Fp2.zero).toK U
    * algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 14 i (.d (splitD c0 t)))) 6]
  simp only [Finset.sum_range_succ, Finset.sum_range_zero, zero_add]
  obtain ⟨h0, h1, h2, h3, h4, h5⟩ := relClD_u1_alg U P D hX Pb Lay B cnA cnM hS t
  rw [h0, h1, h2, h3, h4, h5]
  simp only [gV_some, batchV, dzcClauses, R14, K14_u1, L16, List.zipIdx_cons, List.zipIdx_nil, List.map_cons,
    List.map_nil, List.sum_cons, List.sum_nil, List.getD_cons_zero, List.getD_cons_succ, tailD_u1]
  rw [muK_getD U hist dr 0 (by norm_num), muK_getD U hist dr 1 (by norm_num), muK_getD U hist dr 2 (by norm_num),
    muK_getD U hist dr 3 (by norm_num), muK_getD U hist dr 4 (by norm_num), muK_getD U hist dr 5 (by norm_num),
    cK_two_nat U cnA hcnA, cK_two_nat U cnM hcnM]
  simp (disch := norm_num) only [cK_base, cK_p16] <;> push_cast <;> ring

include hX in
/-- **The hosted terms at `export_u1`**: the gate times the IR's requantization hosts (`sao = 21`,
`sdown = 22`) are the embedded `W16Rels` hosted terms. -/
theorem dzcU1_gh (cnA cnM : ℕ) (hS : PrecR (cfgU1 cnA cnM) S) (t : Fin 19 → Bool) (e0 e1 e2 : K) :
    gV (e0 :: e1 :: e2 :: tailD_u1 U P D Pb Lay B t) (some 36)
        * reqV (cstK U) (e0 :: e1 :: e2 :: tailD_u1 U P D Pb Lay B t) 21 11 [12, 13]
      = algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 14 0 (.d (splitD c0 t)))
    ∧ gV (e0 :: e1 :: e2 :: tailD_u1 U P D Pb Lay B t) (some 36)
        * reqV (cstK U) (e0 :: e1 :: e2 :: tailD_u1 U P D Pb Lay B t) 22 20 [21, 22]
      = algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 14 1 (.d (splitD c0 t))) := by
  obtain ⟨h0, h1⟩ := relGhD_u1_alg U P D hX Pb Lay B cnA cnM hS t
  rw [h0, h1]
  refine ⟨?_, ?_⟩
  all_goals (simp only [gV_some, reqV, L16, List.zipIdx_cons, List.zipIdx_nil, List.map_cons, List.map_nil,
    List.sum_cons, List.sum_nil, List.getD_cons_zero, List.getD_cons_succ, tailD_u1] <;>
    simp (disch := norm_num) only [cK_base, cK_p16] <;> push_cast <;> ring)

include hU hX in
/-- **`SC_DZC`'s batched relation at `export_u1` is the IR's zero-check term**: the six gated clauses
(`relCl 14`), the ten LogUp helper relations (`xcDzcU1`), and the pad term (`pwDzcU1`, weights `ζ^j`). -/
theorem dzcU1_Z (cnA cnM : ℕ) (hcnA : cnA < 2 ^ 63) (hcnM : cnM < 2 ^ 63)
    (hS : PrecR (cfgU1 cnA cnM) S) (hist : Hist) (dr : List Fp2) (bga : Fp2 × Fp2 × Fp2)
    (hα : hist.alpha = bga.2.2) (hγ : hist.gamma = bga.2.1) (t : Fin 19 → Bool) (e0 e1 e2 : K) :
    (∑ κ : Fin (6 + 10), (dr.getD κ Fp2.zero).toK U
        * (if (κ : ℕ) < 6 then algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 14 κ (.d (splitD c0 t)))
          else xcDzcU1 U P D Pb Lay B bga κ t))
      + (dr.getD 16 Fp2.zero).toK U
        * ∑ j : Fin 19, ((dr.getD 19 Fp2.zero).toK U) ^ (j : ℕ) * pwDzcU1 U P D Pb Lay B j t
    = zD_u1 U cnA cnM hist dr (e0 :: e1 :: e2 :: tailD_u1 U P D Pb Lay B t) := by
  have hlks : (lks14_u1.map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 14 dr))).map
      (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U)) = lksX_u1 U bga := by
    unfold lksX_u1 lks14_u1
    rw [lksS_eval c0 shD .D hist (histOf bga.1 bga.2.1 bga.2.2 []) 14 14 dr [] hα hγ]
  have hlk : lkRels (cstK U) (e0 :: e1 :: e2 :: tailD_u1 U P D Pb Lay B t) 26 0 (lksX_u1 U bga)
      = lkRels (cstK U) (valsXD_u1 U P D Pb Lay B t) 26 0 (lksX_u1 U bga) := by
    refine lkRels_congr (cstK U) _ _ 26 0 (lksX_u1 U bga) (fun l hl tt htt => ?_) (fun i _ => ?_)
    · have h5 : 5 ≤ tt.2 := pos_map (Fp2.toK U) _ (fun q => 5 ≤ q)
        (pos_map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 14 []) lks14_u1 (fun q => 5 ≤ q) lks14_u1_pos)
        l hl tt htt
      exact getD3 e0 e1 e2 0 0 0 _ _ (by omega)
    · exact getD3 e0 e1 e2 0 0 0 _ _ (by omega)
  have hlkl : (lkRels (cstK U) (valsXD_u1 U P D Pb Lay B t) 26 0 (lksX_u1 U bga)).length = 10 := by
    rw [lkRels_length]
    unfold lksX_u1
    rw [List.length_map, List.length_map, lks14_u1_length]
  have hpd : padPls (e0 :: e1 :: e2 :: tailD_u1 U P D Pb Lay B t) grp14_u1
      = padPls (valsXD_u1 U P D Pb Lay B t) grp14_u1 := by
    refine padPls_congr _ _ grp14_u1 (fun g hg => ?_)
    rw [grp14_u1_eq] at hg
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hg
    subst hg
    refine ⟨getD3 e0 e1 e2 0 0 0 _ _ (by norm_num), fun p hp => getD3 e0 e1 e2 0 0 0 _ _ ?_⟩
    have := (List.mem_range'_1.mp hp).1
    omega
  have hpdl : (padPls (valsXD_u1 U P D Pb Lay B t) grp14_u1).length = 19 := by
    rw [grp14_u1_eq]
    simp [padPls]
  have hA := dzcU1_cls U P D hX Pb Lay B cnA cnM hcnA hcnM hS hist dr t e0 e1 e2
  have hLg : logupSem (cstK U) (e0 :: e1 :: e2 :: tailD_u1 U P D Pb Lay B t) 26
      (fun k => (((drS 14 0 17).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD (6 + k) 0) 0
      ((lks14_u1.map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 14 dr))).map
        (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U)))
      = ∑ i : Fin 10, (dr.getD (6 + i) Fp2.zero).toK U
          * (lkRels (cstK U) (valsXD_u1 U P D Pb Lay B t) 26 0 (lksX_u1 U bga)).getD i 0 := by
    rw [logupSem_eq_wsum, hlks, hlk, wsum_eq_sum,
      Fin.sum_univ_eq_sum_range (fun i => (((drS 14 0 17).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD
        (6 + (0 + i)) 0 * (lkRels (cstK U) (valsXD_u1 U P D Pb Lay B t) 26 0 (lksX_u1 U bga)).getD i 0), hlkl,
      Fin.sum_univ_eq_sum_range (fun i => (dr.getD (6 + i) Fp2.zero).toK U
        * (lkRels (cstK U) (valsXD_u1 U P D Pb Lay B t) 26 0 (lksX_u1 U bga)).getD i 0) 10]
    refine Finset.sum_congr rfl (fun i hi => ?_)
    rw [Nat.zero_add, muK_getD U hist dr (6 + i) (by have := Finset.mem_range.mp hi; omega)]
  have hP : padSem (cstK U) (e0 :: e1 :: e2 :: tailD_u1 U P D Pb Lay B t)
      ((((drS 14 0 17).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD 16 0)
      (Fp2.toK U ∘ (Sym.eval hist 14 dr ∘ fun j => Sym.pow (Sym.dr 14 19) j)) 0 grp14_u1
      = (dr.getD 16 Fp2.zero).toK U * ∑ j : Fin 19, ((dr.getD 19 Fp2.zero).toK U) ^ (j : ℕ)
          * pwDzcU1 U P D Pb Lay B j t := by
    rw [padSem_eq_wsum _ (cstW_map_std U), hpd, wsum_eq_sum, muK_getD U hist dr 16 (by norm_num)]
    refine congrArg (fun z => (dr.getD 16 Fp2.zero).toK U * z) ?_
    unfold pwDzcU1
    rw [Fin.sum_univ_eq_sum_range (fun j => (Fp2.toK U ∘ (Sym.eval hist 14 dr ∘ fun j => Sym.pow (Sym.dr 14 19) j))
      (0 + j) * (padPls (valsXD_u1 U P D Pb Lay B t) grp14_u1).getD j 0), hpdl,
      Fin.sum_univ_eq_sum_range (fun j => ((dr.getD 19 Fp2.zero).toK U) ^ j
        * (padPls (valsXD_u1 U P D Pb Lay B t) grp14_u1).getD j 0) 19]
    refine Finset.sum_congr rfl (fun j _ => ?_)
    rw [Nat.zero_add]
    show (zpowW (Sym.eval hist 14 dr (Sym.dr 14 19)) j).toK U * _ = _
    rw [toK_zpowW U hU]
    simp [Sym.eval, drawAt]
  unfold zD_u1
  rw [hLg, hP, hA, Fin.sum_univ_add]
  have hc : ∀ i : Fin 6, (i : ℕ) < 6 := fun i => i.isLt
  have hn : ∀ i : Fin 10, ¬ (6 + (i : ℕ) < 6) := fun i => by omega
  simp only [Fin.val_castAdd, Fin.val_natAdd, hc, hn, ↓reduceIte]
  unfold xcDzcU1
  simp only [Nat.add_sub_cancel_left]
  ring

end Z

/-! ## The hosted matmuls (`SC_WO`, `SC_DMM`) -/

section Mm

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

/-- A point of `7 + 12` coordinates read off one draw list. -/
theorem append_draws_u1 (dr : List Fp2) :
    Fin.append (fun i : Fin 7 => (dr.getD i Fp2.zero).toK U)
        (fun a : Fin 12 => (dr.getD (7 + a) Fp2.zero).toK U)
      = fun t : Fin (7 + 12) => (dr.getD t Fp2.zero).toK U := by
  funext t
  refine Fin.addCases (fun i => ?_) (fun i => ?_) t
  · rw [Fin.append_left, Fin.val_castAdd]
  · rw [Fin.append_right, Fin.val_natAdd]

/-- `Dom::Q`'s head-slot-and-dimension bits (`12` bits) as the product `(CgU1 × CjU1) × CdU1`. -/
def eHQ_u1 : (Fin 12 → Bool) ≃ (CgU1 × CjU1) × CdU1 :=
  ⟨splitHQ c0, fun x => Fin.append (Fin.append x.1.1 x.1.2) x.2, append_splitHQ_u1, splitHQ_append c0⟩

theorem sum_HQ_u1 {M : Type} [AddCommMonoid M] (F : (CgU1 × CjU1) × CdU1 → M) :
    ∑ x, F x = ∑ c : Fin 12 → Bool, F (splitHQ c0 c) :=
  (Fintype.sum_equiv eHQ_u1 (fun c => F (splitHQ c0 c)) F (fun _ => rfl)).symm

include hX in
/-- **`SC_WO`'s cube sum at `export_u1`** (slot `10`, inner width `12`): the multilinear extension
of `relMm 14 0` (`Σ_c O(t, c)·W_o(c, w)`) at its claim point `(r_q, r_j)`. -/
theorem mm_woU1 (hrl : 0 < rowLog P .a) (pubs : PubTabs) (hpub : PubR U c0 pubs Pb Lay B)
    (cnA cnM ioIn ioOut : ℕ) (hs10 : slotShape P 10 = (12, 1, 2)) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (r10 : SlotRec) (hr10 : rs[10]? = some r10) (hc10 : ∀ x ∈ r10.draws, x.Canon) :
    spSum P (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs) bga rs 10
      = mleAt (fun y : Fin (7 + 12) → Bool => algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 14 0 (.d (splitD c0 y))))
          (fun t : Fin (7 + 12) => (r10.draws.getD t Fp2.zero).toK U) := by
  obtain ⟨ak, hk', hslot⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 10 (by norm_num)
  unfold spSum
  have hvs : ((drS 10 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 10)) 10 r10.draws)).length = 7 :=
    drS_length 10 0 7 _
  rw [mm_cube U P D hrl (slotShape P 10).1 (slotShape P 10).2.1
    ((drS 10 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 10)) 10 r10.draws)) 7 12 hvs (by rw [hs10])
    (by norm_num) (offU1 31) (DefW16.aDataRows (cfgU1 cnA cnM) + 2 * ak)
    (pubs 10 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 10)) r10.draws 0)
    (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs 10 (seenOf bga rs 10))
    (fun x => by
      rw [polyS_seenOf U P D _ pubs bga rs 10 r10 hr10 x, hslot, rawSlot10_u1]
      simp only [DefW16.numSlot, rawWo_u1, numTabs_ac, numTabs_pubc, numTabs_nil]
      rw [mmIr_map, mmIr_map, cstS_map, mmIr_eval _ (cstW_map_std U)]
      simp only [List.map_cons, List.map_nil, aFx_eval, pubT_eval, List.getD_cons_zero, List.getD_cons_succ])]
  have hr : (fun i : Fin 7 => (((drS 10 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 10)) 10
      r10.draws)).getD i Fp2.zero).toK U) = fun i : Fin 7 => (r10.draws.getD i Fp2.zero).toK U := by
    funext i
    rw [drS_getD _ 10 0 7 i i.isLt, Nat.zero_add]
    simp [Sym.eval, drawAt]
  rw [hr]
  have hwo : ∀ q : Fin 12 → Bool,
      ((pubs 10 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 10)) r10.draws 0).getD (msbIndex 12 q) Fp2.zero).toK U
        = ∑ y : Fin 12 → Bool, eqDr U r10.draws 7 12 y * algebraMap GF K (B.Wo (splitHQ c0 q) y) :=
    fun q => hpub.wo _ _ hc10 q
  simp only [hwo, eqDr]
  refine (mm_fold (fun z c => aPl U P D (offU1 31) (7 + 12) (Fin.append z c))
    (fun c y => algebraMap GF K (B.Wo (splitHQ c0 c) y)) (fun i : Fin 7 => (r10.draws.getD i Fp2.zero).toK U)
    (fun a : Fin 12 => (r10.draws.getD (7 + a) Fp2.zero).toK U)).trans ?_
  refine congrArg₂ mleAt ?_ (append_draws_u1 U r10.draws)
  funext y
  simp only [relMm, map_sum, map_mul]
  rw [sum_HQ_u1]
  refine Finset.sum_congr rfl (fun c _ => ?_)
  show _ = algebraMap GF K (plQ U c0 P D (offU1 31) ((splitD c0 y).1, splitHQ c0 c)) * _
  rw [show algebraMap GF K (plQ U c0 P D (offU1 31) ((splitD c0 y).1, splitHQ c0 c))
      = aPl U P D (offU1 31) 19 (Fin.append (splitD c0 y).1 (Fin.append (Fin.append (splitHQ c0 c).1.1
        (splitHQ c0 c).1.2) (splitHQ c0 c).2)) from aPl_alg U P D hX _ 19 _, append_splitHQ_u1]
  rfl

include hX in
/-- **`SC_DMM`'s cube sum at `export_u1`** (slot `13`, inner width `14`): the multilinear extension
of `relMm 14 1` (`Σ_f H(t, f)·W_d(f, w)`) at its claim point `(r_row, r_j)`. -/
theorem mm_dmmU1 (hrl : 0 < rowLog P .a) (pubs : PubTabs) (hpub : PubR U c0 pubs Pb Lay B)
    (cnA cnM ioIn ioOut : ℕ) (hs13 : slotShape P 13 = (14, 1, 2)) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (r13 : SlotRec) (hr13 : rs[13]? = some r13) (hc13 : ∀ x ∈ r13.draws, x.Canon) :
    spSum P (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs) bga rs 13
      = mleAt (fun y : Fin (7 + 12) → Bool => algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 14 1 (.d (splitD c0 y))))
          (fun t : Fin (7 + 12) => (r13.draws.getD t Fp2.zero).toK U) := by
  obtain ⟨ak, hk', hslot⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 13 (by norm_num)
  unfold spSum
  have hvs : ((drS 13 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 13)) 13 r13.draws)).length = 7 :=
    drS_length 13 0 7 _
  rw [mm_cube U P D hrl (slotShape P 13).1 (slotShape P 13).2.1
    ((drS 13 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 13)) 13 r13.draws)) 7 14 hvs (by rw [hs13])
    (by norm_num) (offU1 53) (DefW16.aDataRows (cfgU1 cnA cnM) + 2 * ak)
    (pubs 13 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 13)) r13.draws 0)
    (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs 13 (seenOf bga rs 13))
    (fun x => by
      rw [polyS_seenOf U P D _ pubs bga rs 13 r13 hr13 x, hslot, rawSlot13_u1]
      simp only [DefW16.numSlot, rawDmm_u1, numTabs_ac, numTabs_pubc, numTabs_nil]
      rw [mmIr_map, mmIr_map, cstS_map, mmIr_eval _ (cstW_map_std U)]
      simp only [List.map_cons, List.map_nil, aFx_eval, pubT_eval, List.getD_cons_zero, List.getD_cons_succ])]
  have hr : (fun i : Fin 7 => (((drS 13 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 13)) 13
      r13.draws)).getD i Fp2.zero).toK U) = fun i : Fin 7 => (r13.draws.getD i Fp2.zero).toK U := by
    funext i
    rw [drS_getD _ 13 0 7 i i.isLt, Nat.zero_add]
    simp [Sym.eval, drawAt]
  rw [hr]
  have hwd : ∀ f : Fin 14 → Bool,
      ((pubs 13 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 13)) r13.draws 0).getD (msbIndex 14 f) Fp2.zero).toK U
        = ∑ y : Fin 12 → Bool, eqDr U r13.draws 7 12 y * algebraMap GF K (B.Wd f y) :=
    fun f => hpub.wd _ _ hc13 f
  simp only [hwd, eqDr]
  refine (mm_fold (fun z c => aPl U P D (offU1 53) (7 + 14) (Fin.append z c))
    (fun c y => algebraMap GF K (B.Wd c y)) (fun i : Fin 7 => (r13.draws.getD i Fp2.zero).toK U)
    (fun a : Fin 12 => (r13.draws.getD (7 + a) Fp2.zero).toK U)).trans ?_
  refine congrArg₂ mleAt ?_ (append_draws_u1 U r13.draws)
  funext y
  simp only [relMm, map_sum, map_mul]
  refine Finset.sum_congr rfl (fun c _ => ?_)
  show _ = algebraMap GF K (plF U c0 P D (offU1 53) ((splitD c0 y).1, c)) * _
  rw [show algebraMap GF K (plF U c0 P D (offU1 53) ((splitD c0 y).1, c))
      = aPl U P D (offU1 53) 21 (Fin.append (splitD c0 y).1 c) from aPl_alg U P D hX _ 21 _]
  rfl

end Mm

/-! ## `SC_DZC`'s named identity at `export_u1` -/

section Form

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K]

/-- **`SC_DZC`'s named identity at `export_u1` (`FormAt` at host `14`)**, parametric in per-layer
`(cnA, cnM)` (with `cnA, cnM < 2 ^ 63`): for every algebra data `dt` whose host-`14` tables are
`W16Rels`' relation tables of `xtU1` (`relCl 14`, `relGh 14`, `relMm 14`, embedded), the LogUp
entries `xcDzcU1`, and the pad planes `pwDzcU1`, on every outcome whose verified slots are hosts
exactly when their definitions host slots, `SC_DZC`'s certified polynomial at the drawn challenges
IS its unmasked residual. -/
theorem formAt_dzcU1 (U : K)
    (hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) {L : ℕ}
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
    (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws) (hsl : P.geom.slots = W16R2.shieldSlots)
    (cnA cnM : ℕ) (hcnA : cnA < 2 ^ 63) (hcnM : cnM < 2 ^ 63)
    (ioIn ioOut : ℕ) (pubs : PubTabs)
    (hdef : P.define = defineS (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
    (hS : PrecR (cfgU1 cnA cnM) S) (_hL : LayR Lay) (hpub : PubR U c0 pubs Pb Lay B)
    (dt : AlgData K L (algShapeU1 P hdr)) (cu : Cuts3 L) (rt : RootsO)
    (hcl : ∀ bga (κ : Fin 16) (b : Fin 19 → Bool), dt.cl 14 cu rt bga κ b
      = if (κ : ℕ) < 6 then algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 14 κ (.d (splitD c0 b)))
        else xcDzcU1 U P D Pb Lay B bga κ b)
    (hpw : ∀ (j : Fin 19) (b : Fin 19 → Bool), dt.pw 14 cu rt j b = pwDzcU1 U P D Pb Lay B j b)
    (hgh : ∀ (i : Fin 2) (b : Fin 19 → Bool),
      dt.gh 14 cu rt i b = algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 14 i (.d (splitD c0 b))))
    (hmm : ∀ (i : Fin 2) (b : Fin 19 → Bool),
      dt.mm 14 cu rt i b = algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 14 i (.d (splitD c0 b))))
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    FormAt U P (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeU1 P hdr) dt hcard 0 cu rt k h).Φ) bga rs 14 := by
  have hs14 : slotShape P 14 = (19, 1, 5) := by simp only [slotShape, hsl]; decide
  have hs10 : slotShape P 10 = (12, 1, 2) := by simp only [slotShape, hsl]; decide
  have hs13 : slotShape P 13 = (14, 1, 2) := by simp only [slotShape, hsl]; decide
  have hcan : ∀ (j : ℕ) (rj : SlotRec), rs[j]? = some rj → ∀ x ∈ rj.draws, x.Canon := by
    intro j rj hrj
    obtain ⟨dfj, hdfj, -⟩ := hslots j rj hrj
    have h' : defineS (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs j
        (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) rj.draws = .ok dfj := hdef ▸ hdfj
    have hc := (defineS_ok h').1
    unfold HistCanon at hc
    exact hc.2.2.2
  obtain ⟨ak14, hk14, hsl14⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 14 (by norm_num)
  obtain ⟨ak10, hk10, hsl10⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 10 (by norm_num)
  obtain ⟨ak13, hk13, hsl13⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 13 (by norm_num)
  refine formAt_two U hcard P (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs hdef D _ dt cu rt bga rs 14
    (by decide) 10 13 (.dr 14 17) (.dr 14 18) (by rw [hsl14, rawSlot14_u1]; rfl)
    (by rw [hsl10, rawSlot10_u1]; rfl) (by rw [hsl13, rawSlot13_u1]; rfl)
    (by norm_num) (by norm_num) hslots (fun r hr => ?_)
  have hlen : 14 < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨r10, hr10⟩ : ∃ r10, rs[10]? = some r10 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  obtain ⟨r13, hr13⟩ : ∃ r13, rs[13]? = some r13 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  set hist := histOf bga.1 bga.2.1 bga.2.2 (rs.take 14) with hhist
  -- the hosted slots
  rw [mm_woU1 U P D hX Pb Lay B hrl pubs hpub cnA cnM ioIn ioOut hs10 bga rs r10 hr10 (hcan 10 r10 hr10),
    mm_dmmU1 U P D hX Pb Lay B hrl pubs hpub cnA cnM ioIn ioOut hs13 bga rs r13 hr13 (hcan 13 r13 hr13)]
  -- the host
  unfold spSum
  rw [dzcU1_cube U P D Pb Lay B hrl cnA cnM (DefW16.aDataRows (cfgU1 cnA cnM)) (DefW16.hDataRows (cfgU1 cnA cnM))
    ioIn ioOut ak14 hk14 (slotShape P 14).1 (slotShape P 14).2.1 (by rw [hs14]) hist r.draws
    (pubs 14 hist r.draws) (hpub.dzcGamA _ _) (hpub.dzcGamM _ _) (hpub.dzcGate _ _)
    (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs 14 (seenOf bga rs 14))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 14 r hr x, hsl14, rawSlot14_u1]; rfl)]
  rw [hostSp_Φ]
  unfold hostPhi
  refine congrArg₂ (· - ·) ?_ ?_
  · -- the host's sum
    refine Finset.sum_congr rfl (fun t _ => ?_)
    have hv := dzcU1_vals U P D Pb Lay B hrl (DefW16.aDataRows (cfgU1 cnA cnM)) (DefW16.hDataRows (cfgU1 cnA cnM))
      ioIn ioOut ak14 hk14 (slotShape P 14).2.1 t hist r.draws (pubs 14 hist r.draws)
      (hpub.dzcGamA _ _ t) (hpub.dzcGamM _ _ t) (hpub.dzcGate _ _ t)
    refine hostPoly_ext _ _ _ _ _ _ _ _ _ _ _ t (fun a => ?_) ?_ (fun i => ?_) (fun i j => ?_) (fun i => ?_)
    · -- τ
      have ha : (a : ℕ) < 19 := a.isLt
      unfold segAt
      rw [dite_eq_left (by show 20 + (a : ℕ) < 39; omega), drS_getD _ 14 20 19 a ha]
      simp only [Fin.val_cast, Sym.eval, drawAt, ite_true]
      first | done | rfl
    · -- the batch
      show batched _ _ _ t = zD_u1 U cnA cnM hist r.draws (valsF_u1 U P D (DefW16.aDataRows (cfgU1 cnA cnM))
        (DefW16.hDataRows (cfgU1 cnA cnM)) ioIn ioOut ak14 hk14 hist r.draws (pubs 14 hist r.draws)
        (slotShape P 14).2.1 (cpt 19 (slotShape P 14).2.1 t))
      rw [hv, ← dzcU1_Z U hU P D hX Pb Lay B cnA cnM hcnA hcnM hS hist r.draws (hist.beta, hist.gamma, hist.alpha)
        rfl rfl t]
      unfold batched
      have hz : segLn ((algShapeU1 P hdr).dl 14) .zeta = 1 := rfl
      rw [ite_eq_left hz, ite_eq_left hz]
      dsimp only
      refine congrArg₂ (· + ·) (Finset.sum_congr rfl (fun κ _ => ?_))
        (congrArg₂ (· * ·) ?_ (Finset.sum_congr rfl (fun j _ => ?_)))
      · have hκ : (κ : ℕ) < 16 := κ.isLt
        rw [hcl _ κ t]
        refine congrArg (· * _) ?_
        unfold segAt
        rw [dite_eq_left (by show 0 + (κ : ℕ) < 39; omega)]
        simp only [Fin.val_cast]
        rw [show segOff ((algShapeU1 P hdr).dl 14) .mu = 0 from rfl, Nat.zero_add]
        first | done | rfl
      · unfold segAt
        rw [dite_eq_left (by show 0 + 16 < 39; omega)]
        first | done | rfl
      · rw [hpw j t]
        refine congrArg (fun z => z ^ (j : ℕ) * pwDzcU1 U P D Pb Lay B j t) ?_
        unfold segAt
        rw [dite_eq_left (by show 19 + 0 < 39; omega)]
        first | done | rfl
    · -- ν
      fin_cases i
      · show segAt _ _ .nu 0 = (((drS 14 17 2).map (Sym.eval hist 14 r.draws)).map (Fp2.toK U)).getD 0 0
        unfold segAt
        rw [dite_eq_left (by show 17 + 0 < 39; omega)]
        first | done | rfl
      · show segAt _ _ .nu 1 = (((drS 14 17 2).map (Sym.eval hist 14 r.draws)).map (Fp2.toK U)).getD 1 0
        unfold segAt
        rw [dite_eq_left (by show 17 + 1 < 39; omega)]
        first | done | rfl
    · -- the hosted claim points
      have hj : (j : ℕ) < 19 := j.isLt
      fin_cases i
      · show algPt U (algShapeU1 P hdr) 14 hist 0 j
          = (((drS 10 0 19).map (Sym.eval hist 14 r.draws)).getD j Fp2.zero).toK U
        rw [drS_getD _ 10 0 19 j hj, Nat.zero_add]
        first | done | rfl
      · show algPt U (algShapeU1 P hdr) 14 hist 1 j
          = (((drS 13 0 19).map (Sym.eval hist 14 r.draws)).getD j Fp2.zero).toK U
        rw [drS_getD _ 13 0 19 j hj, Nat.zero_add]
        first | done | rfl
    · -- the hosted terms
      rw [algH_gh U _ dt 14 cu rt hist i (fun h => absurd h.1 (by decide)), hgh i t]
      fin_cases i
      · show _ = gV (valsF_u1 U P D (DefW16.aDataRows (cfgU1 cnA cnM)) (DefW16.hDataRows (cfgU1 cnA cnM)) ioIn ioOut
            ak14 hk14 hist r.draws (pubs 14 hist r.draws) (slotShape P 14).2.1 (cpt 19 (slotShape P 14).2.1 t))
            (some 36)
          * reqV (cstK U) (valsF_u1 U P D (DefW16.aDataRows (cfgU1 cnA cnM)) (DefW16.hDataRows (cfgU1 cnA cnM))
            ioIn ioOut ak14 hk14 hist r.draws (pubs 14 hist r.draws) (slotShape P 14).2.1
            (cpt 19 (slotShape P 14).2.1 t)) 21 11 [12, 13]
        rw [hv, (dzcU1_gh U P D hX Pb Lay B cnA cnM hS t _ _ _).1]
        first | done | rfl
      · show _ = gV (valsF_u1 U P D (DefW16.aDataRows (cfgU1 cnA cnM)) (DefW16.hDataRows (cfgU1 cnA cnM)) ioIn ioOut
            ak14 hk14 hist r.draws (pubs 14 hist r.draws) (slotShape P 14).2.1 (cpt 19 (slotShape P 14).2.1 t))
            (some 36)
          * reqV (cstK U) (valsF_u1 U P D (DefW16.aDataRows (cfgU1 cnA cnM)) (DefW16.hDataRows (cfgU1 cnA cnM))
            ioIn ioOut ak14 hk14 hist r.draws (pubs 14 hist r.draws) (slotShape P 14).2.1
            (cpt 19 (slotShape P 14).2.1 t)) 22 20 [21, 22]
        rw [hv, (dzcU1_gh U P D hX Pb Lay B cnA cnM hS t _ _ _).2]
        first | done | rfl
  · -- the hosted slots' sums
    have hM : ∀ i : Fin 2, algM (algShapeU1 P hdr) dt 14 cu rt i
        = fun b => algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 14 i (.d (splitD c0 b))) := fun i => by
      rw [algM_mm _ dt 14 cu rt i (fun h => absurd h.1 (by decide))]
      exact funext (hmm i)
    have hP0 : algPt U (algShapeU1 P hdr) 14 hist 0
        = fun t : Fin (7 + 12) => (r10.draws.getD t Fp2.zero).toK U := by
      funext t
      show algDrawAt U hist 10 t = _
      rw [algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 14 10 t r10 (by decide) hr10]
      first | done | rfl
    have hP1 : algPt U (algShapeU1 P hdr) 14 hist 1
        = fun t : Fin (7 + 12) => (r13.draws.getD t Fp2.zero).toK U := by
      funext t
      show algDrawAt U hist 13 t = _
      rw [algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 14 13 t r13 (by decide) hr13]
      first | done | rfl
    rw [Fin.sum_univ_two, hM 0, hM 1, hP0, hP1]
    refine congrArg₂ (· + ·) (congrArg₂ (· * ·) ?_ rfl) (congrArg₂ (· * ·) ?_ rfl)
    · unfold segAt
      beta_reduce
      rw [dite_eq_left (by show 17 + 0 < 39; omega)]
      first | done | rfl
    · unfold segAt
      beta_reduce
      rw [dite_eq_left (by show 17 + 1 < 39; omega)]
      first | done | rfl

end Form

end ZK60.Exec.Block.Join.W16U1.Dzc
