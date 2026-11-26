/-
D63 W16R2 Shieldstral (`export_u1`) port: **host `SC_FZC` (slot 18) and its hosted matmuls
`SC_GMM` (slot 11) and `SC_UMM` (slot 12)** at `cfgU1 cnA cnM` (`W16R2_SHIELD_T128_H24`).

Port of `BlockHostFzc.lean` from the development rung (`lt = 5`, `ld = 9`, `lf = 10`, `Dom::F` 15,
`f0 = 49`, `gate = 19`, `YM = 18` at log 14) to the installed Shieldstral export `export_u1`
(`lt = 7`, `ld = 12`, `lf = 14`, `Dom::F` 21, `f0 = 47`, 9 `Dom::F` planes `47..55`, `gate = 20`,
`up = 12`, `fold = 16`, `h24 = true`, `prodbits = 24`, 7 lookups → 4 LogUp helpers `22..25`
(3 pairs + 1 single), ACT helper `26`, 6 batch entries `0..5`, 9 pad planes `Fin 9`, `YM = 18`
at log 19, hosted matmuls `SC_GMM`/`SC_UMM` inner `ld = 12`).

Because `rawSlot (cfgU1 cnA cnM) s = rawSlot c0 s` by `rfl` for `s ∈ {11, 12, 18}` (neither `cnA` nor
`cnM` enters these three slots), `formAt_fzcU1` is parametric in `cnA cnM : ℕ` via `progW16_slot` and
`numTabs` without hardcoding reserved-row indices.

* `rawTabsF_u1`, `rawMmF_u1`, `shF_u1`, `kF_u1`, `irF_u1`, **`rawSlot18_eq`**, **`rawSlot11_eq`**,
  **`rawSlot12_eq`**: the three raw slots at `cfgU1 cnA cnM`;
* `restF_u1`, **`valsXF_u1`**: `SC_FZC`'s value list on the 21-bit cube (`0 :: 0 :: 0 :: restF_u1`);
* **`xcFzcU1`**: the batch's entries past the product clause (entry `1` ACT relation `fzcAct`, entries
  `2..5` LogUp's four helper relations at tables `12..15`) on `valsXF_u1`;
* **`pwFzcU1`**: the nine pad planes `(1 − supp(F))·plane_j` (`j : Fin 9`);
* **`fzc_vals_u1`**, **`fzc_irEval_u1`**, **`fzc_cube_u1`**, **`fzc_rel0_u1`**, **`fzc_gh0_u1`**,
  **`fzc_gh1_u1`**, **`fzc_batch_u1`**, **`gmm_sum_u1`**, **`umm_sum_u1`**: cube sums and named identities;
* **`formAt_fzcU1`**: `FormAt` at host `18` (`SC_FZC`) for every `(cnA, cnM)`.

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.BlockW16U1Base
import ZK60Formal.BlockHostFzc

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16U1.Fzc

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly hostPhi batched SlotPoly segAt)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl aPl_alg hPl tabK_ph_cpt hTab_eval tabK_pa_cpt eqT_eval pubT_eval paT paT_eval
  aFx_eval mm_cube mm_fold cstS_map cstK cstK_base cstK_p16 toK_zpowW lkRels_congr padPls_congr lksS_eval
  formAt_two eqDr)
open ZK60.Exec.Block.Join.W16.Fzc (drR drR_length drR_getD getD_app getD_app_right rrF amqS nbS nb2S grpF
  getD_cons3 getD_map_toK muF_getD fzcAct_congr mmSlot_eval)
open ZK60.Exec.Block.Join.R13H (plD plF splitF LayR PubR PrecR)
open ZK60.Exec.Block.Join.W16U1
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.W16R2 (segLn segOff segSum)
open ZK60.Exec.Slot.Build (Cst cstW hostTerms gV gV_some L16 reqV batchV fzcIr FzcR FzcK fzcClauses fzcAct
  fzcIr_eval padSem logupSem LkD mmIr mmIr_eval)
open ZK60.Exec.Slot.Compose (fzcIr_map mmIr_map cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-! ## 1. The three raw slots at `export_u1` (`cfgU1 cnA cnM`) -/

/-- An `H` table on its own `21` coordinates (`Dom::F` at `export_u1`). -/
def hT21 (re im m : ℕ) : TabS := .priv ⟨.h, [(re, false), (im, true)], 21, DefW16.rhoC 0 21, m, 0⟩

/-- `SC_FZC`'s raw tables at `export_u1` (19 tables): `eq(τ)`, `eq(r_GMM)`, `eq(r_UMM)`, the 9 `Dom::F`
planes `47..55` (`G, rg₀, rg₁, A, U, ru, H, Htop, rh`), the 4 LogUp helpers `22..25`, the `fact` helper
`26`, and the two public tables (group column, gate `supp(F)` — both `.pub 0` before `numTabs`). -/
def rawTabsF_u1 : List TabS :=
  [.eq (drR 18 10 21) 0, .eq (drR 11 0 21) 0, .eq (drR 11 0 7 ++ drR 12 0 14) 0,
    paT (offU1 47) 21 0, paT (offU1 48) 21 0, paT (offU1 49) 21 0, paT (offU1 50) 21 0, paT (offU1 51) 21 0,
    paT (offU1 52) 21 0, paT (offU1 53) 21 0, paT (offU1 54) 21 0, paT (offU1 55) 21 0,
    hT21 (hOffU1 22).1 (hOffU1 22).2 0, hT21 (hOffU1 23).1 (hOffU1 23).2 0,
    hT21 (hOffU1 24).1 (hOffU1 24).2 0, hT21 (hOffU1 25).1 (hOffU1 25).2 0,
    hT21 (hOffU1 26).1 (hOffU1 26).2 0, .pub 0, .pub 0]

/-- `SC_FZC`'s plane-to-table map at `export_u1` (`Dom::F`'s planes start at `f0 = 47`). -/
def shF_u1 (q : ℕ) : ℕ := 3 + (q - 47)

/-- The shifts at `export_u1`: product fold `16`, gate `20`, up projection `12`. -/
def kF_u1 : FzcK := ⟨16, 20, 12⟩

/-- `SC_FZC`'s IR at `export_u1`. -/
def irF_u1 : ZK60.Exec.Slot.Ir Sym :=
  fzcIr DefW16.cstS rrF kF_u1 (lksS c0 shF_u1 .F) (drR 18 0 7) (drR 18 7 2) amqS nbS nb2S
    (fun j => Sym.pow (.dr 18 9) j) grpF

