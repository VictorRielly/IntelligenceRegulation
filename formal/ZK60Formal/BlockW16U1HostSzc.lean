/-
D63 W16R2 Shieldstral (`export_u1`) port: **host `SC_SZC` (slot 17) and its hosted slots `SC_RS` (slot 4)
and `SC_SCORE` (slot 8)** at `cfgU1 cnA cnM` (`W16R2_SHIELD_T128_H24`).

Port of `BlockHostSzc.lean` from the development rung (`wrho = 17`, `score = 18`, `lt = 5`, `lh = 4`,
`ldh = 6`, `Dom::Ht` 9, `Dom::S` 14, 10 `Dom::S` planes, 9 lookups → 5 LogUp helpers, 10 batch entries,
`rsScale = 32`) to the installed Shieldstral export `export_u1` (`wrho = 16`, `score = 19`, `lt = 7`,
`lh = 5`, `ldh = 7`, `Dom::Ht` 12, `Dom::S` 19, 8 `Dom::S` planes `39..46` with single-limb `sr = [45]`
and `sg = [46]`, 7 lookups → 4 LogUp helpers `17..20` (3 pairs + 1 single), exp helper `21`, 9 batch
entries `0..8`, `rsScale = 128`).

Because `rawSlot (cfgU1 cnA cnM) s = rawSlot c0 s` by `rfl` for `s ∈ {4, 8, 17}` (neither `cnA` nor
`cnM` enters these three slots), `formAt_szcU1` is parametric in `cnA cnM : ℕ` via `progW16_slot` and
`numTabs` without hardcoding reserved-row indices.

* `rawTabs17_u1`, `rawTabs4_u1`, `rawTabs8_u1`, `RSzU1`, `KSzU1`, `irS_u1`, **`rawSlot17_eq`**,
  **`rawSlot4_eq`**, **`rawSlot8_eq`**: the three raw slots at `cfgU1 cnA cnM`;
* `restS_u1`, **`valsXS_u1`**: `SC_SZC`'s value list on the 19-bit cube (`0 :: 0 :: 0 :: restS_u1`);
* **`xcSzcU1`**: the batch's entries `4..8` (the four LogUp helper relations at tables `14..17` and the
  exp tuple's relation at table `18`) on `valsXS_u1`;
* **`szc_point_u1`**, **`szc_cube_u1`**, **`rs_cube_u1`**, **`score_cube_u1`**: the three slots'
  cube sums on `Dom::S` (19 bits), `Dom::Ht` (12 bits), and `SC_SCORE` (10 main + 2 ext bits);
* **`formAt_szcU1`**: `FormAt` at host `17` (`SC_SZC`) for every `(cnA, cnM)`.

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.BlockW16U1Base
import ZK60Formal.BlockHostSzc

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16U1.Szc

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly hostPhi hostPhi_eq batched SlotPoly segAt mle2 mleAt_append mleAt_rowOnly
  mleAt_lin2 mleAt_one rs_cubeSum rs_host_cubeSum eqPoly_append)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl aPl_alg hPl tabK_ph_cpt hTab_eval tabK_pa_cpt tabK_paHead_cpt eqT_eval pubT_eval
  cstS_map cstK cstK_base cstK_p16 sum_append mleAt_append_bits lkRels_congr lksS_eval formAt_two remR)
open ZK60.Exec.Block.Join.W16.Szc (drs drs_length drs_getD taA shapedS amdS nbS getD_cons3 cK cP remR2_lo remR2_hi
  remVal_gt bits_append sum_eq_bits mleAt_eq4 mleAt_add_c mleAt_c_sub mleAt_sub' score_gen ptv drs_ptv mem17
  ev_mul ev_base ev_own ev_hist ptv_own ptv_hist drsK_getD)
open ZK60.Exec.Block.Join.R13H (plQ plK plS plH splitS splitHt splitS_append LayR gS_oneR gHt_oneR PubR PrecR)
open ZK60.Exec.Block.Join.W16U1
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build (Cst cstW hostTerms gV L16 reqV batchV szcIr szcClauses szcDelta szcExp szcIr_eval SzcR
  SzcK rsIr rsIr_eval bilIr bilIr_eval LkD logupSem padSem)
open ZK60.Exec.Slot.Compose (szcIr_map rsIr_map bilIr_map cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Exec.Slot.W16R2 (segLn segOff segSum)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-! ## 1. The three raw slots at `export_u1` (`cfgU1 cnA cnM`) -/

/-- An `H` table (`re + u·im`) on `Dom::S`'s `19` coordinates at `export_u1`. -/
def taHU1 (re im m : ℕ) : TabS := .priv ⟨.h, [(re, false), (im, true)], 19, DefW16.rhoC 0 19, m, 0⟩

/-- `SC_SZC`'s raw tables (19 tables): `eq(τ)`, `eq(p_ht)`, `eq(P_score)`, the mask, the 8 `Dom::S` planes
`39..46` (`s, rsl[0..1], zsel, e, pp, sr[0], sg[0]`), `MX` (`4`), `SUM` (`5`), the 4 LogUp helpers
`17..20`, and the exp helper `21`. -/
def rawTabs17_u1 : List TabS :=
  [.eq (drs 17 0 19) 0, .eq (drs 4 0 12) 0, .eq (drs 8 0 19) 0, .pub 0,
   taA (offU1 39) 19 0, taA (offU1 40) 19 0, taA (offU1 41) 19 0, taA (offU1 42) 19 0,
   taA (offU1 43) 19 0, taA (offU1 44) 19 0, taA (offU1 45) 19 0, taA (offU1 46) 19 0,
   taA (offU1 4) 12 0, taA (offU1 5) 12 0,
   taHU1 (hOffU1 17).1 (hOffU1 17).2 0, taHU1 (hOffU1 18).1 (hOffU1 18).2 0,
   taHU1 (hOffU1 19).1 (hOffU1 19).2 0, taHU1 (hOffU1 20).1 (hOffU1 20).2 0,
   taHU1 (hOffU1 21).1 (hOffU1 21).2 0]

/-- `SC_SZC`'s table positions at `export_u1` (1-limb `sr = [10]`, `sg = [11]`, `mx = 12`, `sum = 13`,
`h0 = 14`, `hx = 18`, no gates). -/
def RSzU1 : SzcR := ⟨0, 1, 2, 3, 4, 7, 8, 9, [10], [11], [5, 6], 12, 13, 14, 18, none, none⟩

theorem RSzU1_gS : RSzU1.gS = none := rfl

/-- `SC_SZC`'s constants at `export_u1`: `−MASK_SCORE = 127`, `f_p = 12`, score shift `19`. -/
def KSzU1 : SzcK := ⟨127, 12, 19⟩

/-- `SC_SZC`'s lookups (`lookups_w16` on `Dom::S` at `export_u1`: 7 lookups). -/
abbrev lksS17_u1 : List (LkD Sym) := DefW16.lksS c0 shapedS .S

theorem lksS17_u1_length : lksS17_u1.length = 7 := by decide

def muS_u1 : List Sym := drs 17 19 9
def nuS_u1 : List Sym := [.dr 17 28, .dr 17 29]

/-- `SC_SZC`'s IR at `export_u1`. -/
def irS_u1 : ZK60.Exec.Slot.Ir Sym :=
  szcIr DefW16.cstS RSzU1 KSzU1 lksS17_u1 muS_u1 nuS_u1 amdS nbS (.dr 4 12) (fun j => Sym.pow Sym.zero j) []