theorem rawSlot18_eq (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 18
    = ⟨rawTabsF_u1, irF_u1, [(11, .dr 18 7), (12, .dr 18 8)], [.dr 18 7, .dr 18 8, .dr 18 9]⟩ := by
  rw [DefW16.rawSlot_shieldU1_ne14 cnA cnM 18 (by decide)]
  rfl

/-- `SC_GMM`'s and `SC_UMM`'s raw `A` table at `export_u1`: `YM` (plane `18`, log `19`) with its `7` token
coordinates fixed at `SC_GMM`'s `r_tf` and inner width `12`. -/
def rawMmF_u1 : TabS :=
  .priv ⟨.a, [(offU1 18, false)], 19, (drR 11 0 7).map CoordS.fixed ++ DefW16.rhoC 0 12, 0, 0⟩

theorem rawSlot11_eq (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 11
    = ⟨[rawMmF_u1, .pub 0], mmIr DefW16.cstS 0 1, [], []⟩ := rfl

theorem rawSlot12_eq (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 12
    = ⟨[rawMmF_u1, .pub 0], mmIr DefW16.cstS 0 1, [], []⟩ := rfl

theorem lksF_u1_length : (lksS c0 shF_u1 .F).length = 7 := by decide

/-- The `export_u1` slot shapes of slots `18`, `11`, `12`. -/
theorem slotShape_fzc_u1 (P : BlockParams) (hsl : P.geom.slots = W16R2.shieldSlots) :
    slotShape P 18 = (21, 1, 5) ∧ slotShape P 11 = (12, 1, 2) ∧ slotShape P 12 = (12, 1, 2) := by
  simp only [slotShape, hsl]
  decide

/-! ## 2. The value list, `valsXF_u1`, `xcFzcU1`, and `pwFzcU1` -/

section Defs

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

/-- **`SC_FZC`'s value list from position `3` on at `export_u1`**: the 9 `Dom::F` planes (`47..55`), the
4 LogUp helpers (`22..25`), the `fact` helper (`26`), the group column, and the gate `supp(F)`. -/
noncomputable def restF_u1 (b : Fin 21 → Bool) : List K :=
  [aPl U P D (offU1 47) 21 b, aPl U P D (offU1 48) 21 b, aPl U P D (offU1 49) 21 b,
    aPl U P D (offU1 50) 21 b, aPl U P D (offU1 51) 21 b, aPl U P D (offU1 52) 21 b,
    aPl U P D (offU1 53) 21 b, aPl U P D (offU1 54) 21 b, aPl U P D (offU1 55) 21 b,
    hPl U P D (hOffU1 22).1 (hOffU1 22).2 21 b, hPl U P D (hOffU1 23).1 (hOffU1 23).2 21 b,
    hPl U P D (hOffU1 24).1 (hOffU1 24).2 21 b, hPl U P D (hOffU1 25).1 (hOffU1 25).2 21 b,
    hPl U P D (hOffU1 26).1 (hOffU1 26).2 21 b,
    algebraMap GF K (B.grpCol (splitF c0 b)), algebraMap GF K (B.gF (splitF c0 b))]

/-- **`SC_FZC`'s value list without the draws at `export_u1`**: the three `eq` entries `0`, followed by
`restF_u1`. -/
noncomputable def valsXF_u1 (b : Fin 21 → Bool) : List K := 0 :: 0 :: 0 :: restF_u1 U P D Pb Lay B b

/-- The LogUp lookups read in the field at a history (they read only `α`, `γ`). -/
noncomputable def lksK_u1 (hist : Hist) (dr : List Fp2) : List (LkD K) :=
  ((lksS c0 shF_u1 .F).map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 18 dr))).map
    (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U))

/-- **The batch's entries of `SC_FZC` past the product clause at `export_u1`**, read without the draws:
entry `1` the ACT tuple's relation, entries `2..5` LogUp's four helper relations (3 pairs + 1 single). -/
noncomputable def xcFzcU1 (bga : Fp2 × Fp2 × Fp2) (κ : ℕ) (b : Fin 21 → Bool) : K :=
  if κ = 1 then
    fzcAct (valsXF_u1 U P D Pb Lay B b) rrF ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 18 [] amqS).toK U)
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 18 [] nbS).toK U)
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 18 [] nb2S).toK U)
  else (lkRels (cstK U) (valsXF_u1 U P D Pb Lay B b) 12 0
    (lksK_u1 U (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD (κ - 2) 0

/-- **The nine pad planes of `SC_FZC` at `export_u1`**: `(1 − supp(F))·plane_j`, `j : Fin 9`. -/
noncomputable def pwFzcU1 (j : Fin 9) (b : Fin 21 → Bool) : K :=
  (padPls (valsXF_u1 U P D Pb Lay B b) grpF).getD j 0

/-- The IR's zero-check sum at a value list. -/
noncomputable def zIR_u1 (hist : Hist) (dr : List Fp2) (v : List K) : K :=
  logupSem (cstK U) v 12 (fun k => (((drR 18 0 7).map (Sym.eval hist 18 dr)).map (Fp2.toK U)).getD (2 + k) 0) 0
      (lksK_u1 U hist dr)
    + (((drR 18 0 7).map (Sym.eval hist 18 dr)).map (Fp2.toK U)).getD 1 0
      * fzcAct v rrF ((Sym.eval hist 18 dr amqS).toK U) ((Sym.eval hist 18 dr nbS).toK U)
        ((Sym.eval hist 18 dr nb2S).toK U)
    + padSem (cstK U) v ((((drR 18 0 7).map (Sym.eval hist 18 dr)).map (Fp2.toK U)).getD 6 0)
      (fun j => (Sym.eval hist 18 dr (Sym.pow (.dr 18 9) j)).toK U) 0 grpF
    + gV v (some 18) * batchV (((drR 18 0 7).map (Sym.eval hist 18 dr)).map (Fp2.toK U))
      (fzcClauses (cstK U) rrF kF_u1 v)

/-- The `eq` points of the three `eq` tables at `export_u1`, read in the field. -/
noncomputable def tauF_u1 (ev : Sym → Fp2) : Fin 21 → K :=
  fun a => (((drR 18 10 21).map ev).getD a Fp2.zero).toK U
noncomputable def p0F_u1 (ev : Sym → Fp2) : Fin 21 → K :=
  fun a => (((drR 11 0 21).map ev).getD a Fp2.zero).toK U
noncomputable def p1F_u1 (ev : Sym → Fp2) : Fin 21 → K :=
  fun a => (((drR 11 0 7 ++ drR 12 0 14).map ev).getD a Fp2.zero).toK U

/-- **The value list `SC_FZC`'s IR reads at a cube point with the zero extension.** -/
noncomputable def vF_u1 (ev : Sym → Fp2) (b : Fin 21 → Bool) : List K :=
  eqPoly (tauF_u1 U ev) (fun a => bit (b a)) :: eqPoly (p0F_u1 U ev) (fun a => bit (b a))
    :: eqPoly (p1F_u1 U ev) (fun a => bit (b a)) :: restF_u1 U P D Pb Lay B b

end Defs

/-! ## 3. Positions past the `eq` tables and the value list at a cube point -/

theorem lksK_u1_pos {K : Type} [Field K] [Algebra GF K] (U : K) (hist : Hist) (dr : List Fp2) :
    ∀ l ∈ lksK_u1 U hist dr, ∀ t ∈ l.terms, 3 ≤ t.2 := by
  intro l hl t ht
  simp only [lksK_u1, lksS, List.mem_map] at hl
  obtain ⟨l1, ⟨l0, ⟨lw, -, rfl⟩, rfl⟩, rfl⟩ := hl
  simp only [ZK60.Exec.Slot.Build.LkD.map, List.mem_map] at ht
  obtain ⟨t1, ⟨t0, ⟨tw, -, rfl⟩, rfl⟩, rfl⟩ := ht
  simp only [shF_u1]
  omega

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)

/-- A numbered `A` table on its own `n` coordinates, at the zero extension. -/
theorem tabK_aSet (hrl : 0 < rowLog P .a) (n e : ℕ) (b : Fin n → Bool) (hn : 0 < n)
    (aB hB ioIn ioOut ak hk off : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    tabK U P D n e (cpt n e b) (TabS.eval ev pub (.priv (DefW16.setRow aB hB ioIn ioOut ak hk
      ⟨.a, [(off, false)], n, DefW16.rhoC 0 n, 0, 0⟩))) = aPl U P D off n b := by
  show tabK U P D n e (cpt n e b)
    (TabS.eval ev pub (.priv ⟨.a, [(off, false)], n, DefW16.rhoC 0 n, aB + 2 * ak, 0⟩)) = _
  rw [aTab_eval, tabK_pa_cpt U P D hrl n e b n hn rfl, castB_rfl]

/-- A numbered `H` table on its own `n` coordinates, at the zero extension. -/
theorem tabK_hSet (hrl : 0 < rowLog P .h) (n e : ℕ) (b : Fin n → Bool) (hn : 0 < n)
    (aB hB ioIn ioOut ak hk re im : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    tabK U P D n e (cpt n e b) (TabS.eval ev pub (.priv (DefW16.setRow aB hB ioIn ioOut ak hk
      ⟨.h, [(re, false), (im, true)], n, DefW16.rhoC 0 n, 0, 0⟩))) = hPl U P D re im n b := by
  show tabK U P D n e (cpt n e b)
    (TabS.eval ev pub (.priv ⟨.h, [(re, false), (im, true)], n, DefW16.rhoC 0 n, hB + 2 * hk, 0⟩)) = _
  rw [hTab_eval, tabK_ph_cpt U P D hrl n e b n hn rfl, castB_rfl]

variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

/-- **`SC_FZC`'s value list at a cube point with the zero extension** (for any numbering sites `ak, hk`). -/
theorem fzc_vals_u1 (hrl : 0 < rowLog P .a) (aB hB ioIn ioOut ak hk e : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2)
    (hg0 : ∀ b : Fin 21 → Bool,
      ((pub 0).getD (msbIndex 21 b) Fp2.zero).toK U = algebraMap GF K (B.grpCol (splitF c0 b)))
    (hg1 : ∀ b : Fin 21 → Bool,
      ((pub 1).getD (msbIndex 21 b) Fp2.zero).toK U = algebraMap GF K (B.gF (splitF c0 b)))
    (b : Fin 21 → Bool) :
    ((DefW16.numTabs aB hB ioIn ioOut ak hk 0 rawTabsF_u1).map (TabS.eval ev pub)).map
        (tabK U P D 21 e (cpt 21 e b)) = vF_u1 U P D Pb Lay B ev b := by
  have hrlh : 0 < rowLog P .h := hrl
  have l1 : ((drR 18 10 21).map ev).length = 21 := by rw [List.length_map, drR_length]
  have l2 : ((drR 11 0 21).map ev).length = 21 := by rw [List.length_map, drR_length]
  have l3 : ((drR 11 0 7 ++ drR 12 0 14).map ev).length = 21 := by
    rw [List.length_map, List.length_append, drR_length, drR_length]
  simp only [rawTabsF_u1, paT, hT21, DefW16.numTabs, List.map_cons, List.map_nil, eqT_eval, pubT_eval,
    tabK_aSet U P D hrl 21 e b (by norm_num), tabK_hSet U P D hrlh 21 e b (by norm_num),
    tabK_pub_cpt, Nat.zero_add, hg0, hg1, tabK_eqFull_cpt U P D 21 e b _ l1,
    tabK_eqFull_cpt U P D 21 e b _ l2, tabK_eqFull_cpt U P D 21 e b _ l3]
  rfl

/-- Off the zero extension the three `eq` entries are `0`. -/
theorem fzc_off_u1 (aB hB ioIn ioOut ak hk e : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2) (b : Fin 21 → Bool)
    (y : Fin e → Bool) (hy : y ≠ fun _ => false) :
    (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 rawTabsF_u1).map (TabS.eval ev pub)).map
        (tabK U P D 21 e (bpt 21 e b y))).getD 0 0 = 0
      ∧ (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 rawTabsF_u1).map (TabS.eval ev pub)).map
        (tabK U P D 21 e (bpt 21 e b y))).getD 1 0 = 0
      ∧ (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 rawTabsF_u1).map (TabS.eval ev pub)).map
        (tabK U P D 21 e (bpt 21 e b y))).getD 2 0 = 0 :=
  ⟨tabK_eq_off U P D 21 e b y hy _ _, tabK_eq_off U P D 21 e b y hy _ _, tabK_eq_off U P D 21 e b y hy _ _⟩

end Vals

/-! ## 4. The IR and `SC_FZC`'s cube sum -/

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

/-- **`SC_FZC`'s IR read in the field at `export_u1`**: host terms with gate shift `20` and up shift `12`. -/
theorem fzc_irEval_u1 (hist : Hist) (dr : List Fp2) (v : List K) :
    irEval ((irF_u1.map (Sym.eval hist 18 dr)).map (Fp2.toK U)) v
      = hostTerms v 0 1 2 (some 18) (some 18) (((drR 18 7 2).map (Sym.eval hist 18 dr)).map (Fp2.toK U))
          (zIR_u1 U hist dr v) (reqV (cstK U) v 20 3 [4, 5]) (reqV (cstK U) v 12 7 [8]) := by
  unfold irF_u1
  rw [fzcIr_map, fzcIr_map, cstS_map, fzcIr_eval _ (cstW_map_std U)]
  have hl : (((lksS c0 shF_u1 .F).map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 18 dr))).map
      (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U))).length = 7 := by
    rw [List.length_map, List.length_map, lksF_u1_length]
  simp only [hl]
  rfl

/-- **`SC_FZC`'s cube sum at `export_u1`** (`n = 21` main variables). -/
theorem fzc_cube_u1 (hrl : 0 < rowLog P .a) (n e : ℕ) (hn : n = 21) (aB hB ioIn ioOut ak hk : ℕ)
    (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2)
    (hg0 : ∀ b : Fin 21 → Bool,
      ((pub 0).getD (msbIndex 21 b) Fp2.zero).toK U = algebraMap GF K (B.grpCol (splitF c0 b)))
    (hg1 : ∀ b : Fin 21 → Bool,
      ((pub 1).getD (msbIndex 21 b) Fp2.zero).toK U = algebraMap GF K (B.gF (splitF c0 b)))
    (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval ((irF_u1.map (Sym.eval hist 18 dr)).map (Fp2.toK U))
      (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 rawTabsF_u1).map (TabS.eval (Sym.eval hist 18 dr) pub)).map
        (tabK U P D n e x))) :
    cubeSum f = ∑ b : Fin 21 → Bool, hostPoly (tauF_u1 U (Sym.eval hist 18 dr))
      (fun b => zIR_u1 U hist dr (vF_u1 U P D Pb Lay B (Sym.eval hist 18 dr) b))
      ![(((drR 18 7 2).map (Sym.eval hist 18 dr)).map (Fp2.toK U)).getD 0 0,
        (((drR 18 7 2).map (Sym.eval hist 18 dr)).map (Fp2.toK U)).getD 1 0]
      ![p0F_u1 U (Sym.eval hist 18 dr), p1F_u1 U (Sym.eval hist 18 dr)] (fun _ => 1)
      (fun i b => if i = 0
        then gV (vF_u1 U P D Pb Lay B (Sym.eval hist 18 dr) b) (some 18)
          * reqV (cstK U) (vF_u1 U P D Pb Lay B (Sym.eval hist 18 dr) b) 20 3 [4, 5]
        else gV (vF_u1 U P D Pb Lay B (Sym.eval hist 18 dr) b) (some 18)
          * reqV (cstK U) (vF_u1 U P D Pb Lay B (Sym.eval hist 18 dr) b) 12 7 [8]) b := by
  subst hn
  have hv := fzc_vals_u1 U P D Pb Lay B hrl aB hB ioIn ioOut ak hk e (Sym.eval hist 18 dr) pub hg0 hg1
  rw [cubeSum_host 21 e (fun x => ((DefW16.numTabs aB hB ioIn ioOut ak hk 0 rawTabsF_u1).map
      (TabS.eval (Sym.eval hist 18 dr) pub)).map (tabK U P D 21 e x))
    0 1 2 (some 18) (some 18) (((drR 18 7 2).map (Sym.eval hist 18 dr)).map (Fp2.toK U)) (zIR_u1 U hist dr)
    (fun v => reqV (cstK U) v 20 3 [4, 5]) (fun v => reqV (cstK U) v 12 7 [8]) f
    (fun x => by rw [hf x, fzc_irEval_u1 U hist dr])
    (fun b y hy => fzc_off_u1 U P D aB hB ioIn ioOut ak hk e (Sym.eval hist 18 dr) pub b y hy)
    (tauF_u1 U (Sym.eval hist 18 dr)) ![p0F_u1 U (Sym.eval hist 18 dr), p1F_u1 U (Sym.eval hist 18 dr)]
    (fun b => (congrArg (fun l : List K => l.getD 0 0) (hv b)).trans rfl)
    (fun b => (congrArg (fun l : List K => l.getD 1 0) (hv b)).trans rfl)
    (fun b => (congrArg (fun l : List K => l.getD 2 0) (hv b)).trans rfl)]
  simp only [hv]