theorem rawSlot17_eq (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 17
    = ⟨rawTabs17_u1, irS_u1, [(4, .mul (.dr 17 28) (.base 128)), (8, .dr 17 29)], [.dr 17 28, .dr 17 29]⟩ := by
  rw [DefW16.rawSlot_shieldU1_ne14 cnA cnM 17 (by decide)]
  rfl

/-- `SC_RS`'s raw tables at `export_u1`: `eq(p_ht)` on the first 12 variables, the mask, `E` (`43`), `ZSEL` (`42`). -/
def rawTabs4_u1 : List TabS :=
  [.eq (drs 4 0 12) 0, .pub 0, taA (offU1 43) 19 0, taA (offU1 42) 19 0]

theorem rawSlot4_eq (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 4
    = ⟨rawTabs4_u1, rsIr DefW16.cstS 0 1 2 3 none (.dr 4 12), [], []⟩ := rfl

/-- `SC_SCORE`'s raw tables at `export_u1`: `eq(r_g)` on the first 3 variables, `QR` (`29`, log 19) read at
`(r_t, ·, r_hj, ·)`, `KR` (`37`, log 17) read at `(r_3, ·, ·)` (extension round `1`). -/
def rawTabs8_u1 : List TabS :=
  [.eq (drs 8 0 3) 0,
   .priv ⟨.a, [(offU1 29, false)], 19,
     (drs 8 5 7).map CoordS.fixed ++ DefW16.rhoC 0 3 ++ (drs 8 3 2).map CoordS.fixed ++ DefW16.rhoC 3 10, 0, 0⟩,
   .priv ⟨.a, [(offU1 37, false)], 17,
     (drs 8 12 7).map CoordS.fixed ++ DefW16.rhoC 0 3 ++ DefW16.rhoC 3 10, 0, 1⟩]

theorem rawSlot8_eq (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 8
    = ⟨rawTabs8_u1, bilIr DefW16.cstS (some 0) 1 2, [], []⟩ := rfl

/-- The `export_u1` slot shapes of slots `17`, `4`, `8`. -/
theorem slotShape_szc_u1 (P : BlockParams) (hsl : P.geom.slots = W16R2.shieldSlots) :
    slotShape P 17 = (19, 1, 4) ∧ slotShape P 4 = (19, 1, 3) ∧ slotShape P 8 = (10, 2, 3) := by
  simp only [slotShape, hsl]
  decide

/-! ## 2. Numbered private tables and `SC_SZC`'s value list at a cube point -/

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- The first 12 coordinates of a `Dom::S` bit vector (`Dom::Ht`'s). -/
def hd12 (b : Fin 19 → Bool) : Fin 12 → Bool := fun a => b (Fin.castAdd 7 a)

theorem hd12_append (r : Fin 12 → Bool) (j : Fin 7 → Bool) : hd12 (Fin.append r j) = r := by
  funext a
  exact Fin.append_left r j a

/-- A numbered `A` table on its own `n` coordinates, at the zero extension. -/
theorem tabK_aSet (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (n e : ℕ) (b : Fin n → Bool)
    (hn : 0 < n) (aB hB ioIn ioOut ak hk off : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    tabK U P D n e (cpt n e b) (TabS.eval ev pub (.priv (DefW16.setRow aB hB ioIn ioOut ak hk
      ⟨.a, [(off, false)], n, DefW16.rhoC 0 n, 0, 0⟩))) = aPl U P D off n b := by
  show tabK U P D n e (cpt n e b)
    (TabS.eval ev pub (.priv ⟨.a, [(off, false)], n, DefW16.rhoC 0 n, aB + 2 * ak, 0⟩)) = _
  rw [aTab_eval, tabK_pa_cpt U P D hrl n e b n hn rfl, castB_rfl]

/-- A numbered `A` table on the first `L ≤ n` main coordinates, at the zero extension. -/
theorem tabK_aHeadSet (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (n e : ℕ) (b : Fin n → Bool)
    (L : ℕ) (hL : 0 < L) (hle : L ≤ n) (aB hB ioIn ioOut ak hk off : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    tabK U P D n e (cpt n e b) (TabS.eval ev pub (.priv (DefW16.setRow aB hB ioIn ioOut ak hk
      ⟨.a, [(off, false)], L, DefW16.rhoC 0 L, 0, 0⟩))) = aPl U P D off L (fun a => b ⟨a, by omega⟩) := by
  show tabK U P D n e (cpt n e b)
    (TabS.eval ev pub (.priv ⟨.a, [(off, false)], L, DefW16.rhoC 0 L, aB + 2 * ak, 0⟩)) = _
  rw [aTab_eval, tabK_paHead_cpt U P D hrl n e b L hL hle]

/-- A numbered `H` table on its own `n` coordinates, at the zero extension. -/
theorem tabK_hSet (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .h) (n e : ℕ) (b : Fin n → Bool)
    (hn : 0 < n) (aB hB ioIn ioOut ak hk re im : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    tabK U P D n e (cpt n e b) (TabS.eval ev pub (.priv (DefW16.setRow aB hB ioIn ioOut ak hk
      ⟨.h, [(re, false), (im, true)], n, DefW16.rhoC 0 n, 0, 0⟩))) = hPl U P D re im n b := by
  show tabK U P D n e (cpt n e b)
    (TabS.eval ev pub (.priv ⟨.h, [(re, false), (im, true)], n, DefW16.rhoC 0 n, hB + 2 * hk, 0⟩)) = _
  rw [hTab_eval, tabK_ph_cpt U P D hrl n e b n hn rfl, castB_rfl]

/-- **`SC_SZC`'s entries from position `3` on at `export_u1`**: the mask, the 8 `Dom::S` planes
(`S8, rs₀, rs₁, ZSEL, E, PP, sr₀, sg₀`), `MX`, `SUM`, the 4 LogUp helpers (`17..20`), and the exp helper (`21`). -/
noncomputable def restS_u1 (P : BlockParams) (D : CmData K P) (mk : K) (b : Fin 19 → Bool) : List K :=
  [mk,
   aPl U P D (offU1 39) 19 b, aPl U P D (offU1 40) 19 b, aPl U P D (offU1 41) 19 b, aPl U P D (offU1 42) 19 b,
   aPl U P D (offU1 43) 19 b, aPl U P D (offU1 44) 19 b, aPl U P D (offU1 45) 19 b, aPl U P D (offU1 46) 19 b,
   aPl U P D (offU1 4) 12 (hd12 b), aPl U P D (offU1 5) 12 (hd12 b),
   hPl U P D (hOffU1 17).1 (hOffU1 17).2 19 b, hPl U P D (hOffU1 18).1 (hOffU1 18).2 19 b,
   hPl U P D (hOffU1 19).1 (hOffU1 19).2 19 b, hPl U P D (hOffU1 20).1 (hOffU1 20).2 19 b,
   hPl U P D (hOffU1 21).1 (hOffU1 21).2 19 b]

/-- **`SC_SZC`'s value list at a cube point with the zero extension** (for any numbering sites `ak, hk`). -/
theorem szc_vals_u1 (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a)
    (aB hB ioIn ioOut ak hk e : ℕ) (b : Fin 19 → Bool) (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    ((DefW16.numTabs aB hB ioIn ioOut ak hk 0 rawTabs17_u1).map (TabS.eval ev pub)).map
        (tabK U P D 19 e (cpt 19 e b))
      = eqPoly (fun a : Fin 19 => (((drs 17 0 19).map ev).getD a Fp2.zero).toK U) (fun a => bit (b a))
        :: eqPoly (fun a : Fin 12 => (((drs 4 0 12).map ev).getD a Fp2.zero).toK U) (fun a => bit (hd12 b a))
        :: eqPoly (fun a : Fin 19 => (((drs 8 0 19).map ev).getD a Fp2.zero).toK U) (fun a => bit (b a))
        :: restS_u1 U P D (((pub 0).getD (msbIndex 19 b) Fp2.zero).toK U) b := by
  have hrlh : 0 < rowLog P .h := hrl
  simp only [rawTabs17_u1, taA, taHU1, DefW16.numTabs, List.map_cons, List.map_nil, eqT_eval, pubT_eval,
    tabK_aSet U P D hrl 19 e b (by norm_num), tabK_aHeadSet U P D hrl 19 e b 12 (by norm_num) (by norm_num),
    tabK_hSet U P D hrlh 19 e b (by norm_num), tabK_pub_cpt]
  rw [tabK_eqFull_cpt U P D 19 e b _ (drs_length ev 17 0 19),
    tabK_eqHead_cpt U P D 19 e b _ 12 (drs_length ev 4 0 12) (by norm_num),
    tabK_eqFull_cpt U P D 19 e b _ (drs_length ev 8 0 19)]
  rfl

end Vals

/-! ## 3. The batch's entries past the named clauses (`valsXS_u1`, `xcSzcU1`) -/

section Xc

variable {K : Type} [Field K] [Algebra GF K]

/-- **`SC_SZC`'s value list without the draws at `export_u1`**: `0, 0, 0`, the causal mask, the 8 `Dom::S`
planes, `MX`, `SUM`, the 4 LogUp helpers (`17..20`), and the exp helper (`21`). -/
noncomputable def valsXS_u1 (U : K) (P : BlockParams) (D : CmData K P) {S : ZK60.Block.BlockShape}
    (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
    (b : Fin 19 → Bool) : List K :=
  0 :: 0 :: 0 :: restS_u1 U P D (algebraMap GF K (B.mask (splitS c0 b))) b

/-- `SC_SZC`'s lookups read in the field, at `α`, `γ` of `bga = (β, γ, α)`. -/
noncomputable def lksK_u1 (U : K) (bga : Fp2 × Fp2 × Fp2) : List (LkD K) :=
  (lksS17_u1.map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 17 []))).map
    (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U))

/-- **The batch's entries of `SC_SZC` past its four named clauses at `export_u1`**: entries `4..7`
LogUp's four helper relations (3 pairs at tables `14..16`, 1 single at table `17`), entry `8` the exp
tuple's relation (table `18`), on `valsXS_u1`. -/
noncomputable def xcSzcU1 (U : K) (P : BlockParams) (D : CmData K P) {S : ZK60.Block.BlockShape}
    (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
    (bga : Fp2 × Fp2 × Fp2) (κ : ℕ) (b : Fin 19 → Bool) : K :=
  (List.replicate 4 0 ++ lkRels (cstK U) (valsXS_u1 U P D Pb Lay B b) 14 0 (lksK_u1 U bga)
    ++ [szcExp (cstK U) RSzU1 KSzU1 (valsXS_u1 U P D Pb Lay B b)
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 17 [] amdS).toK U)
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 17 [] nbS).toK U)]).getD κ 0

end Xc

/-! ## 4. The batch of nine -/

section Lists

variable {R : Type} [CommRing R]

/-- **The batch of nine**: four named clauses, four LogUp helper entries, and the exp relation. -/
theorem batch9 (mu : ℕ → R) (cl : ℕ → R) (xs : List R) (hxs : xs.length = 4) (e : R) :
    ∑ κ : Fin 9, mu κ * (if (κ : ℕ) < 4 then cl κ else (List.replicate 4 0 ++ xs ++ [e]).getD κ 0)
      = wsum (fun k => mu (4 + k)) 0 xs + mu 8 * e + (mu 0 * cl 0 + mu 1 * cl 1 + mu 2 * cl 2 + mu 3 * cl 3) := by
  rcases xs with _ | ⟨x0, _ | ⟨x1, _ | ⟨x2, _ | ⟨x3, _ | ⟨x4, xs⟩⟩⟩⟩⟩ <;>
    simp only [List.length_cons, List.length_nil] at hxs <;> try omega
  rw [Fin.sum_univ_eq_sum_range (fun κ : ℕ => mu κ * (if κ < 4 then cl κ
    else (List.replicate 4 (0 : R) ++ [x0, x1, x2, x3] ++ [e]).getD κ (0 : R))) 9]
  simp (config := { decide := true }) only [Finset.sum_range_succ, Finset.sum_range_zero, wsum, List.replicate_succ,
    List.replicate_zero, List.cons_append, List.nil_append, List.getD_cons_succ, List.getD_cons_zero, ite_true,
    ite_false]
  ring

end Lists

/-! ## 5. Cube splits and named relations at `Dom::S` (`wrho = 16`, single-limb `sr`/`sg`) -/

theorem append_splitS_u1 (b : Fin 19 → Bool) :
    Fin.append (Fin.append (splitS c0 b).1.1 (splitS c0 b).1.2)
      (Fin.append (splitS c0 b).2.1 (splitS c0 b).2.2) = b := by
  funext i
  refine Fin.addCases (fun i5 => ?_) (fun i14 => ?_) i
  · rw [Fin.append_left]
    refine Fin.addCases (fun i3 => ?_) (fun i2 => ?_) i5
    · rw [Fin.append_left]; rfl
    · rw [Fin.append_right]; rfl
  · rw [Fin.append_right]
    refine Fin.addCases (fun i7 => ?_) (fun i7' => ?_) i14
    · rw [Fin.append_left]; rfl
    · rw [Fin.append_right]; rfl

theorem append_splitS_hd_u1 (b : Fin 19 → Bool) :
    Fin.append (Fin.append (splitS c0 b).1.1 (splitS c0 b).1.2) (splitS c0 b).2.1 = hd12 b := by
  funext i
  refine Fin.addCases (fun i5 => ?_) (fun i7 => ?_) i
  · rw [Fin.append_left]
    refine Fin.addCases (fun i3 => ?_) (fun i2 => ?_) i5
    · rw [Fin.append_left]; rfl
    · rw [Fin.append_right]; rfl
  · rw [Fin.append_right]; rfl

theorem append_splitHt_u1 (r : Fin 12 → Bool) :
    Fin.append (Fin.append (splitHt c0 r).1.1 (splitHt c0 r).1.2) (splitHt c0 r).2 = r := by
  funext i
  refine Fin.addCases (fun i5 => ?_) (fun i7 => ?_) i
  · rw [Fin.append_left]
    refine Fin.addCases (fun i3 => ?_) (fun i2 => ?_) i5
    · rw [Fin.append_left]; rfl
    · rw [Fin.append_right]; rfl
  · rw [Fin.append_right]; rfl

/-- **A point of `Dom::S` from a point of `Dom::Ht` (12 bits) and a key token (7 bits).** -/
theorem splitS_app12 (r : Fin 12 → Bool) (j : Fin 7 → Bool) :
    splitS c0 (Fin.append r j : Fin 19 → Bool) = ((splitHt c0 r).1, (splitHt c0 r).2, j) := by
  refine Prod.ext (Prod.ext ?_ ?_) (Prod.ext ?_ ?_)
  · funext i
    exact Fin.append_left r j (Fin.castAdd 7 (Fin.castAdd 2 i))
  · funext i
    exact Fin.append_left r j (Fin.castAdd 7 (Fin.natAdd 3 i))
  · funext i
    exact Fin.append_left r j (Fin.natAdd 5 i)
  · funext i
    refine (congrArg (Fin.append r j : Fin 19 → Bool) (Fin.ext ?_)).trans (Fin.append_right r j i)
    exact (Nat.add_assoc 5 7 i.val).symm

section Rels

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

include hX

theorem alg_plS_u1 (off : ℕ) (b : Fin 19 → Bool) :
    algebraMap GF K (plS U c0 P D off (splitS c0 b)) = aPl U P D off 19 b := by
  unfold plS
  rw [aPl_alg U P D hX, append_splitS_u1]
  rfl

theorem alg_plH_u1 (off : ℕ) (b : Fin 19 → Bool) :
    algebraMap GF K (plH U c0 P D off ((splitS c0 b).1, (splitS c0 b).2.1)) = aPl U P D off 12 (hd12 b) := by
  unfold plH
  rw [aPl_alg U P D hX]
  simp only
  rw [append_splitS_hd_u1]
  rfl

/-- **`SC_SZC`'s four relations at `export_u1`, embedded** (`wrho = 16`, single-limb `sr`/`sg`, `fp = 12`,
gate `gS = 1`). -/
theorem relCl17_alg_u1 (cnA cnM : ℕ) (hS : PrecR (cfgU1 cnA cnM) S) (hL : LayR Lay) (b : Fin 19 → Bool) :
    [algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 17 0 (.s (splitS c0 b))),
      algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 17 1 (.s (splitS c0 b))),
      algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 17 2 (.s (splitS c0 b))),
      algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 17 3 (.s (splitS c0 b)))]
    = [aPl U P D (offU1 42) 19 b * aPl U P D (offU1 42) 19 b - aPl U P D (offU1 42) 19 b,
       aPl U P D (offU1 42) 19 b * (aPl U P D (offU1 4) 12 (hd12 b)
         - algebraMap GF K (B.mask (splitS c0 b)) * (aPl U P D (offU1 39) 19 b + 127) + 127),
       algebraMap GF K (B.mask (splitS c0 b)) * aPl U P D (offU1 43) 19 b * 2 ^ 12
         - aPl U P D (offU1 44) 19 b * aPl U P D (offU1 5) 12 (hd12 b)
         - aPl U P D (offU1 45) 19 b,
       aPl U P D (offU1 46) 19 b + aPl U P D (offU1 45) 19 b + 1 - aPl U P D (offU1 5) 12 (hd12 b)] := by
  have hw : S.wrho = 16 := hS.wrho
  have hfp : S.fp = 12 := hS.fp
  simp only [relCl, gS_oneR B hL, one_mul, hw, hfp, xtU1, remR_lo1,
    remVal_le16 16 (by norm_num), map_sub, map_mul, map_add, map_pow,
    map_ofNat, map_one, alg_plS_u1 U P D hX, alg_plH_u1 U P D hX]

/-- **`SC_SZC`'s second hosted relation (`SC_SCORE`'s requantization, shift `19`), embedded.** -/
theorem relGh171_alg_u1 (cnA cnM : ℕ) (hS : PrecR (cfgU1 cnA cnM) S) (hL : LayR Lay) (b : Fin 19 → Bool) :
    algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 17 1 (.s (splitS c0 b)))
      = 2 ^ 19 * aPl U P D (offU1 39) 19 b
        + (aPl U P D (offU1 40) 19 b + 2 ^ 16 * aPl U P D (offU1 41) 19 b) - 2 ^ 18 := by
  have hss : S.ss = 19 := hS.ss
  simp only [relGh, gS_oneR B hL, one_mul, hss, xtU1, remR2_lo, remR2_hi, remVal_gt 19 (by norm_num),
    map_sub, map_mul, map_add, map_pow, map_ofNat, alg_plS_u1 U P D hX]