end Cube

/-! ## 5. The clause and the hosted terms are the named relations -/

section Rels

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

theorem append_splitF_u1 (b : Fin 21 → Bool) : Fin.append (splitF c0 b).1 (splitF c0 b).2 = b := by
  funext i
  refine Fin.addCases (fun i7 => ?_) (fun i14 => ?_) i
  · rw [Fin.append_left]; rfl
  · rw [Fin.append_right]; rfl

include hX in
theorem alg_plF_u1 (off : ℕ) (b : Fin 21 → Bool) :
    algebraMap GF K (plF U c0 P D off (splitF c0 b)) = aPl U P D off 21 b := by
  unfold plF
  rw [aPl_alg U P D hX]
  show aPl U P D off 21 (Fin.append (splitF c0 b).1 (splitF c0 b).2) = aPl U P D off 21 b
  rw [append_splitF_u1]

include hX in
/-- **The gated product clause IS `relCl 18 0`** (`fold = 16 = S.sprod`, single-limb `rh`). -/
theorem fzc_rel0_u1 (cnA cnM : ℕ) (hS : PrecR (cfgU1 cnA cnM) S) (b : Fin 21 → Bool) (e0 e1 e2 : K) (mu : List K) :
    gV (e0 :: e1 :: e2 :: restF_u1 U P D Pb Lay B b) (some 18)
        * batchV mu (fzcClauses (cstK U) rrF kF_u1 (e0 :: e1 :: e2 :: restF_u1 U P D Pb Lay B b))
      = mu.getD 0 0 * algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 18 0 (.f (splitF c0 b))) := by
  have hsprod : S.sprod = 16 := hS.sprod
  have hrel : relCl Pb Lay B (xtU1 U P D) 18 0 (.f (splitF c0 b))
      = B.gF (splitF c0 b) * (plF U c0 P D (offU1 50) (splitF c0 b) * plF U c0 P D (offU1 51) (splitF c0 b)
        - 2 ^ 16 * plF U c0 P D (offU1 53) (splitF c0 b) - plF U c0 P D (offU1 55) (splitF c0 b) + 2 ^ 15) := by
    simp only [relCl, hsprod]
    rfl
  rw [hrel]
  simp (disch := norm_num) only [gV_some, batchV, fzcClauses, rrF, kF_u1, L16, List.zipIdx_cons, List.zipIdx_nil,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.getD_cons_succ, List.getD_cons_zero, restF_u1,
    add_zero, cstK_base U, cstK_p16 U, map_mul, map_add, map_sub, map_pow, map_ofNat, map_intCast,
    alg_plF_u1 U P D hX]
  push_cast
  ring

include hX in
/-- **The gated first requantization host IS `relGh 18 0`** (gate shift `20`, two limbs `rg`). -/
theorem fzc_gh0_u1 (cnA cnM : ℕ) (hS : PrecR (cfgU1 cnA cnM) S) (b : Fin 21 → Bool) (e0 e1 e2 : K) :
    gV (e0 :: e1 :: e2 :: restF_u1 U P D Pb Lay B b) (some 18)
        * reqV (cstK U) (e0 :: e1 :: e2 :: restF_u1 U P D Pb Lay B b) 20 3 [4, 5]
      = algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 18 0 (.f (splitF c0 b))) := by
  have hsgate : S.sgate = 20 := hS.sgate
  have hrel : relGh Pb Lay B (xtU1 U P D) 18 0 (.f (splitF c0 b))
      = B.gF (splitF c0 b) * (2 ^ 20 * plF U c0 P D (offU1 47) (splitF c0 b)
        + (plF U c0 P D (offU1 48) (splitF c0 b) + 2 ^ 16 * plF U c0 P D (offU1 49) (splitF c0 b)) - 2 ^ 19) := by
    simp only [relGh, hsgate]
    rfl
  rw [hrel]
  simp (disch := norm_num) only [gV_some, reqV, L16, List.zipIdx_cons, List.zipIdx_nil, List.map_cons, List.map_nil,
    List.sum_cons, List.sum_nil, List.getD_cons_succ, List.getD_cons_zero, restF_u1, add_zero, cstK_base U,
    cstK_p16 U, map_mul, map_add, map_sub, map_pow, map_ofNat, map_intCast, alg_plF_u1 U P D hX]
  push_cast
  ring

include hX in
/-- **The gated second requantization host IS `relGh 18 1`** (up shift `12`, single limb `ru`). -/
theorem fzc_gh1_u1 (cnA cnM : ℕ) (hS : PrecR (cfgU1 cnA cnM) S) (b : Fin 21 → Bool) (e0 e1 e2 : K) :
    gV (e0 :: e1 :: e2 :: restF_u1 U P D Pb Lay B b) (some 18)
        * reqV (cstK U) (e0 :: e1 :: e2 :: restF_u1 U P D Pb Lay B b) 12 7 [8]
      = algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 18 1 (.f (splitF c0 b))) := by
  have hsup : S.sup = 12 := hS.sup
  have hrel : relGh Pb Lay B (xtU1 U P D) 18 1 (.f (splitF c0 b))
      = B.gF (splitF c0 b) * (2 ^ 12 * plF U c0 P D (offU1 51) (splitF c0 b)
        + plF U c0 P D (offU1 52) (splitF c0 b) - 2 ^ 11) := by
    simp only [relGh, hsup]
    rfl
  rw [hrel]
  simp (disch := norm_num) only [gV_some, reqV, L16, List.zipIdx_cons, List.zipIdx_nil, List.map_cons, List.map_nil,
    List.sum_cons, List.sum_nil, List.getD_cons_succ, List.getD_cons_zero, restF_u1, add_zero, cstK_base U,
    cstK_p16 U, map_mul, map_add, map_sub, map_pow, map_ofNat, map_intCast, alg_plF_u1 U P D hX]
  push_cast
  ring

end Rels

/-! ## 6. The host's batch -/

section Batch

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7) (P : BlockParams)
  (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

include hU hX in
/-- **The host's batch over the algebra data's tables IS the IR's zero-check sum at `export_u1`**:
the product clause, the ACT relation, LogUp's four helper relations, and the nine pad planes. -/
theorem fzc_batch_u1 (cnA cnM : ℕ) (hS : PrecR (cfgU1 cnA cnM) S) {L : ℕ} (hdr : P.draws = W16R2.shieldDraws)
    (dt : AlgData K L (algShapeU1 P hdr)) (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2)
    (hcl : ∀ (κ : Fin 6) (b : Fin 21 → Bool), dt.cl 18 cu rt bga κ b
      = if (κ : ℕ) < 1 then algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 18 κ (.f (splitF c0 b)))
        else xcFzcU1 U P D Pb Lay B bga κ b)
    (hpw : ∀ (j : Fin 9) (b : Fin 21 → Bool), dt.pw 18 cu rt j b = pwFzcU1 U P D Pb Lay B j b)
    (l : List SlotRec) (dr : List Fp2) (b : Fin 21 → Bool) (e0 e1 e2 : K)
    (ω : (K × K) × (Fin (segLn ((algShapeU1 P hdr).dl 18) .mu
      - segLn ((algShapeU1 P hdr).dl 18) .zeta) → K))
    (h1 : ω.1.1 = (dr.getD 9 Fp2.zero).toK U) (h2 : ω.1.2 = (dr.getD 6 Fp2.zero).toK U)
    (h3 : ∀ κ, ω.2 κ = (dr.getD κ Fp2.zero).toK U) :
    batched (dt.cl 18 cu rt bga) (dt.pw 18 cu rt) ω b
      = zIR_u1 U (histOf bga.1 bga.2.1 bga.2.2 l) dr (e0 :: e1 :: e2 :: restF_u1 U P D Pb Lay B b) := by
  have m_ : ∀ k, k < 7 → (((drR 18 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr)).map
      (Fp2.toK U)).getD k 0 = (dr.getD k Fp2.zero).toK U := fun k hk => muF_getD U _ dr k hk
  have hv : ∀ i, 3 ≤ i → (e0 :: e1 :: e2 :: restF_u1 U P D Pb Lay B b).getD i 0
      = (valsXF_u1 U P D Pb Lay B b).getD i 0 := fun i hi => getD_cons3 _ _ _ _ _ _ _ i hi
  -- the host side, as sums over ranges
  have hA : (∑ k : Fin 6, ω.2 k * dt.cl 18 cu rt bga k b)
      = ∑ k ∈ Finset.range 6, (dr.getD k Fp2.zero).toK U
        * (if k < 1 then algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 18 k (.f (splitF c0 b)))
          else xcFzcU1 U P D Pb Lay B bga k b) := by
    rw [← Fin.sum_univ_eq_sum_range (fun k => (dr.getD k Fp2.zero).toK U
      * (if k < 1 then algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 18 k (.f (splitF c0 b)))
        else xcFzcU1 U P D Pb Lay B bga k b)) 6]
    refine Finset.sum_congr rfl (fun k _ => ?_)
    rw [h3 k, hcl k b]
  have hB : (∑ j : Fin 9, ω.1.1 ^ (j : ℕ) * dt.pw 18 cu rt j b)
      = ∑ j ∈ Finset.range 9, ((dr.getD 9 Fp2.zero).toK U) ^ j
          * (padPls (valsXF_u1 U P D Pb Lay B b) grpF).getD j 0 := by
    rw [← Fin.sum_univ_eq_sum_range (fun j => ((dr.getD 9 Fp2.zero).toK U) ^ j
      * (padPls (valsXF_u1 U P D Pb Lay B b) grpF).getD j 0) 9]
    refine Finset.sum_congr rfl (fun j _ => ?_)
    rw [h1, hpw j b]
    rfl
  -- the IR side
  have hk : lksK_u1 U (histOf bga.1 bga.2.1 bga.2.2 l) dr = lksK_u1 U (histOf bga.1 bga.2.1 bga.2.2 []) [] := by
    unfold lksK_u1
    rw [lksS_eval c0 shF_u1 .F (histOf bga.1 bga.2.1 bga.2.2 l) (histOf bga.1 bga.2.1 bga.2.2 []) 18 18 dr []
      rfl rfl]
  have hlenL : (lkRels (cstK U) (valsXF_u1 U P D Pb Lay B b) 12 0
      (lksK_u1 U (histOf bga.1 bga.2.1 bga.2.2 []) [])).length = 4 := by
    rw [lkRels_length]
    simp only [lksK_u1, List.length_map, lksF_u1_length]
  have hlog : logupSem (cstK U) (e0 :: e1 :: e2 :: restF_u1 U P D Pb Lay B b) 12
      (fun k => (((drR 18 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr)).map (Fp2.toK U)).getD (2 + k) 0)
      0 (lksK_u1 U (histOf bga.1 bga.2.1 bga.2.2 l) dr)
      = ∑ i ∈ Finset.range 4, (dr.getD (2 + i) Fp2.zero).toK U
        * (lkRels (cstK U) (valsXF_u1 U P D Pb Lay B b) 12 0
            (lksK_u1 U (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD i 0 := by
    rw [logupSem_eq_wsum, hk, lkRels_congr (cstK U) _ (valsXF_u1 U P D Pb Lay B b) 12 0 _
      (fun l hl t ht => hv t.2 (lksK_u1_pos U _ [] l hl t ht)) (fun i _ => hv _ (by omega)), wsum_eq_sum]
    rw [Fin.sum_univ_eq_sum_range (fun i => (((drR 18 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr)).map
        (Fp2.toK U)).getD (2 + (0 + i)) 0
      * (lkRels (cstK U) (valsXF_u1 U P D Pb Lay B b) 12 0
          (lksK_u1 U (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD i 0), hlenL]
    refine Finset.sum_congr rfl (fun i hi => ?_)
    have hi4 := Finset.mem_range.mp hi
    rw [m_ _ (by omega), Nat.zero_add]
  have hact : fzcAct (e0 :: e1 :: e2 :: restF_u1 U P D Pb Lay B b) rrF
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr amqS).toK U)
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr nbS).toK U)
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr nb2S).toK U) = xcFzcU1 U P D Pb Lay B bga 1 b := by
    unfold xcFzcU1
    rw [ite_eq_left rfl]
    exact fzcAct_congr _ _ hv _ _ _
  have hlenP : (padPls (valsXF_u1 U P D Pb Lay B b) grpF).length = 9 := by simp [padPls, grpF]
  have hgrp : ∀ g ∈ grpF, (e0 :: e1 :: e2 :: restF_u1 U P D Pb Lay B b).getD g.1 0
        = (valsXF_u1 U P D Pb Lay B b).getD g.1 0
      ∧ ∀ p ∈ g.2, (e0 :: e1 :: e2 :: restF_u1 U P D Pb Lay B b).getD p 0
        = (valsXF_u1 U P D Pb Lay B b).getD p 0 := by
    intro g hg
    simp only [grpF, List.mem_singleton] at hg
    subst hg
    refine ⟨hv 18 (by norm_num), fun p hp => hv p ?_⟩
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
    omega
  have hpad : padSem (cstK U) (e0 :: e1 :: e2 :: restF_u1 U P D Pb Lay B b)
      ((((drR 18 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr)).map (Fp2.toK U)).getD 6 0)
      (fun j => (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr (Sym.pow (.dr 18 9) j)).toK U) 0 grpF
      = (dr.getD 6 Fp2.zero).toK U
        * ∑ j ∈ Finset.range 9, ((dr.getD 9 Fp2.zero).toK U) ^ j
          * (padPls (valsXF_u1 U P D Pb Lay B b) grpF).getD j 0 := by
    rw [padSem_eq_wsum (cstK U) (cstW_map_std U), m_ 6 (by norm_num),
      padPls_congr _ (valsXF_u1 U P D Pb Lay B b) grpF hgrp, wsum_eq_sum]
    congr 1
    rw [Fin.sum_univ_eq_sum_range (fun i => (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr
        (Sym.pow (.dr 18 9) (0 + i))).toK U * (padPls (valsXF_u1 U P D Pb Lay B b) grpF).getD i 0), hlenP]
    refine Finset.sum_congr rfl (fun j _ => ?_)
    rw [Nat.zero_add]
    show (zpowW (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr (.dr 18 9)) j).toK U * _ = _
    rw [toK_zpowW U hU]
    rfl
  have hcla : gV (e0 :: e1 :: e2 :: restF_u1 U P D Pb Lay B b) (some 18)
      * batchV (((drR 18 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr)).map (Fp2.toK U))
        (fzcClauses (cstK U) rrF kF_u1 (e0 :: e1 :: e2 :: restF_u1 U P D Pb Lay B b))
      = (dr.getD 0 Fp2.zero).toK U * algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 18 0 (.f (splitF c0 b))) := by
    rw [fzc_rel0_u1 U P D hX Pb Lay B cnA cnM hS b e0 e1 e2, m_ 0 (by norm_num)]
  have hexp : ∑ k ∈ Finset.range 6, (dr.getD k Fp2.zero).toK U
        * (if k < 1 then algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 18 k (.f (splitF c0 b)))
          else xcFzcU1 U P D Pb Lay B bga k b)
      = (dr.getD 0 Fp2.zero).toK U * algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 18 0 (.f (splitF c0 b)))
        + (dr.getD 1 Fp2.zero).toK U * xcFzcU1 U P D Pb Lay B bga 1 b
        + (dr.getD 2 Fp2.zero).toK U
          * (lkRels (cstK U) (valsXF_u1 U P D Pb Lay B b) 12 0
              (lksK_u1 U (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD 0 0
        + (dr.getD 3 Fp2.zero).toK U
          * (lkRels (cstK U) (valsXF_u1 U P D Pb Lay B b) 12 0
              (lksK_u1 U (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD 1 0
        + (dr.getD 4 Fp2.zero).toK U
          * (lkRels (cstK U) (valsXF_u1 U P D Pb Lay B b) 12 0
              (lksK_u1 U (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD 2 0
        + (dr.getD 5 Fp2.zero).toK U
          * (lkRels (cstK U) (valsXF_u1 U P D Pb Lay B b) 12 0
              (lksK_u1 U (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD 3 0 := by
    simp only [Finset.sum_range_succ, Finset.sum_range_zero, zero_add]
    rfl
  -- assemble
  unfold batched
  show (∑ k : Fin 6, ω.2 k * dt.cl 18 cu rt bga k b)
      + ω.1.2 * (∑ j : Fin 9, ω.1.1 ^ (j : ℕ) * dt.pw 18 cu rt j b) = _
  rw [hA, hB, h2, hexp]
  unfold zIR_u1
  rw [hlog, hact, hpad, hcla, m_ 1 (by norm_num)]
  simp only [Finset.sum_range_succ, Finset.sum_range_zero, zero_add]
  ring

end Batch

/-! ## 7. The hosted matmuls (`SC_GMM` and `SC_UMM`, inner `ld = 12`) -/

section Mm

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

include hX in
/-- The contraction of `SC_FZC`'s pairs at `export_u1`, read through the plane `YM` (plane `18`, log `19`). -/
theorem fzc_mmfun_u1 (y : Fin 21 → Bool) (W : CwU1 → CfU1 → GF) :
    (∑ c : Fin 12 → Bool, aPl U P D (offU1 18) (7 + 12) (Fin.append (fun i => y (Fin.castAdd 14 i)) c)
      * algebraMap GF K (W c (fun i => y (Fin.natAdd 7 i))))
      = algebraMap GF K (∑ c, (xtU1 U P D).YM ((splitF c0 y).1, c) * W c (splitF c0 y).2) := by
  rw [map_sum]
  refine Finset.sum_congr rfl (fun c _ => ?_)
  rw [map_mul, show algebraMap GF K ((xtU1 U P D).YM ((splitF c0 y).1, c))
    = aPl U P D (offU1 18) 19 (Fin.append (splitF c0 y).1 c) from aPl_alg U P D hX (offU1 18) 19 _]
  rfl

include hX in
/-- **`SC_GMM`'s cube sum is the multilinear extension of `relMm 18 0` at its claim point.** -/
theorem gmm_sum_u1 (cnA cnM ioIn ioOut : ℕ) (pubs : PubTabs) (hpub : PubR U c0 pubs Pb Lay B)
    (hrl : 0 < rowLog P .a) (hs11 : slotShape P 11 = (12, 1, 2)) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (r11 : SlotRec) (hr11 : rs[11]? = some r11) (hc11 : ∀ x ∈ r11.draws, x.Canon) :
    cubeSum (polyS U P D (progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs 11 (seenOf bga rs 11))
      = mleAt (fun y : Fin 21 → Bool => algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 18 0 (.f (splitF c0 y))))
          (fun t : Fin 21 => (r11.draws.getD t Fp2.zero).toK U) := by
  obtain ⟨ak, hk, hslot⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 11 (by norm_num)
  have hf : ∀ x, polyS U P D (progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs 11 (seenOf bga rs 11) x
      = tabK U P D (slotShape P 11).1 (slotShape P 11).2.1 x
          (.priv ⟨.a, [(offU1 18, Fp2.one)], 7 + 12, ((drR 11 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2
            (rs.take 11)) 11 r11.draws)).map Coord.fixed ++ rhoAll 12,
            DefW16.aDataRows (cfgU1 cnA cnM) + 2 * ak, 0⟩)
        * tabK U P D (slotShape P 11).1 (slotShape P 11).2.1 x
          (.pub (pubs 11 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 11)) r11.draws 0)) := by
    intro x
    rw [polyS_seenOf U P D _ pubs bga rs 11 r11 hr11 x, hslot, rawSlot11_eq]
    show irEval (((mmIr DefW16.cstS 0 1).map _).map (Fp2.toK U))
      (([TabS.priv ⟨.a, [(offU1 18, false)], 7 + 12, (drR 11 0 7).map CoordS.fixed ++ DefW16.rhoC 0 12,
        DefW16.aDataRows (cfgU1 cnA cnM) + 2 * ak, 0⟩, TabS.pub 0].map (TabS.eval _ _)).map _) = _
    rw [mmSlot_eval, aFx_eval]
  rw [mm_cube U P D hrl _ _ _ 7 12 (by rw [List.length_map, drR_length]) (by rw [hs11]) (by norm_num) (offU1 18) _
    _ _ hf]
  have hwg : ∀ c : Fin 12 → Bool,
      ((pubs 11 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 11)) r11.draws 0).getD (msbIndex 12 c) Fp2.zero).toK U
      = ∑ y : Fin 14 → Bool, eqDr U r11.draws 7 14 y * algebraMap GF K (B.Wg c y) :=
    hpub.wg (histOf bga.1 bga.2.1 bga.2.2 (rs.take 11)) r11.draws hc11
  simp only [hwg, eqDr]
  rw [mm_fold]
  have hfun : ∀ y : Fin 21 → Bool, (∑ c : Fin 12 → Bool, aPl U P D (offU1 18) (7 + 12)
      (Fin.append (fun i => y (Fin.castAdd 14 i)) c) * algebraMap GF K (B.Wg c (fun i => y (Fin.natAdd 7 i))))
      = algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 18 0 (.f (splitF c0 y))) := fun y =>
    fzc_mmfun_u1 U P D hX y B.Wg
  have hpt : ∀ t : Fin (7 + 14), Fin.append (fun i : Fin 7 => (((drR 11 0 7).map (Sym.eval (histOf bga.1 bga.2.1
      bga.2.2 (rs.take 11)) 11 r11.draws)).getD i Fp2.zero).toK U)
      (fun a : Fin 14 => (r11.draws.getD (7 + a) Fp2.zero).toK U) t = (r11.draws.getD t Fp2.zero).toK U := by
    intro t
    refine Fin.addCases (fun i => ?_) (fun a => ?_) t
    · rw [Fin.append_left, drR_getD _ 11 0 7 i i.isLt, Nat.zero_add]
      rfl
    · rw [Fin.append_right]
      rfl
  exact congr (congrArg mleAt (funext hfun)) (funext hpt)

include hX in
/-- **`SC_UMM`'s cube sum is the multilinear extension of `relMm 18 1` at its split claim point** (`SC_GMM`'s
7 token coordinates, then its own 14 draws). -/
theorem umm_sum_u1 (cnA cnM ioIn ioOut : ℕ) (pubs : PubTabs) (hpub : PubR U c0 pubs Pb Lay B)
    (hrl : 0 < rowLog P .a) (hs12 : slotShape P 12 = (12, 1, 2)) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (r11 r12 : SlotRec) (hr11 : rs[11]? = some r11) (hr12 : rs[12]? = some r12)
    (hc12 : ∀ x ∈ r12.draws, x.Canon) :
    cubeSum (polyS U P D (progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs 12 (seenOf bga rs 12))
      = mleAt (fun y : Fin 21 → Bool => algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 18 1 (.f (splitF c0 y))))
          (fun t : Fin 21 => if (t : ℕ) < 7 then (r11.draws.getD t Fp2.zero).toK U
            else (r12.draws.getD ((t : ℕ) - 7) Fp2.zero).toK U) := by
  obtain ⟨ak, hk, hslot⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 12 (by norm_num)
  have hf : ∀ x, polyS U P D (progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs 12 (seenOf bga rs 12) x
      = tabK U P D (slotShape P 12).1 (slotShape P 12).2.1 x
          (.priv ⟨.a, [(offU1 18, Fp2.one)], 7 + 12, ((drR 11 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2
            (rs.take 12)) 12 r12.draws)).map Coord.fixed ++ rhoAll 12,
            DefW16.aDataRows (cfgU1 cnA cnM) + 2 * ak, 0⟩)
        * tabK U P D (slotShape P 12).1 (slotShape P 12).2.1 x
          (.pub (pubs 12 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 12)) r12.draws 0)) := by
    intro x
    rw [polyS_seenOf U P D _ pubs bga rs 12 r12 hr12 x, hslot, rawSlot12_eq]
    show irEval (((mmIr DefW16.cstS 0 1).map _).map (Fp2.toK U))
      (([TabS.priv ⟨.a, [(offU1 18, false)], 7 + 12, (drR 11 0 7).map CoordS.fixed ++ DefW16.rhoC 0 12,
        DefW16.aDataRows (cfgU1 cnA cnM) + 2 * ak, 0⟩, TabS.pub 0].map (TabS.eval _ _)).map _) = _
    rw [mmSlot_eval, aFx_eval]
  rw [mm_cube U P D hrl _ _ _ 7 12 (by rw [List.length_map, drR_length]) (by rw [hs12]) (by norm_num) (offU1 18) _
    _ _ hf]
  have hwu : ∀ c : Fin 12 → Bool,
      ((pubs 12 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 12)) r12.draws 0).getD (msbIndex 12 c) Fp2.zero).toK U
      = ∑ y : Fin 14 → Bool, eqDr U r12.draws 0 14 y * algebraMap GF K (B.Wu c y) :=
    hpub.wu (histOf bga.1 bga.2.1 bga.2.2 (rs.take 12)) r12.draws hc12
  simp only [hwu, eqDr]
  rw [mm_fold]
  have hfun : ∀ y : Fin 21 → Bool, (∑ c : Fin 12 → Bool, aPl U P D (offU1 18) (7 + 12)
      (Fin.append (fun i => y (Fin.castAdd 14 i)) c) * algebraMap GF K (B.Wu c (fun i => y (Fin.natAdd 7 i))))
      = algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 18 1 (.f (splitF c0 y))) := fun y =>
    fzc_mmfun_u1 U P D hX y B.Wu
  have hpt : ∀ t : Fin (7 + 14), Fin.append (fun i : Fin 7 => (((drR 11 0 7).map (Sym.eval (histOf bga.1 bga.2.1
      bga.2.2 (rs.take 12)) 12 r12.draws)).getD i Fp2.zero).toK U)
      (fun a : Fin 14 => (r12.draws.getD (0 + a) Fp2.zero).toK U) t
      = if (t : ℕ) < 7 then (r11.draws.getD t Fp2.zero).toK U
        else (r12.draws.getD ((t : ℕ) - 7) Fp2.zero).toK U := by
    intro t
    refine Fin.addCases (fun i => ?_) (fun a => ?_) t
    · rw [Fin.append_left, drR_getD _ 11 0 7 i i.isLt, Nat.zero_add,
        ite_eq_left (show ((Fin.castAdd 14 i : Fin (7 + 14)) : ℕ) < 7 from i.isLt)]
      exact algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 12 11 i r11 (by norm_num) hr11
    · rw [Fin.append_right, ite_eq_right (show ¬ (((Fin.natAdd 7 a : Fin (7 + 14)) : ℕ) < 7) by simp)]
      simp
  exact congr (congrArg mleAt (funext hfun)) (funext hpt)

end Mm

/-! ## 8. `SC_FZC`'s named identity at `export_u1` (`formAt_fzcU1`) -/

section Form

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K]