end Rels

/-! ## 6. `SC_SZC`'s IR and its polynomial at a cube point -/

section Point

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **`SC_SZC`'s IR read in the field at `export_u1`**: host terms with the batch (LogUp at table `14`,
exp tuple at `μ_8`, four clauses) and the two hosted terms (`SUM + λ`, score requantization at shift `19`). -/
theorem szc_irEval_u1 (hist : Hist) (dr : List Fp2) (v : List K) :
    irEval ((irS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U)) v
      = hostTerms v 0 1 2 none none ((nuS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U))
          (logupSem (cstK U) v 14 (fun k => ((muS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD (4 + k) 0) 0
              ((lksS17_u1.map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 17 dr))).map
                (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U)))
            + ((muS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 8 0
              * szcExp (cstK U) RSzU1 KSzU1 v ((Sym.eval hist 17 dr amdS).toK U) ((Sym.eval hist 17 dr nbS).toK U)
            + batchV ((muS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U)) (szcClauses (cstK U) RSzU1 KSzU1 v))
          (v.getD 13 0 + (Sym.eval hist 17 dr (.dr 4 12)).toK U) (reqV (cstK U) v 19 4 [5, 6]) := by
  unfold irS_u1
  rw [szcIr_map, szcIr_map, cstS_map, szcIr_eval _ (cstW_map_std U)]
  simp only [List.length_map, lksS17_u1_length, padSem, add_zero, RSzU1_gS, gV, Option.toList_none, List.map_nil,
    List.prod_nil, one_mul]
  rfl

omit [Field K] [Algebra GF K] in
/-- The lookups' table positions are past the three `eq` tables. -/
theorem lksS17_u1_pos (f : Sym → Fp2) (g : Fp2 → K) :
    ∀ l ∈ (lksS17_u1.map (ZK60.Exec.Slot.Build.LkD.map f)).map (ZK60.Exec.Slot.Build.LkD.map g),
      ∀ t ∈ l.terms, 3 ≤ t.2 := by
  intro l hl t ht
  simp only [List.mem_map] at hl
  obtain ⟨l1, ⟨l0, hl0, rfl⟩, rfl⟩ := hl
  simp only [ZK60.Exec.Slot.Build.LkD.map, List.map_map, List.mem_map] at ht
  obtain ⟨t0, ht0, rfl⟩ := ht
  simp only [lksS17_u1, DefW16.lksS, List.mem_map] at hl0
  obtain ⟨lw, -, rfl⟩ := hl0
  simp only [List.mem_map] at ht0
  obtain ⟨tw, -, rfl⟩ := ht0
  simp only [Function.comp, shapedS]
  omega

theorem lkRels_cons3_u1 (e0 e1 e2 : K) (rest : List K) (lks : List (LkD K))
    (hp : ∀ l ∈ lks, ∀ t ∈ l.terms, 3 ≤ t.2) :
    lkRels (cstK U) (e0 :: e1 :: e2 :: rest) 14 0 lks = lkRels (cstK U) (0 :: 0 :: 0 :: rest) 14 0 lks :=
  lkRels_congr (cstK U) _ _ 14 0 lks (fun l hl t ht => getD_cons3 e0 e1 e2 rest t.2 (hp l hl t ht))
    (fun i _ => getD_cons3 e0 e1 e2 rest _ (by omega))

variable (P : BlockParams) (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

include hX in
/-- **`SC_SZC`'s polynomial at a cube point with the zero extension at `export_u1`**:
`eq(τ)·Σ_{κ < 9} μ_κ·c_κ + ν₀·eq(p_ht)·(SUM + λ) + ν₁·eq(P₁)·h₁`. -/
theorem szc_point_u1 (cnA cnM : ℕ) (hS : PrecR (cfgU1 cnA cnM) S) (hL : LayR Lay) (hist : Hist) (dr : List Fp2)
    (e0 e1 e2 : K) (b : Fin 19 → Bool) :
    irEval ((irS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U))
        (e0 :: e1 :: e2 :: restS_u1 U P D (algebraMap GF K (B.mask (splitS c0 b))) b)
      = e0 * ∑ κ : Fin 9, ((muS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD κ 0
          * (if (κ : ℕ) < 4 then algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 17 κ (.s (splitS c0 b)))
            else xcSzcU1 U P D Pb Lay B (hist.beta, hist.gamma, hist.alpha) κ b)
        + ((nuS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 0 0
          * (e1 * (aPl U P D (offU1 5) 12 (hd12 b) + (Sym.eval hist 17 dr (.dr 4 12)).toK U))
        + ((nuS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 1 0
          * (e2 * algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 17 1 (.s (splitS c0 b)))) := by
  rw [szc_irEval_u1]
  have hlk := lkRels_cons3_u1 U e0 e1 e2 (restS_u1 U P D (algebraMap GF K (B.mask (splitS c0 b))) b)
    _ (lksS17_u1_pos (Sym.eval hist 17 dr) (Fp2.toK U))
  have hlks : (lksS17_u1.map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 17 dr)))
      = lksS17_u1.map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval (histOf (hist.beta, hist.gamma, hist.alpha).1
          (hist.beta, hist.gamma, hist.alpha).2.1 (hist.beta, hist.gamma, hist.alpha).2.2 []) 17 [])) :=
    lksS_eval c0 shapedS .S hist _ 17 17 dr [] rfl rfl
  have hex : szcExp (cstK U) RSzU1 KSzU1 (e0 :: e1 :: e2 :: restS_u1 U P D (algebraMap GF K (B.mask (splitS c0 b))) b)
      ((Sym.eval hist 17 dr amdS).toK U) ((Sym.eval hist 17 dr nbS).toK U)
      = szcExp (cstK U) RSzU1 KSzU1 (valsXS_u1 U P D Pb Lay B b)
        ((Sym.eval (histOf (hist.beta, hist.gamma, hist.alpha).1 (hist.beta, hist.gamma, hist.alpha).2.1
          (hist.beta, hist.gamma, hist.alpha).2.2 []) 17 [] amdS).toK U)
        ((Sym.eval (histOf (hist.beta, hist.gamma, hist.alpha).1 (hist.beta, hist.gamma, hist.alpha).2.1
          (hist.beta, hist.gamma, hist.alpha).2.2 []) 17 [] nbS).toK U) := rfl
  have hlen : (lkRels (cstK U) (valsXS_u1 U P D Pb Lay B b) 14 0
      (lksK_u1 U (hist.beta, hist.gamma, hist.alpha))).length = 4 := by
    rw [lkRels_length]
    simp only [lksK_u1, List.length_map, lksS17_u1_length]
  unfold xcSzcU1
  rw [batch9 (fun q => ((muS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD q 0)
    (fun q => algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 17 q (.s (splitS c0 b)))) _ hlen]
  have hcl := relCl17_alg_u1 U P D hX Pb Lay B cnA cnM hS hL b
  simp only [List.cons.injEq, and_true] at hcl
  obtain ⟨hc0, hc1, hc2, hc3⟩ := hcl
  simp only [hc0, hc1, hc2, hc3]
  rw [relGh171_alg_u1 U P D hX Pb Lay B cnA cnM hS hL b, logupSem_eq_wsum, hlk, hlks, hex]
  unfold lksK_u1 valsXS_u1 hostTerms
  simp only [gV, Option.toList_none, List.map_nil, List.prod_nil, one_mul, List.getD_cons_zero,
    List.getD_cons_succ, restS_u1]
  simp only [batchV, szcClauses, szcDelta, RSzU1, KSzU1, reqV, L16, List.zipIdx_cons, List.zipIdx_nil,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.getD_cons_zero, List.getD_cons_succ]
  simp (disch := norm_num) only [cK U, cP U, Int.cast_pow, Int.cast_neg, Int.cast_ofNat,
    show (19 - 1 : ℕ) = 18 from rfl]
  ring

end Point

/-! ## 7. Multilinear extensions at `SC_SCORE`'s block sizes (`lt = 7, lkv = 3, lh - lkv = 2, ldh = 7`) -/

section Mle

variable {K : Type} [Field K]

/-- **The extension at `(r, (g, s), c)` with `g`, `c` Boolean** (`SC_SCORE`'s `QR` table, log `19`). -/
theorem mleAt_qr_u1 (f : (Fin (7 + ((3 + 2) + 7)) → Bool) → K) (r : Fin 7 → K) (g : Fin 3 → Bool)
    (s : Fin 2 → K) (c : Fin 7 → Bool) :
    mleAt f (Fin.append r (Fin.append (Fin.append (fun i => bit (g i)) s) (fun i => bit (c i))))
      = ∑ t : Fin 7 → Bool, ∑ j : Fin 2 → Bool, eqPoly r (fun i => bit (t i)) * eqPoly s (fun i => bit (j i))
          * f (Fin.append t (Fin.append (Fin.append g j) c)) := by
  rw [mleAt_append]
  unfold mle2
  refine Finset.sum_congr rfl (fun t _ => ?_)
  have e1 : ∀ w1 : Fin (3 + 2) → Bool, ∑ w2 : Fin 7 → Bool,
      eqPoly r (fun i => bit (t i)) * eqPoly (Fin.append (Fin.append (fun i => bit (g i)) s) (fun i => bit (c i)))
        (fun i => bit (Fin.append w1 w2 i)) * f (Fin.append t (Fin.append w1 w2))
      = eqPoly r (fun i => bit (t i)) * eqPoly (Fin.append (fun i => bit (g i)) s) (fun i => bit (w1 i))
        * f (Fin.append t (Fin.append w1 c)) := by
    intro w1
    have h : ∀ w2 : Fin 7 → Bool, eqPoly r (fun i => bit (t i))
        * eqPoly (Fin.append (Fin.append (fun i => bit (g i)) s) (fun i => bit (c i)))
          (fun i => bit (Fin.append w1 w2 i)) * f (Fin.append t (Fin.append w1 w2))
        = eqPoly (fun i => (bit (c i) : K)) (fun i => bit (w2 i)) * (eqPoly r (fun i => bit (t i))
          * eqPoly (Fin.append (fun i => bit (g i)) s) (fun i => bit (w1 i)) * f (Fin.append t (Fin.append w1 w2))) := by
      intro w2
      rw [bits_append, eqPoly_append]
      ring
    rw [Finset.sum_congr rfl (fun w2 _ => h w2), sum_eq_bits]
  have e2 : ∀ j : Fin 2 → Bool, ∑ g' : Fin 3 → Bool,
      eqPoly r (fun i => bit (t i)) * eqPoly (Fin.append (fun i => bit (g i)) s) (fun i => bit (Fin.append g' j i))
        * f (Fin.append t (Fin.append (Fin.append g' j) c))
      = eqPoly r (fun i => bit (t i)) * eqPoly s (fun i => bit (j i))
        * f (Fin.append t (Fin.append (Fin.append g j) c)) := by
    intro j
    have h : ∀ g' : Fin 3 → Bool, eqPoly r (fun i => bit (t i))
        * eqPoly (Fin.append (fun i => bit (g i)) s) (fun i => bit (Fin.append g' j i))
          * f (Fin.append t (Fin.append (Fin.append g' j) c))
        = eqPoly (fun i => (bit (g i) : K)) (fun i => bit (g' i)) * (eqPoly r (fun i => bit (t i))
          * eqPoly s (fun i => bit (j i)) * f (Fin.append t (Fin.append (Fin.append g' j) c))) := by
      intro g'
      rw [bits_append, eqPoly_append]
      ring
    rw [Finset.sum_congr rfl (fun g' _ => h g'), sum_eq_bits]
  rw [sum_append, Finset.sum_congr rfl (fun w1 _ => e1 w1), sum_append, Finset.sum_comm]
  exact Finset.sum_congr rfl (fun j _ => e2 j)

/-- **The extension at `(r, g, c)` with `g`, `c` Boolean** (`SC_SCORE`'s `KR` table, log `17`). -/
theorem mleAt_kr_u1 (f : (Fin (7 + (3 + 7)) → Bool) → K) (r : Fin 7 → K) (g : Fin 3 → Bool) (c : Fin 7 → Bool) :
    mleAt f (Fin.append r (Fin.append (fun i => bit (g i)) (fun i => bit (c i))))
      = ∑ t : Fin 7 → Bool, eqPoly r (fun i => bit (t i)) * f (Fin.append t (Fin.append g c)) := by
  rw [← bits_append g c]
  exact mleAt_append_bits f r (Fin.append g c)

/-- **The reordering of `SC_SCORE`'s sum at `export_u1`**. -/
theorem score_eq_u1 (QR : (Fin (7 + ((3 + 2) + 7)) → Bool) → K) (KR : (Fin (7 + (3 + 7)) → Bool) → K)
    (rg : Fin 3 → K) (rj : Fin 2 → K) (rt r3 : Fin 7 → K) :
    ∑ g : Fin 3 → Bool, ∑ c : Fin 7 → Bool, eqPoly rg (fun i => bit (g i))
      * ((∑ t : Fin 7 → Bool, ∑ j : Fin 2 → Bool, eqPoly rt (fun i => bit (t i)) * eqPoly rj (fun i => bit (j i))
          * QR (Fin.append t (Fin.append (Fin.append g j) c)))
        * (∑ t' : Fin 7 → Bool, eqPoly r3 (fun i => bit (t' i)) * KR (Fin.append t' (Fin.append g c))))
    = ∑ g : Fin 3 → Bool, ∑ j : Fin 2 → Bool, ∑ t : Fin 7 → Bool, ∑ t' : Fin 7 → Bool,
        eqPoly rg (fun i => bit (g i)) * eqPoly rj (fun i => bit (j i)) * eqPoly rt (fun i => bit (t i))
          * eqPoly r3 (fun i => bit (t' i))
          * ∑ c : Fin 7 → Bool, QR (Fin.append t (Fin.append (Fin.append g j) c)) * KR (Fin.append t' (Fin.append g c)) :=
  score_gen (fun g : Fin 3 → Bool => eqPoly rg (fun i => bit (g i))) (fun j : Fin 2 → Bool => eqPoly rj (fun i => bit (j i)))
    (fun t : Fin 7 → Bool => eqPoly rt (fun i => bit (t i))) (fun t : Fin 7 → Bool => eqPoly r3 (fun i => bit (t i)))
    (fun g j t (c : Fin 7 → Bool) => QR (Fin.append t (Fin.append (Fin.append g j) c)))
    (fun g t (c : Fin 7 → Bool) => KR (Fin.append t (Fin.append g c)))

end Mle

/-! ## 8. The three slots' cube sums at `export_u1` -/

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

include hX hrl in
/-- **`SC_SZC`'s cube sum at `export_u1`** (`n = 19`): `Z̃(τ) + ν₀·128·(S̃UM(p_ht) + λ) + ν₁·h̃₁(P₁)`. -/
theorem szc_cube_u1 (cnA cnM : ℕ) (hS : PrecR (cfgU1 cnA cnM) S) (hL : LayR Lay) (n e : ℕ) (hn : n = 19)
    (aB hB ioIn ioOut ak hk : ℕ) (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2)
    (hmask : ∀ b : Fin 19 → Bool,
      ((pub 0).getD (msbIndex 19 b) Fp2.zero).toK U = algebraMap GF K (B.mask (splitS c0 b)))
    (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval ((irS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U))
      (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 rawTabs17_u1).map (TabS.eval (Sym.eval hist 17 dr) pub)).map
        (tabK U P D n e x))) :
    cubeSum f = mleAt (fun b : Fin 19 → Bool => ∑ κ : Fin 9,
          ((muS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD κ 0
          * (if (κ : ℕ) < 4 then algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 17 κ (.s (splitS c0 b)))
            else xcSzcU1 U P D Pb Lay B (hist.beta, hist.gamma, hist.alpha) κ b))
        (ptv U (Sym.eval hist 17 dr) 17 0 19)
      + ((nuS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 0 0
        * (128 * (mleAt (fun r : Fin 12 → Bool => aPl U P D (offU1 5) 12 r) (ptv U (Sym.eval hist 17 dr) 4 0 12)
          + (Sym.eval hist 17 dr (.dr 4 12)).toK U))
      + ((nuS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 1 0
        * mleAt (fun b : Fin 19 → Bool => algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 17 1 (.s (splitS c0 b))))
          (ptv U (Sym.eval hist 17 dr) 8 0 19) := by
  subst hn
  rw [cubeSum_split]
  have hrow : ∀ b : Fin 19 → Bool, ∑ y : Fin e → Bool, f (fun i => bit (Fin.append b y i))
      = eqPoly (ptv U (Sym.eval hist 17 dr) 17 0 19) (fun i => bit (b i))
          * (∑ κ : Fin 9, ((muS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD κ 0
            * (if (κ : ℕ) < 4 then algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 17 κ (.s (splitS c0 b)))
              else xcSzcU1 U P D Pb Lay B (hist.beta, hist.gamma, hist.alpha) κ b))
        + ((nuS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 0 0
          * (eqPoly (ptv U (Sym.eval hist 17 dr) 4 0 12) (fun i => bit (hd12 b i))
            * (aPl U P D (offU1 5) 12 (hd12 b) + ((Sym.eval hist 17 dr) (.dr 4 12)).toK U))
        + ((nuS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 1 0
          * (eqPoly (ptv U (Sym.eval hist 17 dr) 8 0 19) (fun i => bit (b i))
            * algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 17 1 (.s (splitS c0 b)))) := by
    intro b
    rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
    · show f (cpt 19 e b) = _
      rw [hf, szc_vals_u1 U P D hrl aB hB ioIn ioOut ak hk e b (Sym.eval hist 17 dr) pub, hmask b,
        szc_point_u1 U P D hX Pb Lay B cnA cnM hS hL hist dr, drs_ptv, drs_ptv, drs_ptv]
    · show f (bpt 19 e b y) = 0
      have z0 : (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 rawTabs17_u1).map
          (TabS.eval (Sym.eval hist 17 dr) pub)).map (tabK U P D 19 e (bpt 19 e b y))).getD 0 0 = 0 :=
        tabK_eq_off U P D 19 e b y hy _ _
      have z1 : (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 rawTabs17_u1).map
          (TabS.eval (Sym.eval hist 17 dr) pub)).map (tabK U P D 19 e (bpt 19 e b y))).getD 1 0 = 0 :=
        tabK_eq_off U P D 19 e b y hy _ _
      have z2 : (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 rawTabs17_u1).map
          (TabS.eval (Sym.eval hist 17 dr) pub)).map (tabK U P D 19 e (bpt 19 e b y))).getD 2 0 = 0 :=
        tabK_eq_off U P D 19 e b y hy _ _
      rw [hf, szc_irEval_u1]
      unfold hostTerms
      rw [z0, z1, z2]
      ring
  simp only [hrow]
  rw [Finset.sum_add_distrib, Finset.sum_add_distrib]
  have hB : ∑ b : Fin 19 → Bool, ((nuS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 0 0
        * (eqPoly (ptv U (Sym.eval hist 17 dr) 4 0 12) (fun i => bit (hd12 b i))
          * (aPl U P D (offU1 5) 12 (hd12 b) + ((Sym.eval hist 17 dr) (.dr 4 12)).toK U))
      = ((nuS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 0 0
        * (128 * (mleAt (fun r : Fin 12 → Bool => aPl U P D (offU1 5) 12 r) (ptv U (Sym.eval hist 17 dr) 4 0 12)
          + ((Sym.eval hist 17 dr) (.dr 4 12)).toK U)) := by
    rw [← Finset.mul_sum]
    congr 1
    have h1 := sum_append (a := 12) (b := 7) (fun b =>
      eqPoly (ptv U (Sym.eval hist 17 dr) 4 0 12) (fun i => bit (hd12 b i))
        * (aPl U P D (offU1 5) 12 (hd12 b) + ((Sym.eval hist 17 dr) (.dr 4 12)).toK U))
    refine h1.trans ?_
    simp only [hd12_append]
    have h2 := rs_host_cubeSum (b := 7) (ptv U (Sym.eval hist 17 dr) 4 0 12) (fun _ => (1 : K))
      (fun r => aPl U P D (offU1 5) 12 r) (((Sym.eval hist 17 dr) (.dr 4 12)).toK U)
    simp only [one_mul] at h2
    rw [h2, mleAt_add_c]
    norm_num
  have hC : ∑ b : Fin 19 → Bool, ((nuS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 1 0
        * (eqPoly (ptv U (Sym.eval hist 17 dr) 8 0 19) (fun i => bit (b i))
          * algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 17 1 (.s (splitS c0 b))))
      = ((nuS_u1.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 1 0
        * mleAt (fun b : Fin 19 → Bool => algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 17 1 (.s (splitS c0 b))))
          (ptv U (Sym.eval hist 17 dr) 8 0 19) := by
    rw [← Finset.mul_sum]
    rfl
  rw [hB, hC]
  rfl

include hrl in
/-- **`SC_RS`'s cube sum at `export_u1`** (`n = 19`): `(Σ_j mask·E)~(p_ht) + λ·(Σ_j ZSEL)~(p_ht)`. -/
theorem rs_cube_u1 (n e : ℕ) (hn : n = 19) (aB hB ioIn ioOut ak hk : ℕ) (hist : Hist) (dr : List Fp2)
    (pub : ℕ → List Fp2)
    (hmask : ∀ b : Fin 19 → Bool,
      ((pub 0).getD (msbIndex 19 b) Fp2.zero).toK U = algebraMap GF K (B.mask (splitS c0 b)))
    (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((rsIr DefW16.cstS 0 1 2 3 none (.dr 4 12)).map (Sym.eval hist 4 dr)).map (Fp2.toK U))
      (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 rawTabs4_u1).map (TabS.eval (Sym.eval hist 4 dr) pub)).map
        (tabK U P D n e x))) :
    cubeSum f = mleAt (fun r : Fin 12 → Bool => ∑ j : Fin 7 → Bool,
          algebraMap GF K (B.mask (splitS c0 (Fin.append r j : Fin 19 → Bool)))
            * aPl U P D (offU1 43) 19 (Fin.append r j))
        (ptv U (Sym.eval hist 4 dr) 4 0 12)
      + (Sym.eval hist 4 dr (.dr 4 12)).toK U
        * mleAt (fun r : Fin 12 → Bool => ∑ j : Fin 7 → Bool, aPl U P D (offU1 42) 19 (Fin.append r j))
          (ptv U (Sym.eval hist 4 dr) 4 0 12) := by
  subst hn
  have hir : ∀ v : List K,
      irEval (((rsIr DefW16.cstS 0 1 2 3 none (.dr 4 12)).map (Sym.eval hist 4 dr)).map (Fp2.toK U)) v
      = v.getD 0 0 * (v.getD 1 0 * v.getD 2 0 + ((Sym.eval hist 4 dr) (.dr 4 12)).toK U * v.getD 3 0) := by
    intro v
    rw [rsIr_map, rsIr_map, cstS_map, rsIr_eval _ (cstW_map_std U)]
    simp only [gV, Option.toList_none, List.map_nil, List.prod_nil, one_mul]
  rw [cubeSum_split]
  have hrow : ∀ b : Fin 19 → Bool, ∑ y : Fin e → Bool, f (fun i => bit (Fin.append b y i))
      = eqPoly (ptv U (Sym.eval hist 4 dr) 4 0 12) (fun i => bit (hd12 b i))
        * (algebraMap GF K (B.mask (splitS c0 b)) * aPl U P D (offU1 43) 19 b
          + ((Sym.eval hist 4 dr) (.dr 4 12)).toK U * aPl U P D (offU1 42) 19 b) := by
    intro b
    rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
    · show f (cpt 19 e b) = _
      rw [hf, hir]
      simp only [rawTabs4_u1, taA, DefW16.numTabs, List.map_cons, List.map_nil, eqT_eval, pubT_eval,
        List.getD_cons_zero, List.getD_cons_succ, tabK_aSet U P D hrl 19 e b (by norm_num)]
      rw [tabK_eqHead_cpt U P D 19 e b _ 12 (drs_length (Sym.eval hist 4 dr) 4 0 12) (by norm_num),
        tabK_pub_cpt, hmask b, drs_ptv]
      rfl
    · show f (bpt 19 e b y) = 0
      rw [hf, hir]
      have z0 : (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 rawTabs4_u1).map
          (TabS.eval (Sym.eval hist 4 dr) pub)).map (tabK U P D 19 e (bpt 19 e b y))).getD 0 0 = 0 :=
        tabK_eq_off U P D 19 e b y hy _ _
      rw [z0, zero_mul]
  simp only [hrow]
  have h1 := sum_append (a := 12) (b := 7) (fun b =>
    eqPoly (ptv U (Sym.eval hist 4 dr) 4 0 12) (fun i => bit (hd12 b i))
      * (algebraMap GF K (B.mask (splitS c0 b)) * aPl U P D (offU1 43) 19 b
        + ((Sym.eval hist 4 dr) (.dr 4 12)).toK U * aPl U P D (offU1 42) 19 b))
  refine h1.trans ?_
  simp only [hd12_append]
  have h2 := rs_cubeSum (ptv U (Sym.eval hist 4 dr) 4 0 12) (fun _ _ => (1 : K))
    (fun (r : Fin 12 → Bool) (j : Fin 7 → Bool) =>
      algebraMap GF K (B.mask (splitS c0 (Fin.append r j : Fin 19 → Bool))))
    (fun r j => aPl U P D (offU1 43) 19 (Fin.append r j))
    (fun r j => aPl U P D (offU1 42) 19 (Fin.append r j))
    (((Sym.eval hist 4 dr) (.dr 4 12)).toK U)
  simp only [one_mul] at h2
  exact h2

/-- The coordinates of `SC_SCORE`'s `QR` table at `export_u1`, evaluated. -/
def coordsQ_u1 (ev : Sym → Fp2) : List Coord :=
  ((drs 8 5 7).map CoordS.fixed ++ DefW16.rhoC 0 3 ++ (drs 8 3 2).map CoordS.fixed ++ DefW16.rhoC 3 10).map
    (CoordS.eval ev)

/-- The coordinates of `SC_SCORE`'s `KR` table at `export_u1`, evaluated. -/
def coordsK_u1 (ev : Sym → Fp2) : List Coord :=
  ((drs 8 12 7).map CoordS.fixed ++ DefW16.rhoC 0 3 ++ DefW16.rhoC 3 10).map (CoordS.eval ev)

theorem tabs8_u1_eval (aB hB ioIn ioOut ak hk : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    (DefW16.numTabs aB hB ioIn ioOut ak hk 0 rawTabs8_u1).map (TabS.eval ev pub)
      = [.eq ((drs 8 0 3).map ev) 0,
         .priv ⟨.a, [(offU1 29, Fp2.one)], 19, coordsQ_u1 ev, aB + 2 * ak, 0⟩,
         .priv ⟨.a, [(offU1 37, Fp2.one)], 17, coordsK_u1 ev, aB + 2 * (ak + 1), 1⟩] := rfl

include hrl in
theorem score_qr_u1 (ev : Sym → Fp2) (m : ℕ) (g : Fin 3 → Bool) (c : Fin 7 → Bool) :
    tabK U P D 10 2 (cpt 10 2 (Fin.append g c)) (.priv ⟨.a, [(offU1 29, Fp2.one)], 19, coordsQ_u1 ev, m, 0⟩)
      = ∑ t : Fin 7 → Bool, ∑ j : Fin 2 → Bool, eqPoly (ptv U ev 8 5 7) (fun i => bit (t i))
          * eqPoly (ptv U ev 8 3 2) (fun i => bit (j i))
          * aPl U P D (offU1 29) 19 (Fin.append t (Fin.append (Fin.append g j) c)) := by
  rw [tabK_priv_cpt U P D 10 2 _ _ (by simp) (by norm_num) hrl]
  have hpt : (fun a : Fin 19 => ptK U (xrK 10 (cpt (K := K) 10 2 (Fin.append g c))) (coordsQ_u1 ev) a)
      = (Fin.append (ptv U ev 8 5 7) (Fin.append (Fin.append (fun i => (bit (g i) : K)) (ptv U ev 8 3 2))
          (fun i => (bit (c i) : K))) : Fin 19 → K) := by
    funext a
    fin_cases a <;> rfl
  show mleAt (aPl U P D (offU1 29) 19)
    (fun a : Fin 19 => ptK U (xrK 10 (cpt (K := K) 10 2 (Fin.append g c))) (coordsQ_u1 ev) a) = _
  rw [hpt]
  exact mleAt_qr_u1 (aPl U P D (offU1 29) 19) _ g _ c

include hrl in
theorem score_kr_u1 (ev : Sym → Fp2) (m : ℕ) (g : Fin 3 → Bool) (c : Fin 7 → Bool) :
    tabK U P D 10 2 (cpt 10 2 (Fin.append g c)) (.priv ⟨.a, [(offU1 37, Fp2.one)], 17, coordsK_u1 ev, m, 1⟩)
      = ∑ t : Fin 7 → Bool, eqPoly (ptv U ev 8 12 7) (fun i => bit (t i))
          * aPl U P D (offU1 37) 17 (Fin.append t (Fin.append g c)) := by
  rw [tabK_priv_cpt U P D 10 2 _ _ (by simp) (by norm_num) hrl]
  have hpt : (fun a : Fin 17 => ptK U (xrK 10 (cpt (K := K) 10 2 (Fin.append g c))) (coordsK_u1 ev) a)
      = (Fin.append (ptv U ev 8 12 7) (Fin.append (fun i => (bit (g i) : K)) (fun i => (bit (c i) : K)))
          : Fin 17 → K) := by
    funext a
    fin_cases a <;> rfl
  show mleAt (aPl U P D (offU1 37) 17)
    (fun a : Fin 17 => ptK U (xrK 10 (cpt (K := K) 10 2 (Fin.append g c))) (coordsK_u1 ev) a) = _
  rw [hpt]
  exact mleAt_kr_u1 (aPl U P D (offU1 37) 17) _ g c

include hrl in
/-- **`SC_SCORE`'s cube sum at `export_u1`** (`n = 10`, `e = 2`):
`Σ_g Σ_c eq(r_g, g)·Q̃R(r_t, g, r_hj, c)·K̃R(r_3, g, c)`. -/
theorem score_cube_u1 (n e : ℕ) (hn : n = 10) (he : e = 2) (aB hB ioIn ioOut ak hk : ℕ) (hist : Hist)
    (dr : List Fp2) (pub : ℕ → List Fp2) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((bilIr DefW16.cstS (some 0) 1 2).map (Sym.eval hist 8 dr)).map (Fp2.toK U))
      (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 rawTabs8_u1).map (TabS.eval (Sym.eval hist 8 dr) pub)).map
        (tabK U P D n e x))) :
    cubeSum f = ∑ g : Fin 3 → Bool, ∑ c : Fin 7 → Bool,
      eqPoly (ptv U (Sym.eval hist 8 dr) 8 0 3) (fun i => bit (g i))
      * ((∑ t : Fin 7 → Bool, ∑ j : Fin 2 → Bool, eqPoly (ptv U (Sym.eval hist 8 dr) 8 5 7) (fun i => bit (t i))
          * eqPoly (ptv U (Sym.eval hist 8 dr) 8 3 2) (fun i => bit (j i))
          * aPl U P D (offU1 29) 19 (Fin.append t (Fin.append (Fin.append g j) c)))
        * (∑ t' : Fin 7 → Bool, eqPoly (ptv U (Sym.eval hist 8 dr) 8 12 7) (fun i => bit (t' i))
          * aPl U P D (offU1 37) 17 (Fin.append t' (Fin.append g c)))) := by
  subst hn
  subst he
  have hir : ∀ v : List K, irEval (((bilIr DefW16.cstS (some 0) 1 2).map (Sym.eval hist 8 dr)).map (Fp2.toK U)) v
      = v.getD 0 0 * (v.getD 1 0 * v.getD 2 0) := by
    intro v
    rw [bilIr_map, bilIr_map, cstS_map, bilIr_eval _ (cstW_map_std U)]
    simp only [gV, Option.toList_some, List.map_cons, List.map_nil, List.prod_cons, List.prod_nil, mul_one]
  rw [cubeSum_split]
  refine (sum_append (a := 3) (b := 7) _).trans
    (Finset.sum_congr rfl (fun g _ => Finset.sum_congr rfl (fun c _ => ?_)))
  rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
  · show f (cpt 10 2 (Fin.append g c)) = _
    rw [hf, hir, tabs8_u1_eval]
    simp only [List.map_cons, List.map_nil, List.getD_cons_zero, List.getD_cons_succ]
    rw [tabK_eqHead_cpt U P D 10 2 _ _ 3 (drs_length (Sym.eval hist 8 dr) 8 0 3) (by norm_num),
      score_qr_u1 U P D hrl (Sym.eval hist 8 dr) _ g c,
      score_kr_u1 U P D hrl (Sym.eval hist 8 dr) _ g c, drs_ptv]
    congr 2
    funext i
    exact congrArg bit (Fin.append_left g c i)
  · show f (bpt 10 2 (Fin.append g c) y) = 0
    rw [hf, hir]
    have z0 : (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 rawTabs8_u1).map
        (TabS.eval (Sym.eval hist 8 dr) pub)).map (tabK U P D 10 2 (bpt 10 2 (Fin.append g c) y))).getD 0 0 = 0 :=
      tabK_eq_off U P D 10 2 (Fin.append g c) y hy _ _
    rw [z0, zero_mul]

end Cube

/-! ## 9. `SC_RS`'s row differences and `SC_SCORE`'s contraction, in the planes -/

section Rows

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

include hX

theorem alg_plHt_u1 (off : ℕ) (r : Fin 12 → Bool) :
    algebraMap GF K (plH U c0 P D off (splitHt c0 r)) = aPl U P D off 12 r := by
  unfold plH
  rw [aPl_alg U P D hX, append_splitHt_u1]
  rfl

/-- **`SC_RS`'s first row difference, embedded**: `SUM − Σ_j mask·E` (the gates are `1`). -/
theorem rsA_alg_u1 (hL : LayR Lay) (r : Fin 12 → Bool) :
    algebraMap GF K (relRsA Pb Lay B (xtU1 U P D) (.ht (splitHt c0 r)))
      = aPl U P D (offU1 5) 12 r - ∑ j : Fin 7 → Bool,
          algebraMap GF K (B.mask (splitS c0 (Fin.append r j : Fin 19 → Bool)))
            * aPl U P D (offU1 43) 19 (Fin.append r j) := by
  simp only [relRsA, gHt_oneR B hL, gS_oneR B hL, one_mul, map_sub, map_sum, map_mul, xtU1]
  refine congrArg₂ (fun a b : K => a - b) (alg_plHt_u1 U P D hX (offU1 5) r) (Finset.sum_congr rfl fun j _ => ?_)
  exact congrArg₂ (fun a b : K => a * b)
    (congrArg (fun x => algebraMap GF K (B.mask x)) (splitS_app12 r j).symm)
    ((congrArg (fun x => algebraMap GF K (plS U c0 P D (offU1 43) x)) (splitS_app12 r j).symm).trans
      (alg_plS_u1 U P D hX (offU1 43) (Fin.append r j)))

/-- **`SC_RS`'s second row difference, embedded**: `1 − Σ_j ZSEL`. -/
theorem rsB_alg_u1 (hL : LayR Lay) (r : Fin 12 → Bool) :
    algebraMap GF K (relRsB Pb Lay B (xtU1 U P D) (.ht (splitHt c0 r)))
      = 1 - ∑ j : Fin 7 → Bool, aPl U P D (offU1 42) 19 (Fin.append r j) := by
  simp only [relRsB, gHt_oneR B hL, gS_oneR B hL, one_mul, map_sub, map_sum, map_one, xtU1]
  congr 1
  refine Finset.sum_congr rfl (fun j _ => ?_)
  exact (congrArg (fun x => algebraMap GF K (plS U c0 P D (offU1 42) x)) (splitS_app12 r j).symm).trans
    (alg_plS_u1 U P D hX (offU1 42) (Fin.append r j))

/-- **`SC_SCORE`'s contraction, embedded**, at a point of `Dom::S` made of its four blocks. -/
theorem relMm171_alg_u1 (g : Fin 3 → Bool) (j : Fin 2 → Bool) (t t' : Fin 7 → Bool) :
    algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 17 1
        (.s (splitS c0 (Fin.append (Fin.append g j) (Fin.append t t')))))
      = ∑ c : Fin 7 → Bool, aPl U P D (offU1 29) 19 (Fin.append t (Fin.append (Fin.append g j) c))
          * aPl U P D (offU1 37) 17 (Fin.append t' (Fin.append g c)) := by
  have hs := splitS_append c0 ((g, j), t, t')
  simp only at hs
  rw [hs]
  simp only [relMm, map_sum, map_mul, xtU1]
  refine Finset.sum_congr rfl (fun c _ => ?_)
  unfold plQ plK
  rw [aPl_alg U P D hX, aPl_alg U P D hX]
  rfl

end Rows

/-! ## 10. `SC_SZC`'s certified polynomial at its draws (`algShapeU1`) -/

section Host

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] (U : K) (hcard : 78 < Fintype.card K)
  {L : ℕ} (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws)

include hcard in
/-- **`SC_SZC`'s certified polynomial at its draws at `export_u1`**: `Z̃(τ) + ν₀·h̃₀(P₀) + ν₁·(h̃₁(P₁) − M̃₁(P₁))`. -/
theorem szc_hostPhi_u1 (dt : AlgData K L (algShapeU1 P hdr)) (cu : Cuts3 L) (rt : RootsO) (hist : Hist)
    (dr : List Fp2) :
    (hostSp U (algShapeU1 P hdr) dt hcard 17 mem17 cu rt hist).Φ (fun i => (dr.getD i.val Fp2.zero).toK U)
      = mleAt (fun b : Fin 19 → Bool => ∑ κ : Fin 9, (dr.getD (19 + κ) Fp2.zero).toK U
            * dt.cl 17 cu rt (hist.beta, hist.gamma, hist.alpha) κ b)
          (fun t : Fin 19 => (dr.getD t Fp2.zero).toK U)
        + (dr.getD 28 Fp2.zero).toK U
          * mleAt (algH U (algShapeU1 P hdr) dt 17 cu rt hist 0) (algPt U (algShapeU1 P hdr) 17 hist 0)
        + (dr.getD 29 Fp2.zero).toK U
          * (mleAt (dt.gh 17 cu rt 1) (algPt U (algShapeU1 P hdr) 17 hist 1)
            - mleAt (dt.mm 17 cu rt 1) (algPt U (algShapeU1 P hdr) 17 hist 1)) := by
  have hk : (17 : ℕ) ∈ algHosts := mem17
  have hseg : ∀ (g : ZK60.Exec.Slot.W16R2.Seg) (i : ℕ),
      segOff ((algShapeU1 P hdr).dl 17) g + i < segSum ((algShapeU1 P hdr).dl 17) →
      segAt ((algShapeU1 P hdr).dl 17) (fun j => (fun i : Fin (P.draws 17) => (dr.getD i.val Fp2.zero).toK U)
        (Fin.cast ((algShapeU1 P hdr).hsum 17 hk) j)) g i
        = (dr.getD (segOff ((algShapeU1 P hdr).dl 17) g + i) Fp2.zero).toK U := by
    intro g i hi
    unfold segAt
    rw [dite_eq_left hi]
    rfl
  have hz : segLn ((algShapeU1 P hdr).dl 17) .zeta = 0 := rfl
  have hM0 : mleAt (algM (algShapeU1 P hdr) dt 17 cu rt 0) (algPt U (algShapeU1 P hdr) 17 hist 0) = 0 := by
    unfold algM mleAt
    simp
  rw [hostSp_Φ, hostPhi_eq, Fin.sum_univ_two, hM0, algH_gh U (algShapeU1 P hdr) dt 17 cu rt hist 1 (by decide),
    algM_mm (algShapeU1 P hdr) dt 17 cu rt 1 (by decide)]
  have hbat : batched (dt.cl 17 cu rt (hist.beta, hist.gamma, hist.alpha)) (dt.pw 17 cu rt)
      ((if segLn ((algShapeU1 P hdr).dl 17) .zeta = 1 then segAt ((algShapeU1 P hdr).dl 17) (fun j =>
          (fun i : Fin (P.draws 17) => (dr.getD i.val Fp2.zero).toK U) (Fin.cast ((algShapeU1 P hdr).hsum 17 hk) j))
          .zeta 0 else 0,
        if segLn ((algShapeU1 P hdr).dl 17) .zeta = 1 then segAt ((algShapeU1 P hdr).dl 17) (fun j =>
          (fun i : Fin (P.draws 17) => (dr.getD i.val Fp2.zero).toK U) (Fin.cast ((algShapeU1 P hdr).hsum 17 hk) j))
          .mu (segLn ((algShapeU1 P hdr).dl 17) .mu - segLn ((algShapeU1 P hdr).dl 17) .zeta) else 0),
        fun κ => segAt ((algShapeU1 P hdr).dl 17) (fun j => (fun i : Fin (P.draws 17) =>
          (dr.getD i.val Fp2.zero).toK U) (Fin.cast ((algShapeU1 P hdr).hsum 17 hk) j)) .mu κ)
      = fun b : Fin 19 → Bool => ∑ κ : Fin 9, (dr.getD (19 + κ) Fp2.zero).toK U
          * dt.cl 17 cu rt (hist.beta, hist.gamma, hist.alpha) κ b := by
    funext b
    unfold batched
    simp only [hz, zero_ne_one, ite_false, zero_mul, add_zero]
    refine Finset.sum_congr rfl (fun κ _ => ?_)
    have hmu : segLn ((algShapeU1 P hdr).dl 17) .mu = 9 := rfl
    have hκ := κ.isLt
    rw [hseg .mu κ (by show 19 + (κ : ℕ) < 30; omega)]
    rfl
  have htau : (fun t : Fin (segLn ((algShapeU1 P hdr).dl 17) .tau) => segAt ((algShapeU1 P hdr).dl 17)
      (fun j => (fun i : Fin (P.draws 17) => (dr.getD i.val Fp2.zero).toK U)
        (Fin.cast ((algShapeU1 P hdr).hsum 17 hk) j)) .tau t)
      = fun t : Fin 19 => (dr.getD t Fp2.zero).toK U := by
    funext t
    have ht : (t : ℕ) < 19 := t.isLt
    rw [hseg .tau t (by show 0 + (t : ℕ) < 30; omega)]
    show (dr.getD (0 + (t : ℕ)) Fp2.zero).toK U = _
    rw [Nat.zero_add]
  have hnu0 : segAt ((algShapeU1 P hdr).dl 17) (fun j => (fun i : Fin (P.draws 17) =>
      (dr.getD i.val Fp2.zero).toK U) (Fin.cast ((algShapeU1 P hdr).hsum 17 hk) j)) .nu ((0 : Fin 2) : ℕ)
      = (dr.getD 28 Fp2.zero).toK U :=
    hseg .nu 0 (by show 28 + 0 < 30; omega)
  have hnu1 : segAt ((algShapeU1 P hdr).dl 17) (fun j => (fun i : Fin (P.draws 17) =>
      (dr.getD i.val Fp2.zero).toK U) (Fin.cast ((algShapeU1 P hdr).hsum 17 hk) j)) .nu ((1 : Fin 2) : ℕ)
      = (dr.getD 29 Fp2.zero).toK U :=
    hseg .nu 1 (by show 28 + 1 < 30; omega)
  rw [hbat, htau, hnu0, hnu1]
  simp only [one_mul, sub_zero]
  exact (add_assoc _ _ _).symm

omit [Fintype K] [DecidableEq K] in
/-- `SC_SCORE`'s claim point at `export_u1`, read off the history. -/
theorem algPt_score_u1 (hist : Hist) (t : Fin 19) :
    algPt U (algShapeU1 P hdr) 17 hist 1 t = algDrawAt U hist 8 t := by
  unfold algPt
  rw [ite_eq_right (by decide), ite_eq_right (by decide)]
  rfl

omit [Fintype K] [DecidableEq K] in
/-- **`SC_SZC`'s hosted `SC_RS` function at its claim point at `export_u1`**: `128·(Ã(p_ht) + λ·B̃(p_ht))`. -/
theorem algH0_mle_u1 (dt : AlgData K L (algShapeU1 P hdr)) (cu : Cuts3 L) (rt : RootsO) (hist : Hist)
    (hsc : dt.rsScale = 128) (A B : (Fin 12 → Bool) → K)
    (hA : ∀ b, dt.rsA cu rt b = A b) (hB : ∀ b, dt.rsB cu rt b = B b) (p : Fin 12 → K)
    (hp : ∀ t : Fin 12, algDrawAt U hist 4 t = p t) :
    mleAt (algH U (algShapeU1 P hdr) dt 17 cu rt hist 0) (algPt U (algShapeU1 P hdr) 17 hist 0)
      = 128 * (mleAt A p + algDrawAt U hist 4 12 * mleAt B p) := by
  have e1 : (algH U (algShapeU1 P hdr) dt 17 cu rt hist 0 : (Fin (12 + 7) → Bool) → K)
      = fun z : Fin (12 + 7) → Bool => (fun r => 128 * (A r + algDrawAt U hist 4 12 * B r))
          (fun i => z (Fin.castAdd 7 i)) := by
    funext z
    unfold algH
    rw [dite_eq_left ⟨rfl, rfl⟩, hsc, hA, hB]
    rfl
  have e2 : (algPt U (algShapeU1 P hdr) 17 hist 0 : Fin (12 + 7) → K)
      = Fin.append p (fun _ : Fin 7 => (0 : K)) := by
    funext t
    unfold algPt
    rw [ite_eq_left ⟨rfl, rfl⟩]
    refine Fin.addCases (m := 12) (n := 7) (fun i => ?_) (fun i => ?_) t
    · rw [Fin.append_left]
      split_ifs with h
      · exact hp i
      · exact absurd i.isLt h
    · rw [Fin.append_right]
      split_ifs with h
      · exact absurd h (by show ¬ (12 + (i : ℕ) < 12); omega)
      · rfl
  rw [e1, e2]
  exact (mleAt_rowOnly (fun r => 128 * (A r + algDrawAt U hist 4 12 * B r)) p (fun _ : Fin 7 => 0)).trans
    (mleAt_lin2 A B 128 (algDrawAt U hist 4 12) p)

end Host

/-! ## 11. `SC_SZC`'s named identity at `export_u1` (`formAt_szcU1`) -/

section Form

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K]

/-- **`SC_SZC`'s named identity at W16R2 Shieldstral (`export_u1`)**, parametric in `(cnA, cnM)`:
for every algebra data whose `SC_SZC` tables are the relation tables of the extracted planes `xtU1`
(`relCl 17`, `xcSzcU1`, `relGh 17 1`, `relMm 17 1`, `SC_RS`'s row differences, scale `128`), on every
outcome whose verified slots are hosts exactly when their definitions host slots, `SC_SZC`'s certified
polynomial at the drawn challenges is its unmasked residual `Σ Poly₁₇ − (128·ν₀·Σ Poly₄ + ν₁·Σ Poly₈)`. -/
theorem formAt_szcU1 (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) {L : ℕ}
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
    (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws) (hsl : P.geom.slots = W16R2.shieldSlots)
    (cnA cnM ioIn ioOut : ℕ) (pubs : PubTabs)
    (hdef : P.define = defineS (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
    (hS : PrecR (cfgU1 cnA cnM) S) (hLay : LayR Lay) (hpub : PubR U c0 pubs Pb Lay B)
    (dt : AlgData K L (algShapeU1 P hdr)) (cu : Cuts3 L) (rt : RootsO)
    (hcl : ∀ bga (κ : Fin 9) (b : Fin 19 → Bool), dt.cl 17 cu rt bga κ b
      = if (κ : ℕ) < 4 then algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 17 κ (.s (splitS c0 b)))
        else xcSzcU1 U P D Pb Lay B bga κ b)
    (hgh : ∀ b : Fin 19 → Bool,
      dt.gh 17 cu rt 1 b = algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 17 1 (.s (splitS c0 b))))
    (hmm : ∀ b : Fin 19 → Bool,
      dt.mm 17 cu rt 1 b = algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 17 1 (.s (splitS c0 b))))
    (hrsA : ∀ b : Fin 12 → Bool, dt.rsA cu rt b = algebraMap GF K (relRsA Pb Lay B (xtU1 U P D) (.ht (splitHt c0 b))))
    (hrsB : ∀ b : Fin 12 → Bool, dt.rsB cu rt b = algebraMap GF K (relRsB Pb Lay B (xtU1 U P D) (.ht (splitHt c0 b))))
    (hsc : dt.rsScale = 128)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    FormAt U P (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeU1 P hdr) dt hcard 0 cu rt k h).Φ) bga rs 17 := by
  obtain ⟨hs17, hs4, hs8⟩ := slotShape_szc_u1 P hsl
  obtain ⟨ak17, hk17, hslot17⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 17 (by norm_num)
  obtain ⟨ak4, hk4, hslot4⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 4 (by norm_num)
  obtain ⟨ak8, hk8, hslot8⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 8 (by norm_num)
  have hk : (17 : ℕ) ∈ algHosts := mem17
  refine formAt_two U hcard P (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs hdef D _ dt cu rt bga rs 17 hk 4 8
    (.mul (.dr 17 28) (.base 128)) (.dr 17 29)
    (by rw [hslot17, rawSlot17_eq]; rfl) (by rw [hslot4, rawSlot4_eq]; rfl) (by rw [hslot8, rawSlot8_eq]; rfl)
    (by decide) (by decide) hslots (fun r hr => ?_)
  have hlen : 17 < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨r4, hr4⟩ : ∃ r4, rs[4]? = some r4 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  obtain ⟨r8, hr8⟩ : ∃ r8, rs[8]? = some r8 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  -- the three slots' sums
  have hsp17 := szc_cube_u1 U P D hX hrl Pb Lay B cnA cnM hS hLay (slotShape P 17).1 (slotShape P 17).2.1
    (by rw [hs17]) (DefW16.aDataRows (cfgU1 cnA cnM)) (DefW16.hDataRows (cfgU1 cnA cnM)) ioIn ioOut ak17 hk17
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) r.draws
    (pubs 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) r.draws) (hpub.szcMask _ _)
    (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs 17 (seenOf bga rs 17))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 17 r hr x, hslot17, rawSlot17_eq]; rfl)
  have hsp4 := rs_cube_u1 U P D hrl Pb Lay B (slotShape P 4).1 (slotShape P 4).2.1 (by rw [hs4])
    (DefW16.aDataRows (cfgU1 cnA cnM)) (DefW16.hDataRows (cfgU1 cnA cnM)) ioIn ioOut ak4 hk4
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 4)) r4.draws
    (pubs 4 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 4)) r4.draws) (hpub.rsMask _ _)
    (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs 4 (seenOf bga rs 4))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 4 r4 hr4 x, hslot4, rawSlot4_eq]; rfl)
  have hsp8 := score_cube_u1 U P D hrl (slotShape P 8).1 (slotShape P 8).2.1 (by rw [hs8]) (by rw [hs8])
    (DefW16.aDataRows (cfgU1 cnA cnM)) (DefW16.hDataRows (cfgU1 cnA cnM)) ioIn ioOut ak8 hk8
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) r8.draws
    (pubs 8 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) r8.draws)
    (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs 8 (seenOf bga rs 8))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 8 r8 hr8 x, hslot8, rawSlot8_eq]; rfl)
  rw [szc_hostPhi_u1 U hcard P hdr dt cu rt _ r.draws]
  unfold spSum
  rw [hsp17, hsp4, hsp8]
  -- the batch
  have eZ : mleAt (fun b : Fin 19 → Bool => ∑ κ : Fin 9, (r.draws.getD (19 + κ) Fp2.zero).toK U
        * dt.cl 17 cu rt ((histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).beta,
            (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).gamma,
            (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).alpha) κ b)
        (fun t : Fin 19 => (r.draws.getD t Fp2.zero).toK U)
      = mleAt (fun b : Fin 19 → Bool => ∑ κ : Fin 9,
          ((muS_u1.map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws)).map (Fp2.toK U)).getD κ 0
          * (if (κ : ℕ) < 4 then algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 17 κ (.s (splitS c0 b)))
            else xcSzcU1 U P D Pb Lay B ((histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).beta,
              (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).gamma,
              (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).alpha) κ b))
        (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws) 17 0 19) := by
    rw [ptv_own]
    congr 1
    · funext b
      refine Finset.sum_congr rfl (fun κ _ => ?_)
      rw [hcl, muS_u1, drsK_getD U _ 17 19 9 κ κ.isLt, ev_own]
    · funext t
      rw [Nat.zero_add]
  -- `SC_RS`'s hosted function
  have eH0 : mleAt (algH U (algShapeU1 P hdr) dt 17 cu rt (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 0)
      (algPt U (algShapeU1 P hdr) 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 0)
      = 128 * ((mleAt (fun r : Fin 12 → Bool => aPl U P D (offU1 5) 12 r)
            (fun i => (r4.draws.getD i Fp2.zero).toK U)
          - mleAt (fun r : Fin 12 → Bool => ∑ j : Fin 7 → Bool,
              algebraMap GF K (B.mask (splitS c0 (Fin.append r j : Fin 19 → Bool)))
                * aPl U P D (offU1 43) 19 (Fin.append r j))
            (fun i => (r4.draws.getD i Fp2.zero).toK U))
        + (r4.draws.getD 12 Fp2.zero).toK U
          * (1 - mleAt (fun r : Fin 12 → Bool => ∑ j : Fin 7 → Bool, aPl U P D (offU1 42) 19 (Fin.append r j))
            (fun i => (r4.draws.getD i Fp2.zero).toK U))) := by
    rw [algH0_mle_u1 U P hdr dt cu rt (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) hsc
      (fun r : Fin 12 → Bool => aPl U P D (offU1 5) 12 r - ∑ j : Fin 7 → Bool,
        algebraMap GF K (B.mask (splitS c0 (Fin.append r j : Fin 19 → Bool)))
          * aPl U P D (offU1 43) 19 (Fin.append r j))
      (fun r : Fin 12 → Bool => 1 - ∑ j : Fin 7 → Bool, aPl U P D (offU1 42) 19 (Fin.append r j))
      (fun b => (hrsA b).trans (rsA_alg_u1 U P D hX Pb Lay B hLay b))
      (fun b => (hrsB b).trans (rsB_alg_u1 U P D hX Pb Lay B hLay b))
      (fun i => (r4.draws.getD i Fp2.zero).toK U)
      (fun t => algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 17 4 t r4 (by decide) hr4),
      algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 17 4 12 r4 (by decide) hr4,
      mleAt_sub' (fun r : Fin 12 → Bool => aPl U P D (offU1 5) 12 r), mleAt_c_sub]
  -- `SC_SCORE`'s claim point and the hosted terms
  have hP8 : (algPt U (algShapeU1 P hdr) 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 1 : Fin 19 → K)
      = fun t : Fin 19 => (r8.draws.getD t Fp2.zero).toK U := by
    funext t
    rw [algPt_score_u1 U P hdr (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) t,
      algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 17 8 t r8 (by decide) hr8]
  have eH1 : mleAt (dt.gh 17 cu rt 1) (algPt U (algShapeU1 P hdr) 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 1)
      = mleAt (fun b : Fin 19 → Bool => algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 17 1 (.s (splitS c0 b))))
        (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws) 8 0 19) := by
    rw [hP8, ptv_hist U bga.1 bga.2.1 bga.2.2 rs 17 8 r8 (by decide) hr8]
    exact congrArg₂ mleAt (funext hgh) (funext fun t => by rw [Nat.zero_add])
  have hpt8 : (fun t : Fin 19 => (r8.draws.getD t Fp2.zero).toK U)
      = (Fin.append (Fin.append (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 0 3)
          (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 3 2))
        (Fin.append (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 5 7)
          (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 12 7)) : Fin 19 → K) := by
    rw [ptv_own, ptv_own, ptv_own, ptv_own]
    funext t
    fin_cases t <;> rfl
  have eM1 : mleAt (dt.mm 17 cu rt 1) (algPt U (algShapeU1 P hdr) 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 1)
      = ∑ g : Fin 3 → Bool, ∑ c : Fin 7 → Bool,
        eqPoly (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 0 3) (fun i => bit (g i))
        * ((∑ t : Fin 7 → Bool, ∑ j : Fin 2 → Bool,
            eqPoly (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 5 7) (fun i => bit (t i))
            * eqPoly (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 3 2)
              (fun i => bit (j i))
            * aPl U P D (offU1 29) 19 (Fin.append t (Fin.append (Fin.append g j) c)))
          * (∑ t' : Fin 7 → Bool,
            eqPoly (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 12 7) (fun i => bit (t' i))
            * aPl U P D (offU1 37) 17 (Fin.append t' (Fin.append g c)))) := by
    refine Eq.trans ?_ (score_eq_u1 (aPl U P D (offU1 29) 19) (aPl U P D (offU1 37) 17)
      (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 0 3)
      (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 3 2)
      (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 5 7)
      (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 12 7)).symm
    have e1 : mleAt (dt.mm 17 cu rt 1) (algPt U (algShapeU1 P hdr) 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 1)
        = mleAt (fun z : Fin ((3 + 2) + (7 + 7)) → Bool =>
            algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 17 1 (.s (splitS c0 z))))
          (Fin.append (Fin.append (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 0 3)
              (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 3 2))
            (Fin.append (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 5 7)
              (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 12 7))) := by
      rw [hP8]
      exact congrArg₂ mleAt (funext hmm) hpt8
    rw [e1, mleAt_eq4]
    refine Finset.sum_congr rfl (fun g _ => Finset.sum_congr rfl (fun j _ => Finset.sum_congr rfl
      (fun t _ => Finset.sum_congr rfl (fun t' _ => ?_))))
    exact congrArg ((_ : K) * ·) (relMm171_alg_u1 U P D hX Pb Lay B g j t t')
  -- the weights and `λ`
  have es0 : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws (.mul (.dr 17 28) (.base 128))).toK U
      = (r.draws.getD 28 Fp2.zero).toK U * 128 := by
    rw [ev_mul, Fp2.toK_mul U hU, ev_own, ev_base, Fp2.toK_fromBase,
      Fp.toGF_fromI64 128 (by norm_num) (by norm_num), map_intCast]
    norm_num
  have es1 : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws (.dr 17 29)).toK U
      = (r.draws.getD 29 Fp2.zero).toK U := by rw [ev_own]
  have enu0 : ((nuS_u1.map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws)).map (Fp2.toK U)).getD 0 0
      = (r.draws.getD 28 Fp2.zero).toK U := by
    show (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws (.dr 17 28)).toK U = _
    rw [ev_own]
  have enu1 : ((nuS_u1.map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws)).map (Fp2.toK U)).getD 1 0
      = (r.draws.getD 29 Fp2.zero).toK U := by
    show (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws (.dr 17 29)).toK U = _
    rw [ev_own]
  have el17 : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws (.dr 4 12)).toK U
      = (r4.draws.getD 12 Fp2.zero).toK U :=
    ev_hist U bga.1 bga.2.1 bga.2.2 rs 17 4 12 r4 (by decide) hr4 r.draws
  have el4 : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 4)) 4 r4.draws (.dr 4 12)).toK U
      = (r4.draws.getD 12 Fp2.zero).toK U := by rw [ev_own]
  have ep4 : ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws) 4 0 12
      = fun i : Fin 12 => (r4.draws.getD i Fp2.zero).toK U := by
    rw [ptv_hist U bga.1 bga.2.1 bga.2.2 rs 17 4 r4 (by decide) hr4]
    funext i
    rw [Nat.zero_add]
  have ep4' : ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 4)) 4 r4.draws) 4 0 12
      = fun i : Fin 12 => (r4.draws.getD i Fp2.zero).toK U := by
    rw [ptv_own]
    funext i
    rw [Nat.zero_add]
  rw [eZ, eH0, eH1, eM1, es0, es1, enu0, enu1, el17, el4, ep4, ep4']
  ring

end Form

end ZK60.Exec.Block.Join.W16U1.Szc