/-- **`SC_FZC`'s named identity at W16R2 Shieldstral (`export_u1`)**, parametric in `(cnA, cnM)`:
on every outcome whose verified slots are hosts exactly when their definitions host slots, `SC_FZC`'s
certified polynomial at the drawn challenges IS its unmasked residual `Σ Poly₁₈ − (ν₀·Σ Poly₁₁ + ν₁·Σ Poly₁₂)`,
for every algebra data whose host-`18` tables are `relCl 18`, `xcFzcU1`, `pwFzcU1`, `relGh 18`, and
`relMm 18` of the extracted planes `xtU1`. -/
theorem formAt_fzcU1 (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) {L : ℕ}
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
    (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws) (hsl : P.geom.slots = W16R2.shieldSlots)
    (cnA cnM ioIn ioOut : ℕ) (pubs : PubTabs)
    (hdef : P.define = defineS (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
    (hS : PrecR (cfgU1 cnA cnM) S) (_hLay : LayR Lay) (hpub : PubR U c0 pubs Pb Lay B)
    (dt : AlgData K L (algShapeU1 P hdr)) (cu : Cuts3 L) (rt : RootsO)
    (hcl : ∀ bga (κ : Fin 6) (b : Fin 21 → Bool), dt.cl 18 cu rt bga κ b
      = if (κ : ℕ) < 1 then algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 18 κ (.f (splitF c0 b)))
        else xcFzcU1 U P D Pb Lay B bga κ b)
    (hpw : ∀ (j : Fin 9) (b : Fin 21 → Bool), dt.pw 18 cu rt j b = pwFzcU1 U P D Pb Lay B j b)
    (hgh : ∀ (i : Fin 2) (b : Fin 21 → Bool),
      dt.gh 18 cu rt i b = algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 18 i (.f (splitF c0 b))))
    (hmm : ∀ (i : Fin 2) (b : Fin 21 → Bool),
      dt.mm 18 cu rt i b = algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 18 i (.f (splitF c0 b))))
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    FormAt U P (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeU1 P hdr) dt hcard 0 cu rt k h).Φ) bga rs 18 := by
  obtain ⟨hs18, hs11, hs12⟩ := slotShape_fzc_u1 P hsl
  obtain ⟨ak18, hk18, hslot18⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 18 (by norm_num)
  obtain ⟨_, _, hslot11⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 11 (by norm_num)
  obtain ⟨_, _, hslot12⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 12 (by norm_num)
  refine formAt_two U hcard P (progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs hdef D
    (algShapeU1 P hdr) dt cu rt bga rs 18 (by decide) 11 12 (.dr 18 7) (.dr 18 8)
    (by rw [hslot18, rawSlot18_eq]; rfl) (by rw [hslot11, rawSlot11_eq]; rfl) (by rw [hslot12, rawSlot12_eq]; rfl)
    (by norm_num) (by norm_num) hslots (fun r hr => ?_)
  have hlen : 18 < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨r11, hr11⟩ : ∃ r11, rs[11]? = some r11 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  obtain ⟨r12, hr12⟩ : ∃ r12, rs[12]? = some r12 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  have hcanon : ∀ (j : ℕ) (rj : SlotRec), rs[j]? = some rj → ∀ x ∈ rj.draws, Fp2.Canon x := by
    intro j rj hrj
    obtain ⟨df, hdf, -⟩ := hslots j rj hrj
    have hdf' : defineS (progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) rj.draws
        = .ok df := hdef ▸ hdf
    exact (defineS_ok hdf').1.2.2.2
  -- the three slots' cube sums
  have hsp18 := fzc_cube_u1 U P D Pb Lay B hrl (slotShape P 18).1 (slotShape P 18).2.1 (by rw [hs18])
    (DefW16.aDataRows (cfgU1 cnA cnM)) (DefW16.hDataRows (cfgU1 cnA cnM)) ioIn ioOut ak18 hk18
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) r.draws (pubs 18 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) r.draws)
    (hpub.fzcGrp _ _) (hpub.fzcGate _ _) (polyS U P D (progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs 18 (seenOf bga rs 18))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 18 r hr x, hslot18, rawSlot18_eq]; rfl)
  have hsp11 := gmm_sum_u1 U P D hX Pb Lay B cnA cnM ioIn ioOut pubs hpub hrl hs11 bga rs r11 hr11
    (hcanon 11 r11 hr11)
  have hsp12 := umm_sum_u1 U P D hX Pb Lay B cnA cnM ioIn ioOut pubs hpub hrl hs12 bga rs r11 r12 hr11 hr12
    (hcanon 12 r12 hr12)
  have hz1 : segLn ((algShapeU1 P hdr).dl 18) .zeta = 1 := rfl
  have hM : ∀ i : Fin 2, algM (algShapeU1 P hdr) dt 18 cu rt i
      = fun y => algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 18 i (.f (splitF c0 y))) := fun i => by
    rw [algM_mm (algShapeU1 P hdr) dt 18 cu rt i (fun h => absurd h.1 (by decide))]
    exact funext (hmm i)
  have hp0 : algPt U (algShapeU1 P hdr) 18 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 0
      = fun t => (r11.draws.getD t.val Fp2.zero).toK U := by
    funext t
    show algDrawAt U (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 11 t = _
    exact algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 18 11 t r11 (by norm_num) hr11
  have hp1 : algPt U (algShapeU1 P hdr) 18 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 1
      = fun t : Fin 21 => if (t : ℕ) < 7 then (r11.draws.getD t Fp2.zero).toK U
        else (r12.draws.getD ((t : ℕ) - 7) Fp2.zero).toK U := by
    funext t
    show (if (t : ℕ) < 7 then algDrawAt U (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 11 t
      else algDrawAt U (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 12 ((t : ℕ) - 7)) = _
    rw [algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 18 11 t r11 (by norm_num) hr11,
      algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 18 12 _ r12 (by norm_num) hr12]
  rw [hostSp_Φ]
  unfold hostPhi
  unfold spSum
  rw [hsp18, hsp11, hsp12]
  refine congrArg₂ (fun x y : K => x - y) ?_ ?_
  · -- the host's sum
    refine Finset.sum_congr rfl (fun b _ => ?_)
    refine hostPoly_ext _ _ _ _ _ _ _ _ _ _ _ b (fun a => ?_) ?_ (fun i => ?_) (fun i j => ?_) (fun i => ?_)
    · have ha : (a : ℕ) < 21 := a.isLt
      show segAt ((algShapeU1 P hdr).dl 18)
        (fun j => (fun i : Fin (P.draws 18) => (r.draws.getD i.val Fp2.zero).toK U)
          (Fin.cast ((algShapeU1 P hdr).hsum 18 (by decide)) j)) .tau a = _
      unfold segAt
      rw [dite_eq_left (by show 10 + (a : ℕ) < 31; omega)]
      unfold tauF_u1
      rw [drR_getD _ 18 10 21 a ha]
      rfl
    · refine fzc_batch_u1 U hU P D hX Pb Lay B cnA cnM hS hdr dt cu rt _ (fun κ b => hcl _ κ b) hpw (rs.take 18)
        r.draws b _ _ _ _ ?_ ?_ (fun κ => ?_)
      · dsimp only
        rw [ite_eq_left hz1]
        unfold segAt
        rw [dite_eq_left (by show 9 + 0 < 31; omega)]
        rfl
      · dsimp only
        rw [ite_eq_left hz1]
        unfold segAt
        rw [dite_eq_left (by show 0 + 6 < 31; omega)]
        rfl
      · have hκ : (κ : ℕ) < 6 := κ.isLt
        dsimp only
        unfold segAt
        rw [dite_eq_left (by show 0 + (κ : ℕ) < 31; omega)]
        simp only [Fin.val_cast]
        rw [show segOff ((algShapeU1 P hdr).dl 18) .mu = 0 from rfl, Nat.zero_add]
    · fin_cases i
      · dsimp only
        unfold segAt
        rw [dite_eq_left (by show 7 + 0 < 31; omega)]
        rfl
      · dsimp only
        unfold segAt
        rw [dite_eq_left (by show 7 + 1 < 31; omega)]
        rfl
    · have hj : (j : ℕ) < 21 := j.isLt
      fin_cases i
      · show algPt U (algShapeU1 P hdr) 18 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 0 j
          = p0F_u1 U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 18 r.draws) j
        rw [hp0]
        show (r11.draws.getD j Fp2.zero).toK U = p0F_u1 U _ j
        unfold p0F_u1
        rw [drR_getD _ 11 0 21 j hj, Nat.zero_add]
        exact (algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 18 11 j r11 (by norm_num) hr11).symm
      · show algPt U (algShapeU1 P hdr) 18 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 1 j
          = p1F_u1 U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 18 r.draws) j
        rw [hp1]
        show (if (j : ℕ) < 7 then (r11.draws.getD j Fp2.zero).toK U
          else (r12.draws.getD ((j : ℕ) - 7) Fp2.zero).toK U) = p1F_u1 U _ j
        unfold p1F_u1
        rw [List.map_append]
        have hl7 : ((drR 11 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 18 r.draws)).length = 7 := by
          rw [List.length_map, drR_length]
        by_cases h7 : (j : ℕ) < 7
        · rw [ite_eq_left h7, getD_app ((drR 11 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 18
            r.draws)) ((drR 12 0 14).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 18 r.draws)) Fp2.zero j
            (by rw [hl7]; exact h7), drR_getD _ 11 0 7 j h7, Nat.zero_add]
          exact (algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 18 11 j r11 (by norm_num) hr11).symm
        · rw [ite_eq_right h7, getD_app_right ((drR 11 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18))
            18 r.draws)) ((drR 12 0 14).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 18 r.draws)) Fp2.zero j
            (by rw [hl7]; omega), hl7, drR_getD _ 12 0 14 ((j : ℕ) - 7) (by omega), Nat.zero_add]
          exact (algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 18 12 _ r12 (by norm_num) hr12).symm
    · rw [algH_gh U _ dt 18 cu rt _ i (fun h => absurd h.1 (by decide)), hgh i b]
      fin_cases i
      · exact (fzc_gh0_u1 U P D hX Pb Lay B cnA cnM hS b _ _ _).symm
      · exact (fzc_gh1_u1 U P D hX Pb Lay B cnA cnM hS b _ _ _).symm
  · -- the hosted sums
    rw [Fin.sum_univ_two, hM 0, hM 1, hp0, hp1]
    refine congrArg₂ (fun x y : K => x + y) (congrArg₂ (fun x y : K => x * y) ?_ ?_)
      (congrArg₂ (fun x y : K => x * y) ?_ ?_)
    · dsimp only
      unfold segAt
      rw [dite_eq_left (by show 7 + 0 < 31; omega)]
      rfl
    · rfl
    · dsimp only
      unfold segAt
      rw [dite_eq_left (by show 7 + 1 < 31; omega)]
      rfl
    · rfl

end Form

end ZK60.Exec.Block.Join.W16U1.Fzc
